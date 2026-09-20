#!/usr/bin/env node
/**
 * Database CLI.
 *
 *   node scripts/db.mjs migrate       apply db/migrations/*.sql in name order
 *   node scripts/db.mjs seed          apply db/seeds/*.sql in name order
 *   node scripts/db.mjs reset         drop the cms schema, migrate, seed
 *   node scripts/db.mjs create-admin  create or update a dashboard login
 *   node scripts/db.mjs status        show what has been applied
 *
 * Migrations are recorded in cms.schema_migrations and never re-run. Seeds are
 * deliberately NOT recorded: they are written to be idempotent so that
 * `seed` doubles as "put the shipped copy back".
 *
 * Reads DATABASE_URL from .env.local (or the environment). The password never
 * appears in argv, so it stays out of shell history and process listings.
 */

import { readFile, readdir } from "node:fs/promises";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { randomBytes, scrypt as scryptCb, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { createInterface } from "node:readline/promises";
import pg from "pg";

const scrypt = promisify(scryptCb);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/* --- env ------------------------------------------------------------------ */

/**
 * Minimal .env reader. Next loads .env.local for the app, but this script runs
 * outside Next, and pulling in dotenv for six lines is not worth a dependency.
 */
function loadEnvFile(file) {
  if (!existsSync(file)) return;
  const text = readFileSync(file, "utf8");
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnvFile(path.join(ROOT, ".env.local"));
loadEnvFile(path.join(ROOT, ".env"));

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error(
    [
      "",
      "DATABASE_URL is not set.",
      "",
      "Create D:\\tmp\\cms-website\\.env.local containing:",
      "",
      "  DATABASE_URL=postgres://sbi_cms:YOUR_PASSWORD@localhost:5432/sbi_cms",
      "",
      "If the database does not exist yet, create it first as a superuser:",
      "",
      '  & "C:\\Program Files\\PostgreSQL\\17\\bin\\psql.exe" -U postgres -h localhost -f db/setup.sql',
      "",
    ].join("\n"),
  );
  process.exit(1);
}

/* --- helpers -------------------------------------------------------------- */

function newClient() {
  return new pg.Client({ connectionString: DATABASE_URL, application_name: "sbi-cms-cli" });
}

async function sqlFiles(dir) {
  const full = path.join(ROOT, "db", dir);
  if (!existsSync(full)) return [];
  const entries = await readdir(full);
  return entries.filter((f) => f.endsWith(".sql")).sort();
}

async function ensureMigrationTable(client) {
  await client.query(`CREATE SCHEMA IF NOT EXISTS cms`);
  await client.query(`
    CREATE TABLE IF NOT EXISTS cms.schema_migrations (
      filename    TEXT PRIMARY KEY,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

/**
 * psql meta-commands (\echo, \gexec, \set) are a psql feature, not SQL. The
 * driver would choke on them, so they are stripped here — the migration and
 * seed files use them only for progress output.
 */
function stripPsqlMeta(sql) {
  return sql
    .split(/\r?\n/)
    .filter((line) => !/^\s*\\/.test(line))
    .join("\n");
}

/* --- commands ------------------------------------------------------------- */

async function migrate() {
  const client = newClient();
  await client.connect();
  try {
    await ensureMigrationTable(client);
    const { rows } = await client.query(`SELECT filename FROM cms.schema_migrations`);
    const applied = new Set(rows.map((r) => r.filename));
    const files = await sqlFiles("migrations");
    let ran = 0;

    for (const file of files) {
      if (applied.has(file)) continue;
      const sql = stripPsqlMeta(await readFile(path.join(ROOT, "db/migrations", file), "utf8"));

      /* Each migration is one transaction: a file either lands whole or not at
         all, so a syntax error halfway down cannot leave a half-built schema. */
      await client.query("BEGIN");
      try {
        await client.query(sql);
        await client.query(`INSERT INTO cms.schema_migrations (filename) VALUES ($1)`, [file]);
        await client.query("COMMIT");
        console.log(`  applied  ${file}`);
        ran += 1;
      } catch (error) {
        await client.query("ROLLBACK");
        console.error(`  FAILED   ${file}`);
        throw error;
      }
    }

    console.log(ran === 0 ? "Nothing to apply — schema is up to date." : `Applied ${ran} migration(s).`);
  } finally {
    await client.end();
  }
}

async function seed() {
  const client = newClient();
  await client.connect();
  try {
    for (const file of await sqlFiles("seeds")) {
      const sql = stripPsqlMeta(await readFile(path.join(ROOT, "db/seeds", file), "utf8"));
      await client.query(sql);
      console.log(`  seeded   ${file}`);
    }
    console.log("Seed complete.");
  } finally {
    await client.end();
  }
}

async function reset() {
  const client = newClient();
  await client.connect();
  try {
    console.log("Dropping schema cms ...");
    await client.query(`DROP SCHEMA IF EXISTS cms CASCADE`);
  } finally {
    await client.end();
  }
  await migrate();
  await seed();
}

async function status() {
  const client = newClient();
  await client.connect();
  try {
    await ensureMigrationTable(client);
    const { rows } = await client.query(
      `SELECT filename, applied_at FROM cms.schema_migrations ORDER BY filename`,
    );
    const files = await sqlFiles("migrations");
    const applied = new Map(rows.map((r) => [r.filename, r.applied_at]));

    console.log("\nMigrations");
    for (const f of files) {
      const at = applied.get(f);
      console.log(`  ${at ? "applied " : "pending "} ${f}${at ? `  ${at.toISOString()}` : ""}`);
    }

    const counts = await client.query(`
      SELECT 'admin_users' AS table, count(*)::int FROM cms.admin_users
      UNION ALL SELECT 'media_assets', count(*)::int FROM cms.media_assets
      UNION ALL SELECT 'pages', count(*)::int FROM cms.pages
      UNION ALL SELECT 'page_sections', count(*)::int FROM cms.page_sections
      UNION ALL SELECT 'navigation_items', count(*)::int FROM cms.navigation_items
      UNION ALL SELECT 'hero_rotating_lines', count(*)::int FROM cms.hero_rotating_lines
      UNION ALL SELECT 'hero_kpis', count(*)::int FROM cms.hero_kpis
    `);
    console.log("\nRow counts");
    for (const r of counts.rows) console.log(`  ${String(r.table).padEnd(22)} ${r.count}`);
    console.log("");
  } finally {
    await client.end();
  }
}

/**
 * scrypt with a per-user random salt. Node ships it, so the CMS gains no
 * dependency for password hashing, and its cost parameters are tunable unlike
 * a bare SHA.
 */
export async function hashPassword(password, salt = randomBytes(16).toString("hex")) {
  const derived = await scrypt(password, salt, 64);
  return { hash: derived.toString("hex"), salt };
}

export async function verifyPassword(password, hash, salt) {
  const { hash: candidate } = await hashPassword(password, salt);
  const a = Buffer.from(candidate, "hex");
  const b = Buffer.from(hash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

async function createAdmin() {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try {
    const username = (await rl.question("Username (digits only): ")).trim();
    const fullName = (await rl.question("Full name: ")).trim();
    const email = (await rl.question("Email (optional): ")).trim();
    const password = (await rl.question("Password (min 12 chars): ")).trim();

    if (!/^[0-9]{4,20}$/.test(username)) throw new Error("Username must be 4 to 20 digits.");
    if (!fullName) throw new Error("Full name is required.");

    /* The seeded 16191/16191 placeholder bypasses this rule by being written
       straight into the table. Anything created here is a real account and
       holds to it. */
    if (password.length < 12) throw new Error("Password must be at least 12 characters.");

    const { hash, salt } = await hashPassword(password);
    const client = newClient();
    await client.connect();
    try {
      const existing = await client.query(`SELECT * FROM cms.admin_user_get_by_username($1)`, [
        username,
      ]);
      if (existing.rows[0]?.id) {
        await client.query(`SELECT cms.admin_user_set_password($1, $2, $3)`, [
          existing.rows[0].id,
          hash,
          salt,
        ]);
        await client.query(`SELECT cms.admin_user_update($1, $2, 'admin')`, [
          existing.rows[0].id,
          fullName,
        ]);
        console.log(`\nUpdated existing administrator ${username}.`);
      } else {
        await client.query(`SELECT cms.admin_user_create($1, $2, $3, $4, 'admin', $5)`, [
          username,
          fullName,
          hash,
          salt,
          email || null,
        ]);
        console.log(`\nCreated administrator ${username}.`);
      }
      console.log("Sign in at http://localhost:3001/login\n");
    } finally {
      await client.end();
    }
  } finally {
    rl.close();
  }
}

/* --- entry ---------------------------------------------------------------- */

const COMMANDS = { migrate, seed, reset, status, "create-admin": createAdmin };
const command = process.argv[2];

if (!command || !(command in COMMANDS)) {
  console.error(`Usage: node scripts/db.mjs <${Object.keys(COMMANDS).join("|")}>`);
  process.exit(1);
}

COMMANDS[command]().catch((error) => {
  console.error(`\n${error.message}\n`);
  if (process.env.DEBUG) console.error(error);
  process.exit(1);
});
