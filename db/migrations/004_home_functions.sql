-- ============================================================================
-- 004_home_functions.sql — shared helpers, and CRUD for the first half of the
-- home-page folds. 005 continues with the rest; 006 rebuilds the public
-- payload.
--
-- Every content entity exposes the same seven operations, as required:
--
--   <entity>_create      <entity>_get      <entity>_list
--   <entity>_update      <entity>_delete   <entity>_set_active
--   <entity>_reorder
--
-- Singletons (section_blocks, sticky_nudge) expose _get and _update only;
-- there is nothing to create, list, order or switch off independently of the
-- section that owns them.
--
-- ── On the two helpers below ────────────────────────────────────────────────
--
-- Twenty-three entities reorder identically: check the incoming id list is
-- exactly the parent's current set, then renumber by array position. Written
-- out per entity that is twenty-three copies of the same twenty-five lines,
-- and twenty-three places for one of them to drift.
--
-- `cms.reorder_rows` is therefore the single implementation, and each entity
-- keeps its own thin `_reorder` wrapper so the required per-entity procedure
-- still exists and still returns that entity's rows, typed.
--
-- The helper builds SQL text with format(), which is worth being explicit
-- about: the table and column names it interpolates come only from the
-- wrapper functions in this file — never from an argument the application
-- passes through. p_parent_col is pattern-checked regardless, and %I quotes
-- both. The id array is bound, not interpolated.
-- ============================================================================

SET search_path = cms, public;

-- ---------------------------------------------------------------------------
-- section_id_for — resolve a page slug + section key to a section id.
--
-- The dashboard and the API address sections by their stable keys
-- ('home', 'ipos') rather than by numeric id, so a seeded environment and a
-- freshly migrated one behave the same.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.section_id_for(p_page_slug TEXT, p_section_key TEXT)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
  SELECT s.id
    FROM cms.page_sections s
    JOIN cms.pages p ON p.id = s.page_id
   WHERE p.slug = btrim(p_page_slug)
     AND s.section_key = btrim(p_section_key);
$$;

