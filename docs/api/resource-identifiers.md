---
sidebar_position: 3
---

# Resource identifiers

Every asset and location has two identifiers, and both are first-class. The integer `id` is server-assigned, immutable, and used in URL paths, foreign-key fields, and response keys — the canonical handle for everything inside the API. The string `external_key` is your handle, and the natural key for joining TrakRF records back to your system of record (a SKU, an asset tag, a manufacturer serial number, an ERP code). Each form has its own access path; both are fluently supported. Pick whichever fits the context — neither is a fallback for the other.

## Path-param lookup uses `id`

Single-resource endpoints take the canonical integer `id`:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287"
```

This is the conventional REST shape and the URL stays valid even if the asset's `external_key` changes. Use it when you have an `id` already in hand — typically because you got it from a list response, a previous create, or a record cached in your own database.

## Natural-key lookup uses `/lookup?external_key=`

When you have the natural key but not the canonical `id`, look the resource up by its `external_key`:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/lookup?external_key=SKU-7421-A"
```

Returns the matching asset (`200`) or `404` if no live asset has that key. Equality match only — no globs, no prefix, no regex. Multiple natural-key parameters or none returns `400`. Soft-deleted rows are not addressable through this endpoint; if you need to inspect a deleted record, look it up by `id`.

The same shape is available on locations:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/lookup?external_key=BACK-STORAGE-2"
```

Use `/lookup` when an integrator pastes an `external_key` directly (a barcode scan, a CSV row, an ERP record) and you need to resolve it to a TrakRF resource. Cache the returned `id` if you'll touch the resource again — subsequent path-param reads avoid the `/lookup` round trip.

## List filters accept both forms

Where a list endpoint filters on a related resource, both forms work. For the assets list, filter by current location using either `location_id` or `location_external_key`:

```bash
# Canonical: filter by location id
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?location_id=42"

# Alternate: filter by location external_key
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?location_external_key=BACK-STORAGE-2"
```

Both parameters are repeatable (`?location_id=42&location_id=43`) and both return the standard paginated list envelope. See [Pagination, filtering, sorting](./pagination-filtering-sorting) for the full envelope shape.

## Foreign-key fields in responses come as flat scalar pairs

When a resource references another resource, the response includes both forms as flat scalar fields. An asset response carries `current_location_id` (int) and `current_location_external_key` (string) side by side:

```json
{
  "data": {
    "id": 4287,
    "external_key": "SKU-7421-A",
    "name": "Pallet jack #14",
    "current_location_id": 42,
    "current_location_external_key": "BACK-STORAGE-2",
    "is_active": true,
    "created_at": "2026-03-12T17:04:00Z",
    "updated_at": "2026-04-29T09:21:00Z"
  }
}
```

Both fields are populated whenever the relationship exists — no nested object, no follow-up call to resolve the related resource's natural key. If you need the `id` for a downstream API call, it's there; if you need the `external_key` to write back to your system of record, it's there too. When the relationship is unset (an asset that has never been scanned, a root location with no parent), both fields are still **present in the response, set to `null`**. The OpenAPI spec declares them `nullable: true` and the service emits them on every response; clients should null-check, not key-presence-check.

That makes three response-shape behaviors that coexist on these resources, and it's worth knowing which is which:

| Behavior               | Fields                                                                                                 | Test for                     |
| ---------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------- |
| **Always present**     | `id`, `name`, `external_key`, `created_at`, `updated_at`, `is_active`, `valid_from` (and most scalars) | the value itself             |
| **Present as `null`**  | `current_location_id`, `current_location_external_key`, `parent_id`, `parent_external_key`             | `field === null`             |
| **Omitted when unset** | `valid_to` (and any optional field documented as omit-when-unset on its individual page)               | key presence (`'k' in resp`) |

The omit-when-unset set is small and explicit. When in doubt, check the field's documentation page — [Date fields](./date-fields) covers `valid_to`, this page covers FK pairs, and any field not called out in either is in the always-present row.

## Read shape vs. write shape

Request and response field _names_ match (e.g., `current_location_external_key` reads and writes under the same name), so the natural-key parts of a `PUT` round-trip without remapping. Read shape and write shape are not identical, though: read responses include fields the server rejects on write — server-managed metadata (`id`, `created_at`, `updated_at`), derived fields (`path`, `depth` on locations), and embedded sub-resources (`tags`). The exact set varies by resource.

The general rule: **any field present in the GET response but not in the request schema is read-only and must be stripped before `PUT`.** A naive `GET` → mutate → `PUT` of the entire response object returns:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "unknown field 'id' in request body",
    "instance": "/api/v1/assets/4287",
    "request_id": "01J...",
    "fields": [
      {
        "field": "id",
        "code": "invalid_value",
        "message": "unknown field"
      }
    ]
  }
}
```

