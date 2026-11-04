#!/usr/bin/env node
// Lint gate for the tag allocation register. Uniqueness of every TrakRF tag
// number rests on data/tag-allocations/blocks.csv being contiguous and
// consistent, and the public register page being exactly what that data
// renders. Run from `pnpm lint`. `--data DIR` checks another copy (tests).

import { readFile } from "node:fs/promises";
import {
  defaultDataDir,
  pagePath,
  readRegister,
  renderPage,
  validate,
} from "./lib/tag-allocations.mjs";

const dataFlag = process.argv.indexOf("--data");
const dataDir = dataFlag === -1 ? defaultDataDir : process.argv[dataFlag + 1];

const register = await readRegister(dataDir);
const errors = validate(register);

if (dataDir === defaultDataDir) {
  const onDisk = await readFile(pagePath, "utf8").catch(() => "");
  if (onDisk !== (await renderPage(register)))
    errors.push(
      "docs/integrations/tag-allocations.md does not match the data; run `node scripts/allocate-tags.mjs page`",
    );
}

if (errors.length) {
  console.error(`Tag allocation register: ${errors.length} problem(s)`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(
  `Tag allocation register: ${register.blocks.length} block(s), ${register.namespaces.length} namespace(s), consistent.`,
);
