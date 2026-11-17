/**
 * What the inner pages (About, Leadership, Sector) contain.
 *
 * The home folds are described in registry.ts, one stored-function family each.
 * These pages are stored generically — cms.content_blocks (one object per
 * section) and cms.content_items (rows of a named collection) — so what a
 * section *is* lives here and nowhere in SQL: the same field list drives
 *
 *   - the dashboard, which renders one labelled input per field,
 *   - the Go API, which validates and stores exactly those fields (the file
 *     registry.json is generated from this one by scripts/sync-registry.mjs),
 *   - the seed generator, which names the keys it writes.
 *
 * Field `name`s are the keys stored in `data` and the keys the public site
 * reads, so renaming one is a content migration. A name ending in `_media`
 * holds a media-library id; the public payload swaps it for the image object
 * under the name without the suffix (`photo_media` -> `photo`).
 *
 * Two kinds of section appear in a page's order:
 *   - sections defined here (`about-hero`, `leaders` …), stored generically;
 *   - the home folds that are reused as they are (`faq`, `app-promo`,
 *     `sticky-nudge`, `research`). Their tables hang off the section row, so a
 *     page that has such a section edits it through the registry.ts definition.
 *
 * Free of `server-only`, like registry.ts: the dashboard's client components
 * import it for the field lists. No secrets, no database access.
 */

import type { FieldDef } from "./registry";

/* --- shapes ---------------------------------------------------------------- */

export interface ContentCollection {
  /** The URL segment and the key in the public payload's `collections`. */
  readonly key: string;
  readonly label: string;
  /** What one row is called in the UI ("a leader", "an award"). */
  readonly noun: string;
  readonly fields: readonly FieldDef[];
  /**
   * The field whose value is also stored as the row's stable `item_key` (a
   * slug, or 'board' / 'nse'). The site looks rows up by it, never by
   * position, so reordering in the dashboard cannot change what a row means.
   */
  readonly keyField?: string;
}

export interface ContentSection {
  readonly key: string;
  readonly label: string;
  /** Fields of the section itself (title, button labels …). Empty if none. */
  readonly block: readonly FieldDef[];
  readonly collections: readonly ContentCollection[];
}

export interface PageDef {
  readonly slug: string;
  readonly label: string;
  readonly route: string;
  /** Section keys in render order, content sections and reused folds alike. */
  readonly sectionOrder: readonly string[];
  /** Only the sections stored generically; reused home folds are not listed. */
  readonly sections: Readonly<Record<string, ContentSection>>;
}

/* --- field helpers --------------------------------------------------------- */

const text = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "text",
  ...o,
});
const area = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "textarea",
  ...o,
});
const lines = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "lines",
  ...o,
});
const href = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "href",
  ...o,
});
const num = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "number",
  ...o,
});
const media = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "media",
  ...o,
});
const slug = (name: string, label: string, o: Partial<FieldDef> = {}): FieldDef => ({
  name,
  label,
  kind: "slug",
  ...o,
});
const pick = (
  name: string,
  label: string,
  options: readonly string[],
  o: Partial<FieldDef> = {},
): FieldDef => ({ name, label, kind: "select", options, ...o });
const multi = (
  name: string,
  label: string,
  options: readonly string[],
  o: Partial<FieldDef> = {},
): FieldDef => ({ name, label, kind: "multiselect", options, ...o });

/** A trail crumb. The last one is the current page and normally has no link. */
const BREADCRUMB: ContentCollection = {
  key: "items",
  label: "Breadcrumb trail",
  noun: "a crumb",
  fields: [
    text("label", "Label", { required: true, max: 80 }),
    href("href", "Link", { help: "Leave empty for the current page." }),
  ],
};

const breadcrumbs = (label = "Breadcrumbs"): ContentSection => ({
  key: "breadcrumbs",
  label,
  block: [],
  collections: [BREADCRUMB],
});

/* --- About ---------------------------------------------------------------- */

