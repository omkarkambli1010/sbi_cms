import styles from "./states.module.css";

/**
 * Loading, empty and failure — the three screens an editor actually meets
 * first on a slow morning, so they carry direction rather than mood.
 */

export function Skeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div className={styles.skeleton} aria-hidden="true">
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className={styles.bar} />
      ))}
    </div>
  );
}

export function EmptyState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  /** The primary action, so an empty screen is an invitation rather than a dead end. */
  action?: React.ReactNode;
}) {
  return (
    <div className={styles.empty}>
      <h3>{title}</h3>
      <p>{body}</p>
      {action}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className={styles.error} role="alert">
      <p>{message}</p>
      {onRetry ? (
        <button type="button" className={styles.retry} onClick={onRetry}>
          Try again
        </button>
      ) : null}
    </div>
  );
}
