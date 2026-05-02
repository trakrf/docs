# TRA-569 Doc/Service Drift Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land five doc-only corrections to `docs/api/rate-limits.md` and `docs/api/resource-identifiers.md` so the launch-day docs match the v1 service contract surfaced by BB13. Source: TRA-569 (parent TRA-566). Findings: S1, S2, S3, S5, S11.

**Architecture:** Two markdown files, four logical edits, one final build/PR commit. S1 and S2 are coupled — they share the "Exclusions" section of `rate-limits.md` and the post-fix shape is "no exclusions; everything participates in the bucket." S3, S5, S11 each touch a different section of `resource-identifiers.md` and are independent edits. Option B is assumed for S5 (doc fix only — no service change), per the ticket's stated recommendation. No code, no tests, no spec changes — `static/api/openapi.json` already encodes the truth (`current_location_id` etc. carry `nullable: true`); only the prose is wrong.

**Tech Stack:** Docusaurus 3.x markdown, pnpm exclusively (`npx` is forbidden — use `pnpm exec` / `pnpm dlx`). Prettier formats markdown. `docusaurus.config.ts` enables `onBrokenLinks: "throw"` and `onBrokenAnchors: "throw"`, so any reference to a deleted heading/anchor fails the build — that's the safety net for these edits.

---

## Prerequisites

- Working in worktree `.worktrees/tra-569` on branch `miks2u/tra-569-docservice-drift-fixes-s1-s2-s3-s5-s11`. Confirm with `git branch --show-current && pwd` — branch should match, `pwd` should end in `.worktrees/tra-569`.
- `pnpm install` already run during worktree setup; re-run if `node_modules/` is missing.
- `pnpm typecheck` passes from a clean baseline (verified at worktree creation).
- Port 3000 free for `pnpm dev` if you want to render-check during edits. If another dev server is running in the main checkout, either stop it or use `PORT=3001 pnpm dev`.
- `gh` CLI authenticated for the final `gh pr create` (Task 5). Confirm with `gh auth status`.
- **No CHANGELOG entry required.** Per the recent flatten (commit `b8aa77f`, 2026-04-30), `docs/api/CHANGELOG.md` only carries the single `## v1.0 — Launch (TBD)` heading until launch ships. These are pre-launch doc corrections to the v1 contract, not customer-visible deltas.

## File Structure

- **Modify** — `docs/api/rate-limits.md`
  - Rewrite the "Exclusions" section (lines 81–90 in current `HEAD`): drop the false `/orgs/me`-and-writes carve-outs. Replace with a single short section ("All endpoints participate") and a probe-frequency note for `/orgs/me`. Update line 31 ("Every API response — successful or throttled — includes three headers…") only if the rewrite needs it; the sentence is already factual post-fix and should stay.
- **Modify** — `docs/api/resource-identifiers.md`
  - Rewrite the trailing prose of the "Foreign-key fields in responses come as flat scalar pairs" section (lines 75): replace the "absent from the response — the same omit-when-unset convention" claim with the truth (FK fields are present-as-null when unset). Add a small three-behavior reference paragraph or table immediately after, naming which fields are _omitted-when-unset_, which are _present-as-null_, and noting that everything else is always-present.
  - Rewrite the "Round-trip consistency" section (lines 77–90): the "GET, mutate, PUT back without remapping" claim is false — the read schema carries `id`, `created_at`, `updated_at`, `tags`; the write schema does not, and the server returns `400 validation_error: "unknown field 'id' in request body"` on PUT. Replace with an honest description of the read/write asymmetry: the four read-only fields integrators must strip before PUT, and an example showing the strip-then-PUT pattern.
  - Update the "Locations: `parent_id` and `parent_external_key`" section (lines 92–119): the example `path` value (`"WAREHOUSE-WEST.BACK-STORAGE-2"`) misrepresents the normalization. Replace the JSON example with realistic values (lowercase, hyphens → underscores). Update the `path` description (line 119) to explicitly state path segments are derived via lowercasing and hyphen-to-underscore substitution, and warn against splitting on `.` to recover ancestor `external_key`s.
  - Update the section's closing paragraph about root-location parent fields (line 110: "Root locations (no parent) omit both fields"). After S3 we know `parent_id` and `parent_external_key` are _present-as-null_ on root locations, not omitted — fix this in the same commit as S3 (Task 2).

No new files, no sidebar changes, no spec changes, no code changes. The build's broken-link/anchor checker is the verification net; the human render check at the end (Task 5 step 3) is the qualitative pass.

---

## Task 1: S1 + S2 — Rate-limits doc honesty (drop the false exclusions)

**Files:**

