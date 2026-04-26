# TRA-504 Docs Nit Sweep — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Six-item docs sweep consolidating BB9 (2026-04-24) findings + TRA-501 / TRA-503 deferred docs follow-ups (PRs #222 and #223 merged 2026-04-25). Spec: `spec/superpowers/specs/2026-04-25-tra-504-docs-nit-sweep-design.md`. Branch `miks2u/tra-504-docs-nit-sweep` already has the prerequisite spec sync (`a63c31e`) and design spec (`57d728f`); this plan adds 4 doc edits, 1 verification chore, 1 CHANGELOG commit, then opens a PR.

**Architecture:** Four targeted markdown edits across `docs/api/{pagination-filtering-sorting,authentication,quickstart,errors}.{md,mdx}`, plus one empty chore commit recording the verification work for items 3 & 4, plus one CHANGELOG commit, plus a final `pnpm build` smoke-test before opening the PR. No new files, no sidebar changes, no code changes.

**Tech Stack:** Docusaurus 3.x (markdown / MDX), pnpm exclusively (`npx` is forbidden — use `pnpm exec` or `pnpm dlx`). Prettier is the linter. The interactive `/api` reference is regenerated from `static/api/openapi.json` at build time, so the spec sync done in `a63c31e` already brings the rendered reference into TRA-503 alignment automatically.

---

## Prerequisites

- On branch `miks2u/tra-504-docs-nit-sweep` in worktree `.worktrees/tra-504-docs-nit-sweep`. Confirm with `git branch --show-current && git log --oneline -3`. The two head commits should be `57d728f docs(tra-504): design spec for docs nit sweep` and `a63c31e chore(api): sync spec from preview (post-TRA-501/503 deploy)`.
- `pnpm install` already run in the worktree at setup time. Re-run if `node_modules` is missing.
- Port 3000 free for `pnpm dev` during Task 5. If another dev server is up in the main checkout, either stop it or use `PORT=3001 pnpm dev`.
- For Task 5 verification: `curl` available, plus a preview API key with `scans:read` exported as `TRAKRF_API_KEY`. The endpoint hit (`GET /api/v1/locations/current`) requires `scans:read` and nothing else.
- `gh` CLI authenticated for the final `gh pr create` in Task 7. Confirm with `gh auth status`.

## File Structure

- **Modify** — `docs/api/pagination-filtering-sorting.md` — delete the `### Non-paginated list exceptions` section (lines 32–48 in current `HEAD`). Section anchor `#non-paginated-exceptions` goes away with it.
- **Modify** — `docs/api/authentication.md` — insert a new H3 sub-section `### Identifying a key {#identifying-a-key}` between line 115 (last bullet of Key lifecycle) and line 117 (`## Programmatic key rotation` heading); update the rotation-workflow step 4 at line 126 to link `{keyID}` to the new sub-section.
- **Modify** — `docs/api/quickstart.mdx` — rewrite step 5 of "Mint an API key" (line 36) to name the **Expires** picker, enumerate options, recommend 90 days.
- **Modify** — `docs/api/errors.md` — add `params` to the `too_long` entry of the JSON example (line 65–70 region), append a `params` row to the field-entries table (after line 87), append one prose paragraph after line 98.
- **Modify** — `docs/api/CHANGELOG.md` — append two entries to `## Unreleased → ### Added` (TRA-501 DELETE, TRA-503 envelope), append two entries to `## Unreleased → ### Changed` (expiry picker prose, params documentation).

No tests, no new files, no sidebar changes. The "test" is `pnpm typecheck && pnpm lint && pnpm build` passing — `docusaurus.config.ts` enables `onBrokenLinks: "throw"`, so any broken anchor (e.g., a stray reference to the deleted `#non-paginated-exceptions`) fails the build.

---

## Task 1: Item 5 — Remove non-paginated exceptions from pagination page

**Files:**

- Modify: `docs/api/pagination-filtering-sorting.md` (delete lines 32–48 in current `HEAD`)

Item 5 is unblocked because the prerequisite spec sync `a63c31e` brought all five TRA-503-touched endpoints into envelope-everywhere alignment in `static/api/openapi.json`. Doing this task first because deleting the exceptions section is the largest single change and the most impactful customer-facing correction.

- [ ] **Step 1: Confirm branch state**

Run:

```bash
pwd
git branch --show-current
git log --oneline -3
```

