# TRA-408 API Docs Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix nine sections of API-docs issues via two sequential PRs — factual corrections in PR A, integrator quickstart and new-convention docs in PR B — as specified in `spec/superpowers/specs/2026-04-20-tra-408-api-docs-fixes-design.md`.

**Architecture:** All edits live in `docs/**/*.md{,x}`, `sidebars.ts`, and (if the broken-link check requires) `docusaurus.config.ts`. Platform-owned files (`static/api/openapi.*`, `static/api/trakrf-api.postman_collection.json`) are **never** edited here — upstream changes in `platform/docs/api/openapi.public.*` are the only way to change those. Verification is `pnpm typecheck` + `pnpm build` (broken-link check with `onBrokenLinks: 'throw'`) + manual `pnpm serve` walkthrough.

**Tech Stack:** Docusaurus 3.x (classic preset + redocusaurus), TypeScript (config + sidebars), pnpm package manager. Markdown with one MDX page (`docs/api/postman.mdx`).

---

## Prerequisites (apply to both parts)

- On branch `fix/tra-408-api-docs-corrections` with HEAD at `978fb39` (the spec commit). Confirm with `git branch --show-current && git log -1 --oneline`.
- `pnpm install` has been run and `node_modules/` is populated.
- Baseline `pnpm typecheck` and `pnpm build` pass before any edits are made (Task A0 verifies this).

## Part 1 — PR A: factual corrections

Target branch: `fix/tra-408-api-docs-corrections` (already created off `origin/main` with just the spec commit on it).

### Task A0: Confirm baseline green

**Files:** none modified.

- [ ] **Step 1: Install deps if not already installed**

Run: `pnpm install`
Expected: completes with no errors. If `node_modules/` was already populated, this is a no-op.

- [ ] **Step 2: Verify typecheck passes on clean tree**

Run: `pnpm typecheck`
Expected: 0 errors. This runs `tsc --noEmit` against `docusaurus.config.ts`, `sidebars.ts`, and `src/`.

- [ ] **Step 3: Verify build passes on clean tree**

Run: `pnpm build`
Expected: build completes; no "Broken link" errors. This validates the starting state before we add any new links.

- [ ] **No commit** — this is the baseline.

### Task A0b: Commit tests/blackbox harness (piggyback)

**Files:**

- Track: `tests/blackbox/BB.md`
- Track: `tests/blackbox/.envrc`
- **Never track:** `tests/blackbox/.env.local` (contains credentials; already excluded by the existing `.env.*` rule in `.gitignore` — verified via `git check-ignore`).

Context: `BB.md` documents the black-box API evaluation methodology that produced the finding list this whole ticket addresses. Committing it alongside the docs fixes makes the methodology discoverable for the next evaluator and ties the tooling to the work it triggered.

- [ ] **Step 1: Confirm .gitignore correctly excludes the secret**

Run: `git check-ignore -v tests/blackbox/.env.local`
Expected output contains `.gitignore:10:.env.*\ttests/blackbox/.env.local`. If not, **stop** — do not commit anything until the exclusion is verified. (Existing `.env.*` rule is already correct; this is a sanity check.)

- [ ] **Step 2: Stage the two safe files (by name — do not `git add .`)**

```bash
git add tests/blackbox/BB.md tests/blackbox/.envrc
```

- [ ] **Step 3: Confirm nothing else snuck in**

Run: `git status`
Expected: only `tests/blackbox/BB.md` and `tests/blackbox/.envrc` are staged. `tests/blackbox/.env.local` must still appear as untracked-and-ignored (not listed under "Changes to be committed").

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(tra-408): add tests/blackbox harness (BB.md + .envrc)

BB.md documents the black-box API-evaluation methodology that produced the
finding list TRA-408 is addressing. Commit it alongside the docs fixes so
the methodology is discoverable for future evaluation runs.

