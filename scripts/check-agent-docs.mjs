import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const buildDir = resolve("build");
const requiredFiles = ["llms.txt", "llms-full.txt", "llms-api.txt"];
const markdownFiles = [
  "docs/api/authentication.md",
  "docs/api/errors.md",
  "docs/api/design-notes.md",
  "docs/api/quickstart.md",
];

async function readBuildFile(file) {
  try {
    return await readFile(resolve(buildDir, file), "utf8");
  } catch (error) {
    throw new Error(`Missing build/${file}: ${error.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const files = new Map(
  await Promise.all(
    [...requiredFiles, ...markdownFiles].map(async (file) => [
      file,
      await readBuildFile(file),
    ]),
  ),
);

const llms = files.get("llms.txt");
const api = files.get("llms-api.txt");

assert(
  /\[[^\]]+\]\([^\s)]+\.md\)/.test(llms),
  "llms.txt does not link to Markdown mirrors",
);
assert(api.includes("TrakRF API"), "llms-api.txt does not contain API content");
assert(
  !/\/docs\/(?:user-guide|app-tour)\//.test(api),
  "llms-api.txt includes user-guide or app-tour content",
);

for (const file of markdownFiles) {
  assert(
    !/^\s*<!doctype html/i.test(files.get(file)),
    `build/${file} is an HTML document, not Markdown`,
  );
}

console.log("Agent documentation build output is complete and API-scoped.");
