# Setting this up on another machine

Step by step, from an empty machine to a running CMS with the marketing site
reading from it. Written for PostgreSQL managed through pgAdmin and a normal
git remote.

Allow about 30 minutes. Nothing here needs to be done in a hurry, and two of
the steps are easy to get subtly wrong — they are called out where they
arrive.

---

## 0. What you are moving

Two applications and one database.

| Part | What it is | Port |
| --- | --- | --- |
| `cms-website` | The CMS: dashboard, API, and every migration and seed | 3001 |
| `sbisecurities-web-main` | The public marketing site, which reads from the CMS | 3000 |
| PostgreSQL `sbi_cms` | The content itself: 35 tables, ~230 stored functions | 5432 |

The marketing site does **not** depend on the CMS being up. Every read falls
back, field by field, to the copy in `src/constants/sbi-home.ts`. You can run
the site alone and it renders exactly what it rendered before the CMS
existed — useful while you are part-way through this.

---

## 1. Install the prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Node.js | 20 or newer | Built and tested on 21.6.1 |
| PostgreSQL | 15 or newer | Built and tested on 17 |
| pgAdmin 4 | any current | Ships with the PostgreSQL Windows installer |
| Git | any current | |

During the PostgreSQL install you are asked for a **superuser password** for
the `postgres` account. Write it down — step 3 needs it, and it is not
recoverable.

Check afterwards:

```bash
node --version
git --version
```

---

## 2. Get the code

### 2.1 The CMS

It lives at `https://github.com/omkarkambli1010/sbi_cms.git`.

```bash
git clone https://github.com/omkarkambli1010/sbi_cms.git cms-website
cd cms-website
npm install
```

### 2.2 The marketing site

Its CMS integration is on the branch `feature/cms-integration`, not on
`main`:

```bash
git clone <your-marketing-site-remote> sbisecurities-web-main
cd sbisecurities-web-main
git checkout feature/cms-integration
npm install
```

Four commits make up the integration:

```
5e58ded  minor mobile changes
41fa159  fix(security): reject and sanitise unsafe link schemes from the CMS
b2f1b67  feat(header): read the header's copy from the CMS
6e65df9  feat(home): read the hero's copy from the CMS
```

---

## 3. Create the database — pgAdmin

### 3.1 Connect to the server

pgAdmin usually finds a local install by itself. If **Servers** is empty,
right-click it and choose **Register → Server**:

| Field | Value |
| --- | --- |
| Name (General tab) | `Local PostgreSQL` |
| Host (Connection tab) | `localhost` |
| Port | `5432` |
| Maintenance database | `postgres` |
| Username | `postgres` |
| Password | the superuser password from step 1 |

### 3.2 Create the role and the database

Right-click the **`postgres`** database → **Query Tool**. Open
`db/setup-pgadmin.sql`, replace **both** occurrences of
`REPLACE_WITH_YOUR_PASSWORD` with a password you choose for the application
role, paste the whole file in, and run it (F5).

Three things go wrong here more often than anything else in this document:

- **Use `db/setup-pgadmin.sql`, not `db/setup.sql`.** The latter is written
  for the `psql` command line and uses `\if`, `\set` and `\gexec`, which are
  psql's own commands rather than SQL. pgAdmin stops at the first backslash.
- **Run it against `postgres`, not `sbi_cms`.** `CREATE DATABASE` cannot run
  from inside the database it is creating.
- **Clear any text selection first.** The Query Tool runs *only the
  highlighted text* when something is selected. Click once in the editor,
  then F5, and read the **Messages** tab rather than assuming.

If you see `CREATE DATABASE cannot run inside a transaction block`, turn
autocommit on: the **⚡** menu in the Query Tool toolbar → **Auto commit**.

### 3.3 Confirm it worked

Refresh the browser tree and check that **Login/Group Roles** contains
`sbi_cms` and **Databases** contains `sbi_cms`. Do look — a failed `DO`
block reports nothing at the places you would notice.

---

## 4. Configure and populate the CMS

### 4.1 Environment

Copy the example and fill it in:

```bash
cd cms-website
cp .env.example .env.local
```

Generate two fresh secrets — **do not** reuse the ones from any other
machine:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Run it twice. `.env.local` then reads:

```ini
DATABASE_URL=postgres://sbi_cms:THE_PASSWORD_FROM_STEP_3@localhost:5432/sbi_cms
DATABASE_POOL_MAX=10
DATABASE_STATEMENT_TIMEOUT_MS=8000

CMS_SESSION_SECRET=<first generated value>
CMS_SESSION_TTL_HOURS=12

CMS_MEDIA_DIR=./public/uploads
CMS_MEDIA_PUBLIC_PATH=/uploads
CMS_MEDIA_MAX_BYTES=5242880

CMS_PUBLIC_API_TOKEN=<second generated value>

# Where root-relative media paths resolve when the dashboard previews them.
NEXT_PUBLIC_MEDIA_ORIGIN=http://localhost:3000

# Leave blank. See section 8.
CMS_DEV_BYPASS_AUTH=
```

