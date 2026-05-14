#!/usr/bin/env node
// Rewrite info.contact.url in the build/api/openapi.{json,yaml} artifacts
// from the production canonical (https://app.trakrf.id/api) to the preview
// host (https://app.preview.trakrf.id/api) when this build resolves to the
// preview environment. Mirrors the runtime swap the platform service does
// for app.preview.trakrf.id/api/v1/openapi.* — keeps the docs-site copy
// served at docs.preview.trakrf.id/api/openapi.* byte-identical to the
// service-served copy, so BB's spec-sync preflight succeeds.
//
// Source files in static/ are never mutated; the swap lands in build/ only.
// Runs as the npm `postbuild` hook.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const buildApiDir = resolve(repoRoot, "build/api");

// Mirrors resolveDeployEnv() in docusaurus.config.ts. Kept duplicated rather
// than imported because that file is TypeScript and this hook runs in plain
// node before any TS toolchain has loaded.
function resolveDeployEnv() {
  const explicit = process.env.DEPLOY_ENV;
  if (explicit === "production" || explicit === "preview") return explicit;
  if (process.env.CF_PAGES_BRANCH === "main") return "production";
  if (process.env.CF_PAGES === "1") return "preview";
  return "preview";
}

const deployEnv = resolveDeployEnv();
if (deployEnv !== "preview") {
  console.log(`[swap-openapi-env] deployEnv=${deployEnv}; no swap.`);
  process.exit(0);
}

const PROD_URL = "https://app.trakrf.id/api";
const PREVIEW_URL = "https://app.preview.trakrf.id/api";

const targets = ["openapi.json", "openapi.yaml"].map((name) =>
  resolve(buildApiDir, name),
);

let swapped = 0;
for (const file of targets) {
  if (!existsSync(file)) {
    console.warn(`[swap-openapi-env] missing ${file}; skipping`);
    continue;
  }
  const before = readFileSync(file, "utf8");
  if (!before.includes(PROD_URL)) {
    console.warn(
      `[swap-openapi-env] ${file} has no production contact URL to swap; skipping`,
    );
    continue;
  }
  const after = before.split(PROD_URL).join(PREVIEW_URL);
  writeFileSync(file, after);
  swapped++;
}

console.log(
  `[swap-openapi-env] deployEnv=preview; rewrote info.contact.url in ${swapped} file(s).`,
);
