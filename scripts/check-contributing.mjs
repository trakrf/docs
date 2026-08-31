#!/usr/bin/env node
// Gives CONTRIBUTING.md a consumer.
//
// Nothing read that file, so it rotted: dead `cp` commands, branch conventions
// nobody followed, a rule contradicting CLAUDE.md. Staleness announces itself
// when someone follows an instruction and it fails — but only if someone does.
// This is that someone. Run from `pnpm lint`, so the validate gate catches drift.

import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const docPath = join(repoRoot, "CONTRIBUTING.md");

// pnpm subcommands that are pnpm's own, not this repo's scripts.
const PNPM_BUILTINS = new Set([
  "install",
  "add",
  "remove",
  "update",
  "dlx",
  "exec",
  "run",
  "why",
  "outdated",
  "audit",
  "store",
  "list",
  "test",
  "start",
  "publish",
]);

// Things that look like paths but are not repo files: URLs, placeholders, and
// absolute paths — a leading slash means an API route (`/api/v1/`), not a file.
const NOT_REPO_PATHS = /^(https?:|\/|<|YOUR_|\.\.?$|node_modules)/;

const text = readFileSync(docPath, "utf8");
const problems = [];

// --- pnpm scripts -----------------------------------------------------------
const pkg = JSON.parse(readFileSync(join(repoRoot, "package.json"), "utf8"));
const scripts = new Set(Object.keys(pkg.scripts ?? {}));

for (const [, name] of text.matchAll(/\bpnpm\s+([a-z][a-z0-9:_-]*)/gi)) {
  if (PNPM_BUILTINS.has(name) || scripts.has(name)) continue;
  problems.push(`pnpm script "${name}" is referenced but not in package.json`);
}

// --- repo-relative paths in inline code spans -------------------------------
// Only inline spans: fenced blocks and prose carry examples, not claims.
const inlineCode = [...text.matchAll(/`([^`\n]+)`/g)].map((m) => m[1].trim());

// A span is a path claim only if it ends in a known file extension or a
// trailing slash. Anything looser also matches branch-name examples such as
// `docs/tra-0000-update-getting-started`, which are illustrations rather than
// claims — and a check that fails on a correct file is a check someone turns
// off.
const FILE_EXT = /\.(md|json|ts|tsx|js|mjs|yml|yaml|sql|sh)$/;

for (const span of inlineCode) {
  const looksLikePath = FILE_EXT.test(span) || span.endsWith("/");
  if (!looksLikePath || NOT_REPO_PATHS.test(span)) continue;
  if (!existsSync(join(repoRoot, span))) {
    problems.push(`path \`${span}\` is referenced but does not exist`);
  }
}

// --- report -----------------------------------------------------------------
if (problems.length > 0) {
  console.error("CONTRIBUTING.md references things that no longer exist:\n");
  for (const p of [...new Set(problems)]) console.error(`  - ${p}`);
  console.error(
    "\nFix the file or the reference. This check exists because nothing else\n" +
      "reads CONTRIBUTING.md, so drift here is otherwise silent.",
  );
  process.exit(1);
}

console.log("CONTRIBUTING.md: all referenced scripts and paths resolve.");