const ABOUT: PageDef = {
  slug: "about",
  label: "About us",
  route: "/about",
  sectionOrder: [
    "breadcrumbs",
    "about-hero",
    "about-who",
    "about-mission-vision",
    "about-values",
    "about-awards",
    "about-csr",
    "about-life",
    "faq",
    "app-promo",
    "sticky-nudge",
  ],
  sections: {
    breadcrumbs: breadcrumbs(),

    "about-hero": {
      key: "about-hero",
      label: "Hero banner",
      block: [
        text("title", "Title", { required: true, max: 120 }),
        area("subtext", "Sub-text", {
          max: 400,
          help: "A line break after “with” matches the design; the page wraps it to the column anyway.",
        }),
        text("mobile_label", "Mobile field — label", { max: 120 }),
        text("mobile_placeholder", "Mobile field — placeholder", { max: 200 }),
        text("mobile_help", "Mobile field — help text", { max: 300 }),
        text("name_label", "Name field — label", { max: 120 }),
        text("name_placeholder", "Name field — placeholder", { max: 200 }),
        text("consent_label", "Consent text", { max: 300 }),
        text("submit_label", "Submit button", { max: 120 }),
      ],
      collections: [
        {
          key: "products",
          label: "Product tiles in the phone",
          noun: "a product tile",
          keyField: "key",
          fields: [
            slug("key", "Key", {
              required: true,
              help: "Names the built-in icon when no image is chosen (stocks, futures, mutual-funds, option-arena, etf, ideas, home-loan, car-loan, sbi-cards).",
            }),
            text("label", "Label", { required: true, max: 60, help: "Use a line break (Enter) to split a long label." }),
            text("badge", "Badge", { max: 12, help: "“New”, or empty for none." }),
            media("icon_media", "Icon"),
          ],
        },
      ],
    },

    "about-who": {
      key: "about-who",
      label: "Who are we?",
      block: [
        text("title", "Title", { required: true, max: 120 }),
        lines("paragraphs", "Paragraphs", { help: "One paragraph per line." }),
      ],
      collections: [],
    },

    "about-mission-vision": {
      key: "about-mission-vision",
      label: "Mission & Vision",
      block: [],
      collections: [
        {
          key: "statements",
          label: "Statements",
          noun: "a statement",
          keyField: "key",
          fields: [
            slug("key", "Key", { required: true, help: "mission or vision." }),
            text("label", "Label", { required: true, max: 60 }),
            area("statement", "Statement", { required: true, max: 400 }),
            num("rest_letters", "Letters highlighted at rest", {
              help: "How many letters are already dark before the visitor scrolls (the design starts the Mission at 12).",
            }),
          ],
        },
      ],
    },

    "about-values": {
      key: "about-values",
      label: "Our values",
      block: [text("title", "Section title", { required: true, max: 120 })],
      collections: [
        {
          key: "values",
          label: "Value cards",
          noun: "a value card",
          keyField: "key",
          fields: [
            slug("key", "Key", {
              required: true,
              help: "Picks the card colour and built-in icon: service, transparency, ethics, politeness, sustainability.",
            }),
            text("title", "Title", { required: true, max: 80 }),
            area("body", "Body", { required: true, max: 600 }),
            media("icon_media", "Icon"),
          ],
        },
      ],
    },

    "about-awards": {
      key: "about-awards",
      label: "Awards & Recognitions",
      block: [text("title", "Section title", { required: true, max: 120 })],
      collections: [
        {
          key: "awards",
          label: "Awards",
          noun: "an award",
          fields: [
            text("title", "Title", { required: true, max: 120, help: "Use a line break (Enter) where the design breaks the title." }),
            area("text", "Description", { max: 300 }),
            media("logo_media", "Logo"),
          ],
        },
      ],
    },

    "about-csr": {
      key: "about-csr",
      label: "CSR Activities",
      block: [text("title", "Section title", { required: true, max: 120 })],
      collections: [
        {
          key: "activities",
          label: "Activities",
          noun: "an activity",
          keyField: "key",
          fields: [
            slug("key", "Key", { help: "Optional handle, e.g. tata-memorial." }),
            text("title", "Title", { required: true, max: 80 }),
            area("text", "Description", { max: 400, help: "Shown under the card while it is the active one." }),
            media("image_media", "Photo"),
          ],
        },
      ],
    },

    "about-life": {
      key: "about-life",
      label: "Life at SSL",
      block: [
        text("title", "Title", { required: true, max: 120 }),
        text("subtext", "Sub-text", { max: 300 }),
        text("cta_label", "Button label", { max: 80 }),
        href("cta_href", "Button link"),
        text("read_more_label", "“Read more” label", { max: 40 }),
        text("view_less_label", "“View less” label", { max: 40 }),
        num("auto_advance_seconds", "Slides change every (seconds)", { help: "The design uses 60." }),
      ],
      collections: [
        {
          key: "slides",
          label: "Slides",
          noun: "a slide",
          fields: [
            text("title", "Title", { required: true, max: 80 }),
            area("body", "Story", { required: true, max: 2000 }),
            media("photo_media", "Front photo"),
            media("back_photo_media", "Photo behind (tilted)"),
          ],
        },
      ],
    },
  },
};

