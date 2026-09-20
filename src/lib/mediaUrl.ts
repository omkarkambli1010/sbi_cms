/**
 * Where a media file can actually be fetched from, for previewing.
 *
 * The CMS does not own the bytes of the existing artwork: `/figma/header/
 * logo-main.svg` and the rest are served out of the marketing site's public
 * folder, and the seed registers those paths rather than copying the files.
 * That is deliberate — it means switching the site to the CMS does not move
 * a single asset — but it leaves the dashboard, on a different port, unable
 * to render a preview from a root-relative path.
 *
 * NEXT_PUBLIC_MEDIA_ORIGIN says where those root-relative paths resolve.
 * Uploads through the dashboard are served by the CMS itself and are left
 * alone: they already resolve here.
 */

const UPLOADS_PREFIX = process.env.NEXT_PUBLIC_MEDIA_PUBLIC_PATH || "/uploads";

export function previewUrl(url: string): string {
  if (!url) return url;

  /* Absolute already, or a data URI: nothing to resolve. */
  if (/^[a-z]+:/i.test(url) || url.startsWith("//")) return url;

  /* This app's own uploads. */
  if (url.startsWith(UPLOADS_PREFIX)) return url;

  const origin = process.env.NEXT_PUBLIC_MEDIA_ORIGIN?.replace(/\/$/, "");
  if (!origin) return url;

  return `${origin}${url.startsWith("/") ? "" : "/"}${url}`;
}
