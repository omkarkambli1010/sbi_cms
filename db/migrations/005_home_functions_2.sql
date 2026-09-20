-- ============================================================================
-- 005_home_functions_2.sql — CRUD for the remaining home-page folds.
--
-- Continues 004. Same seven operations per entity, same conventions; the
-- helpers (cms.reorder_rows, cms.reorder_rows_global, cms.section_id_for) are
-- defined there and reused here. Comments are lighter than 004's because the
-- pattern is established — only the departures from it are annotated.
-- ============================================================================

SET search_path = cms, public;

-- ===========================================================================
-- purpose_cards — Invest with a purpose
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.purpose_card_create(
  p_section_id    BIGINT,
  p_slug          TEXT,
  p_title         TEXT,
  p_lede          TEXT    DEFAULT '',
  p_cta_label     TEXT    DEFAULT '',
  p_cta_href      TEXT    DEFAULT NULL,
  p_art_media_id  BIGINT  DEFAULT NULL,
  p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.purpose_cards
LANGUAGE plpgsql
AS $$
DECLARE v_row cms.purpose_cards;
BEGIN
  INSERT INTO cms.purpose_cards (section_id, slug, title, lede, cta_label, cta_href, art_media_id, display_order)
  VALUES (
    p_section_id, btrim(p_slug), btrim(p_title), coalesce(p_lede, ''),
    coalesce(p_cta_label, ''), nullif(btrim(coalesce(p_cta_href, '')), ''), p_art_media_id,
    coalesce(p_display_order,
             (SELECT coalesce(max(display_order), 0) + 1
                FROM cms.purpose_cards WHERE section_id = p_section_id))
  )
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_card_get(p_id BIGINT)
RETURNS cms.purpose_cards LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.purpose_cards WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.purpose_card_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.purpose_cards LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.purpose_cards
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_card_update(
  p_id           BIGINT,
  p_title        TEXT,
  p_lede         TEXT   DEFAULT '',
  p_cta_label    TEXT   DEFAULT '',
  p_cta_href     TEXT   DEFAULT NULL,
  p_art_media_id BIGINT DEFAULT NULL
)
RETURNS cms.purpose_cards LANGUAGE plpgsql
AS $$
DECLARE v_row cms.purpose_cards;
BEGIN
  UPDATE cms.purpose_cards
     SET title = btrim(p_title), lede = coalesce(p_lede, ''),
         cta_label = coalesce(p_cta_label, ''),
         cta_href = nullif(btrim(coalesce(p_cta_href, '')), ''),
         art_media_id = p_art_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purpose card % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_card_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.purpose_cards WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.purpose_card_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.purpose_cards LANGUAGE plpgsql
AS $$
DECLARE v_row cms.purpose_cards;
BEGIN
  UPDATE cms.purpose_cards SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purpose card % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_card_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.purpose_cards LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.purpose_cards', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.purpose_cards
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- purpose_card_points — bullets, parented by card
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.purpose_point_create(
  p_card_id BIGINT, p_text TEXT, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.purpose_card_points LANGUAGE plpgsql
AS $$
DECLARE v_row cms.purpose_card_points;
BEGIN
  INSERT INTO cms.purpose_card_points (card_id, text, display_order)
  VALUES (p_card_id, btrim(p_text),
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.purpose_card_points WHERE card_id = p_card_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_point_get(p_id BIGINT)
RETURNS cms.purpose_card_points LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.purpose_card_points WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.purpose_point_list(p_card_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.purpose_card_points LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.purpose_card_points
   WHERE card_id = p_card_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_point_update(p_id BIGINT, p_text TEXT)
RETURNS cms.purpose_card_points LANGUAGE plpgsql
AS $$
DECLARE v_row cms.purpose_card_points;
BEGIN
  UPDATE cms.purpose_card_points SET text = btrim(p_text) WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purpose point % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_point_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.purpose_card_points WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.purpose_point_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.purpose_card_points LANGUAGE plpgsql
AS $$
DECLARE v_row cms.purpose_card_points;
BEGIN
  UPDATE cms.purpose_card_points SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purpose point % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.purpose_point_reorder(p_card_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.purpose_card_points LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.purpose_card_points', 'card_id', p_card_id, p_ids);
  RETURN QUERY SELECT * FROM cms.purpose_card_points
                WHERE card_id = p_card_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- platform_steps
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.platform_step_create(
  p_tab_id BIGINT, p_title TEXT, p_body TEXT DEFAULT '', p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.platform_steps LANGUAGE plpgsql
AS $$
DECLARE v_row cms.platform_steps;
BEGIN
  INSERT INTO cms.platform_steps (tab_id, title, body, display_order)
  VALUES (p_tab_id, btrim(p_title), coalesce(p_body, ''),
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.platform_steps WHERE tab_id = p_tab_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.platform_step_get(p_id BIGINT)
RETURNS cms.platform_steps LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.platform_steps WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.platform_step_list(p_tab_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.platform_steps LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.platform_steps
   WHERE tab_id = p_tab_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.platform_step_update(p_id BIGINT, p_title TEXT, p_body TEXT DEFAULT '')
RETURNS cms.platform_steps LANGUAGE plpgsql
AS $$
DECLARE v_row cms.platform_steps;
BEGIN
  UPDATE cms.platform_steps SET title = btrim(p_title), body = coalesce(p_body, '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform step % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.platform_step_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.platform_steps WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.platform_step_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.platform_steps LANGUAGE plpgsql
AS $$
DECLARE v_row cms.platform_steps;
BEGIN
  UPDATE cms.platform_steps SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform step % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.platform_step_reorder(p_tab_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.platform_steps LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.platform_steps', 'tab_id', p_tab_id, p_ids);
  RETURN QUERY SELECT * FROM cms.platform_steps WHERE tab_id = p_tab_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- platform_panels
--
-- step_index is unique per tab, so _create upserts on it: re-pointing the
-- panel shown for step 2 is an edit, not a second row.
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.platform_panel_create(
  p_tab_id BIGINT, p_media_id BIGINT DEFAULT NULL,
  p_step_index INTEGER DEFAULT 0, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.platform_panels LANGUAGE plpgsql
AS $$
DECLARE v_row cms.platform_panels;
BEGIN
  INSERT INTO cms.platform_panels (tab_id, media_id, step_index, display_order)
  VALUES (p_tab_id, p_media_id, coalesce(p_step_index, 0),
          coalesce(p_display_order, coalesce(p_step_index, 0) + 1))
  ON CONFLICT (tab_id, step_index) DO UPDATE
     SET media_id = EXCLUDED.media_id, display_order = EXCLUDED.display_order
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.platform_panel_get(p_id BIGINT)
RETURNS cms.platform_panels LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.platform_panels WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.platform_panel_list(p_tab_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.platform_panels LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.platform_panels
   WHERE tab_id = p_tab_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, step_index, id;
$$;

CREATE OR REPLACE FUNCTION cms.platform_panel_update(
  p_id BIGINT, p_media_id BIGINT DEFAULT NULL, p_step_index INTEGER DEFAULT NULL
)
RETURNS cms.platform_panels LANGUAGE plpgsql
AS $$
DECLARE v_row cms.platform_panels;
BEGIN
  UPDATE cms.platform_panels
     SET media_id = p_media_id, step_index = coalesce(p_step_index, step_index)
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform panel % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.platform_panel_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.platform_panels WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.platform_panel_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.platform_panels LANGUAGE plpgsql
AS $$
DECLARE v_row cms.platform_panels;
BEGIN
  UPDATE cms.platform_panels SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Platform panel % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.platform_panel_reorder(p_tab_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.platform_panels LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.platform_panels', 'tab_id', p_tab_id, p_ids);
  RETURN QUERY SELECT * FROM cms.platform_panels WHERE tab_id = p_tab_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- research_reports
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.research_create(
  p_tab_id BIGINT, p_title TEXT, p_kind TEXT DEFAULT '',
  p_published_on DATE DEFAULT NULL, p_href TEXT DEFAULT NULL,
  p_cover_media_id BIGINT DEFAULT NULL, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.research_reports LANGUAGE plpgsql
AS $$
DECLARE v_row cms.research_reports;
BEGIN
  INSERT INTO cms.research_reports (tab_id, title, kind, published_on, href, cover_media_id, display_order)
  VALUES (p_tab_id, btrim(p_title), coalesce(p_kind, ''), p_published_on,
          nullif(btrim(coalesce(p_href, '')), ''), p_cover_media_id,
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.research_reports WHERE tab_id = p_tab_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.research_get(p_id BIGINT)
RETURNS cms.research_reports LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.research_reports WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.research_list(p_tab_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.research_reports LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.research_reports
   WHERE tab_id = p_tab_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.research_update(
  p_id BIGINT, p_title TEXT, p_kind TEXT DEFAULT '',
  p_published_on DATE DEFAULT NULL, p_href TEXT DEFAULT NULL,
  p_cover_media_id BIGINT DEFAULT NULL
)
RETURNS cms.research_reports LANGUAGE plpgsql
AS $$
DECLARE v_row cms.research_reports;
BEGIN
  UPDATE cms.research_reports
     SET title = btrim(p_title), kind = coalesce(p_kind, ''), published_on = p_published_on,
         href = nullif(btrim(coalesce(p_href, '')), ''), cover_media_id = p_cover_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Research report % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.research_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.research_reports WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.research_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.research_reports LANGUAGE plpgsql
AS $$
DECLARE v_row cms.research_reports;
BEGIN
  UPDATE cms.research_reports SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Research report % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.research_reorder(p_tab_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.research_reports LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.research_reports', 'tab_id', p_tab_id, p_ids);
  RETURN QUERY SELECT * FROM cms.research_reports WHERE tab_id = p_tab_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- news_items
--
-- _set_lead is the extra operation here: the partial unique index allows one
-- lead story per section, so promoting a story has to demote the incumbent in
-- the same statement or the index rejects it.
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.news_create(
  p_section_id BIGINT, p_title TEXT, p_published_label TEXT DEFAULT '',
  p_href TEXT DEFAULT NULL, p_is_lead BOOLEAN DEFAULT FALSE,
  p_image_media_id BIGINT DEFAULT NULL, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.news_items LANGUAGE plpgsql
AS $$
DECLARE v_row cms.news_items;
BEGIN
  IF coalesce(p_is_lead, FALSE) THEN
    UPDATE cms.news_items SET is_lead = FALSE WHERE section_id = p_section_id AND is_lead;
  END IF;

  INSERT INTO cms.news_items (section_id, title, published_label, href, is_lead, image_media_id, display_order)
  VALUES (p_section_id, btrim(p_title), coalesce(p_published_label, ''),
          nullif(btrim(coalesce(p_href, '')), ''), coalesce(p_is_lead, FALSE), p_image_media_id,
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.news_items WHERE section_id = p_section_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.news_get(p_id BIGINT)
RETURNS cms.news_items LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.news_items WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.news_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.news_items LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.news_items
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY is_lead DESC, display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.news_update(
  p_id BIGINT, p_title TEXT, p_published_label TEXT DEFAULT '',
  p_href TEXT DEFAULT NULL, p_image_media_id BIGINT DEFAULT NULL
)
RETURNS cms.news_items LANGUAGE plpgsql
AS $$
DECLARE v_row cms.news_items;
BEGIN
  UPDATE cms.news_items
     SET title = btrim(p_title), published_label = coalesce(p_published_label, ''),
         href = nullif(btrim(coalesce(p_href, '')), ''), image_media_id = p_image_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'News item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.news_set_lead(p_id BIGINT)
RETURNS cms.news_items LANGUAGE plpgsql
AS $$
DECLARE
  v_section_id BIGINT;
  v_row        cms.news_items;
BEGIN
  SELECT section_id INTO v_section_id FROM cms.news_items WHERE id = p_id;
  IF v_section_id IS NULL THEN
    RAISE EXCEPTION 'News item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;

  UPDATE cms.news_items SET is_lead = FALSE WHERE section_id = v_section_id AND is_lead;
  UPDATE cms.news_items SET is_lead = TRUE  WHERE id = p_id RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.news_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.news_items WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.news_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.news_items LANGUAGE plpgsql
AS $$
DECLARE v_row cms.news_items;
BEGIN
  UPDATE cms.news_items SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'News item % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.news_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.news_items LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.news_items', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.news_items
                WHERE section_id = p_section_id ORDER BY is_lead DESC, display_order, id;
END;
$$;

-- ===========================================================================
-- lessons
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.lesson_create(
  p_tab_id BIGINT, p_title TEXT, p_duration TEXT DEFAULT '',
  p_published_on DATE DEFAULT NULL, p_href TEXT DEFAULT NULL,
  p_thumbnail_media_id BIGINT DEFAULT NULL, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.lessons LANGUAGE plpgsql
AS $$
DECLARE v_row cms.lessons;
BEGIN
  INSERT INTO cms.lessons (tab_id, title, duration, published_on, href, thumbnail_media_id, display_order)
  VALUES (p_tab_id, btrim(p_title), coalesce(p_duration, ''), p_published_on,
          nullif(btrim(coalesce(p_href, '')), ''), p_thumbnail_media_id,
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.lessons WHERE tab_id = p_tab_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.lesson_get(p_id BIGINT)
RETURNS cms.lessons LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.lessons WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.lesson_list(p_tab_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.lessons LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.lessons
   WHERE tab_id = p_tab_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.lesson_update(
  p_id BIGINT, p_title TEXT, p_duration TEXT DEFAULT '',
  p_published_on DATE DEFAULT NULL, p_href TEXT DEFAULT NULL,
  p_thumbnail_media_id BIGINT DEFAULT NULL
)
RETURNS cms.lessons LANGUAGE plpgsql
AS $$
DECLARE v_row cms.lessons;
BEGIN
  UPDATE cms.lessons
     SET title = btrim(p_title), duration = coalesce(p_duration, ''),
         published_on = p_published_on, href = nullif(btrim(coalesce(p_href, '')), ''),
         thumbnail_media_id = p_thumbnail_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lesson % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.lesson_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.lessons WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.lesson_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.lessons LANGUAGE plpgsql
AS $$
DECLARE v_row cms.lessons;
BEGIN
  UPDATE cms.lessons SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lesson % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.lesson_reorder(p_tab_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.lessons LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.lessons', 'tab_id', p_tab_id, p_ids);
  RETURN QUERY SELECT * FROM cms.lessons WHERE tab_id = p_tab_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- testimonials
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.testimonial_create(
  p_section_id BIGINT, p_quote TEXT, p_author TEXT DEFAULT '', p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.testimonials LANGUAGE plpgsql
AS $$
DECLARE v_row cms.testimonials;
BEGIN
  INSERT INTO cms.testimonials (section_id, quote, author, display_order)
  VALUES (p_section_id, btrim(p_quote), coalesce(p_author, ''),
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.testimonials WHERE section_id = p_section_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.testimonial_get(p_id BIGINT)
RETURNS cms.testimonials LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.testimonials WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.testimonial_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.testimonials LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.testimonials
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.testimonial_update(p_id BIGINT, p_quote TEXT, p_author TEXT DEFAULT '')
RETURNS cms.testimonials LANGUAGE plpgsql
AS $$
DECLARE v_row cms.testimonials;
BEGIN
  UPDATE cms.testimonials SET quote = btrim(p_quote), author = coalesce(p_author, '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Testimonial % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.testimonial_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.testimonials WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.testimonial_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.testimonials LANGUAGE plpgsql
AS $$
DECLARE v_row cms.testimonials;
BEGIN
  UPDATE cms.testimonials SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Testimonial % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.testimonial_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.testimonials LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.testimonials', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.testimonials
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- pricing_plans / pricing_plan_features
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.plan_create(
  p_section_id BIGINT, p_name TEXT, p_price TEXT DEFAULT '', p_price_note TEXT DEFAULT '',
  p_accent TEXT DEFAULT 'suvidha', p_cta_label TEXT DEFAULT '', p_cta_href TEXT DEFAULT NULL,
  p_icon_media_id BIGINT DEFAULT NULL, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.pricing_plans LANGUAGE plpgsql
AS $$
DECLARE v_row cms.pricing_plans;
BEGIN
  INSERT INTO cms.pricing_plans (section_id, name, price, price_note, accent, cta_label, cta_href, icon_media_id, display_order)
  VALUES (p_section_id, btrim(p_name), coalesce(p_price, ''), coalesce(p_price_note, ''),
          coalesce(nullif(btrim(p_accent), ''), 'suvidha'), coalesce(p_cta_label, ''),
          nullif(btrim(coalesce(p_cta_href, '')), ''), p_icon_media_id,
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.pricing_plans WHERE section_id = p_section_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_get(p_id BIGINT)
RETURNS cms.pricing_plans LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.pricing_plans WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.plan_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.pricing_plans LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.pricing_plans
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.plan_update(
  p_id BIGINT, p_name TEXT, p_price TEXT DEFAULT '', p_price_note TEXT DEFAULT '',
  p_accent TEXT DEFAULT 'suvidha', p_cta_label TEXT DEFAULT '', p_cta_href TEXT DEFAULT NULL,
  p_icon_media_id BIGINT DEFAULT NULL
)
RETURNS cms.pricing_plans LANGUAGE plpgsql
AS $$
DECLARE v_row cms.pricing_plans;
BEGIN
  UPDATE cms.pricing_plans
     SET name = btrim(p_name), price = coalesce(p_price, ''),
         price_note = coalesce(p_price_note, ''),
         accent = coalesce(nullif(btrim(p_accent), ''), 'suvidha'),
         cta_label = coalesce(p_cta_label, ''),
         cta_href = nullif(btrim(coalesce(p_cta_href, '')), ''),
         icon_media_id = p_icon_media_id
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plan % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.pricing_plans WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.plan_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.pricing_plans LANGUAGE plpgsql
AS $$
DECLARE v_row cms.pricing_plans;
BEGIN
  UPDATE cms.pricing_plans SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plan % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.pricing_plans LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.pricing_plans', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.pricing_plans
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_feature_create(
  p_plan_id BIGINT, p_text TEXT, p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.pricing_plan_features LANGUAGE plpgsql
AS $$
DECLARE v_row cms.pricing_plan_features;
BEGIN
  INSERT INTO cms.pricing_plan_features (plan_id, text, display_order)
  VALUES (p_plan_id, btrim(p_text),
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.pricing_plan_features WHERE plan_id = p_plan_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_feature_get(p_id BIGINT)
RETURNS cms.pricing_plan_features LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.pricing_plan_features WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.plan_feature_list(p_plan_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.pricing_plan_features LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.pricing_plan_features
   WHERE plan_id = p_plan_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.plan_feature_update(p_id BIGINT, p_text TEXT)
RETURNS cms.pricing_plan_features LANGUAGE plpgsql
AS $$
DECLARE v_row cms.pricing_plan_features;
BEGIN
  UPDATE cms.pricing_plan_features SET text = btrim(p_text) WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plan feature % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_feature_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.pricing_plan_features WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.plan_feature_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.pricing_plan_features LANGUAGE plpgsql
AS $$
DECLARE v_row cms.pricing_plan_features;
BEGIN
  UPDATE cms.pricing_plan_features SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plan feature % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.plan_feature_reorder(p_plan_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.pricing_plan_features LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.pricing_plan_features', 'plan_id', p_plan_id, p_ids);
  RETURN QUERY SELECT * FROM cms.pricing_plan_features
                WHERE plan_id = p_plan_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- faq_items
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.faq_create(
  p_section_id BIGINT, p_question TEXT, p_answer TEXT DEFAULT '', p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.faq_items LANGUAGE plpgsql
AS $$
DECLARE v_row cms.faq_items;
BEGIN
  INSERT INTO cms.faq_items (section_id, question, answer, display_order)
  VALUES (p_section_id, btrim(p_question), coalesce(p_answer, ''),
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.faq_items WHERE section_id = p_section_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.faq_get(p_id BIGINT)
RETURNS cms.faq_items LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.faq_items WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.faq_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.faq_items LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.faq_items
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.faq_update(p_id BIGINT, p_question TEXT, p_answer TEXT DEFAULT '')
RETURNS cms.faq_items LANGUAGE plpgsql
AS $$
DECLARE v_row cms.faq_items;
BEGIN
  UPDATE cms.faq_items SET question = btrim(p_question), answer = coalesce(p_answer, '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAQ % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.faq_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.faq_items WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.faq_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.faq_items LANGUAGE plpgsql
AS $$
DECLARE v_row cms.faq_items;
BEGIN
  UPDATE cms.faq_items SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAQ % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.faq_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.faq_items LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.faq_items', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.faq_items
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- promo_banners
--
-- _list_live is the extra operation: the public payload needs the scheduling
-- rule applied, and that rule belongs in one place rather than in whichever
-- query happens to read the table.
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.banner_create(
  p_section_id BIGINT, p_title TEXT, p_description TEXT DEFAULT '',
  p_cta_label TEXT DEFAULT '', p_cta_href TEXT DEFAULT NULL,
  p_image_media_id BIGINT DEFAULT NULL, p_image_mobile_media_id BIGINT DEFAULT NULL,
  p_starts_at TIMESTAMPTZ DEFAULT NULL, p_ends_at TIMESTAMPTZ DEFAULT NULL,
  p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.promo_banners LANGUAGE plpgsql
AS $$
DECLARE v_row cms.promo_banners;
BEGIN
  INSERT INTO cms.promo_banners (
    section_id, title, description, cta_label, cta_href,
    image_media_id, image_mobile_media_id, starts_at, ends_at, display_order
  )
  VALUES (p_section_id, btrim(p_title), coalesce(p_description, ''),
          coalesce(p_cta_label, ''), nullif(btrim(coalesce(p_cta_href, '')), ''),
          p_image_media_id, p_image_mobile_media_id, p_starts_at, p_ends_at,
          coalesce(p_display_order,
                   (SELECT coalesce(max(display_order), 0) + 1
                      FROM cms.promo_banners WHERE section_id = p_section_id)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.banner_get(p_id BIGINT)
RETURNS cms.promo_banners LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.promo_banners WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.banner_list(p_section_id BIGINT, p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.promo_banners LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.promo_banners
   WHERE section_id = p_section_id AND (NOT p_only_active OR is_active)
   ORDER BY display_order, id;
$$;

/** Active AND inside its window, best first. The public payload's only read. */
CREATE OR REPLACE FUNCTION cms.banner_list_live(p_section_id BIGINT)
RETURNS SETOF cms.promo_banners LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.promo_banners
   WHERE section_id = p_section_id
     AND is_active
     AND (starts_at IS NULL OR starts_at <= now())
     AND (ends_at   IS NULL OR ends_at   >  now())
   ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.banner_update(
  p_id BIGINT, p_title TEXT, p_description TEXT DEFAULT '',
  p_cta_label TEXT DEFAULT '', p_cta_href TEXT DEFAULT NULL,
  p_image_media_id BIGINT DEFAULT NULL, p_image_mobile_media_id BIGINT DEFAULT NULL,
  p_starts_at TIMESTAMPTZ DEFAULT NULL, p_ends_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS cms.promo_banners LANGUAGE plpgsql
AS $$
DECLARE v_row cms.promo_banners;
BEGIN
  UPDATE cms.promo_banners
     SET title = btrim(p_title), description = coalesce(p_description, ''),
         cta_label = coalesce(p_cta_label, ''),
         cta_href = nullif(btrim(coalesce(p_cta_href, '')), ''),
         image_media_id = p_image_media_id,
         image_mobile_media_id = p_image_mobile_media_id,
         starts_at = p_starts_at, ends_at = p_ends_at
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Banner % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.banner_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.promo_banners WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.banner_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.promo_banners LANGUAGE plpgsql
AS $$
DECLARE v_row cms.promo_banners;
BEGIN
  UPDATE cms.promo_banners SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Banner % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.banner_reorder(p_section_id BIGINT, p_ids BIGINT[])
RETURNS SETOF cms.promo_banners LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows('cms.promo_banners', 'section_id', p_section_id, p_ids);
  RETURN QUERY SELECT * FROM cms.promo_banners
                WHERE section_id = p_section_id ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- sticky_nudge — singleton per section, like section_blocks
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.sticky_nudge_get(p_page_slug TEXT, p_section_key TEXT DEFAULT 'sticky-nudge')
RETURNS cms.sticky_nudge LANGUAGE sql STABLE
AS $$
  SELECT n.* FROM cms.sticky_nudge n
   WHERE n.section_id = cms.section_id_for(p_page_slug, p_section_key);
$$;

CREATE OR REPLACE FUNCTION cms.sticky_nudge_update(
  p_page_slug TEXT, p_title TEXT DEFAULT '', p_mobile_placeholder TEXT DEFAULT '',
  p_name_placeholder TEXT DEFAULT '', p_cta_label TEXT DEFAULT '',
  p_cta_href TEXT DEFAULT NULL, p_section_key TEXT DEFAULT 'sticky-nudge'
)
RETURNS cms.sticky_nudge LANGUAGE plpgsql
AS $$
DECLARE
  v_section_id BIGINT;
  v_row        cms.sticky_nudge;
BEGIN
  v_section_id := cms.section_id_for(p_page_slug, p_section_key);
  IF v_section_id IS NULL THEN
    RAISE EXCEPTION 'Section %/% not found', p_page_slug, p_section_key
      USING ERRCODE = 'no_data_found';
  END IF;

  INSERT INTO cms.sticky_nudge (section_id, title, mobile_placeholder, name_placeholder, cta_label, cta_href)
  VALUES (v_section_id, coalesce(p_title, ''), coalesce(p_mobile_placeholder, ''),
          coalesce(p_name_placeholder, ''), coalesce(p_cta_label, ''),
          nullif(btrim(coalesce(p_cta_href, '')), ''))
  ON CONFLICT (section_id) DO UPDATE SET
    title              = EXCLUDED.title,
    mobile_placeholder = EXCLUDED.mobile_placeholder,
    name_placeholder   = EXCLUDED.name_placeholder,
    cta_label          = EXCLUDED.cta_label,
    cta_href           = EXCLUDED.cta_href
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- ===========================================================================
-- legal_content — site level, keyed by content_key
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.legal_create(
  p_content_key TEXT, p_name TEXT, p_body TEXT DEFAULT '', p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.legal_content LANGUAGE plpgsql
AS $$
DECLARE v_row cms.legal_content;
BEGIN
  INSERT INTO cms.legal_content (content_key, name, body, display_order)
  VALUES (btrim(p_content_key), btrim(p_name), coalesce(p_body, ''),
          coalesce(p_display_order, (SELECT coalesce(max(display_order), 0) + 1 FROM cms.legal_content)))
  ON CONFLICT (content_key) DO UPDATE
     SET name = EXCLUDED.name, body = EXCLUDED.body, display_order = EXCLUDED.display_order
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.legal_get(p_id BIGINT)
RETURNS cms.legal_content LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.legal_content WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.legal_list(p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.legal_content LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.legal_content
   WHERE (NOT p_only_active OR is_active) ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.legal_update(p_id BIGINT, p_name TEXT, p_body TEXT DEFAULT '')
RETURNS cms.legal_content LANGUAGE plpgsql
AS $$
DECLARE v_row cms.legal_content;
BEGIN
  UPDATE cms.legal_content SET name = btrim(p_name), body = coalesce(p_body, '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Legal block % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.legal_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.legal_content WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.legal_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.legal_content LANGUAGE plpgsql
AS $$
DECLARE v_row cms.legal_content;
BEGIN
  UPDATE cms.legal_content SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Legal block % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.legal_reorder(p_ids BIGINT[])
RETURNS SETOF cms.legal_content LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows_global('cms.legal_content', p_ids);
  RETURN QUERY SELECT * FROM cms.legal_content ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- stock_index_letters
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.stock_letter_create(
  p_letter TEXT, p_href TEXT DEFAULT '', p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.stock_index_letters LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stock_index_letters;
BEGIN
  INSERT INTO cms.stock_index_letters (letter, href, display_order)
  VALUES (btrim(p_letter), coalesce(p_href, ''),
          coalesce(p_display_order, (SELECT coalesce(max(display_order), 0) + 1 FROM cms.stock_index_letters)))
  ON CONFLICT (letter) DO UPDATE
     SET href = EXCLUDED.href, display_order = EXCLUDED.display_order
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stock_letter_get(p_id BIGINT)
RETURNS cms.stock_index_letters LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.stock_index_letters WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.stock_letter_list(p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.stock_index_letters LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.stock_index_letters
   WHERE (NOT p_only_active OR is_active) ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.stock_letter_update(p_id BIGINT, p_letter TEXT, p_href TEXT DEFAULT '')
RETURNS cms.stock_index_letters LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stock_index_letters;
BEGIN
  UPDATE cms.stock_index_letters SET letter = btrim(p_letter), href = coalesce(p_href, '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock letter % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stock_letter_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.stock_index_letters WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.stock_letter_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.stock_index_letters LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stock_index_letters;
BEGIN
  UPDATE cms.stock_index_letters SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock letter % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stock_letter_reorder(p_ids BIGINT[])
RETURNS SETOF cms.stock_index_letters LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows_global('cms.stock_index_letters', p_ids);
  RETURN QUERY SELECT * FROM cms.stock_index_letters ORDER BY display_order, id;
END;
$$;

-- ===========================================================================
-- stock_links
-- ===========================================================================

CREATE OR REPLACE FUNCTION cms.stock_link_create(
  p_label TEXT, p_href TEXT DEFAULT '', p_display_order INTEGER DEFAULT NULL
)
RETURNS cms.stock_links LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stock_links;
BEGIN
  INSERT INTO cms.stock_links (label, href, display_order)
  VALUES (btrim(p_label), coalesce(p_href, ''),
          coalesce(p_display_order, (SELECT coalesce(max(display_order), 0) + 1 FROM cms.stock_links)))
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stock_link_get(p_id BIGINT)
RETURNS cms.stock_links LANGUAGE sql STABLE
AS $$ SELECT * FROM cms.stock_links WHERE id = p_id; $$;

CREATE OR REPLACE FUNCTION cms.stock_link_list(p_only_active BOOLEAN DEFAULT FALSE)
RETURNS SETOF cms.stock_links LANGUAGE sql STABLE
AS $$
  SELECT * FROM cms.stock_links
   WHERE (NOT p_only_active OR is_active) ORDER BY display_order, id;
$$;

CREATE OR REPLACE FUNCTION cms.stock_link_update(p_id BIGINT, p_label TEXT, p_href TEXT DEFAULT '')
RETURNS cms.stock_links LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stock_links;
BEGIN
  UPDATE cms.stock_links SET label = btrim(p_label), href = coalesce(p_href, '')
   WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock link % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stock_link_delete(p_id BIGINT)
RETURNS BOOLEAN LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cms.stock_links WHERE id = p_id; RETURN FOUND; END; $$;

CREATE OR REPLACE FUNCTION cms.stock_link_set_active(p_id BIGINT, p_is_active BOOLEAN)
RETURNS cms.stock_links LANGUAGE plpgsql
AS $$
DECLARE v_row cms.stock_links;
BEGIN
  UPDATE cms.stock_links SET is_active = p_is_active WHERE id = p_id RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock link % not found', p_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION cms.stock_link_reorder(p_ids BIGINT[])
RETURNS SETOF cms.stock_links LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM cms.reorder_rows_global('cms.stock_links', p_ids);
  RETURN QUERY SELECT * FROM cms.stock_links ORDER BY display_order, id;
END;
$$;
