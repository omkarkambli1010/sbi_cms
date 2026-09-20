import { FieldReader, NotFoundError, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { resolveCollection } from "@/server/cms/registry";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ section: string; collection: string; id: string }>;
}

/** The publication switch. `is_active` is the only publication control there
 *  is — there is no draft state — so this is how a row leaves the page. */
export async function PATCH(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section, collection, id } = await params;
    const def = resolveCollection(section, collection);

    if (!def) throw new NotFoundError(`No such collection: ${section}/${collection}.`);

    const reader = new FieldReader(await readJson(request));
    const isActive = reader.boolean("is_active");
    reader.done();

    return ok(await callFunctionOne(`cms.${def.fnPrefix}_set_active`, [parseId(id), isActive]));
  });
}
