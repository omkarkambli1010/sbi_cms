import "server-only";

import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";

const scrypt = promisify(scryptCallback);

/** Node ships scrypt, so password hashing costs the project no dependency. */
const KEY_LENGTH = 64;

export interface PasswordRecord {
  hash: string;
  salt: string;
}

export async function hashPassword(
  password: string,
  salt: string = randomBytes(16).toString("hex"),
): Promise<PasswordRecord> {
  const derived = (await scrypt(password, salt, KEY_LENGTH)) as Buffer;
  return { hash: derived.toString("hex"), salt };
}

/**
 * Constant-time comparison.
 *
 * `timingSafeEqual` throws when the two buffers differ in length, so the length
 * is checked first — and a mismatched length is itself a failure, not an error
 * worth surfacing.
 */
export async function verifyPassword(
  password: string,
  expectedHash: string,
  salt: string,
): Promise<boolean> {
  const { hash } = await hashPassword(password, salt);

  const candidate = Buffer.from(hash, "hex");
  const expected = Buffer.from(expectedHash, "hex");

  if (candidate.length !== expected.length) return false;

  return timingSafeEqual(candidate, expected);
}

/**
 * The rules the dashboard enforces on a new password. Deliberately short: a
 * length floor does more for account safety than a character-class rule, which
 * mostly teaches people to end passwords with "1!".
 */
export function describePasswordProblem(password: string): string | null {
  if (password.length < 12) return "Password must be at least 12 characters.";
  if (password.length > 200) return "Password must be 200 characters or fewer.";
  if (!password.trim()) return "Password cannot be blank.";
  return null;
}
