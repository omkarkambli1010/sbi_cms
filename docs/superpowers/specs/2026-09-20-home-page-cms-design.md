# Home Page CMS — design

**Date:** 2026-09-20
**Status:** approved for planning
**Repositories:** `D:\tmp\cms-website` (the CMS), `D:\tmp\sbisecurities-web-main` (the public site)

---

## 1. Goal

Let a non-technical administrator manage every visible element of the SBI
Securities pre-login home page from a dashboard, with PostgreSQL as the source
of truth, without touching source code — and without altering the public page's
design, markup or behaviour.

## 2. Which home page

The page is `HomeComponent.tsx` in `sbisecurities-web-main`: fifteen rendered
folds plus the shared `Header` and `Footer`, with copy centralised in
`src/constants/sbi-home.ts` (763 lines) and the remainder inline in components.

`cms-website/src/app/page.tsx` renders a different, generic page — hero,
features, insights, FAQ — left over from an earlier spike against a Go API that
`CONTRACT.md` describes and that has never been switched on. It is **not** the
target and is removed in Phase 4.

## 3. What already exists in `cms-website`

Real and working:

- `db/migrations/001_schema.sql` — the `cms` schema: `admin_users`,
  `admin_sessions`, `media_assets`, `pages`, `page_sections`, `site_settings`,
  `seo_metadata`, `navigation_menus`, `navigation_items`, `hero_sections`,
  `hero_rotating_lines`, `hero_kpis`.
- `db/migrations/002_functions.sql` — 50 functions, full CRUD plus `set_active`
  and `reorder` per entity, plus `cms.public_page_payload`.
- `db/seeds/001_home.sql`, `db/setup.sql`, `scripts/db.mjs`
  (migrate / seed / reset / status / create-admin).
- `src/server/db/pool.ts` — `callFunction`, with the function name whitelisted
  against a fixed pattern and every value a bound parameter. The only place SQL
  text is built in the application.
- `src/server/auth/password.ts` (scrypt), `src/server/auth/session.ts`,
  `src/server/api/respond.ts`.

Absent, despite `docs/CONTENT-MAP.md` marking it done:

- **Every API route.** `src/app` contains only `page.tsx`, `layout.tsx`,
  `loading.tsx`, `globals.css`.
- **The entire dashboard UI.** `src/components/cms/*` holds the old demo page's
  sections, not admin screens.
- Tables and functions for fourteen of the seventeen folds.

`npm run db:status` fails with `password authentication failed for user
sbi_cms`: PostgreSQL is running but `db/setup.sql` has never been run.
Correcting `CONTENT-MAP.md`'s status marks is Phase 8.

---

## 4. Content inventory

Transcribed from the components and `sbi-home.ts`. This is the contract the
data model must satisfy: every row below must be editable from the dashboard.

### 4.1 Header (`layout/Header/Header.tsx`, every marketing route)

| Element | Source today |
| --- | --- |
| Wordmark logo | `/figma/header/logo-main.svg` |
| Registered mark | `/figma/header/logo-mark.svg` |
| Logo link target | hardcoded `/` |
| Nav items — label, href, order, active | `TOP_NAV` (5 items) |
| Search placeholder | `SEARCH_PLACEHOLDER` |
| Caret, search, menu, accessibility, headset, command glyphs | `/figma/header/*.svg` |

### 4.2 Hero (`HeroSection.tsx`, `HERO`)

Title lead · 3 rotating line-pairs · 2 subtext lines · left and right watermarks
· phone mockup · 7 desktop form labels (mobile label, placeholder and help; name
label and placeholder; consent; submit) · 4 mobile form labels · 3 KPI tiles
(value, label, ornament: plain / star / SBI lockup) · check and info glyphs.

**Already modelled** by `hero_sections`, `hero_rotating_lines`, `hero_kpis`.

### 4.3 Market Pulse (`MarketPulse.tsx`, `MARKET_PULSE`)

Heading "Market Pulse" (inline) · "All markets" arrow href · bull/bear
artwork · 4 ticker rows (name, price, change, direction up or down). Direction
picks `caret-up.svg` or `caret-down.svg`.

### 4.4 Explore our world (`BentoSection.tsx`, `BENTO`)

Title · desktop subtext · **separate** mobile subtext · four cards:

| Card | Fields |
| --- | --- |
| Margin trading | 2 title lines, "Upto" / "4x" / "Leverage" labels, scale art |
| NRI | 3 title lines, globe art + phone art |
| Support | 3 title lines, 2 stats (value + 2 label lines), India art |
| Baskets | 2 title lines, chart art + phone art |

