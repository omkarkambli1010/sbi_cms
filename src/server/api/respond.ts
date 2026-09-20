import "server-only";

import { NextResponse } from "next/server";

import { ForbiddenError, UnauthorizedError } from "@/server/auth/session";

/**
 * One response shape for every API route, and one place that decides which
 * status a failure maps to.
 *
 * Routes throw; they do not build error responses by hand. That keeps the
 * happy path readable and means a new failure mode cannot accidentally leak a
 * stack trace or answer 200.
 */

export interface ApiSuccess<T> {
  ok: true;
  data: T;
}

export interface ApiFailure {
  ok: false;
  error: { message: string; code: string; fields?: Record<string, string> };
}

export function ok<T>(data: T, status = 200): NextResponse<ApiSuccess<T>> {
  return NextResponse.json({ ok: true as const, data }, { status });
}

/** A validation failure the caller can fix, reported field by field. */
export class ValidationError extends Error {
  readonly fields: Record<string, string>;

  constructor(fields: Record<string, string>, message = "Please correct the highlighted fields.") {
    super(message);
    this.name = "ValidationError";
    this.fields = fields;
  }
}

export class NotFoundError extends Error {
  constructor(message = "Not found.") {
    super(message);
    this.name = "NotFoundError";
  }
}

export class ConflictError extends Error {
  constructor(message = "That change conflicts with existing content.") {
    super(message);
    this.name = "ConflictError";
  }
}

/** PostgreSQL SQLSTATEs the stored functions raise deliberately. */
const PG_STATUS: Record<string, number> = {
  "23505": 409, // unique_violation
  "23503": 409, // foreign_key_violation
  "23514": 400, // check_violation
  "23502": 400, // not_null_violation
  P0002: 404, // no_data_found
  "23001": 409, // restrict_violation
  "22P02": 400, // invalid_text_representation
};

/**
 * Failures that mean "the database is not there", rather than "the database
 * refused this". They are worth telling apart, because the first is something
 * an operator fixes and the second is something an editor fixes.
 *
 * ECONNREFUSED and ENOTFOUND come from the socket, so they arrive as Node
 * error codes rather than SQLSTATEs; the rest are PostgreSQL's own.
 */
const UNREACHABLE = new Set([
  "ECONNREFUSED",
  "ENOTFOUND",
  "ETIMEDOUT",
  "28P01", // invalid_password
  "28000", // invalid_authorization_specification
  "3D000", // invalid_catalog_name — no such database
  "57P03", // cannot_connect_now — server starting up
  "08006", // connection_failure
  "08001", // sqlclient_unable_to_establish_sqlconnection
]);

function isPgError(error: unknown): error is { code: string; message: string } {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof (error as { code: unknown }).code === "string"
  );
}

export function fail(error: unknown): NextResponse<ApiFailure> {
  if (error instanceof UnauthorizedError) {
    return NextResponse.json(
      { ok: false as const, error: { message: error.message, code: "unauthorized" } },
      { status: 401 },
    );
  }

  if (error instanceof ForbiddenError) {
    return NextResponse.json(
      { ok: false as const, error: { message: error.message, code: "forbidden" } },
      { status: 403 },
    );
  }

  if (error instanceof ValidationError) {
    return NextResponse.json(
      { ok: false as const, error: { message: error.message, code: "validation", fields: error.fields } },
      { status: 422 },
    );
  }

  if (error instanceof NotFoundError) {
    return NextResponse.json(
      { ok: false as const, error: { message: error.message, code: "not_found" } },
      { status: 404 },
    );
  }

  if (error instanceof ConflictError) {
    return NextResponse.json(
      { ok: false as const, error: { message: error.message, code: "conflict" } },
      { status: 409 },
    );
  }

  if (isPgError(error)) {
    if (UNREACHABLE.has(error.code)) {
      console.error("[api] database unreachable:", error.code, error.message);

      /* 503, not 500: the request was fine and will work once the database
         is back, which is also what the message should say. */
      return NextResponse.json(
        {
          ok: false as const,
          error: {
            message: "The database is not responding. Nothing can be read or saved until it is.",
            code: "db_unreachable",
          },
        },
        { status: 503 },
      );
    }

    const status = PG_STATUS[error.code] ?? 500;

    /* A deliberate RAISE carries a message written for an editor, so it is
       safe to surface. Anything else is an internal fault and is not — and
       it is phrased without naming an operation, because this same branch
       answers reads as well as writes. */
    const message = status < 500 ? error.message : "Something went wrong. Please try again.";

    if (status >= 500) {
      console.error("[api] database error:", error.code, error.message);
    }

    return NextResponse.json(
      { ok: false as const, error: { message, code: `pg_${error.code}` } },
      { status },
    );
  }

  console.error("[api] unhandled error:", error);

  return NextResponse.json(
    { ok: false as const, error: { message: "Unexpected server error.", code: "internal" } },
    { status: 500 },
  );
}

