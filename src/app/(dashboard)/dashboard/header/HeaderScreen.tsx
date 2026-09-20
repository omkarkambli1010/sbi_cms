"use client";

import { useEffect, useState } from "react";

import BlockForm from "@/components/dashboard/BlockForm";
import NavTree from "@/components/dashboard/NavTree";
import sectionStyles from "@/components/dashboard/section.module.css";
import { ErrorState, Skeleton } from "@/components/ui/States";
import { api, ApiError } from "@/lib/apiClient";
import type { FieldDef } from "@/server/cms/registry";

/**
 * The site header.
 *
 * Not a fold: it renders on every marketing route, so it has no
 * `page_sections` row, cannot be reordered, and is reached from the sidebar
 * rather than the home page's list.
 *
 * Its content comes from two places that already existed — `site_settings`
 * for the wordmark and the search field, `navigation_items` for the links —
 * so this screen is two tabs over two APIs rather than one new table.
 */

/* Only the fields the header actually renders. site_settings is one row that
   also carries the footer's address, phone and e-mail; those belong on the
   Footer screen, and are round-tripped untouched by the hidden values below
   rather than being shown here where they would confuse. */
const HEADER_SETTINGS_FIELDS: readonly FieldDef[] = [
  {
    name: "brand_name",
    label: "Brand name",
    kind: "text",
    required: true,
    help: "The wordmark's alt text, and the name read out for the logo link.",
  },
  {
    name: "search_placeholder",
    label: "Search placeholder",
    kind: "text",
    help: "The grey text inside the search field.",
  },
  { name: "logo_media_id", label: "Wordmark", kind: "media" },
];

interface Settings extends Record<string, unknown> {
  brand_name: string;
  legal_name: string;
  address: string;
  phone: string;
  email: string;
  search_placeholder: string;
  logo_media_id: number | null;
  footer_logo_media_id: number | null;
}

export default function HeaderScreen() {
  const [tab, setTab] = useState<"settings" | "links">("settings");
  const [settings, setSettings] = useState<Settings | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [version, setVersion] = useState(0);

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
        setFailure(
          error instanceof ApiError ? error.message : "Could not load the site settings.",
        );
      });

    return () => {
      cancelled = true;
    };
  }, [version]);

  return (
    <>
      <header className={sectionStyles.head}>
        <div className={sectionStyles.headText}>
          <h1>Header</h1>
          <p className={sectionStyles.headNote}>
            The bar at the top of every marketing page. Because it is not part of the home page,
            a change here shows everywhere at once.
          </p>
        </div>
      </header>

      <nav className={sectionStyles.tabs} aria-label="Header sections">
        <button
          type="button"
          className={`${sectionStyles.tab} ${tab === "settings" ? sectionStyles.tabActive : ""}`}
          onClick={() => setTab("settings")}
        >
          Wordmark and search
        </button>
        <button
          type="button"
          className={`${sectionStyles.tab} ${tab === "links" ? sectionStyles.tabActive : ""}`}
          onClick={() => setTab("links")}
        >
          Links
        </button>
      </nav>

      {failure ? (
        <ErrorState message={failure} onRetry={() => setVersion((n) => n + 1)} />
      ) : null}

      {tab === "settings" ? (
        settings === null && !failure ? (
          <Skeleton rows={4} />
        ) : settings ? (
          <BlockForm
            endpoint="/api/admin/settings"
            fields={HEADER_SETTINGS_FIELDS}
            initial={settings}
            /* The rest of the row travels with every save. Sending only the
               three fields above would blank the footer's contact details,
               because the settings endpoint replaces the row. */
            hidden={{
              legal_name: settings.legal_name,
              address: settings.address,
              phone: settings.phone,
              email: settings.email,
              footer_logo_media_id: settings.footer_logo_media_id,
            }}
          />
        ) : null
      ) : (
        <NavTree menuKey="header-primary" noun="link" />
      )}
    </>
  );
}
