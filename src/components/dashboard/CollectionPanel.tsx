"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import ConfirmDialog from "@/components/ui/ConfirmDialog";
import { EmptyState, ErrorState, Skeleton } from "@/components/ui/States";
import { useToast } from "@/components/ui/Toast";
import { useReorder } from "@/components/ui/useReorder";
import { api, ApiError } from "@/lib/apiClient";
import type { CollectionDef, ParentKind } from "@/server/cms/registry";

import ItemDrawer, { type ItemValues } from "./ItemDrawer";
import styles from "./section.module.css";

/**
 * One ordered list: search, filter, add, edit, reorder, disable, delete.
 *
 * Every collection in the CMS is this component. What changes between them is
 * the registry entry — which is the point: twenty screens behaving the same
 * way is a property of there being one screen.
 */

export interface Row {
  id: string | number;
  is_active?: boolean;
  [key: string]: unknown;
}

/**
 * Where this collection's endpoints live.
 *
 * The fifteen folds all sit under /api/admin/home/<section>/<collection> and
 * get these for free. Navigation does not — its items are addressed by menu
 * for listing and by id for editing — so the paths are a parameter rather
 * than something this component assumes.
 */
export interface CollectionRoutes {
  /** GET the list, POST a new row. */
  list: string;
  /** PUT and DELETE one row. */
  item: (id: string | number) => string;
  /** PATCH the active flag. */
  active: (id: string | number) => string;
  /** POST the new order. */
  reorder: string;
}

interface CollectionPanelProps {
  section: string;
  def: CollectionDef;
  /** Options for the parent chooser, when the rows hang off something. */
  parents?: { id: number; label: string }[];
  /** Which sibling collection supplies those options, for the empty message. */
  parentLabel?: string;
  /** Overrides the home-page paths. See CollectionRoutes. */
  routes?: CollectionRoutes;
}

/** The sibling collection a parent chooser is filled from. */
export const PARENT_SOURCE: Partial<Record<ParentKind, string>> = {
  tab: "tabs",
  card: "cards",
  plan: "plans",
};

function titleOf(row: Row): string {
  for (const key of ["title", "name", "label", "question", "quote", "text", "letter", "value"]) {
    const value = row[key];
    if (typeof value === "string" && value.trim()) return value;
  }
  return `Item ${row.id}`;
}

function metaOf(row: Row, def: CollectionDef): string {
  const parts: string[] = [];

  for (const field of def.fields.slice(0, 6)) {
    if (["title", "name", "label", "question", "quote", "text"].includes(field.name)) continue;
    const value = row[field.name];
    if (typeof value === "string" && value.trim()) parts.push(value.trim());
    if (parts.length === 2) break;
  }

  return parts.join(" — ");
}

