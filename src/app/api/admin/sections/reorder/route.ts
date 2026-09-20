import { FieldReader, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction } from "@/server/db/pool";

export async function POST(request: Request) {
  return route(async () => {
    await requireUser();

    const body = await readJson(request);
    const reader = new FieldReader(body);

    const page = reader.string("page") || "home";
    const ids = reader.idList("ids");
    reader.done();

    /* cms.section_reorder rejects a list that is not exactly this page's ids,
       so a dashboard holding a stale list fails loudly instead of renumbering
       half the page. */
    return ok(await callFunction("cms.section_reorder", [page, ids]));
  });
}
