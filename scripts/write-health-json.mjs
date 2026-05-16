#!/usr/bin/env node
// Emit static/health.json from CF Pages env vars (with a git fallback for
// local builds). Runs as the npm `prebuild` hook.
//
// The docs `/health.json` carries only the docs build identity. Spec/build
// version for the API itself lives on the platform side at
// `https://app.{env}.trakrf.id/health.json` — there is no longer a mirrored
// `platform` block here.
import { writeFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const outPath = resolve(repoRoot, "static/health.json");

function resolveDocsCommit() {
  // CF Pages does shallow checkouts; env var is the right default.
  const cfSha = process.env.CF_PAGES_COMMIT_SHA;
  if (cfSha) return cfSha.slice(0, 7);
  try {
    return execSync("git rev-parse --short HEAD", {
      stdio: ["ignore", "pipe", "ignore"],
    })
      .toString()
      .trim();
  } catch {
    return "unknown";
  }
}

const health = {
  docs: {
    commit: resolveDocsCommit(),
    build_time: new Date().toISOString(),
  },
};

writeFileSync(outPath, JSON.stringify(health, null, 2) + "\n");
console.log(`Wrote ${outPath}`);