.envrc uses direnv to load tests/blackbox/.env.local (credentials,
gitignored via the existing .env.* rule — verified via git check-ignore).
EOF
)"
```

### Task A1: §9 — `/reports/*` prose sweep

**Files:** candidates found via grep. Likely `docs/api/webhooks.md`, `docs/api/rate-limits.md`, possibly `docs/api/rest-api-reference.md`.

- [ ] **Step 1: Find every `/reports/` reference in `docs/`**

Use the Grep tool (do not run `rg` directly via Bash):

- Pattern: `/api/v1/reports/`
- Path: `docs/`
- `output_mode`: `"content"` with `-n: true`

Record every file:line hit. Expected outcome: anywhere from 0 to ~6 hits across 1–3 files. The design spec predicted webhooks.md and rate-limits.md, but the files read during brainstorming did not appear to contain `/reports/` strings — so the most likely result is **zero hits** in prose, with the paths living only in the OpenAPI spec (platform-owned, out of scope).

- [ ] **Step 2: For each hit, plan the rewrite**

For each hit, decide the replacement:

- `/api/v1/reports/current-locations` → `/api/v1/locations/current`
- `/api/v1/reports/assets/{id}/history` → `/api/v1/assets/{identifier}/history`
- `/api/v1/reports/assets/*/history` → same rewrite
- Any prose calling these "the reports endpoints" needs rephrasing to "the current-locations endpoint" or "the asset history endpoint" — don't just path-swap and leave misleading surrounding text.

- [ ] **Step 3: Apply the rewrites**

Use the Edit tool for each file. Preserve surrounding prose context.

If zero hits were found in Step 1, skip Steps 3–5 and move to Task A2. Note that as "§9 no-op in prose — platform-owned spec already covers the paths" in the PR A commit for §3 or in the PR description.

- [ ] **Step 4: Verify the build**

Run: `pnpm build`
Expected: completes without broken-link errors. If any rewrite introduced a link to an anchor that doesn't exist, the build will throw.

- [ ] **Step 5: Commit (skip if §9 was a no-op)**

```bash
git add docs/api/
git commit -m "$(cat <<'EOF'
docs(tra-408): update /reports/* prose references to new TRA-396 paths

TRA-396 renamed /api/v1/reports/current-locations to /api/v1/locations/current
and /api/v1/reports/assets/{id}/history to /api/v1/assets/{identifier}/history.
Rewrite all prose references to match. The platform-owned OpenAPI spec already
reflects the new paths.
EOF
)"
```

### Task A2: §3 — endpoint-reference fixes in webhooks.md and rate-limits.md

**Files:**

- Modify: `docs/api/webhooks.md` (lines ~50–51 based on brainstorming read; re-verify at edit time)
- Modify: `docs/api/rate-limits.md` (line ~76 `/orgs/me` block)

- [ ] **Step 1: Read current state of both files**

Read `docs/api/webhooks.md` and `docs/api/rate-limits.md` in full. Locate:

- In webhooks.md: the `GET /api/v1/scans?from=<last-high-water-mark>` polling bullet (brainstorming found this at line 50) and the `GET /api/v1/locations/current` bullet (line 51).
- In rate-limits.md: the `/orgs/me` exclusion block (brainstorming found this at line 76) and any `/scans` references (brainstorming found none in rate-limits.md — the ticket's claim may have been stale).

- [ ] **Step 2: Rewrite the webhooks.md `/scans` polling example**

Replace the `/scans` bullet with an `/assets/{identifier}/history` bullet. Exact replacement text:

```markdown
- **Poll `GET /api/v1/assets/{identifier}/history?from=<last-high-water-mark>`** per asset you're tracking, to get scan events for that asset since your last pull. (The `GET /api/v1/scans` endpoint referenced in earlier docs no longer exists — TRA-396 consolidated the read path under the asset-history endpoint.)
```

- [ ] **Step 3: Add a rename-note to the webhooks.md `/locations/current` bullet**

Change the existing `/locations/current` bullet to include a parenthetical note about the rename:

```markdown
- **Poll `GET /api/v1/locations/current`** for the current asset-at-location snapshot (cheaper than replaying the full scan stream). This endpoint was renamed from `/api/v1/reports/current-locations` under TRA-396; if you see the old path in any third-party code, update it.
```

- [ ] **Step 4: Add the `/orgs/me` response-shape note in rate-limits.md**

Immediately after the existing `/orgs/me` exclusion bullet (line ~76), add this paragraph:

```markdown
**Response-shape note:** `GET /api/v1/orgs/me` returns a bare `{ "id": ..., "name": ... }` object — not the `{ "data": ... }` envelope used by the rest of the v1 API. Clients using this as a liveness probe should be aware the shape may change if the endpoint migrates to the standard envelope. Consider also verifying a "real" enveloped endpoint (e.g. `GET /api/v1/assets?limit=1`) in your health check if you want to detect envelope drift early.
```

_No forward link to `private-endpoints.md` — that page doesn't exist until PR B and `onBrokenLinks: "throw"` would fail the build. PR B §6 will backfill the cross-link._

- [ ] **Step 5: Also sweep rate-limits.md for any `/scans` references the ticket flagged**

Use Grep: pattern `/api/v1/scans`, path `docs/api/rate-limits.md`. If hits exist, rewrite to `/api/v1/assets/{identifier}/history` with the same prose shape as Step 2. If zero hits (the most likely outcome based on the brainstorming read), move on.

- [ ] **Step 6: Verify**

Run: `pnpm typecheck && pnpm build`
Expected: both pass. No broken links.

- [ ] **Step 7: Manual visual check**

Run: `pnpm serve` (or `pnpm dev`). Open `/docs/api/webhooks` and `/docs/api/rate-limits` in a browser. Confirm:

- The new `/assets/{identifier}/history` bullet renders cleanly.
- The `/locations/current` rename note is present.
- The `/orgs/me` response-shape paragraph is present and flows after the existing bullet.

- [ ] **Step 8: Commit**

```bash
git add docs/api/webhooks.md docs/api/rate-limits.md
git commit -m "$(cat <<'EOF'
docs(tra-408): fix endpoint references in webhooks + rate-limits (§3)

- Replace broken /api/v1/scans polling example with /assets/{identifier}/history
  (TRA-396 consolidated the read path).
- Add rename note for /locations/current (renamed from /reports/current-locations
  under TRA-396).
- Add response-shape note on /orgs/me in rate-limits: bare {id,name}, not the
  standard envelope. Forward cross-link to private-endpoints.md will land in
  PR B under §6 to keep this PR self-contained (onBrokenLinks: throw).
EOF
)"
```

### Task A3: §2 — `docs/api/postman.mdx` alignment

**Files:**

- Modify: `docs/api/postman.mdx:31` (baseUrl value) and `:32` (apiKey instruction)

- [ ] **Step 1: Re-read postman.mdx to confirm line numbers**

Read `docs/api/postman.mdx`. Locate the "In the collection variables, set:" list. The two lines are currently:

```markdown
- `baseUrl` to `https://trakrf.id/api/v1`.
- `apiKey` to your API key (create one in **Settings → API Keys** on trakrf.id).
```

- [ ] **Step 2: Replace baseUrl value**

Use Edit tool on `docs/api/postman.mdx`:

- `old_string`: ``- `baseUrl` to `https://trakrf.id/api/v1`.``
- `new_string`: ``- `baseUrl` to `https://app.trakrf.id/api/v1` — the API is served from the `app.` subdomain, not the marketing site.``

- [ ] **Step 3: Replace apiKey instruction**

Use Edit tool on `docs/api/postman.mdx`:

- `old_string`: ``- `apiKey` to your API key (create one in **Settings → API Keys** on trakrf.id).``
- `new_string`: ``- `apiKey` to your API key. See [Authentication → Mint your first API key](./authentication#mint-your-first-api-key) for how to create one.``

_Note: the forward link to `authentication#mint-your-first-api-key` depends on §1 (Task A4) adding that anchor. Order §1 **before** pushing PR A, or this build will fail. Plan ordering puts §1 last in commit order per the spec — verify A4 lands before `pnpm build` is re-run for the whole PR in Task A5._

- [ ] **Step 4: Verify (deferred to Task A5 since §1 isn't written yet)**

Skip a full `pnpm build` here — it would fail on the unresolved `#mint-your-first-api-key` anchor. The §1 commit in Task A4 adds that anchor; the PR-level build verification runs in Task A5.

- [ ] **Step 5: Commit**

```bash
git add docs/api/postman.mdx
git commit -m "$(cat <<'EOF'
docs(tra-408): align postman.mdx with authentication (§2)

- Fix baseUrl: https://trakrf.id/api/v1 → https://app.trakrf.id/api/v1.
  The collection JSON itself is already correct; this was a prose-only bug.
- Replace key-mint instruction with a link to authentication#mint-your-first-api-key
  so there is one source of truth for the mint flow.
EOF
)"
```

### Task A4: §1 — remove UI-in-development banner, add "Mint your first API key" section

**Files:**

- Modify: `docs/api/authentication.md` (delete lines 9–11 banner, add new section after the existing intro paragraph)

- [ ] **Step 1: Re-read authentication.md**

Read `docs/api/authentication.md`. Confirm:

- The banner at lines 9–11 contains:

  ```markdown
  :::note API Keys UI
  The key-management UI (mint, list, revoke) is in active development under [TRA-393](https://linear.app/trakrf/issue/TRA-393). Until it lands, contact [support@trakrf.id](mailto:support@trakrf.id) to request a key for integration testing.
  :::
  ```

- The "## Request header" section follows at line 13.

- [ ] **Step 2: Delete the banner**

Use Edit tool:

- `old_string`:

  ```markdown
  :::note API Keys UI
  The key-management UI (mint, list, revoke) is in active development under [TRA-393](https://linear.app/trakrf/issue/TRA-393). Until it lands, contact [support@trakrf.id](mailto:support@trakrf.id) to request a key for integration testing.
  :::

  ## Request header
  ```

- `new_string`:

  ```markdown
  ## Mint your first API key {#mint-your-first-api-key}

  API keys are created by an organization administrator in the TrakRF web app:

  1. Sign in at [app.trakrf.id](https://app.trakrf.id) with an admin account.
  2. In the left nav, go to **Settings** → **API Keys**.
  3. Click **Create Key**. Give it a descriptive name (e.g. `"prod-integration"` or `"local-dev"`) and pick the scopes the integration needs — only the scopes required for the endpoints you'll call. See the [Scopes](#scopes) table below.
  4. Submit. The full JWT is displayed **once** at creation. Copy it to your secrets store immediately; it cannot be shown again.
  5. Use it as the `Authorization: Bearer <key>` header on every API request. See [Request header](#request-header) for the exact format.

  <!-- TODO: screenshot of Settings → API Keys create-key flow; capture via scripts/refresh-screenshots.sh pattern. Tracked as a follow-up to TRA-408. -->

  ## Request header
  ```

_The `{#mint-your-first-api-key}` syntax sets the explicit anchor. The §2 Postman link and the §4 API quickstart (in PR B) target this exact anchor._

- [ ] **Step 3: Verify**

Run: `pnpm typecheck && pnpm build`
Expected: both pass. The `authentication#mint-your-first-api-key` anchor now resolves for the Postman page's forward link from Task A3.

- [ ] **Step 4: Manual visual check**

Run: `pnpm serve`. Open `/docs/api/authentication` in the browser. Confirm:

- No banner at the top of the page.
- A new H2 "Mint your first API key" appears before "Request header" with the 5-step list and the HTML-comment screenshot placeholder.
- The HTML comment doesn't render visibly.
- The anchor link `/docs/api/authentication#mint-your-first-api-key` scrolls to the new section.
- Open `/docs/api/postman` and confirm the "Settings → API Keys" link click routes to the new section (verifies §2's forward link).

- [ ] **Step 5: Commit**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-408): remove stale UI-in-development banner, add mint-key section (§1)

TRA-393 is Done — the API Keys UI is live in Org Settings → API Keys.
Remove the banner that misdirects integrators to email support, and add a
5-step "Mint your first API key" section with an anchor that Postman and the
API quickstart (PR B) link to as a single source of truth.

Screenshot capture is a deferred follow-up (HTML-comment placeholder left in
place for the runbook to backfill via scripts/refresh-screenshots.sh).
EOF
)"
```

### Task A5: PR A end-to-end verification and push

**Files:** none modified.

- [ ] **Step 1: Fresh build from a clean state**

Run: `pnpm build`
Expected: clean build, no broken-link errors. This validates every cross-link added in A1–A4 now resolves.

- [ ] **Step 2: Fresh typecheck**

Run: `pnpm typecheck`
Expected: 0 errors.

- [ ] **Step 3: Review the commit series**

Run: `git log origin/main..HEAD --oneline`
Expected: 4 or 5 commits:

1. `docs(tra-408): design for API docs fixes (PR A + PR B split)` (spec)
2. Optionally: `docs(tra-408): update /reports/* prose references to new TRA-396 paths` (if §9 had hits)
3. `docs(tra-408): fix endpoint references in webhooks + rate-limits (§3)`
4. `docs(tra-408): align postman.mdx with authentication (§2)`
5. `docs(tra-408): remove stale UI-in-development banner, add mint-key section (§1)`

If the spec commit should _not_ go out with PR A (user may prefer it in its own PR or to land it separately), confirm with the user before pushing. Default: include the spec commit; it documents why the series exists.

- [ ] **Step 4: Manual browser walkthrough of all four touched pages**

Run: `pnpm serve`. Visit:

- `/docs/api/authentication` — banner gone, new Mint section present
- `/docs/api/postman` — new baseUrl, new key-mint link
- `/docs/api/webhooks` — new polling example, /locations/current rename note
- `/docs/api/rate-limits` — /orgs/me response-shape note

Click every sidebar link in the **API** sidebar to confirm nothing else broke.

- [ ] **Step 5: Push and open the PR**

```bash
git push -u origin fix/tra-408-api-docs-corrections
```

Open PR using:

```bash
gh pr create --title "docs(tra-408): API docs factual corrections (§1 §2 §3 §9)" --body "$(cat <<'EOF'
## Summary

First of two PRs for TRA-408. Fixes factual errors and contradictions in the published API docs so a new integrator isn't sent down dead ends before their first successful call.

Covers sections §1, §2, §3, and §9 of the [TRA-408 scope](https://linear.app/trakrf/issue/TRA-408). The §4–§8 sections land in a follow-up PR once this merges.

Design spec: `spec/superpowers/specs/2026-04-20-tra-408-api-docs-fixes-design.md`.

### What changed
- **§1:** Removed the "API Keys UI is in development" banner from `authentication.md` (TRA-393 is Done). Added a "Mint your first API key" section with a 5-step walkthrough — this becomes the single source of truth for the key-mint flow.
- **§2:** Fixed `postman.mdx` contradictions — `baseUrl` is now `https://app.trakrf.id/api/v1` (was `https://trakrf.id/api/v1`), key-mint instruction links to the new Authentication section.
- **§3:** Replaced the broken `GET /api/v1/scans` polling example in `webhooks.md` with `GET /api/v1/assets/{identifier}/history`. Added rename notes for `/locations/current` (was `/reports/current-locations` pre-TRA-396). Documented the `/orgs/me` response-shape quirk in `rate-limits.md`.
- **§9:** [Swept / no-op swept] `/reports/*` prose references. *Adjust this line to "Rewrote N references..." or "No prose references found — platform-owned spec already correct" based on A1 findings.*

### Out of scope — carried to PR B
- §4 API quickstart, §5 Integrations placeholders, §6 private-endpoints page, §7 resource-identifiers page, §8 post-TRA-396 response-shape audit.
- The cross-link from `rate-limits.md#orgs-me` to the new `private-endpoints.md` is deliberately omitted here (PR B adds it under §6) to keep this PR self-contained under `onBrokenLinks: throw`.

### Out of scope — TRA-407-dependent
- `error-codes.md` prose on validation-envelope `fields[]` and the `request_id` ULID format is untouched. Rewrites follow TRA-407 landing.

### Follow-ups (to be filed)
- Capture a real screenshot for the §1 "Mint your first API key" walkthrough via `scripts/refresh-screenshots.sh`; HTML-comment placeholder is in the page today.

## Test plan

- [ ] `pnpm typecheck` passes
- [ ] `pnpm build` passes (broken-link check is enforced: `onBrokenLinks: "throw"`)
- [ ] `pnpm serve` — manual walkthrough of all four touched pages confirms expected content renders
- [ ] Preview deploy at `docs.preview.trakrf.id` spot-checked before marking ready

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: Verify preview deploy**

The `.github/workflows/sync-preview.yml` workflow should fire on push. Wait for the preview URL in the PR (typically commented by the workflow). Spot-check the four touched pages at `https://docs.preview.trakrf.id` (or whatever the workflow produces for this branch).

---

## 🛑 Gate: Merge PR A before proceeding to Part 2

**Do not start Part 2 until PR A is merged to `main`.** PR B branches off _updated_ main and backfills a cross-link that only makes sense once PR A's `rate-limits.md` note is already on main.

After PR A merges:

1. `git checkout main`
2. `git pull origin main`
3. `git branch -d fix/tra-408-api-docs-corrections` (local cleanup)
4. `git branch -D feature/tra-394-redocusaurus` (delete the stale branch identified during brainstorming — PR #6 was merged months ago)
5. Proceed to Task B0.

---

## Part 2 — PR B: integrator quickstart + new conventions

Target branch: `feat/tra-408-api-quickstart-and-conventions`, branched fresh off updated `main`.

### Task B0: Create PR B branch

**Files:** none modified.

- [ ] **Step 1: Confirm you are on updated main**

Run: `git status && git log -1 --oneline`
Expected: on `main`, HEAD includes the merge commit for PR A.

- [ ] **Step 2: Create the PR B branch**

Run: `git checkout -b feat/tra-408-api-quickstart-and-conventions`

- [ ] **Step 3: Baseline build**

Run: `pnpm typecheck && pnpm build`
Expected: both pass. Confirms PR A is green on main.

### Task B1: §7 — create `docs/api/resource-identifiers.md`

**Files:**

- Create: `docs/api/resource-identifiers.md`
- Modify: `sidebars.ts` (add `"api/resource-identifiers"` after `"api/rest-api-reference"`)

- [ ] **Step 1: Create the file**

Write `docs/api/resource-identifiers.md` with this exact content:

````markdown
---
sidebar_position: 3
---

# Resource identifiers

Every resource in the TrakRF API has **two** IDs:

| ID             | Type    | Where you see it                 | How you use it                                                                                               |
| -------------- | ------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `identifier`   | string  | URL path params, response bodies | The business-meaningful ID (e.g. `ASSET-0001`, `LOC-0001`). This is the one clients key on.                  |
| `surrogate_id` | integer | Response bodies only             | Internal-use stable ID; visible so you can correlate across related responses, but not required on the wire. |

This page explains where each form appears and why integrators should key on `identifier`, not `surrogate_id`.

## URL path parameters — `identifier` only

Single-resource read endpoints take the `identifier` (string) as the URL path parameter:

```bash
# Correct — takes the business identifier
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets/ASSET-0001
```

The integer `surrogate_id` is **not** accepted on reads:

```bash
# Wrong — returns 404 not_found
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets/27545709
```

This applies to every GET endpoint with a path param:

- `GET /api/v1/assets/{identifier}`
- `GET /api/v1/assets/{identifier}/history`
- `GET /api/v1/locations/{identifier}`

## Response bodies

Responses return both IDs so clients that need to correlate across related records (e.g. joining asset history back to a specific asset record) can use the stable `surrogate_id` as a foreign key:

```json
{
  "data": {
    "identifier": "ASSET-0001",
    "surrogate_id": 27545709,
    "name": "Warehouse forklift",
    "current_location": "LOC-0001"
  }
}
```

**Clients should key on `identifier`.** `surrogate_id` is stable across updates to a given record but is opaque to integrators and not guaranteed stable across environments.

## Writes (PUT, DELETE)

The published OpenAPI spec at [`/api`](/api) currently shows `{id}` on write-path parameters. This will align with the read-path `{identifier}` convention under [TRA-407](https://linear.app/trakrf/issue/TRA-407). Until that lands, the interactive reference is authoritative for the exact shape each write endpoint accepts. This page will be updated when the alignment ships.

## Session-auth-only exception

There is one SPA-only path that takes the integer `surrogate_id`:

- `GET /api/v1/assets/by-id/{surrogate_id}/history`

This path is accessible **only** with session cookies (used by the first-party TrakRF web app). API-key requests receive `401 unauthorized`. Integrators using API keys should always use `GET /api/v1/assets/{identifier}/history` with the string identifier. See [Private endpoints](./private-endpoints) for the full list of SPA-only paths.
````

_Note: the forward link to `./private-endpoints` at the bottom depends on B2 landing. Since B1 and B2 are both in PR B, the build check deferred to B2 verifies both simultaneously._

- [ ] **Step 2: Update `sidebars.ts`**

Use Edit tool on `sidebars.ts`:

- `old_string`:

  ```typescript
        items: [
          "api/authentication",
          "api/rest-api-reference",
          "api/webhooks",
          "api/rate-limits",
          "api/error-codes",
          "api/postman",
        ],
  ```

- `new_string`:

  ```typescript
        items: [
          "api/authentication",
          "api/rest-api-reference",
          "api/resource-identifiers",
          "api/webhooks",
          "api/rate-limits",
          "api/error-codes",
          "api/postman",
        ],
  ```

_`private-endpoints` is added to the sidebar in Task B2. Don't add it here or the build will fail — the file doesn't exist yet._

- [ ] **Step 3: Verify (partial — `private-endpoints` link will fail)**

Run: `pnpm typecheck`
Expected: 0 errors.

Skip `pnpm build` here — the `./private-endpoints` link at the bottom of `resource-identifiers.md` will fail until B2 creates that file. Full build verification runs in Task B2.

- [ ] **Step 4: Commit**

```bash
git add docs/api/resource-identifiers.md sidebars.ts
git commit -m "$(cat <<'EOF'
docs(tra-408): add Resource identifiers convention doc (§7)

New page docs/api/resource-identifiers.md documents the {identifier}
(string, URL path) vs surrogate_id (integer, response body) distinction
introduced by TRA-396. Every integrator needs this lesson; it gets its
own sidebar entry between REST API Reference and Webhooks.

Hedges TRA-407 dependency for write-path {id}/{identifier} alignment
inline rather than leaving prose unwritten.
EOF
)"
```

### Task B2: §6 — create `docs/api/private-endpoints.md` + cross-link backfill

**Files:**

- Create: `docs/api/private-endpoints.md`
- Modify: `docs/api/rate-limits.md` (add one-line cross-link after the `/orgs/me` response-shape paragraph that PR A landed)
- Modify: `sidebars.ts` (add `"api/private-endpoints"` between `"api/error-codes"` and `"api/postman"`)

- [ ] **Step 1: Create the file**

Write `docs/api/private-endpoints.md` with this exact content:

````markdown
---
sidebar_position: 6
---

# Private endpoints (classification pending)

:::caution Not part of the public API
The endpoints listed on this page are used by the first-party TrakRF web app but are **not currently published in the OpenAPI spec** at [`/api`](/api). Their classification — public API, internal-only, or something in between — is a pending platform decision.

Third-party integrations should not depend on these endpoints. If you need functionality not available via the documented public API, [email support](mailto:support@trakrf.id) so we can prioritize exposing the right primitives.
:::

## Endpoint list

| Endpoint                       | Method(s)         | Used by                | Status       | Classification                          |
| ------------------------------ | ----------------- | ---------------------- | ------------ | --------------------------------------- |
| `/api/v1/auth/login`           | POST              | SPA login form         | Undocumented | Pending                                 |
| `/api/v1/auth/signup`          | POST              | SPA signup form        | Undocumented | Pending                                 |
| `/api/v1/auth/forgot-password` | POST              | SPA password recovery  | Undocumented | Pending                                 |
| `/api/v1/auth/reset-password`  | POST              | SPA password recovery  | Undocumented | Pending                                 |
| `/api/v1/auth/accept-invite`   | POST              | SPA invite acceptance  | Undocumented | Pending                                 |
| `/api/v1/users/me`             | GET               | SPA user context       | Undocumented | Pending                                 |
| `/api/v1/users/me/current-org` | GET               | SPA org context        | Undocumented | Pending                                 |
| `/api/v1/orgs`                 | GET               | SPA org picker         | Undocumented | Pending                                 |
| `/api/v1/orgs/{id}`            | GET               | SPA org detail         | Undocumented | Pending                                 |
| `/api/v1/orgs/{id}/api-keys`   | GET, POST, DELETE | Settings → API Keys UI | Undocumented | Pending                                 |
| `/api/v1/orgs/me`              | GET               | API-key health check   | Undocumented | Pending — see response-shape note below |

## Response-shape note: `/orgs/me` {#orgs-me}

The `GET /api/v1/orgs/me` endpoint is currently excluded from rate limiting (see [Rate limits → Exclusions](./rate-limits#exclusions)) and is commonly used as an API-key liveness probe. It has a **different response shape** from the rest of the v1 API:

```json
{
  "id": 123,
  "name": "Example Org"
}
```

Unlike other endpoints — which wrap payloads in a `{ "data": ... }` envelope — this one returns a bare object. If it migrates to the standard envelope, clients keyed on the bare-object shape will break.

If you're using `/orgs/me` as a health check, prefer to also verify the standard envelope on a "real" endpoint (e.g. `GET /api/v1/assets?limit=1`) so your checks aren't tied to the current shape.

## Classification decisions to come

Each row in the table will be classified over time into one of:

- **Public** — added to the OpenAPI spec and appearing in the [`/api`](/api) reference. Integrators can rely on it.
- **Internal** — marked private (e.g. via an `X-Internal: true` middleware header); third parties must not depend on it.
- **Public-with-caveats** — documented publicly with explicit version/stability caveats.

This page tracks the state until those decisions land.
````

- [ ] **Step 2: Add the cross-link in `rate-limits.md`**

Use Edit tool on `docs/api/rate-limits.md`:

- `old_string` (the paragraph PR A added in Task A2 Step 4):

  ```markdown
  **Response-shape note:** `GET /api/v1/orgs/me` returns a bare `{ "id": ..., "name": ... }` object — not the `{ "data": ... }` envelope used by the rest of the v1 API. Clients using this as a liveness probe should be aware the shape may change if the endpoint migrates to the standard envelope. Consider also verifying a "real" enveloped endpoint (e.g. `GET /api/v1/assets?limit=1`) in your health check if you want to detect envelope drift early.
  ```

- `new_string`:

  ```markdown
  **Response-shape note:** `GET /api/v1/orgs/me` returns a bare `{ "id": ..., "name": ... }` object — not the `{ "data": ... }` envelope used by the rest of the v1 API. Clients using this as a liveness probe should be aware the shape may change if the endpoint migrates to the standard envelope. Consider also verifying a "real" enveloped endpoint (e.g. `GET /api/v1/assets?limit=1`) in your health check if you want to detect envelope drift early. See [Private endpoints → /orgs/me](./private-endpoints#orgs-me) for the full catalog entry.
  ```

- [ ] **Step 3: Update `sidebars.ts`**

Use Edit tool on `sidebars.ts`:

- `old_string`:

  ```typescript
        items: [
          "api/authentication",
          "api/rest-api-reference",
          "api/resource-identifiers",
          "api/webhooks",
          "api/rate-limits",
          "api/error-codes",
          "api/postman",
        ],
  ```

- `new_string`:

  ```typescript
        items: [
          "api/authentication",
          "api/rest-api-reference",
          "api/resource-identifiers",
          "api/webhooks",
          "api/rate-limits",
          "api/error-codes",
          "api/private-endpoints",
          "api/postman",
        ],
  ```

- [ ] **Step 4: Verify**

Run: `pnpm typecheck && pnpm build`
Expected: both pass. The cross-link from `resource-identifiers.md` to `./private-endpoints` (from B1) now resolves; the backfilled cross-link from `rate-limits.md` to `private-endpoints#orgs-me` also resolves; the return link from `private-endpoints.md` to `rate-limits#exclusions` resolves (`Exclusions` is a real H2 in `rate-limits.md`).

- [ ] **Step 5: Manual visual check**

Run: `pnpm serve`. Open `/docs/api/private-endpoints`:

- Confirm the caution admonition renders at the top.
- Confirm the table renders with all 11 rows.
- Confirm the `{#orgs-me}` anchor works: `/docs/api/private-endpoints#orgs-me` scrolls to the response-shape section.
- Click the "Rate limits → Exclusions" return link; confirm it scrolls to the rate-limits Exclusions H2.

Open `/docs/api/rate-limits`:

- Scroll to the Exclusions section.
- Confirm the new "See [Private endpoints → /orgs/me]" forward link is present and routes to the right anchor.

Open `/docs/api/resource-identifiers`:

- Scroll to the bottom. Confirm the `./private-endpoints` link routes to the new page.

- [ ] **Step 6: Commit**

```bash
git add docs/api/private-endpoints.md docs/api/rate-limits.md sidebars.ts
git commit -m "$(cat <<'EOF'
docs(tra-408): add Private endpoints stub + backfill rate-limits cross-link (§6)

New page docs/api/private-endpoints.md catalogs the endpoints used by the
first-party SPA but not yet in the published OpenAPI spec. Every row is
status=undocumented, classification=pending — platform decisions will
populate the real classifications over time.

Also completes the cross-PR forward link PR A left dangling: adds
"See Private endpoints → /orgs/me" to the rate-limits response-shape note.

/orgs/me gets a dedicated response-shape section (anchor #orgs-me) because
its bare {id, name} shape differs from the envelope used by the rest of v1.
EOF
)"
```

### Task B3: §8 — response-shape audit (grep-driven)

**Files:** candidates found via grep. Likely touches inline-JSON examples in `docs/api/*.md` and possibly `docs/user-guide/*.md`.

- [ ] **Step 1: Grep for removed-or-renamed field names**

Run these Grep searches on `docs/`, output_mode=content with -n=true. Record every file:line hit for each pattern:

- Pattern: `current_location_id`
- Pattern: `"org_id"` (quoted to avoid matches in prose about "organization ID")
- Pattern: `"asset_id"` (same reasoning)
- Pattern: `"asset_name"`
- Pattern: `"location_id"`
- Pattern: `"location_name"`
- Pattern: `"deleted_at"`
- Pattern: `"count":` (in JSON examples for list responses)

Most of these were removed by TRA-396. Any hit in an inline-JSON example means the example is stale.

- [ ] **Step 2: Per-hit triage**

For each hit:

- Is the file prose or an auto-generated artifact? (All files under `docs/` are hand-maintained; `static/api/*` is platform-owned and off-limits. If a grep hit is in `static/api/*`, ignore it — that's a platform bug to file separately.)
- Is the hit in an inline JSON example? If yes, rewrite the example to the post-TRA-396 shape:
  - `"id":` → `"surrogate_id":` (where the field was the integer internal ID)
  - Remove `"org_id":`, `"current_location_id":`, `"deleted_at":` lines entirely
  - For `/locations/current` response items: change from `{asset_id, asset_name, asset_identifier, location_id, location_name, last_seen}` → `{asset, location, last_seen}` (where `asset` and `location` are now just identifier strings)
  - For `/assets/{identifier}/history` response items: check the post-TRA-396 shape in the live `/api` reference, update the example to match
  - `"count":` in list wrappers → `"limit":`

- [ ] **Step 3: Also scan narrative prose that calls out removed fields by name**

In the hits list, check surrounding prose. If prose says "each record has an `org_id`" or "we return the `current_location_id` on read," rewrite to match the post-TRA-396 reality (no `org_id` in list items, use `current_location` identifier on asset responses).

- [ ] **Step 4: Apply the rewrites**

Use Edit tool per file. For each edit, keep the change focused on the shape drift — don't scope-creep into reformatting untouched content.

- [ ] **Step 5: Verify**

Run: `pnpm typecheck && pnpm build`
Expected: both pass.

- [ ] **Step 6: Manual visual check**

Run: `pnpm serve`. Open every file the grep touched. Confirm inline JSON examples read cleanly and match what an integrator would actually see from the live API.

- [ ] **Step 7: Commit**

```bash
git add docs/
git commit -m "$(cat <<'EOF'
docs(tra-408): audit and update post-TRA-396 response shapes in prose (§8)

Inline JSON examples and narrative prose in the docs referenced fields that
TRA-396 removed or renamed — `id` → `surrogate_id`, `org_id`/`current_location_id`/
`deleted_at` removed, flatter shape on `/locations/current` items and
`/assets/{identifier}/history`, `count` → `limit` in list wrappers.

Redoc-rendered schemas (auto-generated from platform-owned openapi.yaml) are
already correct; this sync only touches hand-maintained prose.
EOF
)"
```

_If Step 1 returned zero hits across all patterns, §8 is a no-op. Skip the commit and note in the PR body that no prose examples had stale shapes._

### Task B4: §5 — Integrations fill + index page + sidebar fix

**Files:**

- Rewrite: `docs/integrations/mqtt-message-format.md`
- Rewrite: `docs/integrations/fixed-reader-setup.md`
- Create: `docs/integrations/index.md`
- Modify: `sidebars.ts` (place `"integrations/index"` first in `integrationsSidebar`)

- [ ] **Step 1: Rewrite `docs/integrations/mqtt-message-format.md`**

Use Write tool (full file replacement) with content:

```markdown
---
sidebar_position: 2
---

# MQTT message format

## Status

MQTT is the ingest path TrakRF inherits from prior fixed-reader deployments — the schema and processing pipeline that backs the handheld scan flow today were built against the MQTT message format used in those earlier projects. That foundation is already in place in the platform.

**First-party MQTT integration documentation is planned for post-handheld-launch.** The public handheld scanner experience is the near-term priority; MQTT docs will follow once that ships and the first fixed-reader integration engagements begin.

No committed timeline. This page will be rewritten with the message schema, topic conventions, broker configuration, and authentication details when that work starts.

## If you need this today

[Email support](mailto:support@trakrf.id) with your use case. Concrete early-adopter deployments inform the scope of the first-party docs and can accelerate scheduling.
```

- [ ] **Step 2: Rewrite `docs/integrations/fixed-reader-setup.md`**

Use Write tool with content:

```markdown
---
sidebar_position: 3
---

# Fixed reader setup

## Status

TrakRF's current focus is the handheld scanner workflow. The platform data model and ingest pipeline are carried over from prior fixed-reader deployments and already handle fixed-reader data shapes (MQTT messages, location-anchored events, zone-based rules).

**Self-serve fixed-reader deployment — provisioning the reader, configuring its MQTT target, mapping antennas to TrakRF locations — is planned for post-handheld-launch.** The product sequence is: ship the handheld experience first, then build out the fixed-reader setup surface.

No committed timeline. This page will be replaced with step-by-step deployment and configuration instructions when that work starts.

## If you need this today

[Email support](mailto:support@trakrf.id). Early fixed-reader deployments are handled as engagements for now; documented self-service comes after the handheld launch.
```

- [ ] **Step 3: Create `docs/integrations/index.md`**

Write the new file:

```markdown
---
sidebar_position: 1
title: Integrations
---

# Integrations

This section will cover the non-REST-API integration paths into TrakRF.

## What's available now

None of the integration surfaces below are documented yet for self-service. Early deployments are handled as direct engagements — [email support](mailto:support@trakrf.id) if one of these describes your use case.

- **[MQTT message format](./mqtt-message-format)** — the ingest path used by prior fixed-reader deployments; schema and pipeline live, docs pending.
- **[Fixed reader setup](./fixed-reader-setup)** — deploying CS463 and similar fixed RFID readers against a TrakRF org.

## What's documented today

For REST API integration (the primary customer-facing integration surface), start at **[Getting started → Using the API](/docs/getting-started/api)** and the **[interactive API reference](/api)**.
```

_The link `/docs/getting-started/api` depends on Task B5. B4 runs before B5 per the commit order (spec says §5 before §4 because §4 is the biggest structural change, done last to avoid churn). That means this link will be broken until B5 lands. Strategy: skip the build check here and defer it to B5._

- [ ] **Step 4: Update `sidebars.ts` integrationsSidebar**

Use Edit tool:

- `old_string`:

  ```typescript
    integrationsSidebar: [
      {
        type: "category",
        label: "Integration Guides",
        items: [
          "integrations/mqtt-message-format",
          "integrations/fixed-reader-setup",
        ],
      },
    ],
  ```

- `new_string`:

  ```typescript
    integrationsSidebar: [
      "integrations/index",
      {
        type: "category",
        label: "Integration Guides",
        items: [
          "integrations/mqtt-message-format",
          "integrations/fixed-reader-setup",
        ],
      },
    ],
  ```

_Docusaurus's `type: "docSidebar"` navbar item auto-lands on the first sidebar entry. Putting `integrations/index` first makes clicking **Integrations** in the top nav route to the new index page without any `docusaurus.config.ts` change._

- [ ] **Step 5: Partial verify**

Run: `pnpm typecheck`
Expected: 0 errors.

Skip `pnpm build` here — the `/docs/getting-started/api` link from `integrations/index.md` will fail until B5 creates that page. Full build verification happens in B5.

- [ ] **Step 6: Commit**

```bash
git add docs/integrations/ sidebars.ts
git commit -m "$(cat <<'EOF'
docs(tra-408): fill Integrations placeholders and fix nav landing (§5)

MQTT and fixed-reader docs now show honest "planned post-handheld-launch"
abstracts instead of bare "Coming Soon" placeholders. No committed
timeline; pages will be rewritten when that work starts.

New integrations/index.md becomes the landing page for the Integrations
top-nav item (Docusaurus docSidebar auto-lands on first sidebar entry).

Follow-up to file: "write MQTT integration docs" and "write
fixed-reader-setup docs" Linear issues for post-handheld-launch.
EOF
)"
```

### Task B5: §4 — Getting Started folder split (API quickstart track)

**Files:**

- Move: `docs/getting-started.md` → `docs/getting-started/ui.md`
- Create: `docs/getting-started/index.md`
- Create: `docs/getting-started/api.md`
- Modify: `sidebars.ts` (replace `"getting-started"` with a category for the new structure)
- Possibly modify: `docusaurus.config.ts` footer link
- Possibly modify: inbound links from other docs pointing at `./getting-started` or `/docs/getting-started`

- [ ] **Step 1: Create the target directory and move the existing file**

```bash
mkdir docs/getting-started
git mv docs/getting-started.md docs/getting-started/ui.md
```

Use git's rename detection to preserve history.

- [ ] **Step 2: Update the moved file's frontmatter**

Use Edit tool on `docs/getting-started/ui.md`:

- `old_string`:

  ```markdown
  ---
  sidebar_position: 1
  ---

  # Getting Started
  ```

- `new_string`:

  ```markdown
  ---
  sidebar_position: 2
  title: Using the app
  ---

  # Getting started — using the app
  ```

_The current H1 is "Getting Started." Retitling to "using the app" makes the parallel-tracks naming clear in every surface — sidebar, page title, breadcrumb._

- [ ] **Step 3: Create `docs/getting-started/index.md`**

Write:

```markdown
---
sidebar_position: 1
title: Getting started
---

# Getting started

TrakRF can be used two ways — through the first-party web app with a handheld reader, or through the REST API from your own code. Pick the track that matches your integration plan.

## Using the app

End-to-end: pair a handheld reader, scan tags, see reports. 15 minutes, start to first saved scan. You'll need a supported Chromium browser and a Convergence CS108 reader.

[**Start the UI quickstart →**](./ui)

## Using the API

End-to-end: mint an API key, call `/api/v1/locations/current`, see the current asset-at-location snapshot. 10 minutes, no hardware required.

[**Start the API quickstart →**](./api)

## Not sure which?

If you're evaluating TrakRF for your team's operations, start with the UI quickstart — it's the fastest way to see what the platform does. If you're integrating TrakRF into existing systems (inventory, ERP, custom dashboards), start with the API quickstart.
```

- [ ] **Step 4: Create `docs/getting-started/api.md`**

Write:

````markdown
---
sidebar_position: 3
title: Using the API
---

# Getting started — using the API

This page takes you from "I just signed up" to "I called the TrakRF API and got a `200` back" in about 10 minutes, using only standard HTTP tools. It mirrors the [UI quickstart](./ui) — pick whichever track matches your integration plan.

## What you'll need

- A TrakRF account. Sign up at [app.trakrf.id](https://app.trakrf.id) if you don't have one yet.
- An API client of your choice — `curl`, Postman, HTTPie, or your language's standard HTTP library. This guide uses `curl` in examples.
- 10 minutes.

## 1. Mint your first API key

1. Sign in at [app.trakrf.id](https://app.trakrf.id).
2. Click **Settings** in the left nav, then **API Keys**.
3. Click **Create Key**. Give it a descriptive name (e.g. "local dev"), choose scopes (`assets:read` and `locations:read` are enough for this quickstart), and submit.
4. **Copy the JWT immediately.** It's shown once at creation time and can't be recovered later.
5. Save it to an environment variable for the next steps:

   ```bash
   export TRAKRF_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```

Full detail: [Authentication → Mint your first API key](../api/authentication#mint-your-first-api-key).

## 2. Make your first call

The `/api/v1/locations/current` endpoint returns a snapshot of where TrakRF last saw each asset. It's cheap, requires only `locations:read`, and gives you a live signal that your key works:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/locations/current
```

A successful response looks like:

```json
{
  "data": [
    {
      "asset": "ASSET-0001",
      "location": "LOC-0001",
      "last_seen": "2026-04-20T14:32:18Z"
    }
  ],
  "limit": 100
}
```

The `data` array holds one item per asset that has ever been scanned. Each item is `{ asset, location, last_seen }` where `asset` and `location` are the business **identifiers** (not integer surrogate IDs — see [Resource identifiers](../api/resource-identifiers) for why).

If you get a `401`, the key is malformed or not being sent in the header. If you get a `403`, the key lacks `locations:read`. If you get a `429`, you're being rate-limited — see [Rate limits](../api/rate-limits).

## 3. Interpret the response

The two key concepts integrators trip on:

- **`identifier` vs `surrogate_id`** — every resource has a human-meaningful string identifier (what you see in URLs and as `asset` / `location` values above) and an integer surrogate_id (returned in full resource objects). Always key on `identifier`. Full convention: [Resource identifiers](../api/resource-identifiers).
- **Response envelope** — most endpoints wrap payloads in `{ "data": ..., ... }`. List endpoints add pagination metadata (`limit`, `next_cursor`). The exception is `GET /api/v1/orgs/me` (see [Private endpoints: /orgs/me](../api/private-endpoints#orgs-me)).

## 4. Next steps

- **[Interactive reference](/api)** — every endpoint, request/response shape, try-it-now widget.
- **[Postman collection](../api/postman)** — ready-to-import JSON.
- **[REST API Reference](../api/rest-api-reference)** — what's in the reference and how to use it.
- **[Rate limits](../api/rate-limits)** — request budgets, retry-after semantics.
- **[Error codes](../api/error-codes)** — the common error envelope and how to handle each status.
````

- [ ] **Step 5: Update `sidebars.ts` userGuideSidebar**

Use Edit tool:

- `old_string`:

  ```typescript
    userGuideSidebar: [
      "getting-started",
      {
        type: "category",
        label: "User Guide",
  ```

- `new_string`:

  ```typescript
    userGuideSidebar: [
      {
        type: "category",
        label: "Getting started",
        link: { type: "doc", id: "getting-started/index" },
        items: [
          "getting-started/ui",
          "getting-started/api",
        ],
      },
      {
        type: "category",
        label: "User Guide",
  ```

_The `link: { type: "doc", id: "getting-started/index" }` makes the category label itself clickable and route to the index page. Children show nested. The **User Guide** navbar (`type: "docSidebar"`) will auto-land on the first entry, which is now the Getting started category — clicking it routes to the index page._

- [ ] **Step 6: Grep and fix inbound links to the old path**

Run Grep on `docs/` for these patterns; update any hits:

- `./getting-started)` → decide per hit whether to link to `./getting-started/index`, `./getting-started/ui`, or `./getting-started/api`. From sibling docs (e.g. `docs/user-guide/reader-setup.md`), a link that used to go to the whole Getting Started page now most likely wants `./getting-started/ui`.
- `/docs/getting-started)` → same, case by case.
- `/docs/getting-started#` → these targeted anchors within the old file; they now live in `docs/getting-started/ui.md` — update to `/docs/getting-started/ui#...`.
- `(../getting-started` → relative links from one-level-deeper dirs (user-guide, app-tour).

Apply each fix using Edit.

- [ ] **Step 7: Check the footer link in `docusaurus.config.ts`**

The footer has:

```typescript
{
  label: "Getting Started",
  to: "/docs/getting-started",
},
```

Docusaurus _should_ resolve `/docs/getting-started` to the new `getting-started/index.md` automatically (trailing-slash aware, index-file aware). Run `pnpm build` and check. If the broken-link check fires on this link, update the footer `to` to `/docs/getting-started/` (trailing slash) or whatever resolves in the build output.

- [ ] **Step 8: Full verification**

Run: `pnpm typecheck && pnpm build`
Expected: both pass. This is the first full build since Task A0 — all B1–B5 changes verify together.

- [ ] **Step 9: Manual visual check — every touched surface**

Run: `pnpm serve`. Walk through:

- Click **User Guide** in the top navbar → should land on Getting started index page.
- Click **UI quickstart** card → should route to the ui page.
- Click **API quickstart** card → should route to the api page.
- In the sidebar, click "Getting started" category label → routes to index.
- Click "Using the app" → ui page. Click "Using the API" → api page.
- Click the footer "Getting Started" link → routes to index (or the first item Docusaurus chose).
- Click **Integrations** in the top navbar → should land on the new integrations/index.md. (Verifies §5 nav fix in the context of full build.)
- Visit `/docs/api/resource-identifiers` — everything renders, all outbound links resolve.
- Visit `/docs/api/private-endpoints` — same.
- Visit `/docs/getting-started/api` — every link in the "Next steps" section resolves.

- [ ] **Step 10: Commit**

```bash
git add docs/getting-started/ sidebars.ts docusaurus.config.ts
# The docusaurus.config.ts add is only needed if the footer link needed a fix;
# git add is safe if there is no change.
git commit -m "$(cat <<'EOF'
docs(tra-408): split Getting Started into UI and API tracks (§4)

Moves docs/getting-started.md → docs/getting-started/ui.md (content unchanged
except for title/frontmatter) and adds docs/getting-started/index.md as a
landing page plus docs/getting-started/api.md as the API-integrator quickstart
(the path a new developer evaluating the API can now follow from "I have an
account" to "I got a 200 back" without reverse-engineering the JS bundle).

URL break: /docs/getting-started now resolves to the index page via the new
Docusaurus category with link-to-doc config. Inbound links updated across
docs/** to target either ./ui (UI-specific context) or ./index (general).

Sign-up URL centralized on the Authentication page (linked from the API
quickstart) rather than being hardcoded in prose across multiple files.
EOF
)"
```

### Task B6: PR B end-to-end verification and push

**Files:** none modified.

- [ ] **Step 1: Fresh clean build**

Run: `pnpm build`
Expected: clean, no broken-link errors.

- [ ] **Step 2: Fresh typecheck**

Run: `pnpm typecheck`
Expected: 0 errors.

- [ ] **Step 3: Review the commit series**

Run: `git log origin/main..HEAD --oneline`
Expected: 4 or 5 commits in the order: §7, §6, §8 (optional no-op), §5, §4.

- [ ] **Step 4: Final browser walkthrough**

Run: `pnpm serve`. Visit in order:

- `/docs/getting-started` (index) → follow both quickstart links
- `/docs/getting-started/api` → follow every outbound link in Next steps
- `/docs/api/resource-identifiers` → follow the private-endpoints link
- `/docs/api/private-endpoints` → follow the rate-limits#exclusions link
- `/docs/api/rate-limits` → follow the new private-endpoints#orgs-me link
- `/docs/integrations` (index) → follow the getting-started/api link
- Top-nav **Integrations** click → lands on index
- Top-nav **User Guide** click → lands on Getting started index

- [ ] **Step 5: Push and open PR**

```bash
git push -u origin feat/tra-408-api-quickstart-and-conventions
```

```bash
gh pr create --title "feat(tra-408): API docs quickstart + new conventions (§4 §5 §6 §7 §8)" --body "$(cat <<'EOF'
## Summary

Second (and final) PR for TRA-408. Builds on the factual-correction sweep merged via the first PR. Adds the missing integrator-quickstart path, fills the Integrations placeholders with honest roadmap abstracts, and documents the post-TRA-396 conventions a new integrator needs to understand.

Design spec: `spec/superpowers/specs/2026-04-20-tra-408-api-docs-fixes-design.md`.

### What changed
- **§7:** New `docs/api/resource-identifiers.md` documents the `identifier` (string, URL path) vs `surrogate_id` (integer, response body) distinction TRA-396 introduced. First-class sidebar entry between REST API Reference and Webhooks.
- **§6:** New `docs/api/private-endpoints.md` catalogs the 11 endpoints used by the first-party SPA but not published in the OpenAPI spec. Every row is "undocumented / pending" — platform decisions populate real classifications over time. Also backfills the cross-link from `rate-limits.md#orgs-me` that PR A left as plain prose.
- **§8:** Swept `docs/**/*.md{,x}` for references to TRA-396-removed fields (`current_location_id`, `org_id`, `asset_id`, `asset_name`, `location_id`, `location_name`, `deleted_at`, `count`). Inline JSON examples updated to match the post-TRA-396 shape. *Adjust to "no stale references found" if §8 was a no-op.*
- **§5:** Integrations placeholders rewritten with honest "planned post-handheld-launch" abstracts (MQTT + fixed-reader). New `integrations/index.md` becomes the top-nav landing page (replaces landing on the MQTT placeholder).
- **§4:** Getting Started split into a folder: `getting-started/index.md` (landing) + `getting-started/ui.md` (moved content) + `getting-started/api.md` (new API quickstart). The API quickstart gets a new developer from "I have an account" to "I got a 200 back" using only docs content — no reverse-engineering required. The `/docs/getting-started` URL now routes to the new index page.

### URL break
`/docs/getting-started` is now the index page, not the UI quickstart directly. Inbound links updated throughout `docs/`. Acceptable pre-launch per project convention.

### Out of scope
- Capture real screenshot for §1's mint-key walkthrough (follow-up to PR A, tracked separately).
- Populate real classifications in `private-endpoints.md` — platform decisions, filed as follow-up.
- Rewrite TRA-407-dependent parts of `error-codes.md` — blocked on TRA-407 landing.

### Follow-ups to file
- Capture §1 screenshot via `scripts/refresh-screenshots.sh` pattern.
- "Write MQTT integration docs" Linear issue (post-handheld-launch).
- "Write fixed-reader-setup docs" Linear issue (post-handheld-launch).
- Per-endpoint classification rows for `private-endpoints.md` (platform decision).

## Test plan

- [ ] `pnpm typecheck` passes
- [ ] `pnpm build` passes (`onBrokenLinks: "throw"` enforced)
- [ ] `pnpm serve` — manual walkthrough confirms every new page renders, every sidebar/nav click lands where expected, every cross-link resolves
- [ ] Preview deploy at `docs.preview.trakrf.id` spot-checked before marking ready

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: Verify preview deploy**

Wait for the preview URL from the sync-preview workflow. Spot-check the new pages and the full navigation surface at `docs.preview.trakrf.id` before requesting review.

---

## Post-merge cleanup (after both PRs merge)

- [ ] `git checkout main && git pull`
- [ ] `git branch -d feat/tra-408-api-quickstart-and-conventions`
- [ ] Close TRA-408 in Linear with links to both merged PRs.
- [ ] File the follow-up Linear issues documented in each PR description.
