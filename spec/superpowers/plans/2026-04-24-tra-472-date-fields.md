# TRA-472 Date Fields Convention — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a short, standalone "Date fields" page to the public API reference documenting the `valid_from` / `valid_to` convention normalized in [TRA-468](https://linear.app/trakrf/issue/TRA-468) (platform PR #198, merged 2026-04-23). Integrators get one page answering what the response looks like, what the API accepts on input, and why sentinels like `0001-01-01` / `2099-12-31` never appear. Spec: `spec/superpowers/specs/2026-04-24-tra-472-date-fields-design.md`.

**Architecture:** One new markdown page (`docs/api/date-fields.md`), one-line insertion into the `apiSidebar` list in `sidebars.ts`, two Changelog bullets in `docs/api/CHANGELOG.md` (`### Changed` for the new page, `### Fixed` for the backend wire-behavior normalization it documents). Verification via `pnpm build` (catches broken internal links + sidebar typos), `pnpm lint`, visual check via `pnpm dev`, and two live curls against `api.preview.trakrf.id` to confirm the documented shape is actually live before merge.

**Tech Stack:** Docusaurus 3.9.2 (classic preset + redocusaurus), React 19, TypeScript, pnpm. No new runtime deps. Prettier is the linter (`pnpm lint` → `prettier --check .`).

---

## Prerequisites

- On branch `miks2u/tra-472-date-fields-docs` in worktree `.worktrees/tra-472` (created off `origin/main`, spec commits `cd72e6c` and `69b2f18` on it). Confirm with `git branch --show-current && git log --oneline -3`.
- `pnpm install` has been run in `.worktrees/tra-472` (worktrees share the repo but not `node_modules` — worktree gets its own install, OR the implementer can `ln -s ../../node_modules node_modules` since `/home/mike/trakrf-docs/node_modules` already exists from the main checkout). Either works.
- Port 3000 is free for `pnpm dev`. If the user has a dev server running in the main checkout, either stop it or use `PORT=3001 pnpm dev` in the worktree.
- `curl` available, plus an API key with at least `assets:read` and `assets:write` scopes on the **preview** environment. Export as `TRAKRF_API_KEY`. The preview base URL is `https://api.preview.trakrf.id`.

## File Structure

- **Create** — `docs/api/date-fields.md` — the new standalone reference page. One file, ~100 lines, entirely self-contained. Renders at `/docs/api/date-fields`.
- **Modify** — `sidebars.ts` — one-line insertion into the `apiSidebar` → `API Documentation` → `items` array, between `"api/resource-identifiers"` and `"api/pagination-filtering-sorting"`.
- **Modify** — `docs/api/CHANGELOG.md` — append one bullet to the existing `Unreleased → Changed` section, append one bullet to the existing `Unreleased → Fixed` section.

No tests to write — this repo has no automated docs-test harness. The "test" is `pnpm build` passing (`docusaurus.config.ts:17` sets `onBrokenLinks: "throw"`, so any unresolved internal link fails the build) plus a visual check in `pnpm dev`.

---

## Task 1: Create the Date fields page and wire it into the sidebar

**Files:**

- Create: `docs/api/date-fields.md`
- Modify: `sidebars.ts` (one-line insertion into `apiSidebar → API Documentation → items`)

One commit: page + sidebar entry together, so the page is never orphaned.

- [ ] **Step 1: Confirm branch and worktree**

Run:

```bash
pwd
git branch --show-current
git log --oneline -3
```

Expected: `pwd` ends in `.worktrees/tra-472`; branch is `miks2u/tra-472-date-fields-docs`; the three most-recent commits are the two spec commits (`cd72e6c`, `69b2f18`) plus the `main` tip (`85d0810 Merge pull request #39 …`).

If any of those are wrong, stop and re-establish the worktree per the spec's "Branch / Worktree" section before continuing.

- [ ] **Step 2: Write `docs/api/date-fields.md`**

Create the file with this exact content:

````markdown
---
sidebar_position: 4
---

# Date fields

Every timestamped resource in the TrakRF v1 API uses the same two effective-date fields: `valid_from` and `valid_to`. This page describes their shape on the wire and what the API accepts on input. Audit timestamps (`created_at`, `updated_at`, `deleted_at`) follow a different convention and are not covered here.

## The two fields at a glance

| Field        | Always present?         | Type on response | Meaning                                                                    |
| ------------ | ----------------------- | ---------------- | -------------------------------------------------------------------------- |
| `valid_from` | Yes                     | RFC3339 UTC      | When the record became effective. Defaults to the creation time on insert. |
| `valid_to`   | No — omitted when unset | RFC3339 UTC      | When the record expires. **Absent key = no expiry.**                       |

