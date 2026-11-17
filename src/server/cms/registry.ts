/**
 * The one description of what the home page's folds contain.
 *
 * Two things read this file and they must never disagree:
 *
 *   - the API, which turns `/api/admin/home/<section>/<collection>` into a
 *     stored-function call, and
 *   - the dashboard, which decides from it which tabs a section screen shows
 *     and which inputs each drawer renders.
 *
 * Keeping them in one table is the point. A screen that offers a field the API
 * will not save, or an API that accepts one no screen can set, is the failure
 * this prevents.
 *
 * It is also the security boundary for the two dynamic path segments. Neither
 * `[section]` nor `[collection]` is ever interpolated into SQL: they are keys
 * into this object, and a pair that is not here is a 404 before the database
 * is touched. `fnPrefix` is a literal written in this file, so the function
 * name `callFunction` receives is always one of a fixed set — which is what
 * makes its `^cms\.[a-z_]+$` guard a second lock rather than the only one.
 *
 * This module is deliberately free of `server-only`: the dashboard's client
 * components import the field definitions to build their forms. It contains no
 * secrets and no database access — only names and labels.
 */

/* --- field descriptions --------------------------------------------------- */

export type FieldKind =
  | "text"
  | "textarea"
  | "lines"
  | "slug"
  /* A link. Validated for scheme, not just length: a `javascript:` href
     stored here would execute on the public site. */
  | "href"
  | "number"
  | "boolean"
  | "media"
  | "date"
  | "datetime"
  | "select"
  /* Several options at once, stored as a list of the chosen option strings.
     Used by the inner pages (a leader's tabs, a sector's exchanges). */
  | "multiselect";

export interface FieldDef {
  /** Matches the stored function's parameter, minus the `p_` prefix. */
  readonly name: string;
  readonly label: string;
  readonly kind: FieldKind;
  readonly required?: boolean;
  /** For `select`. The stored function constrains the same set. */
  readonly options?: readonly string[];
  readonly help?: string;
  readonly max?: number;
}

/**
 * How a row's parent is found.
 *
 *   section — the fold's own `page_sections` row; the API resolves it
 *   tab / card / plan / hero — an id the caller supplies, belonging to a row
 *     the same screen listed a moment earlier
 *   none — a global list with no parent (the footer's legal blocks, the stock
 *     index) which lists and reorders across the whole table
 */
export type ParentKind = "section" | "tab" | "card" | "plan" | "hero" | "none";

export interface CollectionDef {
  /** The URL segment, and the dashboard tab's identity. */
  readonly key: string;
  readonly label: string;
  /** `cms.<fnPrefix>_create`, `_get`, `_list`, `_update`, `_delete`, … */
  readonly fnPrefix: string;
  readonly parent: ParentKind;
  readonly fields: readonly FieldDef[];
  /**
   * Argument order for `_create`, after the parent id. Written out rather than
   * derived, because `_create` and `_update` genuinely differ: a key chosen
   * once at creation comes first, `display_order` comes last, and news puts
   * `is_lead` in the middle of one and not in the other. Deriving one from the
   * other would be guessing at the SQL from the TypeScript.
   */
  readonly createArgs: readonly string[];
  /** Argument order for `_update`, after the id. */
  readonly updateArgs: readonly string[];
  /** Extra verbs beyond the seven, e.g. news's single lead item. */
  readonly extraActions?: readonly string[];
}

export interface SectionDef {
  readonly key: string;
  readonly label: string;
  /** False for folds whose shell is not a `section_blocks` row. */
  readonly hasBlock: boolean;
  readonly collections: readonly CollectionDef[];
  /** A singleton edited on the Section tab instead of a collection. */
  readonly singleton?: "sticky-nudge" | "hero";
}

/* --- fields used by more than one collection ------------------------------ */

const DISPLAY_ORDER = "display_order";

const f = {
  title: { name: "title", label: "Title", kind: "text", required: true },
  lede: { name: "lede", label: "Lede", kind: "textarea" },
  href: { name: "href", label: "Link", kind: "href" },
  ctaLabel: { name: "cta_label", label: "Button label", kind: "text" },
  ctaHref: { name: "cta_href", label: "Button link", kind: "href" },
} as const satisfies Record<string, FieldDef>;

