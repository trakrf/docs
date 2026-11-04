// The TrakRF tag allocation register: one row per standard-pool block, one
// row per namespace code. Shared by the allocator (scripts/allocate-tags.mjs)
// and the lint check (scripts/check-tag-allocations.mjs) so both apply the
// same rules. The public page docs/integrations/tag-allocations.md is
// rendered from these files and must never be edited by hand.

import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import * as prettier from "prettier";

export const repoRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  "../..",
);
export const defaultDataDir = join(repoRoot, "data/tag-allocations");
export const pagePath = join(repoRoot, "docs/integrations/tag-allocations.md");

export const SEQ_MIN = 10000001;
export const SEQ_MAX = 99999999;
export const STANDARD_PREFIX = "355E4ACFD000" + "0000";
const BLOCK_COLUMNS = [
  "block_id",
  "first",
  "last",
  "ordered_qty",
  "buffer_pct",
  "tag_type",
  "last_used",
  "status",
];
const NAMESPACE_COLUMNS = ["code", "status", "note"];
const BLOCK_STATUSES = new Set(["issued", "closed", "void"]);
const NAMESPACE_STATUSES = new Set([
  "standard",
  "reserved",
  "active",
  "retired",
]);
const BLOCK_ID = /^([A-Za-z0-9]+)-L(\d+)$/;

// --- CSV ------------------------------------------------------------------

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') ((field += '"'), i++);
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") (row.push(field), (field = ""));
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      (row.push(field), rows.push(row), (row = []), (field = ""));
    } else field += c;
  }
  if (field !== "" || row.length) (row.push(field), rows.push(row));
  return rows;
}