- Modify: `docs/api/rate-limits.md` (rewrite lines 81–90 in current `HEAD`)

**Decision per ticket:** Doc fix, not service fix. `/orgs/me` and write endpoints both emit `X-RateLimit-*` headers and the bucket enforces; the original "excluded so liveness probes never trip" / "writes are audited rather than rate-limited" claims were aspirational and never implemented. At 60 req/min the bucket is generous enough that real liveness/write traffic doesn't trip — match the doc to reality. Carving these out for real is a v1.1 conversation explicitly out of scope.

S1 and S2 are batched into one task (and one commit) because they share the same section of the same file and the post-fix shape replaces both bullets with a single coherent "everything participates" framing. Splitting would force a one-bullet half-state in between that wouldn't render coherently.

- [ ] **Step 1: Confirm branch state**

```bash
pwd
git branch --show-current
git log --oneline -3
```

Expected: `pwd` ends in `.worktrees/tra-569`; branch is `miks2u/tra-569-docservice-drift-fixes-s1-s2-s3-s5-s11`; the three head commits are the `main` tip (`7659335 Merge pull request #60 …`) and the two preceding merges (`b8aa77f docs: pre-launch cleanup pass …` and `e6fd32f Merge pull request #59 …`). The worktree should have no commits beyond `main` yet.

- [ ] **Step 2: Read the current "Exclusions" section to confirm line numbers**

Read `docs/api/rate-limits.md` lines 80–95. The current section starts at `## Exclusions` (line 81 — verify exact line number, the ticket text was prepared against an earlier `HEAD`) and runs through the `All other endpoints (the public read surface) participate in the bucket.` sentence (around line 90). The next heading is `## Per-key, not per-organization`. The "Response-shape note" callout (line 88 in current `HEAD`) about `/orgs/me` returning the standard envelope must survive — it links to `private-endpoints#orgs-me` and is correct and useful regardless of rate-limit changes. Re-anchor it under the new section if its old position no longer makes sense.

- [ ] **Step 3: Search for cross-references to the section**

```bash
grep -rn '#exclusions\|orgs/me.*excluded\|writes are audited\|writes are uncapped\|liveness probes never trip' docs/ src/ sidebars.ts spec/ static/ 2>/dev/null
```

Expected: matches inside `docs/api/rate-limits.md` itself (the section being rewritten) and possibly inside `spec/superpowers/` historical specs/plans (those are frozen — leave them). Any _live_ doc cross-link to `#exclusions` (e.g., from `docs/api/quickstart.mdx` or `docs/api/errors.md`) must be rewritten in the same commit; otherwise the build will fail with a broken-anchor error. The most likely place for a stray reference is `docs/api/private-endpoints.md` (which catalogs `/orgs/me`).

- [ ] **Step 4: Rewrite the section**

Replace the current `## Exclusions` block (`## Exclusions` heading through and including the `All other endpoints (the public read surface) participate in the bucket.` sentence) with the following block. The `## Per-key, not per-organization` heading on the next line stays where it is.

```markdown
## All endpoints participate in the bucket

Every endpoint on the public surface — including `GET /api/v1/orgs/me` and every write under `/api/v1/assets` and `/api/v1/locations` — counts against your bucket and emits `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers. There are no carve-outs.

At 60 requests/minute the steady-state budget comfortably covers normal integration traffic, but a few patterns are worth flagging:

- **Liveness/connectivity probes against `GET /api/v1/orgs/me`** — these count, so probe at a frequency your budget tolerates. Once per minute is the simplest pattern that always fits inside the default tier with room to spare; once every 30 seconds is fine if `/orgs/me` is the only thing the probe hits. Aggressive sub-second probes will trip throttling.
- **Bulk writes** — every `POST` / `PUT` / `DELETE` under `/api/v1/assets` and `/api/v1/locations` consumes one token. For ingest workloads above the default tier, [contact support](mailto:support@trakrf.id) about a custom tier rather than spreading writes across multiple keys.

