# TRA-608 + TRA-610 BB18 §1.7 + §1.8 — readOnly-tolerant PUT + always-emit description/valid_to — Implementation Plan

**Goal:** Catch trakrf-docs up to platform PR #274. Two coupled rewrites in `resource-identifiers.md` + a date-fields rewrite + one example-response touch-up + spec refresh.

**Architecture:** Five sequential commits on a feature branch — design + plan + spec refresh + prose edits + example-response touch-up. Verification is `pnpm build`.

**Tech Stack:** Docusaurus 3.9, pnpm. No backend code.

---

## File Structure

| File | Change |
| --- | --- |
| `spec/superpowers/specs/2026-05-08-tra-608-tra-610-bb18-readonly-put-and-always-emit-null-design.md` | Written, committed in Task 1 |
| `spec/superpowers/plans/2026-05-08-tra-608-tra-610-bb18-readonly-put-and-always-emit-null.md` | This file, committed in Task 2 |
| `static/api/openapi.json` | Refreshed (3 views: nullable+required flips) |
| `static/api/openapi.yaml` | Refreshed |
| `static/api/trakrf-api.postman_collection.json` | Regenerated |
| `static/api/platform-meta.json` | Bumped to `platform@85f1145` |
| `docs/api/resource-identifiers.md` | Rewrite "Read shape vs. write shape"; flip behavior table for `description` / `valid_to` |
| `docs/api/date-fields.md` | Flip `valid_to` from omit-when-unset to always-emit-null |
| `docs/getting-started/api.mdx` | Add `"asset_deleted_at": null` to `/locations/current` example response |

---

### Task 1: Commit the design doc

```bash
git add spec/superpowers/specs/2026-05-08-tra-608-tra-610-bb18-readonly-put-and-always-emit-null-design.md
git commit -m "docs(spec): TRA-608+TRA-610 BB18 §1.7+§1.8 design — readOnly-tolerant PUT + always-emit description/valid_to"
```

### Task 2: Commit this plan

```bash
git add spec/superpowers/plans/2026-05-08-tra-608-tra-610-bb18-readonly-put-and-always-emit-null.md
git commit -m "docs(plan): TRA-608+TRA-610 BB18 §1.7+§1.8 plan — readOnly-tolerant PUT + always-emit description/valid_to"
```

### Task 3: Commit the spec refresh

Files refreshed by `bash scripts/refresh-openapi.sh` against `platform@85f1145`:

- `static/api/openapi.json` — `description`, `valid_to` flipped to `nullable: true` + `required` on `asset.PublicAssetView` and `location.PublicLocationView`; `updated_at` same flip on `location.PublicLocationView`; `asset_deleted_at` same flip on `report.PublicCurrentLocationItem`.
- `static/api/openapi.yaml` — same.
- `static/api/trakrf-api.postman_collection.json` — regenerated.
- `static/api/platform-meta.json` — SHA bump to `85f1145`.

```bash
git add static/api/openapi.json static/api/openapi.yaml static/api/trakrf-api.postman_collection.json static/api/platform-meta.json
git commit -m "chore(api): refresh openapi spec from platform main (TRA-608+TRA-610)"
```

### Task 4: Prose edits (single commit)

**`docs/api/resource-identifiers.md`:**

- Behavior table (lines 92–100): drop `description`, `valid_to` from "Omitted when unset" row; collapse the row or note it's empty for asset/location scope; update following prose to name them as always-present-null fields.
- "Read shape vs. write shape" (lines 102–147): rewrite to teach silent-ignore-on-PUT instead of strict-reject. Drop the `400 validation_error` example. Reframe the `del()` jq snippet as optional smaller-payload, not required strip. Keep the per-resource readOnly field lists (still in the spec, still useful for codegen consumers).

**`docs/api/date-fields.md`:**

- Table row for `valid_to`: "No — omitted when unset" → "Yes — `null` when unset".
- "API never returns `valid_to: null`" claim (line 16): flip.
- Two response examples (lines 22–40, 71–82): show `"valid_to": null` for the no-expiry case.
- "Test for the key's presence" prose (line 42) and "API omits `valid_to`" prose (line 82): replace with null-check guidance.

**`docs/getting-started/api.mdx`:**

- Lines 51–66: add `"asset_deleted_at": null` to the example response item.

Verify:

- `grep -n "must be stripped before" docs/api/resource-identifiers.md` → 0 hits.
- `grep -n "never returns.*null" docs/api/date-fields.md` → 0 hits (or rephrased so it's no longer wrong).
- `grep -n "omitted when unset" docs/api/resource-identifiers.md docs/api/date-fields.md` → 0 hits naming `description`/`valid_to`.
- `grep -n "asset_deleted_at" docs/getting-started/api.mdx` → 1 hit.

```bash
git add docs/api/resource-identifiers.md docs/api/date-fields.md docs/getting-started/api.mdx
git commit -m "docs(api): readOnly-tolerant PUT + always-emit description/valid_to/asset_deleted_at (TRA-608+TRA-610)"
```

### Task 5: Verify build

```bash
pnpm build
```

Must succeed with no broken-link warnings.

### Task 6: Push and open PR

```bash
git push -u origin miks2u/tra-608-tra-610-bb18-readonly-put-and-always-emit-null
gh pr create --title "docs(api): TRA-608+TRA-610 BB18 §1.7+§1.8 — readOnly-tolerant PUT + always-emit description/valid_to" --body "..."
```

---

## Acceptance

- `pnpm build` passes.
- `static/api/platform-meta.json` records `platform@85f1145`.
- Resource-identifiers page no longer says readOnly fields "must be stripped" before `PUT`.
- Date-fields page no longer says the API never returns `null` for `valid_to`.
- `/locations/current` example response on the getting-started page includes `"asset_deleted_at": null`.
- PR opened against `main`.
