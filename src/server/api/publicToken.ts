import "server-only";

import { timingSafeEqual } from "node:crypto";

import { UnauthorizedError } from "@/server/auth/session";

/**
 * The bearer check the public routes share.
 *
 * One implementation, so a second public route cannot be added with a subtly
 * weaker check — an early `return` on a missing header, say, or a `===`
 * comparison that leaks length through timing.
 */
export function requirePublicToken(request: Request): void {
  const expected = process.env.CMS_PUBLIC_API_TOKEN?.trim();

  if (!expected) {
    /* Refusing beats serving unauthenticated: an environment that forgot the
       token should fail visibly at the first request, not quietly publish. */
    throw new UnauthorizedError("CMS_PUBLIC_API_TOKEN is not configured on this server.");
  }

  const header = request.headers.get("authorization") ?? "";
  const presented = header.startsWith("Bearer ") ? header.slice(7).trim() : "";

  const a = Buffer.from(presented);
  const b = Buffer.from(expected);

  if (a.length !== b.length || !timingSafeEqual(a, b)) {
    throw new UnauthorizedError("Invalid or missing bearer token.");
  }
}
