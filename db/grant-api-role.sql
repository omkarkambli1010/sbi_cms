-- ============================================================================
-- Grants for the cms-backend role. Run as the schema owner (sbi_cms) AFTER the
-- role exists (db/setup.sql creates it) and after the migrations.
--
--   psql -U sbi_cms -h localhost -d sbi_cms -f db/grant-api-role.sql
--
-- Plain SQL, so pgAdmin's Query Tool can run it too. Safe to repeat. It is the
-- same block migration 016 ends with, for the case where the role was created
-- after the migration ran.
-- ============================================================================

GRANT USAGE ON SCHEMA cms TO sbi_cms_api;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cms TO sbi_cms_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA cms GRANT EXECUTE ON FUNCTIONS TO sbi_cms_api;
REVOKE ALL ON ALL TABLES IN SCHEMA cms FROM sbi_cms_api;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA cms FROM sbi_cms_api;
