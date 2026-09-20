import { ok, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction } from "@/server/db/pool";

/** Every menu, so the Navigation screen can offer them in a picker. */
export async function GET() {
  return route(async () => {
    await requireUser();
    return ok(await callFunction("cms.nav_menu_list"));
  });
}
