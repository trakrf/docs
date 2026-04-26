# TRA-445 — Consolidate OpenAPI sync to a single pull-only flow

**Status:** Design approved 2026-04-26
**Linear:** [TRA-445](https://linear.app/trakrf/issue/TRA-445)
**Branch:** `miks2u/tra-445-pull-only-spec-sync` (worktree at `/home/mike/trakrf-docs-tra-445`)

## Problem

`static/api/openapi.{json,yaml}` on `trakrf/docs` `main` flips between two structurally different artifacts depending on which of two writers ran most recently:

| Flow                                                                | Source                                                                                        | Schema names                                                                            |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **Push** — `trakrf/platform/.github/workflows/publish-api-docs.yml` | `docs/api/openapi.public.{json,yaml}` (filtered, customer-facing, committed in platform repo) | Short — `apikey.APIKeyCreateResponse`, `shared.TagIdentifier`                           |
| **Pull** — `trakrf/docs/scripts/refresh-openapi.sh`                 | `https://app.preview.trakrf.id/api/v1/openapi.{json,yaml}` (runtime, unfiltered)              | Long — `github_com_trakrf_platform_backend_internal_models_apikey.APIKeyCreateResponse` |

Recent log on `main`:

- `a63c31e chore(api): sync spec from preview (post-TRA-501/503 deploy)` — pull flow, long names
- `9940a5d chore(api): sync spec from platform@20e209e` — push flow, short names

Symptoms:

1. **Reviewer noise.** The push bot opens one `sync/platform-<sha>` PR per platform-`main` advance. Each carries a Cloudflare Pages preview deploy. Older bot PRs do not auto-close when a _feature_ PR (e.g. `docs(tra-*)` running `refresh-openapi.sh` manually) lands a spec. Observed 2026-04-22: PRs #22, #24, #25 all open against older SHAs after PR #26 merged the manually-refreshed spec.
2. **Schema-name divergence.** Same endpoint, different type names depending on which flow last ran. Confusing for readers and machine-broken for any consumer that pins on a name.
3. **Dual sources of truth.** TRA-445's original framing ("auto-close stale sync PRs") assumed only SHA differs. Surfaced 2026-04-26: the artifacts themselves differ. The originally proposed "diff is fully subsumed by new `main`" close-logic is structurally unworkable because the pull-flow spec is _never_ an ancestor of the push-flow spec.

## Approach

**Pull-only consolidation.** Eliminate the push flow. The manual-refresh path becomes the sole writer of `static/api/openapi.*`, and pulls the customer-facing filtered spec directly from `trakrf/platform`'s `main` branch on GitHub.

This removes the race rather than papering over it. With one writer and one source, there is nothing to clean up, no auto-close logic to maintain, no per-SHA preview-deploy sprawl.

Source URL switches from `https://app.preview.trakrf.id/api/v1/openapi.{json,yaml}` (runtime, unfiltered) to `https://raw.githubusercontent.com/trakrf/platform/main/docs/api/openapi.public.{json,yaml}` (committed in platform repo, customer-facing, short names).

`platform-meta.json` (added by TRA-508) is repurposed: instead of snapshotting `/health` of a deployed preview build, it records the platform `main` commit the spec was pulled from. Field shape changes; consumers (`scripts/write-health-json.mjs`) read it opaquely so no code change there.

### Why pull from `main` HEAD on GitHub, not from preview API?

Considered three sub-variants:

- **Preview API (status quo).** Eliminates one race but preserves the schema-name divergence — the runtime spec at `app.preview.trakrf.id/api/v1/openapi.*` is the unfiltered Go-internal-paths version, not the customer-facing filtered one. Defeats the point.
- **Platform `main` HEAD on GitHub (chosen).** Tied to a clean merge target on `main`, no question of what's actually deployed where. In practice docs trails implementation, so by the time we refresh, deployed has caught up to `main`. Bundling several platform changes into one docs refresh is also natural.
- **Platform at the deployed commit (`/health.commit` → fetch from that SHA on platform).** Strictest "spec matches deployed reality." Rejected because it implicitly trusts that `app.preview.trakrf.id` always tracks platform `main` (the existing comment in `refresh-openapi.sh` claims this, but staking docs-source-of-truth on a comment is brittle — a future composite-preview change on platform would silently start importing in-flight unmerged endpoints).

## Output shape

### New `scripts/refresh-openapi.sh` flow

```
trakrf/platform (GitHub)              trakrf/docs (local checkout)
─────────────────────────             ─────────────────────────────
                                      $ pnpm refresh-openapi
                                          │
                                          ▼
git ls-remote ────────────────►  resolve $TRAKRF_PLATFORM_REF (default: main) → SHA
                                          │
                                          ▼
raw.githubusercontent.com ────►  fetch openapi.public.{json,yaml}
  /trakrf/platform/<ref>/                 │
  docs/api/openapi.public.*               ▼
                                      write static/api/openapi.{json,yaml}
                                          │
                                          ▼
                                      pnpm dlx openapi-to-postmanv2
                                          │
                                          ▼
                                      write static/api/trakrf-api.postman_collection.json
                                      write static/api/platform-meta.json
                                          │
                                          ▼
                                      developer reviews diff, commits, PRs
```

Single source of truth. No bot, no race, no per-SHA PRs. The manual gate (`pnpm refresh-openapi`) is the only writer of `static/api/openapi.*` and `static/api/trakrf-api.postman_collection.json`.

The Postman collection is regenerated from the freshly-pulled `openapi.json` via `pnpm dlx openapi-to-postmanv2 -p -O folderStrategy=Paths` (mirroring the command platform's retired `publish-api-docs.yml` ran). Multiple docs pages (`docs/api/postman.mdx`, `docs/api/quickstart.mdx`, `docs/api/README.md`, `docs/getting-started/api.mdx`) link to the collection, so it has to keep moving in lockstep with the spec.

### `platform-meta.json` schema (B1)

**Before (TRA-508 shape):**

```json
{
  "commit": "abc1234",
  "tag": "v0.1.2",
  "build_time": "2026-04-25T18:32:11Z",
  "spec_refreshed_at": "2026-04-26T19:08:01Z"
}
```

**After:**

```json
{
  "commit": "abc1234",
  "source_url": "https://github.com/trakrf/platform/commit/abc1234",
  "spec_refreshed_at": "2026-04-26T19:08:01Z"
}
```

- `commit` keeps its 7-char short-SHA shape, so `health.platform.commit` in `/health.json` doesn't change format. The _meaning_ shifts from "deployed-on-preview" to "spec-source-on-platform-main"; worth a one-line callout in the PR description.
- `tag` and `build_time` dropped — they described `/health` of a deployed build; under pull-only the spec source is `main` HEAD, which has no deploy and no semver tag at fetch time.
- `source_url` added for clickability from `/health.json` rendering.

### `TRAKRF_PLATFORM_REF` env override

Defaults to `main`. Setting it to a branch / tag / SHA lets a developer pull from a specific point on platform — useful for coordinated releases or for re-pulling at a known-good SHA. Replaces the old `TRAKRF_SPEC_HOST` (no longer meaningful).

## Components / files changed (docs PR)

| File                                            | Change                                                                                                                                                                                                                                                                                                                                                                                     |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `scripts/refresh-openapi.sh`                    | Rewrite. New source URL, new `TRAKRF_PLATFORM_REF` override, `git ls-remote` for SHA, new `platform-meta.json` schema. Drop `/health` snapshot logic and `TRAKRF_SPEC_HOST` env var. Add `pnpm dlx openapi-to-postmanv2` step to regenerate `static/api/trakrf-api.postman_collection.json` from the freshly-pulled spec. Header comment updated to describe pull-from-platform-main flow. |
| `static/api/trakrf-api.postman_collection.json` | Regenerated by the new script. May change shape slightly because the source spec is the customer-facing filtered one (short schema names) instead of platform's runtime spec; the collection still maps to the same endpoint paths.                                                                                                                                                        |
| `.github/workflows/sync-preview.yml`            | Delete the "Merge platform preview spec" step (lines 123–135). It fetches `sync/platform-preview` and merges it into the docs preview branch — that branch has no writer post-rescope and the step is dead.                                                                                                                                                                                |
| `README.md`                                     | Update the `static/api/platform-meta.json` description (currently line 64) to describe the new flow ("pulled from `trakrf/platform` `main`'s committed spec") and the new field shape.                                                                                                                                                                                                     |
| `static/api/openapi.{json,yaml}`                | Will swap from current long-named runtime spec to short-named filtered spec on first refresh. Big diff but content-equivalent at the path level; reviewer eyeballs the path list (it should match `openapi.public.json`'s path list on platform `main`).                                                                                                                                   |
| `static/api/platform-meta.json`                 | Refreshed via the new script; new schema.                                                                                                                                                                                                                                                                                                                                                  |

## Cross-repo coordination

**TRA-445 (this ticket, docs PR):** all of the above.

**Companion ticket (new, platform):** Delete `.github/workflows/publish-api-docs.yml`. Title suggestion: _"Retire `publish-api-docs.yml` — docs now pulls instead of platform pushing (companion to TRA-445)"_. Label `repo:platform`. Linked as relates-to TRA-445; mentioned in TRA-445's Linear comments and docs-PR body.

**Order:** docs PR first, then platform PR.

If docs ships first, the platform bot can keep opening `sync/platform-<sha>` PRs in the interim. Those PRs use the same `openapi.public.*` source as our new pull script, so they will look identical in shape — a redundant PR we close. If platform ships first, docs continues pulling unfiltered preview spec until the docs PR lands — a brief regression of the schema-name divergence we are fixing. Docs-first is strictly safer.

## Testing / definition of done

**Pre-merge smoke test on the feature branch:**

1. Run `pnpm refresh-openapi`. Expect: exits 0; `static/api/openapi.{json,yaml}` updated; `static/api/trakrf-api.postman_collection.json` regenerated; `static/api/platform-meta.json` shows the new schema with the current platform `main` SHA.
2. Diff path lists (`jq '.paths | keys[]'`) of new vs prior `openapi.json`. Path set should match what `openapi.public.json` carries on platform `main` (short schema names; no `github_com_trakrf_platform_backend_internal_models_*` prefixes).
3. Run `pnpm build`. Expect: build succeeds; `static/health.json` includes `platform.commit` matching what `refresh-openapi.sh` just wrote, plus `platform.source_url`.
4. Spot-check the rendered `/api` page on `pnpm serve` — schema names should be the short customer-facing ones.
5. Override test: `TRAKRF_PLATFORM_REF=<a known older platform SHA> pnpm refresh-openapi`. Confirm the spec content matches that older commit.
6. Negative test: simulate platform unreachable (e.g., `TRAKRF_PLATFORM_REF=does-not-exist`). Script should fail clearly via `set -euo pipefail`; existing `static/api/*` should be untouched.

**Definition of done:**

- Docs PR merged with the smoke test recorded in the PR description.
- Companion platform ticket filed with link.
- One-time remote cleanup completed (orphan `sync/platform-preview` branch deleted; any stale `sync/platform-<sha>` branches swept). _Done interactively during brainstorm: `sync/platform-preview` deleted; no per-SHA branches existed._
- TRA-445 closed with a resolution comment pointing at the merged PR + companion ticket.

## Out of scope

- **Auto-close logic for `sync/platform-*` PRs** — the original ticket's framing. Dies with the bot.
- **Pruning `sync/platform-<sha>` branches via workflow** — none exist on remote today; if any reappear before the platform PR merges, one-shot `gh` cleanup, not workflow work.
- **Platform PR itself** — companion ticket carries it.
- **Backfill of older spec docs / plans that mention the old bot flow** — natural archival; only `README.md:64` is currently load-bearing.
- **Touching the long-lived docs-preview merge bot (`.github/workflows/sync-preview.yml`)** beyond removing the dead `sync/platform-preview` overlay step. The rest of that workflow (composite preview deploy from open docs PRs) stays.
