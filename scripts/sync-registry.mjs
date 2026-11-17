#!/usr/bin/env node
/**
 * Writes the inner pages' registry into cms-backend.
 *
 *   node scripts/sync-registry.mjs
 *
 * src/server/cms/pages.ts is the one description of what About, Leadership and
 * Sector contain. The Go API validates against registry.json's `pages` member,
 * so that member is generated from pages.ts rather than kept by hand — which
 * is how the two used to drift apart for the home folds. Only `pages` is
 * touched; the home members of registry.json are left exactly as they are.
 *
 *   CMS_BACKEND_DIR   path to cms-backend (default D:\tmp\cms-backend)
 *   --check           fail instead of writing when registry.json is out of date
 */

import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import ts from "typescript";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BACKEND = process.env.CMS_BACKEND_DIR ?? "D:/tmp/cms-backend";
const TARGET = path.join(BACKEND, "internal", "cms", "registry.json");
const SOURCE = path.join(ROOT, "src", "server", "cms", "pages.ts");
const check = process.argv.includes("--check");

const js = ts.transpileModule(readFileSync(SOURCE, "utf8"), {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
}).outputText.replace(/^import .*$/gm, ""); // type-only import of ./registry

const dir = mkdtempSync(path.join(tmpdir(), "sbi-registry-"));
const file = path.join(dir, "pages.mjs");
writeFileSync(file, js, "utf8");
const { CONTENT_PAGES } = await import(pathToFileURL(file).href);

/* The Go side's field struct has no zero-value surprises: undefined keys are
   dropped by JSON.stringify, which is what `omitempty` wants. */
const pages = JSON.parse(JSON.stringify(CONTENT_PAGES));

const raw = readFileSync(TARGET, "utf8");
const eol = raw.includes("\r\n") ? "\r\n" : "\n";
const registry = JSON.parse(raw);

if (JSON.stringify(registry.pages ?? null) === JSON.stringify(pages)) {
  console.log("registry.json is up to date.");
  process.exit(0);
}
if (check) {
  console.error("registry.json is out of date. Run: node scripts/sync-registry.mjs");
  process.exit(1);
}

registry.pages = pages;
writeFileSync(TARGET, JSON.stringify(registry, null, 2).replace(/\n/g, eol) + eol, "utf8");
console.log(`Wrote ${Object.keys(pages).length} pages to ${TARGET}`);
