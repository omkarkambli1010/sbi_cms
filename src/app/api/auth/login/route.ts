import { headers } from "next/headers";

import { FieldReader, ok, readJson, route, ValidationError } from "@/server/api/respond";
import { verifyPassword } from "@/server/auth/password";
import { createSession, UnauthorizedError } from "@/server/auth/session";
import { callFunction, callFunctionOne } from "@/server/db/pool";

interface AdminUserRow {
  id: string;
  username: string;
  email: string | null;
  full_name: string;
  role: string;
  password_hash: string;
  password_salt: string;
  is_active: boolean;
}

/** Staff codes: digits only, as `admin_users_username_check` enforces. */
const USERNAME = /^[0-9]{4,20}$/;

/**
 * Attempt throttling.
 *
 * In-process and therefore per-instance: behind several instances an attacker
 * gets the allowance once per instance. That is a real limit and it is stated
 * rather than papered over — a shared counter needs a store this project does
 * not have, and the alternative today is no limit at all. Password hashing is
 * scrypt, so each attempt already costs the attacker more than it costs us.
 */
const WINDOW_MS = 15 * 60 * 1000;
const MAX_ATTEMPTS = 10;

declare global {
  var __sbiCmsLoginAttempts: Map<string, { count: number; resetAt: number }> | undefined;
}

function attempts(): Map<string, { count: number; resetAt: number }> {
  globalThis.__sbiCmsLoginAttempts ??= new Map();
  return globalThis.__sbiCmsLoginAttempts;
}

function throttle(key: string): void {
  const now = Date.now();
  const store = attempts();
  const entry = store.get(key);

  if (!entry || entry.resetAt < now) {
    store.set(key, { count: 1, resetAt: now + WINDOW_MS });
    return;
  }

  entry.count += 1;

  if (entry.count > MAX_ATTEMPTS) {
    throw new UnauthorizedError("Too many attempts. Try again in a few minutes.");
  }
}

function clearThrottle(key: string): void {
  attempts().delete(key);
}

export async function POST(request: Request) {
  return route(async () => {
    const body = await readJson(request);
    const reader = new FieldReader(body);

    const username = reader.string("username", { required: true, max: 20 });
    const password = reader.string("password", { required: true, max: 200 });
    reader.done();

    if (!USERNAME.test(username)) {
      /* Rejected as a validation problem, not as a wrong password: the field
         has a shape, and saying so is not an enumeration risk. */
      throw new ValidationError({ username: "Your username is digits only." });
    }

    const headerList = await headers();
    const ip = headerList.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "local";
    const key = `${username}|${ip}`;

    throttle(key);

    const user = await callFunctionOne<AdminUserRow>("cms.admin_user_get_by_username", [username]);

    /* The same message and the same amount of work whether the username is
       unknown, the account is switched off, or the password is wrong: three
       different answers would be an account-enumeration oracle. The hash is
       verified against a dummy record when there is no user so the timing
       does not give the answer away either. */
    const record = user ?? {
      password_hash: "0".repeat(128),
      password_salt: "0".repeat(32),
      is_active: false,
    };

    const correct = await verifyPassword(password, record.password_hash, record.password_salt);

    if (!user || !user.is_active || !correct) {
      throw new ValidationError(
        { password: "Check your username and password." },
        "Those details do not match an active account.",
      );
    }

    clearThrottle(key);

    await createSession(Number(user.id));
    await callFunction("cms.admin_user_touch_login", [Number(user.id)]);

    return ok({
      id: Number(user.id),
      username: user.username,
      fullName: user.full_name,
      role: user.role,
    });
  });
}
