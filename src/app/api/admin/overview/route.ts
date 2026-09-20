import { ok, route } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction, pingDatabase } from "@/server/db/pool";

interface CountRow {
  label: string;
  total: string;
  inactive: string;
}

export async function GET() {
  return route(async () => {
    const user = await requireUser();

    /* The health check runs first and its result is reported rather than
       thrown: an Overview that says "database unreachable" is more useful
       than one that 500s and tells the editor nothing. */
    const healthy = await pingDatabase();

    const counts = healthy
      ? (await callFunction<CountRow>("cms.overview_counts")).map((row) => ({
          label: row.label,
          total: Number(row.total),
          inactive: Number(row.inactive),
        }))
      : [];

    return ok({
      user: { fullName: user.fullName, username: user.username, role: user.role },
      database: { healthy },
      counts,
    });
  });
}
