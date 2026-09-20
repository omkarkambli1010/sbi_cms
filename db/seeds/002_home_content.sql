-- ============================================================================
-- 002_home_content.sql — GENERATED. Do not edit by hand.
--
--   node scripts/generate-seed.mjs
--
-- Every string below is read from the marketing site's own source:
--   src/constants/sbi-home.ts, plus the section headings and href rules
-- that live in the components. Regenerating after a copy change keeps the
-- two in step; editing this file by hand does not.
--
-- Re-runnable. Content a fold owns is replaced wholesale rather than merged,
-- so running this again is "put the shipped copy back" — which is what the
-- seed is for. Media rows are upserted by URL instead, because an editor's
-- uploads live in the same table and must survive.
-- ============================================================================

SET search_path = cms, public;

BEGIN;

-- --------------------------------------------------------------------------
-- media — artwork the dashboard can swap; glyphs stay in the components
-- --------------------------------------------------------------------------
SELECT cms.media_create('/figma/header/logo-mark.svg', 'logo-mark.svg', 'image/svg+xml', 'SBI Securities registered mark', NULL, NULL, NULL, NULL, 'brand');
SELECT cms.media_create('/figma/footer/logo-b.svg', 'logo-b.svg', 'image/svg+xml', 'SBI Securities', NULL, NULL, NULL, NULL, 'brand');
SELECT cms.media_create('/figma/footer/phone.png', 'phone.png', 'image/png', '', NULL, NULL, NULL, NULL, 'app-promo');
SELECT cms.media_create('/figma/market-pulse/bull-bear.svg', 'bull-bear.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'market-pulse');
SELECT cms.media_create('/figma/bento/margin-scale.png', 'margin-scale.png', 'image/png', '', NULL, NULL, NULL, NULL, 'bento');
SELECT cms.media_create('/figma/bento/nri-globe.png', 'nri-globe.png', 'image/png', '', NULL, NULL, NULL, NULL, 'bento');
SELECT cms.media_create('/figma/bento/nri-phone.png', 'nri-phone.png', 'image/png', '', NULL, NULL, NULL, NULL, 'bento');
SELECT cms.media_create('/figma/bento/support-india.png', 'support-india.png', 'image/png', '', NULL, NULL, NULL, NULL, 'bento');
SELECT cms.media_create('/figma/bento/baskets-chart.png', 'baskets-chart.png', 'image/png', '', NULL, NULL, NULL, NULL, 'bento');
SELECT cms.media_create('/figma/bento/baskets-phone.png', 'baskets-phone.png', 'image/png', '', NULL, NULL, NULL, NULL, 'bento');
SELECT cms.media_create('/figma/offerings/home-loan.svg', 'home-loan.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/education-loan.svg', 'education-loan.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/car-loan.svg', 'car-loan.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/mobile/home-loan.svg', 'home-loan.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/mobile/education-loan.svg', 'education-loan.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/mobile/car-loan.svg', 'car-loan.svg', 'image/svg+xml', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/life-insurance.png', 'life-insurance.png', 'image/png', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/health-insurance.png', 'health-insurance.png', 'image/png', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/offerings/term-insurance.png', 'term-insurance.png', 'image/png', '', NULL, NULL, NULL, NULL, 'offerings');
SELECT cms.media_create('/figma/purpose/retirement.png', 'retirement.png', 'image/png', '', NULL, NULL, NULL, NULL, 'purpose');
SELECT cms.media_create('/figma/purpose/wealth.png', 'wealth.png', 'image/png', '', NULL, NULL, NULL, NULL, 'purpose');
SELECT cms.media_create('/figma/purpose/education.png', 'education.png', 'image/png', '', NULL, NULL, NULL, NULL, 'purpose');
SELECT cms.media_create('/figma/purpose/home.png', 'home.png', 'image/png', '', NULL, NULL, NULL, NULL, 'purpose');
SELECT cms.media_create('/figma/platform/app-panel.png', 'app-panel.png', 'image/png', '', NULL, NULL, NULL, NULL, 'platform');
SELECT cms.media_create('/figma/platform/terminal-panel.png', 'terminal-panel.png', 'image/png', '', NULL, NULL, NULL, NULL, 'platform');
SELECT cms.media_create('/figma/research/report-1.png', 'report-1.png', 'image/png', '', NULL, NULL, NULL, NULL, 'research');
SELECT cms.media_create('/figma/research/report-2.png', 'report-2.png', 'image/png', '', NULL, NULL, NULL, NULL, 'research');
SELECT cms.media_create('/figma/research/report-3.png', 'report-3.png', 'image/png', '', NULL, NULL, NULL, NULL, 'research');
SELECT cms.media_create('/figma/research/report-4.png', 'report-4.png', 'image/png', '', NULL, NULL, NULL, NULL, 'research');
SELECT cms.media_create('/figma/news/lead.png', 'lead.png', 'image/png', '', NULL, NULL, NULL, NULL, 'news');
SELECT cms.media_create('/figma/news/item-1.png', 'item-1.png', 'image/png', '', NULL, NULL, NULL, NULL, 'news');
SELECT cms.media_create('/figma/news/item-2.png', 'item-2.png', 'image/png', '', NULL, NULL, NULL, NULL, 'news');
SELECT cms.media_create('/figma/news/item-3.png', 'item-3.png', 'image/png', '', NULL, NULL, NULL, NULL, 'news');
SELECT cms.media_create('/figma/learn/lesson-1.png', 'lesson-1.png', 'image/png', '', NULL, NULL, NULL, NULL, 'learn');
SELECT cms.media_create('/figma/learn/lesson-2.png', 'lesson-2.png', 'image/png', '', NULL, NULL, NULL, NULL, 'learn');
SELECT cms.media_create('/figma/learn/lesson-3.png', 'lesson-3.png', 'image/png', '', NULL, NULL, NULL, NULL, 'learn');
SELECT cms.media_create('/figma/learn/lesson-4.png', 'lesson-4.png', 'image/png', '', NULL, NULL, NULL, NULL, 'learn');
SELECT cms.media_create('/figma/pricing/suvidha.png', 'suvidha.png', 'image/png', '', NULL, NULL, NULL, NULL, 'pricing');
SELECT cms.media_create('/figma/pricing/prozero.png', 'prozero.png', 'image/png', '', NULL, NULL, NULL, NULL, 'pricing');
SELECT cms.media_create('/figma/pricing/women.png', 'women.png', 'image/png', '', NULL, NULL, NULL, NULL, 'pricing');
SELECT cms.media_create('/figma/sticky/thea.png', 'thea.png', 'image/png', '', NULL, NULL, NULL, NULL, 'sticky-nudge');

-- --------------------------------------------------------------------------
-- site settings — BRAND, SEARCH_PLACEHOLDER
-- --------------------------------------------------------------------------
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

-- --------------------------------------------------------------------------
-- footer navigation — FOOTER_PRIMARY, FOOTER_SECONDARY, Help & Support
-- --------------------------------------------------------------------------
-- One menu per rendered column, so the five-column band survives a reorder
-- in the dashboard. Group headings are the top-level items; their links are
-- children, which is the nesting navigation_items already supports.

INSERT INTO cms.navigation_menus (menu_key, name, location) VALUES
  ('footer-primary', 'Footer — primary columns', 'footer'),
  ('footer-col-1', 'Footer — column 1', 'footer'),
  ('footer-col-2', 'Footer — column 2', 'footer'),
  ('footer-col-3', 'Footer — column 3', 'footer'),
  ('footer-col-4', 'Footer — column 4', 'footer'),
  ('footer-col-5', 'Footer — column 5', 'footer'),
  ('footer-utility', 'Footer — utility', 'footer')
ON CONFLICT (menu_key) DO UPDATE SET name = EXCLUDED.name, location = EXCLUDED.location;

DELETE FROM cms.navigation_items
 WHERE menu_id IN (SELECT id FROM cms.navigation_menus
                    WHERE menu_key IN ('footer-primary', 'footer-col-1', 'footer-col-2', 'footer-col-3', 'footer-col-4', 'footer-col-5', 'footer-utility'));

DO $seed$
DECLARE
  v_group BIGINT;
BEGIN
  v_group := (cms.nav_item_create('footer-primary', 'TRADE & INVEST', '#')).id;
  PERFORM cms.nav_item_create('footer-primary', 'Equity', '/equity', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'IPO', '/ipo', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Derivative', '/derivative', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Margin Trading Facility', '/margin-trading-facility', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Equity SIP', '/equity-sip', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'ETF', '/etf', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Corporate FDs', '/corporate-fds', v_group);
  PERFORM cms.nav_item_create('footer-primary', '54EC Bonds', '/cgs-bond', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Mutual Fund', '/mutual-fund', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'NPS', '/nps', v_group);
  v_group := (cms.nav_item_create('footer-primary', 'OPEN DEMAT ACCOUNT', '#')).id;
  PERFORM cms.nav_item_create('footer-primary', 'Open Demat Account', '/open-account', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'NRI Demat Account', '/nri-demat-account', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Corporate Demat Account', '/corporate-demat-account', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Women''s Demat Account', '/women-s-demat-account', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Brokerage Plans', '/brokerage-plans', v_group);
  PERFORM cms.nav_item_create('footer-primary', 'Account Opening Process', '/account-opening-process', v_group);
  v_group := (cms.nav_item_create('footer-col-1', 'CALCULATORS', '#')).id;
  PERFORM cms.nav_item_create('footer-col-1', 'MF Returns Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'SIP Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'Lumpsum Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'Step-up SIP Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'SWP Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'FD Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'NPS Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'Home Loan EMI Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'Car Loan EMI Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'CAGR Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'Loan EMI Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'RD Calculator', '/calculators', v_group);
  PERFORM cms.nav_item_create('footer-col-1', 'Retirement Calculator', '/calculators', v_group);
  v_group := (cms.nav_item_create('footer-col-2', 'MARKETS', '#')).id;
  PERFORM cms.nav_item_create('footer-col-2', 'Nifty 50', '/markets/nifty-50', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Sensex', '/markets/sensex', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Bank Nifty', '/markets/bank-nifty', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'FinNifty', '/markets/finnifty', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Midcap', '/markets/midcap', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Smallcap', '/markets/smallcap', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Gift Nifty', '/markets/gift-nifty', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Global Markets', '/markets/global-markets', v_group);
  v_group := (cms.nav_item_create('footer-col-2', 'LOANS', '#')).id;
  PERFORM cms.nav_item_create('footer-col-2', 'Home Loan', '/loans/home-loan', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Car Loan', '/loans/car-loan', v_group);
  PERFORM cms.nav_item_create('footer-col-2', 'Education Loan', '/loans/education-loan', v_group);
  v_group := (cms.nav_item_create('footer-col-3', 'LEARNING CENTRE', '#')).id;
  PERFORM cms.nav_item_create('footer-col-3', 'Investor Awareness Program', '/investor-awareness-program', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'Blogs', '/blogs', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'News', '/news', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'Research Reports', '/research-reports', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'Holiday Calendar', '/holiday-calendar', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'Downloads', '/downloads', v_group);
  v_group := (cms.nav_item_create('footer-col-3', 'INSURANCES', '#')).id;
  PERFORM cms.nav_item_create('footer-col-3', 'Home Loan', '/insurance/home-loan', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'Car Loan', '/insurance/car-loan', v_group);
  PERFORM cms.nav_item_create('footer-col-3', 'Education Loan', '/insurance/education-loan', v_group);
  v_group := (cms.nav_item_create('footer-col-4', 'SUPPORT & COMPANY', '#')).id;
  PERFORM cms.nav_item_create('footer-col-4', 'About us', '/about-us', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Contact us', '/contact-us', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Careers', '/careers', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'In the Media', '/in-the-media', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Branch Locator', '/branch-locator', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'CSR', '/csr', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Security tips', '/security-tips', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Disclaimer', '/disclaimer', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Privacy Policy', '/privacy-policy', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Cookies Policy', '/cookies-policy', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'DND Policy', '/dnd-policy', v_group);
  PERFORM cms.nav_item_create('footer-col-4', 'Terms & Conditions', '/terms-and-conditions', v_group);
  v_group := (cms.nav_item_create('footer-col-5', 'USEFUL LINKS', '#')).id;
  PERFORM cms.nav_item_create('footer-col-5', 'Budget 2026', '/budget-2026', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'SBI Realty', '/sso-realty', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Recovery Module', '/recovery-module', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Block Online Access', '/block-online-access', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Request for Proposal', '/request-for-proposal', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Disclosures', '/disclosures', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Announcements', '/announcements', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Investor Charter', '/investor-charter', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'Investor Awareness', '/investor-awareness', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'SCORES', '/scores', v_group);
  PERFORM cms.nav_item_create('footer-col-5', 'ODR Portal', '/odr-portal', v_group);
  PERFORM cms.nav_item_create('footer-utility', 'Help & Support', '/support');
END
$seed$;

-- --------------------------------------------------------------------------
-- section shells — the title / subtitle / CTA every fold shares
-- --------------------------------------------------------------------------

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'market-pulse',
  p_title               => 'Market Pulse',
  p_arrow_href          => '#markets',
  p_arrow_label         => 'All markets'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'bento',
  p_title               => 'Explore our world',
  p_subtitle            => 'Built for traders and investors',
  p_subtitle_mobile     => 'Services built for traders and investors'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'ipos',
  p_title               => 'IPOs',
  p_arrow_href          => '#ipos',
  p_arrow_label         => 'All IPOs'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'offerings',
  p_title               => 'Fund It, Protect It',
  p_subtitle            => 'Financial solutions for more than just investing',
  p_subtitle_break_after => 5,
  p_arrow_href          => '#offerings',
  p_arrow_label         => 'All loans and insurance'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'purpose',
  p_title               => 'Invest with a purpose',
  p_subtitle            => 'SBI Securities helps you build a plan and the wealth to match it.',
  p_title_break_after   => 2,
  p_subtitle_break_after => 7,
  p_arrow_href          => '#goals',
  p_arrow_label         => 'All investment goals'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'platform',
  p_title               => 'Next-gen Investment Platform',
  p_subtitle            => 'Trade, invest, and grow — all in one place.',
  p_title_break_after   => 1,
  p_subtitle_break_after => 7
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'research',
  p_title               => 'Analysis you can trust',
  p_title_break_after   => 2,
  p_arrow_href          => '#research-reports',
  p_arrow_label         => 'All research reports'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'news',
  p_title               => 'Your Daily Market Digest',
  p_subtitle            => 'Stay on top of the markets',
  p_title_break_after   => 2,
  p_arrow_href          => '#news',
  p_arrow_label         => 'All market news'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'learn',
  p_title               => 'Learn before you invest',
  p_title_break_after   => 2
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'testimonials',
  p_title               => 'Testimonials'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'pricing',
  p_title               => 'Pricing Plans',
  p_arrow_href          => '#pricing',
  p_arrow_label         => 'All pricing plans'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'faq',
  p_title               => 'Frequently Asked Questions',
  p_title_break_after   => 2,
  p_cta_label           => 'View All FAQs',
  p_cta_href            => '#faqs'
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'app-promo',
  p_title               => 'Stop Scrolling, Start investing!',
  p_title_break_after   => 2
);

SELECT cms.section_block_update(
  p_page_slug           => 'home',
  p_section_key         => 'sticky-nudge',
  p_title               => 'Smart investing starts here'
);

-- --------------------------------------------------------------------------
-- market pulse — MARKET_PULSE
-- --------------------------------------------------------------------------
DELETE FROM cms.ticker_items WHERE section_id = cms.section_id_for('home', 'market-pulse');
SELECT cms.ticker_create(cms.section_id_for('home', 'market-pulse'), 'NIFTY 50', '24,456.90', '30.00 %', 'up', 1);
SELECT cms.ticker_create(cms.section_id_for('home', 'market-pulse'), 'NIFTY BANK', '56,755.60', '0.58%', 'down', 2);
SELECT cms.ticker_create(cms.section_id_for('home', 'market-pulse'), 'BSE Sensex', '24,456.90', '28.00 %', 'up', 3);
SELECT cms.ticker_create(cms.section_id_for('home', 'market-pulse'), 'GIFT NIFTY', '56,755.60', '1.58%', 'down', 4);

-- --------------------------------------------------------------------------
-- explore our world — BENTO
-- --------------------------------------------------------------------------
-- BENTO.marginTrading.deposit and .buyingPower are not stored: that copy is
-- baked into margin-scale.png and nothing renders the constants (design §9).
DELETE FROM cms.bento_cards WHERE section_id = cms.section_id_for('home', 'bento');
DELETE FROM cms.stat_items  WHERE section_id = cms.section_id_for('home', 'bento');
SELECT cms.bento_card_create(cms.section_id_for('home', 'bento'), 'margin-trading', ARRAY['Margin trading at 0%', 'for 23 trading days'], NULL,
  'Upto', '4x', 'Leverage',
  (SELECT id FROM cms.media_assets WHERE url = '/figma/bento/margin-scale.png'), NULL, 1);
SELECT cms.bento_card_create(cms.section_id_for('home', 'bento'), 'nri', ARRAY['NRI Demat Account', 'Investing without', 'boundaries'], NULL,
  NULL, NULL, NULL,
  (SELECT id FROM cms.media_assets WHERE url = '/figma/bento/nri-globe.png'), (SELECT id FROM cms.media_assets WHERE url = '/figma/bento/nri-phone.png'), 2);
SELECT cms.bento_card_create(cms.section_id_for('home', 'bento'), 'support', ARRAY['Get instant support', 'In-person or online,', 'your choice'], NULL,
  NULL, NULL, NULL,
  (SELECT id FROM cms.media_assets WHERE url = '/figma/bento/support-india.png'), NULL, 3);
SELECT cms.bento_card_create(cms.section_id_for('home', 'bento'), 'baskets', ARRAY['Introducing research', 'backed MTF Baskets'], NULL,
  NULL, NULL, NULL,
  (SELECT id FROM cms.media_assets WHERE url = '/figma/bento/baskets-chart.png'), (SELECT id FROM cms.media_assets WHERE url = '/figma/bento/baskets-phone.png'), 4);
SELECT cms.stat_create(cms.section_id_for('home', 'bento'), '20+', 'Virtual Branches',
  ARRAY['Virtual', 'Branches'], '', NULL, 'support', 1);
SELECT cms.stat_create(cms.section_id_for('home', 'bento'), '130+', 'Physical Branches',
  ARRAY['Physical', 'Branches'], '', NULL, 'support', 2);

-- --------------------------------------------------------------------------
-- IPOs — IPO_TABS, IPOS
-- --------------------------------------------------------------------------
-- Deleting the tabs cascades to their items, so a rerun cannot leave last
-- run's rows orphaned under a renamed tab.
DELETE FROM cms.section_tabs WHERE section_id = cms.section_id_for('home', 'ipos');
DO $seed$
DECLARE v_tab BIGINT;
BEGIN
  v_tab := (cms.tab_create(cms.section_id_for('home', 'ipos'), 'open-ipos', 'Open IPOs', NULL, NULL, 1)).id;
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 1);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 2);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 3);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 4);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 5);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 6);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'ipos'), 'upcoming-ipos', 'Upcoming IPOs', NULL, NULL, 2)).id;
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 1);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 2);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 3);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 4);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 5);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 6);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'ipos'), 'listed-ipos', 'Listed IPOs', NULL, NULL, 3)).id;
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 1);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 2);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 3);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 4);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 5);
  PERFORM cms.ipo_create(v_tab, 'Metallic Technoforge Ltd.', 'Open',
    '21-26 July 2026', '₹72 - ₹77', '167cr',
    '13,800', '/100 Shares',
    'This IPO will list on', '28 July 2026',
    'Application closes on', '26 July 2026',
    'Apply', 'Know More', NULL, NULL, 6);
