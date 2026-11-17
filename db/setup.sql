-- ============================================================================
-- One-time bootstrap. Run this ONCE as a PostgreSQL superuser.
--
--   psql -U postgres -h localhost -f db/setup.sql
--
-- It creates the application role and database. Everything after this point
-- (schema, functions, seed) runs as the application role, which deliberately
-- has no superuser rights: the app never needs them, and a compromised
-- application credential should not be able to reach outside its own database.
--
-- The password is passed in rather than written here, so it never lands in a
-- committed file. It must match the DATABASE_URL in .env.local:
--
--   psql -U postgres -h localhost -v app_password='...' -f db/setup.sql
-- ============================================================================

-- Falls back to an obviously-wrong value if -v was forgotten, so the mistake
-- surfaces at login rather than silently creating a guessable account.
\if :{?app_password}
\else
\set app_password 'NOT-SET-pass-app_password-with--v'
\endif

-- Role ------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sbi_cms') THEN
    EXECUTE format('CREATE ROLE sbi_cms LOGIN PASSWORD %L', :'app_password');
  ELSE
    EXECUTE format('ALTER ROLE sbi_cms LOGIN PASSWORD %L', :'app_password');
  END IF;
END
$$;

-- API role ----------------------------------------------------------------------
-- Used only by cms-backend. It can EXECUTE the cms.* stored routines and do
-- nothing else: no table access at all. Migration 016 makes the routines run
-- with their owner's rights so that is enough. Pass its password separately:
--
--   psql ... -v app_password='...' -v api_password='...' -f db/setup.sql
\if :{?api_password}
\else
\set api_password 'NOT-SET-pass-api_password-with--v'
\endif

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sbi_cms_api') THEN
    EXECUTE format('CREATE ROLE sbi_cms_api LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE', :'api_password');
  ELSE
    EXECUTE format('ALTER ROLE sbi_cms_api LOGIN PASSWORD %L', :'api_password');
  END IF;
END
$$;

-- Database --------------------------------------------------------------------
-- CREATE DATABASE cannot run inside a transaction block or a DO block, so it is
-- guarded with \gexec instead: the SELECT produces the statement only when the
-- database is absent, and \gexec runs whatever the query returned.
SELECT 'CREATE DATABASE sbi_cms OWNER sbi_cms ENCODING ''UTF8'''
 WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'sbi_cms')
\gexec

GRANT ALL PRIVILEGES ON DATABASE sbi_cms TO sbi_cms;
GRANT CONNECT ON DATABASE sbi_cms TO sbi_cms_api;

\echo ''
\echo 'Done. Next:'
\echo '  1. Put the matching DATABASE_URL in D:\tmp\cms-website\.env.local'
\echo '  2. npm run db:migrate'
\echo '  3. psql -U sbi_cms -d sbi_cms -f db/grant-api-role.sql   (only if the role was created after migrating)'
\echo ''