-- ---------------------------------------------------------------------------
-- reorder_rows — renumber display_order from an ordered id array.
--
-- Rejects a list that is not exactly the parent's current id set. That matters
-- more than it looks: a dashboard holding a stale list would otherwise silently
-- renumber some rows and leave others behind, and the mismatch would only show
-- up on the live page.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.reorder_rows(
  p_table      REGCLASS,
  p_parent_col TEXT,
  p_parent_id  BIGINT,
  p_ids        BIGINT[]
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_expected BIGINT;
  v_given    BIGINT;
BEGIN
  IF p_parent_col !~ '^[a-z_]+$' THEN
    RAISE EXCEPTION 'Refusing an unexpected parent column name: %', p_parent_col;
  END IF;

  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN;  -- nothing to order
  END IF;

  IF EXISTS (SELECT 1 FROM unnest(p_ids) AS t(id) GROUP BY t.id HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'Reorder list contains the same id twice'
      USING ERRCODE = 'unique_violation';
  END IF;

  EXECUTE format(
    'SELECT count(*) FROM %s WHERE %I = $1', p_table, p_parent_col
  ) INTO v_expected USING p_parent_id;

  EXECUTE format(
    'SELECT count(*) FROM %s WHERE %I = $1 AND id = ANY($2)', p_table, p_parent_col
  ) INTO v_given USING p_parent_id, p_ids;

  IF v_given <> array_length(p_ids, 1) THEN
    RAISE EXCEPTION 'Reorder list contains a row that does not belong to parent %', p_parent_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  IF v_expected <> array_length(p_ids, 1) THEN
    RAISE EXCEPTION 'Reorder list is incomplete: parent % has % rows, % were given',
      p_parent_id, v_expected, array_length(p_ids, 1)
      USING ERRCODE = 'cardinality_violation';
  END IF;

  EXECUTE format(
    'UPDATE %s AS r SET display_order = t.position
       FROM (SELECT id, ordinality::INTEGER AS position
               FROM unnest($1) WITH ORDINALITY AS u(id, ordinality)) AS t
      WHERE r.id = t.id', p_table
  ) USING p_ids;
END;
$$;

-- The same, for the three site-level tables that have no parent column.
CREATE OR REPLACE FUNCTION cms.reorder_rows_global(p_table REGCLASS, p_ids BIGINT[])
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_expected BIGINT;
  v_given    BIGINT;
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  EXECUTE format('SELECT count(*) FROM %s', p_table) INTO v_expected;
  EXECUTE format('SELECT count(*) FROM %s WHERE id = ANY($1)', p_table)
    INTO v_given USING p_ids;

  IF v_given <> array_length(p_ids, 1) OR v_expected <> array_length(p_ids, 1) THEN
    RAISE EXCEPTION 'Reorder list does not match the table contents'
      USING ERRCODE = 'cardinality_violation';
  END IF;

  EXECUTE format(
    'UPDATE %s AS r SET display_order = t.position
       FROM (SELECT id, ordinality::INTEGER AS position
               FROM unnest($1) WITH ORDINALITY AS u(id, ordinality)) AS t
      WHERE r.id = t.id', p_table
  ) USING p_ids;
END;
$$;

-- ===========================================================================
-- section_blocks — the shared shell. Singleton per section, so _get and
-- _update only, and _update upserts: a fold whose row does not exist yet must
-- still be editable without a separate "create" step in the dashboard.
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.section_block_get(p_page_slug TEXT, p_section_key TEXT)
RETURNS cms.section_blocks
LANGUAGE sql
STABLE
AS $$
  SELECT b.*
    FROM cms.section_blocks b
   WHERE b.section_id = cms.section_id_for(p_page_slug, p_section_key);
$$;

CREATE OR REPLACE FUNCTION cms.section_block_update(
  p_page_slug                  TEXT,
  p_section_key                TEXT,
  p_eyebrow                    TEXT    DEFAULT '',
  p_title                      TEXT    DEFAULT '',
  p_title_lines                TEXT[]  DEFAULT '{}',
  p_subtitle                   TEXT    DEFAULT '',
  p_subtitle_mobile            TEXT    DEFAULT '',
  p_description                TEXT    DEFAULT '',
  p_title_break_after          INTEGER DEFAULT NULL,
  p_subtitle_break_after       INTEGER DEFAULT NULL,
  p_align                      TEXT    DEFAULT 'start',
  p_tone                       TEXT    DEFAULT 'light',
  p_cta_label                  TEXT    DEFAULT '',
  p_cta_label_mobile           TEXT    DEFAULT '',
  p_cta_href                   TEXT    DEFAULT NULL,
  p_cta_visible                BOOLEAN DEFAULT TRUE,
  p_secondary_cta_label        TEXT    DEFAULT '',
  p_secondary_cta_href         TEXT    DEFAULT NULL,
  p_secondary_cta_visible      BOOLEAN DEFAULT FALSE,
  p_arrow_href                 TEXT    DEFAULT NULL,
  p_arrow_label                TEXT    DEFAULT '',
  p_image_media_id             BIGINT  DEFAULT NULL,
  p_image_mobile_media_id      BIGINT  DEFAULT NULL,
  p_background_media_id        BIGINT  DEFAULT NULL,
  p_background_mobile_media_id BIGINT  DEFAULT NULL,
  p_background_color           TEXT    DEFAULT ''
)
RETURNS cms.section_blocks
LANGUAGE plpgsql
AS $$
DECLARE
  v_section_id BIGINT;
  v_row        cms.section_blocks;
BEGIN
  v_section_id := cms.section_id_for(p_page_slug, p_section_key);

  IF v_section_id IS NULL THEN
    RAISE EXCEPTION 'Section %/% not found', p_page_slug, p_section_key
      USING ERRCODE = 'no_data_found';
  END IF;

  INSERT INTO cms.section_blocks (
    section_id, eyebrow, title, title_lines, subtitle, subtitle_mobile, description,
    title_break_after, subtitle_break_after, align, tone,
    cta_label, cta_label_mobile, cta_href, cta_visible,
    secondary_cta_label, secondary_cta_href, secondary_cta_visible,
    arrow_href, arrow_label,
    image_media_id, image_mobile_media_id,
    background_media_id, background_mobile_media_id, background_color
  )
  VALUES (
    v_section_id, coalesce(p_eyebrow, ''), coalesce(p_title, ''),
    coalesce(p_title_lines, '{}'), coalesce(p_subtitle, ''),
    coalesce(p_subtitle_mobile, ''), coalesce(p_description, ''),
    p_title_break_after, p_subtitle_break_after,
    coalesce(nullif(btrim(p_align), ''), 'start'),
    coalesce(nullif(btrim(p_tone), ''), 'light'),
    coalesce(p_cta_label, ''), coalesce(p_cta_label_mobile, ''),
    nullif(btrim(coalesce(p_cta_href, '')), ''), coalesce(p_cta_visible, TRUE),
    coalesce(p_secondary_cta_label, ''),
    nullif(btrim(coalesce(p_secondary_cta_href, '')), ''),
    coalesce(p_secondary_cta_visible, FALSE),
    nullif(btrim(coalesce(p_arrow_href, '')), ''), coalesce(p_arrow_label, ''),
    p_image_media_id, p_image_mobile_media_id,
    p_background_media_id, p_background_mobile_media_id,
    coalesce(btrim(p_background_color), '')
  )
  ON CONFLICT (section_id) DO UPDATE SET
    eyebrow                    = EXCLUDED.eyebrow,
    title                      = EXCLUDED.title,
    title_lines                = EXCLUDED.title_lines,
    subtitle                   = EXCLUDED.subtitle,
    subtitle_mobile            = EXCLUDED.subtitle_mobile,
    description                = EXCLUDED.description,
    title_break_after          = EXCLUDED.title_break_after,
    subtitle_break_after       = EXCLUDED.subtitle_break_after,
    align                      = EXCLUDED.align,
    tone                       = EXCLUDED.tone,
    cta_label                  = EXCLUDED.cta_label,
    cta_label_mobile           = EXCLUDED.cta_label_mobile,
    cta_href                   = EXCLUDED.cta_href,
    cta_visible                = EXCLUDED.cta_visible,
    secondary_cta_label        = EXCLUDED.secondary_cta_label,
    secondary_cta_href         = EXCLUDED.secondary_cta_href,
    secondary_cta_visible      = EXCLUDED.secondary_cta_visible,
    arrow_href                 = EXCLUDED.arrow_href,
    arrow_label                = EXCLUDED.arrow_label,
    image_media_id             = EXCLUDED.image_media_id,
    image_mobile_media_id      = EXCLUDED.image_mobile_media_id,
    background_media_id        = EXCLUDED.background_media_id,
    background_mobile_media_id = EXCLUDED.background_mobile_media_id,
    background_color           = EXCLUDED.background_color
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ===========================================================================
-- section_tabs
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.tab_create(
  p_section_id             BIGINT,
  p_tab_key                TEXT,
  p_label                  TEXT,
  p_transition_duration_ms INTEGER DEFAULT NULL,
  p_transition_easing      TEXT    DEFAULT NULL,
  p_display_order          INTEGER DEFAULT NULL
)
RETURNS cms.section_tabs
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.section_tabs;
BEGIN
  INSERT INTO cms.section_tabs (
    section_id, tab_key, label, transition_duration_ms, transition_easing, display_order
  )
  VALUES (
    p_section_id, btrim(p_tab_key), btrim(p_label),
    p_transition_duration_ms, nullif(btrim(coalesce(p_transition_easing, '')), ''),
    -- Appended to the end unless a position is given, so a newly added tab
    -- never displaces the existing run.
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.section_tabs WHERE section_id = p_section_id))
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.tab_get(p_id BIGINT)
RETURNS cms.section_tabs
LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.section_tabs WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.tab_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.section_tabs
LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.section_tabs
   WHERE section_id = p_section_id
     AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.tab_update(
  p_id                     BIGINT,
  p_label                  TEXT,
  p_transition_duration_ms INTEGER DEFAULT NULL,
  p_transition_easing      TEXT    DEFAULT NULL
)
RETURNS cms.section_tabs
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.section_tabs;
BEGIN
  UPDATE cms.section_tabs
     SET label                  = btrim(p_label),
         transition_duration_ms = p_transition_duration_ms,
         transition_easing      = nullif(btrim(coalesce(p_transition_easing, '')), '')
   WHERE id = p_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tab % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.tab_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM cms.section_tabs WHERE id = p_id;
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION cms.tab_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.section_tabs
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.section_tabs;
BEGIN
  UPDATE cms.section_tabs SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tab % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.tab_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.section_tabs
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.section_tabs', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.section_tabs
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- stat_items
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.stat_create(
  p_section_id    BIGINT,
  p_value         TEXT,
  p_label         TEXT    DEFAULT '',
  p_label_lines   TEXT[]  DEFAULT '{}',
  p_description   TEXT    DEFAULT '',
  p_icon_media_id BIGINT  DEFAULT NULL,
  p_owner_key     TEXT    DEFAULT 'default',
  p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.stat_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stat_items;
BEGIN
  INSERT INTO cms.stat_items (
    section_id, owner_key, value, label, label_lines, description, icon_media_id, display_order
  )
  VALUES (
    p_section_id, coalesce(nullif(btrim(p_owner_key), ''), 'default'),
    btrim(p_value), coalesce(p_label, ''), coalesce(p_label_lines, '{}'),
    coalesce(p_description, ''), p_icon_media_id,
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.stat_items WHERE section_id = p_section_id))
  )
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stat_get(p_id BIGINT)
RETURNS cms.stat_items
LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.stat_items WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.stat_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.stat_items
LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.stat_items
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY owner_key, display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.stat_update(
  p_id            BIGINT,
  p_value         TEXT,
  p_label         TEXT    DEFAULT '',
  p_label_lines   TEXT[]  DEFAULT '{}',
  p_description   TEXT    DEFAULT '',
  p_icon_media_id BIGINT  DEFAULT NULL
)
RETURNS cms.stat_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stat_items;
BEGIN
  UPDATE cms.stat_items
     SET value = btrim(p_value), label = coalesce(p_label, ''),
         label_lines = coalesce(p_label_lines, '{}'),
         description = coalesce(p_description, ''), icon_media_id = p_icon_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stat % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stat_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.stat_items WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.stat_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.stat_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stat_items;
