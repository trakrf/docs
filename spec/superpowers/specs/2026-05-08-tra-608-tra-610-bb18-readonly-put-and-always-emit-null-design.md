---
ticket: TRA-608, TRA-610
parent: TRA-607
date: 2026-05-08
status: design
---

# TRA-608 + TRA-610 — BB18 §1.7 + §1.8 — readOnly-tolerant PUT + always-emit description/valid_to — design

## Goal

Catch trakrf-docs up to platform PR #274 (merged as `85f1145`). Two coupled BB18 fixes shipped:

1. **§1.7 (TRA-608)** — server now silently ignores readOnly fields on `PUT /api/v1/{assets,locations}/{id}`. Naive `GET → mutate → PUT` of the entire response object succeeds with `200`. Strict-unknown-field still applies for typo'd / off-resource fields.
2. **§1.8 (TRA-610)** — `description`, `valid_to` (assets + locations) and `updated_at` (locations only) are now always emitted as `null` when unset, with `nullable: true` + required in the spec. Adjacent fix: `report.PublicCurrentLocationItem.asset_deleted_at` follows the same flip.

The trakrf-docs repo currently teaches the **opposite** rule on both fronts:

- `docs/api/resource-identifiers.md` "Read shape vs. write shape" tells integrators they **must** strip readOnly fields before `PUT` and shows the `400 validation_error` they'd otherwise get. That guidance is now wrong — the server tolerates the fields.
- `docs/api/resource-identifiers.md` table classifies `description` and `valid_to` as "Omitted when unset", and `docs/api/date-fields.md` doubles down with "Absent key = no expiry" and "the API never returns `valid_to: null`". Both are now wrong — the server emits `null`.
- `docs/getting-started/api.mdx` example response for `/api/v1/locations/current` omits `asset_deleted_at` entirely. Should include `"asset_deleted_at": null` to match always-emit shape.

## Scope

### 1. OpenAPI spec refresh

`bash scripts/refresh-openapi.sh` against `platform@main` (resolves to `85f1145`). Picks up the `nullable: true` + `required` flips on the three views and the regenerated Postman collection. Single `chore(api):` commit, reviewable independently from prose.

### 2. `docs/api/resource-identifiers.md`

Two coupled rewrites:

**Behavior table (lines 92–100)** — drop `description` and `valid_to` from the "Omitted when unset" row. With these moved to always-present-null on assets and locations, the row is empty for the resource-identifiers page's scope; collapse to a brief footnote rather than an empty table row. Update the surrounding prose to name the always-present-null fields explicitly.

**"Read shape vs. write shape" section (lines 102–147)** — fundamentally rewrite. Replace the "must be stripped" rule and `400 validation_error` example with:

- The server silently ignores readOnly fields on `PUT`, so a naive `GET → mutate → PUT` round-trip works without preprocessing.
- Strict-unknown-field still applies — typo'd or off-resource fields still return `400 validation_error` with `fields[]` naming the offender. Link to errors page.
- The `del()` jq snippet stays as an **optional** smaller-payload pattern, not a required strip. Reframe the "minimal pattern" framing.
- Generated SDKs (typescript-fetch, openapi-generator) still split read and write types via `readOnly: true` markers; that's still the cleanest path for codegen consumers. Hand-rolled clients no longer need the explicit pop step.

### 3. `docs/api/date-fields.md`

The whole page assumes `valid_to` is omit-when-unset. Update:

- Table row for `valid_to`: "No — omitted when unset" → "Yes — `null` when unset".
- The "never returns null" claim (line 16) — flip to "always emits `null` when unset".
- "Test for the key's presence, not its value" prose (line 42) — replace with null-check guidance.
- Two response examples (lines 22–40, 71–82) — show `"valid_to": null` rather than absent key.
- "API omits `valid_to` because the asset has no expiry" (line 82) — flip to "emits `valid_to: null`".

### 4. `docs/getting-started/api.mdx`

Add `"asset_deleted_at": null` to the example response item on lines 51–66. The accompanying prose doesn't currently mention `asset_deleted_at` so no other change.

## Out of scope

- **`PUT /api/v1/orgs/{id}` and tag POST**: per the platform PR audit, these endpoints already silently accept unknown fields (different / looser contract). Not the BB18 §1.7 surface and no docs claim today contradicts the new state. No change.
- **Per-resource read-only field lists** (`id`, `created_at`, `updated_at`, `tags`, `tree_path`, `depth`): these still exist and the spec still marks them `readOnly: true`. The lists in the resource-identifiers page stay accurate as informational — what changes is the framing (optional strip vs. required strip), not the lists themselves.
- **TRA-587 historical context**: that ticket landed Option A (strict reject of readOnly fields). TRA-608 supersedes it with Option B (silent ignore). The Option-A-was-the-fallback prose history doesn't need a callout — the docs just need to teach the current rule.
- **API CHANGELOG entry**: pre-launch (v1 not yet released). Per project memory, fix the state, don't backfill changelog entries before launch.

## Acceptance

- `static/api/platform-meta.json` records `platform@85f1145`.
- `pnpm build` passes with no broken-link warnings.
- `grep -n "must be stripped before" docs/api/resource-identifiers.md` returns no hits.
- `grep -n "omitted when unset" docs/api/` returns no hits naming `description` or `valid_to` on asset/location pages.
- `docs/api/date-fields.md` no longer contains the "API never returns null" claim for `valid_to`.
- `docs/getting-started/api.mdx` example response for `/locations/current` includes `"asset_deleted_at": null`.
- TRA-608 and TRA-610 moved to Done after merge.
