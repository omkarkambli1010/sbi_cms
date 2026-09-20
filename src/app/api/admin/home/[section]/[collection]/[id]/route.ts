import { NotFoundError, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { buildArgs } from "@/server/cms/collectionArgs";
import { resolveCollection } from "@/server/cms/registry";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ section: string; collection: string; id: string }>;
}

async function collectionFor(params: Params["params"]) {
  const { section, collection, id } = await params;
  const def = resolveCollection(section, collection);

  if (!def) throw new NotFoundError(`No such collection: ${section}/${collection}.`);

  return { def, id: parseId(id) };
}

export async function GET(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { def, id } = await collectionFor(params);
    const row = await callFunctionOne(`cms.${def.fnPrefix}_get`, [id]);

    if (!row) throw new NotFoundError();

    return ok(row);
  });
}

export async function PUT(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { def, id } = await collectionFor(params);
    const args = buildArgs(def, await readJson(request), "update");

    return ok(await callFunctionOne(`cms.${def.fnPrefix}_update`, [id, ...args]));
  });
}

export async function DELETE(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { def, id } = await collectionFor(params);

    const deleted = await callFunctionOne<Record<string, boolean>>(
      `cms.${def.fnPrefix}_delete`,
      [id],
    );

    /* The delete functions return a plain boolean, so the column takes the
       function's own name. Reading the single value rather than the key keeps
       this handler independent of that. */
    const value = deleted ? Object.values(deleted)[0] : false;

    if (!value) throw new NotFoundError("That row no longer exists.");

    return ok({ deleted: true });
  });
}
