#!/usr/bin/env node
// Regenerate static/api/trakrf-api.postman_collection.json from the
// committed OpenAPI spec. Runs as the npm `prebuild` hook so the
// downloadable collection in every build matches the spec in the same
// commit — eliminating the static-artifact-drift class.
//
// Also invoked by scripts/refresh-openapi.sh after a spec pull so the
// committed copy stays current for local dev (where `pnpm dev` doesn't
// run prebuild).
import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const specPath = resolve(repoRoot, "static/api/openapi.json");
const outPath = resolve(
  repoRoot,
  "static/api/trakrf-api.postman_collection.json",
);
const cliPath = resolve(
  repoRoot,
  "node_modules/openapi-to-postmanv2/bin/openapi2postmanv2.js",
);

execFileSync(
  process.execPath,
  [cliPath, "-s", specPath, "-o", outPath, "-p", "-O", "folderStrategy=Paths"],
  { stdio: "inherit" },
);
