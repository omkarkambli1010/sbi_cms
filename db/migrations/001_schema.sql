-- ============================================================================
-- 001_schema.sql — core CMS schema
--
-- Scope: the content needed by the site chrome and the hero fold —
-- site settings, media, pages, page sections, SEO, navigation, hero.
-- The pages/page_sections registry is generic on purpose: the remaining
-- home-page folds (bento, IPOs, offerings, purpose, platform, research, news,
-- learn, testimonials, pricing, FAQ, app promo, sticky nudge, footer) attach
-- to it in later migrations without this file changing.
--
-- Conventions used throughout:
--   * identity primary keys, never serial
--   * every content row carries is_active and display_order where it is listed
--   * created_at / updated_at on every table, updated_at kept by trigger
--   * text columns that must not be blank are constrained, not just NOT NULL
--   * every foreign key states its delete behaviour explicitly
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS cms;

SET search_path = cms, public;

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION cms.touch_updated_at() IS
  'Row-level BEFORE UPDATE trigger: stamps updated_at so the application never has to.';

-- ---------------------------------------------------------------------------
-- admin_users — who may sign in to the dashboard
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.admin_users (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email          TEXT        NOT NULL,
  full_name      TEXT        NOT NULL CHECK (btrim(full_name) <> ''),
  -- scrypt. The salt is stored beside the hash because it is not a secret:
  -- it exists to make identical passwords hash differently.
  password_hash  TEXT        NOT NULL,
  password_salt  TEXT        NOT NULL,
  role           TEXT        NOT NULL DEFAULT 'editor',
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  last_login_at  TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT admin_users_role_check CHECK (role IN ('admin', 'editor')),
  CONSTRAINT admin_users_email_check CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')
);

-- Case-insensitive uniqueness without depending on the citext extension being
-- installed on the target server.
CREATE UNIQUE INDEX IF NOT EXISTS admin_users_email_lower_key
  ON cms.admin_users (lower(email));

