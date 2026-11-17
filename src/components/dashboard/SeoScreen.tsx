"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { ErrorState, Skeleton } from "@/components/ui/States";
import { api, ApiError } from "@/lib/apiClient";
import type { FieldDef } from "@/server/cms/registry";

import BlockForm from "./BlockForm";
import styles from "./section.module.css";

/**
 * A page's SEO: the fields the public site turns into its <title>, meta tags,
 * canonical link and Open Graph card. Saved through /api/admin/seo/<slug>, which
 * every page already had; it simply had no screen.
 */

const SEO_FIELDS: readonly FieldDef[] = [
  { name: "meta_title", label: "Page title", kind: "text", max: 200, help: "Shown in the browser tab and search results." },
  { name: "meta_description", label: "Description", kind: "textarea", max: 500 },
  { name: "meta_keywords", label: "Keywords", kind: "lines", help: "One keyword or phrase per line." },
  { name: "canonical_url", label: "Canonical URL", kind: "text", max: 500, help: "The preferred address for this page, e.g. https://www.sbisecurities.in/about." },
  { name: "og_title", label: "Social title", kind: "text", max: 200, help: "Falls back to the page title." },
  { name: "og_description", label: "Social description", kind: "textarea", max: 500 },
  { name: "og_image_media_id", label: "Social image", kind: "media" },
  { name: "robots", label: "Robots", kind: "select", options: ["index,follow", "noindex,follow", "index,nofollow", "noindex,nofollow"] },
];

export default function SeoScreen({ slug, pageLabel }: { slug: string; pageLabel: string }) {
  const [data, setData] = useState<Record<string, unknown> | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let cancelled = false;
    api
      .get<Record<string, unknown>>(`/api/admin/seo/${slug}`)
      .then((row) => {
        if (!cancelled) setData(row);
      })
      .catch((error) => {
        if (!cancelled) {
          setFailure(error instanceof ApiError ? error.message : "Could not load the SEO details.");
        }
      });
    return () => {
      cancelled = true;
    };
  }, [slug, reload]);

  return (
    <>
      <header className={styles.head}>
        <div className={styles.headText}>
          <p className={styles.trail}>
            <Link href={`/dashboard/pages/${slug}`}>{pageLabel}</Link>
          </p>
          <h1>SEO</h1>
        </div>
      </header>

      {failure ? <ErrorState message={failure} onRetry={() => setReload((n) => n + 1)} /> : null}
      {data === null && !failure ? <Skeleton rows={6} /> : null}
      {data ? (
        <BlockForm
          endpoint={`/api/admin/seo/${slug}`}
          fields={SEO_FIELDS}
          initial={data}
          note="Leave a field blank and the page falls back to its built-in value."
        />
      ) : null}
    </>
  );
}
