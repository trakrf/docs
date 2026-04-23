# TRA-466 Docs: Promote API-Key Management to Public — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `POST/GET/DELETE /api/v1/orgs/{id}/api-keys` read as first-class public endpoints in the docs (Scopes table + new Programmatic key rotation section + updated private-endpoints classification + changelog + refreshed OpenAPI artifacts), matching what `trakrf/platform#197` ships. Spec: `spec/superpowers/specs/2026-04-23-tra-466-docs-api-key-public-promotion-design.md`.

**Architecture:** All edits live in `docs/api/*.md`. The OpenAPI JSON/YAML under `static/api/` is refreshed via `scripts/refresh-openapi.sh` (fetches from preview); not hand-edited. Verification is `pnpm typecheck` + `pnpm build` (`onBrokenLinks: "throw"` catches anchor/link drift) + visual inspection via `pnpm serve` of the three affected pages (`/docs/api/authentication`, `/docs/api/private-endpoints`, `/docs/api/changelog`) and the `/api` Redoc page for the refreshed endpoints.

**Tech Stack:** Docusaurus 3.x (classic preset + redocusaurus), TypeScript config, pnpm. Markdown only — no code changes.

---

## Prerequisites

- On branch `miks2u/tra-466-docs-promote-api-key-management` in worktree `.worktrees/tra-466-docs` (already created off `main`, with spec commit `cfe36c4` on it). Confirm with `git branch --show-current && git log -1 --oneline`.
- `pnpm install` has been run and `node_modules/` is populated in the worktree.
- `trakrf/platform#197` will merge during this work; `scripts/refresh-openapi.sh` depends on `https://app.preview.trakrf.id/api/v1/openapi.{json,yaml}` containing the new endpoints. Task 7 is gated on that.

### Task 0: Baseline green

**Files:** none modified.

- [ ] **Step 1: Confirm branch + head**

Run: `git branch --show-current && git log -1 --oneline`
Expected:
```
miks2u/tra-466-docs-promote-api-key-management
cfe36c4 docs(tra-466): design spec for promoting api-key management to public
```

- [ ] **Step 2: Verify typecheck passes on clean tree**

Run: `pnpm typecheck`
Expected: 0 errors. No output from `tsc` on success.

- [ ] **Step 3: Verify build passes on clean tree**

Run: `pnpm build`
Expected: build completes; no "Broken link" errors; produces `build/` directory. This establishes that any build failure later is caused by our edits, not pre-existing breakage.

- [ ] **No commit** — baseline only.

---

### Task 1: Add `keys:admin` to the Scopes table in `docs/api/authentication.md`

**Files:**
- Modify: `docs/api/authentication.md`

- [ ] **Step 1: Insert the new row at the bottom of the Scopes table**

Find the table rows (currently lines 39–46) and append a new row after `scans:write`. The edit target is:

```markdown
| `scans:write`     | Write  | `POST /inventory/save`                                                             |
```

Replace with:

```markdown
| `scans:write`     | Write  | `POST /inventory/save`                                                             |
| `keys:admin`      | Admin  | `POST /orgs/{id}/api-keys`, `GET /orgs/{id}/api-keys`, `DELETE /orgs/{id}/api-keys/{keyId}` |
```

- [ ] **Step 2: Extend the "non-obvious pairings" bullet list**

The existing list (currently lines 48–52) has three bullets ending with `/inventory/save`. Append one more bullet after the `scans:write` bullet:

```markdown
- **`keys:admin`** is the only "admin" scope in v1 — it gates key creation, listing, and revocation on the caller's own org. A `keys:admin` key may mint another key with `keys:admin`, enabling unattended self-rotation. See [Programmatic key rotation](#programmatic-key-rotation).
```

- [ ] **Step 3: Verify build still passes (broken-link check)**

Run: `pnpm build`
Expected: build completes with no broken-link errors. The new `#programmatic-key-rotation` anchor doesn't exist yet but Docusaurus only resolves hash-anchors on the current page lazily at runtime; the `onBrokenLinks` config checks inter-page links and the existence of target pages, not every in-page anchor. If the build *does* fail on the anchor, skip to Task 2 first, then come back to this build check — the anchor will exist after Task 2's edit lands.