DROP TRIGGER IF EXISTS admin_users_touch ON cms.admin_users;
CREATE TRIGGER admin_users_touch BEFORE UPDATE ON cms.admin_users
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- admin_sessions — opaque server-side sessions
--
-- Only the SHA-256 of the cookie value is stored. A leaked database therefore
-- does not hand over usable session cookies.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.admin_sessions (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id      BIGINT      NOT NULL REFERENCES cms.admin_users (id) ON DELETE CASCADE,
  token_hash   TEXT        NOT NULL UNIQUE,
  user_agent   TEXT,
  ip_address   INET,
  expires_at   TIMESTAMPTZ NOT NULL,
  revoked_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS admin_sessions_user_id_idx ON cms.admin_sessions (user_id);
CREATE INDEX IF NOT EXISTS admin_sessions_expires_at_idx ON cms.admin_sessions (expires_at);

DROP TRIGGER IF EXISTS admin_sessions_touch ON cms.admin_sessions;
CREATE TRIGGER admin_sessions_touch BEFORE UPDATE ON cms.admin_sessions
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- media_assets — every image, icon, illustration and document
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.media_assets (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  -- Public path as the website requests it, e.g. /figma/hero/mockup.png.
  -- Unique so the same file cannot be registered twice under two rows.
  url           TEXT        NOT NULL UNIQUE CHECK (btrim(url) <> ''),
  file_name     TEXT        NOT NULL,
  -- Empty alt text is meaningful (decorative), so '' is allowed and NULL is not.
  alt_text      TEXT        NOT NULL DEFAULT '',
  title         TEXT,
  mime_type     TEXT        NOT NULL,
  byte_size     BIGINT      CHECK (byte_size IS NULL OR byte_size >= 0),
  width         INTEGER     CHECK (width IS NULL OR width > 0),
  height        INTEGER     CHECK (height IS NULL OR height > 0),
  -- Loose grouping for the media library filter, not a hard taxonomy.
  folder        TEXT        NOT NULL DEFAULT 'general',
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  uploaded_by   BIGINT      REFERENCES cms.admin_users (id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS media_assets_folder_idx ON cms.media_assets (folder);
CREATE INDEX IF NOT EXISTS media_assets_active_idx ON cms.media_assets (is_active);

DROP TRIGGER IF EXISTS media_assets_touch ON cms.media_assets;
CREATE TRIGGER media_assets_touch BEFORE UPDATE ON cms.media_assets
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- pages — the page registry. One row today ('home'); the table exists so more
-- pages need no schema change.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.pages (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slug         TEXT        NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name         TEXT        NOT NULL CHECK (btrim(name) <> ''),
  route        TEXT        NOT NULL UNIQUE CHECK (route LIKE '/%'),
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS pages_touch ON cms.pages;
CREATE TRIGGER pages_touch BEFORE UPDATE ON cms.pages
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- page_sections — which folds a page renders, in what order, and whether each
-- is switched on. section_key maps to the React component that renders it.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.page_sections (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  page_id        BIGINT      NOT NULL REFERENCES cms.pages (id) ON DELETE CASCADE,
  section_key    TEXT        NOT NULL CHECK (section_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name           TEXT        NOT NULL CHECK (btrim(name) <> ''),
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- A page cannot render the same fold twice.
  CONSTRAINT page_sections_page_key_key UNIQUE (page_id, section_key)
);

CREATE INDEX IF NOT EXISTS page_sections_page_order_idx
  ON cms.page_sections (page_id, display_order);

DROP TRIGGER IF EXISTS page_sections_touch ON cms.page_sections;
CREATE TRIGGER page_sections_touch BEFORE UPDATE ON cms.page_sections
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- site_settings — brand-level values shared by header, footer and metadata.
-- Singleton, enforced by a one-row check rather than by convention.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.site_settings (
  id                  BOOLEAN     PRIMARY KEY DEFAULT TRUE,
  brand_name          TEXT        NOT NULL CHECK (btrim(brand_name) <> ''),
  legal_name          TEXT        NOT NULL CHECK (btrim(legal_name) <> ''),
  address             TEXT        NOT NULL DEFAULT '',
  phone               TEXT        NOT NULL DEFAULT '',
  email               TEXT        NOT NULL DEFAULT '',
  search_placeholder  TEXT        NOT NULL DEFAULT '',
  logo_media_id       BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  footer_logo_media_id BIGINT     REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT site_settings_singleton CHECK (id)
);

DROP TRIGGER IF EXISTS site_settings_touch ON cms.site_settings;
CREATE TRIGGER site_settings_touch BEFORE UPDATE ON cms.site_settings
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- seo_metadata — one row per page
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.seo_metadata (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  page_id           BIGINT      NOT NULL UNIQUE REFERENCES cms.pages (id) ON DELETE CASCADE,
  meta_title        TEXT        NOT NULL DEFAULT '',
  meta_description  TEXT        NOT NULL DEFAULT '',
  -- Stored as an array rather than a comma-joined string so the dashboard can
  -- edit keywords individually and the API never has to parse.
  meta_keywords     TEXT[]      NOT NULL DEFAULT '{}',
  canonical_url     TEXT,
  og_title          TEXT,
  og_description    TEXT,
  og_image_media_id BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  robots            TEXT        NOT NULL DEFAULT 'index,follow',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS seo_metadata_touch ON cms.seo_metadata;
CREATE TRIGGER seo_metadata_touch BEFORE UPDATE ON cms.seo_metadata
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- navigation_menus / navigation_items
--
-- One table pair serves the header menu, the footer link columns and the
-- social row: they differ by which menu they belong to, not in shape. Items
-- self-reference so a menu can nest without another table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.navigation_menus (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  menu_key     TEXT        NOT NULL UNIQUE CHECK (menu_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name         TEXT        NOT NULL CHECK (btrim(name) <> ''),
  location     TEXT        NOT NULL DEFAULT 'header',
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT navigation_menus_location_check
    CHECK (location IN ('header', 'footer', 'social', 'utility'))
);

DROP TRIGGER IF EXISTS navigation_menus_touch ON cms.navigation_menus;
CREATE TRIGGER navigation_menus_touch BEFORE UPDATE ON cms.navigation_menus
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

CREATE TABLE IF NOT EXISTS cms.navigation_items (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  menu_id        BIGINT      NOT NULL REFERENCES cms.navigation_menus (id) ON DELETE CASCADE,
  parent_id      BIGINT      REFERENCES cms.navigation_items (id) ON DELETE CASCADE,
  label          TEXT        NOT NULL CHECK (btrim(label) <> ''),
  href           TEXT        NOT NULL DEFAULT '#',
  -- Icon for the social row; null everywhere else.
  icon_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  opens_in_new_tab BOOLEAN   NOT NULL DEFAULT FALSE,
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- An item cannot be its own parent. Deeper cycles are prevented in the
  -- reparent function, which walks the ancestry before committing.
  CONSTRAINT navigation_items_no_self_parent CHECK (parent_id IS NULL OR parent_id <> id)
);

CREATE INDEX IF NOT EXISTS navigation_items_menu_order_idx
  ON cms.navigation_items (menu_id, display_order);
CREATE INDEX IF NOT EXISTS navigation_items_parent_idx
  ON cms.navigation_items (parent_id);

DROP TRIGGER IF EXISTS navigation_items_touch ON cms.navigation_items;
CREATE TRIGGER navigation_items_touch BEFORE UPDATE ON cms.navigation_items
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- hero_sections — the hero fold. One row per page section, so a second page
-- can have its own hero without a second table.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.hero_sections (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  section_id          BIGINT      NOT NULL UNIQUE REFERENCES cms.page_sections (id) ON DELETE CASCADE,
  title_lead          TEXT        NOT NULL DEFAULT '',
  -- The two subtext lines are separate columns rather than an array: the
  -- design breaks them deliberately and an editor needs to see both slots.
  subtext_line_1      TEXT        NOT NULL DEFAULT '',
  subtext_line_2      TEXT        NOT NULL DEFAULT '',
  watermark_left      TEXT        NOT NULL DEFAULT '',
  watermark_right     TEXT        NOT NULL DEFAULT '',
  mockup_media_id     BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  -- Lead form labels. Desktop and mobile word several of these differently,
  -- which is why both sets are stored rather than derived.
  form_name_label            TEXT NOT NULL DEFAULT '',
  form_name_placeholder      TEXT NOT NULL DEFAULT '',
  form_mobile_label          TEXT NOT NULL DEFAULT '',
  form_mobile_placeholder    TEXT NOT NULL DEFAULT '',
  form_mobile_help           TEXT NOT NULL DEFAULT '',
  form_consent_label         TEXT NOT NULL DEFAULT '',
  form_submit_label          TEXT NOT NULL DEFAULT '',
  form_name_label_mobile         TEXT NOT NULL DEFAULT '',
  form_name_placeholder_mobile   TEXT NOT NULL DEFAULT '',
  form_mobile_label_mobile       TEXT NOT NULL DEFAULT '',
  form_mobile_placeholder_mobile TEXT NOT NULL DEFAULT '',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS hero_sections_touch ON cms.hero_sections;
CREATE TRIGGER hero_sections_touch BEFORE UPDATE ON cms.hero_sections
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- hero_rotating_lines — the headline that cycles in place. Two lines per
-- entry, ordered.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.hero_rotating_lines (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hero_id        BIGINT      NOT NULL REFERENCES cms.hero_sections (id) ON DELETE CASCADE,
  line_1         TEXT        NOT NULL CHECK (btrim(line_1) <> ''),
  line_2         TEXT        NOT NULL DEFAULT '',
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hero_rotating_lines_order_idx
  ON cms.hero_rotating_lines (hero_id, display_order);

DROP TRIGGER IF EXISTS hero_rotating_lines_touch ON cms.hero_rotating_lines;
CREATE TRIGGER hero_rotating_lines_touch BEFORE UPDATE ON cms.hero_rotating_lines
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();

-- ---------------------------------------------------------------------------
-- hero_kpis — the three proof tiles under the wordmark. kind drives which
-- ornament the tile renders (plain value, star rating, or a logo lockup),
-- which is why value is nullable: the "Backed by SBI" tile has none.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cms.hero_kpis (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hero_id        BIGINT      NOT NULL REFERENCES cms.hero_sections (id) ON DELETE CASCADE,
  kpi_key        TEXT        NOT NULL CHECK (kpi_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  kind           TEXT        NOT NULL DEFAULT 'value',
  value          TEXT,
  label          TEXT        NOT NULL CHECK (btrim(label) <> ''),
  icon_media_id  BIGINT      REFERENCES cms.media_assets (id) ON DELETE SET NULL,
  display_order  INTEGER     NOT NULL DEFAULT 0,
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT hero_kpis_kind_check CHECK (kind IN ('value', 'rating', 'logo')),
  CONSTRAINT hero_kpis_hero_key_key UNIQUE (hero_id, kpi_key),
  -- A value tile with no value would render an empty box.
  CONSTRAINT hero_kpis_value_present
    CHECK (kind = 'logo' OR (value IS NOT NULL AND btrim(value) <> ''))
);

CREATE INDEX IF NOT EXISTS hero_kpis_order_idx ON cms.hero_kpis (hero_id, display_order);

DROP TRIGGER IF EXISTS hero_kpis_touch ON cms.hero_kpis;
CREATE TRIGGER hero_kpis_touch BEFORE UPDATE ON cms.hero_kpis
  FOR EACH ROW EXECUTE FUNCTION cms.touch_updated_at();