Expected: `pwd` ends in `.worktrees/tra-504-docs-nit-sweep`; branch is `miks2u/tra-504-docs-nit-sweep`; the three most-recent commits are `57d728f docs(tra-504): design spec for docs nit sweep`, `a63c31e chore(api): sync spec from preview (post-TRA-501/503 deploy)`, and the `main` tip (`d238225 Merge pull request #45 …`).

- [ ] **Step 2: Sanity-check the spec actually has envelope on all five endpoints**

Re-run the post-sync verification from the design spec:

```bash
for s in internal_handlers_locations.ListAncestorsResponse \
         internal_handlers_locations.ListChildrenResponse \
         internal_handlers_locations.ListDescendantsResponse \
         internal_handlers_orgs.ListAPIKeysResponse \
         internal_handlers_reports.AssetHistoryResponse; do
  echo "=== $s ==="
  jq --arg s "$s" '.components.schemas[$s].properties | keys' static/api/openapi.json
done
```

Expected: every printed array is `["data", "limit", "offset", "total_count"]`. If any is missing fields, **stop** — `static/api/openapi.json` is not in TRA-503 alignment and Task 1 needs to wait on a fresh `bash scripts/refresh-openapi.sh`. Do not proceed to step 3 in that case.

- [ ] **Step 3: Search for any other references to the section anchor**

```bash
grep -rn 'non-paginated-exceptions' docs/ src/ sidebars.ts spec/ 2>/dev/null
```

Expected: only matches inside `spec/superpowers/specs/2026-04-25-tra-504-docs-nit-sweep-design.md` (the design spec we just wrote, which references the section by anchor) and the section's own anchor declaration in `docs/api/pagination-filtering-sorting.md`. Any other match — particularly in `docs/api/*` — is a cross-reference that will become a broken link after step 4 and needs to be rewritten in the same commit.

- [ ] **Step 4: Delete the `### Non-paginated list exceptions` section**

Delete lines 32 through 48 of `docs/api/pagination-filtering-sorting.md` — the entire `### Non-paginated list exceptions` block, including its `{#non-paginated-exceptions}` anchor declaration, the prose describing the location-hierarchy endpoints, the bulleted endpoint list, the inline JSON example showing only `data`, and the closing paragraph that contrasts these endpoints with the paginated `GET /api/v1/locations?parent=…` form. Preserve the blank line at line 31 (after the `total_count` table row) and the `## Pagination` heading at line 50 — they should now sit adjacent with one blank line between them.

Verify with:

```bash
sed -n '28,34p' docs/api/pagination-filtering-sorting.md
```

Expected after the edit: the `total_count` table row, a blank line, then `## Pagination`. The `### Non-paginated list exceptions` heading and its body are gone.

The `Every list endpoint returns the same envelope` claim earlier in the file (around line 12 originally) now stands without exception.

- [ ] **Step 5: Verify the file still parses**

```bash
pnpm typecheck && pnpm lint
```

Expected: both pass with no output. If `pnpm lint` flags formatting on the file, run `pnpm exec prettier --write docs/api/pagination-filtering-sorting.md` and re-run.

- [ ] **Step 6: Visual check (defer to Task 5 if not running dev yet)**

If you'll be doing Task 5 anyway and don't have `pnpm dev` up yet, defer the visual check until then. Otherwise:

```bash
pnpm dev   # in another shell, then visit http://localhost:3000/docs/api/pagination-filtering-sorting
```

Expected: page renders, no `### Non-paginated list exceptions` section, no MDX parse errors in the dev-server console.

- [ ] **Step 7: Commit**

```bash
git add docs/api/pagination-filtering-sorting.md
git commit -m "$(cat <<'EOF'
docs(tra-504): remove non-paginated exceptions, envelope is universal

Per TRA-503 (PR #222, merged 2026-04-25), the location-hierarchy
traversal endpoints (/locations/{id}/{ancestors,children,descendants}),
/orgs/{id}/api-keys, and /assets/{id}/history all now return the
standard pagination envelope (data, limit, offset, total_count).
Confirmed via jq inspection of the post-sync spec at
static/api/openapi.json (sync committed in a63c31e).

Removes the entire "### Non-paginated list exceptions" section. The
"Every list endpoint returns the same envelope" claim earlier in the
page now stands universally.
EOF
)"
```

Expected: one commit added, one file changed (~17 lines deleted).

---

## Task 2: Item 6 — Add id-vs-jti explainer under Key lifecycle

**Files:**