/* --- the folds ------------------------------------------------------------ */

const HERO: SectionDef = {
  key: "hero",
  label: "Hero",
  hasBlock: false,
  singleton: "hero",
  collections: [
    {
      key: "lines",
      label: "Rotating lines",
      fnPrefix: "hero_line",
      parent: "hero",
      fields: [
        { name: "line_1", label: "First line", kind: "text", required: true },
        { name: "line_2", label: "Second line", kind: "text" },
      ],
      createArgs: ["line_1", "line_2"],
      updateArgs: ["line_1", "line_2"],
    },
    {
      key: "kpis",
      label: "KPI tiles",
      fnPrefix: "hero_kpi",
      parent: "hero",
      fields: [
        {
          name: "kpi_key",
          label: "Key",
          kind: "slug",
          required: true,
          help: "Set once. The public payload keys the tile by this.",
        },
        {
          name: "kind",
          label: "Ornament",
          kind: "select",
          options: ["value", "rating", "logo"],
          required: true,
          help: "Plain value, a rating star, or the SBI lockup.",
        },
        { name: "value", label: "Value", kind: "text", help: "Blank is allowed only for a logo tile." },
        { name: "label", label: "Label", kind: "text", required: true },
        { name: "icon_media_id", label: "Icon", kind: "media" },
      ],
      createArgs: ["kpi_key", "kind", "value", "label", "icon_media_id"],
      /* kpi_key and kind are creation-time decisions; hero_kpi_update takes
         neither, so neither appears here. */
      updateArgs: ["value", "label", "icon_media_id"],
    },
  ],
};

const MARKET_PULSE: SectionDef = {
  key: "market-pulse",
  label: "Market Pulse",
  hasBlock: true,
  collections: [
    {
      key: "tickers",
      label: "Ticker rows",
      fnPrefix: "ticker",
      parent: "section",
      fields: [
        { name: "name", label: "Instrument", kind: "text", required: true },
        { name: "price", label: "Price", kind: "text" },
        { name: "change", label: "Change", kind: "text" },
        {
          name: "direction",
          label: "Direction",
          kind: "select",
          options: ["up", "down"],
          required: true,
          help: "Chooses the up or down caret.",
        },
      ],
      createArgs: ["name", "price", "change", "direction", DISPLAY_ORDER],
      updateArgs: ["name", "price", "change", "direction"],
    },
  ],
};

const BENTO: SectionDef = {
  key: "bento",
  label: "Explore our world",
  hasBlock: true,
  collections: [
    {
      key: "cards",
      label: "Cards",
      fnPrefix: "bento_card",
      parent: "section",
      fields: [
        { name: "card_key", label: "Key", kind: "slug", required: true },
        {
          name: "title_lines",
          label: "Title lines",
          kind: "lines",
          help: "The design breaks these deliberately — one line per row.",
        },
        f.href,
        { name: "leverage_upto", label: "Leverage — lead word", kind: "text" },
        { name: "leverage_value", label: "Leverage — value", kind: "text" },
        { name: "leverage_label", label: "Leverage — label", kind: "text" },
        { name: "art_media_id", label: "Artwork", kind: "media" },
        { name: "art_secondary_media_id", label: "Second artwork", kind: "media" },
      ],
      createArgs: [
        "card_key",
        "title_lines",
        "href",
        "leverage_upto",
        "leverage_value",
        "leverage_label",
        "art_media_id",
        "art_secondary_media_id",
        DISPLAY_ORDER,
      ],
      updateArgs: [
        "title_lines",
        "href",
        "leverage_upto",
        "leverage_value",
        "leverage_label",
        "art_media_id",
        "art_secondary_media_id",
      ],
    },
    {
      key: "stats",
      label: "Stats",
      fnPrefix: "stat",
      parent: "section",
      fields: [
        { name: "value", label: "Value", kind: "text", required: true },
        { name: "label", label: "Label", kind: "text" },
        { name: "label_lines", label: "Label lines", kind: "lines" },
        { name: "description", label: "Description", kind: "textarea" },
        { name: "icon_media_id", label: "Icon", kind: "media" },
        { name: "owner_key", label: "Group", kind: "slug", help: "Groups stats on the Statistics screen." },
      ],
      createArgs: [
        "value",
        "label",
        "label_lines",
        "description",
        "icon_media_id",
        "owner_key",
        DISPLAY_ORDER,
      ],
      updateArgs: ["value", "label", "label_lines", "description", "icon_media_id"],
    },
  ],
};

