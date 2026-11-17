import "server-only";

import { cookies } from "next/headers";

/**
 * The one place this app learns where the Go service (cms-backend) lives and
 * how to talk to it.
 *
 * Everything the dashboard reads or writes goes through that service, which is
 * the only thing that holds a database connection. This app has no `pg`, no
 * DATABASE_URL, and no SQL.
 */

export function backendOrigin(): string {
  return (process.env.CMS_BACKEND_URL?.trim() || "http://127.0.0.1:8080").replace(/\/+$/, "");
}

export interface SessionUser {
  id: number;
  /** The numeric staff code people sign in with. */
  username: string;
  fullName: string;
  role: "admin" | "editor";
}

interface Envelope<T> {
  ok: boolean;
  data?: T;
}

/**
 * Calls the backend from a Server Component, carrying the visitor's session
 * cookie so the backend can tell who is asking. Returns null when the backend
 * is unreachable or answers with an error; callers render their own states.
 */
export async function backendGet<T>(path: string): Promise<T | null> {
  const cookieHeader = (await cookies()).toString();

  try {
    const response = await fetch(`${backendOrigin()}${path}`, {
      headers: cookieHeader ? { cookie: cookieHeader } : undefined,
      cache: "no-store",
    });
    const body = (await response.json()) as Envelope<T>;

    return body.ok ? (body.data ?? null) : null;
  } catch (error) {
    console.error(`[backend] ${path} failed:`, (error as Error).message);
    return null;
  }
}

/** Who is signed in, and whether that is only the development bypass. */
export async function getSession(): Promise<{ user: SessionUser | null; bypassed: boolean }> {
  const data = await backendGet<{ user: SessionUser | null; bypassed: boolean }>("/api/auth/me");

  return { user: data?.user ?? null, bypassed: Boolean(data?.bypassed) };
}

export async function getSessionUser(): Promise<SessionUser | null> {
  return (await getSession()).user;
}
