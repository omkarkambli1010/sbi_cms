import { FieldReader, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ id: string }>;
}

/** Enable or disable one fold. PATCH because it changes one flag, not the row. */
export async function PATCH(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);
    const body = await readJson(request);
    const reader = new FieldReader(body);

    if (!("is_active" in body)) {
      reader.string("is_active", { required: true });
    }

    const isActive = reader.boolean("is_active");
    reader.done();

    return ok(await callFunctionOne("cms.section_set_active", [id, isActive]));
  });
}
