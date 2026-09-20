import styles from "./dashboard.module.css";

/**
 * Says, on every screen, that nobody signed in.
 *
 * A bypass you cannot see is a bypass that gets left on. This is deliberately
 * hard to miss and deliberately not dismissible: it disappears when the flag
 * does, and not before.
 */
export default function DevBanner() {
  return (
    <div className={styles.devBanner} role="status">
      <strong>Sign-in is switched off.</strong> Anyone who can reach this address is an
      administrator. Remove <code>CMS_DEV_BYPASS_AUTH</code> from <code>.env.local</code> to put
      the login back.
    </div>
  );
}
