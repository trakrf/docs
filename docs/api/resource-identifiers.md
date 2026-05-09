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

### Numeric `id` is a surrogate key

Numeric `id` values are surrogate keys — unique within their entity type, not across types. The same integer can exist as both an asset id and a tag id; that's expected behavior. The API disambiguates by URL position (`/assets/{asset_id}`, `/locations/{location_id}/tags/{tag_id}`) or query-parameter name (`location_id`, `parent_id`), so an id is never passed without its entity context at the API boundary. Client code matches ids to entity type — standard surrogate-key discipline.

## Natural-key lookup uses `?external_key=`

When you have the natural key but not the canonical `id`, filter the list endpoint by `external_key`:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?external_key=SKU-7421-A"
```

The list envelope returns 0 or 1 matches in `data` (the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` caps live rows at one per key). An empty array is the miss signal — there is no `404` for a natural-key miss on this filter. Soft-deleted rows are not addressable through it; if you need to inspect a deleted record, look it up by `id`.

```bash
ASSET_ID=$(curl -sH "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?external_key=SKU-7421-A" \
     | jq -r '.data[0].id // empty')
[ -z "$ASSET_ID" ] && echo "no asset with that external_key"
```

The same shape is available on locations:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations?external_key=BACK-STORAGE-2"
```

Use the `?external_key=` filter when an integrator pastes an `external_key` directly (a barcode scan, a CSV row, an ERP record) and you need to resolve it to a TrakRF resource. Cache the returned `id` if you'll touch the resource again — subsequent path-param reads avoid the filter round trip.

Repeat the parameter to fetch any-of: `?external_key=SKU-A&external_key=SKU-B` returns up to one match per key (still capped by the live-row uniqueness rule), which is more efficient than N parallel single-key requests when you're resolving a batch.

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

When a resource references another resource, the response includes both forms as flat scalar fields. An asset response carries `location_id` (int) and `location_external_key` (string) side by side:

```json
{
  "data": {
    "id": 4287,
    "external_key": "SKU-7421-A",
    "name": "Pallet jack #14",
    "location_id": 42,
    "location_external_key": "BACK-STORAGE-2",
    "is_active": true,
    "created_at": "2026-03-12T17:04:00Z",
    "updated_at": "2026-04-29T09:21:00Z"
  }
}
```

Both fields are populated whenever the relationship exists — no nested object, no follow-up call to resolve the related resource's natural key. If you need the `id` for a downstream API call, it's there; if you need the `external_key` to write back to your system of record, it's there too. When the relationship is unset (an asset that has never been scanned, a root location with no parent), both fields are still **present in the response, set to `null`**. The OpenAPI spec declares them `nullable: true` and the service emits them on every response; clients should null-check, not key-presence-check.

That makes two response-shape behaviors that coexist on these resources, and it's worth knowing which is which:

| Behavior              | Fields                                                                                                                                     | Test for         |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------- |
| **Always present**    | `id`, `name`, `external_key`, `created_at`, `updated_at`, `is_active`, `valid_from` (and most scalars)                                     | the value itself |
| **Present as `null`** | `location_id`, `location_external_key`, `parent_id`, `parent_external_key`, `description`, `valid_to` (and other unset-but-emitted fields) | `field === null` |

Every field on `PublicAssetView` and `PublicLocationView` is **required** in the OpenAPI spec — generated SDKs will surface them as non-optional with a nullable type. Null-check, don't key-check. The same pattern holds on `report.PublicCurrentLocationItem` (`asset_deleted_at` is always present, `null` for live assets, populated for soft-deleted assets). When in doubt, check the field's documentation page — [Date fields](./date-fields) covers `valid_to`, this page covers FK pairs.

## Asset `metadata` vs. location `tags`: side-channel data {#asset-metadata-vs-location-tags}

`PublicAssetView` carries an open-ended `metadata` object (`additionalProperties: true`) for partner-side annotations the API does not interpret — a CRM record id, an ERP cost-center code, a partner SKU. Locations do **not** have a `metadata` field; the asymmetry is intentional for v1.

The pattern we recommend mirrors the schemas:

| Surface       | Where to put partner-side data                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Assets**    | `metadata` — free-form key/value, no schema, round-trips through `GET` → `PUT`.                  |
| **Locations** | `tags` — typed natural-key pairs (`tag_type`, `value`), enforced unique within the organization. |

Locations were not given an open `metadata` field because the practical "what would I stuff in here" use cases on a location (a CRM site id, a partner facility code) are already addressable through `tags` with a partner-defined `tag_type`. If you have a use case that genuinely needs schemaless side-channel data on a location, [contact us](mailto:support@trakrf.id) — same evaluation track as the v2 capability requests.

## Read shape vs. write shape

Request and response field _names_ match (e.g., `location_external_key` reads and writes under the same name), so the natural-key parts of a `PUT` round-trip without remapping. Read shape and write shape are not identical, though: read responses include fields that aren't part of the request schema — server-managed metadata (`id`, `created_at`, `updated_at`), derived fields (`tree_path`, `depth` on locations), and embedded sub-resources (`tags`). The exact set varies by resource.

The server **silently ignores** these read-only fields on `PUT`. A naive `GET` → mutate → `PUT` of the entire response object succeeds, so codegen-derived clients that re-send the full read shape don't have to strip first. The fields are flagged with `readOnly: true` in the OpenAPI spec; generated SDKs (typescript-fetch, openapi-generator) honor that marker and split read and write into distinct types, which keeps the request payload minimal at the type-system level.

Strict-unknown-field validation still applies for fields that are **not** declared on either the read or the write schema — a typo'd or off-resource field name returns `400 validation_error` with `fields[].field` naming the offender. See [Errors → Validation errors](./errors#validation-errors) for the envelope shape.

```bash
# Naive round-trip — the entire GET response is sent back; readOnly fields
# (id, created_at, updated_at, tags, ...) are silently ignored by the server.
curl -sH "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287" \
| jq '.data | .location_external_key = "PORTABLE-1437"' \
| curl -X PUT \
       -H "Authorization: Bearer $TRAKRF_API_KEY" \
       -H "Content-Type: application/json" \
       -d @- \
       "$BASE_URL/api/v1/assets/4287"
