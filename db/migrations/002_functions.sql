-- ============================================================================
-- 002_functions.sql — CRUD surface
--
-- The application calls these and nothing else; there is no ad-hoc SQL in the
-- API layer. Naming is <entity>_<verb>, and every mutating function returns the
-- affected row so the caller never needs a follow-up SELECT.
--
-- All are SECURITY INVOKER (the default). They exist to centralise and name the
-- operations, not to escalate privilege — the app role already owns these
-- tables, and SECURITY DEFINER here would only widen the blast radius of an
-- injection bug without buying anything.
-- ============================================================================

SET search_path = cms, public;

-- ===========================================================================
-- admin_users
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.admin_user_create(
  p_email         TEXT,
  p_full_name     TEXT,
  p_password_hash TEXT,
  p_password_salt TEXT,
  p_role          TEXT DEFAULT 'editor'
)
RETURNS cms.admin_users
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_users;
BEGIN
  INSERT INTO cms.admin_users (email, full_name, password_hash, password_salt, role)
  VALUES (btrim(p_email), btrim(p_full_name), p_password_hash, p_password_salt, p_role)
  RETURNING * INTO v_row;

  RETURN v_row;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'An account already exists for %', p_email
      USING ERRCODE = 'unique_violation';
END;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_get_by_email(p_email TEXT)
RETURNS cms.admin_users
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.admin_users WHERE lower(email) = lower(btrim(p_email));
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_get(p_id BIGINT)
RETURNS cms.admin_users
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.admin_users WHERE id = p_id;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_list()
RETURNS SETOF cms.admin_users
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.admin_users ORDER BY created_at;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_update(
  p_id        BIGINT,
  p_full_name TEXT,
  p_role      TEXT
)
RETURNS cms.admin_users
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_users;
BEGIN
  UPDATE cms.admin_users
     SET full_name = btrim(p_full_name),
         role      = p_role
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_set_password(
  p_id            BIGINT,
  p_password_hash TEXT,
  p_password_salt TEXT
)
RETURNS cms.admin_users
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_users;
BEGIN
  UPDATE cms.admin_users
     SET password_hash = p_password_hash,
         password_salt = p_password_salt
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  -- Changing a password ends every other session for that account.
  UPDATE cms.admin_sessions
     SET revoked_at = now()
   WHERE user_id = p_id AND revoked_at IS NULL;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.admin_users
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_users;
BEGIN
  UPDATE cms.admin_users SET is_active = p_is_active WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  IF NOT p_is_active THEN
    UPDATE cms.admin_sessions
       SET revoked_at = now()
     WHERE user_id = p_id AND revoked_at IS NULL;
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_admins INTEGER;
BEGIN
  -- Refuse to remove the last active administrator: the dashboard would become
  -- unreachable and there is no recovery path from inside the product.
  SELECT count(*) INTO v_admins
    FROM cms.admin_users
   WHERE role = 'admin' AND is_active AND id <> p_id;

  IF v_admins = 0 THEN
    RAISE EXCEPTION 'Cannot delete the last active administrator'
      USING ERRCODE = 'restrict_violation';
  END IF;

  DELETE FROM cms.admin_users WHERE id = p_id;
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION cms.admin_user_touch_login(p_id BIGINT)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE cms.admin_users SET last_login_at = now() WHERE id = p_id;
$$;

-- ===========================================================================
-- admin_sessions
-- ===========================================================================

