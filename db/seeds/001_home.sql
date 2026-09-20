-- ============================================================================
-- 001_home.sql — seed matching the live marketing site exactly
--
-- Every value here is transcribed from src/constants/sbi-home.ts in the
-- sbisecurities-web repository. That is deliberate: with this seed loaded the
-- public site renders byte-identical to the hardcoded version, so switching it
-- over to the CMS is not supposed to change a single pixel.
--
-- Re-runnable. Content rows are matched on their natural key and updated, so
-- running this twice does not duplicate anything, and running it after an
-- editor has changed copy will put the original text back — which is what a
-- "reset to shipped content" script should do.
-- ============================================================================

SET search_path = cms, public;

BEGIN;

-- ---------------------------------------------------------------------------
-- media
--
-- Paths point at files already served by the marketing site's /public folder.
-- Uploading a replacement through the dashboard writes a new file and repoints
-- the row; nothing here assumes the CMS owns the bytes.
-- ---------------------------------------------------------------------------
SELECT cms.media_create('/figma/header/logo-main.svg', 'logo-main.svg', 'image/svg+xml',
                        'SBI Securities', 'Header logo', NULL, 175, 42, 'brand');
SELECT cms.media_create('/figma/footer/logo-a.svg', 'logo-a.svg', 'image/svg+xml',
                        'SBI Securities', 'Footer logo', NULL, 147, 35, 'brand');
SELECT cms.media_create('/figma/hero/mockup.png', 'mockup.png', 'image/png',
                        '', 'Hero phone mockup', NULL, 414, 560, 'hero');
SELECT cms.media_create('/figma/hero/star.svg', 'star.svg', 'image/svg+xml',
                        '', 'Rating star', NULL, 26, 26, 'hero');
SELECT cms.media_create('/figma/hero/backed-by-sbi.png', 'backed-by-sbi.png', 'image/png',
                        'Backed by SBI', 'Backed by SBI lockup', NULL, 94, 28, 'hero');
SELECT cms.media_create('/figma/footer/social-1.svg', 'social-1.svg', 'image/svg+xml',
                        'Instagram', NULL, NULL, 24, 24, 'social');
SELECT cms.media_create('/figma/footer/social-2.svg', 'social-2.svg', 'image/svg+xml',
                        'X', NULL, NULL, 24, 24, 'social');
SELECT cms.media_create('/figma/footer/social-3.svg', 'social-3.svg', 'image/svg+xml',
                        'Facebook', NULL, NULL, 24, 24, 'social');
SELECT cms.media_create('/figma/footer/social-4.svg', 'social-4.svg', 'image/svg+xml',
                        'LinkedIn', NULL, NULL, 24, 24, 'social');
SELECT cms.media_create('/figma/footer/social-5.svg', 'social-5.svg', 'image/svg+xml',
                        'YouTube', NULL, NULL, 24, 24, 'social');

-- ---------------------------------------------------------------------------
-- site settings (BRAND + SEARCH_PLACEHOLDER)
-- ---------------------------------------------------------------------------
SELECT cms.site_settings_update(
  'SBI Securities',
  'SBICAP Securities Limited',
  'Marathon Futurex, B-wing, 12th Floor, Lower Parel East, Mumbai – 400013',
  '022 6854 5555 / 022 4001 4155',
  'helpdesk@sbicapsec.com',
  'Search for Stocks, F&O, MF and More',
  (SELECT id FROM cms.media_assets WHERE url = '/figma/header/logo-main.svg'),
  (SELECT id FROM cms.media_assets WHERE url = '/figma/footer/logo-a.svg')
);

-- ---------------------------------------------------------------------------
-- page + sections
--
-- One row per fold the home route renders, in the order HomeComponent renders
-- them. The later folds have no content tables yet; their rows exist so the
-- dashboard can already list, reorder and switch them off, and so the next
-- migration only has to add the detail table.
-- ---------------------------------------------------------------------------
INSERT INTO cms.pages (slug, name, route)
VALUES ('home', 'Home page', '/')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, route = EXCLUDED.route;

