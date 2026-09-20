import { FieldReader, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction, callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ menuKey: string }>;
}

/**
 * One menu's items, flat and in order.
 *
 * Flat rather than nested: `parent_id` is on every row, so the screen builds
 * the tree itself and the reorder endpoint keeps working on one level at a
 * time, which is how `cms.nav_item_reorder` numbers them.
 */
export async function GET(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { menuKey } = await params;
    const onlyActive = new URL(request.url).searchParams.get("active") === "true";

    /* `{ items }`, matching the home-page collection lists. The dashboard
       renders both through one component, and a second shape here would mean
       that component had to know which endpoint it was talking to. */
    return ok({ items: await callFunction("cms.nav_item_list", [menuKey, onlyActive]) });
  });
}

export async function POST(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { menuKey } = await params;
    const reader = new FieldReader(await readJson(request));

    const args = [
      menuKey,
      reader.string("label", { required: true, max: 200 }),
      reader.href("href") || "#",
      reader.id("parent_id"),
      reader.id("icon_media_id"),
      reader.boolean("opens_in_new_tab"),
    ];

    reader.done();

    return ok(await callFunctionOne("cms.nav_item_create", args), 201);
  });
}
