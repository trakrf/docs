# TRA-504 — Docs nit sweep: expiry picker, error params, BASE_URL/Postman verification, TRA-501/503 follow-ups

**Status:** Design approved 2026-04-25
**Linear:** [TRA-504](https://linear.app/trakrf/issue/TRA-504)
**Branch:** `miks2u/tra-504-docs-nit-sweep` (worktree at `.worktrees/tra-504-docs-nit-sweep`)

## Problem

BB9 (eval run 2026-04-24, post PR #43 merge) and CC's docs review surfaced six small docs gaps. Two of those six (items 5 and 6) document customer-facing changes shipped platform-side in PRs #222 (TRA-503, pagination envelope) and #223 (TRA-501, id↔jti DELETE accept), both merged 2026-04-25. The platform team intentionally deferred customer-facing docs per the "ship docs behind backend reality" rule (gates on **preview deploy**, since BB testing runs against preview — not on prod deploy).

This sweep consolidates all six items into a single PR.

## Approach

Verify-first, edit-after, on a single feature branch in a worktree, with one commit per item.

A prerequisite spec sync was committed first — at design time, the synced OpenAPI spec at `static/api/openapi.json` was one day stale (sync `9940a5d` → `platform@20e209e` on 2026-04-24, while TRA-503 PR #222 merged 2026-04-25). `scripts/refresh-openapi.sh` was run; jq inspection confirmed all five endpoints touched by TRA-503 now carry the full envelope (`data, limit, offset, total_count`). The refresh was committed as `chore(api): sync spec from preview (post-TRA-501/503 deploy)` (commit `a63c31e`).

Sequence after the prerequisite:

1. Verify items 3 (BASE_URL copy-paste) and 4 (Postman collection) — likely both close as no-change.
2. Doc edits for items 1, 2, 5, 6.
3. CHANGELOG entries last, in a single commit.

Total: **1 prereq sync + 4 doc edits + 1 verification chore + 1 changelog = 7 commits, single PR.** (Item 3 grows to a 5th doc edit if its verification reproduces the empty-host failure — see Risks.)

## Per-item design

### Item 1 — Quickstart: name the expiry picker

**File:** `docs/api/quickstart.mdx`, step 5 of "Mint an API key" (~line 36).

**Current state:** Step 5 already mentions expiry briefly: _"Set an expiration. Leaving the expiry field blank mints a permanent credential — fine for a throwaway local-dev key, but for anything shared or long-lived, pick a date (e.g. 90 days)..."_ It does not name the picker, enumerate options, or strongly recommend a default.

**Change:** Rewrite step 5 to:

- Name the form field ("**Expires**" picker).
- Enumerate the picker options: **Never / 30 days / 90 days / 1 year / Custom**.
- Recommend **90 days** as the default for production keys (rotation cadence aligned with quarterly secrets review).
- Cross-reference [Authentication → Key lifecycle](./authentication#key-lifecycle), where TRA-449's no-expiry security warning lives.

**Commit:** `docs(tra-504): name expiry picker options in quickstart`

### Item 2 — Errors: document `validation_error.fields[].params`

**File:** `docs/api/errors.md`, validation-errors section (~lines 65–98).

**Current state:** The validation-error envelope documents `field`, `code`, and `message` on `fields[]` entries. The `params` object is shipped by the platform (e.g. `{"allowed_values":["asset","person","inventory"]}` on `invalid_value`, `{"max_length":255}` on `too_long`) but undocumented. The CHANGELOG already references it under TRA-466 ("validation errors on unknown values return the allowed set in the `fields[].params` object"); this sweep documents it formally in the API reference.

**Change:**

- (a) Add `"params": {"max_length": 255}` to the `too_long` entry in the JSON example at lines 65–77.
- (b) Add a fourth row to the field-entries table at line 83: `params` — _Optional. Field-specific constraint metadata. Schema varies per field; treat unknown keys gracefully._
- (c) After the `code` enum bullet list (~line 96), add one short paragraph: _"Some entries also include a `params` object carrying constraint metadata (e.g. `max_length`, `allowed_values`, `min`, `max`). The keys are field-specific — don't expect a fixed schema; treat unknown keys gracefully."_

**Commit:** `docs(tra-504): document validation_error fields[].params`

### Item 3 — Verify: quickstart copy-paste path post-TRA-467

**Verification only.** Likely closes as no-change.

**Pre-existing state:** TRA-467 added `<EnvBaseURLBlock />` (`src/components/EnvBaseURLBlock.tsx`), which renders `<pre><code>export BASE_URL=${appHost}</code></pre>` with the env-matching app host substituted at render time. The quickstart uses this block in step 1 (line 26), and subsequent curl examples reference `$BASE_URL/api/v1/...`. A literal copy-paste of the rendered block + a curl block should produce a working request.

**Verification procedure:**

1. `pnpm dev` (in worktree).
2. Open `http://localhost:3000/docs/api/quickstart` in browser.
3. Copy the rendered `export BASE_URL=...` line into a real shell.
4. Copy the step 3 curl block (`curl -H "Authorization: Bearer $TRAKRF_API_KEY" "$BASE_URL/api/v1/locations/current"`) into the same shell with a valid `TRAKRF_API_KEY` exported.
5. Confirm the request reaches the API (any HTTP status with a body, including 401, proves the host substituted; an empty/connection-refused response proves it didn't).

**Outcome A (verified intact):** record in the chore commit, no docs change.

**Outcome B (still broken):** add explicit prose before the EnvBaseURLBlock at line 26: _"First, copy this into your shell:"_ — and re-test. This becomes its own commit `docs(tra-504): make quickstart BASE_URL copy step explicit`.

### Item 4 — Verify: Postman collection link

**Verification only.** Inspection already done; closes as no-change.

**Findings:**

- `static/api/trakrf-api.postman_collection.json` uses `{{baseUrl}}` collection variable throughout — no hardcoded host.
- `docs/api/postman.mdx:31` documents both prod (`https://app.trakrf.id/api/v1`) and preview (`https://app.preview.trakrf.id/api/v1`) baseUrl values, plus instructions for setting `apiKey`.

**Action:** Record verification in the chore commit.

### Item 3 + 4 — Combined verification chore commit

**Commit:** `chore(tra-504): verify items 3 & 4 (BASE_URL copy-paste, Postman collection)`

Commit body documents both verifications (procedure run, observed result, conclusion). No file changes.

### Item 5 — Pagination: remove non-paginated exceptions

**File:** `docs/api/pagination-filtering-sorting.md`, section `### Non-paginated list exceptions {#non-paginated-exceptions}` (lines 32–48).

**Verification (already done at design time, post-spec-sync):** The five endpoints touched by TRA-503 — `/api/v1/locations/{identifier}/{ancestors,children,descendants}`, `/api/v1/orgs/{id}/api-keys`, `/api/v1/assets/{identifier}/history` — all return the full envelope (`data, limit, offset, total_count`) in the post-sync spec. Their schemas now resolve via `internal_handlers_locations.{ListAncestors,ListChildren,ListDescendants}Response`, `internal_handlers_orgs.ListAPIKeysResponse`, `internal_handlers_reports.AssetHistoryResponse`.

**Change:**

- **Delete** the entire `### Non-paginated list exceptions` section (lines 32–48). The `Every list endpoint returns the same envelope` claim at line 12 then stands without exception.
- Search the rest of `docs/` for any links to `#non-paginated-exceptions` (`grep -rn 'non-paginated-exceptions' docs/`) and remove or rewrite them. Likely none.

**Commit:** `docs(tra-504): remove non-paginated exceptions, envelope is universal`

### Item 6 — Authentication: id vs jti explainer

**File:** `docs/api/authentication.md`, before `## Programmatic key rotation` (insert ~line 116, after the Key lifecycle bullets).

**Change:** Add a new H3 sub-section under **Key lifecycle** titled `### Identifying a key {#identifying-a-key}` with three points:

1. Each API key has two identifiers: an integer `id` (surrogate, present in list responses from `GET /api/v1/orgs/{id}/api-keys`) and a UUID `jti` (visible in the JWT `sub` claim and displayed in the web UI's API Keys page).
2. `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` accepts either form for `{keyID}` — the integer surrogate or the UUID.
3. Recommend `jti` for human-readable scripts and audit trails: it's stable, visible everywhere (UI, JWT, API responses), and self-describing as a UUID.

Update the rotation-workflow step 4 at line 126 (`DELETE /api/v1/orgs/{id}/api-keys/{keyID}`) to link the `{keyID}` placeholder to the new `#identifying-a-key` section so the customer can see the choice in context.

**Commit:** `docs(tra-504): explainer for api-key id vs jti identifiers`

### CHANGELOG

**File:** `docs/api/CHANGELOG.md`, `## Unreleased` section.

**Single final commit** adds entries (categorized by impact: platform contract additions under "Added", docs prose improvements under "Changed"):

- **Added:**
  - `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` now accepts either the integer surrogate `id` or the UUID `jti` for `{keyID}`. Documented in [Authentication → Identifying a key](./authentication#identifying-a-key). References TRA-501 and TRA-504.
  - Pagination envelope (`limit`, `offset`, `total_count`) added on `GET /api/v1/locations/{id}/{ancestors,children,descendants}`, `/api/v1/orgs/{id}/api-keys`, and `/api/v1/assets/{id}/history`. Every list endpoint now uses the standard envelope. References TRA-503 and TRA-504.
- **Changed:**
  - Quickstart step 5 now names the **Expires** picker, enumerates its options (Never / 30 days / 90 days / 1 year / Custom), and recommends 90 days for production keys. References TRA-449 and TRA-504.
  - [Errors](./errors) now documents the optional `params` object on `validation_error.fields[]` entries (constraint metadata such as `max_length`, `allowed_values`, `min`, `max`). References TRA-504.

**Commit:** `docs(tra-504): changelog entries for sweep`

## Verification

**Per-commit:**

- `pnpm typecheck && pnpm lint` after each doc-edit commit.

**Final:**

- `pnpm build` to catch broken cross-references (especially the `#non-paginated-exceptions` anchor removal in item 5).
- Smoke-test the rendered build at `pnpm serve`.

## Acceptance

Mirrors the Linear ticket's acceptance list:

1. Quickstart step 5 names the expiry field, lists picker options, recommends 90 days.
2. `errors.md` documents `params` on `fields[]` entries with example.
3. Quickstart copy-paste path verified intact (or fixed with explicit prose).
4. Postman collection verified parameterized.
5. Pagination page reflects envelope-everywhere; exception section removed; OpenAPI spec confirmed to match.
6. id vs jti explainer added under Key lifecycle.
7. CHANGELOG `Unreleased` updated with all four entries.
8. PR opened against `main` from `miks2u/tra-504-docs-nit-sweep`.

## Risks / unknowns

- **BB-original copy-paste failure:** if the verification in item 3 reproduces the empty-host result (i.e. EnvBaseURLBlock isn't actually rendering / isn't copyable), item 3 grows from a verification chore into a quickstart prose commit.
- **Spec rename downstream effects:** the prerequisite sync renamed several response schemas (e.g., `locations.LocationHierarchyResponse` → `internal_handlers_locations.ListAncestorsResponse`). The interactive `/api` reference is regenerated from the spec at build time, so this should be transparent to readers — but verify with `pnpm build` that the rendered reference page still works and nothing in `docs/` hardcoded the old schema names.

## Out of scope

Per the Linear ticket:

- UI tooltips for scope dropdowns (BB9 finding #2 UI half).
- HTTP rate-limit header case nit (`X-RateLimit-Limit` vs `x-ratelimit-limit` — HTTP is case-insensitive).
- `limit=0` minimum doc nit (fold into next docs sweep if it survives).

## References

- [TRA-449](https://linear.app/trakrf/issue/TRA-449) — key expiry security warning (item 1 builds on it)
- [TRA-467](https://linear.app/trakrf/issue/TRA-467) — base URL env auto-detect (item 3 verifies it)
- [TRA-501](https://linear.app/trakrf/issue/TRA-501) — id↔jti DELETE accept (item 6 documents it; PR #223 merged 2026-04-25)
- [TRA-503](https://linear.app/trakrf/issue/TRA-503) — pagination envelope everywhere (item 5 documents it; PR #222 merged 2026-04-25)
- BB9 [FINDINGS.md](http://FINDINGS.md) findings #5 and #8 (eval run 2026-04-24)