`GET /api/v1/orgs/me` returns the standard `{ "data": ... }` envelope, same as every other endpoint on the public surface. See [Private endpoints → /orgs/me](./private-endpoints#orgs-me) for the full catalog entry.
```

Notes for the writer:

- The new heading anchor (`#all-endpoints-participate-in-the-bucket`) replaces the old `#exclusions`. The grep in Step 3 should already have surfaced any cross-links that need updating — handle them in this same commit.
- Keep the existing `## Per-key, not per-organization` and `## Horizontal scaling` sections that follow this block untouched.
- The "Response-shape note" sentence that linked to `/orgs/me` in the catalog is preserved as the closing paragraph of the new section (it's the last paragraph in the block above).

- [ ] **Step 5: Run prettier on the file**

```bash
pnpm exec prettier --write docs/api/rate-limits.md
```

Expected: file is rewritten in place; `git diff --stat docs/api/rate-limits.md` shows the file as modified. If prettier rewrites unrelated lines (e.g. table alignment elsewhere in the file), reset those — only the rewritten section should change in this commit.

- [ ] **Step 6: Build the docs and confirm the change renders cleanly**

```bash
pnpm build 2>&1 | tail -40
```

Expected: build completes with `Compiled successfully` (or equivalent) and no broken-link / broken-anchor errors. Any `Docusaurus broken anchors` error referring to `#exclusions` means a cross-reference was missed in Step 3 — find it (`grep -rn '#exclusions' docs/`) and fix it in this same commit before continuing.

- [ ] **Step 7: Commit**

```bash
git add docs/api/rate-limits.md
git commit -m "docs(rate-limits): drop false /orgs/me + write-endpoint exclusions (S1, S2)

/orgs/me and every write under /api/v1/{assets,locations} emit
X-RateLimit-* headers and the bucket enforces. The original
'excluded so liveness probes never trip' and 'writes are audited
rather than rate-limited' claims were aspirational and never
implemented. Match the doc to the implementation: there are no
carve-outs, and at 60 req/min the steady-state budget covers
normal integration traffic.

Refs TRA-569 (S1, S2)."
```

If the grep in Step 3 surfaced cross-references in _other_ files (e.g., a stale `#exclusions` link in `quickstart.mdx`), include those in this same commit so the broken-anchor build never sees an inconsistent tree. List them in the commit body.

---

## Task 2: S3 — FK fields are present-as-null, not omitted

**Files:**

- Modify: `docs/api/resource-identifiers.md`
  - The trailing prose of the "Foreign-key fields in responses come as flat scalar pairs" section (line 75 in current `HEAD`)
  - The closing sentence of the "Locations: `parent_id` and `parent_external_key`" section (line 110: "Root locations (no parent) omit both fields")

**Decision per ticket:** Doc fix only. The OpenAPI spec already declares `current_location_id`, `current_location_external_key`, `parent_id`, `parent_external_key` as `nullable: true` (verified — see `static/api/openapi.json` `asset.PublicAssetView` lines 161–168 and `location.PublicLocationView`). Live behavior matches the spec — these fields are always present, set to `null` when the relationship is unset. The doc's "absent from the response" framing was wrong from the start. The genuinely omit-when-unset fields (`description`, `valid_to`) keep that behavior; the doc should be honest about all three behaviors coexisting.

- [ ] **Step 1: Re-read the current FK-fields section to confirm exact wording**

Read `docs/api/resource-identifiers.md` lines 56–75. The sentence to replace is the last one in the section (line 75 in current `HEAD`):

> When the relationship is unset (an asset that has never been scanned, a root location with no parent), both fields are absent from the response — the same omit-when-unset convention used on optional [date fields](./date-fields).

Also re-confirm line 110 in the locations subsection ends with "Root locations (no parent) omit both fields." That sentence is the second wrong claim (same factual error, different position) and gets fixed in the same commit.

- [ ] **Step 2: Replace the false claim at line 75 with the present-as-null truth + three-behavior callout**

Replace the single sentence at line 75 (the "When the relationship is unset … absent from the response — the same omit-when-unset convention used on optional [date fields](./date-fields)." sentence) with this multi-paragraph block:

```markdown
When the relationship is unset (an asset that has never been scanned, a root location with no parent), both fields are still **present in the response, set to `null`**. The OpenAPI spec declares them `nullable: true` and the service emits them on every response; clients should null-check, not key-presence-check.

That makes three response-shape behaviors that coexist on these resources, and it's worth knowing which is which:

| Behavior               | Fields                                                                                                  | Test for                     |
| ---------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------- |
| **Always present**     | `id`, `name`, `external_key`, `created_at`, `updated_at`, `is_active`, `valid_from` (and most scalars)  | the value itself             |
| **Present as `null`**  | `current_location_id`, `current_location_external_key`, `parent_id`, `parent_external_key`              | `field === null`             |
| **Omitted when unset** | `valid_to`, `description` (and any optional field documented as omit-when-unset on its individual page) | key presence (`'k' in resp`) |

The omit-when-unset set is small and explicit. When in doubt, check the field's documentation page — [Date fields](./date-fields) covers `valid_to`, this page covers FK pairs, and any field not called out in either is in the always-present row.
```

Notes:

- The wording "and any optional field documented as omit-when-unset on its individual page" is intentionally hedged — the set is small enough today (`valid_to`, `description`) but new fields may join it in v1.1+. Do not enumerate further beyond what's verifiable from the spec and the page-level docs as of this commit.
- The link `[Date fields](./date-fields)` replaces the link that was deleted from the original sentence.
- The table uses pipe-aligned markdown (matching the style already used in `rate-limits.md`). Prettier may renormalize column widths in Step 4 — that's fine.

- [ ] **Step 3: Fix the matching root-location claim at line 110**

Replace this sentence (currently at the end of the prose paragraph below the locations JSON example):

> Root locations (no parent) omit both fields.

With:

> Root locations (no parent) carry both fields as `null`. They're never absent from the response — null-check, don't key-check.

Keep the surrounding sentences ("Set either `parent_id` or `parent_external_key` on create or update to nest under an existing parent." stays as-is.)

- [ ] **Step 4: Run prettier**

```bash
pnpm exec prettier --write docs/api/resource-identifiers.md
```

Expected: file rewritten; only the FK-fields section and the locations-section sentence change in `git diff`. If prettier reflows unrelated table-alignment elsewhere in the file, accept that (it's a one-time formatting normalization) but inspect the diff before committing.

- [ ] **Step 5: Build the docs**

```bash
pnpm build 2>&1 | tail -40
```

Expected: clean build, no broken-link errors. The `[Date fields](./date-fields)` link is the only new reference; verify it resolves (it's an existing page).

- [ ] **Step 6: Eyeball the rendered page (optional but recommended)**

```bash
pnpm dev
# Visit http://localhost:3000/api/resource-identifiers in a browser
# Confirm the new table renders cleanly and the FK-fields paragraph reads coherently
# Ctrl+C to stop the dev server when done
```

If the table renders as a wall of pipes (broken markdown), the column count or escaping is off — the most likely culprit is an unescaped backtick in a cell. Fix and re-render before committing.

- [ ] **Step 7: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(resource-identifiers): FK fields are present-as-null, not omitted (S3)

current_location_id, current_location_external_key, parent_id, and
parent_external_key are declared nullable: true in the OpenAPI spec
and the service always emits them — null when the relationship is
unset, populated otherwise. The previous 'absent from the response,
same omit-when-unset convention as date fields' claim was wrong;
the canonical model is 'present as null when unset'.

Adds an explicit three-behavior reference (always-present /
present-as-null / omitted-when-unset) so integrators writing
generated-client field-presence checks pick the right pattern for
each field. Also fixes the matching 'root locations omit both
fields' sentence in the locations subsection.

Spec is correct; this is doc-only.

Refs TRA-569 (S3)."
```

---

## Task 3: S5 — GET → PUT round-trip honesty (Option B: doc only)

**Files:**

- Modify: `docs/api/resource-identifiers.md` — rewrite the "Round-trip consistency" section (lines 77–90 in current `HEAD`)

**Decision per ticket:** Option B — doc fix, no service change. The current strict-rejection behavior (`400 validation_error: "unknown field 'id' in request body"`) is a feature, not a bug — it surfaces client mistakes early. The doc claim was aspirational; reality is that REST APIs commonly distinguish read shape from write shape. Verified asymmetry from `static/api/openapi.json`:

- Read shape (`asset.PublicAssetView`): `id`, `created_at`, `updated_at`, `tags` are present **and not in the write shape**.
- Write shape (`asset.UpdateAssetRequest`): no `id`, no `created_at`, no `updated_at`, no `tags`. Generated TypeScript clients with strict typing will catch the mismatch at compile time; weaker generators won't, hence the prose-level guidance.

This task is independent of Tasks 1 and 2 and lands as its own commit.

- [ ] **Step 1: Re-read the current section to confirm line range**

Read `docs/api/resource-identifiers.md` lines 76–91. The section runs from the H2 `## Round-trip consistency` heading through the closing prose ("Don't send both for the same relationship in one request.") and the trailing blank line that separates it from the next H2 (`## Locations: parent_id and parent_external_key`).

- [ ] **Step 2: Replace the section in full**

Replace lines 77 through 90 inclusive (the heading and its body) with the following block. The `## Locations: ...` heading on the next line stays where it is.

````markdown
## Read shape vs. write shape

Request and response field _names_ match (e.g., `current_location_external_key` reads and writes under the same name), so the natural-key parts of a `PUT` round-trip without remapping. Read shape and write shape are not identical, though: read responses include four fields that the server rejects on write — `id`, `created_at`, `updated_at`, and `tags`. A naive `GET` → mutate → `PUT` of the entire response object returns:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "unknown field 'id' in request body",
    "instance": "/api/v1/assets/4287",
    "request_id": "01J..."
  }
}
```
````

Strip the four read-only fields before `PUT`. The minimal pattern with `jq`:

\`\`\`bash

# Move an asset to a new location by its external_key

curl -sH "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287" \
| jq '.data | del(.id, .created_at, .updated_at, .tags)
| .current_location_external_key = "PORTABLE-1437"' \
| curl -X PUT \
 -H "Authorization: Bearer $TRAKRF_API_KEY" \
       -H "Content-Type: application/json" \
       -d @- \
       "$BASE_URL/api/v1/assets/4287"
\`\`\`

In a generated TypeScript client with strict typing, the read response type and the write request type are distinct, so the compiler enforces the strip — there's no manual deletion to do. In a generated Python or Go client without strict input types, you'll need to pop the four fields explicitly before sending, or wrap the API in a typed model that excludes them at the call site.

Either form of the FK pair is accepted on write. Send `current_location_id` if you have it; send `current_location_external_key` if that's what the user typed. Don't send both for the same relationship in one request — the server validates them as mutually exclusive.

The same four-field strip applies to `PUT /api/v1/locations/{id}`: `id`, `created_at`, `updated_at`, plus the read-only derived `path` and `depth` (those are computed from the parent chain and are not accepted on write).

````

Notes for the writer:

- The triple-backtick fences inside the markdown block above use escaped fences (`\`\`\``) only because they're being shown to you here; in the actual file they're plain triple-backtick fences. Make sure the bash code-fence is unescaped triple backticks.
- The `del(.id, .created_at, .updated_at, .tags)` jq expression encodes the exact strip set verified against `static/api/openapi.json`. If the spec gains another read-only field on a future v1.x release (covered by versioning's additive-only commitment), this list grows; track via `docs/api/CHANGELOG.md`.
- The closing paragraph about locations names `path` and `depth` as additional location-side read-only fields — verified against `location.PublicLocationView` in the spec. Confirm those two fields are absent from the location update schema before committing; if either turns out to be writable, drop it from the closing sentence.
- The H2 heading anchor changes from `#round-trip-consistency` to `#read-shape-vs-write-shape`. Run `grep -rn '#round-trip-consistency' docs/ src/ sidebars.ts static/` before committing to find stray references — fix any in this same commit. Most likely place to find one is the ToC sidebar of `resource-identifiers.md` itself (Docusaurus autogenerates the in-page ToC, so no manual fix needed there) or a cross-link from `quickstart.mdx`.

- [ ] **Step 3: Verify location update schema has no `path` / `depth`**

```bash
jq '.components.schemas | with_entries(select(.key | test("UpdateLocationRequest|location.UpdateRequest"))) | .[].properties | keys' static/api/openapi.json
````

Expected: a JSON array of property names that **does not include** `path` or `depth`. If it does include either, drop that field from the closing paragraph of the new section. If the jq selector returns empty (schema named differently), grep for the location update schema name (`grep -n 'UpdateLocation\|location.Update' static/api/openapi.json | head`) and re-run with the right key.

- [ ] **Step 4: Sweep for cross-references to the old anchor**

```bash
grep -rn '#round-trip-consistency\|round-trip without' docs/ src/ sidebars.ts spec/ static/ 2>/dev/null
```

Expected: matches inside `docs/api/resource-identifiers.md` (the section being rewritten) and possibly inside `spec/superpowers/` historical specs (frozen — leave them). Any _live_ doc cross-link must be rewritten in the same commit; the most likely place is `docs/api/quickstart.mdx`.

- [ ] **Step 5: Run prettier**

```bash
pnpm exec prettier --write docs/api/resource-identifiers.md
```

Expected: file rewritten; the new section is reformatted to project style. Multi-line `jq | curl` pipelines can sometimes get reflowed in unexpected ways — eyeball the resulting bash block to confirm the pipe-and-continuation structure survives.

- [ ] **Step 6: Build the docs**

```bash
pnpm build 2>&1 | tail -40
```

Expected: clean build. Any broken-anchor error referring to `#round-trip-consistency` means a cross-reference was missed in Step 4.

- [ ] **Step 7: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(resource-identifiers): document read/write schema asymmetry (S5)

The previous 'GET, mutate, PUT back without remapping' claim was
aspirational. Read responses carry id, created_at, updated_at, and
tags; the update request schema doesn't accept any of those, and
the server returns 400 validation_error on unknown fields. Match
the doc to the actual contract and show the jq-strip pattern.

This is the doc-only path (Option B per the ticket). The strict-
rejection behavior is intentionally preserved as a feature — it
catches client typos that an ignore-unknown server would silently
swallow.

Refs TRA-569 (S5)."
```

---

## Task 4: S11 — `path` is normalized; warn against splitting on `.`

**Files:**

- Modify: `docs/api/resource-identifiers.md`
  - JSON example for the location response (lines 96–108 in current `HEAD`)
  - The closing paragraph about `path` (line 119 in current `HEAD`)

**Decision per ticket:** Doc fix. The path-segment normalization (lowercase, hyphen → underscore) is real service behavior — likely from URL-slug compatibility or DB-collation history. Document it explicitly. The genuinely better fix would be making path-segment generation a 1:1 of `external_key`, but that's a meaningful behavior change with potential URL-routing implications and is a v1.1 conversation explicitly out of scope here.

This task is independent of Tasks 1, 2, 3 and lands as its own commit.

- [ ] **Step 1: Re-read the current section to confirm line numbers and example shape**

Read `docs/api/resource-identifiers.md` lines 92–120. Confirm the JSON example currently shows:

```json
"external_key": "BACK-STORAGE-2",
...
"parent_external_key": "WAREHOUSE-WEST",
"path": "WAREHOUSE-WEST.BACK-STORAGE-2",
```

— that is, `path` segments preserve the uppercased / hyphenated `external_key` form. The fix replaces the `path` value with the lowercased / underscored normalization and updates the surrounding prose.

- [ ] **Step 2: Update the JSON example**

Replace the JSON example block (the multi-line block starting `\`\`\`json`and ending with the closing`\`\`\``) with:

```json
{
  "data": {
    "id": 42,
    "external_key": "BACK-STORAGE-2",
    "name": "Back storage, bay 2",
    "parent_id": 7,
    "parent_external_key": "WAREHOUSE-WEST",
    "path": "warehouse_west.back_storage_2",
    "depth": 2
  }
}
```

The visible deltas are `path` only — every other field stays as-is. The `external_key` and `parent_external_key` retain uppercase + hyphens, which is the point: those are the natural keys the integrator picks; `path` is a derived display helper that the server lowercases and underscores.

- [ ] **Step 3: Replace the `path` description paragraph**

Replace the current closing paragraph of the section (line 119 in current `HEAD`):

> `path` is a derived label-path helper (`WAREHOUSE-WEST.BACK-STORAGE-2`) useful for sorting or indenting flat lists. It's not an identifier — you can't look a location up by its `path`.

With this expanded version:

```markdown
`path` is a derived label-path helper, useful for sorting or indenting flat lists. Its segments are derived from each ancestor's `external_key` via two transformations: **lowercase** and **hyphen → underscore**. So an `external_key` of `WAREHOUSE-WEST` contributes the segment `warehouse_west` to its descendants' paths. The path is **not** guaranteed to round-trip back to `external_key` — splitting `path` on `.` recovers the normalized segments, not the original natural keys.

If you need ancestor `external_key`s (for breadcrumbs, parent lookups, or anything that touches your system of record), use `GET /api/v1/locations/{id}/ancestors` instead — it returns the full chain with each ancestor's untransformed `external_key`. Don't try to reverse the lowercasing or underscore substitution from `path`; the transformation is lossy on `external_key`s that already contain underscores or that differ only in case.

`path` is also not an identifier — you can't look a location up by its `path`. Use `GET /api/v1/locations/lookup?external_key=...` for natural-key lookups.
```

Notes for the writer:

- The split-warning is the doc deliverable per the ticket's acceptance criteria ("Warn against splitting `path` on `.` to recover ancestor `external_key`s — that approach loses the original form").
- The `/api/v1/locations/{id}/ancestors` endpoint is referenced earlier in the same file (line 116 in current `HEAD`) — verify the endpoint name and shape match before committing. The reference here is a back-pointer to that earlier section, not a new claim.
- "lossy on `external_key`s that already contain underscores" — this means if a customer chooses `external_key: "BACK_STORAGE_2"` (already underscored), then changes to `"BACK-STORAGE-2"` later, both produce the same `path` segment `back_storage_2`. The doc doesn't need to belabor this; the one-liner is enough warning.

- [ ] **Step 4: Run prettier**

```bash
pnpm exec prettier --write docs/api/resource-identifiers.md
```

Expected: file rewritten; only the JSON example block and the path-description paragraph change in this task's `git diff` (Tasks 2 and 3 already touched other parts of this file — those should already be committed in their own commits, so this commit's diff is scoped to just the locations-section JSON + the closing paragraph).

