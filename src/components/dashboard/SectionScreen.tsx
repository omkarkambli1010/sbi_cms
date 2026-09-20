"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { ErrorState, Skeleton } from "@/components/ui/States";
import { api, ApiError } from "@/lib/apiClient";
import {
  BLOCK_FIELDS,
  HERO_FIELDS,
  STICKY_FIELDS,
  type CollectionDef,
  type SectionDef,
} from "@/server/cms/registry";

import BlockForm from "./BlockForm";
import CollectionPanel, { PARENT_SOURCE, type Row } from "./CollectionPanel";
import styles from "./section.module.css";

/**
 * One fold's screen: a Section tab plus one tab per ordered list it owns.
 *
 * Split into tabs rather than run as one page because Platform, Pricing and
 * Purpose each own two lists on top of their shell, and a single form would
 * be several screens long before an editor reached the rows they came for.
 */

interface SectionScreenProps {
  def: SectionDef;
}

interface SectionPayload {
  block: Record<string, unknown> | null;
  singleton: Record<string, unknown> | null;
}

export default function SectionScreen({ def }: SectionScreenProps) {
  const tabs = [{ key: "section", label: "Section" }, ...def.collections];

  const [tab, setTab] = useState(tabs[0].key);
  const [data, setData] = useState<SectionPayload | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let cancelled = false;

    api
      .get<SectionPayload>(`/api/admin/home/${def.key}`)
      .then((payload) => {
        if (!cancelled) setData(payload);
      })
      .catch((error) => {
        if (!cancelled) {
          setFailure(
            error instanceof ApiError ? error.message : "Could not load this section.",
          );
        }
      });

    return () => {
      cancelled = true;
    };
  }, [def.key, reload]);

  const active = tabs.find((candidate) => candidate.key === tab) ?? tabs[0];

  return (
    <>
      <header className={styles.head}>
        <div className={styles.headText}>
          <p className={styles.trail}>
            <Link href="/dashboard/home">Home page</Link>
          </p>
          <h1>{def.label}</h1>
        </div>
      </header>

      <nav className={styles.tabs} aria-label={`${def.label} sections`}>
        {tabs.map((candidate) => (
          <button
            key={candidate.key}
            type="button"
            className={`${styles.tab} ${candidate.key === tab ? styles.tabActive : ""}`}
            aria-current={candidate.key === tab ? "true" : undefined}
            onClick={() => setTab(candidate.key)}
          >
            {candidate.label}
          </button>
        ))}
      </nav>

      {failure ? <ErrorState message={failure} onRetry={() => setReload((n) => n + 1)} /> : null}

      {/* Keyed on the tab, so React remounts it and the entrance animation
          runs on each switch rather than only the first. */}
      <div key={active.key} className={styles.panelEnter}>
        {active.key === "section" ? (
          data === null && !failure ? (
            <Skeleton rows={6} />
          ) : (
            <ShellForm def={def} data={data} />
          )
        ) : (
          <CollectionTab section={def.key} def={active as CollectionDef} />
        )}
      </div>
    </>
  );
}

function ShellForm({ def, data }: { def: SectionDef; data: SectionPayload | null }) {
  if (def.singleton === "hero") {
    const hero = data?.singleton;

    if (!hero) {
      return (
        <ErrorState message="The home page has no hero row yet. Run the seed to create it." />
      );
    }

    return (
      <BlockForm
        endpoint={`/api/admin/home/${def.key}`}
        fields={HERO_FIELDS}
        initial={hero}
        hidden={{ id: hero.id }}
        note="The rotating claim and the KPI tiles are on their own tabs — this is everything around them."
      />
    );
  }

  if (def.singleton === "sticky-nudge") {
    return (
      <BlockForm
        endpoint={`/api/admin/home/${def.key}`}
        fields={STICKY_FIELDS}
        initial={data?.singleton ?? {}}
        note="The bar that follows the reader down the page."
      />
    );
  }

  return (
    <BlockForm
      endpoint={`/api/admin/home/${def.key}`}
      fields={BLOCK_FIELDS}
      initial={data?.block ?? {}}
      note="Leave a field blank and the page renders nothing in its place."
    />
  );
}

/**
 * A collection whose rows hang off a tab, a card or a plan needs to know
 * which one before it can list anything, so the chooser is filled from the
 * sibling collection the registry names as its parent.
 */
function CollectionTab({ section, def }: { section: string; def: CollectionDef }) {
  const sourceKey = PARENT_SOURCE[def.parent];
  const [parents, setParents] = useState<{ id: number; label: string }[] | null>(null);

  useEffect(() => {
    if (!sourceKey) return;

    let cancelled = false;

    api
      .get<{ items: Row[] }>(`/api/admin/home/${section}/${sourceKey}`)
      .then((payload) => {
        if (cancelled) return;

        setParents(
          payload.items.map((row) => ({
            id: Number(row.id),
            label:
              [row.label, row.title, row.name, row.tab_key, row.slug].find(
                (value) => typeof value === "string" && value.trim(),
              ) as string | undefined ?? `#${row.id}`,
          })),
        );
      })
      .catch(() => {
        if (!cancelled) setParents([]);
      });

    return () => {
      cancelled = true;
    };
  }, [section, sourceKey]);

  if (!sourceKey) {
    return <CollectionPanel section={section} def={def} />;
  }

  if (parents === null) return <Skeleton rows={3} />;

  return (
    <CollectionPanel
      section={section}
      def={def}
      parents={parents}
      parentLabel={def.parent === "tab" ? "Tab" : def.parent === "card" ? "Card" : "Plan"}
    />
  );
}
