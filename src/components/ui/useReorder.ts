"use client";

import { useCallback, useEffect, useRef, useState } from "react";

/**
 * Drag-to-reorder on pointer events, with keyboard equivalents.
 *
 * HTML5 drag-and-drop is not used: it does not fire on touch at all, its drag
 * image cannot be styled usefully, and it offers nothing to a keyboard. All
 * three matter here — reordering is the main way an editor rearranges the
 * page, and a tablet is a plausible device for it.
 *
 * The contract for a caller:
 *
 *   const reorder = useReorder(items.map((i) => i.id), commit);
 *   <ul data-reorder-list>
 *     <li {...reorder.rowProps(id)}>
 *       <button {...reorder.handleProps(id)} />
 *
 * `order` is the live order during a drag; `commit` runs once, on release,
 * with the final list. Nothing is saved mid-drag, so a dropped connection
 * cannot leave a list half-renumbered.
 */

export interface Reorder {
  /** Ids in their current visual order — render from this, not the source. */
  order: number[];
  draggingId: number | null;
  rowProps: (id: number) => {
    "data-reorder-id": number;
    "data-dragging": boolean | undefined;
  };
  handleProps: (id: number) => {
    onPointerDown: (event: React.PointerEvent) => void;
    onKeyDown: (event: React.KeyboardEvent) => void;
    role: "button";
    tabIndex: 0;
    "aria-label": string;
  };
  /** True while a commit is in flight, for disabling the list. */
  saving: boolean;
}

function move(list: number[], from: number, to: number): number[] {
  if (from === to || from < 0 || to < 0 || to >= list.length) return list;

  const next = [...list];
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}

export function useReorder(
  ids: number[],
  commit: (ids: number[]) => Promise<void>,
  label: (id: number) => string = () => "item",
): Reorder {
  const [order, setOrder] = useState<number[]>(ids);
  const [draggingId, setDraggingId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);

  /* The source list changes under us — a row added, a filter applied — so the
     visual order is re-seeded when the ids themselves differ. React's own
     "adjust state during render" pattern: compared as a string because the
     array identity changes every render. */
  const seed = ids.join(",");
  const [seenSeed, setSeenSeed] = useState(seed);

  if (seenSeed !== seed) {
    setSeenSeed(seed);
    if (order.join(",") !== seed) setOrder(ids);
  }

  /* Pointer handlers run between renders and need the latest order without
     re-subscribing. Written in an effect, never during render. */
  const orderRef = useRef(order);

  useEffect(() => {
    orderRef.current = order;
  }, [order]);

  const save = useCallback(
    async (next: number[]) => {
      setSaving(true);
      try {
        await commit(next);
      } finally {
        setSaving(false);
      }
    },
    [commit],
  );

  const onPointerDown = useCallback(
    (id: number) => (event: React.PointerEvent) => {
      /* Primary button or touch only: a right-click on the handle should open
         a context menu, not start a drag nobody can cancel. */
      if (event.button !== 0) return;

      event.preventDefault();

      const handle = event.currentTarget as HTMLElement;
      const list = handle.closest("[data-reorder-list]");
      if (!list) return;

      handle.setPointerCapture(event.pointerId);
      setDraggingId(id);

      const onMove = (moveEvent: PointerEvent) => {
        const rows = Array.from(list.querySelectorAll<HTMLElement>("[data-reorder-id]"));
        const current = orderRef.current;

        /* Where the pointer is, not where it started: the row under the
           cursor is the position the dragged row takes. */
        const target = rows.find((row) => {
          const box = row.getBoundingClientRect();
          return moveEvent.clientY >= box.top && moveEvent.clientY <= box.bottom;
        });

        if (!target) return;

        const from = current.indexOf(id);
        const to = current.indexOf(Number(target.dataset.reorderId));

        if (from !== -1 && to !== -1 && from !== to) {
          const next = move(current, from, to);
          orderRef.current = next;
          setOrder(next);
        }
      };

      const onUp = () => {
        handle.removeEventListener("pointermove", onMove);
        handle.removeEventListener("pointerup", onUp);
        handle.removeEventListener("pointercancel", onUp);
        setDraggingId(null);

        if (orderRef.current.join(",") !== ids.join(",")) {
          void save(orderRef.current);
        }
      };

      handle.addEventListener("pointermove", onMove);
      handle.addEventListener("pointerup", onUp);
      handle.addEventListener("pointercancel", onUp);
    },
    [ids, save],
  );

  const onKeyDown = useCallback(
    (id: number) => (event: React.KeyboardEvent) => {
      const delta = event.key === "ArrowUp" ? -1 : event.key === "ArrowDown" ? 1 : 0;
      if (delta === 0) return;

      event.preventDefault();

      const current = orderRef.current;
      const from = current.indexOf(id);
      const next = move(current, from, from + delta);

      if (next === current) return;

      orderRef.current = next;
      setOrder(next);
      void save(next);
    },
    [save],
  );

  return {
    order,
    draggingId,
    saving,
    rowProps: (id: number) => ({
      "data-reorder-id": id,
      "data-dragging": draggingId === id ? true : undefined,
    }),
    handleProps: (id: number) => ({
      onPointerDown: onPointerDown(id),
      onKeyDown: onKeyDown(id),
      role: "button" as const,
      tabIndex: 0 as const,
      "aria-label": `Reorder ${label(id)}. Use the up and down arrow keys.`,
    }),
  };
}