Titles break deliberately, so they are stored as ordered lines, not one string.
Each card carries up to two artwork slots. `BENTO.marginTrading.deposit` and
`.buyingPower` exist in the constants but are **not rendered** — that copy is
baked into `margin-scale.png`. They are recorded here and excluded from the
model (§9).

### 4.5 IPOs (`IposSection.tsx`, `IPOS`, `IPO_TABS`)

`SectionHead` title "IPOs" plus an "All IPOs" arrow href · 3 tabs · per IPO:
name, status, date range, price band, issue size, min investment, min
investment unit, listing note, listing date, closing note, closing date ·
"Apply" and "Know More" button labels.

### 4.6 Fund It, Protect It (`OfferingsSection.tsx`, `LOANS`, `INSURANCE`)

Title, subtext, 2 tabs · per card: slug, title, lede, highlight lead,
highlight, desktop CTA, mobile CTA, mobile order, artwork, mobile artwork.

### 4.7 Invest with a purpose (`PurposeSection.tsx`, `PURPOSE`)

Title, subtext · per card: slug, title, lede, ordered bullet points, CTA,
artwork (currently derived from the slug), tick glyph.

### 4.8 Next-gen platform (`PlatformSection.tsx`, `PLATFORM`)

Title, subtext · 2 tabs, each with its own transition duration and easing
(`PLATFORM_PANEL_TRANSITION`) · per tab: 3 steps (title, body) and 3 panel
images.

### 4.9 Analysis you can trust (`ResearchSection.tsx`, `RESEARCH`)

Title (inline), mobile break after 2 words · 2 tabs · per report: title, kind,
date, cover image.

### 4.10 Your Daily Market Digest (`NewsSection.tsx`, `NEWS`)

Title, subtext · lead item (title, timestamp, image) · 3 list items (title,
timestamp, image).

### 4.11 Learn before you invest (`LearnSection.tsx`, `LESSONS`)

Title (inline), mobile break after 2 words · 4 tabs · per lesson: title,
duration, date, thumbnail.

### 4.12 Testimonials (`TestimonialsSection.tsx`, `TESTIMONIALS`)

Title "Testimonials" (inline) · per entry: quote, author. No image is
rendered (§9).

### 4.13 Pricing (`PricingSection.tsx`, `PLANS`)

`SectionHead` title "Pricing Plans" plus an "All pricing plans" arrow href ·
per plan: name, price, price note, accent (suvidha / prozero / women), ordered
feature list, plan icon, check glyph.

### 4.14 FAQ (`FaqSection.tsx`, `FAQS`)

Title (inline), CTA label and href, plus/minus glyphs, arrow glyph · per entry:
question, answer, order.

### 4.15 App download promo (`AppPromo.tsx`, `FOOTER_CTA`)

Title (mobile breaks after 2 words), body, CTA label, CTA href (hardcoded
`/download-app`), download glyph, handset artwork.

### 4.16 Sticky nudge (`StickyNudge.tsx`, `STICKY_NUDGE`)

Title, mobile placeholder, name placeholder, CTA label, arrow glyph.

### 4.17 Footer (`layout/Footer/Footer.tsx`)

Logo · address · phone · e-mail · "Help & Support" link · 5 social links
(label, href, icon) · 2 primary link columns · 5 secondary columns holding 7
groups and about 60 links · "Stocks" heading · 27 index letters · 25 keyword
chips · 5 legal blocks (2 registration lines, trading, authorisation, warning,
copyright).

### 4.18 SEO (`app/(marketing)/page.tsx` metadata)

Title, description, canonical, Open Graph type, url, title, description, site
name and locale. Keywords, robots and an OG image are not present today and are
added.

---

## 5. Data model

### 5.1 Approach

Three were considered:

- **Per-fold tables throughout.** Faithful, but duplicates the same six
  title / subtitle / description / image / background / CTA columns seventeen
  times.
- **One JSONB blob per section.** Small schema, no constraints, no
  normalisation. Rejected — the requirement is normalised tables.
- **Shared section chrome plus per-fold item tables.** *Chosen.*

Every fold shares an outer shell; only its repeating rows are distinct. The
shell becomes one table, tabs become one table, and each fold contributes only
what is genuinely its own. This preserves normalisation, loses no field, and
reduces roughly 120 stored functions to about 75.

### 5.2 Conventions (inherited from `001_schema.sql`, unchanged)