- [ ] **Step 4: Commit**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-466): add keys:admin to scopes table

Lists keys:admin on the three api-keys endpoints and adds a
non-obvious-pairings bullet pointing at the new Programmatic key
rotation section (added in the next commit). The anchor is not yet
present on disk — the next commit lands it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add the `## Programmatic key rotation` section to `authentication.md`

**Files:**
- Modify: `docs/api/authentication.md`

- [ ] **Step 1: Insert the new section between `## Key lifecycle` and `## Base URL`**

Find the line `## Base URL` (currently line 99) and insert the new section immediately above it, after the last `## Key lifecycle` bullet (currently line 97). The edit anchor is the line:

```markdown
## Base URL
```

Prepend (before that line):

````markdown
## Programmatic key rotation {#programmatic-key-rotation}

Production integrations (iPaaS connectors, CI/CD, Terraform/Pulumi) should rotate their API keys on a schedule rather than relying on administrator web-UI action. TrakRF supports unattended rotation via the `keys:admin` scope.

The workflow is **create-new → cut-over → revoke-old**, which keeps the integration valid throughout:

1. **List existing keys** — `GET /api/v1/orgs/{id}/api-keys` returns the key metadata (name, scopes, created / last-used, expiration). The JWT itself is never included.
2. **Mint a replacement** — `POST /api/v1/orgs/{id}/api-keys` with `{"name": "<integration>-rotated-<YYYY-MM-DD>", "scopes": [...], "expires_at": "<future>"}`. The response body carries the full JWT **once**; persist it to your secrets store immediately.
3. **Cut over** — deploy the new JWT to the integration. Both keys are valid during the overlap.
4. **Revoke the old key** — `DELETE /api/v1/orgs/{id}/api-keys/{keyId}`. Any subsequent request with the old JWT returns `401 unauthorized`.

### Self-rotation

A key with `keys:admin` can mint another key with `keys:admin`. That means an integration holding a `keys:admin` key can rotate itself on a schedule without an administrator in the loop — mint the replacement, cut over, revoke the old key, all from one integration process.

Because a `keys:admin` key is effectively a rotation-capable credential, treat it like any other high-value secret: short expiry (90 days or less), store it in a secrets manager, and review the key-revocation audit trail during incident response.

### Required scopes on `/api/v1/orgs/{id}/api-keys`

These endpoints accept either:

- An **API key** with the `keys:admin` scope, **or**
- A **session JWT** from an organization administrator (the path the web UI uses).

Requests authenticated with an API key that lacks `keys:admin` return `403 forbidden` with `"Missing required scope: keys:admin"`. Requests with a non-admin session JWT return `403 forbidden` via the org-admin check.

### Example: rotate a key from a script

```bash
# 1. Mint the replacement
NEW_KEY=$(curl -s -H "Authorization: Bearer $TRAKRF_API_KEY" \
               -H "Content-Type: application/json" \
               -d '{"name":"rotated-'"$(date -u +%Y-%m-%d)"'","scopes":["assets:read","keys:admin"],"expires_at":"2026-07-22T00:00:00Z"}' \
               "$BASE_URL/api/v1/orgs/$ORG_ID/api-keys" \
          | jq -r '.data.jwt')

# 2. Deploy $NEW_KEY to the integration, then rotate $TRAKRF_API_KEY in your secrets manager.
# 3. Revoke the old key once the cutover is confirmed:
curl -X DELETE -H "Authorization: Bearer $NEW_KEY" \
     "$BASE_URL/api/v1/orgs/$ORG_ID/api-keys/$OLD_KEY_ID"
```

The shapes of the response envelopes are shown in the [API reference](/api).

````

- [ ] **Step 2: Verify build passes (including the new anchor)**

Run: `pnpm build`
Expected: build completes with no broken-link errors. The `[Programmatic key rotation](#programmatic-key-rotation)` link from Task 1 now resolves to this section's `{#programmatic-key-rotation}` heading.

- [ ] **Step 3: Commit**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-466): add Programmatic key rotation section

New section covering the create-new → cut-over → revoke-old workflow,
self-rotation semantics (keys:admin can mint keys:admin), required
scopes on the three endpoints, and a runnable bash example. Request
body and DELETE path shapes are taken from trakrf/platform#197 and
will be reconciled against the refreshed openapi.{json,yaml} in a
later commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Add session-JWT caveat paragraph to `## Server-to-server design`