The API never returns `0001-01-01T00:00:00Z` zero-time, never returns a `2099-12-31` far-future sentinel, and never returns `"valid_to": null`. If a client sees any of these, it's a bug — see the [Changelog](./CHANGELOG) entry for the normalization cleanup ([TRA-468](https://linear.app/trakrf/issue/TRA-468)).

## Outbound: always RFC3339

Every date on the response is RFC3339 in UTC — clients can parse with a single formatter without branching on shape. Two records from the same list endpoint, one with an expiry and one without:

```json
{
  "data": [
    {
      "identifier": "LOC-0001",
      "name": "Warehouse A",
      "valid_from": "2026-01-15T00:00:00Z",
      "valid_to": "2026-12-31T23:59:59Z"
    },
    {
      "identifier": "LOC-0002",
      "name": "Warehouse B",
      "valid_from": "2026-02-01T00:00:00Z"
    }
  ]
}
```

Note that the second record has **no `valid_to` key at all** — not `"valid_to": null`, not `"valid_to": ""`. Test for the key's presence, not its value.

## Inbound: accepted formats on writes

For clarity, send `valid_from` / `valid_to` as **RFC3339 in UTC**. The API also accepts a couple of other common shapes for convenience:

| Format                | Example                |
| --------------------- | ---------------------- |
| RFC3339 (recommended) | `2026-04-24T15:30:00Z` |
| ISO 8601 date-only    | `2026-04-24`           |
| US `MM/DD/YYYY`       | `04/24/2026`           |

A handful of other regional variants (`DD/MM/YYYY`, `DD.MM.YYYY`, `YYYY/MM/DD`) also parse for tolerance, but the three formats above are the ones you should rely on.

:::warning Slash dates are parsed US-first

`04/05/2026` is parsed as **April 5**, not May 4. If your sender does not always emit US-format dates, send RFC3339 (`2026-04-05T00:00:00Z`) or ISO 8601 (`2026-04-05`) to avoid silent month/day confusion.

:::

## Example

Create an asset with an explicit `valid_from` and no `valid_to`, then read it back:

```bash
# Create
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "identifier": "ASSET-0042",
       "name": "Pallet jack",
       "valid_from": "2026-04-24T00:00:00Z"
     }' \
     "$BASE_URL/api/v1/assets"

# Read
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/ASSET-0042"
```

Response:

```json
{
  "data": {
    "identifier": "ASSET-0042",
    "surrogate_id": 27545812,
    "name": "Pallet jack",
    "valid_from": "2026-04-24T00:00:00Z"
  }
}
```

The response **omits `valid_to`** because the asset has no expiry. If a later `PUT` sets `valid_to`, subsequent reads will return it as RFC3339.

## What changed