The password in `DATABASE_URL` **must** match what you typed into
`setup-pgadmin.sql`. A mismatch shows up as
`password authentication failed for user "sbi_cms"` and nothing more
specific.

If your password contains `@`, `:`, `/` or `#`, percent-encode it — those
characters are URL syntax.

### 4.2 Create the schema and load the content

```bash
npm run db:migrate
npm run db:seed
npm run db:status
```

`db:status` should list migrations `001` to `015` as applied, and row counts
with `page_sections 15` and `media_assets 51`.

Notes on these commands:

- `npm run db:setup` only prints a reminder. Step 3 replaces it.
- Migrations are recorded in `cms.schema_migrations` and never re-run.
- **Seeds are not recorded, deliberately.** They are written to be
  idempotent, so `db:seed` doubles as "put the shipped copy back". Running
  it again after an editor has changed something restores the original text
  for the content the seed owns.
- `npm run db:reset` drops the whole `cms` schema and rebuilds it. It does
  exactly what it says.

### 4.3 Make yourself an account

```bash
npm run db:create-admin
```

It asks for a numeric username (4–20 digits), a full name, an optional
email, and a password of at least 12 characters.

**Then delete the placeholder account.** `db/seeds/003_dev_admin.sql` seeds
`16191` / `16191` so the dashboard can be opened before real accounts exist.
It is weak on purpose and it is in version control:

```sql
-- pgAdmin, Query Tool on the sbi_cms database
DELETE FROM cms.admin_users WHERE username = '16191';
```

and delete `db/seeds/003_dev_admin.sql`, or the next `db:seed` puts it back.

### 4.4 Run it

```bash
npm run dev
```

Sign in at **http://localhost:3001/login** with the account from 4.3.

---

## 5. Point the marketing site at the CMS

Add two lines to the site's `.env.local`:

```ini
HOME_CMS_URL=http://localhost:3001
HOME_CMS_TOKEN=<the CMS_PUBLIC_API_TOKEN from 4.1, exactly>
```

Neither has a `NEXT_PUBLIC_` prefix, and neither should get one. The token
is read server-side only; prefixing it would inline it into the JavaScript
every visitor downloads.

Both are optional. Leave them out and the site renders its hardcoded copy —
which is how you tell a CMS problem from a site problem.

```bash
npm run dev
```

The site comes up on **http://localhost:3000**.

---

## 6. Check it end to end

Work down this list. Each line has a definite answer.

1. **The CMS answers.** `npm run db:status` in `cms-website` lists 15
   applied migrations.
2. **You can sign in.** http://localhost:3001/login with your account. The
   Overview shows counts, not "The database is not responding".
3. **The public API is protected.** In a terminal:
   ```bash
   curl -i http://localhost:3001/api/public/site
   ```
   → `401`. With the token it returns JSON:
   ```bash
   curl -H "authorization: Bearer YOUR_TOKEN" http://localhost:3001/api/public/site
   ```
4. **The site reads the CMS.** In the dashboard open **Header**, change
   **Search placeholder** to something obvious, save, then reload
   http://localhost:3000 — the search box in the header changes. Change it
   back.
5. **The fallback holds.** Stop the CMS (Ctrl-C) and reload the site. It
   still renders, with the original copy. The site's terminal logs
   `[cms] site payload unavailable`. Start the CMS again.

If 1–3 pass and 4 does not, the problem is `HOME_CMS_TOKEN` — it must match
`CMS_PUBLIC_API_TOKEN` character for character.

---

## 7. Media files

The seed registers paths such as `/figma/header/logo-main.svg`. Those files
live in the **marketing site's** `public/` folder — the CMS does not own
them, deliberately, so switching the site over moves no assets.

Two consequences:

- `NEXT_PUBLIC_MEDIA_ORIGIN` in the CMS's `.env.local` tells the dashboard
  where to fetch them for preview. Without it, image previews are blank
  while the live site is fine.
- Uploads made **through** the dashboard are written to `CMS_MEDIA_DIR` and
  served by the CMS itself. In production that should be a mounted volume or
  object storage, not a folder inside the deployment, or a redeploy discards
  every image an editor has added.

---

## 8. Before this reaches anything public

Local defaults that must not travel:

- [ ] **Delete the `16191` account** and `db/seeds/003_dev_admin.sql` (4.3).
- [ ] **`CMS_DEV_BYPASS_AUTH` unset.** Set to `true` it lets anyone who can
      reach the dashboard in with no account. A production build ignores it
      whatever it is set to, and the dashboard shows a banner on every
      screen while it is on — but leave it blank regardless.
