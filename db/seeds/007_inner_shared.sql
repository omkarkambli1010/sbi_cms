-- ============================================================================
-- 007_inner_shared.sql — the home folds that About, Leadership and Sector reuse.
--
-- The FAQ, the app-download promo, the sticky nudge and the research reports
-- appear on the inner pages exactly as they do on the home page. Their tables
-- hang off the section row, so each page gets its own section and its own rows,
-- and an editor can change the FAQ on /about without touching the home page's.
--
-- This seed gives those page-owned sections their starting content: a copy of
-- the home page's rows. Re-runnable — it replaces the copies wholesale, so
-- running it puts them back in step with the home page. Run it after
-- 001/002 (home) and 004–006 (the pages), which the file name order ensures.
-- ============================================================================

SET search_path = cms, public;

BEGIN;

DO $copy$
DECLARE
  v_target RECORD;
  v_home   BIGINT;
  v_dest   BIGINT;
  v_cols   TEXT;
BEGIN
  FOR v_target IN
    SELECT p.slug AS page, s.section_key AS key, s.id AS section_id
      FROM cms.page_sections s
      JOIN cms.pages p ON p.id = s.page_id
     WHERE p.slug IN ('about', 'leadership', 'sector')
       AND s.section_key IN ('faq', 'app-promo', 'sticky-nudge', 'research')
  LOOP
    v_home := cms.section_id_for('home', v_target.key);
    v_dest := v_target.section_id;
    CONTINUE WHEN v_home IS NULL;

    -- The shared shell (title, sub-text, button…): every column but identity
    -- and timestamps.
    SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
      INTO v_cols
      FROM information_schema.columns
     WHERE table_schema = 'cms' AND table_name = 'section_blocks'
       AND column_name NOT IN ('id', 'section_id', 'created_at', 'updated_at');

    EXECUTE format(
      'INSERT INTO cms.section_blocks (section_id, %1$s)
         SELECT $1, %1$s FROM cms.section_blocks WHERE section_id = $2
       ON CONFLICT (section_id) DO UPDATE SET (%1$s) = (SELECT %1$s FROM cms.section_blocks WHERE section_id = $2)',
      v_cols) USING v_dest, v_home;

    IF v_target.key = 'faq' THEN
      DELETE FROM cms.faq_items WHERE section_id = v_dest;
      INSERT INTO cms.faq_items (section_id, question, answer, display_order, is_active)
        SELECT v_dest, question, answer, display_order, is_active
          FROM cms.faq_items WHERE section_id = v_home;

    ELSIF v_target.key = 'app-promo' THEN
      DELETE FROM cms.promo_banners WHERE section_id = v_dest;
      INSERT INTO cms.promo_banners
          (section_id, title, description, cta_label, cta_href, image_media_id, image_mobile_media_id,
           starts_at, ends_at, display_order, is_active)
        SELECT v_dest, title, description, cta_label, cta_href, image_media_id, image_mobile_media_id,
               starts_at, ends_at, display_order, is_active
          FROM cms.promo_banners WHERE section_id = v_home;

    ELSIF v_target.key = 'sticky-nudge' THEN
      INSERT INTO cms.sticky_nudge (section_id, title, mobile_placeholder, name_placeholder, cta_label, cta_href)
        SELECT v_dest, title, mobile_placeholder, name_placeholder, cta_label, cta_href
          FROM cms.sticky_nudge WHERE section_id = v_home
      ON CONFLICT (section_id) DO UPDATE
         SET title = EXCLUDED.title, mobile_placeholder = EXCLUDED.mobile_placeholder,
             name_placeholder = EXCLUDED.name_placeholder, cta_label = EXCLUDED.cta_label,
             cta_href = EXCLUDED.cta_href;

    ELSIF v_target.key = 'research' THEN
      -- Tabs by their key, then each tab's reports under the matching new tab.
      DELETE FROM cms.section_tabs WHERE section_id = v_dest;
      INSERT INTO cms.section_tabs
          (section_id, tab_key, label, transition_duration_ms, transition_easing, display_order, is_active)
        SELECT v_dest, tab_key, label, transition_duration_ms, transition_easing, display_order, is_active
          FROM cms.section_tabs WHERE section_id = v_home;

      INSERT INTO cms.research_reports
          (tab_id, title, kind, published_on, href, cover_media_id, display_order, is_active)
        SELECT nt.id, r.title, r.kind, r.published_on, r.href, r.cover_media_id, r.display_order, r.is_active
          FROM cms.research_reports r
          JOIN cms.section_tabs ot ON ot.id = r.tab_id AND ot.section_id = v_home
          JOIN cms.section_tabs nt ON nt.section_id = v_dest AND nt.tab_key = ot.tab_key;
    END IF;
  END LOOP;
END
$copy$;

COMMIT;
