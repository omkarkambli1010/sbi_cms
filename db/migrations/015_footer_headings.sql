-- ============================================================================
-- 015_footer_headings.sql — the footer's two hardcoded headings.
--
-- Everything else the footer renders is already editable: the address, phone
-- and e-mail are in site_settings; the link columns are navigation_menus; the
-- index letters, keyword chips and legal blocks have had their own tables
-- since 003. Two strings were still literals in Footer.tsx — "Connect with
-- us" over the social icons and "Stocks" over the A-Z — so those two were the
-- only things on the fold an editor could not change.
--
-- They go in site_settings rather than a new table, following the precedent
-- search_placeholder already set: a handful of site-wide interface strings,
-- one row, one screen. A table per string would be worse.
-- ============================================================================

SET search_path = cms, public;

ALTER TABLE cms.site_settings
  ADD COLUMN IF NOT EXISTS connect_label TEXT NOT NULL DEFAULT '';

ALTER TABLE cms.site_settings
  ADD COLUMN IF NOT EXISTS stocks_heading TEXT NOT NULL DEFAULT '';

-- Seed the values the footer renders today, so applying this migration on its
-- own changes nothing on the page.
UPDATE cms.site_settings
   SET connect_label  = coalesce(nullif(connect_label, ''),  'Connect with us'),
       stocks_heading = coalesce(nullif(stocks_heading, ''), 'Stocks')
 WHERE id;

-- The parameter list grows, which CREATE OR REPLACE cannot do without
-- creating a second overload that an eight-argument call would then be
-- ambiguous between. Dropped and rebuilt instead.
DROP FUNCTION IF EXISTS cms.site_settings_update(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BIGINT, BIGINT);

CREATE OR REPLACE FUNCTION cms.site_settings_update(
  p_brand_name           TEXT,
  p_legal_name           TEXT,
  p_address              TEXT,
  p_phone                TEXT,
  p_email                TEXT,
  p_search_placeholder   TEXT,
  p_logo_media_id        BIGINT DEFAULT NULL,
  p_footer_logo_media_id BIGINT DEFAULT NULL,
  p_connect_label        TEXT   DEFAULT NULL,
  p_stocks_heading       TEXT   DEFAULT NULL
)
RETURNS cms.site_settings
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.site_settings;
BEGIN
  INSERT INTO cms.site_settings (
    id, brand_name, legal_name, address, phone, email, search_placeholder,
    logo_media_id, footer_logo_media_id, connect_label, stocks_heading
  )
  VALUES (
    TRUE, btrim(p_brand_name), btrim(p_legal_name), coalesce(p_address, ''),
    coalesce(p_phone, ''), coalesce(p_email, ''), coalesce(p_search_placeholder, ''),
    p_logo_media_id, p_footer_logo_media_id,
    coalesce(p_connect_label, ''), coalesce(p_stocks_heading, '')
  )
  ON CONFLICT (id) DO UPDATE
     SET brand_name           = EXCLUDED.brand_name,
         legal_name           = EXCLUDED.legal_name,
         address              = EXCLUDED.address,
         phone                = EXCLUDED.phone,
         email                = EXCLUDED.email,
         search_placeholder   = EXCLUDED.search_placeholder,
         logo_media_id        = EXCLUDED.logo_media_id,
         footer_logo_media_id = EXCLUDED.footer_logo_media_id,
         connect_label        = EXCLUDED.connect_label,
         stocks_heading       = EXCLUDED.stocks_heading
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;

-- The public payload carries them too, or the site would still have to
-- hardcode the strings it is now being told.
CREATE OR REPLACE FUNCTION cms.site_settings_json()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
           'brandName',         g.brand_name,
           'legalName',         g.legal_name,
           'address',           g.address,
           'phone',             g.phone,
           'email',             g.email,
           'searchPlaceholder', g.search_placeholder,
           'connectLabel',      g.connect_label,
           'stocksHeading',     g.stocks_heading,
           'logo',              cms.media_json(g.logo_media_id),
           'footerLogo',        cms.media_json(g.footer_logo_media_id)
         )
    FROM cms.site_settings g
   WHERE g.id;
$$;