/** The tab strip five folds share. Identical everywhere but Platform. */
function tabsCollection(withTransition = false): CollectionDef {
  const fields: FieldDef[] = [
    { name: "tab_key", label: "Key", kind: "slug", required: true },
    { name: "label", label: "Label", kind: "text", required: true },
  ];

  if (withTransition) {
    fields.push(
      {
        name: "transition_duration_ms",
        label: "Panel transition (ms)",
        kind: "number",
        help: "Read off the Figma Smart Animate reaction for this tab.",
      },
      { name: "transition_easing", label: "Panel easing", kind: "text" },
    );
  }

  /* The argument lists do not vary: cms.tab_create and cms.tab_update take the
     transition columns for every section. Only Platform *shows* them, because
     only Platform's panels animate — the rest would be two inputs that change
     nothing. */
  return {
    key: "tabs",
    label: "Tabs",
    fnPrefix: "tab",
    parent: "section",
    fields,
    createArgs: ["tab_key", "label", "transition_duration_ms", "transition_easing", DISPLAY_ORDER],
    updateArgs: ["label", "transition_duration_ms", "transition_easing"],
  };
}

const IPOS: SectionDef = {
  key: "ipos",
  label: "IPOs",
  hasBlock: true,
  collections: [
    tabsCollection(),
    {
      key: "items",
      label: "IPOs",
      fnPrefix: "ipo",
      parent: "tab",
      fields: [
        { name: "name", label: "Company", kind: "text", required: true },
        { name: "status", label: "Status", kind: "text" },
        { name: "date_range", label: "Date range", kind: "text" },
        { name: "price_band", label: "Price band", kind: "text" },
        { name: "issue_size", label: "Issue size", kind: "text" },
        { name: "min_investment", label: "Minimum investment", kind: "text" },
        { name: "min_investment_unit", label: "Minimum investment unit", kind: "text" },
        { name: "listing_note", label: "Listing note", kind: "text" },
        { name: "listing_date", label: "Listing date", kind: "text" },
        { name: "closing_note", label: "Closing note", kind: "text" },
        { name: "closing_date", label: "Closing date", kind: "text" },
        { name: "apply_label", label: "Apply button", kind: "text" },
        { name: "know_more_label", label: "Know more button", kind: "text" },
        { name: "apply_href", label: "Apply link", kind: "href" },
        { name: "know_more_href", label: "Know more link", kind: "href" },
      ],
      createArgs: [
        "name",
        "status",
        "date_range",
        "price_band",
        "issue_size",
        "min_investment",
        "min_investment_unit",
        "listing_note",
        "listing_date",
        "closing_note",
        "closing_date",
        "apply_label",
        "know_more_label",
        "apply_href",
        "know_more_href",
        DISPLAY_ORDER,
      ],
      updateArgs: [
        "name",
        "status",
        "date_range",
        "price_band",
        "issue_size",
        "min_investment",
        "min_investment_unit",
        "listing_note",
        "listing_date",
        "closing_note",
        "closing_date",
        "apply_label",
        "know_more_label",
        "apply_href",
        "know_more_href",
      ],
    },
  ],
};

const OFFERINGS: SectionDef = {
  key: "offerings",
  label: "Fund It, Protect It",
  hasBlock: true,
  collections: [
    tabsCollection(),
    {
      key: "cards",
      label: "Cards",
      fnPrefix: "offering",
      parent: "tab",
      fields: [
        { name: "slug", label: "Slug", kind: "slug", required: true },
        f.title,
        f.lede,
        {
          name: "highlight_lead",
          label: "Highlight lead-in",
          kind: "text",
          help: "The plain run before the emphasised claim.",
        },
        { name: "highlight", label: "Highlight", kind: "text" },
        f.ctaLabel,
        { name: "cta_label_mobile", label: "Button label (mobile)", kind: "text" },
        f.ctaHref,
        {
          name: "mobile_order",
          label: "Mobile order",
          kind: "number",
          help: "Below 767 the cards run in this order instead.",
        },
        { name: "art_media_id", label: "Artwork", kind: "media" },
        { name: "art_mobile_media_id", label: "Artwork (mobile)", kind: "media" },
      ],
      createArgs: [
        "slug",
        "title",
        "lede",
        "highlight_lead",
        "highlight",
        "cta_label",
        "cta_label_mobile",
        "cta_href",
        "mobile_order",
        "art_media_id",
        "art_mobile_media_id",
        DISPLAY_ORDER,
      ],
      updateArgs: [
        "title",
        "lede",
        "highlight_lead",
        "highlight",
        "cta_label",
        "cta_label_mobile",
        "cta_href",
        "mobile_order",
        "art_media_id",
        "art_mobile_media_id",
      ],
    },
  ],
};

