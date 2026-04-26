# TRA-508 — Build-time `health.json` for docs deploy + spec version spot-checks

**Status:** Design approved 2026-04-26
**Linear:** [TRA-508](https://linear.app/trakrf/issue/TRA-508)
**Branch:** `miks2u/tra-508-add-build-time-healthjson` (worktree at `.worktrees/tra-508-health-json`)

## Problem

Two version-tracking gaps on the docs site:

1. No way to confirm which build of `trakrf/docs` is currently deployed at `docs.trakrf.id` / `docs.preview.trakrf.id`.
2. The committed OpenAPI snapshot at `static/api/openapi.json` only carries `info.version: "v1"` (the API contract version). There is no record of _which platform build_ the spec was captured from. Even when `scripts/refresh-openapi.sh` is run regularly, we cannot tell at a glance whether the docs reference is in sync with the platform that produced it.

The platform backend exposes `/health` (`backend/internal/handlers/health/health.go`) returning commit SHA, tag, and build time at runtime. Docusaurus is a static site, so a runtime endpoint is not possible — but a build-time JSON artifact gives equivalent spot-check capability for the docs site, and snapshotting the platform's `/health` at spec-refresh time pins the committed spec to a specific platform build.

## Approach

Two cooperating pieces, no new runtime, no new dependencies:

- **At spec refresh** (developer-triggered, occasional): `scripts/refresh-openapi.sh` is extended to additionally fetch `<SPEC_HOST>/health` and write `static/api/platform-meta.json`. Committed alongside the spec. This is a snapshot, not a live signal.
- **At docs build** (every Cloudflare Pages deploy and every local `pnpm build`): a new `scripts/write-health-json.mjs` runs as the `prebuild` npm script. It reads CF Pages env vars (with a `git` fallback for local builds), reads `static/api/platform-meta.json`, and emits `static/health.json`. Docusaurus copies `static/*` to `build/`, so the file lands at `build/health.json` and serves at `https://docs.trakrf.id/health.json`.

Deploy target is Cloudflare Pages (project `docs`, defined in `trakrf-infra/terraform/cloudflare/pages.tf`). CF Pages exposes `CF_PAGES_COMMIT_SHA`, `CF_PAGES_BRANCH`, `CF_PAGES_URL` at build time and uses shallow checkouts, so env-var-first resolution is the right default.

## Output shape

`/health.json` served by CF Pages:

```json
{
  "docs": {
    "commit": "<short SHA>",
    "build_time": "<ISO-8601 UTC>"
  },
  "platform": {
    "commit": "<from /health snapshot>",
    "tag": "<from /health snapshot>",
    "build_time": "<from /health snapshot>",
    "spec_refreshed_at": "<ISO-8601 UTC, set when refresh-openapi.sh ran>"
  }
}
```

Notes on shape:

- **Dropped from the platform's `/health` shape:** `status`, `uptime`, `database`, `go_version`, `version`, `timestamp`. Liveness for a static CDN-served site is "the CDN is serving the file"; runtime fields don't apply.
- **`docs.tag` omitted for now.** The docs repo has no semver releases (`package.json` is pinned at `0.0.0`, no version tags in `git tag`). Adding an always-empty field is dead weight; it can be added the day docs cuts a release. The asymmetry with `platform.tag` is informative ("docs aren't versioned, platform is").
- **`platform` may be `null`** if `static/api/platform-meta.json` is missing at build time (e.g., before this lands, or if the file is intentionally deleted).

## Components

### `scripts/refresh-openapi.sh` (modified)

After the existing spec `curl`s, fetch `<SPEC_HOST>/health` as a best-effort step:

```bash
# Best-effort: snapshot platform build metadata. Do not abort spec refresh
# on /health failure — the spec is the load-bearing artifact, the metadata
# is a nice-to-have. Existing platform-meta.json is left intact on failure.
echo "Fetching platform /health..."
if health_json=$(curl -fsSL "$SPEC_HOST/health" 2>/dev/null); then
  # `// ""` defaults null/missing fields to empty string so we never
  # write the literal string "null" into platform-meta.json.
  if commit=$(echo "$health_json" | jq -re '.commit // ""') \
     && build_time=$(echo "$health_json" | jq -re '.build_time // ""') \
     && [ -n "$commit" ] && [ -n "$build_time" ]; then
    tag=$(echo "$health_json" | jq -r '.tag // ""')
    spec_refreshed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    jq -n \
      --arg commit "$commit" \
      --arg tag "$tag" \
      --arg build_time "$build_time" \
      --arg spec_refreshed_at "$spec_refreshed_at" \
      '{commit: $commit, tag: $tag, build_time: $build_time, spec_refreshed_at: $spec_refreshed_at}' \
      > "$OUT_DIR/platform-meta.json"
    echo "Wrote $OUT_DIR/platform-meta.json (platform@$commit)"
  else
    echo "WARN: /health returned malformed or empty JSON, leaving existing platform-meta.json intact" >&2
  fi
else
  echo "WARN: /health unreachable, leaving existing platform-meta.json intact" >&2
fi
```

`jq` becomes a hard dependency for the meta step (it is currently optional in the script for the path-summary). This is acceptable: `jq` is universally available in CI environments and is already on the developer's path for `refresh-openapi.sh` to be useful at all in practice.

### `scripts/write-health-json.mjs` (new)

ES module, ~40 lines, zero new dependencies. Uses only `node:fs`, `node:path`, `node:child_process`, `node:url`:

1. **Resolve docs commit:**
   - First: `process.env.CF_PAGES_COMMIT_SHA?.slice(0, 7)`
   - Fallback: `execSync('git rev-parse --short HEAD').toString().trim()` wrapped in try/catch
   - Final fallback: `"unknown"`
2. **Resolve `build_time`:** `new Date().toISOString()`
3. **Read platform metadata:**
   - Read `static/api/platform-meta.json`. If file missing, set `platform: null` and warn. If file present but unparseable, set `platform: null` and warn.
4. **Write `static/health.json`** pretty-printed (2-space indent, trailing newline).

The script must run before the Docusaurus build copies `static/` into `build/`. The npm `prebuild` lifecycle hook handles this automatically.

### `package.json` (modified)

Add one line:

```json
"prebuild": "node scripts/write-health-json.mjs"
```

No script for `pnpm dev`. Dev mode does not need `health.json`; if developers want to test it, they can run the script manually.

### `.gitignore` (modified)

```
/static/health.json
```

`static/health.json` is a regenerated build artifact and must not be committed. `static/api/platform-meta.json` _is_ committed — it is the snapshot.

### `docusaurus.config.ts`

Untouched. Static files are copied verbatim by Docusaurus.

### `README.md` and/or `CONTRIBUTING.md`

Add a one-line note explaining what `/health.json` is for (deploy spot-check, snapshot of platform build the spec came from). Concrete location TBD during implementation — wherever a new contributor would naturally look first.

## Data flow

**Spec refresh (developer-triggered, occasional):**

```
dev → scripts/refresh-openapi.sh
   ├─ curl <SPEC_HOST>/api/v1/openapi.{json,yaml} → static/api/openapi.{json,yaml}
   └─ curl <SPEC_HOST>/health (best-effort)
       ├─ on success: jq → static/api/platform-meta.json
       └─ on failure: warn, leave existing meta intact
```

**Docs build (every CF Pages deploy and every local `pnpm build`):**

```
pnpm build → prebuild hook → node scripts/write-health-json.mjs
   ├─ docs.commit:  CF_PAGES_COMMIT_SHA → git rev-parse → "unknown"
   ├─ docs.build_time: ISO-8601 UTC now
   └─ platform.*: read static/api/platform-meta.json (or null on missing/malformed)
   → write static/health.json
docusaurus build → copies static/* → build/health.json
CF Pages serves → https://docs.trakrf.id/health.json
                  https://docs.preview.trakrf.id/health.json
```

## Error handling

| Failure                                                 | Behavior                                                                                | Why                                                                                           |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `<SPEC_HOST>/health` unreachable during refresh         | Warn, skip writing `platform-meta.json`, leave existing file intact, spec still written | Spec is load-bearing, meta is best-effort. Previous successful refresh's data stays accurate. |
| `<SPEC_HOST>/health` returns malformed JSON             | Same as above                                                                           | `jq` parse failure caught, warn, continue                                                     |
| `static/api/platform-meta.json` missing at build time   | `health.json` emitted with `platform: null`, log warning, build continues               | Don't block deploys on missing snapshot                                                       |
| `static/api/platform-meta.json` present but unparseable | Same as above                                                                           | Log mentions parse error specifically                                                         |
| `git` not available in CF Pages (shallow checkout)      | Use `CF_PAGES_COMMIT_SHA` env var directly; never call `git` in CF                      | Env-var-first resolution order                                                                |
| `git` fails locally too                                 | `commit: "unknown"`, build continues                                                    | YAGNI to fail the build over a metadata field                                                 |

## Testing

Light-touch — this is a deploy artifact, not a hot path. **No unit test runner added.**

- **Manual run** during implementation: `node scripts/write-health-json.mjs && cat static/health.json | jq .`. Verify the shape with and without `static/api/platform-meta.json` present (delete + rerun to exercise the `platform: null` path; corrupt the file to exercise the malformed path).
- **Build integration**: `pnpm build && pnpm serve`, then `curl http://localhost:3000/health.json | jq .`.
- **Post-deploy verification** (acceptance criterion): after the PR lands and CF Pages deploys, `curl https://docs.preview.trakrf.id/health.json | jq .` and confirm the expected shape and current commit.

If `write-health-json.mjs` grows beyond a flat script, revisit the no-test-runner decision.

## Acceptance

- Running `scripts/refresh-openapi.sh` updates both the spec and `static/api/platform-meta.json` (when `<SPEC_HOST>/health` is reachable).
- `pnpm build` produces `build/health.json` with the current docs commit and `build_time`, plus the snapshotted platform metadata (or `platform: null` if the snapshot file is absent).
- `curl https://docs.preview.trakrf.id/health.json` after deploy returns the expected JSON.
- Brief note in README or CONTRIBUTING explaining what `/health.json` is for.

## Out of scope (YAGNI)

- **User-visible version display** (footer link, `/about` page) — strictly an ops spot-check artifact.
- **Live (non-snapshot) platform metadata path** — the snapshot is the design intent: it pins the committed spec to a known platform build.
- **`/health` alias without `.json` extension** — Docusaurus serves static files literally; one path is enough.
- **`Cache-Control` tuning for `health.json`** — CF Pages defaults are fine. If stale-on-CDN becomes an issue we revisit, but a few minutes of staleness on a deploy spot-check artifact is not material.
- **Sitemap or robots.txt exclusion** — file is harmless, no SEO concern, no security info exposed.
- **Versioning the docs repo with semver tags** — separate decision. The design is forward-compatible: when docs adopts releases, add `docs.tag` to the script's output.
- **Test runner / unit tests for `write-health-json.mjs`** — see Testing section. Manual + build-integration verification is sufficient for ~40 lines of flat script.

## Notes

- `platform.*` is a snapshot, not live — by design. `docs.platform.commit` answers "which platform build does this reference describe", not "what's running in prod right now".
- If `refresh-openapi.sh` is run before this work lands, no `platform-meta.json` exists yet. The first build after this lands will produce `health.json` with `platform: null`. The next `refresh-openapi.sh` run will populate it. This is expected and harmless.
- The platform's `/health` is served at `<SPEC_HOST>/health`, not `<SPEC_HOST>/api/v1/health`. No version prefix.
