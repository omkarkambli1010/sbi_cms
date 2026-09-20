"use client";

import { useId } from "react";

import type { FieldDef } from "@/server/cms/registry";

import MediaPicker from "./MediaPicker";
import styles from "./field.module.css";

/**
 * One input, driven by its registry description.
 *
 * The registry says what a field is; this decides what it looks like. Adding
 * a column to a fold therefore means one entry in the registry and nothing
 * here — which is the only way twenty-odd screens stay consistent.
 */

export interface FieldProps {
  field: FieldDef;
  value: unknown;
  error?: string;
  onChange: (name: string, value: unknown) => void;
}

/** A media reference, however the API happened to serialise it. */
function toMediaId(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export default function Field({ field, value, error, onChange }: FieldProps) {
  const id = useId();
  const describedBy = [error ? `${id}-error` : null, field.help ? `${id}-help` : null]
    .filter(Boolean)
    .join(" ");

  const set = (next: unknown) => onChange(field.name, next);

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={id}>
        {field.label}
        {field.required ? <span className={styles.required}> (required)</span> : null}
      </label>

      {field.kind === "textarea" ? (
        <textarea
          id={id}
          className={`${styles.input} ${styles.textarea} ${error ? styles.invalid : ""}`}
          value={typeof value === "string" ? value : ""}
          rows={4}
          aria-describedby={describedBy || undefined}
          aria-invalid={error ? true : undefined}
          onChange={(event) => set(event.target.value)}
        />
      ) : null}

      {field.kind === "select" ? (
        <select
          id={id}
          className={`${styles.input} ${error ? styles.invalid : ""}`}
          value={typeof value === "string" ? value : ""}
          aria-describedby={describedBy || undefined}
          onChange={(event) => set(event.target.value)}
        >
          <option value="">Choose…</option>
          {field.options?.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      ) : null}

      {field.kind === "boolean" ? (
        <label className={styles.check}>
          <input
            id={id}
            type="checkbox"
            checked={value === true}
            onChange={(event) => set(event.target.checked)}
          />
          <span>Yes</span>
        </label>
      ) : null}

      {field.kind === "lines" ? (
        <LinesInput
          id={id}
          value={Array.isArray(value) ? (value as string[]) : []}
          describedBy={describedBy}
          onChange={set}
        />
      ) : null}

      {field.kind === "media" ? (
        /* PostgreSQL BIGINT arrives from pg as a string, so a saved image id
           reads as "17" rather than 17. Coercing here rather than at each
           call site: every media field on every screen went through this
           branch, and every one of them showed "Nothing chosen" for an image
           that was in fact set. */
        <MediaPicker value={toMediaId(value)} onChange={(mediaId) => set(mediaId)} />
      ) : null}

      {["text", "slug", "href", "number", "date", "datetime"].includes(field.kind) ? (
        <input
          id={id}
          className={`${styles.input} ${error ? styles.invalid : ""}`}
          type={
            field.kind === "number"
              ? "number"
              : field.kind === "date"
                ? "date"
                : field.kind === "datetime"
                  ? "datetime-local"
                  : "text"
          }
          value={value === null || value === undefined ? "" : String(value)}
          aria-describedby={describedBy || undefined}
          aria-invalid={error ? true : undefined}
          onChange={(event) =>
            set(field.kind === "number" ? event.target.value : event.target.value)
          }
        />
      ) : null}

      {field.help ? (
        <p id={`${id}-help`} className={styles.help}>
          {field.help}
        </p>
      ) : null}

      {error ? (
        <p id={`${id}-error`} className={styles.error}>
          {error}
        </p>
      ) : null}
    </div>
  );
}

/**
 * Ordered lines, one per row.
 *
 * A textarea split on newlines would be smaller code and worse: these arrays
 * carry deliberate design breaks, and an editor needs to see how many lines
 * there are and move one without retyping the rest.
 */
function LinesInput({
  id,
  value,
  describedBy,
  onChange,
}: {
  id: string;
  value: string[];
  describedBy: string;
  onChange: (lines: string[]) => void;
}) {
  const lines = value.length > 0 ? value : [""];

  const replace = (index: number, text: string) =>
    onChange(lines.map((line, i) => (i === index ? text : line)));

  return (
    <div className={styles.lines} aria-describedby={describedBy || undefined}>
      {lines.map((line, index) => (
        <div key={index} className={styles.lineRow}>
          <input
            id={index === 0 ? id : undefined}
            className={styles.input}
            value={line}
            aria-label={`Line ${index + 1}`}
            onChange={(event) => replace(index, event.target.value)}
          />
          <button
            type="button"
            className={styles.lineButton}
            onClick={() => onChange(lines.filter((_, i) => i !== index))}
            disabled={lines.length === 1 && lines[0] === ""}
          >
            Remove
          </button>
        </div>
      ))}

      <button type="button" className={styles.addLine} onClick={() => onChange([...lines, ""])}>
        Add line
      </button>
    </div>
  );
}
