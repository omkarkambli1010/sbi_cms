"use client";

import { useEffect, useRef } from "react";

import styles from "./confirm.module.css";

/**
 * The guard in front of anything that cannot be undone.
 *
 * It always names the row. "Delete this item?" teaches an editor to click
 * through; "Delete the FAQ 'Is my money safe…'?" does not.
 */

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  body: string;
  confirmLabel: string;
  tone?: "danger" | "default";
  busy?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export default function ConfirmDialog({
  open,
  title,
  body,
  confirmLabel,
  tone = "default",
  busy = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const cancelRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;

    /* Cancel takes focus, not the destructive button: Enter should not delete
       something because the dialog appeared under the editor's fingers. */
    cancelRef.current?.focus();

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onCancel();
    };

    document.addEventListener("keydown", onKeyDown, true);
    return () => document.removeEventListener("keydown", onKeyDown, true);
  }, [open, onCancel]);

  if (!open) return null;

  return (
    <div className={styles.shell} role="dialog" aria-modal="true" aria-label={title}>
      <div className={styles.scrim} onClick={onCancel} aria-hidden="true" />

      <div className={styles.box}>
        <h2>{title}</h2>
        <p className={styles.body}>{body}</p>

        <div className={styles.actions}>
          <button type="button" ref={cancelRef} className={styles.cancel} onClick={onCancel}>
            Keep it
          </button>
          <button
            type="button"
            className={tone === "danger" ? styles.danger : styles.confirm}
            onClick={onConfirm}
            disabled={busy}
          >
            {busy ? "Working…" : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
