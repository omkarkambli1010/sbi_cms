import { FieldReader, NotFoundError, ok, readJson, route } from "@/server/api/respond";
import { requireAdmin, requireUser } from "@/server/auth/session";
import { callFunctionOne } from "@/server/db/pool";

export async function GET() {
  return route(async () => {
    await requireUser();

    const row = await callFunctionOne("cms.site_settings_get");
    if (!row) throw new NotFoundError("Site settings have not been seeded yet.");

    return ok(row);
  });
}

export async function PUT(request: Request) {
  return route(async () => {
    await requireAdmin();

    const reader = new FieldReader(await readJson(request));

    const args = [
      reader.string("brand_name", { required: true, max: 120 }),
      reader.string("legal_name", { required: true, max: 200 }),
      reader.string("address", { max: 500 }),
      reader.string("phone", { max: 120 }),
      reader.string("email", { max: 200 }),
      reader.string("search_placeholder", { max: 200 }),
      reader.id("logo_media_id"),
      reader.id("footer_logo_media_id"),
      reader.string("connect_label", { max: 120 }),
      reader.string("stocks_heading", { max: 120 }),
    ];

    reader.done();

    return ok(await callFunctionOne("cms.site_settings_update", args));
  });
}