Identity primary keys, never serial · `is_active` and `display_order` on every
listed row · `created_at` and `updated_at` maintained by the
`cms.touch_updated_at` trigger · text that must not be blank constrained, not
merely `NOT NULL` · every foreign key states its delete behaviour · images
referenced as a nullable `*_media_id` pointing at `cms.media_assets`, nulled
rather than cascaded on delete · ordered multi-line copy as `TEXT[]`.

### 5.3 New shared tables — `003_home_schema.sql`

**`cms.section_blocks`** — one row per `page_sections` row, `section_id`
unique. The editable shell of every fold:

- `eyebrow`, `title`, `title_lines TEXT[]`, `subtitle`, `subtitle_mobile`,
  `description`
- `title_break_after INT`, `subtitle_break_after INT`
- `align` constrained to start or center; `tone` constrained to light or dark
- `cta_label`, `cta_label_mobile`, `cta_href`, `cta_visible BOOLEAN`
- `secondary_cta_label`, `secondary_cta_href`, `secondary_cta_visible BOOLEAN`
- `arrow_href`, `arrow_label`
- `image_media_id`, `image_mobile_media_id`
- `background_media_id`, `background_mobile_media_id`
- `background_color`, constrained to a hex triplet or blank

`title_break_after` and `subtitle_break_after` exist because `SectionHead`
takes them today; omitting them would silently change the mobile layout.

**`cms.section_tabs`** — `section_id`, `tab_key`, `label`, `display_order`,
`is_active`, plus a nullable `transition_duration_ms` and `transition_easing`
used only by Platform. Serves IPO (3 tabs), Offerings (2), Platform (2),
Research (2) and Learn (4).

**`cms.stat_items`** — `section_id`, `value`, `label`, `label_lines TEXT[]`,
`description`, `icon_media_id`, order, active. Backs both the requested
Statistics screen and Bento's 20+ / 130+ branch stats.

### 5.4 New per-fold tables

| Table | Columns beyond the conventions |
| --- | --- |
| `ticker_items` | name, price, change, direction constrained to up or down |
| `bento_cards` | card_key, title_lines, leverage_upto, leverage_value, leverage_label, art_media_id, art_secondary_media_id |
| `ipo_items` | tab_id, name, status, date_range, price_band, issue_size, min_investment, min_investment_unit, listing_note, listing_date, closing_note, closing_date, apply_label, know_more_label |
| `offering_cards` | tab_id, slug, title, lede, highlight_lead, highlight, cta_label, cta_label_mobile, mobile_order, art_media_id, art_mobile_media_id |
| `purpose_cards` | slug, title, lede, cta_label, cta_href, art_media_id |
| `purpose_card_points` | card_id, text |
| `platform_steps` | tab_id, title, body |
| `platform_panels` | tab_id, media_id, step_index |
| `research_reports` | tab_id, title, kind, published_on DATE, cover_media_id |
| `news_items` | is_lead BOOLEAN, title, published_label, image_media_id |
| `lessons` | tab_id, title, duration, published_on DATE, thumbnail_media_id |
| `testimonials` | quote, author |
| `pricing_plans` | name, price, price_note, accent constrained to the three known values, icon_media_id |
| `pricing_plan_features` | plan_id, text |
| `faq_items` | question, answer |
| `promo_banners` | title, description, cta_label, cta_href, image_media_id, image_mobile_media_id, starts_at, ends_at |
| `sticky_nudge` | section_id unique, title, mobile_placeholder, name_placeholder, cta_label |
| `legal_content` | content_key, body |
| `stock_index_letters` | letter, href |
| `stock_links` | label, href |

Twenty tables plus the three shared. Footer link columns need none — the
existing `navigation_menus` and `navigation_items` pair already nests and
orders.

`promo_banners` carries the requested scheduling and holds the content of the
App Download Promo card (§8.3). A banner is served only while it is active and
`now()` falls inside its window; either bound may be null for open-ended. Where
several qualify, the lowest `display_order` wins, so scheduling never blanks
the card.

### 5.5 Images that are currently derived

Five folds pick artwork by filename convention rather than by reference —
lesson thumbnails by index, news images by index, research covers by index,
plan icons by accent, purpose art by slug. Each becomes an explicit
`*_media_id`. The seed maps every existing file to a `media_assets` row and
points the owning row at it, so rendered output is unchanged while an editor
gains the ability to swap one image without renaming files.

---

## 6. Stored functions — `004_home_functions.sql`

Every list entity gets the seven required operations: `_create`, `_get`,
`_list` (parent id plus an active-only flag), `_update`, `_delete`,
`_set_active` and `_reorder`.

Singletons — `section_blocks` and `sticky_nudge` — get `_get` and `_update`
only; `section_blocks` upserts, so a fold with no row yet edits cleanly.

