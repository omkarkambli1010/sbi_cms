import { NotFoundError, ok, route } from "@/server/api/respond";
import { requirePublicToken } from "@/server/api/publicToken";
import { callFunctionOne } from "@/server/db/pool";

/**
 * The chrome every marketing route needs: settings, menus, footer content.
 *
 * Separate from the page payload because the header and footer are not part
 * of any one page. A route that only renders the shell should not have to
 * fetch the home page's fifteen sections to find out what the wordmark says.
 */
export async function GET(request: Request) {
  return route(async () => {
    requirePublicToken(request);

    const row = await callFunctionOne<{ public_site_payload: unknown }>(
      "cms.public_site_payload",
    );

    if (!row?.public_site_payload) throw new NotFoundError("Site settings are not seeded.");

    return ok(row.public_site_payload);
  });
}
