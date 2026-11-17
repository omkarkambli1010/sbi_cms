-- ============================================================================
-- 016_api_routine_boundary.sql — the stored routines become the only door.
--
-- The Go service (cms-backend) reaches the database through a dedicated role,
-- sbi_cms_api, that can EXECUTE routines and do nothing else: no SELECT, no
-- INSERT, no UPDATE, no DELETE on any table. For that to work, the routines
-- have to run with their owner's rights rather than the caller's, so every
-- routine in the cms schema is made SECURITY DEFINER.
--
-- Two things make SECURITY DEFINER safe here rather than a privilege hole:
--
--   * search_path is pinned on each routine. A definer routine that inherits
--     the caller's search_path can be made to resolve a name to an object the
--     caller planted; pinning it removes that.
--   * EXECUTE is revoked from PUBLIC and granted by name. A new routine is
--     therefore unreachable until someone decides it should be reachable.
--
-- The role itself is created by db/setup.sql (it needs CREATEROLE, which the
-- application owner deliberately lacks). If the role does not exist yet, the
-- grants at the end are skipped with a NOTICE and db/grant-api-role.sql applies
-- them once it does.
--
-- Idempotent: ALTER and REVOKE can be repeated, and nothing here drops data.
-- ============================================================================

SET search_path = cms, public;

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
       -- Routines installed by an extension belong to it, not to us.
       AND NOT EXISTS (
         SELECT 1 FROM pg_depend d
          WHERE d.objid = p.oid AND d.deptype = 'e'
       )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER SET search_path = cms, public', r.sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', r.sig);
  END LOOP;
END
$boundary$;

-- Routines created from now on are not executable by PUBLIC either.
ALTER DEFAULT PRIVILEGES IN SCHEMA cms REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Grants to the API role, if it exists yet ------------------------------------
DO $grants$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sbi_cms_api') THEN
    GRANT USAGE ON SCHEMA cms TO sbi_cms_api;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cms TO sbi_cms_api;
    ALTER DEFAULT PRIVILEGES IN SCHEMA cms GRANT EXECUTE ON FUNCTIONS TO sbi_cms_api;
    -- Belt and braces: the role must not read or write tables directly.
    REVOKE ALL ON ALL TABLES IN SCHEMA cms FROM sbi_cms_api;
    REVOKE ALL ON ALL SEQUENCES IN SCHEMA cms FROM sbi_cms_api;
  ELSE
    RAISE NOTICE 'Role sbi_cms_api does not exist yet; run db/setup.sql, then db/grant-api-role.sql.';
  END IF;
END
$grants$;
