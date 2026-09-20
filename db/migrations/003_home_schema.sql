-- ============================================================================
-- 003_home_schema.sql — the remaining home-page folds
--
-- 001 modelled the site chrome and the hero. This file adds everything else
-- the home page renders: the shared section shell, the tab strip four folds
-- share, and one table per fold for the rows that are genuinely its own.
--
-- Shape, and why:
--
--   Every fold on the page has the same outer shell — eyebrow, title,
--   subtitle, description, background, CTA. Seventeen copies of those columns
--   would be seventeen places to change when the shell grows a field, so the
--   shell is ONE table (section_blocks) keyed 1:1 to page_sections.
--
--   Five folds carry a tab strip of identical shape, so that is ONE table too
--   (section_tabs). Rows belonging to a tab hang off the tab, not off the
--   section: tab_id already implies the section, and storing both would let
--   the two disagree.
--
--   What is left per fold is only what that fold alone has — an IPO's price
--   band, a plan's accent, a lesson's duration.
--
-- Conventions are 001's, unchanged: identity primary keys; is_active and
-- display_order on every listed row; created_at/updated_at kept by trigger;
-- text that must not be blank constrained rather than merely NOT NULL; every
-- foreign key states its delete behaviour; images referenced by a nullable
-- *_media_id that is nulled, not cascaded, when the asset goes.
--
-- Ordered multi-line copy is TEXT[]. The page breaks several headings
-- deliberately ("NRI Demat Account / Investing without / boundaries"); storing
-- one string and splitting on render would lose the editor's control of where
-- the break falls.
-- ============================================================================

SET search_path = cms, public;

-- ---------------------------------------------------------------------------
-- section_blocks — the editable shell of every fold, one row per section.
--
-- Nullable rather than defaulted-to-'' only where the distinction matters:
-- a NULL cta_href means "this fold has no CTA", where '' would render an
-- anchor to nowhere.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.section_blocks (
  id                     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id             BIGINT      NOT NULL UNIQUE REFERENCES cms.page_sections (id) ON DELETE CASCADE,

  eyebrow                TEXT        NOT NULL DEFAULT '',
  title                  TEXT        NOT NULL DEFAULT '',
  -- Used where the heading is authored as deliberate lines rather than prose.
  title_lines            TEXT[]      NOT NULL DEFAULT '{}',
  subtitle               TEXT        NOT NULL DEFAULT '',
  -- Explore our world words its sub-heading differently below 767; that is a
  -- second string, not a transformation of the first.
  subtitle_mobile        TEXT        NOT NULL DEFAULT '',
  description            TEXT        NOT NULL DEFAULT '',

  -- SectionHead takes these today. Leaving them out would silently re-wrap
  -- every mobile heading the moment the CMS took over.
  title_break_after      INTEGER     CHECK (title_break_after IS NULL OR title_break_after > 0),
  subtitle_break_after   INTEGER     CHECK (subtitle_break_after IS NULL OR subtitle_break_after > 0),

  align                  TEXT        NOT NULL DEFAULT 'start',
  tone                   TEXT        NOT NULL DEFAULT 'light',

  cta_label              TEXT        NOT NULL DEFAULT '',
  -- Several folds label the same button differently on mobile — the offerings
  -- card reads "Get Started" at 1440 and "Explore" at 360.
  cta_label_mobile       TEXT        NOT NULL DEFAULT '',
  cta_href               TEXT,
  cta_visible            BOOLEAN     NOT NULL DEFAULT TRUE,

  secondary_cta_label    TEXT        NOT NULL DEFAULT '',
  secondary_cta_href     TEXT,
  secondary_cta_visible  BOOLEAN     NOT NULL DEFAULT FALSE,

  -- The dotted arrow-up-right that links a fold through to its listing.
  arrow_href             TEXT,
  arrow_label            TEXT        NOT NULL DEFAULT '',

  image_media_id         BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  image_mobile_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  background_media_id    BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  background_mobile_media_id BIGINT  REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  -- '' means "the stylesheet decides", which is the normal case.
  background_color       TEXT        NOT NULL DEFAULT '',

  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT section_blocks_align_check CHECK (align IN ('start', 'center')),
  CONSTRAINT section_blocks_tone_check  CHECK (tone  IN ('light', 'dark')),
  -- Either a hex triplet or nothing. A half-typed colour should fail here
  -- rather than render as a transparent background on the live page.
  CONSTRAINT section_blocks_bg_color_check
    CHECK (background_color = '' OR background_color ~ '^#[0-9a-fA-F]{6}$')
);

