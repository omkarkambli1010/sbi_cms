-- ============================================================================
-- 011_payload_merge_fix.sql — one pair of brackets.
--
-- 007 built each section like this:
--
--   v_sections := v_sections || jsonb_build_object(...) || cms.section_items_json(...);
--
-- `||` is left-associative, so that reads as
--
--   (v_sections || shell) || items
--
-- and `jsonb_array || jsonb_object` APPENDS the object as a new element. The
-- shell went in as one entry and the fold's own rows went in as a second,
-- so the home page came back with thirty sections instead of fifteen: every
-- odd entry a shell with no content, every even one content with no key.
--
-- The intent was to merge the two objects and append the result once. Object
-- against object is a merge; array against object is an append. The fix is to
-- make the merge happen first.
-- ============================================================================

SET search_path = cms, public;

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

  /* NULL rather than an empty document: the caller must be able to tell
     "no such page" from "a page with nothing on it". */
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  FOR v_sec IN
    SELECT s.id, s.section_key, s.name, s.display_order
      FROM cms.page_sections s
     WHERE s.page_id = v_page.id AND s.is_active
     ORDER BY s.display_order, s.id
  LOOP
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

  RETURN jsonb_build_object(
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
    'settings', (
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
        FROM cms.site_settings g WHERE g.id
    ),
    'menus',    cms.nav_menus_json(),
    'footer',   cms.footer_json(),
    'sections', v_sections
  );
END;
$$;