- [ ] **Step 5: Build the docs**

```bash
pnpm build 2>&1 | tail -40
```

Expected: clean build. The new prose links to existing endpoints (`/locations/{id}/ancestors`, `/locations/lookup?external_key=`) — no new anchors introduced in this task.

- [ ] **Step 6: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(resource-identifiers): path is normalized, not external_key form (S11)

Path segments are lowercased and hyphens are replaced with
underscores before assembly, so an external_key of WAREHOUSE-WEST
contributes the segment 'warehouse_west' to its descendants'
paths. The previous example showed an unrealistic preserved-case
form. Update the JSON example to match service reality and warn
against splitting path on '.' to recover ancestor external_keys —
the transformation is lossy and the right pattern is the
/locations/{id}/ancestors endpoint.

The underlying normalization is a v1.1 conversation; this commit
fixes the doc only.

Refs TRA-569 (S11)."
```

---

## Task 5: Final build, render-check, and PR

**Files:**

- (none — verification + PR open only)

This task is the cumulative verification gate before opening the PR. It re-runs the full build against the merged state of Tasks 1–4 and dispatches a manual render-check of both pages against the live preview API behavior (per the ticket's acceptance bullet "All examples in the updated doc pages verified against live preview behavior").

- [ ] **Step 1: Confirm all four prior commits landed cleanly**

```bash
git log --oneline -5
```

Expected: the four task commits sit at the top (in some order: rate-limits, FK-fields, read/write-asymmetry, path-normalization), followed by the `main` tip (`7659335 Merge pull request #60 …`). No `WIP`, no `fixup`, no amends.