END
$seed$;

-- --------------------------------------------------------------------------
-- fund it, protect it — OFFERINGS_TABS, LOANS, INSURANCE
-- --------------------------------------------------------------------------
DELETE FROM cms.section_tabs WHERE section_id = cms.section_id_for('home', 'offerings');
DO $seed$
DECLARE v_tab BIGINT;
BEGIN
  v_tab := (cms.tab_create(cms.section_id_for('home', 'offerings'), 'loans', 'Loans', NULL, NULL, 1)).id;
  PERFORM cms.offering_create(v_tab, 'home-loan', 'Home Loan',
    'Turn your dream home into reality.', 'Interest starts from ', '7.25% p.a.',
    'Get Started', 'Explore', NULL, 2,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/home-loan.svg'), (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/mobile/home-loan.svg'), 1);
  PERFORM cms.offering_create(v_tab, 'education-loan', 'Education Loan',
    'Because your ambitions shouldn''t wait.', 'Study in ', 'India and abroad.',
    'Get Started', 'Explore', NULL, 1,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/education-loan.svg'), (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/mobile/education-loan.svg'), 2);
  PERFORM cms.offering_create(v_tab, 'car-loan', 'Car Loan',
    'Drive home your dream car.', 'Up to ', '100% financing.',
    'Get Started', 'Explore', NULL, 3,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/car-loan.svg'), (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/mobile/car-loan.svg'), 3);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'offerings'), 'insurance', 'Insurance', NULL, NULL, 2)).id;
  PERFORM cms.offering_create(v_tab, 'life-insurance', 'Life Insurance',
    'Protect what matters most.', '', 'Cover your family''s future.',
    'Get Started', 'Explore', NULL, 1,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/life-insurance.png'), NULL, 1);
  PERFORM cms.offering_create(v_tab, 'health-insurance', 'Health Insurance',
    'Care without the cost worry.', '', 'Cashless hospital network.',
    'Get Started', 'Explore', NULL, 2,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/health-insurance.png'), NULL, 2);
  PERFORM cms.offering_create(v_tab, 'term-insurance', 'Term Insurance',
    'High cover, low premium.', '', 'Secure them for the long run.',
    'Get Started', 'Explore', NULL, 3,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/offerings/term-insurance.png'), NULL, 3);
END
$seed$;

-- --------------------------------------------------------------------------
-- invest with a purpose — PURPOSE
-- --------------------------------------------------------------------------
-- Artwork is derived from the slug today (`/figma/purpose/${slug}.png`).
-- Each card gets an explicit reference instead, so an editor can swap one
-- image without renaming a file. The files pointed at are the same ones.
DELETE FROM cms.purpose_cards WHERE section_id = cms.section_id_for('home', 'purpose');
DO $seed$
DECLARE v_card BIGINT;
BEGIN
  v_card := (cms.purpose_card_create(cms.section_id_for('home', 'purpose'), 'retirement',
    'Retirement planning', 'Start early, retire rich.', 'Plan My Retirement', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/purpose/retirement.png'), 1)).id;
  PERFORM cms.purpose_point_create(v_card, 'Systematic retirement investment plans', 1);
  PERFORM cms.purpose_point_create(v_card, 'Tax-efficient wealth accumulation', 2);
  v_card := (cms.purpose_card_create(cms.section_id_for('home', 'purpose'), 'wealth',
    'Wealth creation', 'Grow your money with a disciplined strategy', 'Explore Strategy', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/purpose/wealth.png'), 2)).id;
  PERFORM cms.purpose_point_create(v_card, 'Equity, mutual funds, and more', 1);
  PERFORM cms.purpose_point_create(v_card, 'Expert-curated portfolios', 2);
  v_card := (cms.purpose_card_create(cms.section_id_for('home', 'purpose'), 'education',
    'Fund your education', 'Give your child the best education', 'Start SIP', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/purpose/education.png'), 3)).id;
  PERFORM cms.purpose_point_create(v_card, 'Start a SIP as low as ₹500/month', 1);
  PERFORM cms.purpose_point_create(v_card, 'Goal-based investment tracker', 2);
  v_card := (cms.purpose_card_create(cms.section_id_for('home', 'purpose'), 'home',
    'Buy a home', 'Your dream home is closer than you think', 'Get Started', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/purpose/home.png'), 4)).id;
  PERFORM cms.purpose_point_create(v_card, 'Tailored savings and investment mix', 1);
  PERFORM cms.purpose_point_create(v_card, 'Home loan guidance included', 2);
END
$seed$;

-- --------------------------------------------------------------------------
-- next-gen platform — PLATFORM, PLATFORM_TABS, PLATFORM_PANEL_TRANSITION
-- --------------------------------------------------------------------------
-- The per-tab Smart Animate timing is stored on the tab, because it differs
-- between the two and is read off the Figma reactions, not chosen here.
DELETE FROM cms.section_tabs WHERE section_id = cms.section_id_for('home', 'platform');
DO $seed$
DECLARE v_tab BIGINT;
BEGIN
  v_tab := (cms.tab_create(cms.section_id_for('home', 'platform'), 'mobile-application', 'Mobile Application', 1022, 'cubic-bezier(0.25, 0.9, 0.35, 1)', 1)).id;
  PERFORM cms.platform_step_create(v_tab, 'Real-time position tracking', 'Monitor open positions, live P&L, price movements, quantities, and order status in real time, all from one unified view.', 1);
  PERFORM cms.platform_step_create(v_tab, 'Instant UPI funding', 'Add funds instantly through UPI and get your trading account ready to place orders without waiting for manual processing.', 2);
  PERFORM cms.platform_step_create(v_tab, 'Research calls', 'Get expert market insights and actionable stock recommendations to support smarter trading decisions.', 3);
  PERFORM cms.platform_panel_create(v_tab, (SELECT id FROM cms.media_assets WHERE url = '/figma/platform/app-panel.png'), 0, 1);
  PERFORM cms.platform_panel_create(v_tab, (SELECT id FROM cms.media_assets WHERE url = '/figma/platform/app-panel.png'), 1, 2);
  PERFORM cms.platform_panel_create(v_tab, (SELECT id FROM cms.media_assets WHERE url = '/figma/platform/app-panel.png'), 2, 3);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'platform'), 'trading-terminal', 'Trading terminal', 128, 'cubic-bezier(0.25, 0.9, 0.35, 1)', 2)).id;
  PERFORM cms.platform_step_create(v_tab, '4x E-Margin', 'Trade with up to 4x margin on eligible stocks, giving you greater buying power and flexibility with less upfront capital.', 1);
  PERFORM cms.platform_step_create(v_tab, 'After Market Orders', 'Place buy or sell orders outside regular market hours and have them queued for execution when the market opens.', 2);
  PERFORM cms.platform_step_create(v_tab, 'Screeners', 'Find the right stocks faster with powerful filters and custom criteria to identify opportunities based on your trading strategy.', 3);
  PERFORM cms.platform_panel_create(v_tab, (SELECT id FROM cms.media_assets WHERE url = '/figma/platform/terminal-panel.png'), 0, 1);
  PERFORM cms.platform_panel_create(v_tab, (SELECT id FROM cms.media_assets WHERE url = '/figma/platform/terminal-panel.png'), 1, 2);
  PERFORM cms.platform_panel_create(v_tab, (SELECT id FROM cms.media_assets WHERE url = '/figma/platform/terminal-panel.png'), 2, 3);
END
$seed$;

-- --------------------------------------------------------------------------
-- analysis you can trust — RESEARCH_TABS, RESEARCH
-- --------------------------------------------------------------------------
-- Cover art is picked by index today (`report-${i + 1}.png`); stored per row
-- here for the same reason as the purpose cards.
DELETE FROM cms.section_tabs WHERE section_id = cms.section_id_for('home', 'research');
DO $seed$
DECLARE v_tab BIGINT;
BEGIN
  v_tab := (cms.tab_create(cms.section_id_for('home', 'research'), 'fundamental-research', 'Fundamental Research', NULL, NULL, 1)).id;
  PERFORM cms.research_create(v_tab, 'SSL Morning Update', 'Morning Report',
    '2026-07-28', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-1.png'), 1);
  PERFORM cms.research_create(v_tab, 'Macro Trends Monthly Economic Report', 'Monthly Report',
    '2026-07-26', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-2.png'), 2);
  PERFORM cms.research_create(v_tab, 'Thematic Report - Rockstars of 4QFY26 Result', 'Thematic Report',
    '2026-07-17', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-3.png'), 3);
  PERFORM cms.research_create(v_tab, 'SBI Securities Weekly Wrap', 'Weekly Report',
    '2026-07-10', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-4.png'), 4);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'research'), 'technical-research', 'Technical Research', NULL, NULL, 2)).id;
  PERFORM cms.research_create(v_tab, 'SSL Morning Update', 'Morning Report',
    '2026-07-28', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-1.png'), 1);
  PERFORM cms.research_create(v_tab, 'Macro Trends Monthly Economic Report', 'Monthly Report',
    '2026-07-26', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-2.png'), 2);
  PERFORM cms.research_create(v_tab, 'Thematic Report - Rockstars of 4QFY26 Result', 'Thematic Report',
    '2026-07-17', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-3.png'), 3);
  PERFORM cms.research_create(v_tab, 'SBI Securities Weekly Wrap', 'Weekly Report',
    '2026-07-10', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/research/report-4.png'), 4);
END
$seed$;

-- --------------------------------------------------------------------------
-- your daily market digest — NEWS
-- --------------------------------------------------------------------------
DELETE FROM cms.news_items WHERE section_id = cms.section_id_for('home', 'news');
SELECT cms.news_create(cms.section_id_for('home', 'news'), 'Eternal Q1 Net Profit Jumps Nearly Four-Fold to Rs 92 Cr',
  'Jul 29, 2026 06:45 PM IST', NULL, TRUE, (SELECT id FROM cms.media_assets WHERE url = '/figma/news/lead.png'), 1);
SELECT cms.news_create(cms.section_id_for('home', 'news'), 'RBI Announces Rs 20,000 Crore Government Securities Buyback on July 28',
  'Jul 28 2026 06:45 PM IST', NULL, FALSE, (SELECT id FROM cms.media_assets WHERE url = '/figma/news/item-1.png'), 2);
SELECT cms.news_create(cms.section_id_for('home', 'news'), 'INR vs USD Rate, July 24, 2026: Rupee Rises 22 Paise to 96.51 Against US Dollar in Early Trade',
  'Jul 24, 2026 06:45 PM IST', NULL, FALSE, (SELECT id FROM cms.media_assets WHERE url = '/figma/news/item-2.png'), 3);
SELECT cms.news_create(cms.section_id_for('home', 'news'), 'Nasdaq Slips 0.22% to 25,781.58 as Oil Surges Past $94 and Big Tech Earnings Loom; Dow Defies Weakness with 0.40% Gain',
  'Jul 22, 2026 06:45 PM IST', NULL, FALSE, (SELECT id FROM cms.media_assets WHERE url = '/figma/news/item-3.png'), 4);

-- --------------------------------------------------------------------------
-- learn before you invest — LEARN_TABS, LESSONS
-- --------------------------------------------------------------------------
-- Thumbnails cycle through four files today (`lesson-${(i % 4) + 1}.png`).
DELETE FROM cms.section_tabs WHERE section_id = cms.section_id_for('home', 'learn');
DO $seed$
DECLARE v_tab BIGINT;
BEGIN
  v_tab := (cms.tab_create(cms.section_id_for('home', 'learn'), 'first-time-investors', 'First time investors', NULL, NULL, 1)).id;
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 1);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 2);
  PERFORM cms.lesson_create(v_tab, 'You thought you had figured the market out.', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-3.png'), 3);
  PERFORM cms.lesson_create(v_tab, 'Free advice is the most expensive advice', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-4.png'), 4);
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 5);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 6);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'learn'), 'active-traders', 'Active Traders', NULL, NULL, 2)).id;
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 1);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 2);
  PERFORM cms.lesson_create(v_tab, 'You thought you had figured the market out.', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-3.png'), 3);
  PERFORM cms.lesson_create(v_tab, 'Free advice is the most expensive advice', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-4.png'), 4);
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 5);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 6);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'learn'), 'global-investors', 'Global Investors', NULL, NULL, 3)).id;
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 1);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 2);
  PERFORM cms.lesson_create(v_tab, 'You thought you had figured the market out.', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-3.png'), 3);
  PERFORM cms.lesson_create(v_tab, 'Free advice is the most expensive advice', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-4.png'), 4);
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 5);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 6);
  v_tab := (cms.tab_create(cms.section_id_for('home', 'learn'), 'women-investors', 'Women Investors', NULL, NULL, 4)).id;
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 1);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 2);
  PERFORM cms.lesson_create(v_tab, 'You thought you had figured the market out.', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-3.png'), 3);
  PERFORM cms.lesson_create(v_tab, 'Free advice is the most expensive advice', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-4.png'), 4);
  PERFORM cms.lesson_create(v_tab, 'Why our brain sees patterns that don''t exist', '12:45',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-1.png'), 5);
  PERFORM cms.lesson_create(v_tab, 'Why stories influence investors more than numbers', '12:28',
    '2025-07-02', NULL, (SELECT id FROM cms.media_assets WHERE url = '/figma/learn/lesson-2.png'), 6);
END
$seed$;

-- --------------------------------------------------------------------------
-- testimonials — TESTIMONIALS
-- --------------------------------------------------------------------------
-- No avatar column: the card renders quote and author only (design §9).
DELETE FROM cms.testimonials WHERE section_id = cms.section_id_for('home', 'testimonials');
SELECT cms.testimonial_create(cms.section_id_for('home', 'testimonials'), 'I would like to thank the SBI Securities team for the awesome trading platform and easy-to-read reports. Their regular research inputs help in making diligent and timely calls for my investments. Well done😊',
  'Vishal', 1);
SELECT cms.testimonial_create(cms.section_id_for('home', 'testimonials'), 'The research calls have been consistently useful and the app is quick even on a busy market day. Order execution has never let me down.',
  'Anita', 2);
SELECT cms.testimonial_create(cms.section_id_for('home', 'testimonials'), 'Opening the demat account took minutes and the support team walked me through my first trade patiently. Exactly what a first-time investor needs.',
  'Rahul', 3);
SELECT cms.testimonial_create(cms.section_id_for('home', 'testimonials'), 'Brokerage is transparent and the margin facility is genuinely useful. Being backed by SBI gives me the confidence to invest more.',
  'Meera', 4);

-- --------------------------------------------------------------------------
-- pricing — PLANS
-- --------------------------------------------------------------------------
DELETE FROM cms.pricing_plans WHERE section_id = cms.section_id_for('home', 'pricing');
DO $seed$
DECLARE v_plan BIGINT;
BEGIN
  v_plan := (cms.plan_create(cms.section_id_for('home', 'pricing'), 'SUVIDHA', '₹0',
    '', 'suvidha', '', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/pricing/suvidha.png'), 1)).id;
  PERFORM cms.plan_feature_create(v_plan, 'Free Account Opening', 1);
  PERFORM cms.plan_feature_create(v_plan, '0.50% Delivery of the Order Value', 2);
  PERFORM cms.plan_feature_create(v_plan, '0.50% E-margin', 3);
  PERFORM cms.plan_feature_create(v_plan, '₹20 per order on Intraday', 4);
  v_plan := (cms.plan_create(cms.section_id_for('home', 'pricing'), 'PRO ZERO', '₹99',
    '+ GST', 'prozero', '', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/pricing/prozero.png'), 2)).id;
  PERFORM cms.plan_feature_create(v_plan, 'Free Intraday Brokerage', 1);
  PERFORM cms.plan_feature_create(v_plan, '0.20% Delivery of the Order Value', 2);
  PERFORM cms.plan_feature_create(v_plan, '0.40% E-margin', 3);
  PERFORM cms.plan_feature_create(v_plan, '₹20 per order on Intraday', 4);
  v_plan := (cms.plan_create(cms.section_id_for('home', 'pricing'), 'Women Plan', '₹0',
    '', 'women', '', NULL,
    (SELECT id FROM cms.media_assets WHERE url = '/figma/pricing/women.png'), 3)).id;
  PERFORM cms.plan_feature_create(v_plan, 'Free AOC, Exclusive plan for women', 1);
  PERFORM cms.plan_feature_create(v_plan, '0.20% Delivery of the Order Value', 2);
  PERFORM cms.plan_feature_create(v_plan, '0.50% E-margin', 3);
  PERFORM cms.plan_feature_create(v_plan, 'FREE ETF', 4);
END
$seed$;

-- --------------------------------------------------------------------------
-- FAQ — FAQS
-- --------------------------------------------------------------------------
DELETE FROM cms.faq_items WHERE section_id = cms.section_id_for('home', 'faq');
SELECT cms.faq_create(cms.section_id_for('home', 'faq'), 'Why should I choose SBI Securities over other trading platforms?',
  'Beyond the trust of the SBI name, the platform is built for a seamless trading experience a user-friendly app, real-time watchlists, fast order execution, margin and brokerage transparency, and dedicated research and advisory support. It combines the reliability of a legacy institution with the convenience of a modern digital trading platform.', 1);
SELECT cms.faq_create(cms.section_id_for('home', 'faq'), 'Is my money and data safe with SBI Securities?',
  'Your funds stay in your own bank account and your securities in your own demat account. The platform is SEBI regulated and every session runs over bank-grade encryption.', 2);
SELECT cms.faq_create(cms.section_id_for('home', 'faq'), 'What can I invest in through SBI Securities?',
  'Equity, IPOs, derivatives, ETFs, mutual funds, equity SIPs, corporate FDs, 54EC bonds and NPS — all from a single demat account.', 3);
SELECT cms.faq_create(cms.section_id_for('home', 'faq'), 'Does SBI Securities offer flexible brokerage plans?',
  'Yes. Choose SUVIDHA for zero account opening, PRO ZERO for free intraday brokerage at ₹99 + GST, or the Women Plan for a free account with exclusive pricing.', 4);

-- --------------------------------------------------------------------------
-- app download promo — FOOTER_CTA
-- --------------------------------------------------------------------------
-- The banner IS the card's content, and both window bounds are null, so the
-- fold renders exactly what it renders today while scheduling a replacement
-- becomes possible without a code change (design §8.3).
DELETE FROM cms.promo_banners WHERE section_id = cms.section_id_for('home', 'app-promo');
SELECT cms.banner_create(cms.section_id_for('home', 'app-promo'), 'Stop Scrolling, Start investing!',
  'Watch your money grow. Download the app now and start taking control of your money today.', 'Download Now', '/download-app',
  (SELECT id FROM cms.media_assets WHERE url = '/figma/footer/phone.png'), NULL, NULL, NULL, 1);

-- --------------------------------------------------------------------------
-- sticky nudge — STICKY_NUDGE
-- --------------------------------------------------------------------------
SELECT cms.sticky_nudge_update('home', 'Smart investing starts here',
  'Enter your mobile number', 'Enter your full name',
  'Get Started', NULL, 'sticky-nudge');

-- --------------------------------------------------------------------------
-- footer legal, stock index, keyword chips — FOOTER_LEGAL, STOCK_*
-- --------------------------------------------------------------------------
DELETE FROM cms.legal_content;
SELECT cms.legal_create('registration-1', 'Registration line 1', 'AMFI Registered Mutual Fund Distributor', 1);
SELECT cms.legal_create('registration-2', 'Registration line 2', 'CIN: U65999MH2005PLC155485', 2);
SELECT cms.legal_create('trading', 'Trading disclosure', 'Equities: Trading through SBICAP Securities Limited I Website: www.sbisecurities.in SEBI Registration No.: Stock Broker: INZ000200032 | DP Registration No.: IN-DP-314-2017 | Research Analyst : INH000000602 | IRDAI Corporate Agency Reg. No. CA0103; AMFI Reg. No. ARN-0011 (Date of initial registration: 19th August 2005 and valid upto 18th February 2027); PFRDA Reg. No. POP26092018. In case of any grievances please write to complaints@sbicapsec.com DP related grievance can be sent to :dp.grievance@sbicapsec.com | NPS related grievance can be sent to : Npsgrievance@sbicapsec.com | Compliance officer - Mr.Srijith Menon , email -compliance@sbicapsec.com; Tel No.- 022 - 69316510', 3);
SELECT cms.legal_create('authorization', 'IRDAI authorisation', 'SBICAP Securities Limited is authorized by the Insurance Regulatory and Development Authority of India to act as a Corporate Agent from 01- April- 2025 to 31-March 2028 for procuring or soliciting insurance business of Life, General and Health under license number CA0103, Category: Composite. SBICAP Securities Ltd. does not underwrite the risk or act as an insurer. The advertisement contains only an indication of the cover offered. For more details on risk factors, terms, conditions and exclusions, please read the sales brochure carefully before concluding a sale. SBI Logo displayed belongs to State Bank of India and used by SBICAP Securities Limited under license. Personal information as submitted by you will be shared with SBICAP and insurer in order to complete your application. By continuing, you provide your consent for the above and authorize SBICAP Securities representatives to contact you through call, SMS, WhatsApp or E-mail for providing assistance towards the application process.', 4);
SELECT cms.legal_create('warning', 'Fraud warning', 'BEWARE OF SPURIOUS PHONE CALLS AND FICTITIOUS /FRAUDULENT OFFERSIRDAI is not involved in activities like selling insurance policies, announcing bonus or investment of premiums. Public receiving such phone calls are requested to lodge a police complaint. To read more, please click here - IRDAI Public Notice', 5);
SELECT cms.legal_create('copyright', 'Copyright', 'Copyright © 2024. All rights Reserved. SBICAP Securities Limited.Site is best viewed in edge browser, Firefox 38+, Chrome 50+ at 1366x768 pixel resolution. Windows 10 and above', 6);

DELETE FROM cms.stock_index_letters;
SELECT cms.stock_letter_create('A', '/stocks/a', 1);
SELECT cms.stock_letter_create('B', '/stocks/b', 2);
SELECT cms.stock_letter_create('C', '/stocks/c', 3);
SELECT cms.stock_letter_create('D', '/stocks/d', 4);
SELECT cms.stock_letter_create('E', '/stocks/e', 5);
SELECT cms.stock_letter_create('F', '/stocks/f', 6);
SELECT cms.stock_letter_create('G', '/stocks/g', 7);
SELECT cms.stock_letter_create('H', '/stocks/h', 8);
SELECT cms.stock_letter_create('I', '/stocks/i', 9);
SELECT cms.stock_letter_create('J', '/stocks/j', 10);
SELECT cms.stock_letter_create('K', '/stocks/k', 11);
SELECT cms.stock_letter_create('L', '/stocks/l', 12);
SELECT cms.stock_letter_create('M', '/stocks/m', 13);
SELECT cms.stock_letter_create('N', '/stocks/n', 14);
SELECT cms.stock_letter_create('O', '/stocks/o', 15);
SELECT cms.stock_letter_create('P', '/stocks/p', 16);
SELECT cms.stock_letter_create('Q', '/stocks/q', 17);
SELECT cms.stock_letter_create('R', '/stocks/r', 18);
SELECT cms.stock_letter_create('S', '/stocks/s', 19);
SELECT cms.stock_letter_create('T', '/stocks/t', 20);
SELECT cms.stock_letter_create('U', '/stocks/u', 21);
SELECT cms.stock_letter_create('V', '/stocks/v', 22);
SELECT cms.stock_letter_create('W', '/stocks/w', 23);
SELECT cms.stock_letter_create('X', '/stocks/x', 24);
SELECT cms.stock_letter_create('Y', '/stocks/y', 25);
SELECT cms.stock_letter_create('Z', '/stocks/z', 26);
SELECT cms.stock_letter_create('0-9', '/stocks/0-9', 27);
SELECT cms.stock_letter_create('All', '/stocks/all', 28);

DELETE FROM cms.stock_links;
SELECT cms.stock_link_create('Nifty 50 Stocks Overview', '/stocks', 1);
SELECT cms.stock_link_create('Essential Resources for Nifty 50', '/stocks', 2);
SELECT cms.stock_link_create('Nifty Stocks Sorted by Sector', '/stocks', 3);
SELECT cms.stock_link_create('Nifty Stocks Organized by Value', '/stocks', 4);
SELECT cms.stock_link_create('Price-Based Nifty Stock List', '/stocks', 5);
SELECT cms.stock_link_create('Top Trending Nifty Stocks', '/stocks', 6);
SELECT cms.stock_link_create('Nifty Stocks Categorized by Cap', '/stocks', 7);
SELECT cms.stock_link_create('Nifty Stocks Ordered by Volume', '/stocks', 8);
SELECT cms.stock_link_create('Nifty Stocks Arranged by Returns', '/stocks', 9);
SELECT cms.stock_link_create('Nifty Stocks Listed by Performance', '/stocks', 10);
SELECT cms.stock_link_create('Current Trending Nifty Stocks', '/stocks', 11);
SELECT cms.stock_link_create('Nifty Stocks Grouped by Industry', '/stocks', 12);
SELECT cms.stock_link_create('Nifty Stocks Classified by Yield', '/stocks', 13);
SELECT cms.stock_link_create('Nifty Stocks Sorted by Market Cap', '/stocks', 14);
SELECT cms.stock_link_create('Nifty Stocks Listed by Price Move', '/stocks', 15);
SELECT cms.stock_link_create('Trending Nifty Stocks', '/stocks', 16);
SELECT cms.stock_link_create('Nifty Stocks Categorized by Theme', '/stocks', 17);
SELECT cms.stock_link_create('Nifty Stocks Arranged by Weight', '/stocks', 18);
SELECT cms.stock_link_create('Nifty Stocks Sorted by Turnover', '/stocks', 19);
SELECT cms.stock_link_create('Nifty Stocks Organized by Index', '/stocks', 20);
SELECT cms.stock_link_create('Trending Nifty Stocks', '/stocks', 21);
SELECT cms.stock_link_create('Nifty Stocks Grouped by Segment', '/stocks', 22);
SELECT cms.stock_link_create('Nifty Stocks Classified by Beta', '/stocks', 23);
SELECT cms.stock_link_create('Nifty Stocks Sorted by Delivery', '/stocks', 24);
SELECT cms.stock_link_create('Nifty Stocks Listed by PE Ratio', '/stocks', 25);

COMMIT;
