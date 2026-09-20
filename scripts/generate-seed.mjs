#!/usr/bin/env node
/**
 * Generates db/seeds/002_home_content.sql from the marketing site's own
 * constants.
 *
 *   node scripts/generate-seed.mjs
 *
 * Why generate rather than transcribe: the whole point of the seed is that the
 * public page renders identically before and after it is switched over to the
 * CMS. A hand-typed copy of 763 lines of copy would be wrong somewhere, and
 * the diff that catches it runs at the very end of the project. Reading the
 * constants directly makes the class of error impossible.
 *
 * sbi-home.ts is TypeScript and this is Node 21, which cannot import it. It is
 * transpiled with the TypeScript compiler already in devDependencies and the
 * plain JavaScript is imported from the OS temp directory — nothing is written
 * into either repository.
 *
 * Copy that lives in a component rather than in the constants file (section
 * headings, arrow labels, the footer's href rules) is duplicated below, each
 * occurrence marked with the file it was read from. Those are the only literal
 * strings in this script; everything else comes from the import.
 */

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import ts from "typescript";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SITE = process.env.SBI_SITE_DIR ?? "D:\\tmp\\sbisecurities-web-main";
const CONSTANTS = path.join(SITE, "src", "constants", "sbi-home.ts");
const OUT = path.join(ROOT, "db", "seeds", "002_home_content.sql");

/* --- load the constants --------------------------------------------------- */

async function loadConstants() {
  let source;
  try {
    source = readFileSync(CONSTANTS, "utf8");
  } catch {
    console.error(
      [
        "",
        `Could not read ${CONSTANTS}.`,
        "",
        "This script reads the marketing site's copy directly. Point it at a",
        "checkout with SBI_SITE_DIR:",
        "",
        "  SBI_SITE_DIR=/path/to/sbisecurities-web node scripts/generate-seed.mjs",
        "",
      ].join("\n"),
    );
    process.exit(1);
  }

  const js = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
  }).outputText;

  const dir = mkdtempSync(path.join(tmpdir(), "sbi-seed-"));
  const file = path.join(dir, "sbi-home.mjs");
  writeFileSync(file, js, "utf8");

  return import(pathToFileURL(file).href);
}

/* --- SQL literals --------------------------------------------------------- */

/** The only place a value becomes SQL text. Everything goes through it. */
function lit(value) {
  if (value === null || value === undefined) return "NULL";
  if (typeof value === "number") return String(value);
  if (typeof value === "boolean") return value ? "TRUE" : "FALSE";
  return `'${String(value).replace(/'/g, "''")}'`;
}

function arr(values) {
  if (!values || values.length === 0) return "'{}'";
  return `ARRAY[${values.map(lit).join(", ")}]`;
}

/** `(SELECT id FROM cms.media_assets WHERE url = '…')`, or NULL. */
function media(url) {
  if (!url) return "NULL";
  return `(SELECT id FROM cms.media_assets WHERE url = ${lit(url)})`;
}

function section(key) {
  return `cms.section_id_for('home', ${lit(key)})`;
}

/** A date the site prints as "28 July 2026" becomes a DATE the database sorts. */
function isoDate(printed) {
  const parsed = new Date(`${printed} UTC`);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString().slice(0, 10);
}

