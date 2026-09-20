-- ============================================================================
-- 007_public_payload.sql — the whole home page as one JSONB document.
--
-- 002 shipped a cms.public_page_payload that only knew about the tables 001
-- created (hero, navigation, SEO). Fourteen folds later it returns a fraction
-- of the page, so it is replaced here rather than extended: a partial payload
-- that looks complete is worse than none.
--
-- Why one document rather than a route per fold: the public site renders this
-- page on every cold request. Seventeen round trips would put the database in
-- the critical path seventeen times; one prepared call does not.
--
-- What the caller never sees: inactive rows, banners outside their window,
-- media ids without their URL, and every bookkeeping column (created_at,
-- updated_at, display_order is kept only where the site orders client-side).
-- The API route is therefore a pass-through with no shaping of its own.
--
-- Key style is camelCase, matching the TypeScript that consumes it, so the
-- site maps the payload onto its existing prop names without a translation
-- layer that could silently drop a field.
-- ============================================================================

SET search_path = cms, public;

-- ---------------------------------------------------------------------------
-- media_json — one image, resolved
--
-- Returns NULL (not an empty object) when the column is null or the asset has
-- been deactivated, so a component can test the slot with a single falsy check
-- rather than probing for a url inside an object that is always present.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.media_json(p_id BIGINT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
           'id',     m.id,
           'url',    m.url,
           'alt',    m.alt_text,
           'title',  m.title,
           'width',  m.width,
           'height', m.height
         )
    FROM cms.media_assets m
   WHERE m.id = p_id AND m.is_active;
$$;

-- ---------------------------------------------------------------------------
-- nav_children — one level of a menu, and everything under it
--
-- plpgsql rather than sql because the body recurses: a SQL function cannot
-- reference itself at creation time, while plpgsql resolves the call when it
-- runs. The footer nests two levels today; nothing here assumes that depth.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.nav_children(p_menu_id BIGINT, p_parent_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_items JSONB;
BEGIN
  SELECT coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id',       i.id,
               'label',    i.label,
               'href',     i.href,
               'icon',     cms.media_json(i.icon_media_id),
               'newTab',   i.opens_in_new_tab,
               'children', cms.nav_children(i.menu_id, i.id)
             )
             ORDER BY i.display_order, i.id
           ),
           '[]'::jsonb
         )
    INTO v_items
    FROM cms.navigation_items i
   WHERE i.menu_id = p_menu_id
     AND i.parent_id IS NOT DISTINCT FROM p_parent_id
     AND i.is_active;

  RETURN v_items;
END;
$$;

CREATE OR REPLACE FUNCTION cms.nav_menus_json()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
           jsonb_object_agg(
             m.menu_key,
             jsonb_build_object(
               'name',     m.name,
               'location', m.location,
               'items',    cms.nav_children(m.id, NULL)
             )
           ),
           '{}'::jsonb
         )
    FROM cms.navigation_menus m
   WHERE m.is_active;
$$;

-- ---------------------------------------------------------------------------
-- section_block_json — the shell every fold shares
--
-- Returns an object even when no section_blocks row exists yet, so a fold that
-- has never been edited renders with empty strings rather than crashing on a
-- null. Empty-string defaults come from the table, not from here.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.section_block_json(p_section_id BIGINT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
           (SELECT jsonb_build_object(
                     'eyebrow',            b.eyebrow,
                     'title',              b.title,
                     'titleLines',         to_jsonb(b.title_lines),
                     'subtitle',           b.subtitle,
                     'subtitleMobile',     b.subtitle_mobile,
                     'description',        b.description,
                     'titleBreakAfter',    b.title_break_after,
                     'subtitleBreakAfter', b.subtitle_break_after,
                     'align',              b.align,
                     'tone',               b.tone,
                     'ctaLabel',           b.cta_label,
                     'ctaLabelMobile',     b.cta_label_mobile,
                     'ctaHref',            b.cta_href,
                     'ctaVisible',         b.cta_visible,
                     'secondaryCtaLabel',  b.secondary_cta_label,
                     'secondaryCtaHref',   b.secondary_cta_href,
                     'secondaryCtaVisible', b.secondary_cta_visible,
                     'arrowHref',          b.arrow_href,
                     'arrowLabel',         b.arrow_label,
                     'image',              cms.media_json(b.image_media_id),
                     'imageMobile',        cms.media_json(b.image_mobile_media_id),
                     'background',         cms.media_json(b.background_media_id),
                     'backgroundMobile',   cms.media_json(b.background_mobile_media_id),
                     'backgroundColor',    b.background_color
                   )
              FROM cms.section_blocks b
             WHERE b.section_id = p_section_id),
           '{}'::jsonb
         );
$$;

