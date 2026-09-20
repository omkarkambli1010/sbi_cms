# Content map — website section → CMS screen → table → procedure → API

Every content element on the marketing home page, where it lives, and what
moves it. Derived by reading the live site, not assumed: the source column
names the exact export in `sbisecurities-web/src/constants/sbi-home.ts` (or the
component) that currently hardcodes the value.

**Status legend** — ✅ built and wired · 🟡 table + procedures exist, screen
pending · ⬜ inventoried, not yet implemented.

---

## 1. Site chrome

| Website element | Source today | CMS screen | Table | Procedure | API | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Brand name, legal name | `BRAND.name`, `BRAND.legalName` | Global Settings | `cms.site_settings` | `site_settings_get` / `site_settings_update` | `GET/PUT /api/admin/settings` | ✅ |
| Registered address | `BRAND.address` | Global Settings | `cms.site_settings` | as above | as above | ✅ |
| Phone, e-mail | `BRAND.phone`, `BRAND.email` | Global Settings | `cms.site_settings` | as above | as above | ✅ |
| Header logo | `/figma/header/logo-main.svg` | Global Settings → logo picker | `cms.site_settings.logo_media_id` → `cms.media_assets` | `site_settings_update`, `media_*` | as above | ✅ |
| Footer logo | `/figma/footer/logo-a.svg` | Global Settings → logo picker | `cms.site_settings.footer_logo_media_id` | as above | as above | ✅ |
| Search placeholder | `SEARCH_PLACEHOLDER` | Global Settings | `cms.site_settings.search_placeholder` | as above | as above | ✅ |
| Top navigation items | `TOP_NAV` | Navigation | `cms.navigation_menus` + `cms.navigation_items` | `nav_item_list/create/update/delete/set_active/reorder` | `/api/admin/navigation*` | ✅ |
| Social links + icons | `SOCIALS` in `Footer.tsx` | Navigation → Social menu | same pair, `menu_key = 'social'` | as above | as above | ✅ |

## 2. Page + SEO

| Website element | Source today | CMS screen | Table | Procedure | API | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Which folds render, in what order | `HomeComponent.tsx` JSX order | Section Management | `cms.pages`, `cms.page_sections` | `section_list_by_page`, `section_set_active`, `section_reorder` | `/api/admin/sections*` | ✅ |
| SEO title / description | route `metadata` | SEO Management | `cms.seo_metadata` | `seo_get_by_page`, `seo_upsert` | `GET/PUT /api/admin/seo/[slug]` | ✅ |
| SEO keywords | not present today | SEO Management | `cms.seo_metadata.meta_keywords` (`TEXT[]`) | as above | as above | ✅ |
| Canonical URL, robots | not present today | SEO Management | `cms.seo_metadata` | as above | as above | ✅ |
| Open Graph title/description/image | not present today | SEO Management | `cms.seo_metadata` + `media_assets` | as above | as above | ✅ |

## 3. Hero fold

| Website element | Source today | CMS screen | Table | Procedure | API | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Lead line "Smart Investing with" | `HERO.titleLead` | Hero / Banner | `cms.hero_sections.title_lead` | `hero_get`, `hero_update` | `GET/PUT /api/admin/hero` | ✅ |
| Rotating headline pairs | `HERO.rotatingLines` | Hero → Rotating lines | `cms.hero_rotating_lines` | `hero_line_list/create/update/delete/set_active/reorder` | `/api/admin/hero/lines*` | ✅ |
| Sub-text lines 1 and 2 | `HERO.subtext` | Hero / Banner | `hero_sections.subtext_line_1/2` | `hero_update` | as above | ✅ |
| TRADE / INVEST wordmarks | `HERO.watermarkLeft/Right` | Hero / Banner | `hero_sections.watermark_left/right` | `hero_update` | as above | ✅ |
| Phone mockup image | `/figma/hero/mockup.png` | Hero → image picker | `hero_sections.mockup_media_id` | `hero_update`, `media_*` | as above | ✅ |
| Lead-form labels (desktop) | `HERO.form.*` | Hero → Form labels | `hero_sections.form_*` | `hero_update` | as above | ✅ |
| Lead-form labels (mobile) | `HERO.formMobile.*` | Hero → Form labels | `hero_sections.form_*_mobile` | `hero_update` | as above | ✅ |
| KPI tiles (5M+, 4.4, Backed by SBI) | `HERO.kpis` | Hero → KPI tiles | `cms.hero_kpis` | `hero_kpi_list/update/set_active/reorder` | `/api/admin/hero/kpis*` | ✅ |
| KPI star + SBI lockup images | `/figma/hero/star.svg`, `backed-by-sbi.png` | Hero → KPI tiles | `hero_kpis.icon_media_id` | as above | as above | ✅ |