const PURPOSE: SectionDef = {
  key: "purpose",
  label: "Invest with a purpose",
  hasBlock: true,
  collections: [
    {
      key: "cards",
      label: "Cards",
      fnPrefix: "purpose_card",
      parent: "section",
      fields: [
        { name: "slug", label: "Slug", kind: "slug", required: true },
        f.title,
        f.lede,
        f.ctaLabel,
        f.ctaHref,
        { name: "art_media_id", label: "Artwork", kind: "media" },
      ],
      createArgs: ["slug", "title", "lede", "cta_label", "cta_href", "art_media_id", DISPLAY_ORDER],
      updateArgs: ["title", "lede", "cta_label", "cta_href", "art_media_id"],
    },
    {
      key: "points",
      label: "Card points",
      fnPrefix: "purpose_point",
      parent: "card",
      fields: [{ name: "text", label: "Point", kind: "text", required: true }],
      createArgs: ["text", DISPLAY_ORDER],
      updateArgs: ["text"],
    },
  ],
};

const PLATFORM: SectionDef = {
  key: "platform",
  label: "Next-gen platform",
  hasBlock: true,
  collections: [
    tabsCollection(true),
    {
      key: "steps",
      label: "Steps",
      fnPrefix: "platform_step",
      parent: "tab",
      fields: [
        f.title,
        { name: "body", label: "Body", kind: "textarea" },
      ],
      createArgs: ["title", "body", DISPLAY_ORDER],
      updateArgs: ["title", "body"],
    },
    {
      key: "panels",
      label: "Panels",
      fnPrefix: "platform_panel",
      parent: "tab",
      fields: [
        { name: "media_id", label: "Panel image", kind: "media" },
        {
          name: "step_index",
          label: "Step",
          kind: "number",
          help: "Which step shows this panel. Zero-based.",
        },
      ],
      createArgs: ["media_id", "step_index", DISPLAY_ORDER],
      updateArgs: ["media_id", "step_index"],
    },
  ],
};

const RESEARCH: SectionDef = {
  key: "research",
  label: "Analysis you can trust",
  hasBlock: true,
  collections: [
    tabsCollection(),
    {
      key: "reports",
      label: "Reports",
      fnPrefix: "research",
      parent: "tab",
      fields: [
        f.title,
        { name: "kind", label: "Report type", kind: "text" },
        { name: "published_on", label: "Published", kind: "date" },
        f.href,
        { name: "cover_media_id", label: "Cover", kind: "media" },
      ],
      createArgs: ["title", "kind", "published_on", "href", "cover_media_id", DISPLAY_ORDER],
      updateArgs: ["title", "kind", "published_on", "href", "cover_media_id"],
    },
  ],
};

const NEWS: SectionDef = {
  key: "news",
  label: "Daily Market Digest",
  hasBlock: true,
  collections: [
    {
      key: "items",
      label: "Stories",
      fnPrefix: "news",
      parent: "section",
      fields: [
        f.title,
        { name: "published_label", label: "Timestamp", kind: "text", help: "Printed as written." },
        f.href,
        { name: "image_media_id", label: "Image", kind: "media" },
      ],
      /* is_lead is set through news_set_lead, which demotes the previous lead
         in the same statement. A plain boolean field would let two rows claim
         the lead slot. */
      createArgs: ["title", "published_label", "href", "is_lead", "image_media_id", DISPLAY_ORDER],
      updateArgs: ["title", "published_label", "href", "image_media_id"],
      extraActions: ["set_lead"],
    },
  ],
};

