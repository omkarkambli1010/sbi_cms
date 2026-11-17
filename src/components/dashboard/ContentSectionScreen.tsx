"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { ErrorState, Skeleton } from "@/components/ui/States";
import { api, ApiError } from "@/lib/apiClient";
import type { CollectionDef } from "@/server/cms/registry";
import type { ContentCollection, ContentSection } from "@/server/cms/pages";

import BlockForm from "./BlockForm";
import CollectionPanel from "./CollectionPanel";
import styles from "./section.module.css";

/**
 * A section of an inner page (About, Leadership, Sector).
 *
 * The same screen shape as a home fold — a Section tab, then one tab per list —
 * driven by pages.ts instead of registry.ts. Rows come back flat from the API,
 * so the generic CollectionPanel and BlockForm do all the work; what this adds
 * is only the mapping from a ContentCollection to the CollectionDef they read.
 */

interface Props {
  page: string;
  pageLabel: string;
  section: ContentSection;
}

interface Payload {
  block: Record<string, unknown>;
}

/** CollectionPanel reads a CollectionDef; the routine fields are unused here
 *  because the content routes validate against the registry, not an arg list. */
function asDef(collection: ContentCollection): CollectionDef {
  return {
    key: collection.key,
    label: collection.label,
    fnPrefix: "content_item",
    parent: "section",
    fields: collection.fields,
    createArgs: [],
    updateArgs: [],
  };
}

export default function ContentSectionScreen({ page, pageLabel, section }: Props) {
  const hasBlock = section.block.length > 0;
  const tabs = [
    ...(hasBlock ? [{ key: "section", label: "Section" }] : []),
    ...section.collections.map((c) => ({ key: c.key, label: c.label })),
  ];

  const [tab, setTab] = useState(tabs[0]?.key ?? "section");
  const [data, setData] = useState<Payload | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    if (!hasBlock) return;
    let cancelled = false;

    api
      .get<Payload>(`/api/admin/pages/${page}/${section.key}`)
      .then((payload) => {
        if (!cancelled) setData(payload);
      })
      .catch((error) => {
        if (!cancelled) {
          setFailure(error instanceof ApiError ? error.message : "Could not load this section.");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [hasBlock, page, section.key, reload]);

  const active = tabs.find((candidate) => candidate.key === tab) ?? tabs[0];
  const collection = section.collections.find((c) => c.key === active?.key);

  return (
    <>
      <header className={styles.head}>
        <div className={styles.headText}>
          <p className={styles.trail}>
            <Link href={`/dashboard/pages/${page}`}>{pageLabel}</Link>
          </p>
          <h1>{section.label}</h1>
        </div>
      </header>

      {tabs.length > 1 ? (
        <nav className={styles.tabs} aria-label={`${section.label} sections`}>
          {tabs.map((candidate) => (
            <button
              key={candidate.key}
              type="button"
              className={`${styles.tab} ${candidate.key === active.key ? styles.tabActive : ""}`}
              aria-current={candidate.key === active.key ? "true" : undefined}
              onClick={() => setTab(candidate.key)}
            >
              {candidate.label}
            </button>
          ))}
        </nav>
      ) : null}

      {failure ? <ErrorState message={failure} onRetry={() => setReload((n) => n + 1)} /> : null}

      <div key={active?.key} className={styles.panelEnter}>
        {collection ? (
          <CollectionPanel page={page} section={section.key} def={asDef(collection)} />
        ) : data === null && !failure ? (
          <Skeleton rows={6} />
        ) : data ? (
          <BlockForm
            endpoint={`/api/admin/pages/${page}/${section.key}`}
            fields={section.block}
            initial={data.block}
            note="Leave a field blank and the page falls back to its built-in text for that field."
          />
        ) : null}
      </div>
    </>
  );
}
