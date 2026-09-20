import "server-only";

import { randomUUID } from "node:crypto";
import { mkdir, unlink, writeFile } from "node:fs/promises";
import path from "node:path";

import { ValidationError } from "@/server/api/respond";

/**
 * Where uploads land, and what an upload is allowed to be.
 *
 * The rule that matters: the name a browser sends is never used as a path.
 * It is kept as `file_name` metadata so the library can show what an editor
 * uploaded, and the bytes are written under a name this module generates. A
 * filename of `../../.env` is then just an unusual label rather than a write
 * outside the media directory.
 */

const DEFAULT_MAX_BYTES = 5 * 1024 * 1024;

/** Types the marketing site actually renders. SVG is included deliberately —
 *  the existing artwork is SVG — and is served from the same origin as the
 *  dashboard, so uploads are restricted to signed-in administrators. */
const ALLOWED: Record<string, string> = {
  "image/png": ".png",
  "image/jpeg": ".jpg",
  "image/webp": ".webp",
  "image/gif": ".gif",
  "image/svg+xml": ".svg",
  "image/avif": ".avif",
};

export interface StoredFile {
  /** Public path, e.g. `/uploads/2026/09/7f3c….png`. */
  url: string;
  /** Absolute path on disk, for cleanup when the database write fails. */
  absolutePath: string;
  byteSize: number;
  mimeType: string;
}

export function maxUploadBytes(): number {
  const raw = Number(process.env.CMS_MEDIA_MAX_BYTES);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_MAX_BYTES;
}

function mediaDir(): string {
  return path.resolve(process.env.CMS_MEDIA_DIR?.trim() || "./public/uploads");
}

function publicPrefix(): string {
  const raw = process.env.CMS_MEDIA_PUBLIC_PATH?.trim() || "/uploads";
  return raw.endsWith("/") ? raw.slice(0, -1) : raw;
}

export async function storeUpload(file: File): Promise<StoredFile> {
  const extension = ALLOWED[file.type];

  if (!extension) {
    throw new ValidationError(
      { file: "Unsupported file type." },
      `Upload a PNG, JPEG, WebP, GIF, AVIF or SVG. That file is ${file.type || "of unknown type"}.`,
    );
  }

  if (file.size <= 0) {
    throw new ValidationError({ file: "That file is empty." });
  }

  const limit = maxUploadBytes();

  if (file.size > limit) {
    throw new ValidationError(
      { file: `Too large. The limit is ${Math.round(limit / 1024 / 1024)}MB.` },
    );
  }

  /* Dated folders keep one directory from growing to tens of thousands of
     entries, which several filesystems handle poorly and every `ls` handles
     slowly. */
  const now = new Date();
  const folder = `${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
  const name = `${randomUUID()}${extension}`;

  const directory = path.join(mediaDir(), folder);
  await mkdir(directory, { recursive: true });

  const absolutePath = path.join(directory, name);
  await writeFile(absolutePath, Buffer.from(await file.arrayBuffer()));

  return {
    url: `${publicPrefix()}/${folder}/${name}`,
    absolutePath,
    byteSize: file.size,
    mimeType: file.type,
  };
}

/** Removes a file written moments ago when the database row could not be made. */
export async function discardUpload(absolutePath: string): Promise<void> {
  try {
    await unlink(absolutePath);
  } catch {
    /* Already gone, or never written. Either way there is nothing to undo and
       failing the request over it would report the wrong problem. */
  }
}