const LEARN: SectionDef = {
  key: "learn",
  label: "Learn before you invest",
  hasBlock: true,
  collections: [
    tabsCollection(),
    {
      key: "lessons",
      label: "Lessons",
      fnPrefix: "lesson",
      parent: "tab",
      fields: [
        f.title,
        { name: "duration", label: "Duration", kind: "text" },
        { name: "published_on", label: "Published", kind: "date" },
        f.href,
        { name: "thumbnail_media_id", label: "Thumbnail", kind: "media" },
      ],
      createArgs: ["title", "duration", "published_on", "href", "thumbnail_media_id", DISPLAY_ORDER],
      updateArgs: ["title", "duration", "published_on", "href", "thumbnail_media_id"],
    },
  ],
};

const TESTIMONIALS: SectionDef = {
  key: "testimonials",
  label: "Testimonials",
  hasBlock: true,
  collections: [
    {
      key: "items",
      label: "Testimonials",
      fnPrefix: "testimonial",
      parent: "section",
      /* No avatar: the card renders quote and author only. A control that
         changes nothing on the page is worse than no control. */
      fields: [
        { name: "quote", label: "Quote", kind: "textarea", required: true },
        { name: "author", label: "Author", kind: "text" },
      ],
      createArgs: ["quote", "author", DISPLAY_ORDER],
      updateArgs: ["quote", "author"],
    },
  ],
};

const PRICING: SectionDef = {
  key: "pricing",
  label: "Pricing",
  hasBlock: true,
  collections: [
    {
      key: "plans",
      label: "Plans",
      fnPrefix: "plan",
      parent: "section",
      fields: [
        { name: "name", label: "Plan name", kind: "text", required: true },
        { name: "price", label: "Price", kind: "text" },
        { name: "price_note", label: "Price note", kind: "text" },
        {
          name: "accent",
          label: "Accent",
          kind: "select",
          options: ["suvidha", "prozero", "women"],
          required: true,
        },
        f.ctaLabel,
        f.ctaHref,
        { name: "icon_media_id", label: "Plan icon", kind: "media" },
      ],
      createArgs: [
        "name",
        "price",
        "price_note",
        "accent",
        "cta_label",
        "cta_href",
        "icon_media_id",
        DISPLAY_ORDER,
      ],
      updateArgs: ["name", "price", "price_note", "accent", "cta_label", "cta_href", "icon_media_id"],
    },
    {
      key: "features",
      label: "Plan features",
      fnPrefix: "plan_feature",
      parent: "plan",
      fields: [{ name: "text", label: "Feature", kind: "text", required: true }],
      createArgs: ["text", DISPLAY_ORDER],
      updateArgs: ["text"],
    },
  ],
};

const FAQ: SectionDef = {
  key: "faq",
  label: "FAQ",
  hasBlock: true,
  collections: [
    {
      key: "items",
      label: "Questions",
      fnPrefix: "faq",
      parent: "section",
      fields: [
        { name: "question", label: "Question", kind: "text", required: true },
        { name: "answer", label: "Answer", kind: "textarea" },
      ],
      createArgs: ["question", "answer", DISPLAY_ORDER],
      updateArgs: ["question", "answer"],
    },
  ],
};

const APP_PROMO: SectionDef = {
  key: "app-promo",
  label: "App Download Promo",
  hasBlock: true,
  collections: [
    {
      key: "banners",
      label: "Promotional banners",
      fnPrefix: "banner",
      parent: "section",
      fields: [
        f.title,
        { name: "description", label: "Body", kind: "textarea" },
        f.ctaLabel,
        f.ctaHref,
        { name: "image_media_id", label: "Artwork", kind: "media" },
        { name: "image_mobile_media_id", label: "Artwork (mobile)", kind: "media" },
        {
          name: "starts_at",
          label: "Starts",
          kind: "datetime",
          help: "Leave blank for no start bound.",
        },
        { name: "ends_at", label: "Ends", kind: "datetime", help: "Leave blank for no end bound." },
      ],
      createArgs: [
        "title",
        "description",
        "cta_label",
        "cta_href",
        "image_media_id",
        "image_mobile_media_id",
        "starts_at",
        "ends_at",
        DISPLAY_ORDER,
      ],
      updateArgs: [
        "title",
        "description",
        "cta_label",
        "cta_href",
        "image_media_id",
        "image_mobile_media_id",
        "starts_at",
        "ends_at",
      ],
    },
  ],
};