BEGIN
  UPDATE cms.stat_items SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stat % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stat_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.stat_items
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.stat_items', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.stat_items
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- ticker_items — Market Pulse
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.ticker_create(
  p_section_id    BIGINT,
  p_name          TEXT,
  p_price         TEXT    DEFAULT '',
  p_change        TEXT    DEFAULT '',
  p_direction     TEXT    DEFAULT 'up',
  p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.ticker_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.ticker_items;
BEGIN
  INSERT INTO cms.ticker_items (section_id, name, price, change, direction, display_order)
  VALUES (
    p_section_id, btrim(p_name), coalesce(p_price, ''), coalesce(p_change, ''),
    coalesce(nullif(btrim(p_direction), ''), 'up'),
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.ticker_items WHERE section_id = p_section_id))
  )
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.ticker_get(p_id BIGINT)
RETURNS cms.ticker_items
LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.ticker_items WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.ticker_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.ticker_items
LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.ticker_items
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.ticker_update(
  p_id        BIGINT,
  p_name      TEXT,
  p_price     TEXT DEFAULT '',
  p_change    TEXT DEFAULT '',
  p_direction TEXT DEFAULT 'up'
)
RETURNS cms.ticker_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.ticker_items;
BEGIN
  UPDATE cms.ticker_items
     SET name = btrim(p_name), price = coalesce(p_price, ''),
         change = coalesce(p_change, ''),
         direction = coalesce(nullif(btrim(p_direction), ''), 'up')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticker item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.ticker_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.ticker_items WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.ticker_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.ticker_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.ticker_items;