## 4. Media

| Website element | Source today | CMS screen | Table | Procedure | API | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Every image, icon, illustration | files under `/public/figma/**` | Media Library | `cms.media_assets` | `media_create/get/list/update/set_active/delete` | `/api/admin/media*` | ✅ |
| Alt text | hardcoded per `<img>` | Media Library | `media_assets.alt_text` | `media_update` | as above | ✅ |

## 5. Remaining home-page folds

Inventoried from the live site; tables and screens follow the same pattern as
the hero. `page_sections` rows already exist for all of them, so each can be
switched off or reordered from the dashboard today even before its detail
table lands.

| Fold | Source today | Fields to manage | Planned table(s) | Status |
| --- | --- | --- | --- | --- |
| Market pulse ticker | `MARKET_PULSE` | name, price, change, direction | `ticker_items` | ⬜ |
| Explore our world | `BENTO` | section title + 2 sub-texts (desktop/mobile), 4 cards each with multi-line titles, `4x` leverage figures, branch stats, per-card art | `bento_cards`, `bento_card_stats` | ⬜ |
| IPOs | `IPOS`, `IPO_TABS` | tab labels; per IPO: name, status, date range, price band, issue size, min investment + unit, listing/closing notes and dates | `ipo_tabs`, `ipos` | ⬜ |
| Fund It, Protect It | `LOANS`, `INSURANCE`, `OFFERINGS_TABS` | tab labels; per card: slug, title, lede, highlight lead + highlight, CTA (desktop/mobile), mobile order, art + mobile art | `offering_tabs`, `offerings` | ⬜ |
| Invest with a purpose | `PURPOSE` | title, sub-text; per card: slug, title, lede, bullet points, CTA | `purpose_cards`, `purpose_card_points` | ⬜ |
| Next-gen platform | `PLATFORM`, `PLATFORM_TABS` | title, sub-text; per tab: label, panel images, 3 steps (title + body), transition timing | `platform_tabs`, `platform_steps`, `platform_panels` | ⬜ |
| Analysis you can trust | `RESEARCH`, `RESEARCH_TABS` | tab labels; per report: title, kind, date, cover image | `research_tabs`, `research_reports` | ⬜ |
| Daily market digest | `NEWS` | title, sub-text, lead item, list items (title + timestamp + image) | `news_items` | ⬜ |
| Learn before you invest | `LESSONS`, `LEARN_TABS` | tab labels; per lesson: title, duration, date, thumbnail | `learn_tabs`, `lessons` | ⬜ |
| Testimonials | `TESTIMONIALS` | quote, author, avatar initial | `testimonials` | ⬜ |
| Pricing plans | `PLANS` | name, price, price note, accent, feature list, plan icon | `pricing_plans`, `pricing_plan_features` | ⬜ |
| FAQ | `FAQS` | question, answer, order | `faqs` | ⬜ |
| App download promo | `FOOTER_CTA` | title, body, CTA label, phone mockup | `promo_sections` | ⬜ |
| Sticky nudge | `STICKY_NUDGE` | title, placeholders, CTA label | `sticky_nudge` | ⬜ |
| Footer link columns | `FOOTER_PRIMARY`, `FOOTER_SECONDARY` | column titles + links | `navigation_menus`/`navigation_items` (already generic) | 🟡 |
| Stocks directory | `STOCK_INDEX_LETTERS`, `STOCK_LINKS` | letters, keyword chips | `stock_index_letters`, `stock_links` | ⬜ |
| Legal / disclaimer | `FOOTER_LEGAL` | registration lines, trading, authorisation, warning, copyright | `legal_content` | ⬜ |

---

## Request flow

```
Admin dashboard (browser)
  └─ POST/PUT /api/admin/*          session cookie, HttpOnly
       └─ requireUser() / requireAdmin()
            └─ callFunction("cms.<procedure>", [...])      bound parameters only
                 └─ PostgreSQL stored function
                      └─ cms.* tables

Public website (server render, port 3000)
  └─ GET /api/public/pages/home     shared server-to-server token
       └─ callFunction("cms.public_page_payload", ["home"])
            └─ one JSONB document, inactive rows already filtered
                 └─ falls back to the shipped constants if the CMS is down
```

Only `callFunction` in `src/server/db/pool.ts` builds SQL text, and the
function name it interpolates is matched against `^cms\.[a-z_]+$` and never
comes from request input. Every value is a bound parameter.
