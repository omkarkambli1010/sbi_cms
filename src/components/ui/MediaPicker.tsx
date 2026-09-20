"use client";

import { useCallback, useEffect, useState } from "react";

import { api } from "@/lib/apiClient";
import { previewUrl } from "@/lib/mediaUrl";

import Drawer from "./Drawer";
import styles from "./mediaPicker.module.css";

/**
 * Choosing an image, without leaving the form.
 *
 * Shows what is currently set rather than an id, because "17" tells an editor
 * nothing about whether the right picture is attached.
 */

export interface MediaAsset {
  id: number;
  url: string;
  file_name: string;
  alt_text: string;
  folder: string;
  mime_type: string;
}

interface MediaPickerProps {
  value: number | null;
  onChange: (id: number | null) => void;
}

export default function MediaPicker({ value, onChange }: MediaPickerProps) {
  const [open, setOpen] = useState(false);
  const [fetched, setFetched] = useState<MediaAsset | null>(null);
  const [looked, setLooked] = useState<number | null>(null);

  /* Derived rather than stored: clearing the field must not need a second
     state update, and a stale asset must never show under a new id. */
  const current = value !== null && fetched?.id === value ? fetched : null;
  const looking = value !== null && current === null && looked !== value;

  useEffect(() => {
    if (value === null) return;

    let cancelled = false;

    api
      .get<{ asset: MediaAsset }>(`/api/admin/media/${value}`)
      .then((data) => {
        /* pg returns BIGINT as a string, so normalise before the identity
           check below — "17" === 17 is false, and the picker would report a
           perfectly good image as missing. */
        if (!cancelled) setFetched({ ...data.asset, id: Number(data.asset.id) });
      })
      .catch(() => {
        /* A reference to a deleted asset reads as "image missing" rather than
           breaking the form; the editor can pick a replacement. */
      })
      .finally(() => {
        if (!cancelled) setLooked(value);
      });

    return () => {
      cancelled = true;
    };
  }, [value]);

  return (
    <div className={styles.picker}>
      <div className={styles.preview}>
        {current ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={previewUrl(current.url)} alt="" />
        ) : (
          <span className={styles.blank}>
            {looking ? "Loading" : value ? "Image missing" : "No image"}
          </span>
        )}
      </div>

      <div className={styles.meta}>
        <span className={styles.name}>{current?.file_name ?? "Nothing chosen"}</span>

        <div className={styles.actions}>
          <button type="button" className={styles.action} onClick={() => setOpen(true)}>
            {value ? "Replace" : "Choose image"}
          </button>
          {value ? (
            <button type="button" className={styles.action} onClick={() => onChange(null)}>
              Clear
            </button>
          ) : null}
        </div>
      </div>

      <MediaBrowser
        open={open}
        onClose={() => setOpen(false)}
        onPick={(asset) => {
          const id = Number(asset.id);
          setFetched({ ...asset, id });
          setLooked(id);
          onChange(id);
          setOpen(false);
        }}
      />
    </div>
  );
}

function MediaBrowser({
  open,
  onClose,
  onPick,
}: {
  open: boolean;
  onClose: () => void;
  onPick: (asset: MediaAsset) => void;
}) {
  const [items, setItems] = useState<MediaAsset[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(false);

  const load = useCallback(async (term: string) => {
    setLoading(true);
    try {
      const data = await api.get<{ items: MediaAsset[] }>(
        `/api/admin/media?limit=60&search=${encodeURIComponent(term)}`,
      );
      setItems(data.items);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!open) return;

    /* Debounced so typing a filename is not one request per keystroke. */
    const timer = window.setTimeout(() => void load(search), 200);
    return () => window.clearTimeout(timer);
  }, [open, search, load]);

  return (
    <Drawer open={open} title="Media library" onRequestClose={onClose}>
      <input
        className={styles.search}
        placeholder="Search by file name or alt text"
        value={search}
        onChange={(event) => setSearch(event.target.value)}
      />

      {loading && items.length === 0 ? <p className={styles.note}>Loading…</p> : null}

      {!loading && items.length === 0 ? (
        <p className={styles.note}>
          Nothing matches that. Upload images from the Media library screen.
        </p>
      ) : null}

      <ul className={styles.grid}>
        {items.map((asset) => (
          <li key={asset.id}>
            <button type="button" className={styles.tile} onClick={() => onPick(asset)}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={previewUrl(asset.url)} alt="" />
              <span>{asset.file_name}</span>
            </button>
          </li>
        ))}
      </ul>
    </Drawer>
  );
}
