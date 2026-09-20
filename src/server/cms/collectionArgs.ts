import "server-only";

import { callFunctionOne } from "@/server/db/pool";
import { NotFoundError, ValidationError } from "@/server/api/respond";
import type { CollectionDef, FieldDef } from "@/server/cms/registry";

/**
 * Turns a JSON body into the positional argument list a stored function takes.
 *
 * The order comes from the registry's `createArgs` / `updateArgs`, which are
 * written to match the SQL exactly. Nothing here builds SQL text: the values
 * become bound parameters in `callFunction`, and the function name comes from
 * the registry's literal `fnPrefix`.
 *
 * Validation is per field and collected, not thrown on the first problem, so
 * a drawer reports every bad input at once.
 */

const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Schemes a stored link may use. Anything else is refused on save. */
const LINK_SCHEMES = ["http:", "https:", "mailto:", "tel:"];

interface Coerced {
  value: unknown;
  problem?: string;
}

function coerce(field: FieldDef, raw: unknown): Coerced {
  switch (field.kind) {
    case "text":
    case "textarea": {
      const value = typeof raw === "string" ? raw.trim() : "";
      if (field.required && !value) return { value, problem: "This field is required." };
      if (field.max && value.length > field.max) {
        return { value, problem: `Must be ${field.max} characters or fewer.` };
      }
      return { value };
    }

    case "href": {
      const value = typeof raw === "string" ? raw.trim() : "";

      if (!value) {
        return field.required ? { value, problem: "This field is required." } : { value: null };
      }

      /* A path or a fragment on this site. */
      if (value.startsWith("#") || (value.startsWith("/") && !value.startsWith("//"))) {
        return { value };
      }

      if (value.startsWith("//")) {
        return {
          value,
          problem: "Start with / for a page on this site, or https:// for another.",
        };
      }

      try {
        const parsed = new URL(value, "https://sbisecurities.in");

        if (!LINK_SCHEMES.includes(parsed.protocol)) {
          /* javascript:, data: and vbscript: all land here. Stored, they
             would run on the public site the moment the link is rendered. */
          return {
            value,
            problem: "Use a path, or an http, https, mailto or tel link.",
          };
        }

        return { value };
      } catch {
        return { value, problem: "That is not a valid link." };
      }
    }

    case "slug": {
      const value = typeof raw === "string" ? raw.trim().toLowerCase() : "";
      if (!value) {
        return field.required
          ? { value, problem: "This field is required." }
          : { value: null };
      }
      if (!SLUG.test(value)) {
        return { value, problem: "Use lowercase letters, numbers and hyphens." };
      }
      return { value };
    }

    case "select": {
      const value = typeof raw === "string" ? raw.trim() : "";
      if (!value && !field.required) return { value: null };
      if (!field.options?.includes(value)) {
        return { value, problem: `Choose one of: ${field.options?.join(", ")}.` };
      }
      return { value };
    }

    case "lines": {
      if (raw === null || raw === undefined) return { value: [] };
      if (!Array.isArray(raw)) return { value: [], problem: "Expected a list of lines." };
      const value = raw
        .map((line) => (typeof line === "string" ? line.trim() : ""))
        .filter((line) => line.length > 0);
      return { value };
    }

    case "number": {
      if (raw === null || raw === undefined || raw === "") {
        return field.required ? { value: null, problem: "This field is required." } : { value: null };
      }
      const value = Number(raw);
      if (!Number.isFinite(value)) return { value: null, problem: "Must be a number." };
      return { value };
    }

    case "boolean":
      return { value: typeof raw === "boolean" ? raw : false };

    case "media": {
      if (raw === null || raw === undefined || raw === "") return { value: null };
      const value = Number(raw);
      if (!Number.isInteger(value) || value <= 0) {
        return { value: null, problem: "Pick an image from the library." };
      }
      return { value };
    }

    case "date": {
      if (raw === null || raw === undefined || raw === "") return { value: null };
      const value = String(raw).trim();
      if (!ISO_DATE.test(value)) return { value: null, problem: "Use the date picker." };
      return { value };
    }

    case "datetime": {
      if (raw === null || raw === undefined || raw === "") return { value: null };
      const parsed = new Date(String(raw));
      if (Number.isNaN(parsed.getTime())) return { value: null, problem: "Not a valid date and time." };
      return { value: parsed.toISOString() };
    }

    default:
      return { value: null };
  }
}

/**
 * `display_order` and `is_lead` are in an argument list but are not editable
 * fields: order is decided by where a row is appended (and changed by the
 * reorder endpoint), and the lead story is set through its own call so two
 * rows cannot both claim the slot.
 */
const IMPLICIT: Record<string, unknown> = {
  display_order: null, // the function appends to the end
  is_lead: false,
};

export function buildArgs(
  def: CollectionDef,
  body: Record<string, unknown>,
  mode: "create" | "update",
): unknown[] {
  const order = mode === "create" ? def.createArgs : def.updateArgs;
  const problems: Record<string, string> = {};
  const args: unknown[] = [];

  for (const name of order) {
    if (name in IMPLICIT && !def.fields.some((field) => field.name === name)) {
      args.push(IMPLICIT[name]);
      continue;
    }

    const field = def.fields.find((candidate) => candidate.name === name);

    if (!field) {
      /* An argument the registry lists but describes no field for. That is a
         registry bug rather than a bad request, and guessing a value would
         write something nobody chose. */
      throw new Error(`Registry lists argument "${name}" for ${def.fnPrefix} with no field.`);
    }

    const { value, problem } = coerce(field, body[field.name]);
    if (problem) problems[field.name] = problem;
    args.push(value);
  }

  if (Object.keys(problems).length > 0) throw new ValidationError(problems);

  return args;
}

/* --- parents -------------------------------------------------------------- */

interface ParentRow {
  id: string | number;
}

/**
 * Resolves the id a `_list`, `_create` or `_reorder` hangs off.
 *
 * `section` is derived from the URL, so a caller cannot point a fold's rows at
 * another fold. The nested kinds (tab, card, plan, hero) take an id from the
 * query string, because only the caller knows which tab is open; the foreign
 * key keeps them honest, and every caller here is an authenticated
 * administrator.
 */
export async function resolveParentId(
  def: CollectionDef,
  section: string,
  fromQuery: string | null,
): Promise<number | null> {
  if (def.parent === "none") return null;

  if (def.parent === "section") {
    const row = await callFunctionOne<{ section_id_for: string | null }>("cms.section_id_for", [
      "home",
      section,
    ]);
    const id = row?.section_id_for ? Number(row.section_id_for) : null;
    if (!id) throw new NotFoundError(`No section "${section}" on the home page.`);
    return id;
  }

  if (def.parent === "hero") {
    const hero = await callFunctionOne<ParentRow>("cms.hero_get", ["home"]);
    if (!hero) throw new NotFoundError("The home page has no hero yet.");
    return Number(hero.id);
  }

  const id = Number(fromQuery);

  if (!Number.isInteger(id) || id <= 0) {
    throw new ValidationError(
      { parent: "Required." },
      `This list belongs to a ${def.parent}; pass ?parent=<id>.`,
    );
  }

  return id;
}