**Files:**
- Modify: `docs/api/authentication.md`

- [ ] **Step 1: Append one paragraph to the end of `## Server-to-server design`**

Find the end of the existing `## Server-to-server design` section (currently the single paragraph at line 118 ending with "...leaking keys to end-user devices."). Append a new paragraph after it, before the `## Environment variables` heading:

```markdown
**Session JWTs are also accepted** on public endpoints (same `Authorization: Bearer <jwt>` form), because the web app and the API share a router. A session JWT is effectively unscoped for its 1-hour lifetime and is only convenient for ad-hoc UI-driven requests; integrators should use API keys so that auth is durable and scope-limited.
```

- [ ] **Step 2: Verify build passes**

Run: `pnpm build`
Expected: build completes with no broken-link errors.

- [ ] **Step 3: Commit**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-466): note that session JWTs are accepted on public endpoints

Surfaces the shared-router behavior that the blackbox pass noted:
session JWTs authenticate public-endpoint requests with no scope
enforcement. Points integrators at API keys instead.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Remove api-keys content from `docs/api/private-endpoints.md`

**Files:**
- Modify: `docs/api/private-endpoints.md`

- [ ] **Step 1: Remove the `/orgs/{id}/api-keys` row from the table**

Find the row (currently line 26):

```markdown
| `/api/v1/orgs/{id}/api-keys`   | GET, POST, DELETE | Settings → API Keys UI | Internal                         | Internal — see API-key note below         |
```

Delete the entire row. No replacement.

- [ ] **Step 2: Remove the `## API-key management is Internal` section**

Find the section header (currently line 44):

```markdown
## API-key management is Internal {#api-key-management}
```

Delete from that heading through the last bullet of the section (the `Ask for a rotation primitive` bullet, currently line 51), **and** the blank line that separates that section from the next heading `## Classification policy`. The section must be entirely removed; nothing left pointing at `#api-key-management`.

- [ ] **Step 3: Scan the repo for stale `#api-key-management` references**

Run: `grep -rn "api-key-management" docs/ spec/`
Expected: zero matches inside `docs/` (the removed section was the only definition). Matches inside `spec/superpowers/specs/` are allowed — those are design-doc references to the section name, not live links.

- [ ] **Step 4: Verify build passes (broken-link check catches anchor drift)**

Run: `pnpm build`
Expected: build completes with no broken-link errors. Docusaurus's `onBrokenLinks: "throw"` will flag any page that still links to `#api-key-management`.

- [ ] **Step 5: Commit**

```bash
git add docs/api/private-endpoints.md
git commit -m "$(cat <<'EOF'
docs(tra-466): remove api-keys row and Internal classification

trakrf/platform#197 promotes POST/GET/DELETE /api/v1/orgs/{id}/api-keys
to the public API with the new keys:admin scope. The rotation narrative
now lives in authentication.md under Programmatic key rotation; this
page is the live classification list and the row leaves with the
promotion.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Add CHANGELOG entry under Unreleased → Added

**Files:**
- Modify: `docs/api/CHANGELOG.md`

- [ ] **Step 1: Append a new bullet to Unreleased → Added**

Find the `### Added` subsection under `## Unreleased` (currently lines 23–27, three existing bullets ending with the `type` field enumerates bullet). After the last bullet in that subsection, append:

```markdown
- `POST /api/v1/orgs/{id}/api-keys`, `GET /api/v1/orgs/{id}/api-keys`, and `DELETE /api/v1/orgs/{id}/api-keys/{keyId}` are now public, authenticated with the new **`keys:admin`** scope (or a session JWT from an org administrator). A `keys:admin` key may mint another `keys:admin` key, enabling unattended rotation for iPaaS, CI/CD, and IaC workflows. See [Authentication → Programmatic key rotation](./authentication#programmatic-key-rotation).
```

- [ ] **Step 2: Verify build passes**

Run: `pnpm build`
Expected: build completes with no broken-link errors. The `./authentication#programmatic-key-rotation` link resolves to the Task 2 section.

- [ ] **Step 3: Commit**

