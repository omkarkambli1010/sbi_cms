import { FieldReader, NotFoundError, ok, readJson, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { resolveSection } from "@/server/cms/registry";
import { callFunctionOne } from "@/server/db/pool";

interface Params {
  params: Promise<{ section: string }>;
}

/**
 * The shell of one fold — `section_blocks`, plus the singleton table where the
 * fold has one (the hero, the sticky nudge).
 *
 * `[section]` is a registry key, never SQL. An unknown key is a 404 here,
 * before any database call.
 */
export async function GET(_request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section } = await params;
    const def = resolveSection(section);

    if (!def) throw new NotFoundError(`No such section: ${section}.`);

    const block = def.hasBlock
      ? await callFunctionOne("cms.section_block_get", ["home", section])
      : null;

    const singleton =
      def.singleton === "hero"
        ? await callFunctionOne("cms.hero_get", ["home"])
        : def.singleton === "sticky-nudge"
          ? await callFunctionOne("cms.sticky_nudge_get", ["home", section])
          : null;

    return ok({
      key: def.key,
      label: def.label,
      hasBlock: def.hasBlock,
      singletonKind: def.singleton ?? null,
      collections: def.collections.map((c) => ({
        key: c.key,
        label: c.label,
        parent: c.parent,
        fields: c.fields,
      })),
      block,
      singleton,
    });
  });
}

export async function PUT(request: Request, { params }: Params) {
  return route(async () => {
    await requireUser();

    const { section } = await params;
    const def = resolveSection(section);

    if (!def) throw new NotFoundError(`No such section: ${section}.`);

    const body = await readJson(request);
    const reader = new FieldReader(body);

    if (def.singleton === "hero") {
      const args = [
        reader.id("id", { required: true }),
        reader.string("title_lead", { max: 200 }),
        reader.string("subtext_line_1", { max: 300 }),
        reader.string("subtext_line_2", { max: 300 }),
        reader.string("watermark_left", { max: 60 }),
        reader.string("watermark_right", { max: 60 }),
        reader.id("mockup_media_id"),
        reader.string("form_name_label", { max: 120 }),
        reader.string("form_name_placeholder", { max: 200 }),
        reader.string("form_mobile_label", { max: 120 }),
        reader.string("form_mobile_placeholder", { max: 200 }),
        reader.string("form_mobile_help", { max: 300 }),
        reader.string("form_consent_label", { max: 300 }),
        reader.string("form_submit_label", { max: 120 }),
        reader.string("form_name_label_mobile", { max: 120 }),
        reader.string("form_name_placeholder_mobile", { max: 200 }),
        reader.string("form_mobile_label_mobile", { max: 120 }),
        reader.string("form_mobile_placeholder_mobile", { max: 200 }),
      ];

      reader.done();
      return ok(await callFunctionOne("cms.hero_update", args));
    }

    if (def.singleton === "sticky-nudge") {
      const args = [
        "home",
        reader.string("title", { max: 200 }),
        reader.string("mobile_placeholder", { max: 200 }),
        reader.string("name_placeholder", { max: 200 }),
        reader.string("cta_label", { max: 120 }),
        reader.href("cta_href") || null,
        section,
      ];

      reader.done();
      return ok(await callFunctionOne("cms.sticky_nudge_update", args));
    }

    if (!def.hasBlock) {
      throw new NotFoundError(`Section ${section} has no editable shell.`);
    }

    const args = [
      "home",
      section,
      reader.string("eyebrow", { max: 120 }),
      reader.string("title", { max: 300 }),
      reader.stringList("title_lines", { max: 8 }),
      reader.string("subtitle", { max: 500 }),
      reader.string("subtitle_mobile", { max: 500 }),
      reader.string("description", { max: 2000 }),
      reader.id("title_break_after"),
      reader.id("subtitle_break_after"),
      reader.string("align") || "start",
      reader.string("tone") || "light",
      reader.string("cta_label", { max: 120 }),
      reader.string("cta_label_mobile", { max: 120 }),
      reader.href("cta_href") || null,
      reader.boolean("cta_visible", true),
      reader.string("secondary_cta_label", { max: 120 }),
      reader.href("secondary_cta_href") || null,
      reader.boolean("secondary_cta_visible", false),
      reader.href("arrow_href") || null,
      reader.string("arrow_label", { max: 120 }),
      reader.id("image_media_id"),
      reader.id("image_mobile_media_id"),
      reader.id("background_media_id"),
      reader.id("background_mobile_media_id"),
      reader.string("background_color", { max: 7 }),
    ];

    reader.done();

    return ok(await callFunctionOne("cms.section_block_update", args));
  });
}
