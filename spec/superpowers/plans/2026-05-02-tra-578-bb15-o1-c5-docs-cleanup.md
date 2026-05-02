# TRA-578 BB15 O-1 + C-5 docs cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `trakrf-docs` into alignment with platform PR #262 — drop the programmatic-mint surface from the public Authentication doc, rename `scans:read` → `history:read` in user-facing docs, list the four `/api-keys*` ops as Internal in `private-endpoints.md`, and refresh the OpenAPI artifacts.

**Architecture:** Pure docs PR. Six files touched: `docs/api/authentication.md` (large delete + renames), `docs/api/private-endpoints.md` (table additions), `docs/api/resource-identifiers.md` (small delete), `docs/getting-started/api.mdx` (rename), `docs/api/quickstart.mdx` (rename), `static/api/*` (already refreshed on the branch). No code, no tests beyond `pnpm build`'s broken-link / Redocly checks.

**Tech Stack:** Docusaurus, Redocly OpenAPI bundler, pnpm.

**Spec:** `spec/superpowers/specs/2026-05-02-tra-578-bb15-o1-c5-docs-cleanup-design.md`

---

## File Structure

| File | Change | Notes |
| ---- | ------ | ----- |
| `docs/api/authentication.md` | Modify | Rename scope, drop UI carve-out, drop two H2/H3 sections, drop `keys:admin` row + bullet |
| `docs/api/private-endpoints.md` | Modify | Add three rows to the Endpoint list table |
| `docs/api/resource-identifiers.md` | Modify | Drop trailing "Authentication keys are different" section (lines 209–211) |
| `docs/getting-started/api.mdx` | Modify | Replace `scans:read` literals (×4) with `history:read` |
| `docs/api/quickstart.mdx` | Modify | Replace `scans:read` literal (×1) with `history:read` |
| `static/api/openapi.json` | Already modified | On branch, contains `platform@b0db561` |
| `static/api/openapi.yaml` | Already modified | Same |
| `static/api/platform-meta.json` | Already modified | `b0db561` |
| `static/api/trakrf-api.postman_collection.json` | Already modified | Regenerated |

The `static/api/*` files are already on the working tree from the spec refresh and need to be staged with the prose changes. Treat them as one commit (the rename) since the rename + the spec are the same fact.

---

## Task 1: Rename `scans:read` → `history:read` in `getting-started/api.mdx`

**Files:**
- Modify: `docs/getting-started/api.mdx` (lines 39, 51, 79, 89)

- [ ] **Step 1: Edit line 39 — UI selector parenthetical**

Change in `docs/getting-started/api.mdx`:

```
4. Click **New key**. Give it a descriptive name (e.g. "local dev"), choose scopes (`scans:read` alone is enough for this quickstart — the `/locations/current` endpoint is gated by `scans:read`; grant `assets:read` and `locations:read` if you plan to hit the other read endpoints), and submit.
```

to:

```
4. Click **New key**. Give it a descriptive name (e.g. "local dev"), choose scopes (`history:read` alone is enough for this quickstart — the `/locations/current` endpoint is gated by `history:read`; grant `assets:read` and `locations:read` if you plan to hit the other read endpoints), and submit.
```

- [ ] **Step 2: Edit line 51 — first-call prose**

Change:

```
The `/api/v1/locations/current` endpoint returns a snapshot of where TrakRF last saw each asset. It's cheap, requires `scans:read`, and gives you a live signal that your key works:
```

to:

```
The `/api/v1/locations/current` endpoint returns a snapshot of where TrakRF last saw each asset. It's cheap, requires `history:read`, and gives you a live signal that your key works:
```

- [ ] **Step 3: Edit line 79 — error-prose**

Change:

```
If you get a `401`, the key is malformed or not being sent in the header. If you get a `403`, the body names the missing scope — for this endpoint it'll be `"Missing required scope: scans:read"`. If you get a `429`, you're being rate-limited — see [Rate limits](../api/rate-limits). If you're calling from browser JavaScript and getting a CORS error with no body, the API is server-to-server only ([details](../api/authentication#server-to-server)).
```

to:

```
If you get a `401`, the key is malformed or not being sent in the header. If you get a `403`, the body names the missing scope — for this endpoint it'll be `"Missing required scope: history:read"`. If you get a `429`, you're being rate-limited — see [Rate limits](../api/rate-limits). If you're calling from browser JavaScript and getting a CORS error with no body, the API is server-to-server only ([details](../api/authentication#server-to-server)).
```

