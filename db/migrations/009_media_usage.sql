-- ============================================================================
-- 009_media_usage.sql — make "is this image in use?" mean all of the schema.
--
-- cms.media_delete in 002 refuses to delete an asset that is referenced, and
-- checked the five tables that existed then. 003 added eighteen more that
-- point at media_assets. Left as it was, deleting a bento card's artwork
-- would succeed and silently null the card's reference, while deleting the
-- hero's mockup would be refused — the same action with two different
-- outcomes depending on which fold happened to use the file.
--
-- cms.media_usage also gives the dashboard something honest to show: not just
-- "in use" but where, so an editor can go and change those rows first.
-- ============================================================================

SET search_path = cms, public;

CREATE OR REPLACE FUNCTION cms.media_usage(p_id BIGINT)
RETURNS TABLE (
  location TEXT,
  uses     BIGINT
)
LANGUAGE sql
STABLE
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
  ) AS usage(location, uses)
   WHERE usage.uses > 0
   ORDER BY usage.uses DESC, usage.location;
$$;

CREATE OR REPLACE FUNCTION cms.media_delete(p_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_uses  BIGINT;
  v_where TEXT;
BEGIN
  SELECT coalesce(sum(uses), 0), string_agg(location, ', ' ORDER BY location)
    INTO v_uses, v_where
    FROM cms.media_usage(p_id);

  IF v_uses > 0 THEN
    /* Named places rather than a bare count: "used in 3 places" leaves an
       editor hunting, and the hunt is across twenty screens. */
    RAISE EXCEPTION 'Media asset % is still used in: %', p_id, v_where
      USING ERRCODE = 'restrict_violation';
  END IF;

  DELETE FROM cms.media_assets WHERE id = p_id;
  RETURN FOUND;
END;
$$;
