#!/usr/bin/env node
// Emit static/health.json from CF Pages env vars (with a git fallback
// for local builds) + a committed snapshot of platform /health at
// static/api/platform-meta.json. Runs as the npm `prebuild` hook.
import { readFileSync, writeFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const platformMetaPath = resolve(repoRoot, "static/api/platform-meta.json");
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

function readPlatformMeta() {
  let raw;
  try {
    raw = readFileSync(platformMetaPath, "utf8");
  } catch (err) {
    if (err.code === "ENOENT") {
      console.warn(
        `WARN: ${platformMetaPath} not found; emitting platform: null`,
      );
      return null;
    }
    throw err;
  }
  try {
    return JSON.parse(raw);
  } catch (err) {
    console.warn(
      `WARN: ${platformMetaPath} is not valid JSON (${err.message}); emitting platform: null`,
    );
    return null;
  }
}

const health = {
  docs: {
    commit: resolveDocsCommit(),
    build_time: new Date().toISOString(),
  },
  platform: readPlatformMeta(),
};

writeFileSync(outPath, JSON.stringify(health, null, 2) + "\n");
console.log(`Wrote ${outPath}`);
