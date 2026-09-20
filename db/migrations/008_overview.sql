-- ============================================================================
-- 008_overview.sql — the dashboard's landing figures.
--
-- The Overview screen wants a handful of counts. It could ask for each list
-- and measure its length, but that ships every row of every table across the
-- wire to produce fifteen integers. One function, one round trip.
--
-- Counts are of rows an editor can act on, so inactive rows are included:
-- "12 FAQs, 2 switched off" is the useful reading, and hiding the disabled
-- ones would make the number disagree with the screen that lists them.
-- ============================================================================

SET search_path = cms, public;

CREATE OR REPLACE FUNCTION cms.overview_counts()
RETURNS TABLE (
  label    TEXT,
  total    BIGINT,
  inactive BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 'Sections'::TEXT, count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.page_sections
  UNION ALL
  SELECT 'Media assets', count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.media_assets
  UNION ALL
  SELECT 'Navigation links', count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.navigation_items
  UNION ALL
  SELECT 'Administrators', count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.admin_users
  UNION ALL
  SELECT 'IPOs', count(*), count(*) FILTER (WHERE NOT is_active) FROM cms.ipo_items
  UNION ALL
  SELECT 'Offering cards', count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.offering_cards
  UNION ALL
  SELECT 'Research reports', count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.research_reports
  UNION ALL
  SELECT 'Lessons', count(*), count(*) FILTER (WHERE NOT is_active) FROM cms.lessons
  UNION ALL
  SELECT 'News stories', count(*), count(*) FILTER (WHERE NOT is_active) FROM cms.news_items
  UNION ALL
  SELECT 'Testimonials', count(*), count(*) FILTER (WHERE NOT is_active) FROM cms.testimonials
  UNION ALL
  SELECT 'Pricing plans', count(*), count(*) FILTER (WHERE NOT is_active) FROM cms.pricing_plans
  UNION ALL
  SELECT 'FAQs', count(*), count(*) FILTER (WHERE NOT is_active) FROM cms.faq_items
  UNION ALL
  SELECT 'Promotional banners', count(*), count(*) FILTER (WHERE NOT is_active)
    FROM cms.promo_banners;
$$;

-- ---------------------------------------------------------------------------
-- banner_schedule_state — what the Promotional Banners table shows in its
-- status column. The rule lives next to the payload's, not in the dashboard,
-- so "live" cannot come to mean two different things.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.banner_schedule_state(
  p_is_active BOOLEAN,
  p_starts_at TIMESTAMPTZ,
  p_ends_at   TIMESTAMPTZ
)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
           WHEN NOT p_is_active                              THEN 'disabled'
           WHEN p_starts_at IS NOT NULL AND p_starts_at > now() THEN 'scheduled'
           WHEN p_ends_at   IS NOT NULL AND p_ends_at  <= now() THEN 'expired'
           ELSE 'live'
         END;
$$;
