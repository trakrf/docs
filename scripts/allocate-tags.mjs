#!/usr/bin/env node
// Issues TrakRF standard-pool tag numbers. Every allocation goes through this
// script and a pull request; nobody edits blocks.csv by hand to issue numbers.
//
//   allocate --block-id PO1234-L1 --qty 2500 [--buffer 5] --tag-type "Avery Web"
//   export   --block-id PO1234-L1 [--out file.csv]   per-tag bureau file
//   close    --block-id PO1234-L1 --last-used 10002590
//   page                                             re-render the register page
//
// --data DIR works on another copy of the register (tests); the public page is
// only re-rendered for the real one.

import { writeFile } from "node:fs/promises";
import {
  EXPORT_COLUMNS,
  SEQ_MAX,
  bufferFor,
  defaultDataDir,
  exportRows,
  nextFirst,
  readRegister,
  toCsv,
  validate,
  writeBlocks,
  writePage,
} from "./lib/tag-allocations.mjs";

const [command, ...rest] = process.argv.slice(2);
const opts = {};
for (let i = 0; i < rest.length; i += 2) {
  if (!rest[i].startsWith("--")) fail(`unexpected argument ${rest[i]}`);
  opts[rest[i].slice(2)] = rest[i + 1];
}
const dataDir = opts.data ?? defaultDataDir;

function fail(message) {
  console.error(`allocate-tags: ${message}`);
  process.exit(1);
}
function need(name) {
  if (opts[name] === undefined || opts[name] === "")
    fail(`--${name} is required`);
  return opts[name];
}

const register = await readRegister(dataDir);
const existing = validate(register);
if (existing.length)
  fail(`register is inconsistent, fix it first:\n  ${existing.join("\n  ")}`);
const findBlock = (id) =>
  register.blocks.find((b) => b.block_id === id) ?? fail(`no block ${id}`);

async function save() {
  const errors = validate(register);
  if (errors.length)
    fail(
      `refusing to write an inconsistent register:\n  ${errors.join("\n  ")}`,
    );
  await writeBlocks(register.blocks, dataDir);
  if (dataDir === defaultDataDir) await writePage(register);
}

switch (command) {
  case "allocate": {
    const id = need("block-id");
    const qty = Number(need("qty"));
    const pct = Number(opts.buffer ?? 5);
    const tagType = need("tag-type");
    if (!Number.isInteger(qty) || qty < 1)
      fail("--qty must be a positive integer");
    if (!Number.isInteger(pct) || pct < 0)
      fail("--buffer must be a whole percentage");
    if (register.blocks.some((b) => b.block_id === id))
      fail(`block ${id} already exists`);
    const first = nextFirst(register.blocks);
    const last = first + qty + bufferFor(qty, pct) - 1;
    if (last > SEQ_MAX) fail(`block would end at ${last}, past ${SEQ_MAX}`);
    register.blocks.push({
      block_id: id,
      first: String(first),
      last: String(last),
      ordered_qty: String(qty),
      buffer_pct: String(pct),
      tag_type: tagType,
      last_used: "",
      status: "issued",
    });
    await save();
    console.log(
      `${id}: ${first}–${last} (${qty} ordered + ${last - first + 1 - qty} buffer)`,
    );
    break;
  }
  case "export": {
    const csv = toCsv(EXPORT_COLUMNS, exportRows(findBlock(need("block-id"))));
    if (opts.out) await writeFile(opts.out, csv);
    else process.stdout.write(csv);
    break;
  }
  case "close": {
    const block = findBlock(need("block-id"));
    const lastUsed = need("last-used");
    if (block.status !== "issued")
      fail(`${block.block_id} is ${block.status}, not issued`);
    if (
      !/^[0-9]{8}$/.test(lastUsed) ||
      +lastUsed < +block.first ||
      +lastUsed > +block.last
    )
      fail(`--last-used must be within ${block.first}–${block.last}`);
    block.last_used = lastUsed;
    block.status = "closed";
    await save();
    console.log(
      `${block.block_id}: closed at ${lastUsed}; ${+block.last - +lastUsed} numbers retired`,
    );
    break;
  }
  case "page":
    if (dataDir !== defaultDataDir) fail("page renders the real register only");
    await writePage(register);
    console.log("docs/integrations/tag-allocations.md re-rendered");
    break;
  default:
    fail(
      "usage: allocate | export | close | page (see the header of this script)",
    );
}
