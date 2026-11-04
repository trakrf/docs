#!/usr/bin/env node
// Decodes every example EPC on the tag numbering page, so an example is never
// checked by eye. Bureaus encode from this page, and a wrong URN or a
// mis-laid field there ends up in the chip. Run from `pnpm lint`.
//
// Rules:
//   - every 24-hex-character value is a GID-96 EPC under manager 98872573
//   - an EPC followed by a URN on one line (arrow or table row) decodes to it
//   - every URN on the page is the decoding of some EPC on the page
//   - a standard-pool EPC (namespace 000) has 0000 reserved and an 8-digit
//     decimal sequence, 10000001–99999999

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const pagePath = join(repoRoot, "docs/integrations/tag-numbering.md");
const page = readFileSync(pagePath, "utf8");

const MANAGER = 98872573n;
const EPC_RE = /(?<![0-9A-Fa-f])[0-9A-Fa-f]{24}(?![0-9A-Fa-f])/g;
const URN_RE = /urn:epc:id:gid:\d+\.\d+\.\d+/g;

function decode(epc) {
  const v = BigInt(`0x${epc}`);
  const header = v >> 88n;
  const manager = (v >> 60n) & ((1n << 28n) - 1n);
  const objectClass = (v >> 36n) & ((1n << 24n) - 1n);
  const serial = v & ((1n << 36n) - 1n);
  return {
    header,
    manager,
    urn: `urn:epc:id:gid:${manager}.${objectClass}.${serial}`,
  };
}

const errors = [];
const epcs = [...new Set(page.match(EPC_RE) ?? [])];
if (epcs.length === 0) errors.push("no example EPC found on the page");

const decoded = new Set();
for (const epc of epcs) {
  if (epc !== epc.toUpperCase())
    errors.push(`${epc}: write EPCs in uppercase hex`);
  const d = decode(epc);
  decoded.add(d.urn);
  if (d.header !== 0x35n) errors.push(`${epc}: header is not 35 (GID-96)`);
  if (d.manager !== MANAGER)
    errors.push(`${epc}: manager number is ${d.manager}, not ${MANAGER}`);
  if (epc.slice(9, 12) === "000") {
    if (epc.slice(12, 16) !== "0000")
      errors.push(
        `${epc}: standard pool, reserved characters 13–16 are not 0000`,
      );
    if (!/^[1-9][0-9]{7}$/.test(epc.slice(16)))
      errors.push(
        `${epc}: standard pool, sequence is not 8 decimal digits from 10000001`,
      );
  }
}

for (const [i, line] of page.split("\n").entries()) {
  const pair = /([0-9A-F]{24})[^0-9A-Za-z]*(urn:epc:id:gid:\d+\.\d+\.\d+)/g;
  for (const [, epc, urn] of line.matchAll(pair)) {
    const want = decode(epc).urn;
    if (urn !== want)
      errors.push(`line ${i + 1}: ${epc} decodes to ${want}, page says ${urn}`);
  }
}

for (const urn of new Set(page.match(URN_RE) ?? [])) {
  if (!decoded.has(urn))
    errors.push(`${urn}: not the decoding of any EPC on the page`);
}

if (errors.length) {
  console.error(
    `docs/integrations/tag-numbering.md: ${errors.length} problem(s)`,
  );
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log(
  `tag-numbering.md: ${epcs.length} example EPC(s) decode as stated.`,
);
