"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";

import { api } from "@/lib/apiClient";
import { CONTENT_PAGE_ORDER, CONTENT_PAGES } from "@/server/cms/pages";
import { SECTIONS, SECTION_ORDER } from "@/server/cms/registry";

import styles from "./dashboard.module.css";

/**
 * The sticky bar above the content — Mosaic puts one here, and the reference
 * fills its left side with a search field.
 *
 * Ours searches. A box that looked like search and did nothing would be the
 * worst kind of borrowed detail, so this one jumps to a screen: type three
 * letters of a fold and press Enter. Nineteen destinations is small enough
 * to filter in the browser, so it costs no request.
 */

interface TopbarProps {
  user: { fullName: string; username: string; role: string };
}

interface Destination {
  label: string;
  href: string;
  group: string;
}

const CHROME: Destination[] = [
  { label: "Overview", href: "/dashboard", group: "Dashboard" },
  { label: "Home page", href: "/dashboard/home", group: "Dashboard" },
  { label: "Header", href: "/dashboard/header", group: "Site-wide" },
  { label: "Footer", href: "/dashboard/footer", group: "Site-wide" },
  { label: "Statistics", href: "/dashboard/statistics", group: "Site-wide" },
  { label: "SEO", href: "/dashboard/seo", group: "Site-wide" },
  { label: "Media library", href: "/dashboard/media", group: "Library" },
  { label: "Navigation", href: "/dashboard/navigation", group: "Library" },
  { label: "Settings", href: "/dashboard/settings", group: "Library" },
];

export default function Topbar({ user }: TopbarProps) {
  const router = useRouter();
  const [term, setTerm] = useState("");
  const [open, setOpen] = useState(false);

  const destinations = useMemo<Destination[]>(
    () => [
      ...SECTION_ORDER.map((key) => ({
        label: SECTIONS[key].label,
        href: `/dashboard/home/${key}`,
        group: "Home page",
      })),
      ...CONTENT_PAGE_ORDER.flatMap((slug) => {
        const page = CONTENT_PAGES[slug];
        return [
          { label: page.label, href: `/dashboard/pages/${slug}`, group: "Pages" },
          ...page.sectionOrder.map((key) => ({
            label: `${page.label} — ${page.sections[key]?.label ?? SECTIONS[key]?.label ?? key}`,
            href: `/dashboard/pages/${slug}/${key}`,
            group: page.label,
          })),
          { label: `${page.label} — SEO`, href: `/dashboard/pages/${slug}/seo`, group: page.label },
        ];
      }),
      ...CHROME,
    ],
    [],
  );

  const matches = useMemo(() => {
    const needle = term.trim().toLowerCase();
    if (!needle) return [];
    return destinations.filter((d) => d.label.toLowerCase().includes(needle)).slice(0, 7);
  }, [term, destinations]);

  function go(href: string) {
    setTerm("");
    setOpen(false);
    router.push(href);
  }

  async function signOut() {
    await api.post("/api/auth/logout");
    router.push("/login");
    router.refresh();
  }

  const initials = user.fullName
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();

  return (
    <header className={styles.topbar}>
      <div className={styles.jump}>
        <input
          className={styles.jumpInput}
          type="search"
          placeholder="Jump to a screen"
          aria-label="Jump to a screen"
          value={term}
          onChange={(event) => {
            setTerm(event.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          /* A blur that fires before the click would close the list out from
             under the pointer, so closing waits a frame. */
          onBlur={() => window.setTimeout(() => setOpen(false), 120)}
          onKeyDown={(event) => {
            if (event.key === "Enter" && matches[0]) go(matches[0].href);
            if (event.key === "Escape") setOpen(false);
          }}
        />

        {open && matches.length > 0 ? (
          <ul className={styles.jumpList}>
            {matches.map((match) => (
              <li key={match.href}>
                <button type="button" className={styles.jumpItem} onClick={() => go(match.href)}>
                  <span>{match.label}</span>
                  <span className={styles.jumpGroup}>{match.group}</span>
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>

      <div className={styles.who}>
        <span className={styles.avatar} aria-hidden="true">
          {initials}
        </span>
        <span className={styles.whoText}>
          <span className={styles.whoName}>{user.fullName}</span>
          <span className={styles.whoMeta}>
            {user.username ? `Username ${user.username}` : user.role}
          </span>
        </span>
        <button type="button" className={styles.signOut} onClick={signOut}>
          Sign out
        </button>
      </div>
    </header>
  );
}
