"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { SECTION_ORDER, SECTIONS } from "@/server/cms/registry";

import styles from "./dashboard.module.css";

/**
 * Navigation, in the order the page itself is built.
 *
 * The Home page group lists the fifteen folds top to bottom exactly as they
 * render, then the screens that are not folds. That ordering is the whole
 * idea: an editor looking for "the bit with the tabs and the reports" scrolls
 * the sidebar the way they would scroll the page.
 *
 * Anything with something under it collapses, and only those things get a
 * chevron — a disclosure control on a row with nothing to disclose is a
 * promise the sidebar cannot keep. Fifteen folds plus seven other screens is
 * more than fits comfortably on a laptop, so being able to fold away the part
 * you are not working in is the difference between scanning and scrolling.
 *
 * A group containing the current screen starts open, so arriving from the
 * top-bar search reveals where you landed — but that is a default, not a
 * lock: an explicit click always wins, including collapsing the group you
 * are standing in.
 */

/** Chrome and page metadata: on every marketing route, or about the page
 *  rather than in it. None is a position on the home page. */
const SITE_WIDE = [
  { href: "/dashboard/header", label: "Header" },
  { href: "/dashboard/footer", label: "Footer" },
  { href: "/dashboard/statistics", label: "Statistics" },
  { href: "/dashboard/seo", label: "SEO" },
];

const LIBRARY = [
  { href: "/dashboard/media", label: "Media library" },
  { href: "/dashboard/navigation", label: "Navigation" },
  { href: "/dashboard/settings", label: "Settings" },
];