-- ---------------------------------------------------------------------------
-- tab_items_json — the rows that hang off one tab
--
-- Four folds are tab-driven and each stores a different row type, so the tab
-- key alone is not enough: the section key selects the table. A section that
-- has tabs but no per-tab rows returns an empty object rather than null.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.tab_items_json(p_section_key TEXT, p_tab_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v JSONB := '{}'::jsonb;
BEGIN
  IF p_section_key = 'ipos' THEN
    SELECT jsonb_build_object('items', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',                i.id,
               'name',              i.name,
               'status',            i.status,
               'dateRange',         i.date_range,
               'priceBand',         i.price_band,
               'issueSize',         i.issue_size,
               'minInvestment',     i.min_investment,
               'minInvestmentUnit', i.min_investment_unit,
               'listingNote',       i.listing_note,
               'listingDate',       i.listing_date,
               'closingNote',       i.closing_note,
               'closingDate',       i.closing_date,
               'applyLabel',        i.apply_label,
               'applyHref',         i.apply_href,
               'knowMoreLabel',     i.know_more_label,
               'knowMoreHref',      i.know_more_href
             ) ORDER BY i.display_order, i.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.ipo_items i
     WHERE i.tab_id = p_tab_id AND i.is_active;

  ELSIF p_section_key = 'offerings' THEN
    SELECT jsonb_build_object('cards', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',             c.id,
               'slug',           c.slug,
               'title',          c.title,
               'lede',           c.lede,
               'highlightLead',  c.highlight_lead,
               'highlight',      c.highlight,
               'ctaLabel',       c.cta_label,
               'ctaLabelMobile', c.cta_label_mobile,
               'ctaHref',        c.cta_href,
               'mobileOrder',    c.mobile_order,
               'art',            cms.media_json(c.art_media_id),
               'artMobile',      cms.media_json(c.art_mobile_media_id)
             ) ORDER BY c.display_order, c.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.offering_cards c
     WHERE c.tab_id = p_tab_id AND c.is_active;

  ELSIF p_section_key = 'platform' THEN
    v := jsonb_build_object(
      'steps', coalesce((
        SELECT jsonb_agg(jsonb_build_object('id', s.id, 'title', s.title, 'body', s.body)
                         ORDER BY s.display_order, s.id)
          FROM cms.platform_steps s WHERE s.tab_id = p_tab_id AND s.is_active
      ), '[]'::jsonb),
      'panels', coalesce((
        SELECT jsonb_agg(jsonb_build_object(
                 'id', p.id, 'stepIndex', p.step_index, 'image', cms.media_json(p.media_id))
                 ORDER BY p.display_order, p.step_index, p.id)
          FROM cms.platform_panels p WHERE p.tab_id = p_tab_id AND p.is_active
      ), '[]'::jsonb)
    );

  ELSIF p_section_key = 'research' THEN
    SELECT jsonb_build_object('reports', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',    r.id,
               'title', r.title,
               'kind',  r.kind,
               'date',  r.published_on,
               'href',  r.href,
               'cover', cms.media_json(r.cover_media_id)
             ) ORDER BY r.display_order, r.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.research_reports r
     WHERE r.tab_id = p_tab_id AND r.is_active;

  ELSIF p_section_key = 'learn' THEN
    SELECT jsonb_build_object('lessons', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',        l.id,
               'title',     l.title,
               'duration',  l.duration,
               'date',      l.published_on,
               'href',      l.href,
               'thumbnail', cms.media_json(l.thumbnail_media_id)
             ) ORDER BY l.display_order, l.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.lessons l
     WHERE l.tab_id = p_tab_id AND l.is_active;
  END IF;

  RETURN coalesce(v, '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION cms.section_tabs_json(p_section_id BIGINT, p_section_key TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id',        t.id,
               'key',       t.tab_key,
               'label',     t.label,
               'transition', CASE
                               WHEN t.transition_duration_ms IS NULL AND t.transition_easing IS NULL
                                 THEN NULL
                               ELSE jsonb_build_object(
                                      'durationMs', t.transition_duration_ms,
                                      'easing',     t.transition_easing)
                             END
             ) || cms.tab_items_json(p_section_key, t.id)
             ORDER BY t.display_order, t.id
           ),
           '[]'::jsonb
         )
    FROM cms.section_tabs t
   WHERE t.section_id = p_section_id AND t.is_active;
$$;

