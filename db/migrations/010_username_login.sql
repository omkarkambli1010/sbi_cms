-- ============================================================================
-- 010_username_login.sql — sign in with a numeric username, not an email.
--
-- 001 made the email address the login identity and constrained it to look
-- like an email. The dashboard is for SBI Securities staff, who are
-- identified by a numeric staff code, so the identity moves to `username`:
-- digits only, unique, and the thing the sign-in form asks for.
--
-- The email column stays, because an administrator still has a contact
-- address and the media library records who uploaded what — but it is now
-- optional, and it is no longer how anyone signs in.
--
-- Two functions are dropped rather than replaced: CREATE OR REPLACE cannot
-- rename an input parameter or change a return type, and both change here.
-- ============================================================================

SET search_path = cms, public;

-- ---------------------------------------------------------------------------
-- schema
-- ---------------------------------------------------------------------------

ALTER TABLE cms.admin_users
  ADD COLUMN IF NOT EXISTS username TEXT;

-- Digits only, and long enough to be a staff code rather than a typo.
ALTER TABLE cms.admin_users
  DROP CONSTRAINT IF EXISTS admin_users_username_check;

ALTER TABLE cms.admin_users
  ADD CONSTRAINT admin_users_username_check
  CHECK (username IS NULL OR username ~ '^[0-9]{4,20}$');

-- A plain unique index, not a partial one: PostgreSQL already treats NULLs as
-- distinct, so accounts without a username coexist, and ON CONFLICT (username)
-- can infer this index without having to repeat a predicate.
CREATE UNIQUE INDEX IF NOT EXISTS admin_users_username_key
  ON cms.admin_users (username);

-- An account created before this migration has no username and therefore
-- cannot sign in. That is deliberate: inventing one from the email address
-- would silently hand somebody a credential nobody chose.
ALTER TABLE cms.admin_users ALTER COLUMN email DROP NOT NULL;

ALTER TABLE cms.admin_users
  DROP CONSTRAINT IF EXISTS admin_users_email_check;

ALTER TABLE cms.admin_users
  ADD CONSTRAINT admin_users_email_check
  CHECK (email IS NULL OR email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

-- ---------------------------------------------------------------------------
-- functions
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION cms.admin_user_get_by_username(p_username TEXT)
RETURNS cms.admin_users
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM cms.admin_users WHERE username = btrim(p_username);
$$;

DROP FUNCTION IF EXISTS cms.admin_user_create(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION cms.admin_user_create(
  p_username      TEXT,
  p_full_name     TEXT,
  p_password_hash TEXT,
  p_password_salt TEXT,
  p_role          TEXT DEFAULT 'editor',
  p_email         TEXT DEFAULT NULL
)
RETURNS cms.admin_users
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_users;
BEGIN
  INSERT INTO cms.admin_users (username, email, full_name, password_hash, password_salt, role)
  VALUES (
    btrim(p_username),
    nullif(btrim(coalesce(p_email, '')), ''),
    btrim(p_full_name),
    p_password_hash,
    p_password_salt,
    p_role
  )
  RETURNING * INTO v_row;

  RETURN v_row;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'An account already exists for username %', p_username
      USING ERRCODE = 'unique_violation';
END;
$$;

-- session_resolve carries the username so the dashboard can name the signed-in
-- user without a second query, and so it has something to show for an account
-- with no email address.
DROP FUNCTION IF EXISTS cms.session_resolve(TEXT);

CREATE OR REPLACE FUNCTION cms.session_resolve(p_token_hash TEXT)
RETURNS TABLE (
  session_id BIGINT,
  user_id    BIGINT,
  username   TEXT,
  email      TEXT,
  full_name  TEXT,
  role       TEXT,
  expires_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT s.id, u.id, u.username, u.email, u.full_name, u.role, s.expires_at
    FROM cms.admin_sessions s
    JOIN cms.admin_users u ON u.id = s.user_id
   WHERE s.token_hash = p_token_hash
     AND s.revoked_at IS NULL
     AND s.expires_at > now()
     AND u.is_active;
$$;
