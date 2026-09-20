import { FieldReader, NotFoundError, ok, parseId, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ id: string }>;
}

export async function GET(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const row = await callFunctionOne("cms.nav_item_get", [parseId((await params).id)]);
    if (!row) throw new NotFoundError();

    return ok(row);
  });
}

export async function PUT(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const id = parseId((await params).id);
    const reader = new FieldReader(await readJson(request));

    const args = [
      id,
      reader.string("label", { required: true, max: 200 }),
      reader.href("href") || "#",
      reader.id("icon_media_id"),
      reader.boolean("opens_in_new_tab"),
    ];

    reader.done();

    return ok(await callFunctionOne("cms.nav_item_update", args));
  });
}

export async function DELETE(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    /* Children go with the parent: navigation_items cascades on parent_id, so
       removing a footer heading removes its links rather than leaving them
       orphaned at the top level of the menu. */
    const deleted = await callFunctionOne<{ nav_item_delete: boolean }>("cms.nav_item_delete", [
      parseId((await params).id),
    ]);

    if (!deleted?.nav_item_delete) throw new NotFoundError("That link no longer exists.");

    return ok({ deleted: true });
  });
}
