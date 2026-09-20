import Link from "next/link";

import { requireUser } from "@/server/auth/session";
import { callFunction, pingDatabase } from "@/server/db/pool";

import styles from "./overview.module.css";

export const metadata = { title: "Overview" };
export const dynamic = "force-dynamic";

interface CountRow {
  label: string;
  total: string;
  inactive: string;
}

export default async function OverviewPage() {
  await requireUser();
  const healthy = await pingDatabase();
  const counts = healthy ? await callFunction<CountRow>("cms.overview_counts") : [];

  return (
    <>
      <header className={styles.head}>
        <h1>Overview</h1>
        <p className={styles.lede}>
          Everything on the SBI Securities home page is editable here. Changes are live the moment
          you save them — there is no separate publish step.
        </p>
      </header>

      {!healthy ? (
        <div className={styles.down} role="alert">
          <h2>The database is not answering</h2>
          <p>
            Nothing can be read or saved until it is back. Check that PostgreSQL is running and
            that <code>DATABASE_URL</code> points at it.
          </p>
        </div>
      ) : null}

      {healthy ? (
        <>
          <section className={styles.panel}>
            <h2>Start here</h2>
            <ul className={styles.shortcuts}>
              <li>
                <Link href="/dashboard/home">
                  <span className={styles.shortcutTitle}>The home page, fold by fold</span>
                  <span className={styles.shortcutBody}>
                    Reorder the page, switch a section off, or open one to edit it.
                  </span>
                </Link>
              </li>
              <li>
                <Link href="/dashboard/media">
                  <span className={styles.shortcutTitle}>Media library</span>
                  <span className={styles.shortcutBody}>
                    Upload artwork and replace an image everywhere it is used.
                  </span>
                </Link>
              </li>
              <li>
                <Link href="/dashboard/seo">
                  <span className={styles.shortcutTitle}>Search and sharing</span>
                  <span className={styles.shortcutBody}>
                    The title, description and preview image search engines show.
                  </span>
                </Link>
              </li>
            </ul>
          </section>

          <section className={styles.panel}>
            <h2>What is in the CMS</h2>
            <ul className={styles.counts}>
              {counts.map((row) => {
                const inactive = Number(row.inactive);

                return (
                  <li key={row.label}>
                    <span className={styles.figure}>{row.total}</span>
                    <span className={styles.figureLabel}>{row.label}</span>
                    <span className={styles.figureNote}>
                      {inactive === 0 ? "all showing" : `${inactive} switched off`}
                    </span>
                  </li>
                );
              })}
            </ul>
          </section>
        </>
      ) : null}
    </>
  );
}
