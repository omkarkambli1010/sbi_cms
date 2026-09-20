-- ============================================================================
-- One-time bootstrap, for pgAdmin's Query Tool.
--
-- Same job as db/setup.sql: create the application role and its database.
-- A separate file because setup.sql is written for psql and uses psql's own
-- meta-commands (\if, \set, \gexec, \echo), which are a psql feature and not
-- SQL — pgAdmin reports a syntax error on the first backslash. Everything
-- here is plain SQL.
--
-- HOW TO RUN
--
--   1. In pgAdmin, connect to your local server as the `postgres` superuser.
--   2. Right-click the `postgres` database -> Query Tool.
--   3. Paste this file in and run it (F5).
--
-- Run it against `postgres`, not against `sbi_cms`: CREATE DATABASE cannot run
-- from inside the database it is creating.
--
-- REPLACE the two placeholders below with the password you want the
-- application role to use, and put the same one in DATABASE_URL in
-- .env.local. If the two disagree the app cannot log in.
--
-- Nothing real is committed here on purpose: this file is in version
-- control, and a working database password in a repository is a working
-- database password for anyone who clones it.
--
-- After this, nothing else is done by hand. `npm run db:migrate` creates all
-- 35 tables and 229 stored functions, and `npm run db:seed` fills them.
-- ============================================================================

-- Role ----------------------------------------------------------------------
-- The application role is deliberately not a superuser: the app never needs
-- those rights, and a leaked application credential should not be able to
-- reach outside its own database.
DO $bootstrap$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sbi_cms') THEN
    CREATE ROLE sbi_cms LOGIN PASSWORD 'REPLACE_WITH_YOUR_PASSWORD';
  ELSE
    ALTER ROLE sbi_cms LOGIN PASSWORD 'REPLACE_WITH_YOUR_PASSWORD';
  END IF;
END
$bootstrap$;

-- Database --------------------------------------------------------------------
-- CREATE DATABASE cannot run inside a transaction or a DO block, so it is not
-- guarded here. Running this a second time reports
--
--   ERROR: database "sbi_cms" already exists
--
-- which means the line above it already did its job. Ignore it and carry on.
CREATE DATABASE sbi_cms OWNER sbi_cms ENCODING 'UTF8';

GRANT ALL PRIVILEGES ON DATABASE sbi_cms TO sbi_cms;
