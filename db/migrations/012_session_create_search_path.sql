-- ============================================================================
-- 012_session_create_search_path.sql — qualify one call.
--
-- cms.session_create called `try_cast_inet(p_ip_address)` with no schema. That
-- resolved fine while 002 was being applied, because the migration file opens
-- with `SET search_path = cms, public` — but that is a setting on the session
-- doing the applying, not on the function. At runtime the application connects
-- with the default search_path (`"$user", public`), cms is not on it, and the
-- call fails with 42883 undefined_function.
--
-- It only ever surfaced on a successful sign-in: every failing login returns
-- before a session is created, so the first person to type the right password
-- was always going to be the one to find it.
--
-- Every other cross-function call in the schema is already qualified — this
-- was the only one — so the fix is to make this one match, rather than to
-- pin a search_path the rest of the schema does not rely on.
-- ============================================================================

SET search_path = cms, public;

CREATE OR REPLACE FUNCTION cms.session_create(
  p_user_id    BIGINT,
  p_token_hash TEXT,
  p_expires_at TIMESTAMPTZ,
  p_user_agent TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL
)
RETURNS cms.admin_sessions
LANGUAGE plpgsql
AS $$
DECLARE
  v_row cms.admin_sessions;
BEGIN
  INSERT INTO cms.admin_sessions (user_id, token_hash, expires_at, user_agent, ip_address)
  VALUES (
    p_user_id,
    p_token_hash,
    p_expires_at,
    p_user_agent,
    -- A malformed forwarded-for header should not fail a login.
    CASE WHEN p_ip_address IS NULL OR btrim(p_ip_address) = '' THEN NULL
         ELSE cms.try_cast_inet(p_ip_address) END
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;
