import { ok, route } from "@/server/api/respond";
import { destroySession } from "@/server/auth/session";

/**
 * POST rather than GET: signing out is a state change, and a GET would let a
 * prefetch or an image tag end someone's session.
 */
export async function POST() {
  return route(async () => {
    await destroySession();
    return ok({ signedOut: true });
  });
}