```bash
git add docs/api/CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs(tra-466): changelog entry for api-keys promotion

Adds Unreleased → Added bullet covering the three endpoints and the
new keys:admin scope, linking to the Programmatic key rotation
section in authentication.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Visual inspection of content edits (pre-spec-refresh)

**Files:** none modified.

This is an inspection task; no commits. The goal is to confirm the three affected pages render correctly before we mix in the spec refresh.

- [ ] **Step 1: Start the dev server**

Run: `pnpm dev`
Expected: dev server starts on `http://localhost:3000` with no compilation errors. Leave it running for Steps 2–4.

- [ ] **Step 2: Inspect `/docs/api/authentication`**

In a browser, open `http://localhost:3000/docs/api/authentication` and verify:
- The Scopes table has a `keys:admin` row at the bottom with Access = `Admin` and the three api-keys endpoints in the Endpoints column.
- The "non-obvious pairings" list has a `keys:admin` bullet with a link to `Programmatic key rotation`. Click it — page scrolls to the new section.
- The `## Programmatic key rotation` section renders: numbered workflow list, `### Self-rotation`, `### Required scopes`, `### Example: rotate a key from a script` with a syntax-highlighted bash block.
- The `## Server-to-server design` section ends with the new session-JWT-accepted paragraph (bold "Session JWTs are also accepted" lead-in).

- [ ] **Step 3: Inspect `/docs/api/private-endpoints`**

Open `http://localhost:3000/docs/api/private-endpoints` and verify:
- The table no longer contains a `/api/v1/orgs/{id}/api-keys` row.
- There is no `## API-key management is Internal` heading on the page.
- The `:::caution Internal endpoints` admonition at top still renders.
- The remaining table rows (`/auth/login`, `/auth/signup`, `/users/me`, `/orgs`, `/orgs/me`) are intact.

- [ ] **Step 4: Inspect `/docs/api/changelog`**

Open `http://localhost:3000/docs/api/changelog` and verify:
- Under `Unreleased → Added`, the new bullet is present.
- Click the `Authentication → Programmatic key rotation` link — browser navigates to `/docs/api/authentication#programmatic-key-rotation` and scrolls to the right section.

- [ ] **Step 5: Stop the dev server**

In the terminal running `pnpm dev`, press `Ctrl+C`. No commit — this is inspection only.

---

### Task 7: Refresh the OpenAPI spec from preview (gated on platform PR merge)

**Files:**
- Modify: `static/api/openapi.json`
- Modify: `static/api/openapi.yaml`

**Prerequisite:** `trakrf/platform#197` has merged to `main` and the preview deploy at `https://app.preview.trakrf.id` has picked up the new build. Confirm by running `curl -s https://app.preview.trakrf.id/api/v1/openapi.json | jq -r '.paths | keys[] | select(contains("api-keys"))'` — expected output contains `/api/v1/orgs/{id}/api-keys`. If the output is empty, the preview hasn't rebuilt yet; wait and retry.

- [ ] **Step 1: Confirm the platform PR has merged**

Run: `gh pr view 197 --repo trakrf/platform --json state,mergedAt`
Expected: `"state":"MERGED"` and a non-null `mergedAt` timestamp.

- [ ] **Step 2: Confirm the preview spec contains the new endpoints**

Run: `curl -s https://app.preview.trakrf.id/api/v1/openapi.json | jq -r '.paths | keys[] | select(contains("api-keys"))'`
Expected output contains at least:
```
/api/v1/orgs/{id}/api-keys
```
(And likely `/api/v1/orgs/{id}/api-keys/{keyId}` for DELETE.)

If the output is empty, **stop** — wait for the preview to rebuild, then retry. Do not run the refresh against a stale spec.

- [ ] **Step 3: Run the refresh script**

Run: `./scripts/refresh-openapi.sh`
Expected: the script downloads `openapi.json` and `openapi.yaml` to `static/api/`, prints the line counts, and prints the path list (which should now include `/api/v1/orgs/{id}/api-keys` and its `{keyId}` sub-path). The script exits 0.

- [ ] **Step 4: Review the diff for sanity**

Run: `git diff --stat static/api/`
Expected: both files changed with additions. The additions should be proportional to what platform PR #197 reported (~290 JSON / ~179 YAML lines, give or take).

