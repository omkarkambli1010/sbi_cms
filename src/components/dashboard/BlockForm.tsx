"use client";

import { useState } from "react";

import Field from "@/components/ui/Field";
import { useToast } from "@/components/ui/Toast";
import { api, ApiError } from "@/lib/apiClient";
import type { FieldDef } from "@/server/cms/registry";

import styles from "./section.module.css";

/**
 * The Section tab: whatever a fold's shell is.
 *
 * Three different shapes go through here — `section_blocks`, the hero, the
 * sticky nudge — because from an editor's side they are the same thing: a
 * form of named fields with one Save. The caller supplies the fields and the
 * endpoint; this owns dirty state, per-field errors and the save.
 */

interface BlockFormProps {
  title?: string;
  note?: string;
  endpoint: string;
  fields: readonly FieldDef[];
  initial: Record<string, unknown>;
  /** Sent with every save but not shown, e.g. the hero's own id. */
  hidden?: Record<string, unknown>;
}

export default function BlockForm({
  title,
  note,
  endpoint,
  fields,
  initial,
  hidden,
}: BlockFormProps) {
  const toast = useToast();

  const [values, setValues] = useState<Record<string, unknown>>(initial);
  const [saved, setSaved] = useState<Record<string, unknown>>(initial);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  const dirty = JSON.stringify(values) !== JSON.stringify(saved);

  async function save() {
    setBusy(true);
    setErrors({});

    try {
      await api.put(endpoint, { ...hidden, ...values });
      setSaved(values);
      toast.success("Changes saved");
    } catch (error) {
      if (error instanceof ApiError) {
        setErrors(error.fields);
        if (Object.keys(error.fields).length === 0) toast.error(error.message);
      } else {
        toast.error("Could not reach the server. Your changes have not been saved.");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={styles.form}>
      {title ? <h2 className={styles.fieldsetTitle}>{title}</h2> : null}
      {note ? <p className={styles.fieldsetNote}>{note}</p> : null}

      {fields.map((field) => (
        <div
          key={field.name}
          className={field.kind === "textarea" || field.kind === "lines" ? styles.formWide : ""}
        >
          <Field
            field={field}
            value={values[field.name]}
            error={errors[field.name]}
            onChange={(name, value) => setValues((current) => ({ ...current, [name]: value }))}
          />
        </div>
      ))}

      <div className={styles.formFoot}>
        <button type="button" className={styles.primary} onClick={save} disabled={busy || !dirty}>
          {busy ? "Saving…" : "Save changes"}
        </button>

        <button
          type="button"
          className={styles.secondary}
          onClick={() => {
            setValues(saved);
            setErrors({});
          }}
          disabled={busy || !dirty}
        >
          Undo
        </button>

        {dirty ? <span className={styles.dirty}>Unsaved changes</span> : null}
      </div>
    </div>
  );
}