- [ ] **Step 2: Final clean build with link/anchor checks**

```bash
pnpm typecheck && pnpm lint && pnpm build 2>&1 | tail -60
```

Expected: typecheck passes, lint passes, build prints `Compiled successfully` (or equivalent) with **zero** broken-link warnings, **zero** broken-anchor warnings, and **zero** prettier complaints. If any step fails, stop and fix in a new commit (do not amend the task commits — keep them clean for the reviewer).

- [ ] **Step 3: Manual render-check against live preview**

Start the dev server and verify both pages render correctly and match live preview API behavior.

```bash
pnpm dev
```

Then open in a browser:

1. **`http://localhost:3000/api/rate-limits`** — confirm:
   - The "All endpoints participate in the bucket" section renders cleanly with the `/orgs/me` and writes bullet pattern.
   - The `[contact support](mailto:support@trakrf.id)` link works.
   - No leftover `#exclusions` or "writes are audited" copy anywhere.
   - **Live verification:** With a preview API key, run `curl -i -H "Authorization: Bearer $TRAKRF_API_KEY" "$BASE_URL/api/v1/orgs/me"` and confirm `X-RateLimit-*` headers are in the response. Repeat for `POST /api/v1/assets` (a real write — pick a throwaway external_key) and `DELETE /api/v1/assets/{id}` and confirm the same. This is the "examples verified against live preview behavior" acceptance bullet for S1+S2.