- Modify: `docs/api/authentication.md` (insert new H3 after line 115, edit step 4 at line 126 of the rotation workflow)

Documents TRA-501 (PR #223, merged 2026-04-25) — `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` accepts either the integer surrogate `id` or the UUID `jti`. The UI displays the UUID; some customers will reference keys by either form.

- [ ] **Step 1: Confirm the rotation-workflow step 4 still reads as expected**

```bash
sed -n '126p' docs/api/authentication.md
```

Expected: `4. **Revoke the old key** — `DELETE /api/v1/orgs/{id}/api-keys/{keyID}`. Any subsequent request with the old JWT returns `401 unauthorized`.`

If the line number has drifted, find the right line with `grep -n 'Revoke the old key' docs/api/authentication.md` and use that line instead in step 3 below.

- [ ] **Step 2: Insert the new sub-section under Key lifecycle**

Open `docs/api/authentication.md`. Find the boundary between the `## Key lifecycle` bullet list and the `## Programmatic key rotation` heading. Currently lines 115–117 read:

```markdown
- **Expiration:** keys do not expire by default — leaving the field blank at creation mints a permanent credential with no `exp` claim. For any key beyond a throwaway local-dev credential, set an explicit expiration (e.g. 90 days) and schedule the rotation. Expired keys return `401 unauthorized`.

## Programmatic key rotation {#programmatic-key-rotation}
```

Insert a new `### Identifying a key {#identifying-a-key}` sub-section between them. The result should read:

```markdown
- **Expiration:** keys do not expire by default — leaving the field blank at creation mints a permanent credential with no `exp` claim. For any key beyond a throwaway local-dev credential, set an explicit expiration (e.g. 90 days) and schedule the rotation. Expired keys return `401 unauthorized`.

### Identifying a key {#identifying-a-key}

Every API key has two identifiers:

- An integer `id` (surrogate key) — present in list responses from `GET /api/v1/orgs/{id}/api-keys`.
- A UUID `jti` — embedded in the JWT's `sub` claim, displayed in the web UI's API Keys page, and printed in audit-log entries.

`DELETE /api/v1/orgs/{id}/api-keys/{keyID}` accepts either form for `{keyID}`. For human-readable scripts, audit trails, and incident-response runbooks, prefer `jti`: it's stable, visible everywhere the key surfaces (UI, JWT, API responses, logs), and self-describing as a UUID.

## Programmatic key rotation {#programmatic-key-rotation}
```

Note: the new sub-section is `###` (H3), not `##` — it lives under the `## Key lifecycle` parent. Docusaurus will render it as a sub-heading and add it to the right-rail TOC.

- [ ] **Step 3: Update step 4 of the rotation workflow to link the new sub-section**

The current step 4 (line 126 before the insertion in step 2 — re-check the new line number after the insertion; `grep -n 'Revoke the old key' docs/api/authentication.md` will find it):

```markdown
4. **Revoke the old key** — `DELETE /api/v1/orgs/{id}/api-keys/{keyID}`. Any subsequent request with the old JWT returns `401 unauthorized`.
```

Replace with:

```markdown
4. **Revoke the old key** — `DELETE /api/v1/orgs/{id}/api-keys/{keyID}`, where `{keyID}` is either the integer `id` or the UUID `jti` (see [Identifying a key](#identifying-a-key)). Any subsequent request with the old JWT returns `401 unauthorized`.
```

- [ ] **Step 4: Verify the file still parses and the new anchor resolves**

```bash
pnpm typecheck && pnpm lint
```

Expected: both pass. Then sanity-check the new anchor exists where the link points:

```bash
grep -n 'identifying-a-key' docs/api/authentication.md
```

Expected: two matches — the section anchor declaration (`### Identifying a key {#identifying-a-key}`) and the link from step 4 (`(#identifying-a-key)`).

- [ ] **Step 5: Visual check (defer to Task 5 if not running dev yet)**

If `pnpm dev` is up, visit `http://localhost:3000/docs/api/authentication#identifying-a-key` and confirm the page scrolls to the new sub-section. Then click the link from rotation-workflow step 4 — it should land on the same anchor.

- [ ] **Step 6: Commit**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-504): explainer for api-key id vs jti identifiers

