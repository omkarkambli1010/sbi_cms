"use client";

import { useState } from "react";

import ConfirmDialog from "@/components/ui/ConfirmDialog";
import Drawer from "@/components/ui/Drawer";
import Field from "@/components/ui/Field";
import { ApiError } from "@/lib/apiClient";
import type { FieldDef } from "@/server/cms/registry";

import styles from "./section.module.css";

/**
 * Add and edit, for any collection.
 *
 * The inputs come from the registry, so a fold gains a field by gaining a
 * registry entry. Server-side validation errors are shown against the field
 * they belong to rather than as one message at the top, because `respond.ts`
 * reports them per field and a long form is otherwise a guessing game.
 */

export type ItemValues = Record<string, unknown>;

interface ItemDrawerProps {
  open: boolean;
  title: string;
  fields: readonly FieldDef[];
  values: ItemValues;
  onChange: (values: ItemValues) => void;
  onSave: () => Promise<void>;
  onClose: () => void;
  dirty: boolean;
}

export default function ItemDrawer({
  open,
  title,
  fields,
  values,
  onChange,
  onSave,
  onClose,
  dirty,
}: ItemDrawerProps) {
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [confirmDiscard, setConfirmDiscard] = useState(false);

  function requestClose() {
    if (dirty) {
      setConfirmDiscard(true);
      return;
    }
    reset();
    onClose();
  }

  function reset() {
    setErrors({});
    setMessage(null);
    setConfirmDiscard(false);
  }

  async function save() {
    setSaving(true);
    setErrors({});
    setMessage(null);

    try {
      await onSave();
      reset();
    } catch (error) {
      if (error instanceof ApiError) {
        setErrors(error.fields);
        /* Only show the banner when no field owns the problem; otherwise the
           same sentence appears twice. */
        setMessage(Object.keys(error.fields).length === 0 ? error.message : null);
      } else {
        setMessage("Could not reach the server. Your changes have not been saved.");
      }
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <Drawer
        open={open}
        title={title}
        onRequestClose={requestClose}
        footer={
          <>
            <button type="button" className={styles.secondary} onClick={requestClose}>
              Cancel
            </button>
            <button type="button" className={styles.primary} onClick={save} disabled={saving}>
              {saving ? "Saving…" : "Save"}
            </button>
          </>
        }
      >
        {message ? (
          <p className={styles.dirty} role="alert">
            {message}
          </p>
        ) : null}

        {fields.map((field) => (
          <Field
            key={field.name}
            field={field}
            value={values[field.name]}
            error={errors[field.name]}
            onChange={(name, value) => onChange({ ...values, [name]: value })}
          />
        ))}
      </Drawer>

      <ConfirmDialog
        open={confirmDiscard}
        title="Discard your changes?"
        body="This form has edits that have not been saved. Closing it now loses them."
        confirmLabel="Discard"
        tone="danger"
        onCancel={() => setConfirmDiscard(false)}
        onConfirm={() => {
          reset();
          onClose();
        }}
      />
    </>
  );
}