const STICKY_NUDGE: SectionDef = {
  key: "sticky-nudge",
  label: "Sticky Nudge",
  hasBlock: false,
  singleton: "sticky-nudge",
  collections: [],
};

/* --- the fifteen folds, in page order ------------------------------------- */

export const SECTIONS: Record<string, SectionDef> = Object.fromEntries(
  [
    HERO,
    MARKET_PULSE,
    BENTO,
    IPOS,
    OFFERINGS,
    PURPOSE,
    PLATFORM,
    RESEARCH,
    NEWS,
    LEARN,
    TESTIMONIALS,
    PRICING,
    FAQ,
    APP_PROMO,
    STICKY_NUDGE,
  ].map((s) => [s.key, s]),
);

export const SECTION_ORDER: readonly string[] = [
  "hero",
  "market-pulse",
  "bento",
  "ipos",
  "offerings",
  "purpose",
  "platform",
  "research",
  "news",
  "learn",
  "testimonials",
  "pricing",
  "faq",
  "app-promo",
  "sticky-nudge",
];

/* --- collections that belong to no fold ----------------------------------- */

/**
 * The footer's own content. Reached from the Footer screen rather than the
 * home hub, because the footer renders on every marketing route and is not a
 * `page_sections` row.
 */
export const FOOTER_COLLECTIONS: readonly CollectionDef[] = [
  {
    key: "legal",
    label: "Legal blocks",
    fnPrefix: "legal",
    parent: "none",
    fields: [
      { name: "content_key", label: "Key", kind: "slug", required: true },
      { name: "name", label: "Name", kind: "text", required: true },
      { name: "body", label: "Body", kind: "textarea" },
    ],
    createArgs: ["content_key", "name", "body", DISPLAY_ORDER],
    updateArgs: ["name", "body"],
  },
  {
    key: "stock-letters",
    label: "Stock index",
    fnPrefix: "stock_letter",
    parent: "none",
    fields: [
      { name: "letter", label: "Letter", kind: "text", required: true },
      { name: "href", label: "Link", kind: "href" },
    ],
    createArgs: ["letter", "href", DISPLAY_ORDER],
    updateArgs: ["letter", "href"],
  },
  {
    key: "stock-links",
    label: "Keyword chips",
    fnPrefix: "stock_link",
    parent: "none",
    fields: [
      { name: "label", label: "Label", kind: "text", required: true },
      { name: "href", label: "Link", kind: "href" },
    ],
    createArgs: ["label", "href", DISPLAY_ORDER],
    updateArgs: ["label", "href"],
  },
];


/* --- the shells ----------------------------------------------------------- */

/**
 * `section_blocks` — the shell every fold shares.
 *
 * `title_break_after` and `subtitle_break_after` are here because
 * `SectionHead` on the public site takes them: the mobile frames break
 * several headings at a chosen word rather than letting them wrap, and
 * dropping the controls would silently change those layouts.
 */
