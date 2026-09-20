import { NotFoundError, ok, parseId, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { resolveCollection } from "@/server/cms/registry";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ section: string; collection: string; id: string }>;
}

/**
 * Promotes one news story to the lead slot.
 *
 * A route of its own rather than a boolean on the row, because the lead is
 * exclusive: `cms.news_set_lead` demotes the current lead in the same
 * statement, so the digest can never render two lead cards or none.
 */
export async function POST(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section, collection, id } = await params;
    const def = resolveCollection(section, collection);

    if (!def?.extraActions?.includes("set_lead")) {
      throw new NotFoundError(`${section}/${collection} has no lead item.`);
    }

    return ok(await callFunctionOne(`cms.${def.fnPrefix}_set_lead`, [parseId(id)]));
  });
}