`_reorder` follows the pattern already set by `cms.nav_item_reorder`: it
rejects an id array that is not exactly the parent's current id set, so a stale
dashboard cannot silently drop a row, and it renumbers inside one statement.

All functions are `SECURITY INVOKER` and take bound parameters only.

`005_public_payload.sql` replaces `cms.public_page_payload(p_page_slug)` so it
returns the whole page as one JSONB document — sections in display order,
inactive rows and out-of-window banners already filtered, media resolved to
public URLs. One round trip serves the public page.

---

## 7. API — `src/app/api/**`

Route Handlers over `callFunction` and the existing `respond.ts`. Chosen over
Server Actions because the requirement names CRUD APIs and because a route
surface can be exercised without a browser.

- `POST /api/auth/login` — sets an HttpOnly cookie; only its SHA-256 is stored
- `POST /api/auth/logout`
- `GET /api/admin/overview` — counts and database health
- `GET` and `PUT /api/admin/settings`
- `GET` and `PUT /api/admin/seo/[slug]`
- `GET` and `POST /api/admin/media` — POST is multipart, bounded by `CMS_MEDIA_MAX_BYTES`
- `PUT` and `DELETE /api/admin/media/[id]`
- `GET /api/admin/sections?page=home`
- `PATCH /api/admin/sections/[id]` — enable or disable
- `POST /api/admin/sections/reorder`
- `GET` and `PUT /api/admin/home/[section]` — the `section_blocks` shell
- `GET` and `POST /api/admin/home/[section]/[collection]`
- `PUT` and `DELETE /api/admin/home/[section]/[collection]/[id]`
- `PATCH /api/admin/home/[section]/[collection]/[id]/active`
- `POST /api/admin/home/[section]/[collection]/reorder`
- `GET`, `POST`, `PUT`, `DELETE /api/admin/navigation/...`
- `GET /api/public/pages/home` — bearer `CMS_PUBLIC_API_TOKEN`

`[collection]` is needed because several folds own more than one ordered list:
Platform has `steps` and `panels`, Pricing has `plans` and `features`, Purpose
has `cards` and `points`, and every tabbed fold also has `tabs`. A single
`items` route would have had to guess.

Both `[section]` and `[collection]` are resolved through one server-side
registry that maps a pair to its stored-function prefix and its parent column.
Neither segment is ever interpolated into SQL, and a pair the registry does not
know returns 404 before any database call. That registry is also what the
dashboard reads to decide which tabs a section screen shows, so the two cannot
drift apart.

Every admin handler calls `requireAdmin()` first. Upload writes go to
`CMS_MEDIA_DIR` under a generated name; the original filename is stored as
metadata and never used as a path.

---

## 8. Dashboard — `src/app/(dashboard)/**`

Next 16 App Router, React 19, CSS Modules, **no new dependencies**. Reordering
uses a pointer-events hook of about 90 lines that works with mouse and touch
and exposes up/down arrow keys; HTML5 drag-and-drop does neither well.

Visual direction is taken from the live site so the two read as one product:
SBI navy `#22409A`, the Poppins and Inter pairing the marketing site already
loads, an 8px radius scale.

### 8.1 Navigation

- Overview
- Home Page, expanding to the fifteen rendered folds in page order — Hero ·
  Market Pulse · Explore our world · IPOs · Fund It, Protect It · Invest with a
  purpose · Platform · Research · Daily Market Digest · Learn · Testimonials ·
  Pricing · FAQ · App Download Promo · Sticky Nudge — followed by the four
  screens that are not folds: Header · Footer · Statistics · SEO
- Media Library
- Navigation
- Settings and Users

### 8.2 Screen anatomy

`/dashboard/home` is the hub: the **fifteen folds** as a drag-ordered list,
each with an enable/disable toggle and a link into its own screen. Header,
Footer, Statistics and SEO are reached from the sidebar but are not in that
list — Header and Footer are chrome shared by every marketing route, SEO is
page metadata, and Statistics is a cross-section view (§8.3). None of the four
is a `page_sections` row, so none is reorderable.

Each section screen is split into a **Section** tab plus one tab per ordered
collection the fold owns, so no screen becomes one very long form. The tab set
comes from the same registry the API uses (§7), so the two cannot drift.

- **Section** — the `section_blocks` shell: titles, description, images,
  background colour, CTAs.
- **Tabs** — where the fold is tab-driven, edited before its items, since items
  belong to a tab.
