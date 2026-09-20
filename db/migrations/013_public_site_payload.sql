-- ============================================================================
-- 013_public_site_payload.sql — the chrome, on its own.
--
-- The header and footer render on every marketing route, not just the home
-- page. They are already inside cms.public_page_payload because that document
-- carries `settings`, `menus` and `footer` alongside the page's sections —
-- but a /blogs page asking for the home page's payload just to find out what
-- the wordmark says would be reading the wrong thing and would couple two
-- unrelated caches together.
--
-- So the chrome gets its own call. The two share every helper, so there is no
-- second definition of what a menu or a media reference looks like: only a
-- second door into the same functions.
-- ============================================================================

SET search_path = cms, public;

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
           'logo',              cms.media_json(g.logo_media_id),
           'footerLogo',        cms.media_json(g.footer_logo_media_id)
         )
    FROM cms.site_settings g
   WHERE g.id;
$$;

CREATE OR REPLACE FUNCTION cms.public_site_payload()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
           'settings', cms.site_settings_json(),
           'menus',    cms.nav_menus_json(),
           'footer',   cms.footer_json()
         );
$$;

-- public_page_payload now builds its settings from the same function, so the
-- header cannot describe the brand one way on the home page and another way
-- on /blogs.
CREATE OR REPLACE FUNCTION cms.public_page_payload(p_page_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_page     cms.pages;
  v_sections JSONB := '[]'::jsonb;
  v_sec      RECORD;
BEGIN
  SELECT * INTO v_page FROM cms.pages WHERE slug = p_page_slug AND is_active;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  FOR v_sec IN
    SELECT s.id, s.section_key, s.name, s.display_order
      FROM cms.page_sections s
     WHERE s.page_id = v_page.id AND s.is_active
     ORDER BY s.display_order, s.id
  LOOP
    /* The brackets matter — see 011. */
    v_sections := v_sections || (
      jsonb_build_object(
        'key',   v_sec.section_key,
        'name',  v_sec.name,
        'order', v_sec.display_order,
        'block', cms.section_block_json(v_sec.id),
        'tabs',  cms.section_tabs_json(v_sec.id, v_sec.section_key)
      )
      || cms.section_items_json(v_sec.id, v_sec.section_key)
    );
  END LOOP;

  RETURN cms.public_site_payload() || jsonb_build_object(
    'page', jsonb_build_object('slug', v_page.slug, 'name', v_page.name, 'route', v_page.route),
    'seo', (
      SELECT jsonb_build_object(
               'title',         s.meta_title,
               'description',   s.meta_description,
               'keywords',      to_jsonb(s.meta_keywords),
               'canonical',     s.canonical_url,
               'ogTitle',       s.og_title,
               'ogDescription', s.og_description,
               'ogImage',       cms.media_json(s.og_image_media_id),
               'robots',        s.robots
             )
        FROM cms.seo_metadata s WHERE s.page_id = v_page.id
    ),
    'sections', v_sections
  );
END;
$$;
