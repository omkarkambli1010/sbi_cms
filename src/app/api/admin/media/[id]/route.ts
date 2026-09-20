import { FieldReader, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction, callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ id: string }>;
}

export async function GET(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);

    return ok({
      asset: await callFunctionOne("cms.media_get", [id]),
      /* Shown next to the delete button, so the refusal is explained before
         it happens rather than after. */
      usage: await callFunction("cms.media_usage", [id]),
    });
  });
}

export async function PUT(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);
    const reader = new FieldReader(await readJson(request));

    const args = [
      id,
      reader.string("alt_text", { max: 500 }),
      reader.string("title", { max: 200 }) || null,
      reader.string("folder", { max: 60 }),
    ];

    reader.done();

    return ok(await callFunctionOne("cms.media_update", args));
  });
}

export async function DELETE(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);

    /* The row goes; the file on disk stays. Deleting bytes that a cached page,
       a CDN or an external site may still reference is not reversible, and an
       orphaned file costs a few kilobytes. */
    const deleted = await callFunctionOne<{ media_delete: boolean }>("cms.media_delete", [id]);

    return ok({ deleted: Boolean(deleted?.media_delete) });
  });
}