- [ ] **Step 4: Edit line 89 — JSON example**

Change:

```
    "detail": "Missing required scope: scans:read",
```

to:

```
    "detail": "Missing required scope: history:read",
```

- [ ] **Step 5: Verify zero remaining `scans:read` literals in the file**

Run:

```bash
grep -n 'scans:read' docs/getting-started/api.mdx
```

Expected: no output (exit 1).

- [ ] **Step 6: Commit**

```bash
git add docs/getting-started/api.mdx
git commit -m "docs(getting-started): rename scans:read → history:read (TRA-578 C-5)"
```

---

## Task 2: Rename `scans:read` → `history:read` in `quickstart.mdx`

**Files:**
- Modify: `docs/api/quickstart.mdx` (line 35)

- [ ] **Step 1: Edit line 35**

Change in `docs/api/quickstart.mdx`:

```
4. Click **New key**. Give it a descriptive name (e.g. `"local-dev"`). The first verification call below (`GET /api/v1/orgs/me`) works with any valid key — no specific scope required. For the round-trip walkthrough in step 4 you'll need `assets:read` and `assets:write`; for the other read endpoints, `locations:read` and `scans:read`. See [Authentication → Scopes](./authentication#scopes) for the full matrix.
```

to:

```
4. Click **New key**. Give it a descriptive name (e.g. `"local-dev"`). The first verification call below (`GET /api/v1/orgs/me`) works with any valid key — no specific scope required. For the round-trip walkthrough in step 4 you'll need `assets:read` and `assets:write`; for the other read endpoints, `locations:read` and `history:read`. See [Authentication → Scopes](./authentication#scopes) for the full matrix.
```

- [ ] **Step 2: Verify zero remaining `scans:read` literals in the file**

Run:

```bash
grep -n 'scans:read' docs/api/quickstart.mdx
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add docs/api/quickstart.mdx
git commit -m "docs(quickstart): rename scans:read → history:read (TRA-578 C-5)"
```

---

## Task 3: Update Authentication scopes tables and pairings (rename + drop `keys:admin`)

**Files:**
- Modify: `docs/api/authentication.md` (lines 44, 52, 62–63, 69)

- [ ] **Step 1: Strip the `keys:admin` carve-out from the UI labels intro (line 44)**

Change:

```
The **New key** form in the web app lets you pick a resource (Assets / Locations / Scans) and an access level (None / Read / Read+Write). Each combination maps to one or two of the scope strings used throughout these docs and in API responses. `keys:admin` is not exposed in the form — admin-tier keys are minted via API, see [Programmatic key rotation](#programmatic-key-rotation).
```

to:

```
The **New key** form in the web app lets you pick a resource (Assets / Locations / History) and an access level (None / Read / Read+Write). Each combination maps to one or two of the scope strings used throughout these docs and in API responses.
```

