"use client";

import { createContext, useCallback, useContext, useMemo, useState } from "react";

import styles from "./toast.module.css";

/**
 * Confirmation that a save landed, and the one place a failure is announced.
 *
 * Messages are written in the same words as the button that caused them —
 * "Publish" produces "Published" — so an editor can tell at a glance that the
 * thing they asked for is the thing that happened.
 */

type Tone = "success" | "error";

interface Toast {
  id: number;
  tone: Tone;
  message: string;
}

interface ToastApi {
  success: (message: string) => void;
  error: (message: string) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

const LIFETIME_MS = 5000;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const push = useCallback((tone: Tone, message: string) => {
    const id = Date.now() + Math.random();

    setToasts((current) => [...current, { id, tone, message }]);

    /* Errors stay as long as successes: an editor who looked away should not
       have to repeat an action to find out why it failed. Dismiss is manual
       as well as automatic. */
    window.setTimeout(() => {
      setToasts((current) => current.filter((toast) => toast.id !== id));
    }, LIFETIME_MS);
  }, []);

  const api = useMemo<ToastApi>(
    () => ({
      success: (message: string) => push("success", message),
      error: (message: string) => push("error", message),
    }),
    [push],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}

      <div className={styles.stack} role="status" aria-live="polite">
        {toasts.map((toast) => (
          <div key={toast.id} className={`${styles.toast} ${styles[toast.tone]}`}>
            <span>{toast.message}</span>
            <button
              type="button"
              className={styles.dismiss}
              aria-label="Dismiss"
              onClick={() => setToasts((current) => current.filter((t) => t.id !== toast.id))}
            >
              ×
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const api = useContext(ToastContext);

  if (!api) {
    throw new Error("useToast must be used inside <ToastProvider>.");
  }

  return api;
}