- [ ] **New `CMS_SESSION_SECRET` and `CMS_PUBLIC_API_TOKEN`** per
      environment. Changing the session secret signs everyone out, which is
      the intended behaviour after a suspected leak.
- [ ] **A real database password**, not the one in any example.
- [ ] **`CMS_MEDIA_DIR` on durable storage** (section 7).
- [ ] **The CMS is not public.** Nothing in it is meant to be reachable from
      the internet except `/api/public/*`, and those are behind the bearer
      token.
- [ ] **Revalidation window.** The site reads the CMS with
      `revalidate: 60` outside development, so an edit takes up to a minute
      to appear on a static route. If that is too slow, the read is in
      `src/server/cms/siteChrome.ts` and `homeContent.ts`; `revalidateTag`
      on publish is the proper fix and is not built yet.

---

## 9. When something goes wrong

**`password authentication failed for user "sbi_cms"`**
The password in `DATABASE_URL` does not match the role's. Note that this
server returns the same error for a role that does not exist, so check the
role is actually there (3.3) before assuming it is the password. To reset
it, in pgAdmin on the `postgres` database:
```sql
ALTER ROLE sbi_cms WITH LOGIN PASSWORD 'the password in your .env.local';
```

**`syntax error at or near "\"` in pgAdmin**
You ran `db/setup.sql` instead of `db/setup-pgadmin.sql` (3.2).

**`CREATE DATABASE cannot run inside a transaction block`**
Autocommit is off in the Query Tool (3.2).

**The dashboard says "The database is not responding"**
PostgreSQL is not running, or `DATABASE_URL` points somewhere else. The
CMS's terminal logs the real reason with a SQLSTATE.

**Sign-in says "Too many attempts"**
Ten failures per username and IP in fifteen minutes. The counter is held in
memory, so restarting the CMS clears it.

**Image previews are blank in the dashboard, but fine on the site**
`NEXT_PUBLIC_MEDIA_ORIGIN` is unset or wrong (section 7). It is read at
build time, so restart the CMS after changing it.

**The site ignores the CMS**
In order: is `HOME_CMS_URL` reachable from the site's process; does
`HOME_CMS_TOKEN` match; does `curl` with the token return JSON. The site's
terminal logs `[cms] …` on every fallback and says which of these it was.

**A static page shows old content after an edit**
Expected outside development — see the revalidation note in section 8.

---

## 10. What is in the database

For orientation when you open it in pgAdmin. Everything is in the `cms`
schema.

**Accounts and media** — `admin_users`, `admin_sessions`, `media_assets`

**Page structure** — `pages`, `page_sections`, `section_blocks`,
`section_tabs`, `site_settings`, `seo_metadata`, `navigation_menus`,
`navigation_items`

**Hero** — `hero_sections`, `hero_rotating_lines`, `hero_kpis`

**One table per fold** — `ticker_items`, `bento_cards`, `stat_items`,
`ipo_items`, `offering_cards`, `purpose_cards` + `purpose_card_points`,
`platform_steps` + `platform_panels`, `research_reports`, `news_items`,
`lessons`, `testimonials`, `pricing_plans` + `pricing_plan_features`,
`faq_items`, `promo_banners`, `sticky_nudge`

**Footer** — `legal_content`, `stock_index_letters`, `stock_links`

**Bookkeeping** — `schema_migrations`

Two things to know before poking at it directly:

- The application never writes SQL of its own. Every read and write goes
  through a stored function, and `src/server/db/pool.ts` is the single place
  a statement is built. If you add a column, it needs a function to reach
  it.
- `cms.public_page_payload('home')` and `cms.public_site_payload()` return
  the whole published shape as JSONB. Running them in the Query Tool is the
  fastest way to see what the marketing site will actually receive:
  ```sql
  SELECT jsonb_pretty(cms.public_page_payload('home'));
  ```

---

## 11. Day-to-day commands

In `cms-website`:

| Command | What it does |
| --- | --- |
| `npm run dev` | The dashboard on 3001 |
| `npm run build` / `npm start` | Production build and serve |
| `npm run typecheck` | TypeScript, no emit |
| `npm run lint` | ESLint |
| `npm run db:migrate` | Apply pending migrations |
| `npm run db:seed` | Re-apply the seeds (restores shipped copy) |
| `npm run db:status` | Applied migrations and row counts |
| `npm run db:reset` | **Drops** the `cms` schema, then migrates and seeds |
| `npm run db:create-admin` | Create or update a dashboard login |

In `sbisecurities-web-main`: `npm run dev`, `npm run build`.

Regenerating the content seed from the marketing site's constants:

```bash
node scripts/generate-seed.mjs
```

It reads `src/constants/sbi-home.ts` from the site — set `SBI_SITE_DIR` if
the two repositories are not side by side — and rewrites
`db/seeds/002_home_content.sql`. Never edit that file by hand; it says so at
the top.