function csvField(value) {
  const s = String(value ?? "");
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function toCsv(columns, records) {
  const lines = [columns.join(",")];
  for (const r of records)
    lines.push(columns.map((c) => csvField(r[c])).join(","));
  return lines.join("\n") + "\n";
}

async function readTable(path, columns) {
  const rows = parseCsv(await readFile(path, "utf8"));
  const [header, ...body] = rows;
  if (header?.join(",") !== columns.join(","))
    throw new Error(`${path}: header must be ${columns.join(",")}`);
  return body.map((cells, i) => {
    if (cells.length !== columns.length)
      throw new Error(
        `${path}: row ${i + 2} has ${cells.length} fields, expected ${columns.length}`,
      );
    return Object.fromEntries(columns.map((c, j) => [c, cells[j]]));
  });
}

export async function readRegister(dataDir = defaultDataDir) {
  return {
    blocks: await readTable(join(dataDir, "blocks.csv"), BLOCK_COLUMNS),
    namespaces: await readTable(
      join(dataDir, "namespaces.csv"),
      NAMESPACE_COLUMNS,
    ),
  };
}

export async function writeBlocks(blocks, dataDir = defaultDataDir) {
  await writeFile(join(dataDir, "blocks.csv"), toCsv(BLOCK_COLUMNS, blocks));
}

// --- Rules ----------------------------------------------------------------

export const bufferFor = (qty, pct) => Math.ceil((qty * pct) / 100);

const isSeq = (s) => /^[0-9]{8}$/.test(s) && +s >= SEQ_MIN && +s <= SEQ_MAX;

export function validate({ blocks, namespaces }) {
  const errors = [];
  const ids = new Set();
  let expectedFirst = SEQ_MIN;
  for (const [i, b] of blocks.entries()) {
    const at = `blocks.csv row ${i + 2} (${b.block_id || "no id"})`;
    if (!BLOCK_ID.test(b.block_id))
      errors.push(`${at}: block_id must look like <order>-L<line>`);
    if (ids.has(b.block_id)) errors.push(`${at}: duplicate block_id`);
    ids.add(b.block_id);
    for (const f of ["first", "last"])
      if (!isSeq(b[f]))
        errors.push(`${at}: ${f} must be 8 digits in ${SEQ_MIN}–${SEQ_MAX}`);
    if (!/^[1-9][0-9]*$/.test(b.ordered_qty))
      errors.push(`${at}: ordered_qty must be a positive integer`);
    if (!/^[0-9]+$/.test(b.buffer_pct))
      errors.push(`${at}: buffer_pct must be a whole number`);
    if (!BLOCK_STATUSES.has(b.status))
      errors.push(`${at}: status must be issued, closed or void`);
    if (b.last_used !== "" && !isSeq(b.last_used))
      errors.push(`${at}: last_used must be empty or 8 digits`);
    if (+b.first !== expectedFirst)
      errors.push(
        `${at}: first is ${b.first}, expected ${expectedFirst} (blocks must be contiguous, no gaps or overlaps)`,
      );
    const size = +b.ordered_qty + bufferFor(+b.ordered_qty, +b.buffer_pct);
    if (+b.last - +b.first + 1 !== size)
      errors.push(
        `${at}: range holds ${+b.last - +b.first + 1} numbers, ordered_qty + buffer is ${size}`,
      );
    if (
      b.last_used !== "" &&
      (+b.last_used < +b.first || +b.last_used > +b.last)
    )
      errors.push(
        `${at}: last_used ${b.last_used} is outside ${b.first}–${b.last}`,
      );
    if (b.status === "closed" && b.last_used === "")
      errors.push(`${at}: closed requires last_used`);
    expectedFirst = +b.last + 1;
  }
  const codes = new Set();
  for (const [i, n] of namespaces.entries()) {
    const at = `namespaces.csv row ${i + 2} (${n.code || "no code"})`;
    if (!/^[0-9A-F]{3}$/.test(n.code))
      errors.push(`${at}: code must be 3 uppercase hex characters`);
    if (codes.has(n.code)) errors.push(`${at}: duplicate code`);
    codes.add(n.code);
    if (!NAMESPACE_STATUSES.has(n.status))
      errors.push(
        `${at}: status must be standard, reserved, active or retired`,
      );
    if (n.code === "000" && n.status !== "standard")
      errors.push(`${at}: 000 must be standard`);
    if (n.code === "0A5" && n.status === "active")
      errors.push(
        `${at}: 0A5 is the documentation example and is never active`,
      );
  }
  if (!codes.has("000"))
    errors.push("namespaces.csv: 000 (standard pool) is missing");
  return errors;
}

// --- Allocation and export -----------------------------------------------

export function nextFirst(blocks) {
  return blocks.length ? Math.max(...blocks.map((b) => +b.last)) + 1 : SEQ_MIN;
}

export const epcFor = (sequence) => STANDARD_PREFIX + String(sequence);

export function exportRows(block) {
  const [, order, line] = block.block_id.match(BLOCK_ID);
  const orderedLast = +block.first + +block.ordered_qty - 1;
  const rows = [];
  for (let seq = +block.first; seq <= +block.last; seq++) {
    rows.push({
      order,
      line,
      roll: 1,
      tag_type: block.tag_type,
      sequence: seq,
      epc_hex: epcFor(seq),
      barcode: seq,
      human_readable: seq,
      overrun: seq > orderedLast ? "yes" : "no",
    });
  }
  return rows;
}

export const EXPORT_COLUMNS = [
  "order",
  "line",
  "roll",
  "tag_type",
  "sequence",
  "epc_hex",
  "barcode",
  "human_readable",
  "overrun",
];

// --- Page -----------------------------------------------------------------

const cell = (s) => String(s).replace(/\|/g, "\\|");

export async function renderPage({ blocks, namespaces }) {
  const blockRows = blocks.map((b) => {
    const buffer = +b.last - +b.first + 1 - +b.ordered_qty;
    return `| ${cell(b.block_id)} | ${b.first} | ${b.last} | ${b.ordered_qty} | ${buffer} | ${cell(b.tag_type)} | ${b.status} | ${b.last_used || "—"} |`;
  });
  const nsRows = namespaces.map(
    (n) => `| \`${n.code}\` | ${n.status} | ${cell(n.note)} |`,
  );
  const md = `---
# Generated by scripts/allocate-tags.mjs from data/tag-allocations/. Do not edit:
# pnpm lint fails if this page and the data disagree.
sidebar_position: 5
title: Tag allocation register
description: Every block of TrakRF standard-pool tag numbers issued so far, and every namespace code assigned.
---

# Tag allocation register

Every block of [standard-pool](./tag-numbering#how-the-numbers-are-issued) tag numbers TrakRF has issued, and every namespace code assigned. Numbers are drawn from one global counter, in order, and never reissued.

## Standard-pool blocks

The next block starts at **${nextFirst(blocks)}**.

| Block | First | Last | Ordered | Buffer | Tag type | Status | Last used |
| --- | --- | --- | --- | --- | --- | --- | --- |
${blockRows.join("\n")}

- **Ordered** is the first part of the block; **Buffer** is the overrun allowance at its end.
- **Status**: \`issued\` (with the bureau), \`closed\` (last number used reported, the rest retired), or \`void\` (cancelled, never reissued).

## Namespaces

| Code | Status | Note |
| --- | --- | --- |
${nsRows.join("\n")}

Customer namespaces control their own sequencing, so they have no blocks here. A code is never reassigned, even after a customer leaves.
`;
  const config = (await prettier.resolveConfig(pagePath)) ?? {};
  return prettier.format(md, { ...config, filepath: pagePath });
}

export async function writePage(register) {
  await writeFile(pagePath, await renderPage(register));
}