2. **`http://localhost:3000/api/resource-identifiers`** — confirm:
   - The three-behavior table renders cleanly (no broken pipe alignment).
   - The `## Read shape vs. write shape` section's bash code block (the `jq | curl` pipeline) renders without escaping artifacts.
   - The locations JSON example shows the lowercased/underscored `path: "warehouse_west.back_storage_2"`.
   - No broken anchors, no Prettier whitespace artifacts.
   - **Live verification:** With a preview API key:
     - `curl -H "Authorization: Bearer $TRAKRF_API_KEY" "$BASE_URL/api/v1/assets" | jq '.data[0]'` — confirm `current_location_id` and `current_location_external_key` are present (possibly as `null`) on at least one asset that has no location set. (S3 verification.)
     - Take any asset's `data` object, naively `PUT` it back: `curl -X PUT -H "Authorization: Bearer $TRAKRF_API_KEY" -H "Content-Type: application/json" -d "$asset_json" "$BASE_URL/api/v1/assets/$id"` — confirm the server returns `400 validation_error` mentioning an unknown field. Then strip with `jq 'del(.id, .created_at, .updated_at, .tags)'` and `PUT` the result — confirm `200`. (S5 verification.)
     - Create a location with `external_key: "BB14-LOC-A"` and a parent: `curl -X POST -H "Authorization: Bearer $TRAKRF_API_KEY" -H "Content-Type: application/json" -d '{"external_key": "BB14-LOC-A", "name": "BB14 verification", "parent_external_key": "<existing>"}' "$BASE_URL/api/v1/locations"` — confirm the response's `path` field shows the normalized form (lowercase, underscores). (S11 verification.) Clean up with `DELETE /api/v1/locations/{id}` after.

