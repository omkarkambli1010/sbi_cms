-- ============================================================================
-- 003_dev_admin.sql — a placeholder sign-in so the dashboard can be opened.
--
--   Username  16191
--   Password  16191
--
-- This is a development credential, requested as a stand-in until real
-- accounts exist. It is weak on purpose and it is in version control, so it
-- must not reach an environment anyone outside the team can reach. Two things
-- follow from that:
--
--   * Before this goes anywhere public, delete this file and create a real
--     account with `npm run db:create-admin`, which enforces a 12-character
--     minimum that these five digits would never pass.
--   * The hash below is scrypt with the same parameters the application uses
--     (N=16384, r=8, p=1, 64-byte key), so nothing special is needed to verify
--     it — it is an ordinary row that happens to have a guessable password.
--
-- Re-runnable: the password is reset to 16191 on every seed, which is what
-- "put the shipped state back" should mean for a placeholder account.
-- ============================================================================

SET search_path = cms, public;

BEGIN;

INSERT INTO cms.admin_users (username, full_name, password_hash, password_salt, role)
VALUES (
  '16191',
  'SBI Securities admin',
  '9872adaa38802bc269ae8cb06f96011ae67ff971c0d28ccbd4dfd9d0a1c58ccc4cc3d9e0c9d18002d087e47085bc093afe783180a807bdbe6c8d27de553fdbbc',
  'e608eb345d714a399902f66d6c23b6ae',
  'admin'
)
ON CONFLICT (username) DO UPDATE
   SET full_name     = EXCLUDED.full_name,
       password_hash = EXCLUDED.password_hash,
       password_salt = EXCLUDED.password_salt,
       role          = EXCLUDED.role,
       is_active     = TRUE;

COMMIT;
