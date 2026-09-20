# Home Page CMS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a non-technical administrator manage every visible element of the SBI Securities pre-login home page from a dashboard backed by PostgreSQL, without changing the public page's design, markup or behaviour.

**Architecture:** PostgreSQL holds normalised content and exposes it only through stored functions; `src/server/db/pool.ts#callFunction` is the single place SQL text is built. Next 16 Route Handlers wrap those functions behind `requireAdmin()`. A React 19 / CSS-Modules dashboard consumes those routes. The public site reads one JSONB payload server-side and keeps `sbi-home.ts` as its typed fallback.

**Tech Stack:** PostgreSQL 17, Next 16.2.9 (App Router), React 19.2.4, `pg` 8.23, CSS Modules. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-20-home-page-cms-design.md`

## Global Constraints

- **No new npm dependencies.** Reordering, toasts, drawers and validation are hand-rolled.
- **Normalised tables only.** No JSONB blob-per-section as storage. JSONB appears only as the *output* of `cms.public_page_payload`.
- **All data access through stored functions.** Route handlers call `callFunction` / `callFunctionOne`. No inline SQL outside `db/migrations/**`.
- **Never interpolate request input into SQL**, including the `[section]` and `[collection]` path segments — both resolve through the server-side registry (Task 5), and a pair the registry does not know is a 404 before any database call.
- **Every admin handler calls `requireAdmin()` first.**
- **Conventions from `001_schema.sql` are unchanged:** identity primary keys, `is_active` and `display_order` on every listed row, `created_at`/`updated_at` by the `cms.touch_updated_at` trigger, text that must not be blank constrained rather than merely `NOT NULL`, every foreign key stating its delete behaviour, images as nullable `*_media_id` pointing at `cms.media_assets`, ordered multi-line copy as `TEXT[]`.
- **Seed fidelity is the acceptance test.** Every string in `db/seeds/002_home_content.sql` is transcribed from `D:\tmp\sbisecurities-web-main\src\constants\sbi-home.ts` and the inline copy in the fold components. No invented copy. Seeds are re-runnable.
- **No change to the public page's JSX structure, class names, SCSS files or interactions.** Verified by a rendered-HTML diff, not judgement.
- **Brand:** SBI navy `#22409A`; the Poppins and Inter pairing the marketing site already loads; an 8px radius scale.
- **Responsive floors:** sidebar collapses to a drawer below 1024px; tables become stacked cards below 768px. Manual pass at 1440, 768 and 390.
- **Deliberately not modelled** (spec §9): `BENTO.marginTrading.deposit` and `.buyingPower`, testimonial avatars, decorative glyphs, localisation, draft/publish versioning.

---

### Task 1: Database bootstrap and the four missing hero functions

**Files:**
- Run: `db/setup.sql` (once, as a PostgreSQL superuser)
- Create: `db/migrations/006_hero_gaps.sql`
- Verify: `npm run db:status`

`002_functions.sql` gives `hero_line_list/create/update/set_active/delete/reorder` and `hero_kpi_list/update/set_active/reorder`. The seven required operations are therefore incomplete: `hero_line_get`, `hero_kpi_create`, `hero_kpi_get` and `hero_kpi_delete` do not exist, and the Hero screen needs all four.

**Interfaces:**
- Produces: `cms.hero_line_get(p_id BIGINT)`, `cms.hero_kpi_create(p_hero_id BIGINT, p_value TEXT, p_label TEXT, p_ornament TEXT, p_media_id BIGINT)`, `cms.hero_kpi_get(p_id BIGINT)`, `cms.hero_kpi_delete(p_id BIGINT)`.

- [ ] **Step 1: Bootstrap the role and database**

Run as a superuser, passing the same password that is already in `DATABASE_URL` in `.env.local`:

```bash
"/c/Program Files/PostgreSQL/17/bin/psql" -U postgres -h localhost \
  -v app_password='<the password from .env.local>' -f db/setup.sql
```

- [ ] **Step 2: Confirm 001 and 002 apply cleanly**

Run: `npm run db:migrate && npm run db:status`
Expected: migrations `001`–`005` recorded, no error.

- [ ] **Step 3: Write `006_hero_gaps.sql`**

Follow the shape of `cms.hero_line_create` (`002_functions.sql:975`) and `cms.hero_line_delete` (`:1036`). `hero_kpi_create` appends to the end of the hero's KPI order. `hero_kpi_delete` raises `no_data_found` when the id does not exist, so `respond.ts` maps it to 404.

- [ ] **Step 4: Apply and smoke-test**

```sql
SELECT cms.hero_kpi_create((SELECT id FROM cms.hero_sections LIMIT 1), '4.7', 'App rating', 'star', NULL);
SELECT * FROM cms.hero_kpi_list((SELECT id FROM cms.hero_sections LIMIT 1), FALSE);
```

- [ ] **Step 5: Commit**

---

### Task 2: Public payload — `007_public_payload.sql`

**Files:**
- Create: `db/migrations/007_public_payload.sql`
- Replaces: `cms.public_page_payload(p_page_slug TEXT)` from `002_functions.sql:1177`

**Interfaces:**
- Produces: `cms.public_page_payload(p_page_slug TEXT) RETURNS JSONB` — `{ page, seo, settings, header: { nav[] }, footer: {...}, sections: [ { key, name, order, block, tabs[], items: {...} } ] }`. Sections in `display_order`; rows with `is_active = false` omitted; banners filtered to those whose `[starts_at, ends_at]` window contains `now()`, either bound nullable; every `*_media_id` resolved to `{ url, alt, width, height }`.

- [ ] **Step 1: Write the function**
- [ ] **Step 2: Verify one round trip returns every fold**

```sql
SELECT jsonb_array_length(cms.public_page_payload('home') -> 'sections');  -- 15
SELECT jsonb_pretty(cms.public_page_payload('home'));
```

- [ ] **Step 3: Commit**

---

### Task 3: Seed the home page from `sbi-home.ts`

**Files:**
- Create: `scripts/generate-seed.mjs`
- Create: `db/seeds/002_home_content.sql` (generated)
- Modify: `scripts/db.mjs` — apply every `db/seeds/*.sql` in name order

Generated rather than retyped, because spec §13 names seed fidelity as the primary risk. The generator reads `D:\tmp\sbisecurities-web-main\src\constants\sbi-home.ts` plus the inline copy in `MarketPulse.tsx`, `TestimonialsSection.tsx` and `Footer.tsx`, and emits `SELECT cms.*_create(...)` calls with every literal quoted through one `sqlLiteral()` helper.

- [ ] **Step 1: Write the generator**
- [ ] **Step 2: Generate, and read the output against the constants file**
- [ ] **Step 3: Seed twice and confirm idempotence**

Run: `npm run db:seed && npm run db:seed`
Expected: identical row counts after each run.

- [ ] **Step 4: Commit**

---

### Task 4: SQL smoke script

**Files:**
- Create: `scripts/smoke.mjs`

Exercises create, get, list, update, reorder, set_active and delete on every entity inside one transaction that is rolled back, so it is safe to run against a seeded database.

- [ ] **Step 1: Write it**
- [ ] **Step 2: Run `node scripts/smoke.mjs`; every entity reports PASS**
- [ ] **Step 3: Commit**

---

### Task 5: The section/collection registry

**Files:**
- Create: `src/server/cms/registry.ts`

**Interfaces:**
- Produces: `SECTIONS: Record<string, SectionDef>`; `resolveCollection(section: string, collection: string): CollectionDef | null`; `type CollectionDef = { key: string; label: string; fnPrefix: string; parent: "section" | "tab" | "card" | "plan" | "none"; fields: FieldDef[] }`.

One table drives three things: which stored-function prefix a URL pair maps to, which parent id its `_list` and `_reorder` take, and which tabs the dashboard screen shows. Shared by Task 6 and Task 9, so the API and the UI cannot drift.

- [ ] **Step 1: Write it, one entry per fold**
- [ ] **Step 2: `npm run typecheck`**
- [ ] **Step 3: Commit**

---

### Task 6: API routes

**Files:**
- Create: `src/app/api/auth/login/route.ts`, `auth/logout/route.ts`
- Create: `src/app/api/admin/overview/route.ts`, `admin/settings/route.ts`, `admin/seo/[slug]/route.ts`
- Create: `src/app/api/admin/media/route.ts`, `admin/media/[id]/route.ts`
- Create: `src/app/api/admin/sections/route.ts`, `admin/sections/[id]/route.ts`, `admin/sections/reorder/route.ts`
- Create: `src/app/api/admin/home/[section]/route.ts`
- Create: `src/app/api/admin/home/[section]/[collection]/route.ts`
- Create: `src/app/api/admin/home/[section]/[collection]/[id]/route.ts`
- Create: `src/app/api/admin/home/[section]/[collection]/[id]/active/route.ts`
- Create: `src/app/api/admin/home/[section]/[collection]/reorder/route.ts`
- Create: `src/app/api/admin/navigation/**`
- Create: `src/app/api/public/pages/home/route.ts`

Login rate-limits per email and IP. Media `POST` is multipart, bounded by `CMS_MEDIA_MAX_BYTES`, written under a generated name into `CMS_MEDIA_DIR`; the original filename is stored as metadata and never used as a path. The public route requires bearer `CMS_PUBLIC_API_TOKEN`.

- [ ] **Step 1: Auth routes; verify against an admin created with `npm run db:create-admin`**
- [ ] **Step 2: Overview, settings, SEO, sections**
- [ ] **Step 3: Media, including the path-traversal guard on upload**
- [ ] **Step 4: The generic `home/[section]/[collection]` family over the registry**
- [ ] **Step 5: Navigation, and the public payload route**
- [ ] **Step 6: `npm run typecheck && npm run lint`**
- [ ] **Step 7: Commit**

---

### Task 7: Remove the dead Go-API spike

**Files:**
- Delete: `src/app/page.tsx`, `src/app/loading.tsx`, `src/components/cms/*`, `src/server/cms/cms.{config,service,fallback,types}.ts`, `src/server/http/serverFetch.ts`, `CONTRACT.md`
- Modify: `.env.example` and `.env.local` — drop `CMS_API_BASE_URL`, `CMS_API_CONTRACT_APPROVED`, `CMS_API_TIMEOUT_MS`
- Modify: `README.md` — describe the CMS, not the spike

Done after Task 6, so nothing is deleted before its replacement exists. `src/server/cms/registry.ts` stays.

- [ ] **Step 1: Delete, then `npm run build` to prove nothing referenced them**
- [ ] **Step 2: Commit**

---

### Task 8: Dashboard shell

**Files:**
- Create: `src/app/(dashboard)/layout.tsx`, `dashboard.module.css`, `Sidebar.tsx`
- Create: `src/app/login/page.tsx`
- Create: `src/app/(dashboard)/dashboard/page.tsx` (Overview)
- Create: `src/app/(dashboard)/dashboard/media/page.tsx`
- Create: `src/components/ui/{Toast,Drawer,DataTable,Field,MediaPicker,ConfirmDialog,Skeleton,EmptyState}.tsx` and their CSS modules
- Create: `src/components/ui/useReorder.ts` — pointer events, mouse and touch, up/down arrow keys, about 90 lines
- Create: `src/lib/apiClient.ts` — `get/post/put/patch/del`, surfacing `ApiFailure.error.fields` to forms

- [ ] **Step 1: Layout, sidebar, login and logout round trip in a browser**
- [ ] **Step 2: Overview with counts and database health**
- [ ] **Step 3: The shared UI primitives**
- [ ] **Step 4: Media library — upload, replace, delete, preview**
- [ ] **Step 5: Commit**

---

### Task 9: Home hub, plus the Header, Hero, SEO and Footer screens

**Files:**
- Create: `src/app/(dashboard)/dashboard/home/page.tsx` — the fifteen folds, drag-ordered, each with an enable toggle
- Create: `src/app/(dashboard)/dashboard/home/[section]/page.tsx` — the generic screen, tabs from the registry
- Create: `src/components/dashboard/SectionForm.tsx`, `CollectionTable.tsx`, `ItemDrawer.tsx`
- Create: `src/app/(dashboard)/dashboard/header/page.tsx`, `footer/page.tsx`, `seo/page.tsx`, `statistics/page.tsx`

Header, Footer, Statistics and SEO are sidebar entries, not `page_sections` rows, so none of them is reorderable and none appears in the hub list. Statistics groups `stat_items` by owning fold and says in copy that the hero's KPI tiles live on the Hero screen.

- [ ] **Step 1: The hub, with reordering and toggles**
- [ ] **Step 2: The generic section screen driven by the registry**
- [ ] **Step 3: Hero — rotating lines, KPIs, form labels**
- [ ] **Step 4: Header, Footer, SEO, Statistics**
- [ ] **Step 5: Commit**

---

### Task 10: The remaining fourteen fold screens

Each is the generic screen from Task 9 plus its registry entry. Only Platform (Steps and Panels), Pricing (Plans and Features), Purpose (Cards and Points) and the four tabbed folds need more than the default two tabs.

- [ ] **Step 1: Market Pulse, Explore our world, IPOs, Fund It Protect It**
- [ ] **Step 2: Invest with a purpose, Platform, Research, Daily Market Digest**
- [ ] **Step 3: Learn, Testimonials, Pricing, FAQ**
- [ ] **Step 4: App Download Promo (banners, with scheduling), Sticky Nudge**
- [ ] **Step 5: Manual pass at 1440, 768 and 390**
- [ ] **Step 6: Commit**

---

### Task 11: Public site integration — branch `feature/cms-integration`

**Files (in `D:\tmp\sbisecurities-web-main`):**
- Create: `src/server/cms/{client,types,fallback}.ts`
- Modify: `src/components/home/HomeComponent.tsx` → async Server Component
- Modify: each fold to take props; existing `"use client"` markers stay
- Keep: `src/constants/sbi-home.ts` as the typed fallback

- [ ] **Step 1: Capture the rendered HTML of `/` before the change**
- [ ] **Step 2: Add the server-side read, with timeout, validation and fallback**
- [ ] **Step 3: Thread props through the fifteen folds**
- [ ] **Step 4: Capture after, and diff. A non-empty diff is a defect.**
- [ ] **Step 5: Commit on the branch**

---

### Task 12: Correct the documentation

**Files:**
- Rewrite: `docs/CONTENT-MAP.md` — status marks that are true
- Modify: `README.md` — setup, migration, seeding, running the dashboard

- [ ] **Step 1: Rewrite**
- [ ] **Step 2: Commit**
