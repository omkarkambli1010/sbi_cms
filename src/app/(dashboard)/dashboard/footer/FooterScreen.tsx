"use client";

import { useEffect, useState } from "react";

import BlockForm from "@/components/dashboard/BlockForm";
import CollectionPanel from "@/components/dashboard/CollectionPanel";
import NavTree from "@/components/dashboard/NavTree";
import sectionStyles from "@/components/dashboard/section.module.css";
import { ErrorState, Skeleton } from "@/components/ui/States";
import { api, ApiError } from "@/lib/apiClient";
import { FOOTER_COLLECTIONS, type FieldDef } from "@/server/cms/registry";

import styles from "./footer.module.css";

/**
 * The site footer.
 *
 * Like the header, it is chrome rather than a fold — it renders on every
 * marketing route, so it has no page_sections row and cannot be reordered.
 *
 * Unlike the header it is large, so the screen is four tabs rather than two.
 * Everything behind them already existed: site_settings for the contact
 * block, navigation_menus for the eight link columns, and the three tables
 * 003 added for the stock index, the keyword chips and the legal text.
 */

/* The footer's slice of site_settings. The header's fields are round-tripped
   untouched — see the hidden values below — because the endpoint replaces
   the whole row. */
const CONTACT_FIELDS: readonly FieldDef[] = [
  { name: "legal_name", label: "Legal name", kind: "text", required: true },
  { name: "address", label: "Address", kind: "textarea" },
  { name: "phone", label: "Phone", kind: "text", help: "Printed as written; the tel: link strips the spaces." },
  { name: "email", label: "Email", kind: "text" },
  { name: "footer_logo_media_id", label: "Footer logo", kind: "media" },
  {
    name: "connect_label",
    label: "Heading over the social icons",
    kind: "text",
  },
  { name: "stocks_heading", label: "Heading over the A–Z", kind: "text" },
];

/**
 * The footer renders one menu per rendered column, which is why there are
 * eight rather than one: the five-column band would not survive being
 * flattened into a single list.
 */
const MENUS = [
  { key: "footer-primary", label: "Primary columns" },
  { key: "footer-col-1", label: "Column 1" },
  { key: "footer-col-2", label: "Column 2" },
  { key: "footer-col-3", label: "Column 3" },
  { key: "footer-col-4", label: "Column 4" },
  { key: "footer-col-5", label: "Column 5" },
  { key: "footer-utility", label: "Help & Support" },
  { key: "social", label: "Social links" },
];

type Tab = "contact" | "links" | "stocks" | "legal";

interface Settings extends Record<string, unknown> {
  brand_name: string;
  legal_name: string;
  address: string;
  phone: string;
  email: string;
  search_placeholder: string;
  logo_media_id: number | null;
  footer_logo_media_id: number | null;
  connect_label: string;
  stocks_heading: string;
}

export default function FooterScreen() {
  const [tab, setTab] = useState<Tab>("contact");
  const [settings, setSettings] = useState<Settings | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [version, setVersion] = useState(0);
  const [menuKey, setMenuKey] = useState(MENUS[0].key);

  useEffect(() => {
    let cancelled = false;

    api
      .get<Settings>("/api/admin/settings")
      .then((data) => {
        if (cancelled) return;
        setSettings(data);
        setFailure(null);
      })
      .catch((error) => {
        if (cancelled) return;
        setFailure(error instanceof ApiError ? error.message : "Could not load the settings.");
      });

    return () => {
      cancelled = true;
    };
  }, [version]);

  const letters = FOOTER_COLLECTIONS.find((c) => c.key === "stock-letters");
  const chips = FOOTER_COLLECTIONS.find((c) => c.key === "stock-links");
  const legal = FOOTER_COLLECTIONS.find((c) => c.key === "legal");

  const tabs: { key: Tab; label: string }[] = [
    { key: "contact", label: "Contact and headings" },
    { key: "links", label: "Link columns" },
    { key: "stocks", label: "Stock index" },
    { key: "legal", label: "Legal text" },
  ];

  return (
    <>
      <header className={sectionStyles.head}>
        <div className={sectionStyles.headText}>
          <h1>Footer</h1>
          <p className={sectionStyles.headNote}>
            The band at the bottom of every marketing page. Like the header, a change here shows
            everywhere at once.
          </p>
        </div>
      </header>

      <nav className={sectionStyles.tabs} aria-label="Footer sections">
        {tabs.map((candidate) => (
          <button
            key={candidate.key}
            type="button"
            className={`${sectionStyles.tab} ${tab === candidate.key ? sectionStyles.tabActive : ""}`}
            aria-current={tab === candidate.key ? "true" : undefined}
            onClick={() => setTab(candidate.key)}
          >
            {candidate.label}
          </button>
        ))}
      </nav>

      {failure ? (
        <ErrorState message={failure} onRetry={() => setVersion((n) => n + 1)} />
      ) : null}

      {tab === "contact" ? (
        settings === null && !failure ? (
          <Skeleton rows={5} />
        ) : settings ? (
          <BlockForm
            endpoint="/api/admin/settings"
            fields={CONTACT_FIELDS}
            initial={settings}
            /* The header's fields travel with every save. Omitting them would
               blank the wordmark and the search placeholder, because the
               settings endpoint replaces the row rather than patching it. */
            hidden={{
              brand_name: settings.brand_name,
              search_placeholder: settings.search_placeholder,
              logo_media_id: settings.logo_media_id,
            }}
          />
        ) : null
      ) : null}

      {tab === "links" ? (
        <>
          <label className={styles.menuPick}>
            Column
            <select
              className={sectionStyles.filter}
              value={menuKey}
              onChange={(event) => setMenuKey(event.target.value)}
            >
              {MENUS.map((menu) => (
                <option key={menu.key} value={menu.key}>
                  {menu.label}
                </option>
              ))}
            </select>
          </label>

          <p className={styles.menuNote}>
            Each column is its own menu, which is how the five-column band keeps its shape. A
            heading is a link with others nested inside it.
          </p>

          {/* Keyed, so switching column remounts the tree rather than
              showing the previous one's rows while the next loads. */}
          <NavTree key={menuKey} menuKey={menuKey} noun="link" />
        </>
      ) : null}

      {tab === "stocks" && letters && chips ? (
        <div className={styles.stack}>
          <section>
            <h2 className={styles.groupHeading}>Index letters</h2>
            <CollectionPanel section="footer" def={letters} />
          </section>

          <section>
            <h2 className={styles.groupHeading}>Keyword chips</h2>
            <CollectionPanel section="footer" def={chips} />
          </section>
        </div>
      ) : null}

      {tab === "legal" && legal ? (
        <>
          <p className={styles.menuNote}>
            The registration lines, disclosures and copyright notice. These are the longest text
            on the site and the most consequential to get wrong.
          </p>
          <CollectionPanel section="footer" def={legal} />
        </>
      ) : null}
    </>
  );
}