/* --- Leadership ----------------------------------------------------------- */

const LEADER_GROUPS = ["board", "managing"] as const;

const LEADERSHIP: PageDef = {
  slug: "leadership",
  label: "Leadership",
  route: "/leadership",
  sectionOrder: [
    "breadcrumbs",
    "detail-breadcrumbs",
    "leadership-banner",
    "leadership-tabs",
    "leaders",
    "app-promo",
    "sticky-nudge",
  ],
  sections: {
    breadcrumbs: breadcrumbs("Breadcrumbs — listing"),

    "detail-breadcrumbs": {
      key: "detail-breadcrumbs",
      label: "Breadcrumbs — leader page",
      block: [],
      collections: [BREADCRUMB],
    },

    "leadership-banner": {
      key: "leadership-banner",
      label: "Banner",
      block: [text("heading", "Heading", { required: true, max: 160 })],
      collections: [],
    },

    "leadership-tabs": {
      key: "leadership-tabs",
      label: "Tabs",
      block: [text("tabs_label", "Tabs accessible name", { max: 80 })],
      collections: [
        {
          key: "tabs",
          label: "Tabs",
          noun: "a tab",
          keyField: "key",
          fields: [
            pick("key", "Key", LEADER_GROUPS, { required: true, help: "Leaders are assigned to these keys." }),
            text("label", "Label", { required: true, max: 60 }),
          ],
        },
      ],
    },

    leaders: {
      key: "leaders",
      label: "Leaders",
      block: [],
      collections: [
        {
          key: "leaders",
          label: "Leaders",
          noun: "a leader",
          keyField: "slug",
          fields: [
            slug("slug", "URL slug", {
              required: true,
              max: 80,
              help: "The leader's page is /leadership/<slug>. Changing it changes that address.",
            }),
            text("name", "Name", { required: true, max: 120 }),
            text("role", "Role", { required: true, max: 200 }),
            multi("groups", "Shown under", LEADER_GROUPS, { help: "Tick every tab this leader appears on." }),
            media("photo_media", "Listing photo", { help: "Square crop on the listing." }),
            media("detail_photo_media", "Detail photo", { help: "Used on the leader's own page; falls back to the listing photo." }),
            lines("bio", "Biography", { help: "One paragraph per line. Empty = no biography text." }),
          ],
        },
      ],
    },
  },
};

/* --- Sector --------------------------------------------------------------- */

const EXCHANGES = ["nse", "bse"] as const;

