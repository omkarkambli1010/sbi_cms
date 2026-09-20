import { NotFoundError, ok, route } from "@/server/api/respond";
import { requirePublicToken } from "@/server/api/publicToken";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ slug: string }>;
}

/**
 * The published page, as one document.
 *
 * One of two routes that answer without a dashboard session — the other is
 * /api/public/site, which carries the header and footer. A pass-through:
 * `cms.public_page_payload` has
 * already dropped inactive rows, applied banner scheduling and resolved media
 * to URLs, so there is no shaping here that could diverge from what the
 * dashboard's preview of the same data would show.
 */

export async function GET(request: Request, { params }: Params) {
  return route(async () => {
    requirePublicToken(request);

    const { slug } = await params;

    const row = await callFunctionOne<{ public_page_payload: unknown }>(
      "cms.public_page_payload",
      [slug],
    );

    /* The function returns NULL for an unknown or disabled page, which
       callFunctionOne reports as null. That is a 404, not an empty page. */
    if (!row?.public_page_payload) throw new NotFoundError(`No published page "${slug}".`);

    return ok(row.public_page_payload);
  });
}