INSERT INTO cms.page_sections (page_id, section_key, name, display_order)
SELECT p.id, v.section_key, v.name, v.display_order
  FROM cms.pages p,
       (VALUES
         ('hero',         'Hero / banner',            1),
         ('market-pulse', 'Market pulse ticker',      2),
         ('bento',        'Explore our world',        3),
         ('ipos',         'IPOs',                     4),
         ('offerings',    'Fund It, Protect It',      5),
         ('purpose',      'Invest with a purpose',    6),
         ('platform',     'Next-gen platform',        7),
         ('research',     'Analysis you can trust',   8),
         ('news',         'Daily market digest',      9),
         ('learn',        'Learn before you invest', 10),
         ('testimonials', 'Testimonials',            11),
         ('pricing',      'Pricing plans',           12),
         ('faq',          'FAQ',                     13),
         ('app-promo',    'App download promo',      14),
         ('sticky-nudge', 'Sticky bottom nudge',     15)
       ) AS v(section_key, name, display_order)
 WHERE p.slug = 'home'
ON CONFLICT (page_id, section_key) DO UPDATE
   SET name = EXCLUDED.name, display_order = EXCLUDED.display_order;

-- ---------------------------------------------------------------------------
-- SEO — taken from the marketing site's existing route metadata
-- ---------------------------------------------------------------------------
SELECT cms.seo_upsert(
  'home',
  'Online Trading and Investment Services | SBI Securities',
  'Open a free Demat account with SBI Securities. Trade equity, IPOs, derivatives, mutual funds and more, backed by the trust of SBI.',
  ARRAY['demat account', 'online trading', 'share market', 'IPO', 'mutual funds',
        'SBI Securities', 'stock broker india'],
  'https://www.sbisecurities.in/',
  NULL,
  NULL,
  (SELECT id FROM cms.media_assets WHERE url = '/figma/hero/backed-by-sbi.png'),
  'index,follow'
);

-- ---------------------------------------------------------------------------
-- navigation menus
-- ---------------------------------------------------------------------------
INSERT INTO cms.navigation_menus (menu_key, name, location) VALUES
  ('header-primary', 'Header navigation', 'header'),
  ('social',         'Social links',      'social')
ON CONFLICT (menu_key) DO UPDATE SET name = EXCLUDED.name, location = EXCLUDED.location;

-- TOP_NAV
INSERT INTO cms.navigation_items (menu_id, label, href, display_order)
SELECT m.id, v.label, v.href, v.display_order
  FROM cms.navigation_menus m,
       (VALUES
         ('Trade & Invest',      '#trade-and-invest',    1),
         ('Loans and Insurance', '#loans-and-insurance', 2),
         ('Research',            '#research',            3),
         ('Investor Awareness',  '#investor-awareness',  4),
         ('More',                '#more',                5)
       ) AS v(label, href, display_order)
 WHERE m.menu_key = 'header-primary'
   -- No natural key on nav items, so the guard is the label within the menu.
   AND NOT EXISTS (
     SELECT 1 FROM cms.navigation_items i
      WHERE i.menu_id = m.id AND i.label = v.label
   );

-- SOCIALS (from Footer.tsx)
INSERT INTO cms.navigation_items (menu_id, label, href, icon_media_id, opens_in_new_tab, display_order)
SELECT m.id, v.label, v.href,
       (SELECT id FROM cms.media_assets WHERE url = v.icon_url),
       TRUE, v.display_order
  FROM cms.navigation_menus m,
       (VALUES
         ('Instagram', 'https://www.instagram.com/', '/figma/footer/social-1.svg', 1),
         ('X',         'https://x.com/',             '/figma/footer/social-2.svg', 2),
         ('Facebook',  'https://www.facebook.com/',  '/figma/footer/social-3.svg', 3),
         ('LinkedIn',  'https://www.linkedin.com/',  '/figma/footer/social-4.svg', 4),
         ('YouTube',   'https://www.youtube.com/',   '/figma/footer/social-5.svg', 5)
       ) AS v(label, href, icon_url, display_order)
 WHERE m.menu_key = 'social'
   AND NOT EXISTS (
     SELECT 1 FROM cms.navigation_items i
      WHERE i.menu_id = m.id AND i.label = v.label
   );