Run: `git diff static/api/openapi.json | head -100`
Expected: the diff includes a new `"/api/v1/orgs/{id}/api-keys"` path with POST/GET operations and (likely) a `"/api/v1/orgs/{id}/api-keys/{keyId}"` with DELETE, each under `"tags": [..., "public"]` or similar — no longer under `"internal"`.

- [ ] **Step 5: Capture the platform SHA for the commit message**

Run: `curl -s https://app.preview.trakrf.id/api/v1/openapi.json | jq -r '.info.version, .info["x-build-sha"] // empty'`
If the `x-build-sha` field is present in the spec, note it for the commit message. If not, omit the SHA and use "latest preview" in the message.

- [ ] **Step 6: Commit**

```bash
git add static/api/openapi.json static/api/openapi.yaml
git commit -m "$(cat <<'EOF'
chore(api): sync preview spec from platform

Picks up POST/GET/DELETE /api/v1/orgs/{id}/api-keys now that
trakrf/platform#197 has merged and the preview deploy has rebuilt.
Matches the convention used in c360911 and 2c342c0.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

(If a platform SHA was captured in Step 5, include it: `chore(api): sync preview spec from platform@<sha>`.)

---

### Task 8: Reconcile the example in `authentication.md` against the refreshed spec

**Files:**
- Potentially modify: `docs/api/authentication.md` (only if discrepancies are found)

The spec (from the platform PR body) described the POST/DELETE shapes well enough to sketch the example in Task 2. Now that the real spec is on disk, verify — and fix the example only if the real spec disagrees.

- [ ] **Step 1: Extract the real POST request body shape**

Run:
```bash
jq '.paths["/api/v1/orgs/{id}/api-keys"].post.requestBody.content["application/json"].schema' static/api/openapi.json
```

Expected: a schema describing the request body. Note the required/optional field names — especially whether `name`, `scopes`, and `expires_at` (or a different spelling like `expiresAt` or `expires`) are the actual keys.

- [ ] **Step 2: Extract the real POST response body shape**

Run:
```bash
jq '.paths["/api/v1/orgs/{id}/api-keys"].post.responses["201"].content["application/json"].schema // .paths["/api/v1/orgs/{id}/api-keys"].post.responses["200"].content["application/json"].schema' static/api/openapi.json
```

Expected: a schema describing the response. Note where the JWT is exposed — `data.jwt`, `data.token`, or a different property name.

- [ ] **Step 3: Identify the DELETE path**

Run:
```bash
jq -r '.paths | keys[] | select(contains("api-keys"))' static/api/openapi.json
```

Expected: two paths, one for the collection (POST/GET) and one for the item (DELETE). Note the item-path parameter name — `{keyId}`, `{id}`, or something else.

- [ ] **Step 4: Compare and fix**

Open `docs/api/authentication.md` and cross-check the following against the spec extracts from Steps 1–3:

- **Scopes-table row** (Task 1) uses `DELETE /orgs/{id}/api-keys/{keyId}`. If the real parameter name differs, update the row to match.
- **The "Mint a replacement" bullet** in `## Programmatic key rotation` uses `expires_at`. If the real field is spelled differently, update this bullet.
- **The "Revoke the old key" bullet** uses `DELETE /api/v1/orgs/{id}/api-keys/{keyId}`. Update if the parameter name differs.
- **The bash example**'s POST body uses `"expires_at"`, the jq extraction uses `.data.jwt`, the DELETE curl uses `/api/v1/orgs/$ORG_ID/api-keys/$OLD_KEY_ID`. Update any of these to match the spec.

If the spec matches what Task 2 wrote, **no edit is needed** — proceed to Step 6.

- [ ] **Step 5: Verify build passes after any corrections**

Run: `pnpm build`
Expected: build completes with no broken-link errors.

- [ ] **Step 6: Commit (only if edits were made in Step 4)**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-466): reconcile rotation example with refreshed openapi spec

Matches request/response field names and the DELETE sub-path to what
the refreshed static/api/openapi.json actually declares.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If no edits were made, skip the commit.

---

### Task 9: Final visual inspection of `/api` reference

**Files:** none modified.

- [ ] **Step 1: Start the dev server**

Run: `pnpm dev`
Expected: dev server starts on `http://localhost:3000`.