```

For a smaller request body — and for hand-rolled clients that want to be explicit about what they're updating — strip the read-only fields with `jq`:

```bash
# Smaller payload: drop the readOnly fields explicitly before PUT.
curl -sH "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287" \
| jq '.data | del(.id, .created_at, .updated_at, .tags)
       | .location_external_key = "PORTABLE-1437"' \
| curl -X PUT \
       -H "Authorization: Bearer $TRAKRF_API_KEY" \
       -H "Content-Type: application/json" \
       -d @- \
       "$BASE_URL/api/v1/assets/4287"
```

For assets the read-only set today is `id`, `created_at`, `updated_at`, and `tags`. For locations the set is larger: `id`, `created_at`, `updated_at`, `tree_path`, `depth`, and `tags`. The two location-specific additions (`tree_path`, `depth`) are derived ancestor metadata — see [Locations: `parent_id` and `parent_external_key`](#locations-parent_id-and-parent_external_key) below for what they describe.

Future resources may grow their own read-only fields. Don't memorize per-resource lists — derive them from the spec's `readOnly: true` markers, or rely on a generated client. The server's silent-ignore rule means existing clients keep working as the readOnly set grows.

Either form of the FK pair is accepted on write. Send `location_id` if you have it; send `location_external_key` if that's what the user typed. **Sending both is allowed when they agree** — the server cross-validates the pair and rejects disagreement (e.g., one set, the other `null`, or the two values pointing at different rows) with `400 invalid_value` and `detail: "location_id and location_external_key disagree"`. The same rule covers `parent_id` / `parent_external_key` on locations.

To **clear** a relationship, send `null` on either form (or both — they agree). The other writable-nullable fields work the same way: PUT `{"description": null}` clears the description; PUT `{"valid_to": null}` clears the expiry. Asset writable-nullables are `description`, `location_id`, `location_external_key`, `valid_to`; location writable-nullables are `description`, `parent_id`, `parent_external_key`, `valid_to`. After a clear, the field reads back as `null` (see [Always present vs. present-as-null](#foreign-key-fields-in-responses-come-as-flat-scalar-pairs) above; for `valid_to` specifically see [Date fields](./date-fields)).

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
    "tree_path": "warehouse_west.back_storage_2",
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

`tree_path` is a derived label-path helper, useful for sorting or indenting flat lists. Segments are joined by `.` and each segment is derived from the corresponding ancestor's `external_key` via two transformations: **lowercase** and **hyphen → underscore**. So an `external_key` of `WAREHOUSE-WEST` contributes the segment `warehouse_west` to its descendants' tree paths. The pattern on `external_key` (see [`external_key` value rules](#external_key-value-rules)) keeps `.` and `_` reserved for these roles, so `tree_path` is well-formed by construction. The transformation is still **lossy on case** — `WAREHOUSE-WEST` and `warehouse-west` are distinct `external_key`s but produce the same segment — so don't try to reverse it.

If you need ancestor `external_key`s (for breadcrumbs, parent lookups, or anything that touches your system of record), use `GET /api/v1/locations/{location_id}/ancestors` instead — it returns the full chain with each ancestor's untransformed `external_key`.

**Don't cache `tree_path`.** The value is derived, and renaming an `external_key` rewrites the `tree_path` on that location _and every descendant_ in one transaction. A client that pinned `tree_path` for hierarchy queries will silently desync after a rename. If you need stable hierarchy state, store the chain of `external_key`s (or the `id` chain via `/ancestors`) and re-derive on demand.

`tree_path` is also not an identifier — you can't look a location up by its `tree_path`. Use the [`?external_key=` filter](#natural-key-lookup-uses-external_key) on the locations list endpoint for natural-key lookups.

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

## `external_key` value rules {#external_key-value-rules}

`external_key` is constrained by the regex `^[A-Za-z0-9-]+$` — alphanumerics and hyphen only, length 1–255. The OpenAPI spec declares this `pattern` on every write schema (`POST` and `PUT` on assets and locations, plus the `*_external_key` foreign-key fields). Invalid input returns `400 validation_error` with `code: invalid_value`.

The reserved characters and why they're reserved:

| Character             | Reason it's reserved                                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `.` (period)          | `tree_path` segment separator                                                                                                   |
| `_` (underscore)      | segment-internal separator after `tree_path` normalization (each hyphen in `external_key` becomes an underscore in `tree_path`) |
| ` ` (space), `/`, `:` | URL-, log-, and path-hostile; reserved to avoid surprise quoting                                                                |

Practical examples:

| Value            | Verdict                                   |
| ---------------- | ----------------------------------------- |
| `SKU-7421-A`     | ✓ accepted                                |
| `BACK-STORAGE-2` | ✓ accepted                                |
| `MyAsset123`     | ✓ accepted (case is preserved on the key) |
| `BB With Spaces` | ✗ `400 invalid_value`                     |
| `BB/slash`       | ✗ `400 invalid_value`                     |
| `BB:colon`       | ✗ `400 invalid_value`                     |
| `BB.dotted`      | ✗ `400 invalid_value`                     |
| `BB_underscored` | ✗ `400 invalid_value`                     |
| `BB漢字`         | ✗ `400 invalid_value` (non-ASCII)         |

`external_key` is **case-preserving** on storage — `MyAsset` and `myasset` are distinct keys for uniqueness purposes — but `tree_path` lowercases every segment, so two location keys differing only in case will collide on `tree_path` even though they coexist as distinct rows. Pick a casing convention and stick to it.

## `is_active` is authoritative

Assets and locations carry both an `is_active` boolean and a pair of `valid_from` / `valid_to` timestamps. The API treats `is_active` as the source of truth for whether the resource is usable right now. `valid_from` and `valid_to` are informational metadata — the v1 service does not compute effective state from them.

Concretely: an asset with `is_active: true` and `valid_to: "2024-01-01T00:00:00Z"` (a `valid_to` already in the past) is still treated as active by the API. List filters on `is_active=true` will return it; the `?external_key=` filter will resolve it; `PUT`s will succeed.

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

There's no top-level `/api/v1/tags?value=...` discovery endpoint — tags are discovered through their parent resource, either embedded in an asset or location response or via `GET /api/v1/assets/{asset_id}/tags`.