-- ---------------------------------------------------------------------------
-- hero_json — the hero fold's own tables
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.hero_json(p_section_id BIGINT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
           'titleLead',      h.title_lead,
           'subtext',        jsonb_build_array(h.subtext_line_1, h.subtext_line_2),
           'watermarkLeft',  h.watermark_left,
           'watermarkRight', h.watermark_right,
           'mockup',         cms.media_json(h.mockup_media_id),
           'form', jsonb_build_object(
             'nameLabel',             h.form_name_label,
             'namePlaceholder',       h.form_name_placeholder,
             'mobileLabel',           h.form_mobile_label,
             'mobilePlaceholder',     h.form_mobile_placeholder,
             'mobileHelp',            h.form_mobile_help,
             'consentLabel',          h.form_consent_label,
             'submitLabel',           h.form_submit_label
           ),
           'formMobile', jsonb_build_object(
             'nameLabel',         h.form_name_label_mobile,
             'namePlaceholder',   h.form_name_placeholder_mobile,
             'mobileLabel',       h.form_mobile_label_mobile,
             'mobilePlaceholder', h.form_mobile_placeholder_mobile
           ),
           'lines', coalesce((
             SELECT jsonb_agg(jsonb_build_array(l.line_1, l.line_2)
                              ORDER BY l.display_order, l.id)
               FROM cms.hero_rotating_lines l
              WHERE l.hero_id = h.id AND l.is_active
           ), '[]'::jsonb),
           'kpis', coalesce((
             SELECT jsonb_agg(jsonb_build_object(
                      'id',    k.id,
                      'key',   k.kpi_key,
                      'kind',  k.kind,
                      'value', k.value,
                      'label', k.label,
                      'icon',  cms.media_json(k.icon_media_id))
                      ORDER BY k.display_order, k.id)
               FROM cms.hero_kpis k
              WHERE k.hero_id = h.id AND k.is_active
           ), '[]'::jsonb)
         )
    FROM cms.hero_sections h
   WHERE h.section_id = p_section_id;
$$;