function Chevron({ open }: { open: boolean }) {
  return (
    <svg
      className={`${styles.chevron} ${open ? styles.chevronOpen : ""}`}
      viewBox="0 0 16 16"
      width="14"
      height="14"
      aria-hidden="true"
      focusable="false"
    >
      <path
        d="M4 6l4 4 4-4"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export default function Sidebar() {
  const pathname = usePathname();
  const [drawerOpen, setDrawerOpen] = useState(false);

  const inHome = pathname.startsWith("/dashboard/home");
  const inSiteWide = SITE_WIDE.some((i) => pathname.startsWith(i.href));
  const inLibrary = LIBRARY.some((i) => pathname.startsWith(i.href));

  /* Only groups the editor has actually clicked appear here. Everything
     else falls back to "open if you are inside it", so arriving on a screen
     from the top-bar search reveals where you landed.
     
     An explicit click then wins over that default, including collapsing the
     group you are currently in — which is the case that matters: with
     fifteen folds expanded, folding them away is how you reach Site-wide
     without scrolling. Forcing the active group open would make the one
     control an editor reaches for the one that does nothing.

     Session state, not localStorage: reading storage during the first
     render would disagree with the server's HTML and trip a hydration
     mismatch, and correcting it afterwards flickers. Client-side navigation
     keeps this, so it only resets on a hard refresh. */
  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>({});

  const isOpen = (key: string, active: boolean) => openGroups[key] ?? active;

  const toggle = (key: string, active: boolean) =>
    setOpenGroups((current) => ({ ...current, [key]: !(current[key] ?? active) }));

  const link = (href: string, label: string, exact = false) => {
    const active = exact ? pathname === href : pathname === href || pathname.startsWith(`${href}/`);

    return (
      <li key={href}>
        <Link
          href={href}
          className={`${styles.navLink} ${active ? styles.navLinkActive : ""}`}
          aria-current={active ? "page" : undefined}
        >
          {label}
        </Link>
      </li>
    );
  };

  /** A labelled run of links. The whole label toggles it. */
  const group = (
    key: string,
    label: string,
    active: boolean,
    items: { href: string; label: string }[],
  ) => {
    const open = isOpen(key, active);

    return (
      <li key={key}>
        <button
          type="button"
          className={styles.navGroupLabel}
          aria-expanded={open}
          aria-controls={`nav-group-${key}`}
          onClick={() => toggle(key, active)}
        >
          {label}
          <Chevron open={open} />
        </button>

        <div
          id={`nav-group-${key}`}
          className={`${styles.collapse} ${open ? styles.collapseOpen : ""}`}
        >
          <div className={styles.collapseInner}>
            <ul className={styles.groupList}>
              {items.map((item) => link(item.href, item.label))}
            </ul>
          </div>
        </div>
      </li>
    );
  };

  const homeOpen = isOpen("home", inHome);

  return (
    <>
      <button
        type="button"
        className={styles.drawerToggle}
        aria-expanded={drawerOpen}
        aria-controls="dashboard-nav"
        onClick={() => setDrawerOpen((current) => !current)}
      >
        {drawerOpen ? "Close menu" : "Menu"}
      </button>

      {/* Below 1024 the sidebar is a drawer over the content, so it needs a
          way out that is not the one button that opened it. Tapping away is
          what everybody tries first. Hidden at desktop widths, where the
          sidebar is part of the page rather than on top of it. */}
      {drawerOpen ? (
        <div
          className={styles.drawerScrim}
          onClick={() => setDrawerOpen(false)}
          aria-hidden="true"
        />
      ) : null}

      <nav
        id="dashboard-nav"
        className={`${styles.sidebar} ${drawerOpen ? styles.sidebarOpen : ""}`}
        aria-label="Dashboard"
      >
        <div className={styles.brand}>
          <span className={styles.brandName}>SBI Securities</span>
          <span className={styles.brandRole}>Content management</span>
        </div>

        {/* Following a link on a phone puts the drawer away: leaving it open
            over the screen the editor just asked for is a thing they would
            have to work around every time. Handled on the list rather than
            on each link so a new entry cannot forget it — and skipped for a
            chevron, which is not navigation. */}
        <ul
          className={styles.navList}
          onClick={(event) => {
            if ((event.target as HTMLElement).closest("button")) return;
            setDrawerOpen(false);
          }}
        >
          {link("/dashboard", "Overview", true)}

          {/* Home page is both a destination and a group: the label goes to
              the hub, the chevron folds the fifteen screens away. Same split
              as the site header's dropdowns, for the same reason — one
              control doing both jobs does neither predictably. */}
          <li className={styles.navGroup}>
            <span className={styles.navRow}>
              <Link
                href="/dashboard/home"
                className={`${styles.navLink} ${styles.navLinkGrow} ${
                  pathname === "/dashboard/home" ? styles.navLinkActive : ""
                }`}
                aria-current={pathname === "/dashboard/home" ? "page" : undefined}
              >
                Home page
              </Link>

              <button
                type="button"
                className={styles.navDisclosure}
                aria-expanded={homeOpen}
                aria-controls="nav-group-home"
                onClick={() => toggle("home", inHome)}
              >
                <Chevron open={homeOpen} />
                <span className="visually-hidden">
                  {homeOpen ? "Hide the home page sections" : "Show the home page sections"}
                </span>
              </button>
            </span>

            <div
              id="nav-group-home"
              className={`${styles.collapse} ${homeOpen ? styles.collapseOpen : ""}`}
            >
              <div className={styles.collapseInner}>
                <ol className={styles.foldList}>
              {SECTION_ORDER.map((key, index) => {
                const href = `/dashboard/home/${key}`;
                const active = pathname === href;

                return (
                      <li key={key}>
                        <Link
                          href={href}
                          className={`${styles.foldLink} ${active ? styles.foldLinkActive : ""}`}
                          aria-current={active ? "page" : undefined}
                        >
                          <span className={styles.foldIndex}>{index + 1}</span>
                          {SECTIONS[key].label}
                        </Link>
                      </li>
                );
              })}
                </ol>
              </div>
            </div>
          </li>

          {group("site", "Site-wide", inSiteWide, SITE_WIDE)}
          {group("library", "Library", inLibrary, LIBRARY)}
        </ul>
      </nav>
    </>
  );
}