Per TRA-501 (PR #223, merged 2026-04-25), DELETE /api/v1/orgs/{id}/api-keys/{keyID}
accepts either the integer surrogate id or the UUID jti. Adds a new
"Identifying a key" sub-section under Key lifecycle naming both
identifiers, where each appears, and recommending jti for scripts and
audit trails. Updates the rotation-workflow step 4 to link the new
section so customers see the choice in context.
EOF
)"
```

Expected: one commit added, one file changed (~10 lines added, 1 line modified).

---

## Task 3: Item 1 — Quickstart: name the expiry picker and recommend 90 days

**Files:**

- Modify: `docs/api/quickstart.mdx` (rewrite step 5 of "Mint an API key" at line 36)

Current step 5 mentions expiry but doesn't enumerate the picker options or strongly recommend a default. BB9 caught a new dev hitting the picker with no guidance.

- [ ] **Step 1: Confirm step 5 still reads as expected**

```bash
sed -n '36p' docs/api/quickstart.mdx
```

Expected (line 36):

```
5. **Set an expiration.** Leaving the expiry field blank mints a permanent credential — fine for a throwaway local-dev key, but for anything shared or long-lived, pick a date (e.g. 90 days) and put a rotation reminder on the calendar. See [Authentication → Key lifecycle](./authentication#key-lifecycle).
```

If the line number has drifted, find with `grep -n '5. \*\*Set an expiration' docs/api/quickstart.mdx`.

- [ ] **Step 2: Replace step 5 with the rewritten prose**

Open `docs/api/quickstart.mdx`. Replace the entire line 36 with:

```markdown
5. **Pick an expiration.** The **Expires** picker offers **Never / 30 days / 90 days / 1 year / Custom**. For production keys, **90 days** is the recommended default — short enough to align with quarterly secrets review, long enough to avoid weekly rotation churn. Pick **Never** only for throwaway local-dev keys; the [no-expiry security warning](./authentication#key-lifecycle) explains the audit-trail and incident-response cost. For shared or long-lived keys, set the expiration and put the rotation date on the calendar.
```

The leading `5. ` numbering and the trailing newline are preserved.

- [ ] **Step 3: Verify the file still parses**

```bash
pnpm typecheck && pnpm lint
```

Expected: both pass. If `pnpm lint` complains about line length or formatting, run `pnpm exec prettier --write docs/api/quickstart.mdx` and re-check the diff.

- [ ] **Step 4: Visual check (defer to Task 5 if not running dev yet)**

If `pnpm dev` is up, visit `http://localhost:3000/docs/api/quickstart` and confirm the rewritten step 5 renders as a numbered list item, the bold formatting works (`Expires`, `Never / 30 days / …`, `90 days`, `Never`), and the link to `./authentication#key-lifecycle` resolves.

- [ ] **Step 5: Commit**

```bash
git add docs/api/quickstart.mdx
git commit -m "$(cat <<'EOF'
docs(tra-504): name expiry picker options in quickstart

Per BB9 (2026-04-24), the quickstart's "Mint an API key" walkthrough
mentioned expiry in passing but didn't name the picker or enumerate
the options (Never / 30 days / 90 days / 1 year / Custom). Rewrites
step 5 to name the Expires picker, list the choices, recommend 90
days as the production default (quarterly-review-aligned), and cross-
reference TRA-449's no-expiry security warning under Key lifecycle.
EOF
)"
```

Expected: one commit added, one file changed (1 line modified, possibly slight re-wrapping).

---

## Task 4: Item 2 — Document `validation_error.fields[].params`

**Files:**

- Modify: `docs/api/errors.md` (three sub-edits in the `## Validation errors` section)

The `params` field is shipped by the platform but undocumented in the API reference. CHANGELOG already mentions it in passing under TRA-466's API-key promotion entry; this task documents it formally so customers reading the errors reference can rely on it for programmatic handling.

- [ ] **Step 1: Confirm anchor lines still match**

```bash
sed -n '67,70p' docs/api/errors.md
sed -n '85,87p' docs/api/errors.md
sed -n '96,98p' docs/api/errors.md
```

Expected:

- Lines 67–70: the `too_long` field-error entry in the JSON example (`"field": "identifier"`, `"code": "too_long"`, `"message": "identifier must be at most 255 characters"`).
- Lines 85–87: the three rows of the field-entries table (`field`, `code`, `message`).
- Lines 96–98: the last bullet of the `code` enum (`too_large`), the trailing blank line, and the "extensible enum" paragraph.

If any of these have drifted, find the right line with grep and adjust the edit targets accordingly.

- [ ] **Step 2: (Sub-edit a) Add `params` to the `too_long` entry in the JSON example**

The current block at lines 65–70:

```json
    "fields": [
      {
        "field": "identifier",
        "code": "too_long",
        "message": "identifier must be at most 255 characters"
      },
```

Replace with (note the comma after `"message"` and the new `"params"` line):

```json
    "fields": [
      {
        "field": "identifier",
        "code": "too_long",
        "message": "identifier must be at most 255 characters",
        "params": { "max_length": 255 }
      },
```

The other two entries (`type` / `invalid_value` and the closing `]`) stay unchanged.

- [ ] **Step 3: (Sub-edit b) Add a `params` row to the field-entries table**

The current table at lines 83–87:

```markdown
| Field     | Purpose                                                                                                                                                                                                          |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `field`   | The JSON field name of the offending request attribute (e.g. `identifier`, `org_name`). Values are the snake_case JSON keys defined by the endpoint's request schema, not Go struct names or JSON-pointer paths. |
| `code`    | A machine-readable code — your validation UI can branch on this. Extensible enum.                                                                                                                                |
| `message` | A human-readable message safe to show the end user.                                                                                                                                                              |
```

Append one row immediately after `message`:

```markdown
| Field     | Purpose                                                                                                                                                                                                          |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `field`   | The JSON field name of the offending request attribute (e.g. `identifier`, `org_name`). Values are the snake_case JSON keys defined by the endpoint's request schema, not Go struct names or JSON-pointer paths. |
| `code`    | A machine-readable code — your validation UI can branch on this. Extensible enum.                                                                                                                                |
| `message` | A human-readable message safe to show the end user.                                                                                                                                                              |
| `params`  | Optional. Field-specific constraint metadata (e.g. `max_length`, `allowed_values`, `min`, `max`). Schema varies per field — treat unknown keys gracefully.                                                       |
```

Prettier may re-align the column padding when it runs in step 5 — that's fine; let it.

- [ ] **Step 4: (Sub-edit c) Add a `params` paragraph after the code-enum bullets**

The current text at lines 96–99:

```markdown
- `too_large` — numeric value above the maximum

The `code` enum is extensible — TrakRF may add new validation codes in any v1 release. Treat unknown codes as generic invalid-value errors and surface the `message` field.
```

Insert a new paragraph between the bullets-end and the "extensible" paragraph:

```markdown
- `too_large` — numeric value above the maximum

Some entries also include a `params` object carrying constraint metadata (e.g. `max_length`, `allowed_values`, `min`, `max`). The keys are field-specific — don't expect a fixed schema, and treat unknown keys gracefully.

The `code` enum is extensible — TrakRF may add new validation codes in any v1 release. Treat unknown codes as generic invalid-value errors and surface the `message` field.
```

- [ ] **Step 5: Verify the file still parses, and re-format if needed**

```bash
pnpm typecheck && pnpm lint
```

Expected: both pass. If `pnpm lint` re-flows the table padding, run `pnpm exec prettier --write docs/api/errors.md` and check the diff:

```bash
git diff docs/api/errors.md
```

The diff should show: the JSON example with the `params` line, the new table row for `params`, and the new paragraph between the code-enum and the "extensible" paragraph. No other changes.

- [ ] **Step 6: Visual check (defer to Task 5 if not running dev yet)**

If `pnpm dev` is up, visit `http://localhost:3000/docs/api/errors#validation-errors` and confirm: the JSON example highlights `params` correctly, the table has four rows, and the new paragraph reads cleanly above the "extensible enum" prose.

- [ ] **Step 7: Commit**

```bash
git add docs/api/errors.md
git commit -m "$(cat <<'EOF'
docs(tra-504): document validation_error fields[].params

The platform has shipped an optional `params` object on each
validation_error fields[] entry for some time (e.g. {"max_length":
255} on too_long, {"allowed_values": [...]} on invalid_value).
Useful for programmatic handling but undocumented in the API
reference until now.

Adds: the params field to one entry of the JSON example, a fourth
row to the field-entries table, and a short paragraph noting the
schema is field-specific and clients should treat unknown keys
gracefully.
EOF
)"
```

Expected: one commit added, one file changed (~6 lines added).

---

## Task 5: Items 3 & 4 — Verify BASE_URL copy-paste and Postman collection

**Files:** none changed — this task produces an empty chore commit recording the verification.

Both items were inspected at design time and look like they'll close as no-change. This task does the live verification (item 3 via browser + curl, item 4 via re-confirming the file inspections) and records the result.

- [ ] **Step 1: Start the dev server**

In a second shell:

```bash
pnpm dev
```

Wait for `[INFO] Docusaurus website is running at: http://localhost:3000/` then leave the server up.

If port 3000 is in use:

```bash
PORT=3001 pnpm dev
```

— and substitute `localhost:3001` everywhere below.

- [ ] **Step 2: Item 3 — verify the BASE_URL copy-paste path**

In a browser, open `http://localhost:3000/docs/api/quickstart`. Locate the rendered code block under **1. Pick your environment** — the one produced by `<EnvBaseURLBlock />`. It should look like:

```
export BASE_URL=https://app.preview.trakrf.id
```

(or `https://app.trakrf.id` depending on which env the dev server reports — defaults to preview locally.)

In a third shell:

```bash
export TRAKRF_API_KEY=<your preview key with scans:read>
# Then paste the export line you just copied from the rendered page:
export BASE_URL=https://app.preview.trakrf.id
# Then paste the step-3 curl block from the rendered page:
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/current"
```

Expected: an HTTP response body — either `200` with the locations payload, or `401` if the key is wrong, or some other status code. Any response body proves `BASE_URL` substituted correctly. An empty response, "could not resolve host," or "connection refused" means the EnvBaseURLBlock isn't actually rendering / the export didn't take.

**Outcome A (got a response, any status):** record as verified, no docs change. Continue to step 3.

**Outcome B (empty / no host resolved):** the verification failed — TRA-467's auto-detect isn't actually working in the rendered build. Pause here and add an explicit prose lead-in before the EnvBaseURLBlock in `docs/api/quickstart.mdx`. The current line 26 reads `<EnvBaseURLBlock />`. Insert one line above it:

```markdown
First, copy this line into your shell:

<EnvBaseURLBlock />
```

Then re-run the curl to confirm the prose helps. Make this its own commit `docs(tra-504): make quickstart BASE_URL copy step explicit` BEFORE the chore commit in step 4 below, and update step 4's chore-commit body to record Outcome B.

- [ ] **Step 3: Item 4 — re-confirm Postman collection inspection**

```bash
grep -c '"host"' static/api/trakrf-api.postman_collection.json
grep -c '{{baseUrl}}' static/api/trakrf-api.postman_collection.json
```

Expected: the count of `{{baseUrl}}` matches (or exceeds) the count of `"host"` — meaning every `host` array points at the variable, not a hardcoded URL. If the variable count is lower than the host count, search for the offending hardcoded value:

```bash
grep -nE '"host":\s*\[[^]]*"app\.' static/api/trakrf-api.postman_collection.json
```

Any match is a host hardcoded to `app.trakrf.id` or similar — that needs filing as a follow-up, not fixing in this sweep (the collection is bot-generated from the OpenAPI spec; the fix lives in the platform repo, not here).

Then re-confirm the docs page documents both env values:

```bash
grep -nE 'app\.(preview\.)?trakrf\.id' docs/api/postman.mdx
```

Expected: two matches on line 31 (or wherever the `Importing into Postman` collection-variables list lives) — one for prod, one for preview.

**Outcome (both confirmed):** record as verified, no docs change.

- [ ] **Step 4: Stop the dev server, commit the verification chore**

`Ctrl-C` the dev server. Then create an empty commit recording both verifications:

```bash
git commit --allow-empty -m "$(cat <<'EOF'
chore(tra-504): verify items 3 & 4 (BASE_URL copy-paste, Postman collection)

Item 3 — BASE_URL copy-paste path (post-TRA-467 auto-detect):

  Started `pnpm dev`, opened /docs/api/quickstart in a browser,
  copied the rendered <EnvBaseURLBlock /> output and the step-3
  curl block into a real shell, exported a preview API key, and
  ran the curl. Got an HTTP response (status code in body),
  confirming BASE_URL substituted correctly. No docs change.

Item 4 — Postman collection link:

  Inspected static/api/trakrf-api.postman_collection.json — every
  "host" entry points at {{baseUrl}}; no hardcoded URLs.
  Re-confirmed docs/api/postman.mdx documents both prod
  (https://app.trakrf.id/api/v1) and preview
  (https://app.preview.trakrf.id/api/v1) values for the baseUrl
  collection variable. No docs change.

(If you're reading this and Outcome B happened in either item,
the prose-fix commit lands immediately before this one and the
relevant block above is updated to say so.)
EOF
)"
```

Expected: one empty commit added (no files changed).

---

## Task 6: CHANGELOG — record all four contract / docs deltas

**Files:**

- Modify: `docs/api/CHANGELOG.md` (append four bullets to `## Unreleased`)

Two `### Added` entries (TRA-501 contract change, TRA-503 contract change), two `### Changed` entries (expiry picker prose, params documentation).

- [ ] **Step 1: Confirm the `## Unreleased` shape**

```bash
sed -n '20,40p' docs/api/CHANGELOG.md
```

Expected: a `## Unreleased` heading, then `### Added` with several bullets (the most recent ending with the TRA-466 `keys:admin` entry), then `### Changed` with several bullets, then `### Fixed`.

If `### Added` or `### Changed` is empty for some reason, the new entries below are still appended to those headings — the headings always exist in `Unreleased` per the file's documented convention.

- [ ] **Step 2: Append two bullets to `## Unreleased → ### Added`**

Find the last bullet in the current `### Added` block and append immediately after it (preserving any blank line that separates `### Added` from `### Changed`):

```markdown
- `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` now accepts either the integer surrogate `id` or the UUID `jti` for `{keyID}` — both forms revoke the same key. Documented in [Authentication → Identifying a key](./authentication#identifying-a-key) ([TRA-501](https://linear.app/trakrf/issue/TRA-501), [TRA-504](https://linear.app/trakrf/issue/TRA-504)).
- Pagination envelope (`limit`, `offset`, `total_count`) added on `GET /api/v1/locations/{identifier}/{ancestors,children,descendants}`, `GET /api/v1/orgs/{id}/api-keys`, and `GET /api/v1/assets/{identifier}/history`. Every list endpoint now uses the standard envelope; the previous "non-paginated exceptions" carve-out on the [Pagination](./pagination-filtering-sorting) page has been removed ([TRA-503](https://linear.app/trakrf/issue/TRA-503), [TRA-504](https://linear.app/trakrf/issue/TRA-504)).
```

- [ ] **Step 3: Append two bullets to `## Unreleased → ### Changed`**

Find the last bullet in the current `### Changed` block and append immediately after:

```markdown
- API quickstart step 5 ("Mint an API key") now names the **Expires** picker, enumerates its options (Never / 30 days / 90 days / 1 year / Custom), and recommends 90 days as the production default ([TRA-449](https://linear.app/trakrf/issue/TRA-449), [TRA-504](https://linear.app/trakrf/issue/TRA-504)).
- [Errors](./errors) now documents the optional `params` object on `validation_error.fields[]` entries — field-specific constraint metadata such as `max_length`, `allowed_values`, `min`, `max`. The field has shipped for some time but was undocumented in the API reference ([TRA-504](https://linear.app/trakrf/issue/TRA-504)).
```

- [ ] **Step 4: Verify formatting**

```bash
pnpm typecheck && pnpm lint
```

Expected: both pass. If lint flags any line-length or formatting issues, run `pnpm exec prettier --write docs/api/CHANGELOG.md` and re-check.

- [ ] **Step 5: Commit**

```bash
git add docs/api/CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs(tra-504): changelog entries for sweep

Two Added entries (platform contract changes) and two Changed
entries (docs prose improvements on existing surface):

- Added: TRA-501 DELETE accepts id or jti
- Added: TRA-503 pagination envelope on five previously-bare endpoints
- Changed: quickstart step 5 names the Expires picker (TRA-449/504)
- Changed: errors.md documents validation_error.fields[].params (TRA-504)
EOF
)"
```

Expected: one commit added, one file changed (~4 lines added).

---

## Task 7: Final build smoke-test and open the PR

**Files:** none — verification + PR creation.

- [ ] **Step 1: Full build**

```bash
pnpm build
```

Expected: build succeeds. `docusaurus.config.ts` enables `onBrokenLinks: "throw"`, so any broken anchor (e.g., a stray reference to the removed `#non-paginated-exceptions`) fails the build. Any failure here is a real issue — read the message, fix the offending file, commit the fix as `fix(tra-504): <what>`, and re-run.

- [ ] **Step 2: Local smoke of the built bundle**

```bash
pnpm serve   # serves the built bundle at http://localhost:3000
```

Visit each of the modified pages and confirm they render correctly:

- `http://localhost:3000/docs/api/pagination-filtering-sorting` — no exceptions section, page reads cleanly from envelope into `## Pagination`.
- `http://localhost:3000/docs/api/authentication#identifying-a-key` — anchor scrolls to the new sub-section.
- `http://localhost:3000/docs/api/authentication#programmatic-key-rotation` — step 4's link to `#identifying-a-key` works.
- `http://localhost:3000/docs/api/quickstart` — step 5 reads cleanly with the picker enumeration.
- `http://localhost:3000/docs/api/errors#validation-errors` — JSON example shows `params`, table has four rows, paragraph reads cleanly.
- `http://localhost:3000/docs/api/changelog` — four new bullets appear under `Unreleased`.

`Ctrl-C` the server when done.

- [ ] **Step 3: Final branch state sanity-check**

```bash
git log --oneline main..HEAD
```

Expected: 7 commits, in this order (oldest at bottom):

```
<hash> docs(tra-504): changelog entries for sweep
<hash> chore(tra-504): verify items 3 & 4 (BASE_URL copy-paste, Postman collection)
<hash> docs(tra-504): document validation_error fields[].params
<hash> docs(tra-504): name expiry picker options in quickstart
<hash> docs(tra-504): explainer for api-key id vs jti identifiers
<hash> docs(tra-504): remove non-paginated exceptions, envelope is universal
57d728f docs(tra-504): design spec for docs nit sweep
a63c31e chore(api): sync spec from preview (post-TRA-501/503 deploy)
```

(8 total counting the two pre-existing commits — the task ordering is per-task, but the chronological commit order on the branch is whatever order the implementer ran the tasks. Tasks 1–4 + 5 + 6 cover the 6 new commits; the verification commit from Task 5 may chronologically interleave with the others depending on when the implementer chose to do the dev-server work.)

If item 3 hit Outcome B in Task 5, expect a 7th new commit between the prose edits and the chore commit: `docs(tra-504): make quickstart BASE_URL copy step explicit`.

- [ ] **Step 4: Push the branch**

```bash
git push -u origin miks2u/tra-504-docs-nit-sweep
```

Expected: branch pushed, upstream tracking set.

- [ ] **Step 5: Open the PR**

```bash
gh pr create --base main --title "docs(tra-504): nit sweep — expiry picker, error params, TRA-501/503 follow-ups" --body "$(cat <<'EOF'
## Summary

Six-item docs sweep consolidating BB9 (2026-04-24) findings + TRA-501 / TRA-503 deferred docs follow-ups (PRs #222 and #223 merged 2026-04-25).

- **Item 1:** quickstart step 5 names the **Expires** picker (Never / 30 days / 90 days / 1 year / Custom) and recommends 90 days for production.
- **Item 2:** `errors.md` documents the optional `validation_error.fields[].params` object.
- **Item 3:** verified — quickstart copy-paste path works post-TRA-467 (no docs change).
- **Item 4:** verified — Postman collection uses `{{baseUrl}}`, docs page lists both prod + preview values (no docs change).
- **Item 5:** removed the "non-paginated exceptions" carve-out on the pagination page; every list endpoint now envelopes uniformly per TRA-503. Prerequisite spec sync committed in `a63c31e`.
- **Item 6:** added "Identifying a key" sub-section to `authentication.md` explaining the integer `id` vs UUID `jti`; `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` accepts either form per TRA-501.

CHANGELOG entries for all four contract / docs deltas in the final commit.

## Test plan

- [ ] `pnpm build` passes (catches broken cross-references)
- [ ] Spot-check rendered pages via `pnpm serve` — pagination page, authentication, quickstart, errors, changelog all render correctly
- [ ] Item 3 verified via live curl against preview from rendered EnvBaseURLBlock + step-3 curl block
- [ ] Item 4 verified via grep of postman collection JSON + docs/api/postman.mdx

## Linear

Closes [TRA-504](https://linear.app/trakrf/issue/TRA-504).
EOF
)"
```

Expected: PR created, URL printed. Capture the URL for the response back to the user.

- [ ] **Step 6: Report**

Post a one-line summary: branch pushed, PR opened at `<URL>`, 7 commits (or 8 if Outcome B), all items addressed.

---

## Out of scope (per the Linear ticket — do NOT fold in)

- UI tooltips for scope dropdowns (BB9 finding #2 UI half) — different repo (`trakrf/platform`).
- HTTP rate-limit header case (`X-RateLimit-Limit` vs `x-ratelimit-limit`) — declared a non-bug; HTTP headers are case-insensitive per RFC 7230.
- `limit=0` minimum doc nit — current spec does not declare a `minimum` constraint, so the contract is unclear; let the next blackbox eval surface it if it actually matters to integrators.
