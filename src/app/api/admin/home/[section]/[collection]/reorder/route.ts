import { FieldReader, NotFoundError, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { resolveParentId } from "@/server/cms/collectionArgs";
import { resolveCollection } from "@/server/cms/registry";
import { callFunction } from "@/server/db/pool";

interface Params {
  params: Promise<{ section: string; collection: string }>;
}

export async function POST(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section, collection } = await params;
    const def = resolveCollection(section, collection);

    if (!def) throw new NotFoundError(`No such collection: ${section}/${collection}.`);

    const url = new URL(request.url);
    const parentId = await resolveParentId(def, section, url.searchParams.get("parent"));

    const reader = new FieldReader(await readJson(request));
    const ids = reader.idList("ids");
    reader.done();

    /* The stored function rejects an id set that is not exactly the parent's
       current one. A dashboard that has drifted therefore fails the whole
       reorder rather than renumbering the rows it still knows about and
       leaving the rest behind. */
    return ok(
      await callFunction(
        `cms.${def.fnPrefix}_reorder`,
        parentId === null ? [ids] : [parentId, ids],
      ),
    );
  });
}
