import { FieldReader, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction } from "@/server/db/pool";

interface Params {
  params: Promise<{ menuKey: string }>;
}

export async function POST(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { menuKey } = await params;

    /* Ordering is per level. Without ?parent the call means the top level,
       which is what the stored function's NULL default already says. */
    const raw = new URL(request.url).searchParams.get("parent");
    const parentId = raw === null || raw === "" ? null : Number(raw);

    const reader = new FieldReader(await readJson(request));
    const ids = reader.idList("ids");
    reader.done();

    return ok(await callFunction("cms.nav_item_reorder", [menuKey, ids, parentId]));
  });
}
