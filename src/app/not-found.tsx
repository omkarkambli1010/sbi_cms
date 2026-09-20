import Link from "next/link";

/**
 * Several sidebar entries point at screens that are not built yet. Rather
 * than a bare 404, say which they are and where the built ones live — during
 * a review that is the difference between "broken" and "not finished".
 */
export default function NotFound() {
  return (
    <main style={{ maxWidth: 620, margin: "0 auto", padding: "72px 24px" }}>
      <h1 style={{ marginBottom: 10 }}>That screen is not built yet</h1>

      <p style={{ color: "var(--ink-3)", marginBottom: 20 }}>
        The dashboard is part-finished. These are the screens that exist today:
      </p>

      <ul style={{ lineHeight: 2, paddingLeft: 18, marginBottom: 24 }}>
        <li>
          <Link href="/dashboard">Overview</Link>
        </li>
        <li>
          <Link href="/dashboard/home">Home page</Link> — the fold list, drag to reorder
        </li>
        <li>
          <Link href="/dashboard/home/hero">Hero</Link>, and the other fourteen folds under{" "}
          <code>/dashboard/home/&lt;fold&gt;</code>
        </li>
        <li>
          <Link href="/login">Sign in</Link>
        </li>
      </ul>

      <p style={{ color: "var(--ink-3)" }}>
        Media library, Header, Footer, Statistics, SEO, Navigation and Settings are still to
        come.
      </p>
    </main>
  );
}
