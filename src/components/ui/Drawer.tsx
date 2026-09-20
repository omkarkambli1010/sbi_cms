"use client";

import { useEffect, useRef } from "react";

import styles from "./drawer.module.css";

/**
 * The side panel every add and edit happens in.
 *
 * A panel rather than a modal so the table behind it stays readable — an
 * editor filling in an IPO can still see the rows either side of it.
 *
 * Escape and the backdrop both ask to close, and the caller decides: when the
 * form is dirty it puts a confirmation in the way instead of discarding work.
 */

interface DrawerProps {
  open: boolean;
  title: string;
  /** Asked, not told. The caller may refuse while the form is dirty. */
  onRequestClose: () => void;
  footer?: React.ReactNode;
  children: React.ReactNode;
}

export default function Drawer({ open, title, onRequestClose, footer, children }: DrawerProps) {
  const panelRef = useRef<HTMLDivElement>(null);
  const restoreFocusTo = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) return;

    restoreFocusTo.current = document.activeElement as HTMLElement | null;

    /* Focus the panel itself rather than the first input: a screen reader
       then announces the drawer's name before its contents, and a sighted
       editor is not dropped into the middle of a form. */
    panelRef.current?.focus();

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.stopPropagation();
        onRequestClose();
        return;
      }

      if (event.key !== "Tab") return;

      /* Keep Tab inside the panel. Without this, tabbing past the last field
         walks into the table behind and there is no way back but the mouse. */
      const focusable = panelRef.current?.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])',
      );

      if (!focusable || focusable.length === 0) return;

      const first = focusable[0];
      const last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKeyDown, true);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.removeEventListener("keydown", onKeyDown, true);
      document.body.style.overflow = previousOverflow;
      restoreFocusTo.current?.focus();
    };
  }, [open, onRequestClose]);

  if (!open) return null;

  return (
    <div className={styles.shell}>
      <div className={styles.scrim} onClick={onRequestClose} aria-hidden="true" />

      <div
        ref={panelRef}
        className={styles.panel}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
      >
        <header className={styles.head}>
          <h2>{title}</h2>
          <button type="button" className={styles.close} onClick={onRequestClose}>
            Close
          </button>
        </header>

        <div className={styles.body}>{children}</div>

        {footer ? <footer className={styles.foot}>{footer}</footer> : null}
      </div>
    </div>
  );
}
