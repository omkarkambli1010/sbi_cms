import { ok, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { SECTIONS } from "@/server/cms/registry";
import { callFunction } from "@/server/db/pool";

interface SectionRow {
  id: string;
  section_key: string;
  name: string;
  display_order: number;
  is_active: boolean;
  updated_at: string;
}

/**
 * The home hub's list.
 *
 * Rows come from the database, but whether a fold has a dashboard screen —
 * and what that screen is called — comes from the registry. A `page_sections`
 * row with no registry entry is reported with `screen: false` rather than
 * linked to a 404.
 */
export async function GET(request: Request) {
  return route(async () => {
    await requireUser();

    const page = new URL(request.url).searchParams.get("page") ?? "home";
    const rows = await callFunction<SectionRow>("cms.section_list_by_page", [page]);

    return ok(
      rows.map((row) => {
        const def = SECTIONS[row.section_key];

        return {
          id: Number(row.id),
          key: row.section_key,
          name: row.name,
          label: def?.label ?? row.name,
          order: row.display_order,
          isActive: row.is_active,
          updatedAt: row.updated_at,
          screen: Boolean(def),
          collections: def?.collections.map((c) => ({ key: c.key, label: c.label })) ?? [],
        };
      }),
    );
  });
}
