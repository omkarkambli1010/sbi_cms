import "server-only";

import { createHmac, randomBytes } from "node:crypto";
import { cookies, headers } from "next/headers";

import { callFunction, callFunctionOne } from "@/server/db/pool";

export const SESSION_COOKIE = "sbi_cms_session";

export interface SessionUser {
  id: number;
  /** The numeric staff code people sign in with. */
  username: string;
  /** Contact address. Optional — it is not how anyone signs in. */
  email: string | null;
  fullName: string;
  role: "admin" | "editor";
}

interface SessionRow {
  session_id: string;
  user_id: string;
  username: string | null;
  email: string | null;
  full_name: string;
  role: string;
  expires_at: Date;
}

function sessionSecret(): string {
  const secret = process.env.CMS_SESSION_SECRET?.trim();

  if (!secret || secret.length < 32) {
    throw new Error(
      "CMS_SESSION_SECRET must be set to at least 32 characters. Generate one with: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\"",
    );
  }

  return secret;
}

/**
 * What goes in the database is an HMAC of the cookie value, not the value
 * itself and not a bare SHA. The server-side secret acts as a pepper: someone
 * holding a dump of admin_sessions still cannot mint a working cookie without
 * also holding CMS_SESSION_SECRET.
 */
function tokenHash(token: string): string {
  return createHmac("sha256", sessionSecret()).update(token).digest("hex");
}

function ttlHours(): number {
  const raw = Number(process.env.CMS_SESSION_TTL_HOURS ?? 12);
  return Number.isFinite(raw) && raw > 0 ? raw : 12;
}

/** Issues a session and sets the cookie. Returns nothing the caller must handle. */
export async function createSession(userId: number): Promise<void> {
  const token = randomBytes(32).toString("hex");
  const expiresAt = new Date(Date.now() + ttlHours() * 60 * 60 * 1000);

  const headerList = await headers();

  await callFunction("cms.session_create", [
    userId,
    tokenHash(token),
    expiresAt.toISOString(),
    headerList.get("user-agent")?.slice(0, 500) ?? null,
    /* Only the first hop is meaningful; the rest of x-forwarded-for can be
       spoofed by the client. Behind a trusted proxy this is the real address. */
    headerList.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null,
  ]);

  const cookieStore = await cookies();

  cookieStore.set(SESSION_COOKIE, token, {
    httpOnly: true,
    sameSite: "lax",
    /* Lax rather than strict so following a link into the dashboard keeps the
       session; the dashboard performs no cross-site state change on GET. */
    secure: process.env.NODE_ENV === "production",
    path: "/",
    expires: expiresAt,
  });
}

/**
 * Development-only sign-in bypass.
 *
 * Set CMS_DEV_BYPASS_AUTH=true in .env.local to walk the dashboard without an
 * account — useful before the database exists, since the sign-in form cannot
 * work until there is an admin_users row to check against.
 *
 * Two locks, not one. The environment variable alone is not enough: the
 * NODE_ENV check means a production build ignores the flag even if the
 * variable is set there by accident, by a copied .env, or on purpose. A
 * single flag would be one careless deploy away from an open dashboard.
 *
 * It is also announced in the UI — see the banner in the dashboard layout —
 * because a bypass nobody can see is one nobody remembers to turn off.
 */
export function isAuthBypassed(): boolean {
  return process.env.NODE_ENV !== "production" && process.env.CMS_DEV_BYPASS_AUTH === "true";
}

/** The stand-in identity. Not a database row, and deliberately labelled. */
const BYPASS_USER: SessionUser = {
  id: 0,
  username: "00000",
  email: null,
  fullName: "Development bypass",
  role: "admin",
};

/** Resolves the caller, or null when there is no valid session. */
export async function getSessionUser(): Promise<SessionUser | null> {
  /* Before the cookie is read, and before the database is touched: the whole
     point is that this works with no database at all. */
  if (isAuthBypassed()) return BYPASS_USER;

  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;

  if (!token) return null;

  let row: SessionRow | null;

  try {
    row = await callFunctionOne<SessionRow>("cms.session_resolve", [tokenHash(token)]);
  } catch (error) {
    /* A database outage should read as "not signed in" rather than a 500 on
       every page, so the dashboard can still render its error state. */
    console.error("[auth] session lookup failed:", (error as Error).message);
    return null;
  }

  if (!row) return null;

  return {
    id: Number(row.user_id),
    username: row.username ?? "",
    email: row.email,
    fullName: row.full_name,
    role: row.role === "admin" ? "admin" : "editor",
  };
}

export async function destroySession(): Promise<void> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE)?.value;

  if (token) {
    try {
      await callFunction("cms.session_revoke", [tokenHash(token)]);
    } catch (error) {
      /* Best effort: the cookie is cleared either way, so the browser stops
         presenting it even if the row could not be marked revoked. */
      console.error("[auth] session revoke failed:", (error as Error).message);
    }
  }

  cookieStore.delete(SESSION_COOKIE);
}

/**
 * Guard for API routes and Server Components that must not render for an
 * anonymous caller. Throws a typed error the route handler maps to a 401.
 */
export class UnauthorizedError extends Error {
  constructor(message = "Authentication required.") {
    super(message);
    this.name = "UnauthorizedError";
  }
}

export class ForbiddenError extends Error {
  constructor(message = "You do not have permission to do that.") {
    super(message);
    this.name = "ForbiddenError";
  }
}

export async function requireUser(): Promise<SessionUser> {
  const user = await getSessionUser();
  if (!user) throw new UnauthorizedError();
  return user;
}

export async function requireAdmin(): Promise<SessionUser> {
  const user = await requireUser();
  if (user.role !== "admin") throw new ForbiddenError("Administrator access required.");
  return user;
}