-- ---------------------------------------------------------------------------
-- hero (HERO)
-- ---------------------------------------------------------------------------
INSERT INTO cms.hero_sections (
  section_id, title_lead, subtext_line_1, subtext_line_2,
  watermark_left, watermark_right, mockup_media_id,
  form_name_label, form_name_placeholder,
  form_mobile_label, form_mobile_placeholder, form_mobile_help,
  form_consent_label, form_submit_label,
  form_name_label_mobile, form_name_placeholder_mobile,
  form_mobile_label_mobile, form_mobile_placeholder_mobile
)
SELECT s.id,
       'Smart Investing with',
       'SBI Securities empowers every investor.',
       'From first SIP to full portfolio.',
       'TRADE', 'INVEST',
       (SELECT id FROM cms.media_assets WHERE url = '/figma/hero/mockup.png'),
       'Enter Full Name', 'Enter your full name',
       'Enter Mobile no.', 'Enter your mobile number',
       'You will receive an OTP on the mobile number',
       'I agree to terms and conditions', 'Get Started',
       'Enter Full name', 'Enter your Full name',
       'Mobile Number', 'Enter your 10 digit mobile number'
  FROM cms.page_sections s
  JOIN cms.pages p ON p.id = s.page_id
 WHERE p.slug = 'home' AND s.section_key = 'hero'
ON CONFLICT (section_id) DO UPDATE
   SET title_lead                     = EXCLUDED.title_lead,
       subtext_line_1                 = EXCLUDED.subtext_line_1,
       subtext_line_2                 = EXCLUDED.subtext_line_2,
       watermark_left                 = EXCLUDED.watermark_left,
       watermark_right                = EXCLUDED.watermark_right,
       mockup_media_id                = EXCLUDED.mockup_media_id,
       form_name_label                = EXCLUDED.form_name_label,
       form_name_placeholder          = EXCLUDED.form_name_placeholder,
       form_mobile_label              = EXCLUDED.form_mobile_label,
       form_mobile_placeholder        = EXCLUDED.form_mobile_placeholder,
       form_mobile_help               = EXCLUDED.form_mobile_help,
       form_consent_label             = EXCLUDED.form_consent_label,
       form_submit_label              = EXCLUDED.form_submit_label,
       form_name_label_mobile         = EXCLUDED.form_name_label_mobile,
       form_name_placeholder_mobile   = EXCLUDED.form_name_placeholder_mobile,
       form_mobile_label_mobile       = EXCLUDED.form_mobile_label_mobile,
       form_mobile_placeholder_mobile = EXCLUDED.form_mobile_placeholder_mobile;

-- rotating headline
INSERT INTO cms.hero_rotating_lines (hero_id, line_1, line_2, display_order)
SELECT h.id, v.line_1, v.line_2, v.display_order
  FROM cms.hero_sections h,
       (VALUES
         ('Free Intraday',       'Trading*',        1),
         ('0% Interest on MTF',  'for 23 days',     2),
         ('₹20/order for carry', 'forward trades',  3)
       ) AS v(line_1, line_2, display_order)
 WHERE NOT EXISTS (
   SELECT 1 FROM cms.hero_rotating_lines l
    WHERE l.hero_id = h.id AND l.line_1 = v.line_1
 );

-- KPI tiles
INSERT INTO cms.hero_kpis (hero_id, kpi_key, kind, value, label, icon_media_id, display_order)
SELECT h.id, v.kpi_key, v.kind, v.value, v.label,
       (SELECT id FROM cms.media_assets WHERE url = v.icon_url),
       v.display_order
  FROM cms.hero_sections h,
       (VALUES
         ('downloads', 'value',  '5M+', 'Downloads',          NULL,                             1),
         ('rating',    'rating', '4.4', 'Ratings on Android', '/figma/hero/star.svg',           2),
         ('backing',   'logo',   NULL,  'Backed by SBI',      '/figma/hero/backed-by-sbi.png',  3)
       ) AS v(kpi_key, kind, value, label, icon_url, display_order)
ON CONFLICT (hero_id, kpi_key) DO UPDATE
   SET kind          = EXCLUDED.kind,
       value         = EXCLUDED.value,
       label         = EXCLUDED.label,
       icon_media_id = EXCLUDED.icon_media_id,
       display_order = EXCLUDED.display_order;

COMMIT;

\echo 'Seed complete.'