-- Small helper so session_create never raises on a junk address.
CREATE OR REPLACE FUNCTION cms.try_cast_inet(p_value TEXT)
RETURNS INET
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN p_value::INET;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION cms.session_create(
  p_user_id    BIGINT,
  p_token_hash TEXT,
  p_expires_at TIMESTAMPTZ,
  p_user_agent TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL
)
RETURNS cms.admin_sessions
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_sessions;
BEGIN
  INSERT INTO cms.admin_sessions (user_id, token_hash, expires_at, user_agent, ip_address)
  VALUES (
    p_user_id,
    p_token_hash,
    p_expires_at,
    p_user_agent,
    -- A malformed forwarded-for header should not fail a login.
    CASE WHEN p_ip_address IS NULL OR btrim(p_ip_address) = '' THEN NULL
         ELSE try_cast_inet(p_ip_address) END
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

/** The joined shape the session middleware needs in one round trip. */
CREATE OR REPLACE FUNCTION cms.session_resolve(p_token_hash TEXT)
RETURNS TABLE (
  session_id   BIGINT,
  user_id      BIGINT,
  email        TEXT,
  full_name    TEXT,
  role         TEXT,
  expires_at   TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT s.id, u.id, u.email, u.full_name, u.role, s.expires_at
    FROM cms.admin_sessions s
    JOIN cms.admin_users u ON u.id = s.user_id
   WHERE s.token_hash = p_token_hash
     AND s.revoked_at IS NULL
     AND s.expires_at > now()
     AND u.is_active;
$$;

CREATE OR REPLACE FUNCTION cms.session_revoke(p_token_hash TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE cms.admin_sessions
     SET revoked_at = now()
   WHERE token_hash = p_token_hash AND revoked_at IS NULL;

  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION cms.session_purge_expired()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM cms.admin_sessions
   WHERE expires_at < now() - INTERVAL '7 days'
      OR (revoked_at IS NOT NULL AND revoked_at < now() - INTERVAL '7 days');

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ===========================================================================
-- media_assets
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.media_create(
  p_url         TEXT,
  p_file_name   TEXT,
  p_mime_type   TEXT,
  p_alt_text    TEXT    DEFAULT '',
  p_title       TEXT    DEFAULT NULL,
  p_byte_size   BIGINT  DEFAULT NULL,
  p_width       INTEGER DEFAULT NULL,
  p_height      INTEGER DEFAULT NULL,
  p_folder      TEXT    DEFAULT 'general',
  p_uploaded_by BIGINT  DEFAULT NULL
)
RETURNS cms.media_assets
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.media_assets;
BEGIN
  INSERT INTO cms.media_assets (
    url, file_name, mime_type, alt_text, title, byte_size, width, height, folder, uploaded_by
  )
  VALUES (
    btrim(p_url), btrim(p_file_name), btrim(p_mime_type), coalesce(p_alt_text, ''),
    p_title, p_byte_size, p_width, p_height, coalesce(nullif(btrim(p_folder), ''), 'general'),
    p_uploaded_by
  )
  -- Re-registering a path that already exists updates it rather than failing;
  -- that is what "replace this image" means from the dashboard.
  ON CONFLICT (url) DO UPDATE
     SET file_name = EXCLUDED.file_name,
         mime_type = EXCLUDED.mime_type,
         alt_text  = EXCLUDED.alt_text,
         title     = EXCLUDED.title,
         byte_size = EXCLUDED.byte_size,
         width     = EXCLUDED.width,
         height    = EXCLUDED.height,
         folder    = EXCLUDED.folder
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.media_get(p_id BIGINT)
RETURNS cms.media_assets
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.media_assets WHERE id = p_id;
$$;

/** Search + filter + pagination for the media library table. */
CREATE OR REPLACE FUNCTION cms.media_list(
  p_search      TEXT    DEFAULT NULL,
  p_folder      TEXT    DEFAULT NULL,
  p_only_active BOOLEAN DEFAULT FALSE,
  p_limit       INTEGER DEFAULT 50,
  p_offset      INTEGER DEFAULT 0
)
RETURNS TABLE (
  id          BIGINT,
  url         TEXT,
  file_name   TEXT,
  alt_text    TEXT,
  title       TEXT,
  mime_type   TEXT,
  byte_size   BIGINT,
  width       INTEGER,
  height      INTEGER,
  folder      TEXT,
  is_active   BOOLEAN,
  created_at  TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ,
  total_count BIGINT
)
LANGUAGE sql
STABLE
AS $$
  WITH filtered AS (
    SELECT m.*
      FROM cms.media_assets m
     WHERE (p_search IS NULL OR btrim(p_search) = ''
            OR m.file_name ILIKE '%' || btrim(p_search) || '%'
            OR m.alt_text  ILIKE '%' || btrim(p_search) || '%'
            OR m.url       ILIKE '%' || btrim(p_search) || '%')
       AND (p_folder IS NULL OR btrim(p_folder) = '' OR m.folder = p_folder)
       AND (NOT p_only_active OR m.is_active)
  )
  SELECT f.id, f.url, f.file_name, f.alt_text, f.title, f.mime_type, f.byte_size,
         f.width, f.height, f.folder, f.is_active, f.created_at, f.updated_at,
         count(*) OVER () AS total_count
    FROM filtered f
   ORDER BY f.created_at DESC
   LIMIT greatest(p_limit, 1) OFFSET greatest(p_offset, 0);
$$;

CREATE OR REPLACE FUNCTION cms.media_update(
  p_id       BIGINT,
  p_alt_text TEXT,
  p_title    TEXT,
  p_folder   TEXT
)
RETURNS cms.media_assets
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.media_assets;
BEGIN
  UPDATE cms.media_assets
     SET alt_text = coalesce(p_alt_text, ''),
         title    = p_title,
         folder   = coalesce(nullif(btrim(p_folder), ''), 'general')
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Media asset % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.media_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.media_assets
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.media_assets;
BEGIN
  UPDATE cms.media_assets SET is_active = p_is_active WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Media asset % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

/**
 * Deletes only when nothing references the asset. Every reference is ON DELETE
 * SET NULL, so an unguarded delete would silently blank a logo or a hero image
 * instead of telling the editor what is still using it.
 */
CREATE OR REPLACE FUNCTION cms.media_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_uses INTEGER;
BEGIN
  SELECT
    (SELECT count(*) FROM cms.site_settings   WHERE logo_media_id = p_id OR footer_logo_media_id = p_id)
  + (SELECT count(*) FROM cms.seo_metadata    WHERE og_image_media_id = p_id)
  + (SELECT count(*) FROM cms.navigation_items WHERE icon_media_id = p_id)
  + (SELECT count(*) FROM cms.hero_sections   WHERE mockup_media_id = p_id)
  + (SELECT count(*) FROM cms.hero_kpis       WHERE icon_media_id = p_id)
  INTO v_uses;

  IF v_uses > 0 THEN
    RAISE EXCEPTION 'Media asset % is used in % place(s) and cannot be deleted', p_id, v_uses
      USING ERRCODE = 'restrict_violation';
  END IF;

  DELETE FROM cms.media_assets WHERE id = p_id;
  RETURN FOUND;
END;
$$;

-- ===========================================================================
-- pages / page_sections
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.page_list()
RETURNS SETOF cms.pages
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.pages ORDER BY id;
$$;

CREATE OR REPLACE FUNCTION cms.page_get_by_slug(p_slug TEXT)
RETURNS cms.pages
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.pages WHERE slug = btrim(p_slug);
$$;

CREATE OR REPLACE FUNCTION cms.section_list_by_page(p_page_slug TEXT)
RETURNS TABLE (
  id            BIGINT,
  section_key   TEXT,
  name          TEXT,
  display_order INTEGER,
  is_active     BOOLEAN,
  updated_at    TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT s.id, s.section_key, s.name, s.display_order, s.is_active, s.updated_at
    FROM cms.page_sections s
    JOIN cms.pages p ON p.id = s.page_id
   WHERE p.slug = btrim(p_page_slug)
   ORDER BY s.display_order, s.id;
$$;

CREATE OR REPLACE FUNCTION cms.section_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.page_sections
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.page_sections;
BEGIN
  UPDATE cms.page_sections SET is_active = p_is_active WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Section % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

/**
 * Reorder helper shared in spirit by every ordered list: the caller sends the
 * ids in their new order and the function writes positions 1..n. Doing it in
 * one statement keeps the list consistent even if two editors save at once.
 */
CREATE OR REPLACE FUNCTION cms.section_reorder(p_page_slug TEXT, p_ids BIGINT[])
RETURNS SETOF cms.page_sections
LANGUAGE plpgsql
AS $$
DECLARE
  v_page_id BIGINT;
BEGIN
  SELECT id INTO v_page_id FROM cms.pages WHERE slug = btrim(p_page_slug);

  IF v_page_id IS NULL THEN
    RAISE EXCEPTION 'Page % not found', p_page_slug USING ERRCODE = 'no_data_found';
  END IF;

  -- Every id must belong to this page, or the reorder is rejected whole.
  IF EXISTS (
    SELECT 1 FROM unnest(p_ids) AS t(id)
     WHERE NOT EXISTS (
       SELECT 1 FROM cms.page_sections s WHERE s.id = t.id AND s.page_id = v_page_id
     )
  ) THEN
    RAISE EXCEPTION 'Reorder list contains a section that is not on page %', p_page_slug
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  UPDATE cms.page_sections s
     SET display_order = t.position
    FROM (SELECT id, ordinality::INTEGER AS position
            FROM unnest(p_ids) WITH ORDINALITY AS u(id, ordinality)) AS t
   WHERE s.id = t.id;

  RETURN QUERY
    SELECT * FROM cms.page_sections
     WHERE page_id = v_page_id
     ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- site_settings
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.site_settings_get()
RETURNS cms.site_settings
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.site_settings WHERE id;
$$;

CREATE OR REPLACE FUNCTION cms.site_settings_update(
  p_brand_name           TEXT,
  p_legal_name           TEXT,
  p_address              TEXT,
  p_phone                TEXT,
  p_email                TEXT,
  p_search_placeholder   TEXT,
  p_logo_media_id        BIGINT DEFAULT NULL,
  p_footer_logo_media_id BIGINT DEFAULT NULL
)
RETURNS cms.site_settings
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.site_settings;
BEGIN
  INSERT INTO cms.site_settings (
    id, brand_name, legal_name, address, phone, email, search_placeholder,
    logo_media_id, footer_logo_media_id
  )
  VALUES (
    TRUE, btrim(p_brand_name), btrim(p_legal_name), coalesce(p_address, ''),
    coalesce(p_phone, ''), coalesce(p_email, ''), coalesce(p_search_placeholder, ''),
    p_logo_media_id, p_footer_logo_media_id
  )
  ON CONFLICT (id) DO UPDATE
     SET brand_name           = EXCLUDED.brand_name,
         legal_name           = EXCLUDED.legal_name,
         address              = EXCLUDED.address,
         phone                = EXCLUDED.phone,
         email                = EXCLUDED.email,
         search_placeholder   = EXCLUDED.search_placeholder,
         logo_media_id        = EXCLUDED.logo_media_id,
         footer_logo_media_id = EXCLUDED.footer_logo_media_id
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ===========================================================================
-- seo_metadata
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.seo_get_by_page(p_page_slug TEXT)
RETURNS TABLE (
  id                BIGINT,
  page_slug         TEXT,
  meta_title        TEXT,
  meta_description  TEXT,
  meta_keywords     TEXT[],
  canonical_url     TEXT,
  og_title          TEXT,
  og_description    TEXT,
  og_image_url      TEXT,
  og_image_media_id BIGINT,
  robots            TEXT,
  updated_at        TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT s.id, p.slug, s.meta_title, s.meta_description, s.meta_keywords,
         s.canonical_url, s.og_title, s.og_description, m.url, s.og_image_media_id,
         s.robots, s.updated_at
    FROM cms.seo_metadata s
    JOIN cms.pages p ON p.id = s.page_id
    LEFT JOIN cms.media_assets m ON m.id = s.og_image_media_id
   WHERE p.slug = btrim(p_page_slug);
$$;

CREATE OR REPLACE FUNCTION cms.seo_upsert(
  p_page_slug         TEXT,
  p_meta_title        TEXT,
  p_meta_description  TEXT,
  p_meta_keywords     TEXT[],
  p_canonical_url     TEXT   DEFAULT NULL,
  p_og_title          TEXT   DEFAULT NULL,
  p_og_description    TEXT   DEFAULT NULL,
  p_og_image_media_id BIGINT DEFAULT NULL,
  p_robots            TEXT   DEFAULT 'index,follow'
)
RETURNS cms.seo_metadata
LANGUAGE plpgsql
AS $$
DECLARE
  v_page_id BIGINT;
  v_row     cms.seo_metadata;
BEGIN
  SELECT id INTO v_page_id FROM cms.pages WHERE slug = btrim(p_page_slug);

  IF v_page_id IS NULL THEN
    RAISE EXCEPTION 'Page % not found', p_page_slug USING ERRCODE = 'no_data_found';
  END IF;

  INSERT INTO cms.seo_metadata (
    page_id, meta_title, meta_description, meta_keywords, canonical_url,
    og_title, og_description, og_image_media_id, robots
  )
  VALUES (
    v_page_id, coalesce(p_meta_title, ''), coalesce(p_meta_description, ''),
    coalesce(p_meta_keywords, '{}'), p_canonical_url, p_og_title, p_og_description,
    p_og_image_media_id, coalesce(nullif(btrim(p_robots), ''), 'index,follow')
  )
  ON CONFLICT (page_id) DO UPDATE
     SET meta_title        = EXCLUDED.meta_title,
         meta_description  = EXCLUDED.meta_description,
         meta_keywords     = EXCLUDED.meta_keywords,
         canonical_url     = EXCLUDED.canonical_url,
         og_title          = EXCLUDED.og_title,
         og_description    = EXCLUDED.og_description,
         og_image_media_id = EXCLUDED.og_image_media_id,
         robots            = EXCLUDED.robots
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ===========================================================================
-- navigation
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.nav_menu_list()
RETURNS SETOF cms.navigation_menus
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.navigation_menus ORDER BY location, id;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_list(p_menu_key TEXT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS TABLE (
  id               BIGINT,
  menu_key         TEXT,
  parent_id        BIGINT,
  label            TEXT,
  href             TEXT,
  icon_media_id    BIGINT,
  icon_url         TEXT,
  opens_in_new_tab BOOLEAN,
  display_order    INTEGER,
  is_active        BOOLEAN,
  updated_at       TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT i.id, mn.menu_key, i.parent_id, i.label, i.href, i.icon_media_id, md.url,
         i.opens_in_new_tab, i.display_order, i.is_active, i.updated_at
    FROM cms.navigation_items i
    JOIN cms.navigation_menus mn ON mn.id = i.menu_id
    LEFT JOIN cms.media_assets md ON md.id = i.icon_media_id
   WHERE mn.menu_key = btrim(p_menu_key)
     AND (NOT p_only_active OR i.is_active)
   ORDER BY i.display_order, i.id;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_get(p_id BIGINT)
RETURNS cms.navigation_items
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.navigation_items WHERE id = p_id;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_create(
  p_menu_key         TEXT,
  p_label            TEXT,
  p_href             TEXT    DEFAULT '#',
  p_parent_id        BIGINT  DEFAULT NULL,
  p_icon_media_id    BIGINT  DEFAULT NULL,
  p_opens_in_new_tab BOOLEAN DEFAULT FALSE
)
RETURNS cms.navigation_items
LANGUAGE plpgsql
AS $$
DECLARE
  v_menu_id BIGINT;
  v_order   INTEGER;
  v_row     cms.navigation_items;
BEGIN
  SELECT id INTO v_menu_id FROM cms.navigation_menus WHERE menu_key = btrim(p_menu_key);

  IF v_menu_id IS NULL THEN
    RAISE EXCEPTION 'Menu % not found', p_menu_key USING ERRCODE = 'no_data_found';
  END IF;

  -- New items land at the end of their own level.
  SELECT coalesce(max(display_order), 0) + 1 INTO v_order
    FROM cms.navigation_items
   WHERE menu_id = v_menu_id
     AND parent_id IS NOT DISTINCT FROM p_parent_id;

  INSERT INTO cms.navigation_items (
    menu_id, parent_id, label, href, icon_media_id, opens_in_new_tab, display_order
  )
  VALUES (
    v_menu_id, p_parent_id, btrim(p_label),
    coalesce(nullif(btrim(p_href), ''), '#'), p_icon_media_id, p_opens_in_new_tab, v_order
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_update(
  p_id               BIGINT,
  p_label            TEXT,
  p_href             TEXT,
  p_icon_media_id    BIGINT  DEFAULT NULL,
  p_opens_in_new_tab BOOLEAN DEFAULT FALSE
)
RETURNS cms.navigation_items
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.navigation_items;
BEGIN
  UPDATE cms.navigation_items
     SET label            = btrim(p_label),
         href             = coalesce(nullif(btrim(p_href), ''), '#'),
         icon_media_id    = p_icon_media_id,
         opens_in_new_tab = p_opens_in_new_tab
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Navigation item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.navigation_items
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.navigation_items;
BEGIN
  UPDATE cms.navigation_items SET is_active = p_is_active WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Navigation item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  -- Children cascade by the foreign key; this is here so the caller gets a
  -- truthful "did anything happen" answer.
  DELETE FROM cms.navigation_items WHERE id = p_id;
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION cms.nav_item_reorder(p_menu_key TEXT, p_ids BIGINT[])
RETURNS SETOF cms.navigation_items
LANGUAGE plpgsql
AS $$
DECLARE
  v_menu_id BIGINT;
BEGIN
  SELECT id INTO v_menu_id FROM cms.navigation_menus WHERE menu_key = btrim(p_menu_key);

  IF v_menu_id IS NULL THEN
    RAISE EXCEPTION 'Menu % not found', p_menu_key USING ERRCODE = 'no_data_found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM unnest(p_ids) AS t(id)
     WHERE NOT EXISTS (
       SELECT 1 FROM cms.navigation_items i WHERE i.id = t.id AND i.menu_id = v_menu_id
     )
  ) THEN
    RAISE EXCEPTION 'Reorder list contains an item that is not in menu %', p_menu_key
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  UPDATE cms.navigation_items i
     SET display_order = t.position
    FROM (SELECT id, ordinality::INTEGER AS position
            FROM unnest(p_ids) WITH ORDINALITY AS u(id, ordinality)) AS t
   WHERE i.id = t.id;

  RETURN QUERY
    SELECT * FROM cms.navigation_items
     WHERE menu_id = v_menu_id
     ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- hero
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.hero_get(p_page_slug TEXT)
RETURNS TABLE (
  id                             BIGINT,
  section_id                     BIGINT,
  title_lead                     TEXT,
  subtext_line_1                 TEXT,
  subtext_line_2                 TEXT,
  watermark_left                 TEXT,
  watermark_right                TEXT,
  mockup_media_id                BIGINT,
  mockup_url                     TEXT,
  mockup_alt                     TEXT,
  form_name_label                TEXT,
  form_name_placeholder          TEXT,
  form_mobile_label              TEXT,
  form_mobile_placeholder        TEXT,
  form_mobile_help               TEXT,
  form_consent_label             TEXT,
  form_submit_label              TEXT,
  form_name_label_mobile         TEXT,
  form_name_placeholder_mobile   TEXT,
  form_mobile_label_mobile       TEXT,
  form_mobile_placeholder_mobile TEXT,
  updated_at                     TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT h.id, h.section_id, h.title_lead, h.subtext_line_1, h.subtext_line_2,
         h.watermark_left, h.watermark_right, h.mockup_media_id, m.url, m.alt_text,
         h.form_name_label, h.form_name_placeholder, h.form_mobile_label,
         h.form_mobile_placeholder, h.form_mobile_help, h.form_consent_label,
         h.form_submit_label, h.form_name_label_mobile, h.form_name_placeholder_mobile,
         h.form_mobile_label_mobile, h.form_mobile_placeholder_mobile, h.updated_at
    FROM cms.hero_sections h
    JOIN cms.page_sections s ON s.id = h.section_id
    JOIN cms.pages p ON p.id = s.page_id
    LEFT JOIN cms.media_assets m ON m.id = h.mockup_media_id
   WHERE p.slug = btrim(p_page_slug);
$$;

CREATE OR REPLACE FUNCTION cms.hero_update(
  p_id                             BIGINT,
  p_title_lead                     TEXT,
  p_subtext_line_1                 TEXT,
  p_subtext_line_2                 TEXT,
  p_watermark_left                 TEXT,
  p_watermark_right                TEXT,
  p_mockup_media_id                BIGINT,
  p_form_name_label                TEXT,
  p_form_name_placeholder          TEXT,
  p_form_mobile_label              TEXT,
  p_form_mobile_placeholder        TEXT,
  p_form_mobile_help               TEXT,
  p_form_consent_label             TEXT,
  p_form_submit_label              TEXT,
  p_form_name_label_mobile         TEXT,
  p_form_name_placeholder_mobile   TEXT,
  p_form_mobile_label_mobile       TEXT,
  p_form_mobile_placeholder_mobile TEXT
)
RETURNS cms.hero_sections
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.hero_sections;
BEGIN
  UPDATE cms.hero_sections
     SET title_lead                     = coalesce(p_title_lead, ''),
         subtext_line_1                 = coalesce(p_subtext_line_1, ''),
         subtext_line_2                 = coalesce(p_subtext_line_2, ''),
         watermark_left                 = coalesce(p_watermark_left, ''),
         watermark_right                = coalesce(p_watermark_right, ''),
         mockup_media_id                = p_mockup_media_id,
         form_name_label                = coalesce(p_form_name_label, ''),
         form_name_placeholder          = coalesce(p_form_name_placeholder, ''),
         form_mobile_label              = coalesce(p_form_mobile_label, ''),
         form_mobile_placeholder        = coalesce(p_form_mobile_placeholder, ''),
         form_mobile_help               = coalesce(p_form_mobile_help, ''),
         form_consent_label             = coalesce(p_form_consent_label, ''),
         form_submit_label              = coalesce(p_form_submit_label, ''),
         form_name_label_mobile         = coalesce(p_form_name_label_mobile, ''),
         form_name_placeholder_mobile   = coalesce(p_form_name_placeholder_mobile, ''),
         form_mobile_label_mobile       = coalesce(p_form_mobile_label_mobile, ''),
         form_mobile_placeholder_mobile = coalesce(p_form_mobile_placeholder_mobile, '')
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hero % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

-- hero rotating lines --------------------------------------------------------

CREATE OR REPLACE FUNCTION cms.hero_line_list(p_hero_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.hero_rotating_lines
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.hero_rotating_lines
   WHERE hero_id = p_hero_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.hero_line_create(
  p_hero_id BIGINT,
  p_line_1  TEXT,
  p_line_2  TEXT DEFAULT ''
)
RETURNS cms.hero_rotating_lines
LANGUAGE plpgsql
AS $$
DECLARE
  v_order INTEGER;
  v_row   cms.hero_rotating_lines;
BEGIN
  SELECT coalesce(max(display_order), 0) + 1 INTO v_order
    FROM cms.hero_rotating_lines WHERE hero_id = p_hero_id;

  INSERT INTO cms.hero_rotating_lines (hero_id, line_1, line_2, display_order)
  VALUES (p_hero_id, btrim(p_line_1), coalesce(p_line_2, ''), v_order)
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_line_update(p_id BIGINT, p_line_1 TEXT, p_line_2 TEXT)
RETURNS cms.hero_rotating_lines
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.hero_rotating_lines;
BEGIN
  UPDATE cms.hero_rotating_lines
     SET line_1 = btrim(p_line_1), line_2 = coalesce(p_line_2, '')
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hero line % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_line_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.hero_rotating_lines
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.hero_rotating_lines;
BEGIN
  UPDATE cms.hero_rotating_lines SET is_active = p_is_active WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hero line % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_line_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM cms.hero_rotating_lines WHERE id = p_id;
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_line_reorder(p_hero_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.hero_rotating_lines
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM unnest(p_ids) AS t(id)
     WHERE NOT EXISTS (
       SELECT 1 FROM cms.hero_rotating_lines l WHERE l.id = t.id AND l.hero_id = p_hero_id
     )
  ) THEN
    RAISE EXCEPTION 'Reorder list contains a line that is not on hero %', p_hero_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  UPDATE cms.hero_rotating_lines l
     SET display_order = t.position
    FROM (SELECT id, ordinality::INTEGER AS position
            FROM unnest(p_ids) WITH ORDINALITY AS u(id, ordinality)) AS t
   WHERE l.id = t.id;

  RETURN QUERY
    SELECT * FROM cms.hero_rotating_lines WHERE hero_id = p_hero_id ORDER BY display_order, id;
END;
$$;

-- hero KPIs ------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cms.hero_kpi_list(p_hero_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS TABLE (
  id            BIGINT,
  kpi_key       TEXT,
  kind          TEXT,
  value         TEXT,
  label         TEXT,
  icon_media_id BIGINT,
  icon_url      TEXT,
  display_order INTEGER,
  is_active     BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
  SELECT k.id, k.kpi_key, k.kind, k.value, k.label, k.icon_media_id, m.url,
         k.display_order, k.is_active
    FROM cms.hero_kpis k
    LEFT JOIN cms.media_assets m ON m.id = k.icon_media_id
   WHERE k.hero_id = p_hero_id AND (NOT p_only_active OR k.is_active)
   ORDER BY k.display_order, k.id;
$$;

CREATE OR REPLACE FUNCTION cms.hero_kpi_update(
  p_id            BIGINT,
  p_value         TEXT,
  p_label         TEXT,
  p_icon_media_id BIGINT DEFAULT NULL
)
RETURNS cms.hero_kpis
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.hero_kpis;
BEGIN
  UPDATE cms.hero_kpis
     SET value         = nullif(btrim(coalesce(p_value, '')), ''),
         label         = btrim(p_label),
         icon_media_id = p_icon_media_id
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hero KPI % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_kpi_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.hero_kpis
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.hero_kpis;
BEGIN
  UPDATE cms.hero_kpis SET is_active = p_is_active WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hero KPI % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.hero_kpi_reorder(p_hero_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.hero_kpis
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM unnest(p_ids) AS t(id)
     WHERE NOT EXISTS (
       SELECT 1 FROM cms.hero_kpis k WHERE k.id = t.id AND k.hero_id = p_hero_id
     )
  ) THEN
    RAISE EXCEPTION 'Reorder list contains a KPI that is not on hero %', p_hero_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  UPDATE cms.hero_kpis k
     SET display_order = t.position
    FROM (SELECT id, ordinality::INTEGER AS position
            FROM unnest(p_ids) WITH ORDINALITY AS u(id, ordinality)) AS t
   WHERE k.id = t.id;

  RETURN QUERY
    SELECT * FROM cms.hero_kpis WHERE hero_id = p_hero_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- public read — the whole page in one call
--
-- The public website is read-heavy and latency-sensitive, so it does not make
-- one request per fold. This returns the published shape as a single JSONB
-- document, with inactive rows already filtered out, so the API route is a
-- pass-through and the site never sees CMS bookkeeping columns.
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.public_page_payload(p_page_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_page_id BIGINT;
  v_hero_id BIGINT;
  v_result  JSONB;
BEGIN
  SELECT id INTO v_page_id FROM cms.pages WHERE slug = btrim(p_page_slug) AND is_active;

  IF v_page_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT h.id INTO v_hero_id
    FROM cms.hero_sections h
    JOIN cms.page_sections s ON s.id = h.section_id
   WHERE s.page_id = v_page_id;

  SELECT jsonb_build_object(
    'slug', p.slug,
    'name', p.name,
    'route', p.route,

    'settings', (
      SELECT jsonb_build_object(
        'brandName', st.brand_name,
        'legalName', st.legal_name,
        'address', st.address,
        'phone', st.phone,
        'email', st.email,
        'searchPlaceholder', st.search_placeholder,
        'logoUrl', lm.url,
        'logoAlt', lm.alt_text,
        'footerLogoUrl', fm.url,
        'footerLogoAlt', fm.alt_text
      )
        FROM cms.site_settings st
        LEFT JOIN cms.media_assets lm ON lm.id = st.logo_media_id
        LEFT JOIN cms.media_assets fm ON fm.id = st.footer_logo_media_id
       WHERE st.id
    ),

    'seo', (
      SELECT jsonb_build_object(
        'title', se.meta_title,
        'description', se.meta_description,
        'keywords', to_jsonb(se.meta_keywords),
        'canonicalUrl', se.canonical_url,
        'ogTitle', coalesce(se.og_title, se.meta_title),
        'ogDescription', coalesce(se.og_description, se.meta_description),
        'ogImageUrl', om.url,
        'robots', se.robots
      )
        FROM cms.seo_metadata se
        LEFT JOIN cms.media_assets om ON om.id = se.og_image_media_id
       WHERE se.page_id = v_page_id
    ),

    'sections', coalesce((
      SELECT jsonb_agg(jsonb_build_object('key', s.section_key, 'name', s.name)
                       ORDER BY s.display_order, s.id)
        FROM cms.page_sections s
       WHERE s.page_id = v_page_id AND s.is_active
    ), '[]'::jsonb),

    'navigation', coalesce((
      SELECT jsonb_object_agg(mn.menu_key, items)
        FROM (
          SELECT i.menu_id,
                 jsonb_agg(jsonb_build_object(
                   'id', i.id,
                   'label', i.label,
                   'href', i.href,
                   'iconUrl', md.url,
                   'newTab', i.opens_in_new_tab
                 ) ORDER BY i.display_order, i.id) AS items
            FROM cms.navigation_items i
            LEFT JOIN cms.media_assets md ON md.id = i.icon_media_id
           WHERE i.is_active AND i.parent_id IS NULL
           GROUP BY i.menu_id
        ) grouped
        JOIN cms.navigation_menus mn ON mn.id = grouped.menu_id
       WHERE mn.is_active
    ), '{}'::jsonb),

    'hero', (
      SELECT jsonb_build_object(
        'titleLead', h.title_lead,
        'subtext', jsonb_build_array(h.subtext_line_1, h.subtext_line_2),
        'watermarkLeft', h.watermark_left,
        'watermarkRight', h.watermark_right,
        'mockupUrl', hm.url,
        'mockupAlt', hm.alt_text,
        'rotatingLines', coalesce((
          SELECT jsonb_agg(jsonb_build_array(l.line_1, l.line_2) ORDER BY l.display_order, l.id)
            FROM cms.hero_rotating_lines l
           WHERE l.hero_id = h.id AND l.is_active
        ), '[]'::jsonb),
        'kpis', coalesce((
          SELECT jsonb_agg(jsonb_build_object(
                   'key', k.kpi_key,
                   'kind', k.kind,
                   'value', k.value,
                   'label', k.label,
                   'iconUrl', km.url
                 ) ORDER BY k.display_order, k.id)
            FROM cms.hero_kpis k
            LEFT JOIN cms.media_assets km ON km.id = k.icon_media_id
           WHERE k.hero_id = h.id AND k.is_active
        ), '[]'::jsonb),
        'form', jsonb_build_object(
          'nameLabel', h.form_name_label,
          'namePlaceholder', h.form_name_placeholder,
          'mobileLabel', h.form_mobile_label,
          'mobilePlaceholder', h.form_mobile_placeholder,
          'mobileHelp', h.form_mobile_help,
          'consent', h.form_consent_label,
          'submit', h.form_submit_label
        ),
        'formMobile', jsonb_build_object(
          'nameLabel', h.form_name_label_mobile,
          'namePlaceholder', h.form_name_placeholder_mobile,
          'mobileLabel', h.form_mobile_label_mobile,
          'mobilePlaceholder', h.form_mobile_placeholder_mobile
        )
      )
        FROM cms.hero_sections h
        LEFT JOIN cms.media_assets hm ON hm.id = h.mockup_media_id
       WHERE h.id = v_hero_id
    )
  )
  INTO v_result
  FROM cms.pages p
  WHERE p.id = v_page_id;

  RETURN v_result;
END;
$$;