- [ ] **Step 2: Inspect the Redoc-rendered `/api` reference**

Open `http://localhost:3000/api` and verify:
- The left sidebar includes an "api-keys" section (or similar tag grouping) listing the three operations: create, list, delete.
- Opening the **POST /api/v1/orgs/{id}/api-keys** operation shows the request body schema with the fields referenced in the prose (`name`, `scopes`, and whatever expiry field the spec actually uses).
- The **DELETE** operation shows the correct path parameter name.
- Each of the three operations lists `keys:admin` as a required scope (or lists the security requirement consistent with the endpoint's auth model).

- [ ] **Step 3: Re-inspect `/docs/api/authentication` for consistency**

Open `http://localhost:3000/docs/api/authentication` and confirm the Programmatic key rotation section and the example code block match what the Redoc page shows for the three endpoints. If Task 8 made any edits, this is where the reconciliation pays off.

- [ ] **Step 4: Stop the dev server**

`Ctrl+C` in the dev-server terminal. No commit.

---

### Task 10: Push branch and open the PR

**Files:** none modified locally; opens a PR on GitHub.

- [ ] **Step 1: Confirm all commits are on the branch**

Run: `git log --oneline main..HEAD`
Expected: 5–7 commits, all prefixed `docs(tra-466):` or `chore(api):`, in the order the tasks produced them. No stray commits.

- [ ] **Step 2: Confirm tree is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean` and either "ahead of 'origin/main' by N commits" or no tracking branch yet.

- [ ] **Step 3: Push the branch**

Run: `git push -u origin miks2u/tra-466-docs-promote-api-key-management`
Expected: push succeeds.

- [ ] **Step 4: Open the PR**

Run:
```bash
gh pr create --title "docs(tra-466): promote api-key management endpoints to public API" --body "$(cat <<'EOF'
## Summary

Docs side of TRA-466. Pairs with [trakrf/platform#197](https://github.com/trakrf/platform/pull/197) (now merged), which promoted `POST/GET/DELETE /api/v1/orgs/{id}/api-keys` to the public API and added the `keys:admin` scope.

- Add `keys:admin` row to the Scopes table and a non-obvious-pairings bullet pointing at the new section.
- Add a **Programmatic key rotation** section to `docs/api/authentication.md` covering the create-new → cut-over → revoke-old workflow, self-rotation semantics (`keys:admin` may mint `keys:admin`), required scopes, and a runnable bash example.
- Note that session JWTs are accepted on public endpoints (blackbox finding from 2026-04-23; existing platform behavior, now documented).
- Remove the `/api/v1/orgs/{id}/api-keys` row and the "API-key management is Internal" section from `docs/api/private-endpoints.md` — they're public now.
- Changelog entry under Unreleased → Added.
- Refresh `static/api/openapi.{json,yaml}` from `app.preview.trakrf.id` so `/api` Redoc reflects the new endpoints.

Design spec: `spec/superpowers/specs/2026-04-23-tra-466-docs-api-key-public-promotion-design.md`
Plan: `spec/superpowers/plans/2026-04-23-tra-466-docs-api-key-public-promotion.md`

## Test plan

- [ ] `pnpm build` passes (broken-link check enforces cross-page anchors).
- [ ] `pnpm dev` — `/docs/api/authentication` shows `keys:admin` in scopes, the new Programmatic key rotation section, and the session-JWT paragraph.
- [ ] `pnpm dev` — `/docs/api/private-endpoints` has the api-keys row removed and no stale `#api-key-management` references.
- [ ] `pnpm dev` — `/docs/api/changelog` Unreleased → Added bullet links to the new section and resolves.
- [ ] `pnpm dev` — `/api` Redoc page shows the three api-keys operations under a public tag, with `keys:admin` as the required scope and schemas that match the example in authentication.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL is returned. Report the URL back to the user.

- [ ] **No commit** — branch push and PR are the deliverables.

---

## Notes

- **No squash merge** (per `CLAUDE.md`). Each task's commit preserves the rationale for the corresponding section of the spec.
- **Do not push to `main`** (per `CLAUDE.md`).
- **The spec commit (`cfe36c4`) stays on the branch** — it's the design-of-record and should ship with the PR.