If any live behavior diverges from the doc (e.g., headers no longer present on `/orgs/me`, server now ignores unknown fields on PUT, path normalization changed), **stop** — service has shipped a change that invalidates this plan. Re-open the ticket with the new finding before continuing. The ticket assumes 2026-05-01 service state.

Stop the dev server (`Ctrl+C`) when done.

- [ ] **Step 4: Push the branch**

```bash
git push -u origin miks2u/tra-569-docservice-drift-fixes-s1-s2-s3-s5-s11
```

Expected: branch pushed to origin, tracking set. If the branch was previously pushed (e.g., during an earlier failed attempt), this is `git push` with no `-u`.

- [ ] **Step 5: Open the PR**

```bash
gh pr create --title "docs: doc/service drift fixes — S1, S2, S3, S5, S11 (TRA-569)" --body "$(cat <<'EOF'
## Summary

Five doc-only corrections to land the BB13-surfaced doc/service mismatches before BB14 verification. All five are doc fixes (no service changes); Option B chosen for S5 per the ticket's recommendation.

- **S1** — `/orgs/me` is rate-limited; doc claimed it was excluded. Fixed.
- **S2** — write endpoints are rate-limited; doc claimed they were exempt. Fixed.
- **S3** — FK fields (`current_location_id`, `current_location_external_key`, `parent_id`, `parent_external_key`) are present-as-null when unset, not omitted. Doc rewritten with explicit three-behavior reference (always-present / present-as-null / omitted-when-unset).
- **S5** — read schema carries `id`, `created_at`, `updated_at`, `tags`; write schema doesn't. Documented the asymmetry honestly with a `jq`-strip pattern instead of the false "round-trip without remapping" claim. The strict-rejection server behavior is preserved as a feature.
- **S11** — `path` segments are derived via lowercasing + hyphen→underscore substitution, not the preserved-case form the doc previously implied. Updated example, added warning against splitting `path` on `.` to recover ancestor external_keys.

Out of scope (per ticket): the omit-vs-null behavior change itself (S3 service-side fix), carving `/orgs/me` and writes out of the rate-limit bucket, and fixing path normalization to preserve case+hyphens. Those are v1.1 conversations.

Refs Linear TRA-569; parent TRA-566.

## Test plan

- [x] `pnpm typecheck && pnpm lint && pnpm build` clean (no broken links, no broken anchors)
- [x] Rendered both pages locally; copy reads coherently end-to-end
- [x] Live preview verification — `X-RateLimit-*` headers present on `/orgs/me` + a write (S1, S2)
- [x] Live preview verification — FK fields present-as-null on an unset relationship (S3)
- [x] Live preview verification — naive PUT of `data` returns 400; strip-then-PUT returns 200 (S5)
- [x] Live preview verification — newly-created location's `path` is lowercased + underscored (S11)
- [ ] Reviewer reads both pages end-to-end for tone and consistency with the rest of `docs/api/`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Paste it into the Linear ticket as a comment.

- [ ] **Step 6: Update Linear**

Move TRA-569 to `In Review`. Add a comment with the PR URL and a one-line summary of the BB14-verification gate ("All five findings landed as doc-only fixes; live preview verification ran through PR test plan; ready for reviewer pass before BB14").

This is the end of the plan. Worktree cleanup happens via the `superpowers:finishing-a-development-branch` skill after merge.

---

## Self-review notes

- **Spec coverage:** All five acceptance bullets from the ticket map to tasks (S1+S2 → Task 1; S3 → Task 2; S5 → Task 3; S11 → Task 4; live-preview verification → Task 5 step 3; PR opened → Task 5 step 5). The "if Option A chosen for S5" branch is explicitly skipped per the ticket's stated recommendation; Task 3's commit message and PR description both name Option B so the choice is documented.
- **Type/anchor consistency:** Task 1 changes the `#exclusions` anchor → `#all-endpoints-participate-in-the-bucket`; the in-task grep + same-commit-fix pattern handles cross-references. Task 3 changes `#round-trip-consistency` → `#read-shape-vs-write-shape`; same pattern. Task 2 introduces no new anchors. Task 4 introduces no new anchors. The cumulative build in Task 5 step 2 is the final safety net.
- **No placeholders:** Every step has the actual prose, the actual JSON, the actual bash, and the actual commit message. No "fill in details", no "similar to Task N" — Task 3's jq strip and Task 4's prose are written out in full even though both touch the same file as Task 2.
- **One ambiguity to resolve at execution time:** Task 3 step 3 includes a jq probe to confirm `path` and `depth` are absent from the location update schema; if the spec says otherwise, the closing sentence of Task 3's new section needs adjustment. Documented inline.