export default function CollectionPanel({
  section,
  def,
  parents,
  parentLabel,
  routes,
}: CollectionPanelProps) {
  const toast = useToast();

  const needsParent = parents !== undefined;
  const [parentId, setParentId] = useState<number | null>(parents?.[0]?.id ?? null);

  const [rows, setRows] = useState<Row[] | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [show, setShow] = useState<"all" | "active" | "inactive">("all");

  const [editing, setEditing] = useState<Row | null>(null);
  const [adding, setAdding] = useState(false);
  const [values, setValues] = useState<ItemValues>({});
  const [original, setOriginal] = useState<ItemValues>({});
  const [confirmDelete, setConfirmDelete] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);

  const base = `/api/admin/home/${section}/${def.key}`;
  const query = parentId === null ? "" : `?parent=${parentId}`;

  /* The default is the home-page shape; `routes` replaces it wholesale. */
  const path: CollectionRoutes = routes ?? {
    list: `${base}${query}`,
    item: (id) => `${base}/${id}`,
    active: (id) => `${base}/${id}/active`,
    reorder: `${base}/reorder${query}`,
  };

  /* Reading is an effect keyed on what is being read; writing bumps
     `version` to ask for it again. The cancelled flag matters as much as the
     lint rule it satisfies: switching tabs quickly would otherwise let a
     slower first response land on top of a faster second one. */
  const [version, setVersion] = useState(0);
  const refresh = useCallback(() => setVersion((n) => n + 1), []);

  useEffect(() => {
    if (needsParent && parentId === null) return;

    let cancelled = false;

    api
      .get<{ items: Row[] }>(path.list)
      .then((data) => {
        if (cancelled) return;

        /* Defensive because this component now serves more than one API. An
           endpoint that answers in an unexpected shape should show an error
           an editor can report, not crash the screen. */
        if (!Array.isArray(data?.items)) {
          setRows([]);
          setFailure("This list came back in a shape the screen did not expect.");
          return;
        }

        setRows(data.items);
        setFailure(null);
      })
      .catch((error) => {
        if (cancelled) return;
        setRows([]);
        setFailure(error instanceof ApiError ? error.message : "Could not load this list.");
      });

    return () => {
      cancelled = true;
    };
  }, [path.list, needsParent, parentId, version]);

  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();

    return (rows ?? []).filter((row) => {
      if (show === "active" && row.is_active === false) return false;
      if (show === "inactive" && row.is_active !== false) return false;
      if (!term) return true;
      return JSON.stringify(row).toLowerCase().includes(term);
    });
  }, [rows, search, show]);

  const byId = useMemo(() => new Map(visible.map((row) => [Number(row.id), row])), [visible]);

  const commitOrder = useCallback(
    async (ids: number[]) => {
      try {
        await api.post(path.reorder, { ids });
        toast.success("Order saved");
      } catch (error) {
        toast.error(
          error instanceof ApiError ? error.message : "The new order could not be saved.",
        );
      } finally {
        /* Refetch either way: on success to pick up the renumbering, on
           failure to put the list back the way the database has it. */
        refresh();
      }
    },
    [path.reorder, toast, refresh],
  );

  const reorder = useReorder(
    visible.map((row) => Number(row.id)),
    commitOrder,
    (id) => titleOf(byId.get(id) ?? ({ id } as Row)),
  );

  /* Reordering a filtered list would send an incomplete id set, which the
     stored function rejects outright. Rather than let an editor discover
     that through an error, the handles are only offered on the full list. */
  const canReorder = search.trim() === "" && show === "all" && !reorder.saving;

  function openAdd() {
    const blank: ItemValues = {};
    for (const field of def.fields) {
      blank[field.name] = field.kind === "lines" ? [] : field.kind === "boolean" ? false : "";
    }
    setValues(blank);
    setOriginal(blank);
    setEditing(null);
    setAdding(true);
  }

  function openEdit(row: Row) {
    const next: ItemValues = {};
    for (const field of def.fields) {
      const value = row[field.name];
      next[field.name] =
        field.kind === "lines"
          ? Array.isArray(value)
            ? value
            : []
          : value === null || value === undefined
            ? field.kind === "boolean"
              ? false
              : ""
            : value;
    }
    setValues(next);
    setOriginal(next);
    setEditing(row);
    setAdding(false);
  }

  async function save() {
    if (adding) {
      await api.post(path.list, values);
      toast.success(`${def.label.replace(/s$/, "")} added`);
    } else if (editing) {
      await api.put(path.item(editing.id), values);
      toast.success("Changes saved");
    }

    setAdding(false);
    setEditing(null);
    refresh();
  }

  async function toggleActive(row: Row) {
    const next = row.is_active === false;

    try {
      await api.patch(path.active(row.id), { is_active: next });
      toast.success(next ? "Showing on the page" : "Hidden from the page");
      refresh();
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "That change was not saved.");
    }
  }

  async function remove(row: Row) {
    setDeleting(true);

    try {
      await api.del(path.item(row.id));
      toast.success("Deleted");
      setConfirmDelete(null);
      refresh();
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "That row could not be deleted.");
    } finally {
      setDeleting(false);
    }
  }

  const dirty = JSON.stringify(values) !== JSON.stringify(original);

  /* Nothing to list until a parent is chosen, and nothing to choose from
     until one is made — so this is a signpost, not an empty table. */
  if (needsParent && parentId === null) {
    return (
      <EmptyState
        title={`No ${parentLabel?.toLowerCase() ?? "parent"} yet`}
        body={`These rows belong to a ${parentLabel?.toLowerCase() ?? "parent"}. Add one on the ${
          parentLabel ?? "parent"
        } tab first.`}
      />
    );
  }

  return (
    <section>
      <div className={styles.panelBar}>
        {needsParent ? (
          <label className={styles.parentPick}>
            {parentLabel ?? "Belongs to"}
            <select
              className={styles.filter}
              value={parentId ?? ""}
              onChange={(event) => setParentId(Number(event.target.value) || null)}
            >
              {parents?.map((parent) => (
                <option key={parent.id} value={parent.id}>
                  {parent.label}
                </option>
              ))}
            </select>
          </label>
        ) : null}

        <input
          className={styles.search}
          placeholder={`Search ${def.label.toLowerCase()}`}
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />

        <select
          className={styles.filter}
          value={show}
          aria-label="Filter by state"
          onChange={(event) => setShow(event.target.value as typeof show)}
        >
          <option value="all">All</option>
          <option value="active">Showing</option>
          <option value="inactive">Hidden</option>
        </select>

        <button
          type="button"
          className={styles.primary}
          onClick={openAdd}
          disabled={needsParent && parentId === null}
        >
          Add
        </button>
      </div>

      {failure ? <ErrorState message={failure} onRetry={refresh} /> : null}

      {rows === null ? <Skeleton /> : null}

      {rows !== null && rows.length === 0 ? (
        <EmptyState
          title={`No ${def.label.toLowerCase()} yet`}
          body="Nothing here will render on the page until you add something."
          action={
            <button type="button" className={styles.primary} onClick={openAdd}>
              Add the first one
            </button>
          }
        />
      ) : null}

      {rows !== null && rows.length > 0 && visible.length === 0 ? (
        <EmptyState
          title="Nothing matches"
          body="Clear the search or the filter to see the rest of the list."
        />
      ) : null}

      {visible.length > 0 ? (
        <ul className={styles.table} data-reorder-list>
          {reorder.order.map((id) => {
            const row = byId.get(id);
            if (!row) return null;

            const hidden = row.is_active === false;

            return (
              <li key={id} className={styles.row} {...reorder.rowProps(id)}>
                {canReorder ? (
                  <span className={styles.handle} {...reorder.handleProps(id)} />
                ) : (
                  <span />
                )}

                <div className={styles.cell}>
                  <div className={styles.cellTitle}>{titleOf(row)}</div>
                  <div className={styles.cellMeta}>{metaOf(row, def)}</div>
                </div>

                <div className={styles.rowActions}>
                  <span className={`${styles.pill} ${hidden ? styles.pillOff : styles.pillLive}`}>
                    {hidden ? "Hidden" : "Showing"}
                  </span>
                  <button
                    type="button"
                    className={styles.rowButton}
                    onClick={() => void toggleActive(row)}
                  >
                    {hidden ? "Show" : "Hide"}
                  </button>
                  <button
                    type="button"
                    className={styles.rowButton}
                    onClick={() => openEdit(row)}
                  >
                    Edit
                  </button>
                  <button
                    type="button"
                    className={`${styles.rowButton} ${styles.rowDanger}`}
                    onClick={() => setConfirmDelete(row)}
                  >
                    Delete
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
      ) : null}

      {!canReorder && visible.length > 1 && rows !== null && rows.length > 0 ? (
        <p className={styles.headNote}>
          Reordering is available when the list is unfiltered — the whole list has to move
          together.
        </p>
      ) : null}

      <ItemDrawer
        open={adding || editing !== null}
        title={adding ? `Add ${def.label.replace(/s$/, "").toLowerCase()}` : `Edit ${def.label.replace(/s$/, "").toLowerCase()}`}
        fields={def.fields}
        values={values}
        dirty={dirty}
        onChange={setValues}
        onSave={save}
        onClose={() => {
          setAdding(false);
          setEditing(null);
        }}
      />

      <ConfirmDialog
        open={confirmDelete !== null}
        title="Delete this permanently?"
        body={
          confirmDelete
            ? `“${titleOf(confirmDelete)}” will be removed from the page and from the database. To take it off the page but keep it, use Hide instead.`
            : ""
        }
        confirmLabel="Delete"
        tone="danger"
        busy={deleting}
        onCancel={() => setConfirmDelete(null)}
        onConfirm={() => confirmDelete && void remove(confirmDelete)}
      />
    </section>
  );
}