BEGIN
  UPDATE cms.ticker_items SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticker item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.ticker_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.ticker_items
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.ticker_items', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.ticker_items
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- bento_cards — Explore our world
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.bento_card_create(
  p_section_id             BIGINT,
  p_card_key               TEXT,
  p_title_lines            TEXT[]  DEFAULT '{}',
  p_href                   TEXT    DEFAULT NULL,
  p_leverage_upto          TEXT    DEFAULT NULL,
  p_leverage_value         TEXT    DEFAULT NULL,
  p_leverage_label         TEXT    DEFAULT NULL,
  p_art_media_id           BIGINT  DEFAULT NULL,
  p_art_secondary_media_id BIGINT  DEFAULT NULL,
  p_display_order          INTEGER DEFAULT NULL
)
RETURNS cms.bento_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.bento_cards;
BEGIN
  INSERT INTO cms.bento_cards (
    section_id, card_key, title_lines, href,
    leverage_upto, leverage_value, leverage_label,
    art_media_id, art_secondary_media_id, display_order
  )
  VALUES (
    p_section_id, btrim(p_card_key), coalesce(p_title_lines, '{}'),
    nullif(btrim(coalesce(p_href, '')), ''),
    nullif(btrim(coalesce(p_leverage_upto, '')), ''),
    nullif(btrim(coalesce(p_leverage_value, '')), ''),
    nullif(btrim(coalesce(p_leverage_label, '')), ''),
    p_art_media_id, p_art_secondary_media_id,
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.bento_cards WHERE section_id = p_section_id))
  )
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.bento_card_get(p_id BIGINT)
RETURNS cms.bento_cards
LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.bento_cards WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.bento_card_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.bento_cards
LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.bento_cards
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.bento_card_update(
  p_id                     BIGINT,
  p_title_lines            TEXT[]  DEFAULT '{}',
  p_href                   TEXT    DEFAULT NULL,
  p_leverage_upto          TEXT    DEFAULT NULL,
  p_leverage_value         TEXT    DEFAULT NULL,
  p_leverage_label         TEXT    DEFAULT NULL,
  p_art_media_id           BIGINT  DEFAULT NULL,
  p_art_secondary_media_id BIGINT  DEFAULT NULL
)
RETURNS cms.bento_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.bento_cards;
BEGIN
  UPDATE cms.bento_cards
     SET title_lines            = coalesce(p_title_lines, '{}'),
         href                   = nullif(btrim(coalesce(p_href, '')), ''),
         leverage_upto          = nullif(btrim(coalesce(p_leverage_upto, '')), ''),
         leverage_value         = nullif(btrim(coalesce(p_leverage_value, '')), ''),
         leverage_label         = nullif(btrim(coalesce(p_leverage_label, '')), ''),
         art_media_id           = p_art_media_id,
         art_secondary_media_id = p_art_secondary_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bento card % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.bento_card_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.bento_cards WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.bento_card_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.bento_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.bento_cards;
