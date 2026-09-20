import { NotFoundError, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { buildArgs, resolveParentId } from "@/server/cms/collectionArgs";
import { resolveCollection } from "@/server/cms/registry";
import { callFunction, callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ section: string; collection: string }>;
}

/**
 * List and create, for every ordered list in the CMS.
 *
 * One handler serves twenty-odd collections because they all expose the same
 * operations under the same names. What differs — the function prefix, the
 * parent, the argument order — is data in the registry, not code here.
 */
export async function GET(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section, collection } = await params;
    const def = resolveCollection(section, collection);

    if (!def) throw new NotFoundError(`No such collection: ${section}/${collection}.`);

    const url = new URL(request.url);
    const onlyActive = url.searchParams.get("active") === "true";
    const parentId = await resolveParentId(def, section, url.searchParams.get("parent"));

    const args = parentId === null ? [onlyActive] : [parentId, onlyActive];

    return ok({
      collection: { key: def.key, label: def.label, parent: def.parent, fields: def.fields },
      parentId,
      items: await callFunction(`cms.${def.fnPrefix}_list`, args),
    });
  });
}

export async function POST(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section, collection } = await params;
    const def = resolveCollection(section, collection);

    if (!def) throw new NotFoundError(`No such collection: ${section}/${collection}.`);

    const body = await readJson(request);
    const url = new URL(request.url);
    const parentId = await resolveParentId(def, section, url.searchParams.get("parent"));

    const args = buildArgs(def, body, "create");

    return ok(
      await callFunctionOne(
        `cms.${def.fnPrefix}_create`,
        parentId === null ? args : [parentId, ...args],
      ),
      201,
    );
  });
}