See the [Changelog](./CHANGELOG) entry for the backend cleanup ([TRA-468](https://linear.app/trakrf/issue/TRA-468)) that made this convention uniform across every resource.
````

- [ ] **Step 3: Insert the new page into `sidebars.ts`**

Open `sidebars.ts` and find the `apiSidebar` key. Within it, the single category object has an `items` array whose current contents are:

```ts
items: [
  "api/quickstart",
  "api/authentication",
  "api/resource-identifiers",
  "api/pagination-filtering-sorting",
  "api/errors",
  "api/rate-limits",
  "api/versioning",
  "api/CHANGELOG",
  "api/webhooks",
  "api/postman",
  "api/private-endpoints",
],
```

Change to:

```ts
items: [
  "api/quickstart",
  "api/authentication",
  "api/resource-identifiers",
  "api/date-fields",
  "api/pagination-filtering-sorting",
  "api/errors",
  "api/rate-limits",
  "api/versioning",
  "api/CHANGELOG",
  "api/webhooks",
  "api/postman",
  "api/private-endpoints",
],
```

(One line inserted after `"api/resource-identifiers"`.)

- [ ] **Step 4: Run typecheck, lint, and build**

Run (from `.worktrees/tra-472`):

```bash
pnpm typecheck
pnpm lint
pnpm build
```

Expected:

- `pnpm typecheck` — no errors.
- `pnpm lint` — `All matched files use Prettier code style!` (if it reports formatting drift on `docs/api/date-fields.md` or `sidebars.ts`, run `pnpm lint:fix` and re-run lint).
- `pnpm build` — ends with a line like `[SUCCESS] Generated static files in "build".` No `[ERROR]` lines, no broken-internal-link warnings that mention `date-fields` or `CHANGELOG`.

If `pnpm build` reports a broken link to `./CHANGELOG` from the new page, confirm the casing matches the file (`docs/api/CHANGELOG.md`, uppercase `CHANGELOG`).

- [ ] **Step 5: Visual check with `pnpm dev`**

Run:

```bash
pnpm dev &
DEV_PID=$!
sleep 8
```

Open a browser to `http://localhost:3000/docs/api/date-fields` and verify:

1. Page renders with the `# Date fields` heading.
2. Left sidebar shows "Date fields" as a new entry under "API Documentation", positioned between "Resource identifiers" and "Pagination, filtering, sorting".
3. The `:::warning Slash dates are parsed US-first` block renders as a yellow warning admonition — not as four raw lines of markdown.
4. Click the `[Changelog](./CHANGELOG)` link in either the opening callout or the closing "What changed" section — it resolves to `/docs/api/CHANGELOG` without a 404.
5. Browse to `/docs/api` (the API README) and confirm the sidebar order matches expectation.

Stop the dev server:

```bash
kill $DEV_PID 2>/dev/null
```

No commit yet — this step is visual inspection only. If any check fails, fix inline and re-run from Step 4.

- [ ] **Step 6: Stage and commit**

```bash
git add docs/api/date-fields.md sidebars.ts
git status
```

Expected `git status` output: two changes staged (`new file: docs/api/date-fields.md`, `modified: sidebars.ts`), nothing else.

```bash
git commit -m "$(cat <<'EOF'
docs(tra-472): add Date fields page to API reference

Documents the valid_from / valid_to convention normalized in TRA-468:
valid_from always present as RFC3339 UTC, valid_to omitted from responses
when the record has no expiry, inbound FlexibleDate parsing with the
US-first slash-date ambiguity called out explicitly.

Wired into the apiSidebar between resource-identifiers and pagination.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: one commit created on `miks2u/tra-472-date-fields-docs`.

---

## Task 2: Add changelog entries

**Files:**

- Modify: `docs/api/CHANGELOG.md` (append one bullet to `Unreleased → Changed`, append one bullet to `Unreleased → Fixed`)

Both bullets in one commit — they describe the same integrator-visible change from the docs-vs-reality perspective.

- [ ] **Step 1: Read the current Unreleased section**

Run:

```bash
head -50 docs/api/CHANGELOG.md
```

Expected: `## Unreleased` heading followed by `### Added`, `### Changed`, `### Fixed` subsections (in that order). The `### Changed` subsection already has four TRA-467 bullets. The `### Fixed` subsection already has six bullets, the last of which is about `POST /api/v1/assets` and `POST /api/v1/locations` defaulting `valid_from` to the current time (TRA-447 — related but distinct; our new bullet covers the backfill + response-shape normalization done in TRA-468).

- [ ] **Step 2: Append the `### Changed` bullet**

Find the existing `### Changed` subsection under `## Unreleased`. After the existing fourth bullet (the one ending `…clients should match on type ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F7).`), append one new bullet — keep the list format identical (single-line bullet, trailing Linear link in parentheses, period at end):

```markdown
- Added **[Date fields](./date-fields)** — a new API-reference page documenting the `valid_from` / `valid_to` convention: `valid_from` always present as RFC3339, `valid_to` omitted when unset, inbound `FlexibleDate` parsing with US-first slash-date ambiguity warning ([TRA-472](https://linear.app/trakrf/issue/TRA-472)).
```

- [ ] **Step 3: Append the `### Fixed` bullet**

Find the existing `### Fixed` subsection under `## Unreleased`. After the last existing bullet (the `valid_from` default one), append:

```markdown
- `valid_from` and `valid_to` now follow a single convention across every resource: `valid_from` is always present as RFC3339 UTC, `valid_to` is omitted from responses when the record has no expiry. Zero-time (`0001-01-01T00:00:00Z`) and far-future sentinels (`2099-12-31T...`) no longer appear on the wire, and no response returns `"valid_to": null`. Existing rows were backfilled by a one-way migration ([TRA-468](https://linear.app/trakrf/issue/TRA-468)).
```

- [ ] **Step 4: Lint and build**

```bash
pnpm lint
pnpm build
```

Expected:

- `pnpm lint` clean (if drift, `pnpm lint:fix` then re-run).
- `pnpm build` succeeds. Watch especially for an "unresolved link" warning on `./date-fields` — if present, Docusaurus can't find the file, which would mean Step 2 in Task 1 was wrong or never committed.

- [ ] **Step 5: Visual check of the Changelog page**

```bash
pnpm dev &
DEV_PID=$!
sleep 8
```

Open `http://localhost:3000/docs/api/CHANGELOG` and confirm:

1. `Unreleased → Changed` now shows five bullets total (four TRA-467 + one TRA-472).
2. `Unreleased → Fixed` now shows seven bullets, the last of which is the TRA-468 one.
3. The `[Date fields](./date-fields)` link in the Changed bullet resolves to the new page.
4. Both `[TRA-472]` and `[TRA-468]` anchor links go to their Linear URLs.

Stop the dev server:

```bash
kill $DEV_PID 2>/dev/null
```

- [ ] **Step 6: Stage and commit**

```bash
git add docs/api/CHANGELOG.md
git diff --cached --stat
```

Expected: `docs/api/CHANGELOG.md` shows 2 insertions (one per bullet; no deletions, no unrelated whitespace churn).

```bash
git commit -m "$(cat <<'EOF'
docs(tra-472): changelog entries for date fields page

Two Unreleased bullets: a Changed entry pointing to the new Date fields
page (TRA-472) and a Fixed entry for the TRA-468 backend normalization
that made the valid_from / valid_to convention uniform on the wire.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Preview-deploy reality check

**Files:** none modified. This is the second blocking gate from the ticket: confirm the documented convention is actually live on preview before the PR merges.

No commit. If any check fails, the PR holds — report which assertion failed, rope in the user, and do not proceed to Task 4.

- [ ] **Step 1: Confirm the API key is set**

```bash
test -n "$TRAKRF_API_KEY" && echo "key present" || echo "SET TRAKRF_API_KEY FIRST"
```

Expected: `key present`. If not, mint a preview-environment key (see `docs/api/authentication.md`) before continuing.

- [ ] **Step 2: List locations and grep for forbidden values**

```bash
curl -s -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "https://api.preview.trakrf.id/api/v1/locations?limit=100" \
  | tee /tmp/tra-472-locations.json \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('count=', len(d.get('data',[])))"
```

Expected: non-zero count. Then:

```bash
grep -c "0001-01-01" /tmp/tra-472-locations.json
grep -c "2099-12-31" /tmp/tra-472-locations.json
grep -c '"valid_to": *null' /tmp/tra-472-locations.json
```

Expected: all three greps return `0`.

If any return >0, the backend has not fully converged to the documented convention. Stop. Surface the finding to the user along with sample offending records so they can decide whether it's a TRA-468 regression (re-open + fix) or a secondary data issue (likely blocked by TRA-473, which is listed as related on TRA-472).

- [ ] **Step 3: Confirm at least one record in the response omits `valid_to`**

```bash
python3 -c "
import json
data = json.load(open('/tmp/tra-472-locations.json'))['data']
without = [r for r in data if 'valid_to' not in r]
with_exp = [r for r in data if 'valid_to' in r]
print(f'without valid_to: {len(without)}; with valid_to: {len(with_exp)}')
if without:
    print('sample without:', without[0].get('identifier'))
"
```

Expected: `without valid_to` is at least 1. The documented contract is "absent key, not null" — if every record carries `valid_to`, the test is inconclusive (maybe every preview record happens to have an expiry), so pull a second resource (e.g., assets) and re-check until at least one absent-key case is observed.

- [ ] **Step 4: Round-trip an asset with no `valid_to`**

```bash
IDENT="TRA-472-PREVIEW-$(date +%s)"
curl -s -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d "{\"identifier\":\"$IDENT\",\"name\":\"TRA-472 preview smoke\",\"valid_from\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
     "https://api.preview.trakrf.id/api/v1/assets" \
  | tee /tmp/tra-472-create.json
curl -s -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "https://api.preview.trakrf.id/api/v1/assets/$IDENT" \
  | tee /tmp/tra-472-get.json
```

Expected: create response has 2xx-ish shape (`{"data":{...}}`), no `valid_to` key in the response data. Then:

```bash
python3 -c "
import json
g = json.load(open('/tmp/tra-472-get.json'))['data']
print('valid_from present:', 'valid_from' in g)
print('valid_to present:', 'valid_to' in g)
print('valid_to value if present:', g.get('valid_to', '(absent)'))
"
```

Expected: `valid_from present: True`; `valid_to present: False`; last line prints `(absent)`.

If `valid_to` is present in the GET response (as `null`, empty string, or any value) when the create payload did not set it, the contract is broken. Stop and surface.

- [ ] **Step 5: Clean up the smoke-test record**

```bash
curl -s -X DELETE -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "https://api.preview.trakrf.id/api/v1/assets/$IDENT"
```

No specific expectation — we just want the asset gone so the preview data stays tidy. Note that this leaves `/tmp/tra-472-*.json` files around for the user's audit; they can be deleted at leisure.

- [ ] **Step 6: Record verification result**

No commit, but keep the `/tmp/tra-472-*.json` files until the PR is merged in case the reviewer wants to inspect them.

Confirm to the user: "Preview-deploy verification passed: no sentinels, at least one `valid_to`-absent record observed, round-trip confirms `valid_to` is omitted when unsent. Safe to push and open the PR."

---

## Task 4: Push branch and open the PR

**Files:** none modified locally. Opens the PR on GitHub.

- [ ] **Step 1: Confirm clean working tree and final commit log**

```bash
git status
git log --oneline main..HEAD
```

Expected:

- `git status`: `nothing to commit, working tree clean`.
- `git log main..HEAD`: exactly four commits ahead of `main`:
  1. `docs(tra-472): design spec for valid_from/valid_to convention page`
  2. `docs(tra-472): put docs-page bullet in Changed per TRA-467 precedent`
  3. `docs(tra-472): add Date fields page to API reference`
  4. `docs(tra-472): changelog entries for date fields page`

- [ ] **Step 2: Push the branch**

```bash
git push -u origin miks2u/tra-472-date-fields-docs
```

Expected: successful push; the branch is created on GitHub tracking `origin/miks2u/tra-472-date-fields-docs`.

- [ ] **Step 3: Open the PR via `gh`**

```bash
gh pr create \
  --title "docs(tra-472): document valid_from / valid_to convention" \
  --body "$(cat <<'EOF'
## Summary

- Adds `docs/api/date-fields.md` — a standalone reference page documenting the `valid_from` / `valid_to` convention normalized by [TRA-468](https://linear.app/trakrf/issue/TRA-468) (platform PR #198). Covers response shape (absent `valid_to` key = no expiry, never a sentinel), accepted inbound formats (RFC3339 recommended; ISO and US slash also work), and the US-first slash-date ambiguity gotcha.
- Wires the page into the API sidebar between Resource identifiers and Pagination.
- Adds two Unreleased Changelog bullets: a `Changed` entry for the new page and a `Fixed` entry for the backend wire-behavior change integrators will see.

Closes [TRA-472](https://linear.app/trakrf/issue/TRA-472).

## Verification

- `pnpm typecheck`, `pnpm lint`, `pnpm build` all clean.
- Visual check in `pnpm dev`: new page renders, admonition renders as a warning callout, sidebar slot is correct, internal links resolve.
- **Preview-deploy reality check performed** (the ticket's blocking gate 2): `GET /api/v1/locations` on `api.preview.trakrf.id` contains no `0001-01-01` / `2099-12-31` / `"valid_to": null`, and at least one node confirmed the "absent key" shape. `POST /api/v1/assets` round-trip confirmed `valid_to` is omitted when not sent on create. Smoke-test record cleaned up.

## Out of scope / follow-ups

- `static/api/openapi.yaml` still carries date-only example values (`"2025-01-01"`) for `valid_from` / `valid_to`, contradicting the new "outbound always RFC3339" rule. The spec is generated from platform `openapi.public.yaml` and synced via `scripts/refresh-openapi.sh`. **Suggested follow-up ticket (platform side):** update example values to RFC3339 and add `description` fields on `valid_from` / `valid_to` schema entries.
- `created_at` / `updated_at` / `deleted_at` audit timestamps — different convention, deliberately out of scope per TRA-468 and restated in this PR's design spec.
- `valid_from < valid_to` validation — out of scope per TRA-468.

## Test plan

- [x] `pnpm typecheck` clean
- [x] `pnpm lint` clean
- [x] `pnpm build` clean (no broken-link warnings)
- [x] Visual check in `pnpm dev`
- [x] Preview-deploy curls pass

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed to stdout.

- [ ] **Step 4: Report the PR URL to the user**

Paste the `gh pr create` output URL back to the user for review. Do **not** self-merge — per the project rule, merges require explicit confirmation and never a squash.

---

## Verification Checklist (cross-cuts all tasks)

Before declaring the plan complete:

- [ ] `pnpm typecheck` passes
- [ ] `pnpm lint` passes
- [ ] `pnpm build` passes with no `[ERROR]` lines and no broken-internal-link warnings
- [ ] New page renders correctly in `pnpm dev` with admonition formatting
- [ ] Sidebar shows "Date fields" in the correct slot
- [ ] All internal links (`./CHANGELOG`, TRA-472, TRA-468) resolve
- [ ] Preview-deploy curls confirm `valid_to` absent when unset and no sentinels on the wire
- [ ] PR opened against `main` with a body that calls out the preview-deploy verification
- [ ] Platform-side follow-up (OpenAPI example fixes) mentioned in PR description