function slugify(text) {
  return text
    .toLowerCase()
    .replace(/&/g, "and")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

/* --- copy that lives in components, not in sbi-home.ts -------------------- */

/** FooterLinkGroup.tsx — reproduced so seeded hrefs equal rendered hrefs. */
const FOOTER_ROUTES = {
  "54EC Bonds": "/cgs-bond",
  "SBI Realty": "/sso-realty",
  Blogs: "/blogs",
  "Open Demat Account": "/open-account",
  "MF Returns Calculator": "/calculators",
  "SIP Calculator": "/calculators",
  "Lumpsum Calculator": "/calculators",
  "Step-up SIP Calculator": "/calculators",
  "SWP Calculator": "/calculators",
  "FD Calculator": "/calculators",
  "NPS Calculator": "/calculators",
  "Home Loan EMI Calculator": "/calculators",
  "Car Loan EMI Calculator": "/calculators",
  "CAGR Calculator": "/calculators",
  "Loan EMI Calculator": "/calculators",
  "RD Calculator": "/calculators",
  "Retirement Calculator": "/calculators",
};

function footerHref(label, group) {
  if (FOOTER_ROUTES[label]) return FOOTER_ROUTES[label];
  const slug = slugify(label);
  if (group === "LOANS") return `/loans/${slug}`;
  if (group === "INSURANCES") return `/insurance/${slug}`;
  if (group === "MARKETS") return `/markets/${slug}`;
  return `/${slug}`;
}

/**
 * The shell of each fold, as the components set it today.
 *
 * `arrowHref` is null for Learn because the component derives it from the
 * selected tab (`#learn-${tabSlug}` in LearnSection.tsx). Storing a fixed
 * value would change what the page renders, which is exactly what this seed
 * must not do; the derived link stays in the component.
 */
const BLOCKS = (C) => [
  {
    key: "market-pulse",
    title: "Market Pulse", // MarketPulse.tsx
    arrowHref: "#markets",
    arrowLabel: "All markets",
  },
  {
    key: "bento",
    title: C.BENTO.title,
    subtitle: C.BENTO.subtext,
    subtitleMobile: C.BENTO.subtextMobile,
  },
  {
    key: "ipos",
    title: "IPOs", // IposSection.tsx
    arrowHref: "#ipos",
    arrowLabel: "All IPOs",
  },
  {
    key: "offerings",
    title: "Fund It, Protect It", // OfferingsSection.tsx
    subtitle: "Financial solutions for more than just investing",
    subtitleBreakAfter: 5,
    arrowHref: "#offerings",
    arrowLabel: "All loans and insurance",
  },
  {
    key: "purpose",
    title: C.PURPOSE.title,
    subtitle: C.PURPOSE.subtext,
    titleBreakAfter: 2,
    subtitleBreakAfter: 7,
    arrowHref: "#goals",
    arrowLabel: "All investment goals",
  },
  {
    key: "platform",
    title: C.PLATFORM.title,
    subtitle: C.PLATFORM.subtext,
    titleBreakAfter: 1, // PlatformSection.tsx breaks after the first word
    subtitleBreakAfter: 7,
  },
  {
    key: "research",
    title: "Analysis you can trust", // ResearchSection.tsx
    titleBreakAfter: 2,
    arrowHref: "#research-reports",
    arrowLabel: "All research reports",
  },
  {
    key: "news",
    title: C.NEWS.title,
    subtitle: C.NEWS.subtext,
    titleBreakAfter: 2,
    arrowHref: "#news",
    arrowLabel: "All market news",
  },
  {
    key: "learn",
    title: "Learn before you invest", // LearnSection.tsx
    titleBreakAfter: 2,
    arrowHref: null,
    arrowLabel: "",
  },
  { key: "testimonials", title: "Testimonials" }, // TestimonialsSection.tsx
  {
    key: "pricing",
    title: "Pricing Plans", // PricingSection.tsx
    arrowHref: "#pricing",
    arrowLabel: "All pricing plans",
  },
  {
    key: "faq",
    title: "Frequently Asked Questions", // FaqSection.tsx
    titleBreakAfter: 2,
    ctaLabel: "View All FAQs",
    ctaHref: "#faqs",
  },
  { key: "app-promo", title: C.FOOTER_CTA.title, titleBreakAfter: 2 },
  { key: "sticky-nudge", title: C.STICKY_NUDGE.title },
];

/**
 * Media the CMS owns.
 *
 * Decorative glyphs — carets, ticks, checks, plus/minus, chevrons, the search
 * and menu icons — are not here. They are part of the component design rather
 * than content (design §9), and registering them would put controls in the
 * dashboard that change nothing an editor would recognise.
 */
const MEDIA = [
  ["/figma/header/logo-mark.svg", "svg", "SBI Securities registered mark", "brand"],
  ["/figma/footer/logo-b.svg", "svg", "SBI Securities", "brand"],
  ["/figma/footer/phone.png", "png", "", "app-promo"],
  ["/figma/market-pulse/bull-bear.svg", "svg", "", "market-pulse"],
  ["/figma/bento/margin-scale.png", "png", "", "bento"],
  ["/figma/bento/nri-globe.png", "png", "", "bento"],
  ["/figma/bento/nri-phone.png", "png", "", "bento"],
  ["/figma/bento/support-india.png", "png", "", "bento"],
  ["/figma/bento/baskets-chart.png", "png", "", "bento"],
  ["/figma/bento/baskets-phone.png", "png", "", "bento"],
  ["/figma/offerings/home-loan.svg", "svg", "", "offerings"],
  ["/figma/offerings/education-loan.svg", "svg", "", "offerings"],
  ["/figma/offerings/car-loan.svg", "svg", "", "offerings"],
  ["/figma/offerings/mobile/home-loan.svg", "svg", "", "offerings"],
  ["/figma/offerings/mobile/education-loan.svg", "svg", "", "offerings"],
  ["/figma/offerings/mobile/car-loan.svg", "svg", "", "offerings"],
  ["/figma/offerings/life-insurance.png", "png", "", "offerings"],
  ["/figma/offerings/health-insurance.png", "png", "", "offerings"],
  ["/figma/offerings/term-insurance.png", "png", "", "offerings"],
  ["/figma/purpose/retirement.png", "png", "", "purpose"],
  ["/figma/purpose/wealth.png", "png", "", "purpose"],
  ["/figma/purpose/education.png", "png", "", "purpose"],
  ["/figma/purpose/home.png", "png", "", "purpose"],
  ["/figma/platform/app-panel.png", "png", "", "platform"],
  ["/figma/platform/terminal-panel.png", "png", "", "platform"],
  ["/figma/research/report-1.png", "png", "", "research"],
  ["/figma/research/report-2.png", "png", "", "research"],
  ["/figma/research/report-3.png", "png", "", "research"],
  ["/figma/research/report-4.png", "png", "", "research"],
  ["/figma/news/lead.png", "png", "", "news"],
  ["/figma/news/item-1.png", "png", "", "news"],
  ["/figma/news/item-2.png", "png", "", "news"],
  ["/figma/news/item-3.png", "png", "", "news"],
  ["/figma/learn/lesson-1.png", "png", "", "learn"],
  ["/figma/learn/lesson-2.png", "png", "", "learn"],
  ["/figma/learn/lesson-3.png", "png", "", "learn"],
  ["/figma/learn/lesson-4.png", "png", "", "learn"],
  ["/figma/pricing/suvidha.png", "png", "", "pricing"],
  ["/figma/pricing/prozero.png", "png", "", "pricing"],
  ["/figma/pricing/women.png", "png", "", "pricing"],
  ["/figma/sticky/thea.png", "png", "", "sticky-nudge"],
];

const MIME = { svg: "image/svg+xml", png: "image/png", jpg: "image/jpeg", webp: "image/webp" };

/* --- emit ----------------------------------------------------------------- */

function build(C) {
  const out = [];
  const w = (line = "") => out.push(line);
  const heading = (text) => {
    w();
    w(`-- ${"-".repeat(74)}`);
    w(`-- ${text}`);
    w(`-- ${"-".repeat(74)}`);
  };

  w("-- ============================================================================");
  w("-- 002_home_content.sql — GENERATED. Do not edit by hand.");
  w("--");
  w("--   node scripts/generate-seed.mjs");
  w("--");
  w("-- Every string below is read from the marketing site's own source:");
  w("--   src/constants/sbi-home.ts, plus the section headings and href rules");
  w("-- that live in the components. Regenerating after a copy change keeps the");
  w("-- two in step; editing this file by hand does not.");
  w("--");
  w("-- Re-runnable. Content a fold owns is replaced wholesale rather than merged,");
  w("-- so running this again is \"put the shipped copy back\" — which is what the");
  w("-- seed is for. Media rows are upserted by URL instead, because an editor's");
  w("-- uploads live in the same table and must survive.");
  w("-- ============================================================================");
  w();
  w("SET search_path = cms, public;");
  w();
  w("BEGIN;");

  /* media ------------------------------------------------------------------ */
  heading("media — artwork the dashboard can swap; glyphs stay in the components");
  for (const [url, ext, alt, folder] of MEDIA) {
    const file = url.split("/").pop();
    w(
      `SELECT cms.media_create(${lit(url)}, ${lit(file)}, ${lit(MIME[ext])}, ` +
        `${lit(alt)}, NULL, NULL, NULL, NULL, ${lit(folder)});`,
    );
  }

  /* site settings ---------------------------------------------------------- */
  heading("site settings — BRAND, SEARCH_PLACEHOLDER");
  w(
    `SELECT cms.site_settings_update(\n` +
      `  ${lit(C.BRAND.name)},\n` +
      `  ${lit(C.BRAND.legalName)},\n` +
      `  ${lit(C.BRAND.address)},\n` +
      `  ${lit(C.BRAND.phone)},\n` +
      `  ${lit(C.BRAND.email)},\n` +
      `  ${lit(C.SEARCH_PLACEHOLDER)},\n` +
      `  ${media("/figma/header/logo-main.svg")},\n` +
      `  ${media("/figma/footer/logo-a.svg")}\n` +
      `);`,
  );

  /* footer navigation ------------------------------------------------------ */
  heading("footer navigation — FOOTER_PRIMARY, FOOTER_SECONDARY, Help & Support");
  w("-- One menu per rendered column, so the five-column band survives a reorder");
  w("-- in the dashboard. Group headings are the top-level items; their links are");
  w("-- children, which is the nesting navigation_items already supports.");
  w();
  w("INSERT INTO cms.navigation_menus (menu_key, name, location) VALUES");
  const menus = [
    ["footer-primary", "Footer — primary columns"],
    ...C.FOOTER_SECONDARY.map((_, i) => [`footer-col-${i + 1}`, `Footer — column ${i + 1}`]),
    ["footer-utility", "Footer — utility"],
  ];
  w(menus.map(([key, name]) => `  (${lit(key)}, ${lit(name)}, 'footer')`).join(",\n"));
  w("ON CONFLICT (menu_key) DO UPDATE SET name = EXCLUDED.name, location = EXCLUDED.location;");
  w();
  w("DELETE FROM cms.navigation_items");
  w(" WHERE menu_id IN (SELECT id FROM cms.navigation_menus");
  w(`                    WHERE menu_key IN (${menus.map(([k]) => lit(k)).join(", ")}));`);
  w();
  w("DO $seed$");
  w("DECLARE");
  w("  v_group BIGINT;");
  w("BEGIN");

  const emitGroup = (menuKey, group) => {
    w(`  v_group := (cms.nav_item_create(${lit(menuKey)}, ${lit(group.title)}, '#')).id;`);
    for (const label of group.links) {
      w(
        `  PERFORM cms.nav_item_create(${lit(menuKey)}, ${lit(label)}, ` +
          `${lit(footerHref(label, group.title))}, v_group);`,
      );
    }
  };

  for (const group of C.FOOTER_PRIMARY) emitGroup("footer-primary", group);
  C.FOOTER_SECONDARY.forEach((column, i) => {
    for (const group of column) emitGroup(`footer-col-${i + 1}`, group);
  });
  w("  PERFORM cms.nav_item_create('footer-utility', 'Help & Support', '/support');");
  w("END");
  w("$seed$;");

  /* section blocks --------------------------------------------------------- */
  heading("section shells — the title / subtitle / CTA every fold shares");
  for (const b of BLOCKS(C)) {
    const args = [
      `  p_page_slug           => 'home'`,
      `  p_section_key         => ${lit(b.key)}`,
      `  p_title               => ${lit(b.title ?? "")}`,
    ];
    if (b.subtitle) args.push(`  p_subtitle            => ${lit(b.subtitle)}`);
    if (b.subtitleMobile) args.push(`  p_subtitle_mobile     => ${lit(b.subtitleMobile)}`);
    if (b.titleBreakAfter) args.push(`  p_title_break_after   => ${b.titleBreakAfter}`);
    if (b.subtitleBreakAfter) args.push(`  p_subtitle_break_after => ${b.subtitleBreakAfter}`);
    if (b.ctaLabel) args.push(`  p_cta_label           => ${lit(b.ctaLabel)}`);
    if (b.ctaHref) args.push(`  p_cta_href            => ${lit(b.ctaHref)}`);
    if (b.arrowHref) args.push(`  p_arrow_href          => ${lit(b.arrowHref)}`);
    if (b.arrowLabel) args.push(`  p_arrow_label         => ${lit(b.arrowLabel)}`);
    w();
    w(`SELECT cms.section_block_update(`);
    w(args.join(",\n"));
    w(`);`);
  }

  /* market pulse ----------------------------------------------------------- */
  heading("market pulse — MARKET_PULSE");
  w(`DELETE FROM cms.ticker_items WHERE section_id = ${section("market-pulse")};`);
  C.MARKET_PULSE.forEach((t, i) => {
    w(
      `SELECT cms.ticker_create(${section("market-pulse")}, ${lit(t.name)}, ` +
        `${lit(t.price)}, ${lit(t.change)}, ${lit(t.direction)}, ${i + 1});`,
    );
  });

  /* bento ------------------------------------------------------------------ */
  heading("explore our world — BENTO");
  w("-- BENTO.marginTrading.deposit and .buyingPower are not stored: that copy is");
  w("-- baked into margin-scale.png and nothing renders the constants (design §9).");
  w(`DELETE FROM cms.bento_cards WHERE section_id = ${section("bento")};`);
  w(`DELETE FROM cms.stat_items  WHERE section_id = ${section("bento")};`);
  const bentoCards = [
    ["margin-trading", C.BENTO.marginTrading.title, "/figma/bento/margin-scale.png", null, {
      upto: C.BENTO.marginTrading.upto,
      value: C.BENTO.marginTrading.multiple,
      label: C.BENTO.marginTrading.leverage,
    }],
    ["nri", C.BENTO.nri.title, "/figma/bento/nri-globe.png", "/figma/bento/nri-phone.png", null],
    ["support", C.BENTO.support.title, "/figma/bento/support-india.png", null, null],
    ["baskets", C.BENTO.baskets.title, "/figma/bento/baskets-chart.png",
      "/figma/bento/baskets-phone.png", null],
  ];
  bentoCards.forEach(([key, lines, art, art2, lev], i) => {
    w(
      `SELECT cms.bento_card_create(${section("bento")}, ${lit(key)}, ${arr(lines)}, NULL,\n` +
        `  ${lit(lev?.upto ?? null)}, ${lit(lev?.value ?? null)}, ${lit(lev?.label ?? null)},\n` +
        `  ${media(art)}, ${media(art2)}, ${i + 1});`,
    );
  });
  C.BENTO.support.stats.forEach((s, i) => {
    w(
      `SELECT cms.stat_create(${section("bento")}, ${lit(s.value)}, ${lit(s.label.join(" "))},\n` +
        `  ${arr(s.label)}, '', NULL, 'support', ${i + 1});`,
    );
  });

  /* IPOs ------------------------------------------------------------------- */
  heading("IPOs — IPO_TABS, IPOS");
  w("-- Deleting the tabs cascades to their items, so a rerun cannot leave last");
  w("-- run's rows orphaned under a renamed tab.");
  w(`DELETE FROM cms.section_tabs WHERE section_id = ${section("ipos")};`);
  w("DO $seed$");
  w("DECLARE v_tab BIGINT;");
  w("BEGIN");
  C.IPO_TABS.forEach((label, ti) => {
    w(
      `  v_tab := (cms.tab_create(${section("ipos")}, ${lit(slugify(label))}, ` +
        `${lit(label)}, NULL, NULL, ${ti + 1})).id;`,
    );
    /* The site shows the same six cards under every tab today. */
    C.IPOS.forEach((ipo, i) => {
      w(
        `  PERFORM cms.ipo_create(v_tab, ${lit(ipo.name)}, ${lit(ipo.status)},\n` +
          `    ${lit(ipo.dateRange)}, ${lit(ipo.priceBand)}, ${lit(ipo.issueSize)},\n` +
          `    ${lit(ipo.minInvestment)}, ${lit(ipo.minInvestmentUnit)},\n` +
          `    ${lit(ipo.listingNote)}, ${lit(ipo.listingDate)},\n` +
          `    ${lit(ipo.closingNote)}, ${lit(ipo.closingDate)},\n` +
          `    'Apply', 'Know More', NULL, NULL, ${i + 1});`,
      );
    });
  });
  w("END");
  w("$seed$;");

  /* offerings -------------------------------------------------------------- */
  heading("fund it, protect it — OFFERINGS_TABS, LOANS, INSURANCE");
  w(`DELETE FROM cms.section_tabs WHERE section_id = ${section("offerings")};`);
  w("DO $seed$");
  w("DECLARE v_tab BIGINT;");
  w("BEGIN");
  [
    [C.OFFERINGS_TABS[0], C.LOANS],
    [C.OFFERINGS_TABS[1], C.INSURANCE],
  ].forEach(([label, cards], ti) => {
    w(
      `  v_tab := (cms.tab_create(${section("offerings")}, ${lit(slugify(label))}, ` +
        `${lit(label)}, NULL, NULL, ${ti + 1})).id;`,
    );
    cards.forEach((c, i) => {
      w(
        `  PERFORM cms.offering_create(v_tab, ${lit(c.slug)}, ${lit(c.title)},\n` +
          `    ${lit(c.lede)}, ${lit(c.highlightLead ?? "")}, ${lit(c.highlight)},\n` +
          `    ${lit(c.cta)}, ${lit(c.ctaMobile)}, NULL, ${c.mobileOrder},\n` +
          `    ${media(c.art)}, ${media(c.artMobile ?? null)}, ${i + 1});`,
      );
    });
  });
  w("END");
  w("$seed$;");

  /* purpose ---------------------------------------------------------------- */
  heading("invest with a purpose — PURPOSE");
  w("-- Artwork is derived from the slug today (`/figma/purpose/${slug}.png`).");
  w("-- Each card gets an explicit reference instead, so an editor can swap one");
  w("-- image without renaming a file. The files pointed at are the same ones.");
  w(`DELETE FROM cms.purpose_cards WHERE section_id = ${section("purpose")};`);
  w("DO $seed$");
  w("DECLARE v_card BIGINT;");
  w("BEGIN");
  C.PURPOSE.cards.forEach((card, i) => {
    w(
      `  v_card := (cms.purpose_card_create(${section("purpose")}, ${lit(card.slug)},\n` +
        `    ${lit(card.title)}, ${lit(card.lede)}, ${lit(card.cta)}, NULL,\n` +
        `    ${media(`/figma/purpose/${card.slug}.png`)}, ${i + 1})).id;`,
    );
    card.points.forEach((point, pi) => {
      w(`  PERFORM cms.purpose_point_create(v_card, ${lit(point)}, ${pi + 1});`);
    });
  });
  w("END");
  w("$seed$;");

  /* platform --------------------------------------------------------------- */
  heading("next-gen platform — PLATFORM, PLATFORM_TABS, PLATFORM_PANEL_TRANSITION");
  w("-- The per-tab Smart Animate timing is stored on the tab, because it differs");
  w("-- between the two and is read off the Figma reactions, not chosen here.");
  w(`DELETE FROM cms.section_tabs WHERE section_id = ${section("platform")};`);
  w("DO $seed$");
  w("DECLARE v_tab BIGINT;");
  w("BEGIN");
  C.PLATFORM_TABS.forEach((label, ti) => {
    const t = C.PLATFORM_PANEL_TRANSITION[label];
    w(
      `  v_tab := (cms.tab_create(${section("platform")}, ${lit(slugify(label))}, ` +
        `${lit(label)}, ${t ? t.durationMs : "NULL"}, ${lit(t?.easing ?? null)}, ${ti + 1})).id;`,
    );
    (C.PLATFORM.steps[label] ?? []).forEach((step, i) => {
      w(`  PERFORM cms.platform_step_create(v_tab, ${lit(step.title)}, ${lit(step.body)}, ${i + 1});`);
    });
    (C.PLATFORM.panels[label] ?? []).forEach((url, i) => {
      w(`  PERFORM cms.platform_panel_create(v_tab, ${media(url)}, ${i}, ${i + 1});`);
    });
  });
  w("END");
  w("$seed$;");

  /* research --------------------------------------------------------------- */
  heading("analysis you can trust — RESEARCH_TABS, RESEARCH");
  w("-- Cover art is picked by index today (`report-${i + 1}.png`); stored per row");
  w("-- here for the same reason as the purpose cards.");
  w(`DELETE FROM cms.section_tabs WHERE section_id = ${section("research")};`);
  w("DO $seed$");
  w("DECLARE v_tab BIGINT;");
  w("BEGIN");
  C.RESEARCH_TABS.forEach((label, ti) => {
    w(
      `  v_tab := (cms.tab_create(${section("research")}, ${lit(slugify(label))}, ` +
        `${lit(label)}, NULL, NULL, ${ti + 1})).id;`,
    );
    C.RESEARCH.forEach((r, i) => {
      w(
        `  PERFORM cms.research_create(v_tab, ${lit(r.title)}, ${lit(r.kind)},\n` +
          `    ${lit(isoDate(r.date))}, NULL, ${media(`/figma/research/report-${i + 1}.png`)}, ${i + 1});`,
      );
    });
  });
  w("END");
  w("$seed$;");

  /* news ------------------------------------------------------------------- */
  heading("your daily market digest — NEWS");
  w(`DELETE FROM cms.news_items WHERE section_id = ${section("news")};`);
  w(
    `SELECT cms.news_create(${section("news")}, ${lit(C.NEWS.lead.title)},\n` +
      `  ${lit(C.NEWS.lead.timestamp)}, NULL, TRUE, ${media("/figma/news/lead.png")}, 1);`,
  );
  C.NEWS.items.forEach((item, i) => {
    w(
      `SELECT cms.news_create(${section("news")}, ${lit(item.title)},\n` +
        `  ${lit(item.timestamp)}, NULL, FALSE, ${media(`/figma/news/item-${i + 1}.png`)}, ${i + 2});`,
    );
  });

  /* learn ------------------------------------------------------------------ */
  heading("learn before you invest — LEARN_TABS, LESSONS");
  w("-- Thumbnails cycle through four files today (`lesson-${(i % 4) + 1}.png`).");
  w(`DELETE FROM cms.section_tabs WHERE section_id = ${section("learn")};`);
  w("DO $seed$");
  w("DECLARE v_tab BIGINT;");
  w("BEGIN");
  C.LEARN_TABS.forEach((label, ti) => {
    w(
      `  v_tab := (cms.tab_create(${section("learn")}, ${lit(slugify(label))}, ` +
        `${lit(label)}, NULL, NULL, ${ti + 1})).id;`,
    );
    C.LESSONS.forEach((lesson, i) => {
      w(
        `  PERFORM cms.lesson_create(v_tab, ${lit(lesson.title)}, ${lit(lesson.duration)},\n` +
          `    ${lit(isoDate(lesson.date))}, NULL, ` +
          `${media(`/figma/learn/lesson-${(i % 4) + 1}.png`)}, ${i + 1});`,
      );
    });
  });
  w("END");
  w("$seed$;");

  /* testimonials ----------------------------------------------------------- */
  heading("testimonials — TESTIMONIALS");
  w("-- No avatar column: the card renders quote and author only (design §9).");
  w(`DELETE FROM cms.testimonials WHERE section_id = ${section("testimonials")};`);
  C.TESTIMONIALS.forEach((t, i) => {
    w(
      `SELECT cms.testimonial_create(${section("testimonials")}, ${lit(t.quote)},\n` +
        `  ${lit(t.author)}, ${i + 1});`,
    );
  });

  /* pricing ---------------------------------------------------------------- */
  heading("pricing — PLANS");
  w(`DELETE FROM cms.pricing_plans WHERE section_id = ${section("pricing")};`);
  w("DO $seed$");
  w("DECLARE v_plan BIGINT;");
  w("BEGIN");
  C.PLANS.forEach((plan, i) => {
    w(
      `  v_plan := (cms.plan_create(${section("pricing")}, ${lit(plan.name)}, ${lit(plan.price)},\n` +
        `    ${lit(plan.priceNote ?? "")}, ${lit(plan.accent)}, '', NULL,\n` +
        `    ${media(`/figma/pricing/${plan.accent}.png`)}, ${i + 1})).id;`,
    );
    plan.features.forEach((feature, fi) => {
      w(`  PERFORM cms.plan_feature_create(v_plan, ${lit(feature)}, ${fi + 1});`);
    });
  });
  w("END");
  w("$seed$;");

  /* FAQ -------------------------------------------------------------------- */
  heading("FAQ — FAQS");
  w(`DELETE FROM cms.faq_items WHERE section_id = ${section("faq")};`);
  C.FAQS.forEach((faq, i) => {
    w(
      `SELECT cms.faq_create(${section("faq")}, ${lit(faq.question)},\n` +
        `  ${lit(faq.answer)}, ${i + 1});`,
    );
  });

  /* app promo -------------------------------------------------------------- */
  heading("app download promo — FOOTER_CTA");
  w("-- The banner IS the card's content, and both window bounds are null, so the");
  w("-- fold renders exactly what it renders today while scheduling a replacement");
  w("-- becomes possible without a code change (design §8.3).");
  w(`DELETE FROM cms.promo_banners WHERE section_id = ${section("app-promo")};`);
  w(
    `SELECT cms.banner_create(${section("app-promo")}, ${lit(C.FOOTER_CTA.title)},\n` +
      `  ${lit(C.FOOTER_CTA.body)}, ${lit(C.FOOTER_CTA.cta)}, '/download-app',\n` +
      `  ${media("/figma/footer/phone.png")}, NULL, NULL, NULL, 1);`,
  );

  /* sticky nudge ----------------------------------------------------------- */
  heading("sticky nudge — STICKY_NUDGE");
  w(
    `SELECT cms.sticky_nudge_update('home', ${lit(C.STICKY_NUDGE.title)},\n` +
      `  ${lit(C.STICKY_NUDGE.mobilePlaceholder)}, ${lit(C.STICKY_NUDGE.namePlaceholder)},\n` +
      `  ${lit(C.STICKY_NUDGE.cta)}, NULL, 'sticky-nudge');`,
  );

  /* footer content --------------------------------------------------------- */
  heading("footer legal, stock index, keyword chips — FOOTER_LEGAL, STOCK_*");
  w("DELETE FROM cms.legal_content;");
  const legal = [
    ["registration-1", "Registration line 1", C.FOOTER_LEGAL.registration[0]],
    ["registration-2", "Registration line 2", C.FOOTER_LEGAL.registration[1]],
    ["trading", "Trading disclosure", C.FOOTER_LEGAL.trading],
    ["authorization", "IRDAI authorisation", C.FOOTER_LEGAL.authorization],
    ["warning", "Fraud warning", C.FOOTER_LEGAL.warning],
    ["copyright", "Copyright", C.FOOTER_LEGAL.copyright],
  ];
  legal.forEach(([key, name, body], i) => {
    w(`SELECT cms.legal_create(${lit(key)}, ${lit(name)}, ${lit(body)}, ${i + 1});`);
  });
  w();
  w("DELETE FROM cms.stock_index_letters;");
  C.STOCK_INDEX_LETTERS.forEach((letter, i) => {
    w(`SELECT cms.stock_letter_create(${lit(letter)}, ${lit(`/stocks/${letter.toLowerCase()}`)}, ${i + 1});`);
  });
  w();
  w("DELETE FROM cms.stock_links;");
  C.STOCK_LINKS.forEach((label, i) => {
    w(`SELECT cms.stock_link_create(${lit(label)}, '/stocks', ${i + 1});`);
  });

  w();
  w("COMMIT;");
  w();

  return out.join("\n");
}

/* --- run ------------------------------------------------------------------ */

const constants = await loadConstants();
const sql = build(constants);
writeFileSync(OUT, sql, "utf8");

const lines = sql.split("\n").length;
console.log(`Wrote ${path.relative(ROOT, OUT)} (${lines} lines) from ${CONSTANTS}`);
