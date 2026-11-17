-- ============================================================================
-- 019_content_payload.sql — content_blocks/content_items in the public payload.
--
-- section_items_json (007) is a branch per home fold, keyed by section key. It
-- is not rewritten here: it is renamed, and a thin wrapper of the same name
-- calls it and adds a `content` member for any section that has content rows.
-- Home folds have none, so their payload is byte-for-byte what it was; a
-- shared fold (faq, app-promo, sticky-nudge, research) placed on an inner page
-- is served by the legacy branch, because its rows are in the old tables.
-- ============================================================================

SET search_path = cms, public;

-- --------------------------------------------------------------------------
-- resolve_media — swap `<name>_media` ids for media objects
--
--   {"photo_media": 12, "title": "x"}  →  {"photo": {url, alt, …}, "title": "x"}
--
-- One level deep, which is as deep as the registry nests (a field is a scalar,
-- a list of strings, or a media id). An id that no longer resolves — deleted,
-- or an inactive asset — yields null, which the site treats as "use the
-- built-in image".
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.resolve_media(p_data JSONB)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
  SELECT coalesce(
           jsonb_object_agg(
             CASE WHEN right(e.key, 6) = '_media' THEN left(e.key, length(e.key) - 6) ELSE e.key END,
             CASE
               WHEN right(e.key, 6) = '_media' THEN
                 CASE
                   WHEN (e.value #>> '{}') ~ '^[0-9]+$' THEN cms.media_json((e.value #>> '{}')::BIGINT)
                   ELSE 'null'::jsonb
                 END
               ELSE e.value
             END),
           '{}'::jsonb)
    FROM jsonb_each(coalesce(p_data, '{}'::jsonb)) AS e;
$$;

-- --------------------------------------------------------------------------
-- content_json — one section's block and active collections
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.content_json(p_section_id BIGINT)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
  SELECT jsonb_build_object(
           'block', coalesce((
             SELECT cms.resolve_media(b.data) FROM cms.content_blocks b WHERE b.section_id = p_section_id
           ), '{}'::jsonb),
           'collections', coalesce((
             SELECT jsonb_object_agg(c.collection, c.rows)
               FROM (
                 SELECT i.collection,
                        jsonb_agg(
                          jsonb_build_object('id', i.id, 'key', i.item_key) || cms.resolve_media(i.data)
                          ORDER BY i.display_order, i.id
                        ) AS rows
                   FROM cms.content_items i
                  WHERE i.section_id = p_section_id AND i.is_active
                  GROUP BY i.collection
               ) AS c
           ), '{}'::jsonb)
         );
$$;

-- --------------------------------------------------------------------------
-- the wrapper
-- --------------------------------------------------------------------------
ALTER FUNCTION cms.section_items_json(BIGINT, TEXT) RENAME TO section_items_json_legacy;

CREATE OR REPLACE FUNCTION cms.section_items_json(p_section_id BIGINT, p_section_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
DECLARE
  v JSONB := cms.section_items_json_legacy(p_section_id, p_section_key);
BEGIN
  IF EXISTS (SELECT 1 FROM cms.content_blocks WHERE section_id = p_section_id)
     OR EXISTS (SELECT 1 FROM cms.content_items WHERE section_id = p_section_id) THEN
    v := v || jsonb_build_object('content', cms.content_json(p_section_id));
  END IF;
  RETURN v;
END;
$$;

-- --------------------------------------------------------------------------
-- media_usage — content_blocks / content_items count as usage
--
-- Re-issued from 009 with one more clause. Without it, deleting a photo from
-- the library would succeed while a leader or an award still points at it.
-- --------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.media_usage(p_id BIGINT)
RETURNS TABLE (
  location TEXT,
  uses     BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER SET search_path = cms, public
AS $$
  SELECT * FROM (
    SELECT 'Site settings'::TEXT, count(*) FROM cms.site_settings
     WHERE logo_media_id = p_id OR footer_logo_media_id = p_id
    UNION ALL
    SELECT 'SEO — Open Graph image', count(*) FROM cms.seo_metadata
     WHERE og_image_media_id = p_id
    UNION ALL
    SELECT 'Navigation icons', count(*) FROM cms.navigation_items
     WHERE icon_media_id = p_id
    UNION ALL
    SELECT 'Hero mockup', count(*) FROM cms.hero_sections WHERE mockup_media_id = p_id
    UNION ALL
    SELECT 'Hero KPI icons', count(*) FROM cms.hero_kpis WHERE icon_media_id = p_id
    UNION ALL
    SELECT 'Section images and backgrounds', count(*) FROM cms.section_blocks
     WHERE image_media_id = p_id OR image_mobile_media_id = p_id
        OR background_media_id = p_id OR background_mobile_media_id = p_id
    UNION ALL
    SELECT 'Statistics icons', count(*) FROM cms.stat_items WHERE icon_media_id = p_id
    UNION ALL
    SELECT 'Bento card artwork', count(*) FROM cms.bento_cards
     WHERE art_media_id = p_id OR art_secondary_media_id = p_id
    UNION ALL
    SELECT 'Offering card artwork', count(*) FROM cms.offering_cards
     WHERE art_media_id = p_id OR art_mobile_media_id = p_id
    UNION ALL
    SELECT 'Purpose card artwork', count(*) FROM cms.purpose_cards WHERE art_media_id = p_id
    UNION ALL
    SELECT 'Platform panels', count(*) FROM cms.platform_panels WHERE media_id = p_id
    UNION ALL
    SELECT 'Research covers', count(*) FROM cms.research_reports WHERE cover_media_id = p_id
    UNION ALL
    SELECT 'News images', count(*) FROM cms.news_items WHERE image_media_id = p_id
    UNION ALL
    SELECT 'Lesson thumbnails', count(*) FROM cms.lessons WHERE thumbnail_media_id = p_id
    UNION ALL
    SELECT 'Pricing plan icons', count(*) FROM cms.pricing_plans WHERE icon_media_id = p_id
    UNION ALL
    SELECT 'Promotional banners', count(*) FROM cms.promo_banners
     WHERE image_media_id = p_id OR image_mobile_media_id = p_id
    UNION ALL
    SELECT 'Inner-page content images', count(*)
      FROM (
        SELECT data FROM cms.content_blocks
        UNION ALL
        SELECT data FROM cms.content_items
      ) AS c
     WHERE EXISTS (
       SELECT 1 FROM jsonb_each(c.data) AS e
        WHERE right(e.key, 6) = '_media' AND (e.value #>> '{}') = p_id::TEXT
     )
  ) AS usage(location, uses)
   WHERE usage.uses > 0
   ORDER BY usage.uses DESC, usage.location;
$$;

-- --------------------------------------------------------------------------
-- the 016 boundary, re-applied to what this migration created
-- --------------------------------------------------------------------------
DO $boundary$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'cms'
       AND p.prokind = 'f'
       AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER SET search_path = cms, public', r.sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.sig);
  END LOOP;
END
$boundary$;

DO $grants$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sbi_cms_api') THEN
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cms TO sbi_cms_api;
    REVOKE ALL ON ALL TABLES IN SCHEMA cms FROM sbi_cms_api;
  END IF;
END
$grants$;