const SECTOR: PageDef = {
  slug: "sector",
  label: "Sector Snapshot",
  route: "/sector",
  sectionOrder: [
    "breadcrumbs",
    "sector-snapshot",
    "sectors",
    "market-news",
    "research",
    "faq",
    "app-promo",
    "sticky-nudge",
  ],
  sections: {
    breadcrumbs: breadcrumbs(),

    "sector-snapshot": {
      key: "sector-snapshot",
      label: "Sector Snapshot — labels",
      block: [
        text("title", "Page title", { required: true, max: 120 }),
        text("table_view_label", "Table view button", { max: 60 }),
        text("card_view_label", "Card view button", { max: 60 }),
        text("heatmap_view_label", "Heatmap view button", { max: 60 }),
        text("pagination_label", "Pagination accessible name", { max: 80 }),
        num("table_page_size", "Rows per page (table)", { help: "The design shows 12." }),
        num("card_page_size", "Cards per page", { help: "The design shows 6." }),
        text("col_name", "Column — sector name", { max: 60 }),
        text("col_day_change", "Column — day change", { max: 60 }),
        text("col_stocks", "Column — number of stocks", { max: 60 }),
        text("col_adv_dec", "Column — advance / decline", { max: 60 }),
        text("col_ratio", "Column — advance / decline ratio", { max: 60 }),
        text("col_cap_pct", "Column — market cap (%)", { max: 60 }),
        text("col_cap", "Column — market cap (Cr.)", { max: 60 }),
        text("col_pe", "Column — sector PE", { max: 60 }),
        text("advance_label", "Card — advance badge", { max: 40 }),
        text("decline_label", "Card — decline badge", { max: 40 }),
        text("ratio_label", "Card — ratio prefix", { max: 40 }),
        text("day_change_label", "Card — day change label", { max: 60 }),
        text("fact_stocks", "Card — stocks label", { max: 60, help: "Use a line break (Enter) to wrap the label as the design does." }),
        text("fact_cap_pct", "Card — market cap (%) label", { max: 60 }),
        text("fact_cap", "Card — market cap (Cr) label", { max: 60 }),
        text("fact_pe", "Card — sector PE label", { max: 60 }),
      ],
      collections: [
        {
          key: "tabs",
          label: "Tabs",
          noun: "a tab",
          keyField: "key",
          fields: [
            pick("key", "Key", ["overview", "performance"], { required: true }),
            text("label", "Label", { required: true, max: 60 }),
          ],
        },
        {
          key: "exchanges",
          label: "Exchange filters",
          noun: "a filter",
          keyField: "key",
          fields: [
            pick("key", "Key", ["all", ...EXCHANGES], { required: true }),
            text("label", "Label", { required: true, max: 40 }),
          ],
        },
      ],
    },

    sectors: {
      key: "sectors",
      label: "Sectors",
      block: [],
      collections: [
        {
          key: "sectors",
          label: "Sectors",
          noun: "a sector",
          fields: [
            text("name", "Name", { required: true, max: 120 }),
            num("stocks", "Number of stocks", { required: true }),
            num("advancing", "Advancing", { required: true }),
            num("declining", "Declining", { required: true }),
            num("adv_dec_ratio", "Advance / decline ratio", { required: true }),
            num("market_cap_pct", "Market cap (%)", { required: true }),
            text("market_cap", "Market cap (display)", { required: true, max: 30, help: "Shown as typed, e.g. “80.25 Cr”." }),
            num("pe", "Sector PE", { required: true }),
            num("day_change", "Day change (%)", { required: true }),
            multi("exchanges", "Listed on", EXCHANGES),
          ],
        },
      ],
    },

    "market-news": {
      key: "market-news",
      label: "Market News",
      block: [
        text("title", "Section title", { required: true, max: 120 }),
        text("more_label", "“Read more” label", { max: 40 }),
        text("all_label", "“All news” accessible name", { max: 80 }),
        href("all_href", "“All news” link"),
      ],
      collections: [
        {
          key: "stories",
          label: "Stories",
          noun: "a story",
          fields: [
            text("title", "Headline", { required: true, max: 200 }),
            text("date", "Date", { max: 40, help: "Shown as typed, e.g. “26 Jul 2026”." }),
            text("time", "Time", { max: 40, help: "Shown as typed, e.g. “06:45 PM IST”." }),
            href("href", "Link"),
            media("image_media", "Image"),
          ],
        },
      ],
    },
  },
};

/* --- the registry ---------------------------------------------------------- */

export const CONTENT_PAGES: Readonly<Record<string, PageDef>> = {
  about: ABOUT,
  leadership: LEADERSHIP,
  sector: SECTOR,
};

export const CONTENT_PAGE_ORDER = ["about", "leadership", "sector"] as const;

export function resolvePage(slugValue: string): PageDef | undefined {
  return CONTENT_PAGES[slugValue];
}

export function resolveContentSection(page: string, section: string): ContentSection | undefined {
  return CONTENT_PAGES[page]?.sections[section];
}

export function resolveContentCollection(
  page: string,
  section: string,
  collection: string,
): ContentCollection | undefined {
  return resolveContentSection(page, section)?.collections.find((c) => c.key === collection);
}