A naive PUT of every read-only field produces one `fields[]` entry per offending key — see [Errors → Validation errors](./errors#validation-errors) for the complete envelope shape.

For assets the read-only set today is `id`, `created_at`, `updated_at`, and `tags`. The minimal pattern with `jq`:

```bash
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
```

Locations have a larger read-only set (notably the derived `path` and `depth` in addition to the metadata fields), and future resources may have their own. Don't memorize per-resource lists — derive the strip set from the schema diff between the response object and the request body shape. In a generated TypeScript client with strict typing, the read response type and the write request type are distinct, so the compiler enforces the strip — there's no manual deletion to do. In a generated Python or Go client without strict input types, you'll need to pop the read-only fields explicitly before sending, or wrap the API in a typed model that excludes them at the call site.

Either form of the FK pair is accepted on write. Send `current_location_id` if you have it; send `current_location_external_key` if that's what the user typed. Don't send both for the same relationship in one request — the server validates them as mutually exclusive.

## Locations: `parent_id` and `parent_external_key`

Locations follow the same flat-scalar pattern for their parent reference. A location response includes both `parent_id` and `parent_external_key` whenever the location has a parent:

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

Set either `parent_id` or `parent_external_key` on create or update to nest under an existing parent. Root locations (no parent) carry both fields as `null`. They're never absent from the response — null-check, don't key-check.

`parent_id` and `parent_external_key` are one-hop only — they describe the immediate parent, not the chain to the root. For multi-hop traversal use the dedicated endpoint:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/42/ancestors"
```

`path` is a derived label-path helper, useful for sorting or indenting flat lists. Its segments are derived from each ancestor's `external_key` via two transformations: **lowercase** and **hyphen → underscore**. So an `external_key` of `WAREHOUSE-WEST` contributes the segment `warehouse_west` to its descendants' paths. The path is **not** guaranteed to round-trip back to `external_key` — splitting `path` on `.` is unreliable in general, and outright wrong if any ancestor's `external_key` contains a literal period (those pass through the transformation untouched and become indistinguishable from segment separators).

If you need ancestor `external_key`s (for breadcrumbs, parent lookups, or anything that touches your system of record), use `GET /api/v1/locations/{id}/ancestors` instead — it returns the full chain with each ancestor's untransformed `external_key`. Don't try to reverse the lowercasing or underscore substitution from `path`; the transformation is lossy on `external_key`s that already contain underscores or that differ only in case.

`path` is also not an identifier — you can't look a location up by its `path`. Use `GET /api/v1/locations/lookup?external_key=...` for natural-key lookups.

## Asset `external_key` is optional

`external_key` is required on locations but optional on assets. Omit it on `POST /api/v1/assets` and the server assigns one in the format `ASSET-NNNN` from a per-organization sequence:

```bash
# Caller-supplied external_key
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "Pallet jack #14", "external_key": "SKU-7421-A"}' \
     "$BASE_URL/api/v1/assets"

# Server-assigned external_key (returns external_key: "ASSET-0142" or similar)
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "Pallet jack #14"}' \
     "$BASE_URL/api/v1/assets"
```

A caller-supplied `external_key` that collides with an existing live asset returns `409 conflict`. Once an asset is soft-deleted its `external_key` becomes immediately available for reuse. Full create flows live in the [Quickstart](./quickstart).

## `is_active` is authoritative

Assets and locations carry both an `is_active` boolean and a pair of `valid_from` / `valid_to` timestamps. The API treats `is_active` as the source of truth for whether the resource is usable right now. `valid_from` and `valid_to` are informational metadata — the v1 service does not compute effective state from them.

Concretely: an asset with `is_active: true` and `valid_to: "2024-01-01T00:00:00Z"` (a `valid_to` already in the past) is still treated as active by the API. List filters on `is_active=true` will return it; `/lookup` will resolve it; `PUT`s will succeed.

If your business logic needs time-based filtering ("active and within its validity window"), apply that filter client-side. A computed `is_active_effective` field is on the v1.x roadmap if customer pain materializes; do not depend on the service deriving it today.

## Tags use a composite natural key

Tags follow the same principle as assets and locations, with a composite shape: a tag's natural key is the `(tag_type, value)` pair within an organization, enforced by the partial unique index `(org_id, tag_type, value) WHERE deleted_at IS NULL`. Inserting a duplicate live `(tag_type, value)` for the same organization returns `409 conflict`.

Tag responses still carry a canonical integer `id` for path-param access (e.g., `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`):

```json
{
  "data": {
    "id": 9183,
    "tag_type": "rfid",
    "value": "E2-8042-2D-19F0-AB10",
    "is_active": true
  }
}
```

There's no top-level `/api/v1/tags/lookup` endpoint — tags are discovered through their parent resource, either embedded in an asset or location response or via `GET /api/v1/assets/{id}/tags`.