BEGIN
  UPDATE cms.bento_cards SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bento card % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.bento_card_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.bento_cards
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.bento_cards', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.bento_cards
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- ipo_items — parented by tab
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.ipo_create(
  p_tab_id              BIGINT,
  p_name                TEXT,
  p_status              TEXT    DEFAULT '',
  p_date_range          TEXT    DEFAULT '',
  p_price_band          TEXT    DEFAULT '',
  p_issue_size          TEXT    DEFAULT '',
  p_min_investment      TEXT    DEFAULT '',
  p_min_investment_unit TEXT    DEFAULT '',
  p_listing_note        TEXT    DEFAULT '',
  p_listing_date        TEXT    DEFAULT '',
  p_closing_note        TEXT    DEFAULT '',
  p_closing_date        TEXT    DEFAULT '',
  p_apply_label         TEXT    DEFAULT 'Apply',
  p_know_more_label     TEXT    DEFAULT 'Know More',
  p_apply_href          TEXT    DEFAULT NULL,
  p_know_more_href      TEXT    DEFAULT NULL,
  p_display_order       INTEGER DEFAULT NULL
)
RETURNS cms.ipo_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.ipo_items;
BEGIN
  INSERT INTO cms.ipo_items (
    tab_id, name, status, date_range, price_band, issue_size,
    min_investment, min_investment_unit, listing_note, listing_date,
    closing_note, closing_date, apply_label, know_more_label,
    apply_href, know_more_href, display_order
  )
  VALUES (
    p_tab_id, btrim(p_name), coalesce(p_status, ''), coalesce(p_date_range, ''),
    coalesce(p_price_band, ''), coalesce(p_issue_size, ''),
    coalesce(p_min_investment, ''), coalesce(p_min_investment_unit, ''),
    coalesce(p_listing_note, ''), coalesce(p_listing_date, ''),
    coalesce(p_closing_note, ''), coalesce(p_closing_date, ''),
    coalesce(nullif(btrim(p_apply_label), ''), 'Apply'),
    coalesce(nullif(btrim(p_know_more_label), ''), 'Know More'),
    nullif(btrim(coalesce(p_apply_href, '')), ''),
    nullif(btrim(coalesce(p_know_more_href, '')), ''),
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.ipo_items WHERE tab_id = p_tab_id))
  )
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.ipo_get(p_id BIGINT)
RETURNS cms.ipo_items
LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.ipo_items WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.ipo_list(p_tab_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.ipo_items
LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.ipo_items
   WHERE tab_id = p_tab_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.ipo_update(
  p_id                  BIGINT,
  p_name                TEXT,
  p_status              TEXT DEFAULT '',
  p_date_range          TEXT DEFAULT '',
  p_price_band          TEXT DEFAULT '',
  p_issue_size          TEXT DEFAULT '',
  p_min_investment      TEXT DEFAULT '',
  p_min_investment_unit TEXT DEFAULT '',
  p_listing_note        TEXT DEFAULT '',
  p_listing_date        TEXT DEFAULT '',
  p_closing_note        TEXT DEFAULT '',
  p_closing_date        TEXT DEFAULT '',
  p_apply_label         TEXT DEFAULT 'Apply',
  p_know_more_label     TEXT DEFAULT 'Know More',
  p_apply_href          TEXT DEFAULT NULL,
  p_know_more_href      TEXT DEFAULT NULL
)
RETURNS cms.ipo_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.ipo_items;
BEGIN
  UPDATE cms.ipo_items
     SET name = btrim(p_name), status = coalesce(p_status, ''),
         date_range = coalesce(p_date_range, ''), price_band = coalesce(p_price_band, ''),
         issue_size = coalesce(p_issue_size, ''),
         min_investment = coalesce(p_min_investment, ''),
         min_investment_unit = coalesce(p_min_investment_unit, ''),
         listing_note = coalesce(p_listing_note, ''),
         listing_date = coalesce(p_listing_date, ''),
         closing_note = coalesce(p_closing_note, ''),
         closing_date = coalesce(p_closing_date, ''),
         apply_label = coalesce(nullif(btrim(p_apply_label), ''), 'Apply'),
         know_more_label = coalesce(nullif(btrim(p_know_more_label), ''), 'Know More'),
         apply_href = nullif(btrim(coalesce(p_apply_href, '')), ''),
         know_more_href = nullif(btrim(coalesce(p_know_more_href, '')), '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'IPO % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.ipo_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.ipo_items WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.ipo_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.ipo_items
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.ipo_items;
BEGIN
  UPDATE cms.ipo_items SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'IPO % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.ipo_reorder(p_tab_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.ipo_items
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.ipo_items', 'tab_id', p_tab_id, p_ids);
  RETURN QUERY SELECT * FROM cms.ipo_items WHERE tab_id = p_tab_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- offering_cards — Fund It, Protect It. Parented by tab.
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.offering_create(
  p_tab_id              BIGINT,
  p_slug                TEXT,
  p_title               TEXT,
  p_lede                TEXT    DEFAULT '',
  p_highlight_lead      TEXT    DEFAULT '',
  p_highlight           TEXT    DEFAULT '',
  p_cta_label           TEXT    DEFAULT '',
  p_cta_label_mobile    TEXT    DEFAULT '',
  p_cta_href            TEXT    DEFAULT NULL,
  p_mobile_order        INTEGER DEFAULT 0,
  p_art_media_id        BIGINT  DEFAULT NULL,
  p_art_mobile_media_id BIGINT  DEFAULT NULL,
  p_display_order       INTEGER DEFAULT NULL
)
RETURNS cms.offering_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.offering_cards;
BEGIN
  INSERT INTO cms.offering_cards (
    tab_id, slug, title, lede, highlight_lead, highlight,
    cta_label, cta_label_mobile, cta_href, mobile_order,
    art_media_id, art_mobile_media_id, display_order
  )
  VALUES (
    p_tab_id, btrim(p_slug), btrim(p_title), coalesce(p_lede, ''),
    coalesce(p_highlight_lead, ''), coalesce(p_highlight, ''),
    coalesce(p_cta_label, ''), coalesce(p_cta_label_mobile, ''),
    nullif(btrim(coalesce(p_cta_href, '')), ''), coalesce(p_mobile_order, 0),
    p_art_media_id, p_art_mobile_media_id,
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.offering_cards WHERE tab_id = p_tab_id))
  )
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.offering_get(p_id BIGINT)
RETURNS cms.offering_cards
LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.offering_cards WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.offering_list(p_tab_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.offering_cards
LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.offering_cards
   WHERE tab_id = p_tab_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.offering_update(
  p_id                  BIGINT,
  p_title               TEXT,
  p_lede                TEXT    DEFAULT '',
  p_highlight_lead      TEXT    DEFAULT '',
  p_highlight           TEXT    DEFAULT '',
  p_cta_label           TEXT    DEFAULT '',
  p_cta_label_mobile    TEXT    DEFAULT '',
  p_cta_href            TEXT    DEFAULT NULL,
  p_mobile_order        INTEGER DEFAULT 0,
  p_art_media_id        BIGINT  DEFAULT NULL,
  p_art_mobile_media_id BIGINT  DEFAULT NULL
)
RETURNS cms.offering_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.offering_cards;
BEGIN
  UPDATE cms.offering_cards
     SET title = btrim(p_title), lede = coalesce(p_lede, ''),
         highlight_lead = coalesce(p_highlight_lead, ''),
         highlight = coalesce(p_highlight, ''),
         cta_label = coalesce(p_cta_label, ''),
         cta_label_mobile = coalesce(p_cta_label_mobile, ''),
         cta_href = nullif(btrim(coalesce(p_cta_href, '')), ''),
         mobile_order = coalesce(p_mobile_order, 0),
         art_media_id = p_art_media_id,
         art_mobile_media_id = p_art_mobile_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offering card % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.offering_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.offering_cards WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.offering_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.offering_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.offering_cards;
BEGIN
  UPDATE cms.offering_cards SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offering card % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.offering_reorder(p_tab_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.offering_cards
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.offering_cards', 'tab_id', p_tab_id, p_ids);
  RETURN QUERY SELECT * FROM cms.offering_cards WHERE tab_id = p_tab_id ORDER BY display_order, id;
END;
$$;