/** Wraps a route handler so every throw lands in `fail`. */
export function route<T>(handler: () => Promise<NextResponse<T>>): Promise<NextResponse<T | ApiFailure>> {
  return handler().catch((error) => fail(error));
}

/* --- request parsing ------------------------------------------------------ */

export async function readJson(request: Request): Promise<Record<string, unknown>> {
  try {
    const body = await request.json();
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      throw new ValidationError({}, "Request body must be a JSON object.");
    }
    return body as Record<string, unknown>;
  } catch (error) {
    if (error instanceof ValidationError) throw error;
    throw new ValidationError({}, "Request body is not valid JSON.");
  }
}

/**
 * Small typed readers. They collect problems rather than throwing on the first
 * one, so a form reports every bad field at once instead of one per round trip.
 */
export class FieldReader {
  private readonly body: Record<string, unknown>;
  private readonly problems: Record<string, string> = {};

  constructor(body: Record<string, unknown>) {
    this.body = body;
  }

  string(key: string, opts: { required?: boolean; max?: number; min?: number } = {}): string {
    const raw = this.body[key];
    const value = typeof raw === "string" ? raw.trim() : "";

    if (opts.required && !value) {
      this.problems[key] = "This field is required.";
      return "";
    }
    if (opts.min && value.length > 0 && value.length < opts.min) {
      this.problems[key] = `Must be at least ${opts.min} characters.`;
    }
    if (opts.max && value.length > opts.max) {
      this.problems[key] = `Must be ${opts.max} characters or fewer.`;
    }

    return value;
  }

  /**
   * A link target, rejected rather than sanitised.
   *
   * The site sanitises again when it renders, because rows already stored
   * have to be safe too — but an editor who types `javascript:...` should be
   * told the field is wrong, not have it silently rewritten to "#" and
   * wonder later why the link goes nowhere. Refusing here is the half that
   * gives feedback; sanitising there is the half that cannot be bypassed.
   */
  href(key: string, opts: { required?: boolean; max?: number } = {}): string {
    const value = this.string(key, { required: opts.required, max: opts.max ?? 500 });

    if (!value) return value;
    if (value.startsWith("#") || (value.startsWith("/") && !value.startsWith("//"))) {
      return value;
    }

    /* Protocol-relative is an absolute URL in disguise, and its scheme is
       whatever the page happens to be served over — so it is not allowed to
       stand in for a relative path. */
    if (value.startsWith("//")) {
      this.problems[key] = "Start the link with / for a page on this site, or https:// for another.";
      return value;
    }

    try {
      const parsed = new URL(value, "https://sbisecurities.in");

      if (!["http:", "https:", "mailto:", "tel:"].includes(parsed.protocol)) {
        this.problems[key] =
          "Links must be a path, or use http, https, mailto or tel. That scheme is not allowed.";
      }
    } catch {
      this.problems[key] = "That is not a valid link.";
    }

    return value;
  }

  boolean(key: string, fallback = false): boolean {
    const raw = this.body[key];
    return typeof raw === "boolean" ? raw : fallback;
  }

  /** Numeric id, or null. Rejects anything that is not a positive integer. */
  id(key: string, opts: { required?: boolean } = {}): number | null {
    const raw = this.body[key];

    if (raw === null || raw === undefined || raw === "") {
      if (opts.required) this.problems[key] = "This field is required.";
      return null;
    }

    const value = Number(raw);

    if (!Number.isInteger(value) || value <= 0) {
      this.problems[key] = "Must be a valid id.";
      return null;
    }

    return value;
  }

  idList(key: string): number[] {
    const raw = this.body[key];

    if (!Array.isArray(raw) || raw.length === 0) {
      this.problems[key] = "Expected a non-empty list of ids.";
      return [];
    }

    const values = raw.map(Number);

    if (values.some((v) => !Number.isInteger(v) || v <= 0)) {
      this.problems[key] = "List contains an invalid id.";
      return [];
    }

    return values;
  }

  stringList(key: string, opts: { max?: number } = {}): string[] {
    const raw = this.body[key];

    if (raw === undefined || raw === null) return [];

    if (!Array.isArray(raw)) {
      this.problems[key] = "Expected a list.";
      return [];
    }

    const values = raw
      .map((v) => (typeof v === "string" ? v.trim() : ""))
      .filter((v) => v.length > 0);

    if (opts.max && values.length > opts.max) {
      this.problems[key] = `At most ${opts.max} entries.`;
    }

    return values;
  }

  /** Throws with everything collected so far, or returns cleanly. */
  done(): void {
    if (Object.keys(this.problems).length > 0) {
      throw new ValidationError(this.problems);
    }
  }
}

/** Route params are strings; ids from the URL need the same guard as body ids. */
export function parseId(raw: string | undefined, label = "id"): number {
  const value = Number(raw);

  if (!Number.isInteger(value) || value <= 0) {
    throw new ValidationError({ [label]: "Must be a valid id." }, `Invalid ${label}.`);
  }

  return value;
}
