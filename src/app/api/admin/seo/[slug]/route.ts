import { FieldReader, NotFoundError, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ slug: string }>;
}

export async function GET(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { slug } = await params;
    const row = await callFunctionOne("cms.seo_get_by_page", [slug]);

    if (!row) throw new NotFoundError(`No SEO metadata for page "${slug}".`);

    return ok(row);
  });
}

export async function PUT(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { slug } = await params;
    const reader = new FieldReader(await readJson(request));

    const args = [
      slug,
      reader.string("meta_title", { max: 200 }),
      reader.string("meta_description", { max: 500 }),
      reader.stringList("meta_keywords", { max: 40 }),
      reader.string("canonical_url", { max: 500 }) || null,
      reader.string("og_title", { max: 200 }) || null,
      reader.string("og_description", { max: 500 }) || null,
      reader.id("og_image_media_id"),
      reader.string("robots", { max: 100 }) || "index,follow",
    ];

    reader.done();

    /* seo_upsert raises no_data_found for an unknown page, which respond.ts
       maps to 404 — so an invented slug cannot quietly create metadata that
       belongs to nothing. */
    return ok(await callFunctionOne("cms.seo_upsert", args));
  });
}
