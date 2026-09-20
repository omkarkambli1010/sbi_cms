import "server-only";

import { Pool, type PoolClient, type QueryResultRow } from "pg";

/**
 * The single PostgreSQL pool for this process.
 *
 * `server-only` is load-bearing: if a Client Component ever reaches this
 * module the build fails rather than shipping a connection string to the
 * browser. It is enforcement, not convention.
 *
 * In development Next re-evaluates modules on every hot reload. A module-level
 * `new Pool()` would therefore leak a pool per reload until PostgreSQL refuses
 * new connections, so the instance is parked on globalThis and reused.
 */

declare global {
  var __sbiCmsPool: Pool | undefined;
}

function connectionString(): string {
  const url = process.env.DATABASE_URL?.trim();

  if (!url) {
    throw new Error(
      "DATABASE_URL is not set. Copy .env.example to .env.local and point it at your PostgreSQL instance.",
    );
  }

  return url;
}

function createPool(): Pool {
  const pool = new Pool({
    connectionString: connectionString(),
    max: Number(process.env.DATABASE_POOL_MAX ?? 10),
    application_name: "sbi-cms",
    /* A runaway query should not hold a request open indefinitely. Set on the
       pool so every connection inherits it rather than relying on call sites. */
    statement_timeout: Number(process.env.DATABASE_STATEMENT_TIMEOUT_MS ?? 8000),
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });

  /* An idle client erroring (server restart, network blip) emits on the pool.
     Without a listener Node treats it as an unhandled error and exits. */
  pool.on("error", (error) => {
    console.error("[db] idle client error:", error.message);
  });

  return pool;
}

export function getPool(): Pool {
  if (!globalThis.__sbiCmsPool) {
    globalThis.__sbiCmsPool = createPool();
  }
  return globalThis.__sbiCmsPool;
}

/**
 * Calls a stored function and returns its rows.
 *
 * Every argument goes through a bound parameter — the function name is the only
 * part of the statement built from a string, and it is never taken from request
 * input. This is the single place SQL text is constructed in the whole app.
 */
export async function callFunction<T extends QueryResultRow = QueryResultRow>(
  fn: string,
  args: readonly unknown[] = [],
): Promise<T[]> {
  if (!/^cms\.[a-z_]+$/.test(fn)) {
    throw new Error(`Refusing to call a function with an unexpected name: ${fn}`);
  }

  const placeholders = args.map((_, i) => `$${i + 1}`).join(", ");
  const text = `SELECT * FROM ${fn}(${placeholders})`;

  const result = await getPool().query<T>(text, args as unknown[]);
  return result.rows;
}

/** The same, for functions that return one row (or none). */
export async function callFunctionOne<T extends QueryResultRow = QueryResultRow>(
  fn: string,
  args: readonly unknown[] = [],
): Promise<T | null> {
  const rows = await callFunction<T>(fn, args);
  const row = rows[0];

  /* A function declared RETURNS <composite> yields one row of all-NULL columns
     when it matched nothing, rather than zero rows. Treat that as "not found"
     so callers get null instead of an object full of nulls. */
  if (!row) return null;
  if (Object.values(row).every((value) => value === null)) return null;

  return row;
}

/**
 * Runs several calls in one transaction.
 *
 * Used where a dashboard action is more than one statement — a reorder
 * followed by a read, say — so a partial failure cannot leave an ordered list
 * half-renumbered.
 */
export async function withTransaction<T>(
  work: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await getPool().connect();

  try {
    await client.query("BEGIN");
    const result = await work(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

/** True when the database answers. Used by the dashboard's health indicator. */
export async function pingDatabase(): Promise<boolean> {
  try {
    await getPool().query("SELECT 1");
    return true;
  } catch {
    return false;
  }
}
