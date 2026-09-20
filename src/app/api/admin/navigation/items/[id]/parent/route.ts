import { FieldReader, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ id: string }>;
}

/**
 * Moves a link under another, or back to the top level.
 *
 * A route of its own rather than a field on PUT, for the same reason
 * cms.nav_item_move is a function of its own: `parent_id: null` is a real
 * value meaning "top level", so a body that simply omitted it could not be
 * told apart from one asking to promote the link.
 *
 * The stored function refuses a cycle, a different menu, or an item as its
 * own parent — so a dashboard that got confused cannot take every marketing
 * page down by making nav_children recurse forever.
 */
export async function PATCH(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);
    const reader = new FieldReader(await readJson(request));
    const parentId = reader.id("parent_id");
    reader.done();

    return ok(await callFunctionOne("cms.nav_item_move", [id, parentId]));
  });
}