DROP TRIGGER IF EXISTS section_blocks_touch ON cms.section_blocks;
CREATE TRIGGER section_blocks_touch BEFORE UPDATE ON cms.section_blocks
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- section_tabs — the tab strip shared by IPOs, Offerings, Platform, Research
-- and Learn.
--
-- The transition columns are nullable because only Platform animates its
-- panel; the values are read off the Figma ON_CLICK reactions and differ per
-- tab (1022ms for Mobile Application, 128ms for Trading terminal), so they
-- belong to the tab and not to the section.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.section_tabs (
  id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id              BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  tab_key                 TEXT        NOT NULL CHECK (tab_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label                   TEXT        NOT NULL CHECK (btrim(label) <> ''),
  transition_duration_ms  INTEGER     CHECK (transition_duration_ms IS NULL OR transition_duration_ms >= 0),
  transition_easing       TEXT,
  display_order           INTEGER     NOT NULL DEFAULT 0,
  is_active               BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT section_tabs_section_key_key UNIQUE (section_id, tab_key)
);

CREATE INDEX IF NOT EXISTS section_tabs_section_order_idx
  ON cms.section_tabs (section_id, display_order);

DROP TRIGGER IF EXISTS section_tabs_touch ON cms.section_tabs;
CREATE TRIGGER section_tabs_touch BEFORE UPDATE ON cms.section_tabs
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- stat_items — a number, a label and an optional icon.
--
-- Backs the Statistics screen and, today, Explore our world's "20+ Virtual
-- Branches" and "130+ Physical Branches". The hero's KPI tiles are NOT here:
-- they carry an ornament kind (plain / star / logo) that drives which
-- decoration renders, which these do not, and they already have hero_kpis.
--
-- owner_key groups stats within a section so one fold can hold more than one
-- run of them without another table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.stat_items (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id     BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  owner_key      TEXT        NOT NULL DEFAULT 'default',
  value          TEXT        NOT NULL CHECK (btrim(value) <> ''),
  label          TEXT        NOT NULL DEFAULT '',
  -- "Virtual / Branches" is set on two lines in the frame.
  label_lines    TEXT[]      NOT NULL DEFAULT '{}',
  description    TEXT        NOT NULL DEFAULT '',
  icon_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stat_items_section_order_idx
  ON cms.stat_items (section_id, owner_key, display_order);

DROP TRIGGER IF EXISTS stat_items_touch ON cms.stat_items;
CREATE TRIGGER stat_items_touch BEFORE UPDATE ON cms.stat_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- ticker_items — Market Pulse.
--
-- price and change are text, not numeric: they are formatted quotes carrying
-- their own separators and unit ("24,456.90", "30.00 %"), and the page prints
-- them verbatim. Storing them as numbers would mean re-deriving a format the
-- CMS has no way to know.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.ticker_items (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id     BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  name           TEXT        NOT NULL CHECK (btrim(name) <> ''),
  price          TEXT        NOT NULL DEFAULT '',
  change         TEXT        NOT NULL DEFAULT '',
  -- Picks caret-up.svg or caret-down.svg and the colour with it.
  direction      TEXT        NOT NULL DEFAULT 'up',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ticker_items_direction_check CHECK (direction IN ('up', 'down'))
);

CREATE INDEX IF NOT EXISTS ticker_items_section_order_idx
  ON cms.ticker_items (section_id, display_order);

DROP TRIGGER IF EXISTS ticker_items_touch ON cms.ticker_items;
CREATE TRIGGER ticker_items_touch BEFORE UPDATE ON cms.ticker_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- bento_cards — Explore our world.
--
-- Four cards that do not share a shape: one carries a leverage figure, one
-- carries branch statistics (in stat_items), two carry only artwork. The
-- leverage columns are nullable because three of the four have none, and each
-- card has up to two artwork slots because the NRI and Baskets cards each
-- layer two exports.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.bento_cards (
  id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id              BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  card_key                TEXT        NOT NULL CHECK (card_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title_lines             TEXT[]      NOT NULL DEFAULT '{}',
  href                    TEXT,
  -- "Upto" / "4x" / "Leverage" — three separate runs at three type sizes.
  leverage_upto           TEXT,
  leverage_value          TEXT,
  leverage_label          TEXT,
  art_media_id            BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  art_secondary_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order           INTEGER     NOT NULL DEFAULT 0,
  is_active               BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT bento_cards_section_key_key UNIQUE (section_id, card_key)
);

CREATE INDEX IF NOT EXISTS bento_cards_section_order_idx
  ON cms.bento_cards (section_id, display_order);

DROP TRIGGER IF EXISTS bento_cards_touch ON cms.bento_cards;
CREATE TRIGGER bento_cards_touch BEFORE UPDATE ON cms.bento_cards
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- ipo_items — one row per IPO, hanging off the tab that lists it.
--
-- The dates are text for the same reason the ticker's price is: the card
-- prints "21-26 July 2026" and "28 July 2026" as authored, and a range is not
-- a DATE at all.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.ipo_items (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tab_id               BIGINT      NOT NULL REFERENCES cms.section_tabs (id) ON DELETE CASCADE,
  name                 TEXT        NOT NULL CHECK (btrim(name) <> ''),
  status               TEXT        NOT NULL DEFAULT '',
  date_range           TEXT        NOT NULL DEFAULT '',
  price_band           TEXT        NOT NULL DEFAULT '',
  issue_size           TEXT        NOT NULL DEFAULT '',
  min_investment       TEXT        NOT NULL DEFAULT '',
  min_investment_unit  TEXT        NOT NULL DEFAULT '',
  listing_note         TEXT        NOT NULL DEFAULT '',
  listing_date         TEXT        NOT NULL DEFAULT '',
  -- The 360 card leads with the close deadline instead of the listing date.
  closing_note         TEXT        NOT NULL DEFAULT '',
  closing_date         TEXT        NOT NULL DEFAULT '',
  apply_label          TEXT        NOT NULL DEFAULT 'Apply',
  know_more_label      TEXT        NOT NULL DEFAULT 'Know More',
  apply_href           TEXT,
  know_more_href       TEXT,
  display_order        INTEGER     NOT NULL DEFAULT 0,
  is_active            BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ipo_items_tab_order_idx ON cms.ipo_items (tab_id, display_order);

DROP TRIGGER IF EXISTS ipo_items_touch ON cms.ipo_items;
CREATE TRIGGER ipo_items_touch BEFORE UPDATE ON cms.ipo_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- offering_cards — Fund It, Protect It.
--
-- mobile_order is a real field, not a derived one: the mobile frame runs
-- Education, Home, Car where the desktop runs Home, Education, Car, and the
-- page applies it as a CSS order so the DOM keeps the desktop run.
--
-- art_mobile_media_id is separate because the wide export bakes a slice of the
-- neighbouring section's background into the artboard; the transparent copy is
-- a different file, not the same file at another size.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.offering_cards (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tab_id              BIGINT      NOT NULL REFERENCES cms.section_tabs (id) ON DELETE CASCADE,
  slug                TEXT        NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title               TEXT        NOT NULL CHECK (btrim(title) <> ''),
  lede                TEXT        NOT NULL DEFAULT '',
  -- The regular run that opens the second line, ahead of the emphasised claim.
  highlight_lead      TEXT        NOT NULL DEFAULT '',
  highlight           TEXT        NOT NULL DEFAULT '',
  cta_label           TEXT        NOT NULL DEFAULT '',
  cta_label_mobile    TEXT        NOT NULL DEFAULT '',
  cta_href            TEXT,
  mobile_order        INTEGER     NOT NULL DEFAULT 0,
  art_media_id        BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  art_mobile_media_id BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order       INTEGER     NOT NULL DEFAULT 0,
  is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT offering_cards_tab_slug_key UNIQUE (tab_id, slug)
);

CREATE INDEX IF NOT EXISTS offering_cards_tab_order_idx
  ON cms.offering_cards (tab_id, display_order);

DROP TRIGGER IF EXISTS offering_cards_touch ON cms.offering_cards;
CREATE TRIGGER offering_cards_touch BEFORE UPDATE ON cms.offering_cards
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- purpose_cards / purpose_card_points — Invest with a purpose.
--
-- The bullets are their own table rather than a TEXT[] because the dashboard
-- reorders and disables them individually; a TEXT[] can do neither without
-- rewriting the whole array.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.purpose_cards (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id     BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  slug           TEXT        NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title          TEXT        NOT NULL CHECK (btrim(title) <> ''),
  lede           TEXT        NOT NULL DEFAULT '',
  cta_label      TEXT        NOT NULL DEFAULT '',
  cta_href       TEXT,
  art_media_id   BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT purpose_cards_section_slug_key UNIQUE (section_id, slug)
);

CREATE INDEX IF NOT EXISTS purpose_cards_section_order_idx
  ON cms.purpose_cards (section_id, display_order);

DROP TRIGGER IF EXISTS purpose_cards_touch ON cms.purpose_cards;
CREATE TRIGGER purpose_cards_touch BEFORE UPDATE ON cms.purpose_cards
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

CREATE TABLE IF NOT EXISTS cms.purpose_card_points (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  card_id        BIGINT      NOT NULL REFERENCES cms.purpose_cards (id) ON DELETE CASCADE,
  text           TEXT        NOT NULL CHECK (btrim(text) <> ''),
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS purpose_card_points_card_order_idx
  ON cms.purpose_card_points (card_id, display_order);

DROP TRIGGER IF EXISTS purpose_card_points_touch ON cms.purpose_card_points;
CREATE TRIGGER purpose_card_points_touch BEFORE UPDATE ON cms.purpose_card_points
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- platform_steps / platform_panels — Next-gen platform.
--
-- Panels are a separate table from steps because the two are not 1:1 in
-- principle: the Figma note asks for the panel to change per step but ships
-- one export per tab, so today three panel rows point at the same asset.
-- Modelling them as a column on the step would make the eventual per-step
-- artwork a migration rather than an edit.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.platform_steps (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tab_id         BIGINT      NOT NULL REFERENCES cms.section_tabs (id) ON DELETE CASCADE,
  title          TEXT        NOT NULL CHECK (btrim(title) <> ''),
  body           TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS platform_steps_tab_order_idx
  ON cms.platform_steps (tab_id, display_order);

DROP TRIGGER IF EXISTS platform_steps_touch ON cms.platform_steps;
CREATE TRIGGER platform_steps_touch BEFORE UPDATE ON cms.platform_steps
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

CREATE TABLE IF NOT EXISTS cms.platform_panels (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tab_id         BIGINT      NOT NULL REFERENCES cms.section_tabs (id) ON DELETE CASCADE,
  media_id       BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  -- Which step this panel is shown for. Zero-based, matching the component.
  step_index     INTEGER     NOT NULL DEFAULT 0 CHECK (step_index >= 0),
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT platform_panels_tab_step_key UNIQUE (tab_id, step_index)
);

CREATE INDEX IF NOT EXISTS platform_panels_tab_order_idx
  ON cms.platform_panels (tab_id, display_order);

DROP TRIGGER IF EXISTS platform_panels_touch ON cms.platform_panels;
CREATE TRIGGER platform_panels_touch BEFORE UPDATE ON cms.platform_panels
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- research_reports — Analysis you can trust.
--
-- published_on is a real DATE here, unlike the IPO dates: the card prints one
-- day, not a range, so the value can be stored properly and formatted on
-- render.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.research_reports (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tab_id          BIGINT      NOT NULL REFERENCES cms.section_tabs (id) ON DELETE CASCADE,
  title           TEXT        NOT NULL CHECK (btrim(title) <> ''),
  kind            TEXT        NOT NULL DEFAULT '',
  published_on    DATE,
  href            TEXT,
  cover_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order   INTEGER     NOT NULL DEFAULT 0,
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS research_reports_tab_order_idx
  ON cms.research_reports (tab_id, display_order);

DROP TRIGGER IF EXISTS research_reports_touch ON cms.research_reports;
CREATE TRIGGER research_reports_touch BEFORE UPDATE ON cms.research_reports
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- news_items — Your Daily Market Digest.
--
-- is_lead marks the single large card. It is a flag rather than a separate
-- table because the lead and the list items carry exactly the same fields and
-- an editor swapping which story leads should be a toggle, not a retype.
--
-- published_label is text: the card prints "Jul 29, 2026 06:45 PM IST"
-- including a timezone abbreviation, which no date formatting on this side
-- would reproduce reliably.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.news_items (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id       BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  title            TEXT        NOT NULL CHECK (btrim(title) <> ''),
  published_label  TEXT        NOT NULL DEFAULT '',
  href             TEXT,
  is_lead          BOOLEAN     NOT NULL DEFAULT FALSE,
  image_media_id   BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order    INTEGER     NOT NULL DEFAULT 0,
  is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS news_items_section_order_idx
  ON cms.news_items (section_id, display_order);
-- At most one lead story per section. A partial unique index says that once,
-- rather than leaving it to whichever code path happens to write last.
CREATE UNIQUE INDEX IF NOT EXISTS news_items_one_lead_idx
  ON cms.news_items (section_id) WHERE is_lead;

DROP TRIGGER IF EXISTS news_items_touch ON cms.news_items;
CREATE TRIGGER news_items_touch BEFORE UPDATE ON cms.news_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- lessons — Learn before you invest.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.lessons (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tab_id              BIGINT      NOT NULL REFERENCES cms.section_tabs (id) ON DELETE CASCADE,
  title               TEXT        NOT NULL CHECK (btrim(title) <> ''),
  -- "12:45" as printed, and read aloud by the screen-reader label beside it.
  duration            TEXT        NOT NULL DEFAULT '',
  published_on        DATE,
  href                TEXT,
  thumbnail_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order       INTEGER     NOT NULL DEFAULT 0,
  is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS lessons_tab_order_idx ON cms.lessons (tab_id, display_order);

DROP TRIGGER IF EXISTS lessons_touch ON cms.lessons;
CREATE TRIGGER lessons_touch BEFORE UPDATE ON cms.lessons
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- testimonials.
--
-- Quote and author only: that is what the card renders. There is no avatar
-- column, because adding one would put a picker in the dashboard that changes
-- nothing on the page.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.testimonials (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id     BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  quote          TEXT        NOT NULL CHECK (btrim(quote) <> ''),
  author         TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS testimonials_section_order_idx
  ON cms.testimonials (section_id, display_order);

DROP TRIGGER IF EXISTS testimonials_touch ON cms.testimonials;
CREATE TRIGGER testimonials_touch BEFORE UPDATE ON cms.testimonials
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- pricing_plans / pricing_plan_features.
--
-- accent is constrained rather than free text because it selects a stylesheet
-- branch and a plan icon; an unrecognised value would render an unstyled card.
-- Adding a fourth plan style is therefore deliberately a migration.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.pricing_plans (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id     BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  name           TEXT        NOT NULL CHECK (btrim(name) <> ''),
  price          TEXT        NOT NULL DEFAULT '',
  price_note     TEXT        NOT NULL DEFAULT '',
  accent         TEXT        NOT NULL DEFAULT 'suvidha',
  cta_label      TEXT        NOT NULL DEFAULT '',
  cta_href       TEXT,
  icon_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pricing_plans_accent_check
    CHECK (accent IN ('suvidha', 'prozero', 'women'))
);

CREATE INDEX IF NOT EXISTS pricing_plans_section_order_idx
  ON cms.pricing_plans (section_id, display_order);

DROP TRIGGER IF EXISTS pricing_plans_touch ON cms.pricing_plans;
CREATE TRIGGER pricing_plans_touch BEFORE UPDATE ON cms.pricing_plans
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

CREATE TABLE IF NOT EXISTS cms.pricing_plan_features (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plan_id        BIGINT      NOT NULL REFERENCES cms.pricing_plans (id) ON DELETE CASCADE,
  text           TEXT        NOT NULL CHECK (btrim(text) <> ''),
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS pricing_plan_features_plan_order_idx
  ON cms.pricing_plan_features (plan_id, display_order);

DROP TRIGGER IF EXISTS pricing_plan_features_touch ON cms.pricing_plan_features;
CREATE TRIGGER pricing_plan_features_touch BEFORE UPDATE ON cms.pricing_plan_features
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- faq_items.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.faq_items (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id     BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  question       TEXT        NOT NULL CHECK (btrim(question) <> ''),
  answer         TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS faq_items_section_order_idx
  ON cms.faq_items (section_id, display_order);

DROP TRIGGER IF EXISTS faq_items_touch ON cms.faq_items;
CREATE TRIGGER faq_items_touch BEFORE UPDATE ON cms.faq_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- promo_banners — the content of the App Download Promo card.
--
-- These rows ARE that card, which is why scheduling one does not add a fold to
-- the page: the card already renders, and the window decides which version of
-- it an editor is showing. The lowest display_order among the qualifying rows
-- wins, so a scheduled banner expiring never leaves the card blank as long as
-- one open-ended row exists.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.promo_banners (
  id                     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id             BIGINT      NOT NULL REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  title                  TEXT        NOT NULL CHECK (btrim(title) <> ''),
  description            TEXT        NOT NULL DEFAULT '',
  cta_label              TEXT        NOT NULL DEFAULT '',
  cta_href               TEXT,
  image_media_id         BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  image_mobile_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  -- Either bound may be null, meaning open-ended in that direction.
  starts_at              TIMESTAMPTZ,
  ends_at                TIMESTAMPTZ,
  display_order          INTEGER     NOT NULL DEFAULT 0,
  is_active              BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- A window that ends before it starts can never show; reject it at write
  -- time rather than letting an editor wonder why nothing changed.
  CONSTRAINT promo_banners_window_check
    CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS promo_banners_section_order_idx
  ON cms.promo_banners (section_id, display_order);
CREATE INDEX IF NOT EXISTS promo_banners_window_idx
  ON cms.promo_banners (starts_at, ends_at);

DROP TRIGGER IF EXISTS promo_banners_touch ON cms.promo_banners;
CREATE TRIGGER promo_banners_touch BEFORE UPDATE ON cms.promo_banners
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- sticky_nudge — the bar pinned to the bottom of the viewport. Singleton per
-- section, like hero_sections.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.sticky_nudge (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id          BIGINT      NOT NULL UNIQUE REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  title               TEXT        NOT NULL DEFAULT '',
  mobile_placeholder  TEXT        NOT NULL DEFAULT '',
  name_placeholder    TEXT        NOT NULL DEFAULT '',
  cta_label           TEXT        NOT NULL DEFAULT '',
  cta_href            TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS sticky_nudge_touch ON cms.sticky_nudge;
CREATE TRIGGER sticky_nudge_touch BEFORE UPDATE ON cms.sticky_nudge
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- legal_content — the footer's registration, trading, authorisation, warning
-- and copyright blocks.
--
-- Not attached to a page: the footer is chrome on every marketing route, so
-- these are site-level like site_settings, keyed by content_key.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.legal_content (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  content_key    TEXT        NOT NULL UNIQUE CHECK (content_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name           TEXT        NOT NULL CHECK (btrim(name) <> ''),
  body           TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS legal_content_order_idx ON cms.legal_content (display_order);

DROP TRIGGER IF EXISTS legal_content_touch ON cms.legal_content;
CREATE TRIGGER legal_content_touch BEFORE UPDATE ON cms.legal_content
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- stock_index_letters / stock_links — the footer's stocks directory.
--
-- Site-level for the same reason as legal_content.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.stock_index_letters (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  letter         TEXT        NOT NULL UNIQUE CHECK (btrim(letter) <> ''),
  href           TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stock_index_letters_order_idx
  ON cms.stock_index_letters (display_order);

DROP TRIGGER IF EXISTS stock_index_letters_touch ON cms.stock_index_letters;
CREATE TRIGGER stock_index_letters_touch BEFORE UPDATE ON cms.stock_index_letters
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

CREATE TABLE IF NOT EXISTS cms.stock_links (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  label          TEXT        NOT NULL CHECK (btrim(label) <> ''),
  href           TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stock_links_order_idx ON cms.stock_links (display_order);

DROP TRIGGER IF EXISTS stock_links_touch ON cms.stock_links;
CREATE TRIGGER stock_links_touch BEFORE UPDATE ON cms.stock_links
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();