(The resource-list rename `Scans → History` mirrors the UI label change platform PR #262 made in `ScopeSelector.tsx`. The `keys:admin` carve-out + forward link are deleted; nothing replaces them.)

- [ ] **Step 2: Rename UI labels table row (line 52)**

Change:

```
| Scans → Read               | `scans:read`                        |
```

to:

```
| History → Read             | `history:read`                      |
```

- [ ] **Step 3: Rename scopes table row + drop `keys:admin` row (lines 62–63)**

Change the two table rows:

```
| `scans:read`      | Read   | `GET /locations/current`, `GET /assets/{id}/history`, scan-event endpoints                                                   |
| `keys:admin`      | Admin  | `POST /orgs/{id}/api-keys`, `GET /orgs/{id}/api-keys`, `DELETE /orgs/{id}/api-keys/{key_id}`, `.../api-keys/by-jti/{jti}`    |
```

to (one row, `keys:admin` row deleted):

```
| `history:read`    | Read   | `GET /locations/current`, `GET /assets/{id}/history`                                                                         |
```

(Drops the "scan-event endpoints" tail — there are no scan-event endpoints on the public surface, which was the whole reason for the C-5 rename.)

- [ ] **Step 4: Rewrite non-obvious-pairings bullets (lines 67–69) — rename × drop**

Change:

```
- **`/locations/current`** is gated by **`scans:read`**, not `locations:read`. The snapshot is derived from scan events, so it lives under the scans scope.
- **`/assets/{id}/history`** is gated by **`scans:read`** for the same reason — it's a projection of scan events, not a property of the asset.
- **`keys:admin`** is the only "admin" scope in v1 — it gates key creation, listing, and revocation on the caller's own org. A `keys:admin` key may mint another key with `keys:admin`, enabling unattended self-rotation. See [Programmatic key rotation](#programmatic-key-rotation).
```

to (two bullets, `keys:admin` bullet deleted, scope rename applied):

```
- **`/locations/current`** is gated by **`history:read`**, not `locations:read`. The snapshot is derived from scan events, so it lives under the history scope.
- **`/assets/{id}/history`** is gated by **`history:read`** for the same reason — it's a projection of scan events, not a property of the asset.
```

- [ ] **Step 5: Verify zero remaining `scans:read` or `keys:admin` literals**

Run:

```bash
grep -n 'scans:read\|keys:admin' docs/api/authentication.md
```

Expected: no output. (If anything remains, it's a leftover in `Identifying a key` or `Programmatic key rotation` — those are deleted in Task 4, so a non-empty grep here is fine to defer until after Task 4 completes; in that case verify after Task 4 instead.)

- [ ] **Step 6: Commit**

```bash
git add docs/api/authentication.md
git commit -m "docs(auth): rename scans:read → history:read; drop keys:admin row (TRA-578)"
```

---

## Task 4: Delete `Identifying a key` and `Programmatic key rotation` sections

**Files:**
- Modify: `docs/api/authentication.md` (lines 116–172)

- [ ] **Step 1: Delete the two sections in one edit**

Use the Edit tool to replace lines 116 through the closing of the `## Programmatic key rotation` H2 (the line before `## Base URL`) with nothing. Concretely, the `old_string` is the block that begins:

```
### Identifying a key {#identifying-a-key}

Every API key has two identifiers:
```

…and ends at:

```
The shapes of the response envelopes are shown in the [API reference](/api).

```

Replace with empty string. The `## Key lifecycle` section above (ending at line 114, the **Expiration** bullet) and the `## Base URL` section below (starting at the next line, currently line 174) become adjacent — confirm one blank line separates them.

- [ ] **Step 2: Verify the file ends `## Key lifecycle` with `## Base URL` next**

Run:

```bash
grep -n '^##' docs/api/authentication.md
```

Expected output (the `^##` H2 list):

```
## Mint your first API key {#mint-your-first-api-key}
## Request header
## Scopes
## Example requests
## Key lifecycle
## Base URL
## Server-to-server design {#server-to-server}
## Environment variables
## Testing connectivity
```

No `## Programmatic key rotation`. (The `## Scopes` section retains its `### UI labels` H3 — `grep '^##'` filters those out.)

- [ ] **Step 3: Verify deleted anchors no longer appear and have no remaining refs**

Run:

```bash
grep -rn '#programmatic-key-rotation\|#identifying-a-key' docs/ | grep -v node_modules
```

Expected: no output.

- [ ] **Step 4: Verify zero `scans:read` and zero `keys:admin` literals across the file**

Run:

```bash
grep -n 'scans:read\|keys:admin' docs/api/authentication.md
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add docs/api/authentication.md
git commit -m "docs(auth): drop programmatic key rotation + identifying-a-key sections (TRA-578 O-1)"
```

---

## Task 5: Add four api-keys rows to `private-endpoints.md` Endpoint list

**Files:**
- Modify: `docs/api/private-endpoints.md` (Endpoint list table around line 31)

- [ ] **Step 1: Insert three rows after `/api/v1/orgs/{id}` row**

In `docs/api/private-endpoints.md`, locate the row:

```
| `/api/v1/orgs/{id}`            | GET       | SPA org detail        | Internal                    | Internal       |
```

Insert these three rows immediately after it (and before `/api/v1/orgs/me`):

```
| `/api/v1/orgs/{id}/api-keys`                  | POST, GET | SPA avatar menu → API Keys | Internal                    | Internal       |
| `/api/v1/orgs/{id}/api-keys/{key_id}`         | DELETE    | SPA avatar menu → API Keys | Internal                    | Internal       |
| `/api/v1/orgs/{id}/api-keys/by-jti/{jti}`     | DELETE    | SPA avatar menu → API Keys | Internal                    | Internal       |
```

The wider Endpoint column will widen the table — that's expected and matches Markdown table behavior. Docusaurus / GitHub renders the column to the widest cell.

- [ ] **Step 2: Verify the rows render in the table**

Run:

```bash
grep -n 'api-keys' docs/api/private-endpoints.md
```

Expected: three lines, all in the Endpoint list table.

- [ ] **Step 3: Commit**

```bash
git add docs/api/private-endpoints.md
git commit -m "docs(private-endpoints): list /orgs/{id}/api-keys ops as Internal (TRA-578 O-1)"
```

---

## Task 6: Drop "Authentication keys are different" section from `resource-identifiers.md`

**Files:**
- Modify: `docs/api/resource-identifiers.md` (lines 207–211, the trailing H2)

- [ ] **Step 1: Delete the section**

Locate this block at the end of the file:

```
There's no top-level `/api/v1/tags/lookup` endpoint — tags are discovered through their parent resource, either embedded in an asset or location response or via `GET /api/v1/assets/{id}/tags`.

## Authentication keys are different

API keys (`/api/v1/orgs/{id}/api-keys`) follow a different identifier model from assets, locations, and tags — separate canonical `id` and JTI vocabulary, separate revocation paths. See [Authentication](./authentication) for the key lifecycle and the `/by-jti/{jti}` revocation route.
```

Replace with:

```
There's no top-level `/api/v1/tags/lookup` endpoint — tags are discovered through their parent resource, either embedded in an asset or location response or via `GET /api/v1/assets/{id}/tags`.
```

(The `## Tags use a composite natural key` section becomes the last section of the file. That's the clean stop noted in the spec.)

- [ ] **Step 2: Verify api-keys reference is gone from this file**

Run:

```bash
grep -n 'api-keys\|by-jti' docs/api/resource-identifiers.md
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(resource-identifiers): drop trailing api-keys section (TRA-578 O-1)"
```

---

## Task 7: Stage and commit the OpenAPI spec refresh

**Files:**
- Stage (already modified): `static/api/openapi.json`, `static/api/openapi.yaml`, `static/api/platform-meta.json`, `static/api/trakrf-api.postman_collection.json`

- [ ] **Step 1: Confirm spec state on the branch**

Run:

```bash
jq -r '.commit' static/api/platform-meta.json
jq -r '.paths | keys[] | select(test("api-keys"))' static/api/openapi.json | wc -l
grep -oE '"(scans:read|history:read)"' static/api/openapi.json | sort -u
```

Expected:
```
b0db561
0
"history:read"
```

- [ ] **Step 2: Commit the refresh**

```bash
git add static/api/openapi.json static/api/openapi.yaml static/api/platform-meta.json static/api/trakrf-api.postman_collection.json
git commit -m "$(cat <<'EOF'
chore(spec): refresh openapi from platform@b0db561 (TRA-578)

Picks up trakrf/platform#262 — drops /api/v1/orgs/{id}/api-keys* paths
from the public spec and renames the scans:read scope literal to
history:read on the two scan-derived routes.

Spec deltas: openapi.json -537 lines, openapi.yaml -345 lines, postman
collection regenerated.
EOF
)"
```

---

## Task 8: Validate the build

- [ ] **Step 1: Run `pnpm build`**

```bash
pnpm build
```

Expected: clean exit. Watch for:

- Broken-link errors mentioning `#programmatic-key-rotation` or `#identifying-a-key` (would mean Task 4 missed an external ref — re-run the grep in Task 4 Step 3 to find it).
- Redocly bundling errors against `static/api/openapi.json` (would mean the spec refresh produced an invalid file — investigate before merging).
- TypeScript errors (the docs site has typed config but no doc edits in this PR touch TS).

- [ ] **Step 2: If any errors surface, fix them and re-run `pnpm build` until clean**

No new commits expected — fixes here are bug-fixes for an oversight in earlier tasks. Amend or new-commit per the issue.

- [ ] **Step 3: Final cross-file scope-literal sweep**

Run:

```bash
grep -rn 'scans:read' docs/ | grep -v node_modules
```

Expected: no output.

- [ ] **Step 4: Final anchor sweep**

```bash
grep -rn '#programmatic-key-rotation\|#identifying-a-key' docs/ static/ | grep -v node_modules
```

Expected: no output.

---

## Task 9: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/tra-578-bb15-o1-c5-docs-cleanup
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --title "docs: TRA-578 BB15 O-1 + C-5 docs cleanup (drop programmatic mint, scans:read → history:read)" --body "$(cat <<'EOF'
## Summary

Docs follow-up for [trakrf/platform#262](https://github.com/trakrf/platform/pull/262) (TRA-578). The platform PR flipped all four `/api/v1/orgs/{id}/api-keys*` ops to internal and renamed scope `scans:read` → `history:read` end-to-end. This PR brings the docs in line.

- **Authentication doc** — drops the `## Programmatic key rotation` H2 (and its three sub-sections), drops the `### Identifying a key` H3, drops the `keys:admin` row + bullet (only gated internal endpoints), renames the `Scans → Read | scans:read` row to `History → Read | history:read`, and renames the two non-obvious-pairings bullets.
- **`private-endpoints.md`** — adds the three `/orgs/{id}/api-keys*` ops to the Endpoint list as Internal, used by the SPA avatar menu.
- **`resource-identifiers.md`** — drops the trailing "Authentication keys are different" section (its only purpose was pointing at the now-internal `/by-jti/{jti}` route).
- **Quickstart + getting-started/api** — replaces every `scans:read` literal (5 occurrences across 2 files) with `history:read`, including the `Missing required scope:` error-body example.
- **`static/api/*`** — refreshed from `trakrf/platform@b0db561`. `openapi.json` -537 lines, `openapi.yaml` -345 lines (api-keys paths + `keys:admin` scope literal pruned). Postman collection regenerated.

## Scope decision

Cascaded the deletions beyond the platform PR's enumerated scope (which only said "remove Programmatic key rotation + Required scopes sections, rename scans:read"). The cascade catches:

- `keys:admin` row in the scopes table — gated only internal endpoints once O-1 landed.
- `### Identifying a key` section — discusses the `id` vs. `jti` revocation routes that are no longer reachable from the public surface.
- `resource-identifiers.md` "Authentication keys are different" paragraph — references the now-internal `/by-jti/{jti}` route.

Surgical-only would have left the doc internally contradictory ("there is no programmatic mint" + a `keys:admin` admin scope row + a section explaining how to identify keys for revocation). Brainstormed with @miks2u; chose cascade.

Spec: `spec/superpowers/specs/2026-05-02-tra-578-bb15-o1-c5-docs-cleanup-design.md`
Plan: `spec/superpowers/plans/2026-05-02-tra-578-bb15-o1-c5-docs-cleanup.md`

## Test plan

- [x] `pnpm build` — clean (typecheck, broken-link check, Redocly bundle)
- [x] `grep -rn 'scans:read' docs/` returns nothing
- [x] `grep -rn '#programmatic-key-rotation\|#identifying-a-key' docs/ static/` returns nothing
- [x] `static/api/platform-meta.json` carries `b0db561`
- [x] `jq '.paths | keys[]' static/api/openapi.json` no longer lists any `/api-keys*` path
- [ ] Visual spot-check of the rendered Authentication page (no orphan refs, sections flow `Scopes → Examples → Key lifecycle → Base URL`)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Print the PR URL for the reviewer**

The `gh pr create` output is the URL. Post it back to the user.

---

## Self-Review Checklist

**Spec coverage:**

| Spec acceptance criterion | Task |
| ------------------------- | ---- |
| Auth scopes table has `history:read`, no `scans:read`, no `keys:admin` row | 3, 4 |
| No `### Identifying a key` section | 4 |
| No `## Programmatic key rotation` H2 | 4 |
| UI labels table shows `History → Read \| history:read` | 3 |
| `private-endpoints.md` has three api-keys rows, all Internal | 5 |
| `resource-identifiers.md` has no `## Authentication keys are different` | 6 |
| `getting-started/api.mdx` and `quickstart.mdx` have zero `scans:read` | 1, 2 |
| No `#programmatic-key-rotation` or `#identifying-a-key` anchor refs | 4 (verify), 8 (cross-corpus sweep) |
| `static/api/platform-meta.json` carries `b0db561` | 7 |
| `pnpm build` passes | 8 |
| PR opens against `main` | 9 |

All criteria mapped.

**Placeholder scan:** No "TBD" / "TODO" / "implement later" steps. All edits show full `old_string` / `new_string` text.

**Type consistency:** N/A (no code).

**Cross-task naming:** "history:read" used consistently. Branch name `feat/tra-578-bb15-o1-c5-docs-cleanup` used consistently.
