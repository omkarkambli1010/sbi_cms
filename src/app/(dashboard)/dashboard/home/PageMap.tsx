"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";

import { ErrorState, Skeleton } from "@/components/ui/States";
import { useToast } from "@/components/ui/Toast";
import { useReorder } from "@/components/ui/useReorder";
import { api, ApiError } from "@/lib/apiClient";

import styles from "./home.module.css";

/**
 * The home page, as an outline.
 *
 * This is the one screen in the dashboard that is not a table of rows. It is
 * a map of the page itself: fifteen folds in the order a visitor meets them,
 * each showing where it sits, whether it is showing, and what it is called.
 * An editor who knows the page can find the fold they mean without knowing
 * anything about the database underneath it.
 *
 * Header, Footer, Statistics and SEO are deliberately absent. Header and
 * Footer are chrome on every marketing route, SEO is page metadata, and
 * Statistics reads across sections — none of them is a position on this page,
 * so putting them in a list you can drag would imply they could move.
 */

interface SectionRow {
  id: number;
  key: string;
  label: string;
  name: string;
  order: number;
  isActive: boolean;
  screen: boolean;
  collections: { key: string; label: string }[];
}

export default function PageMap() {
  const toast = useToast();

  const [rows, setRows] = useState<SectionRow[] | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  const [version, setVersion] = useState(0);
  const refresh = useCallback(() => setVersion((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;

    api
      .get<SectionRow[]>("/api/admin/sections?page=home")
      .then((sections) => {
        if (cancelled) return;
        setRows(sections);
        setFailure(null);
      })
      .catch((error) => {
        if (cancelled) return;
        setRows([]);
        setFailure(
          error instanceof ApiError ? error.message : "Could not load the page's sections.",
        );
      });

    return () => {
      cancelled = true;
    };
  }, [version]);

  const byId = useMemo(() => new Map((rows ?? []).map((row) => [row.id, row])), [rows]);

  const commit = useCallback(
    async (ids: number[]) => {
      try {
        await api.post("/api/admin/sections/reorder", { page: "home", ids });
        toast.success("Page order saved");
      } catch (error) {
        toast.error(
          error instanceof ApiError ? error.message : "The new order could not be saved.",
        );
      } finally {
        /* Refetch either way: on success for the renumbering, on failure to
           put the list back the way the database has it. */
        refresh();
      }
    },
    [toast, refresh],
  );

  const reorder = useReorder(
    (rows ?? []).map((row) => row.id),
    commit,
    (id) => byId.get(id)?.label ?? "section",
  );

  async function toggle(row: SectionRow) {
    setBusyId(row.id);

    try {
      await api.patch(`/api/admin/sections/${row.id}`, { is_active: !row.isActive });
      toast.success(row.isActive ? `${row.label} hidden` : `${row.label} showing`);
      refresh();
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "That change was not saved.");
    } finally {
      setBusyId(null);
    }
  }

  if (rows === null) return <Skeleton rows={8} />;

  return (
    <>
      {failure ? <ErrorState message={failure} onRetry={refresh} /> : null}

      <ol className={styles.map} data-reorder-list>
        {reorder.order.map((id, index) => {
          const row = byId.get(id);
          if (!row) return null;

          return (
            <li
              key={id}
              className={`${styles.fold} ${row.isActive ? "" : styles.foldOff}`}
              {...reorder.rowProps(id)}
            >
              <span
                className={styles.handle}
                {...reorder.handleProps(id)}
                aria-disabled={reorder.saving || undefined}
              />

              <span className={styles.position} aria-hidden="true">
                {index + 1}
              </span>

              <div className={styles.foldText}>
                {row.screen ? (
                  <Link href={`/dashboard/home/${row.key}`} className={styles.foldName}>
                    {row.label}
                  </Link>
                ) : (
                  <span className={styles.foldName}>{row.name}</span>
                )}

                <span className={styles.foldMeta}>
                  {row.screen
                    ? row.collections.length > 0
                      ? row.collections.map((c) => c.label).join(", ")
                      : "Text and images only"
                    : "No editing screen — this section is in the database but not in the dashboard"}
                </span>
              </div>

              {/* `display: contents` on wide screens, so the grid below is
                  unchanged; a flex row on a phone, so the state and the
                  button share a line instead of taking one each. Fifteen
                  folds at three lines apiece is a lot of scrolling. */}
              <span className={styles.foldActions}>
                <span
                  className={`${styles.pill} ${row.isActive ? styles.pillLive : styles.pillOff}`}
                >
                  {row.isActive ? "Showing" : "Hidden"}
                </span>

                <button
                  type="button"
                  className={styles.foldButton}
                  onClick={() => void toggle(row)}
                  disabled={busyId === row.id}
                >
                  {row.isActive ? "Hide" : "Show"}
                </button>
              </span>
            </li>
          );
        })}
      </ol>
    </>
  );
}