- **One tab per collection** — Items for most folds; Steps and Panels for
  Platform; Plans and Features for Pricing; Cards and Points for Purpose. Each
  is a table with search, an active/inactive filter, add and edit in a side
  drawer, drag handles, and delete behind a confirmation naming the row.

Most folds therefore show two tabs; the four with their own tab strip show
three; Platform, Pricing and Purpose show three or four.

Shared throughout: a media picker with preview, loading skeletons, empty states
that offer the primary action, success and error toasts, and a guard on Cancel
when a form is dirty.

Responsive: the sidebar collapses to a drawer below 1024px; tables become
stacked cards below 768px.

### 8.3 Two screens that need justifying

The brief asks for promotional banners with scheduling, and for a statistics
screen. The home page has no fold that is purely either. Rather than add
dashboard controls that change nothing on the page (§9), both attach to
content that is already rendered:

**Promotional Banners** is the App Download Promo fold's Items tab.
`promo_banners` rows *are* the content of that card — title, description, CTA,
artwork — and the fold renders the active banner whose window contains `now()`,
lowest `display_order` winning. The seed creates one banner from `FOOTER_CTA`
with both bounds null, so today's output is unchanged and scheduling a
replacement becomes possible without a code change.

**Statistics** is a cross-section view of `stat_items`, grouped by the fold
that owns them. Today that is Explore our world's 20+ and 130+ branch stats.
The hero's three KPI tiles are *not* listed here: they are `hero_kpis`, a
different table with an ornament kind, and they stay on the Hero screen where
their context is. The Statistics screen says so rather than leaving an editor
hunting for them.

---

## 9. Deliberately not modelled

Recorded so a later reader does not mistake these for oversights:

- **`BENTO.marginTrading.deposit` and `.buyingPower`** — present in the
  constants, not rendered; the copy is inside `margin-scale.png`. Making them
  editable would imply an effect they do not have.
- **A testimonial image** — the card renders quote and author only. An unused
  `avatar_media_id` would put a control in the dashboard that changes nothing
  on the page.
- **Decorative glyphs** — check marks, ticks, plus and minus, carets and
  arrows are part of the component design, not content, and stay in
  `/public/figma`. Logos, artwork, panels, covers and thumbnails are all
  CMS-managed.
- **Localisation and content versioning** — not requested. No locale column, no
  draft/publish workflow; `is_active` is the only publication control.

---

## 10. Public site integration — branch `feature/cms-integration`

`HomeComponent` becomes an async Server Component that reads
`/api/public/pages/home` server-side and passes each section its slice as
props. Twelve of the fifteen sections are already Client Components; they keep
their `"use client"` marker and receive props, so nothing fetches in the
browser and the content still arrives in the initial HTML.

`sbi-home.ts` is **kept** and becomes the typed fallback. If the CMS is
unreachable, times out, or returns a payload that fails validation, the page
renders exactly what it renders today.

No JSX structure, class name, SCSS file or interaction changes. The check is
mechanical: capture the rendered HTML of `/` before the change, seed the
database from the same constants, capture it after, and diff. A non-empty diff
is a defect, not a judgement call.

---

## 11. Verification

- `npm run typecheck` and `npm run lint` clean in both repositories.
- `db:reset`, `db:migrate` and `db:seed` re-runnable from scratch; seeds
  idempotent.
- A SQL smoke script exercising every function: create, get, list, update,
  reorder, disable, delete.
- Rendered-HTML diff of the public home page, before against after.
- A manual pass over every dashboard screen at 1440, 768 and 390.

## 12. Phases

1. Database bootstrap; confirm `001` and `002` apply cleanly.
2. `003` schema, `004` functions, `005` payload, and a seed transcribed from
   `sbi-home.ts` — no invented copy.
3. Auth and API routes.
4. Dashboard shell: layout, sidebar, login, overview, media library, toasts,
   reorder hook. Remove the dead demo page, `src/components/cms/*`, the
   server-to-server Go API modules and `CONTRACT.md`.
5. Home Page hub plus the Header, Hero, SEO and Footer screens.
6. The remaining fourteen fold screens.
7. Public site integration on its branch, with the HTML diff.
8. Rewrite `docs/CONTENT-MAP.md` so its status marks are true.

## 13. Risks

- **Seed fidelity.** The public page is only unchanged if the seed reproduces
  `sbi-home.ts` exactly. Mitigated by generating the seed from the constants
  file rather than retyping it, and by the HTML diff.
- **Scale.** Twenty-three tables, about 75 functions, about 25 screens.
  Mitigated by phase boundaries — each phase is independently verifiable.
- **Two repositories.** The public site changes on its own branch, so the
  integration can be abandoned without affecting the CMS.
