"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Field from "@/components/ui/Field";
import { EmptyState, ErrorState, Skeleton } from "@/components/ui/States";
import { useToast } from "@/components/ui/Toast";
import { useReorder } from "@/components/ui/useReorder";
import { api, ApiError } from "@/lib/apiClient";
import type { FieldDef } from "@/server/cms/registry";

import styles from "./section.module.css";
import tree from "./navTree.module.css";

/**
 * A menu, edited as the tree it is.
 *
 * `CollectionPanel` serves every other list in the CMS, but it assumes one
 * flat level: one drag list, one reorder call. Navigation is the only place
 * with depth, and bending the shared component to cope would have made
 * twenty screens carry a concept one of them needs.
 *
 * Ordering is per level, matching `cms.nav_item_reorder`, which rejects a
 * list that is not exactly one level's id set. That falls out of the
 * structure here: each level renders its own `NavLevel`, and each has its
 * own reorder hook and its own commit.
 */

export interface NavRow {
  id: string;
  parent_id: string | null;
  label: string;
  href: string;
  opens_in_new_tab: boolean;
  is_active: boolean;
  display_order: number;
}

interface NavTreeProps {
  menuKey: string;
  /** What a top-level entry is called on this screen, e.g. "link". */
  noun?: string;
}

const FIELDS: readonly FieldDef[] = [
  { name: "label", label: "Label", kind: "text", required: true },
  { name: "href", label: "Link", kind: "href" },
  { name: "opens_in_new_tab", label: "Open in a new tab", kind: "boolean" },
];

type Draft = { label: string; href: string; opens_in_new_tab: boolean; parent_id: string };

const BLANK: Draft = { label: "", href: "", opens_in_new_tab: false, parent_id: "" };

