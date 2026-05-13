# TRA-701 — Writable-fields comment matches spec (BB32 D1)

**Linear:** [TRA-701](https://linear.app/trakrf/issue/TRA-701/quickstart-writable-fields-comment-lists-4-fields-spec-declares-6-bb32) (child of TRA-700, BB32 findings)
**Scope:** docs-only; no platform changes.

## Problem

The minimal-PATCH example in `docs/api/resource-identifiers.md` carries a code comment enumerating asset writable fields. The list is missing two fields — `is_active` and `valid_from` — that the spec's `UpdateAssetRequest` declares and the live service accepts. Integrators reading the prose understate the writable surface by a third.

Current state (`docs/api/resource-identifiers.md:253`):

```bash
# Minimal PATCH: only the field being changed. Omitted fields stay as-is.
# Asset writable fields: name, description, valid_to, metadata.
```

Per `static/api/openapi.yaml`:

- `UpdateAssetRequest`: `name, description, is_active, metadata, valid_from, valid_to` (6 fields)
- `UpdateLocationRequest`: `name, description, is_active, parent_id, valid_from, valid_to` (6 fields; no `metadata`)

The acceptance criterion calls out **each PATCH-targeted resource**; the section's current single-resource enumeration does not name location's writable surface at all.

## Non-problems

- The writable-nullables sentence later in the same section (`description`, `valid_to` for assets; `description`, `parent_id`, `valid_to` for locations) already matches the spec — no drift there.
- `quickstart.mdx`'s PATCH example deliberately does not enumerate writable fields; it links to this section. Touching it would create a second drift surface for future schema additions.

## Fix

Replace the single-resource comment line with a two-line enumeration covering both PATCH-targeted resources. Keep the curl example unchanged (still PATCH on an asset).

Before:

```bash
# Minimal PATCH: only the field being changed. Omitted fields stay as-is.
# Asset writable fields: name, description, valid_to, metadata.
curl -X PATCH \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/merge-patch+json" \
     -d '{"description": "back-stockroom shelf 3, bin B"}' \
     "$BASE_URL/api/v1/assets/4287"
```

After:

```bash
# Minimal PATCH: only the field being changed. Omitted fields stay as-is.
# Asset writable fields:    name, description, is_active, metadata, valid_from, valid_to.
# Location writable fields: name, description, is_active, parent_id, valid_from, valid_to.
curl -X PATCH \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/merge-patch+json" \
     -d '{"description": "back-stockroom shelf 3, bin B"}' \
     "$BASE_URL/api/v1/assets/4287"
```

Aligned column makes the asset/location set difference (`metadata` vs `parent_id`) immediately legible.

## Out of scope

- A parallel curl example for `PATCH /locations/{id}`. The contract is identical; a duplicate code block adds bytes without adding signal.
- Restructuring the enumeration into a table. Two six-item sets read fine inline.
- Touching `docs/api/quickstart.mdx`. The PATCH example there is intentionally minimal and points at this section.

## Acceptance

- [x] Comment enumerates all six asset writable fields.
- [x] Comment enumerates all six location writable fields.
- [x] Field lists match `UpdateAssetRequest` / `UpdateLocationRequest` in the current OpenAPI spec mirror.
- [x] No changes outside `docs/api/resource-identifiers.md`.
