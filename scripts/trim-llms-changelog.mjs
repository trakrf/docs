#!/usr/bin/env node
// Trims the API changelog inside the single-file agent docs after build.
//
// The changelog is the largest page on the site, and almost all of it is
// pre-launch history. Agents loading llms-full.txt or llms-api.txt get the
// newest entries and a link to the full changelog; the per-page Markdown
// mirror (build/docs/api/changelog.md) is left complete. The llms plugin has
// no per-page trimming, hence a post-build step.

import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const KEEP_ENTRIES = 8;
const buildDir = resolve("build");
const targets = ["llms-full.txt", "llms-api.txt"];

const index = await readFile(resolve(buildDir, "llms.txt"), "utf8");
const changelogUrl = index.match(/\]\((\S+\/docs\/api\/changelog\.md)\)/)?.[1];
if (!changelogUrl) throw new Error("llms.txt has no link to the changelog");

for (const name of targets) {
  const path = resolve(buildDir, name);
  const text = await readFile(path, "utf8");
  const start = text.search(/^## Changelog$/m);
  if (start === -1) throw new Error(`${name} has no "## Changelog" section`);
  const sepAt = text.indexOf("\n---\n", start);
  const end = sepAt === -1 ? text.length : sepAt;
  const section = text.slice(start, end);

  // Entry headings are level 3 and deeper inside the section, newest first.
  const headings = [...section.matchAll(/^#{3,} .*$/gm)];
  if (headings.length <= KEEP_ENTRIES) continue;
  const cut = headings[KEEP_ENTRIES].index;
  const dropped = headings.length - KEEP_ENTRIES;
  const trimmed =
    section.slice(0, cut).trimEnd() +
    `\n\nOlder changelog entries: ${changelogUrl} (${dropped} more entries).\n`;

  await writeFile(path, text.slice(0, start) + trimmed + text.slice(end));
  console.log(
    `${name}: changelog trimmed to ${KEEP_ENTRIES} entries (${dropped} linked).`,
  );
}