export default function NavTree({ menuKey, noun = "link" }: NavTreeProps) {
  const toast = useToast();

  const [rows, setRows] = useState<NavRow[] | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [version, setVersion] = useState(0);

  const [editing, setEditing] = useState<NavRow | null>(null);
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState<Draft>(BLANK);
  const [original, setOriginal] = useState<Draft>(BLANK);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState<NavRow | null>(null);
  const [deleting, setDeleting] = useState(false);

  const base = `/api/admin/navigation/${menuKey}`;
  const refresh = useCallback(() => setVersion((n) => n + 1), []);

  useEffect(() => {
    let cancelled = false;

    api
      .get<{ items: NavRow[] }>(base)
      .then((data) => {
        if (cancelled) return;
        setRows(Array.isArray(data?.items) ? data.items : []);
        setFailure(null);
      })
      .catch((error) => {
        if (cancelled) return;
        setRows([]);
        setFailure(error instanceof ApiError ? error.message : "Could not load this menu.");
      });

    return () => {
      cancelled = true;
    };
  }, [base, version]);

  const childrenOf = useMemo(() => {
    const map = new Map<string | null, NavRow[]>();

    for (const row of rows ?? []) {
      const key = row.parent_id;
      map.set(key, [...(map.get(key) ?? []), row]);
    }

    for (const list of map.values()) list.sort((a, b) => a.display_order - b.display_order);

    return map;
  }, [rows]);

  /* A link can be moved under any other link that is not one of its own
     descendants. Working that out here means the picker cannot offer a move
     the database is going to refuse. */
  const parentOptions = useMemo(() => {
    const subject = editing?.id;
    const banned = new Set<string>();

    if (subject) {
      const walk = (id: string) => {
        banned.add(id);
        for (const child of childrenOf.get(id) ?? []) walk(child.id);
      };
      walk(subject);
    }

    return (rows ?? []).filter((row) => !banned.has(row.id));
  }, [rows, editing, childrenOf]);

  function openAdd(parentId: string | null) {
    const blank = { ...BLANK, parent_id: parentId ?? "" };
    setDraft(blank);
    setOriginal(blank);
    setErrors({});
    setEditing(null);
    setAdding(true);
  }

  function openEdit(row: NavRow) {
    const next: Draft = {
      label: row.label,
      href: row.href,
      opens_in_new_tab: row.opens_in_new_tab,
      parent_id: row.parent_id ?? "",
    };
    setDraft(next);
    setOriginal(next);
    setErrors({});
    setAdding(false);
    setEditing(row);
  }

  async function save() {
    setSaving(true);
    setErrors({});

    const body = {
      label: draft.label,
      href: draft.href,
      opens_in_new_tab: draft.opens_in_new_tab,
    };

    try {
      if (adding) {
        await api.post(base, {
          ...body,
          parent_id: draft.parent_id === "" ? null : Number(draft.parent_id),
        });
        toast.success(`${noun[0].toUpperCase()}${noun.slice(1)} added`);
      } else if (editing) {
        await api.put(`/api/admin/navigation/items/${editing.id}`, body);

        /* Two calls, because moving is its own verb — but only when the
           parent actually changed, so an ordinary edit does not shunt the
           link to the end of its level. */
        if (draft.parent_id !== original.parent_id) {
          await api.patch(`/api/admin/navigation/items/${editing.id}/parent`, {
            parent_id: draft.parent_id === "" ? null : Number(draft.parent_id),
          });
        }

        toast.success("Changes saved");
      }

      setAdding(false);
      setEditing(null);
      refresh();
    } catch (error) {
      if (error instanceof ApiError) {
        setErrors(error.fields);
        if (Object.keys(error.fields).length === 0) toast.error(error.message);
      } else {
        toast.error("Could not reach the server. Your changes have not been saved.");
      }
    } finally {
      setSaving(false);
    }
  }

  async function toggle(row: NavRow) {
    try {
      await api.patch(`/api/admin/navigation/items/${row.id}/active`, {
        is_active: !row.is_active,
      });
      toast.success(row.is_active ? "Hidden from the menu" : "Showing in the menu");
      refresh();
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "That change was not saved.");
    }
  }

  async function remove(row: NavRow) {
    setDeleting(true);

    try {
      await api.del(`/api/admin/navigation/items/${row.id}`);
      toast.success("Deleted");
      setConfirmDelete(null);
      refresh();
    } catch (error) {
      toast.error(error instanceof ApiError ? error.message : "That link could not be deleted.");
    } finally {
      setDeleting(false);
    }
  }

  const dirty = JSON.stringify(draft) !== JSON.stringify(original);
  const top = childrenOf.get(null) ?? [];

  return (
    <section>
      <div className={styles.panelBar}>
        <p className={tree.hint}>
          Drag to reorder within a level. Use <strong>Inside</strong> in the editor to nest a link
          under another — a nested link becomes a dropdown on the site.
        </p>
        <button type="button" className={styles.primary} onClick={() => openAdd(null)}>
          Add {noun}
        </button>
      </div>

      {failure ? <ErrorState message={failure} onRetry={refresh} /> : null}

      {rows === null ? <Skeleton rows={5} /> : null}

      {rows !== null && rows.length === 0 ? (
        <EmptyState
          title="This menu is empty"
          body="Nothing will render until you add a link."
          action={
            <button type="button" className={styles.primary} onClick={() => openAdd(null)}>
              Add the first {noun}
            </button>
          }
        />
      ) : null}

      {top.length > 0 ? (
        <div className={tree.panel}>
          <NavLevel
            menuKey={menuKey}
            parentId={null}
            items={top}
            childrenOf={childrenOf}
            depth={0}
            onEdit={openEdit}
            onToggle={toggle}
            onDelete={setConfirmDelete}
            onAddChild={openAdd}
            onReordered={refresh}
          />
        </div>
      ) : null}

      <Drawer
        open={adding || editing !== null}
        title={adding ? `Add ${noun}` : `Edit ${noun}`}
        onRequestClose={() => {
          setAdding(false);
          setEditing(null);
        }}
        footer={
          <>
            <button
              type="button"
              className={styles.secondary}
              onClick={() => {
                setAdding(false);
                setEditing(null);
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              className={styles.primary}
              onClick={save}
              disabled={saving || !dirty}
            >
              {saving ? "Saving…" : "Save"}
            </button>
          </>
        }
      >
        {FIELDS.map((field) => (
          <Field
            key={field.name}
            field={field}
            value={draft[field.name as keyof Draft]}
            error={errors[field.name]}
            onChange={(name, value) => setDraft((d) => ({ ...d, [name]: value }))}
          />
        ))}

        <div className={tree.parentField}>
          <label className={tree.parentLabel} htmlFor="nav-parent">
            Inside
          </label>
          <select
            id="nav-parent"
            className={tree.parentSelect}
            value={draft.parent_id}
            onChange={(event) => setDraft((d) => ({ ...d, parent_id: event.target.value }))}
          >
            <option value="">Top level — shows in the bar itself</option>
            {parentOptions.map((row) => (
              <option key={row.id} value={row.id}>
                {row.label}
              </option>
            ))}
          </select>
          <p className={tree.parentHelp}>
            Choose a link to make this one appear in its dropdown. A link cannot be moved inside
            its own children.
          </p>
        </div>
      </Drawer>

      <ConfirmDialog
        open={confirmDelete !== null}
        title="Delete this link permanently?"
        body={
          confirmDelete
            ? `“${confirmDelete.label}” will be removed from the menu${
                (childrenOf.get(confirmDelete.id) ?? []).length > 0
                  ? `, along with the ${(childrenOf.get(confirmDelete.id) ?? []).length} link(s) inside it`
                  : ""
              }. To take it off the site but keep it, use Hide instead.`
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

/* --- one level ------------------------------------------------------------ */

interface NavLevelProps {
  menuKey: string;
  parentId: string | null;
  items: NavRow[];
  childrenOf: Map<string | null, NavRow[]>;
  depth: number;
  onEdit: (row: NavRow) => void;
  onToggle: (row: NavRow) => void;
  onDelete: (row: NavRow) => void;
  onAddChild: (parentId: string) => void;
  onReordered: () => void;
}

/**
 * Rendered once per level, so each gets its own reorder hook and its own
 * commit scoped to that parent. That is not a convenience — the stored
 * function rejects a list that is not exactly one level's id set.
 */
function NavLevel({
  menuKey,
  parentId,
  items,
  childrenOf,
  depth,
  onEdit,
  onToggle,
  onDelete,
  onAddChild,
  onReordered,
}: NavLevelProps) {
  const toast = useToast();
  const byId = useMemo(() => new Map(items.map((i) => [Number(i.id), i])), [items]);

  const commit = useCallback(
    async (ids: number[]) => {
      const query = parentId === null ? "" : `?parent=${parentId}`;

      try {
        await api.post(`/api/admin/navigation/${menuKey}/reorder${query}`, { ids });
        toast.success("Order saved");
      } catch (error) {
        toast.error(error instanceof ApiError ? error.message : "The order was not saved.");
      } finally {
        onReordered();
      }
    },
    [menuKey, parentId, toast, onReordered],
  );

  const reorder = useReorder(
    items.map((i) => Number(i.id)),
    commit,
    (id) => byId.get(id)?.label ?? "link",
  );

  return (
    <ul className={tree.level} data-reorder-list>
      {reorder.order.map((id) => {
        const row = byId.get(id);
        if (!row) return null;

        const kids = childrenOf.get(row.id) ?? [];

        return (
          <li key={id}>
            <div
              className={`${tree.row} ${row.is_active ? "" : tree.rowOff}`}
              style={{ paddingLeft: `${18 + depth * 26}px` }}
              {...reorder.rowProps(id)}
            >
              <span className={styles.handle} {...reorder.handleProps(id)} />

              <div className={tree.cell}>
                <span className={tree.label}>{row.label}</span>
                <span className={tree.meta}>
                  {row.href}
                  {kids.length > 0 ? ` · dropdown with ${kids.length}` : ""}
                  {row.opens_in_new_tab ? " · new tab" : ""}
                </span>
              </div>

              <div className={styles.rowActions}>
                <span
                  className={`${styles.pill} ${row.is_active ? styles.pillLive : styles.pillOff}`}
                >
                  {row.is_active ? "Showing" : "Hidden"}
                </span>
                <button
                  type="button"
                  className={styles.rowButton}
                  onClick={() => onAddChild(row.id)}
                >
                  Add inside
                </button>
                <button type="button" className={styles.rowButton} onClick={() => onToggle(row)}>
                  {row.is_active ? "Hide" : "Show"}
                </button>
                <button type="button" className={styles.rowButton} onClick={() => onEdit(row)}>
                  Edit
                </button>
                <button
                  type="button"
                  className={`${styles.rowButton} ${styles.rowDanger}`}
                  onClick={() => onDelete(row)}
                >
                  Delete
                </button>
              </div>
            </div>

            {kids.length > 0 ? (
              <NavLevel
                menuKey={menuKey}
                parentId={row.id}
                items={kids}
                childrenOf={childrenOf}
                depth={depth + 1}
                onEdit={onEdit}
                onToggle={onToggle}
                onDelete={onDelete}
                onAddChild={onAddChild}
                onReordered={onReordered}
              />
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}