export const BLOCK_FIELDS: readonly FieldDef[] = [
  { name: "eyebrow", label: "Eyebrow", kind: "text" },
  { name: "title", label: "Title", kind: "text" },
  {
    name: "title_lines",
    label: "Title lines",
    kind: "lines",
    help: "Use these instead of Title where the design breaks the heading itself.",
  },
  { name: "subtitle", label: "Subtitle", kind: "textarea" },
  {
    name: "subtitle_mobile",
    label: "Subtitle on mobile",
    kind: "textarea",
    help: "Leave blank to use the same subtitle at every width.",
  },
  { name: "description", label: "Description", kind: "textarea" },
  {
    name: "title_break_after",
    label: "Break title after word",
    kind: "number",
    help: "On narrow screens only. Blank means no forced break.",
  },
  { name: "subtitle_break_after", label: "Break subtitle after word", kind: "number" },
  { name: "align", label: "Alignment", kind: "select", options: ["start", "center"] },
  { name: "tone", label: "Tone", kind: "select", options: ["light", "dark"] },
  { name: "cta_label", label: "Button label", kind: "text" },
  { name: "cta_label_mobile", label: "Button label on mobile", kind: "text" },
  { name: "cta_href", label: "Button link", kind: "href" },
  { name: "cta_visible", label: "Show the button", kind: "boolean" },
  { name: "secondary_cta_label", label: "Second button label", kind: "text" },
  { name: "secondary_cta_href", label: "Second button link", kind: "href" },
  { name: "secondary_cta_visible", label: "Show the second button", kind: "boolean" },
  { name: "arrow_href", label: "Corner arrow link", kind: "href" },
  { name: "arrow_label", label: "Corner arrow description", kind: "text", help: "Read aloud by screen readers." },
  { name: "image_media_id", label: "Image", kind: "media" },
  { name: "image_mobile_media_id", label: "Image on mobile", kind: "media" },
  { name: "background_media_id", label: "Background", kind: "media" },
  { name: "background_mobile_media_id", label: "Background on mobile", kind: "media" },
  { name: "background_color", label: "Background colour", kind: "text", help: "A hex value such as #f7fbff, or blank." },
];

/** `hero_sections` — the fold with its own table rather than a shared shell. */
export const HERO_FIELDS: readonly FieldDef[] = [
  { name: "title_lead", label: "Opening words", kind: "text", help: "The fixed run before the rotating claim." },
  { name: "subtext_line_1", label: "Subtext, first line", kind: "text" },
  { name: "subtext_line_2", label: "Subtext, second line", kind: "text" },
  { name: "watermark_left", label: "Left watermark", kind: "text" },
  { name: "watermark_right", label: "Right watermark", kind: "text" },
  { name: "mockup_media_id", label: "Phone mockup", kind: "media" },
  { name: "form_name_label", label: "Name label", kind: "text" },
  { name: "form_name_placeholder", label: "Name placeholder", kind: "text" },
  { name: "form_mobile_label", label: "Mobile label", kind: "text" },
  { name: "form_mobile_placeholder", label: "Mobile placeholder", kind: "text" },
  { name: "form_mobile_help", label: "Mobile help text", kind: "text" },
  { name: "form_consent_label", label: "Consent text", kind: "textarea" },
  { name: "form_submit_label", label: "Submit button", kind: "text" },
  {
    name: "form_name_label_mobile",
    label: "Name label (mobile form)",
    kind: "text",
    help: "The mobile hero words several of these differently, so both sets are stored.",
  },
  { name: "form_name_placeholder_mobile", label: "Name placeholder (mobile form)", kind: "text" },
  { name: "form_mobile_label_mobile", label: "Mobile label (mobile form)", kind: "text" },
  { name: "form_mobile_placeholder_mobile", label: "Mobile placeholder (mobile form)", kind: "text" },
];

/** `sticky_nudge` — the bar that follows the reader down the page. */
export const STICKY_FIELDS: readonly FieldDef[] = [
  { name: "title", label: "Title", kind: "text" },
  { name: "mobile_placeholder", label: "Mobile number placeholder", kind: "text" },
  { name: "name_placeholder", label: "Name placeholder", kind: "text" },
  { name: "cta_label", label: "Button label", kind: "text" },
  { name: "cta_href", label: "Button link", kind: "href" },
];

/* --- lookups -------------------------------------------------------------- */

export function resolveSection(section: string): SectionDef | null {
  return Object.hasOwn(SECTIONS, section) ? SECTIONS[section] : null;
}

/**
 * The single gate between a URL and a stored-function name.
 *
 * `home` is accepted for the fifteen folds and `footer` for the collections
 * that hang off no fold, so both travel the same route handlers.
 */
export function resolveCollection(section: string, collection: string): CollectionDef | null {
  if (section === "footer") {
    return FOOTER_COLLECTIONS.find((c) => c.key === collection) ?? null;
  }

  const def = resolveSection(section);
  if (!def) return null;

  return def.collections.find((c) => c.key === collection) ?? null;
}

/** Looks a field up by name so a handler can coerce the value it was sent. */
export function fieldOf(def: CollectionDef, name: string): FieldDef | null {
  return def.fields.find((field) => field.name === name) ?? null;
}
