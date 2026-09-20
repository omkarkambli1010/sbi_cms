import { ok, route, ValidationError } from "@/server/api/respond";
import { requireUser } from "@/server/auth/session";
import { callFunction, callFunctionOne } from "@/server/db/pool";
import { discardUpload, storeUpload } from "@/server/media/storage";

interface MediaRow {
  id: string;
  total_count: string;
}

export async function GET(request: Request) {
  return route(async () => {
    await requireUser();

    const url = new URL(request.url);
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 50), 1), 200);
    const offset = Math.max(Number(url.searchParams.get("offset") ?? 0), 0);

    const rows = await callFunction<MediaRow>("cms.media_list", [
      url.searchParams.get("search"),
      url.searchParams.get("folder"),
      url.searchParams.get("active") === "true",
      limit,
      offset,
    ]);

    /* total_count rides along on every row from the window function; it is
       the same value on each, so it is lifted out rather than repeated. */
    const total = rows.length > 0 ? Number(rows[0].total_count) : 0;

    return ok({
      items: rows.map((row) => {
        const { total_count, ...rest } = row;
        void total_count;
        return rest;
      }),
      total,
      limit,
      offset,
    });
  });
}

export async function POST(request: Request) {
  return route(async () => {
    const user = await requireUser();

    const contentType = request.headers.get("content-type") ?? "";

    if (!contentType.includes("multipart/form-data")) {
      throw new ValidationError({}, "Send the file as multipart/form-data.");
    }

    const form = await request.formData();
    const file = form.get("file");

    if (!(file instanceof File)) {
      throw new ValidationError({ file: "No file was attached." });
    }

    const stored = await storeUpload(file);

    try {
      const row = await callFunctionOne("cms.media_create", [
        stored.url,
        /* The browser's name, kept as a label only. Never a path — see
           storage.ts, which generates the name the bytes are written under. */
        file.name.slice(0, 255),
        stored.mimeType,
        String(form.get("alt_text") ?? "").slice(0, 500),
        (String(form.get("title") ?? "").slice(0, 200) || null),
        stored.byteSize,
        null,
        null,
        String(form.get("folder") ?? "general").slice(0, 60),
        user.id,
      ]);

      return ok(row, 201);
    } catch (error) {
      /* The row is the record of truth; a file with no row is litter nobody
         can see or delete from the dashboard. */
      await discardUpload(stored.absolutePath);
      throw error;
    }
  });
}
