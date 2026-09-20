import { FieldReader, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ id: string }>;
}

export async function PATCH(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);
    const reader = new FieldReader(await readJson(request));
    const isActive = reader.boolean("is_active");
    reader.done();

    return ok(await callFunctionOne("cms.nav_item_set_active", [id, isActive]));
  });
}