-- ---------------------------------------------------------------------------
-- section_items_json — the rows a fold owns directly (not through a tab)
--
-- One branch per fold. A fold whose rows all hang off tabs returns an empty
-- object here and carries its content inside `tabs` instead.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.section_items_json(p_section_id BIGINT, p_section_key TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v JSONB := '{}'::jsonb;
BEGIN
  IF p_section_key = 'hero' THEN
    v := jsonb_build_object('hero', cms.hero_json(p_section_id));

  ELSIF p_section_key = 'market-pulse' THEN
    SELECT jsonb_build_object('tickers', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',        t.id,
               'name',      t.name,
               'price',     t.price,
               'change',    t.change,
               'direction', t.direction
             ) ORDER BY t.display_order, t.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.ticker_items t
     WHERE t.section_id = p_section_id AND t.is_active;

  ELSIF p_section_key = 'bento' THEN
    v := jsonb_build_object(
      'cards', coalesce((
        SELECT jsonb_agg(jsonb_build_object(
                 'id',            c.id,
                 'key',           c.card_key,
                 'titleLines',    to_jsonb(c.title_lines),
                 'href',          c.href,
                 'leverageUpto',  c.leverage_upto,
                 'leverageValue', c.leverage_value,
                 'leverageLabel', c.leverage_label,
                 'art',           cms.media_json(c.art_media_id),
                 'artSecondary',  cms.media_json(c.art_secondary_media_id))
                 ORDER BY c.display_order, c.id)
          FROM cms.bento_cards c WHERE c.section_id = p_section_id AND c.is_active
      ), '[]'::jsonb),
      'stats', cms.stats_json(p_section_id)
    );

  ELSIF p_section_key = 'purpose' THEN
    SELECT jsonb_build_object('cards', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',       c.id,
               'slug',     c.slug,
               'title',    c.title,
               'lede',     c.lede,
               'ctaLabel', c.cta_label,
               'ctaHref',  c.cta_href,
               'art',      cms.media_json(c.art_media_id),
               'points',   coalesce((
                 SELECT jsonb_agg(p.text ORDER BY p.display_order, p.id)
                   FROM cms.purpose_card_points p
                  WHERE p.card_id = c.id AND p.is_active
               ), '[]'::jsonb)
             ) ORDER BY c.display_order, c.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.purpose_cards c
     WHERE c.section_id = p_section_id AND c.is_active;

  ELSIF p_section_key = 'news' THEN
    SELECT jsonb_build_object('items', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',        n.id,
               'title',     n.title,
               'timestamp', n.published_label,
               'href',      n.href,
               'isLead',    n.is_lead,
               'image',     cms.media_json(n.image_media_id)
             ) ORDER BY n.is_lead DESC, n.display_order, n.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.news_items n
     WHERE n.section_id = p_section_id AND n.is_active;

  ELSIF p_section_key = 'testimonials' THEN
    SELECT jsonb_build_object('items', coalesce(jsonb_agg(
             jsonb_build_object('id', t.id, 'quote', t.quote, 'author', t.author)
             ORDER BY t.display_order, t.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.testimonials t
     WHERE t.section_id = p_section_id AND t.is_active;

  ELSIF p_section_key = 'pricing' THEN
    SELECT jsonb_build_object('plans', coalesce(jsonb_agg(
             jsonb_build_object(
               'id',        p.id,
               'name',      p.name,
               'price',     p.price,
               'priceNote', p.price_note,
               'accent',    p.accent,
               'ctaLabel',  p.cta_label,
               'ctaHref',   p.cta_href,
               'icon',      cms.media_json(p.icon_media_id),
               'features',  coalesce((
                 SELECT jsonb_agg(f.text ORDER BY f.display_order, f.id)
                   FROM cms.pricing_plan_features f
                  WHERE f.plan_id = p.id AND f.is_active
               ), '[]'::jsonb)
             ) ORDER BY p.display_order, p.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.pricing_plans p
     WHERE p.section_id = p_section_id AND p.is_active;

  ELSIF p_section_key = 'faq' THEN
    SELECT jsonb_build_object('items', coalesce(jsonb_agg(
             jsonb_build_object('id', f.id, 'question', f.question, 'answer', f.answer)
             ORDER BY f.display_order, f.id
           ), '[]'::jsonb))
      INTO v
      FROM cms.faq_items f
     WHERE f.section_id = p_section_id AND f.is_active;

  ELSIF p_section_key = 'app-promo' THEN
    /* Scheduling is applied here, not in the site: a banner outside its window
       must never reach the browser, and "which banner is live" is one rule in
       one place. Lowest display_order wins so a scheduled replacement cannot
       leave the card blank. */
    SELECT jsonb_build_object('banner', (
             SELECT jsonb_build_object(
                      'id',          b.id,
                      'title',       b.title,
                      'description', b.description,
                      'ctaLabel',    b.cta_label,
                      'ctaHref',     b.cta_href,
                      'image',       cms.media_json(b.image_media_id),
                      'imageMobile', cms.media_json(b.image_mobile_media_id)
                    )
               FROM cms.promo_banners b
              WHERE b.section_id = p_section_id
                AND b.is_active
                AND (b.starts_at IS NULL OR b.starts_at <= now())
                AND (b.ends_at   IS NULL OR b.ends_at   >  now())
              ORDER BY b.display_order, b.id
              LIMIT 1
           ))
      INTO v;

  ELSIF p_section_key = 'sticky-nudge' THEN
    SELECT jsonb_build_object('nudge', (
             SELECT jsonb_build_object(
                      'title',             n.title,
                      'mobilePlaceholder', n.mobile_placeholder,
                      'namePlaceholder',   n.name_placeholder,
                      'ctaLabel',          n.cta_label,
                      'ctaHref',           n.cta_href
                    )
               FROM cms.sticky_nudge n
              WHERE n.section_id = p_section_id
           ))
      INTO v;
  END IF;

  RETURN coalesce(v, '{}'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION cms.stats_json(p_section_id BIGINT)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id',          s.id,
               'ownerKey',    s.owner_key,
               'value',       s.value,
               'label',       s.label,
               'labelLines',  to_jsonb(s.label_lines),
               'description', s.description,
               'icon',        cms.media_json(s.icon_media_id)
             ) ORDER BY s.display_order, s.id
           ),
           '[]'::jsonb
         )
    FROM cms.stat_items s
   WHERE s.section_id = p_section_id AND s.is_active;
$$;

-- ---------------------------------------------------------------------------
-- footer_json — the chrome that is not a page section
--
-- Link columns come from navigation_menus, so they are already in nav_menus_json
-- and are not repeated here. What is left is the footer's own content: the
-- legal blocks, the stock index letters and the keyword chips.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cms.footer_json()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
           'legal', coalesce((
             SELECT jsonb_object_agg(l.content_key, l.body)
               FROM cms.legal_content l WHERE l.is_active
           ), '{}'::jsonb),
           'stockLetters', coalesce((
             SELECT jsonb_agg(jsonb_build_object('letter', s.letter, 'href', s.href)
                              ORDER BY s.display_order, s.id)
               FROM cms.stock_index_letters s WHERE s.is_active
           ), '[]'::jsonb),
           'stockLinks', coalesce((
             SELECT jsonb_agg(jsonb_build_object('label', s.label, 'href', s.href)
                              ORDER BY s.display_order, s.id)
               FROM cms.stock_links s WHERE s.is_active
           ), '[]'::jsonb)
         );
$$;

-- ---------------------------------------------------------------------------
-- public_page_payload — the whole thing
-- ---------------------------------------------------------------------------
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
    v_sections := v_sections || jsonb_build_object(
      'key',   v_sec.section_key,
      'name',  v_sec.name,
      'order', v_sec.display_order,
      'block', cms.section_block_json(v_sec.id),
      'tabs',  cms.section_tabs_json(v_sec.id, v_sec.section_key)
    ) || cms.section_items_json(v_sec.id, v_sec.section_key);
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
