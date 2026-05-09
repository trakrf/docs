---
sidebar_position: 3
---

# Resource identifiers

Every asset and location has two identifiers. The integer `id` is **canonical at the URL surface** — server-assigned, immutable, and the form path-param routes and foreign-key fields use. The string `external_key` is **canonical for partner-side joins** — your handle, the natural key for tying a TrakRF record to a row in your system of record (a SKU, an asset tag, a manufacturer serial number, an ERP code). Both are durable; both round-trip on every response; neither is a fallback for the other. They are not equivalent, though: an `id` is unique to TrakRF storage and meaningless outside it; an `external_key` is yours and is the only form your warehouse software, ERP, or operator will recognize. Pick the form the next system over recognizes.

## String-handle concepts at a glance

Three string-handle concepts appear across these resources, and they show up close enough together to blur. Briefly:

- **`external_key`** — the resource's own natural key (this page, top-to-bottom).
- **`*_external_key` foreign-key fields** — flat-scalar references _to_ another resource's `external_key` from a record that holds the relationship. Examples: `location_external_key` on assets, `parent_external_key` on locations. Covered under [Foreign-key fields in responses](#foreign-key-fields-in-responses-come-as-flat-scalar-pairs).
- **`tree_path`** — a derived label-path on locations only, useful for sorting / breadcrumbs / indenting flat lists. Not an identifier and not a natural key. Covered under [Locations: `parent_id` and `parent_external_key`](#locations-parent_id-and-parent_external_key).

The first two are partner-supplied and write-routable; the third is server-derived and read-only. The asymmetry is deliberate.

**Character set.** `external_key` (and every `*_external_key` foreign-key field) is constrained to alphanumerics and the hyphen — `^[A-Za-z0-9-]+$`, length 1–255. Underscore, period, slash, colon, and whitespace are reserved. See [`external_key` value rules](#external_key-value-rules) for the full table and the rationale for each reserved character.

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

Every field on `PublicAssetView` and `PublicLocationView` is **required** in the OpenAPI spec — generated SDKs will surface them as non-optional with a nullable type. Null-check, don't key-check. The same pattern holds on `report.PublicCurrentLocationItem`. When in doubt, check the field's documentation page — [Date fields](./date-fields) covers `valid_to`, this page covers FK pairs and the soft-delete model (below).

### Soft-delete is not a general field {#soft-delete-visibility}

Soft-deleted records drop out of list responses entirely — every list endpoint applies a `WHERE deleted_at IS NULL` predicate at the storage layer, and the API surface mirrors it. There is no general `deleted_at` field on assets, locations, or tags on the public surface.

`asset_deleted_at` is the one exception, and it's narrowly scoped: it appears **only** on `report.PublicCurrentLocationItem` (the row shape returned by `GET /api/v1/locations/current`), and **only** when the request includes `?include_deleted=true`. Without that flag, deleted assets don't appear in the response at all and the field is absent from the row. With the flag, the field is always present — `null` for live assets, populated with the deletion timestamp for soft-deleted ones. This is the dedicated path for "show me what's been retired in this report."

The other inspection path for a soft-deleted asset is the path-param read by `id` (`GET /api/v1/assets/{asset_id}`). It returns the record without a `*_deleted_at` field — the path-param read doesn't apply the currently-effective predicate (covered under [Effective dating and `is_active`](#effective-dating-and-is-active)) and doesn't surface the deletion timestamp either. If you need the deletion timestamp for a non-locations-current resource, the API doesn't expose one today.

## Asset `metadata` vs. location `tags`: side-channel data {#asset-metadata-vs-location-tags}

`PublicAssetView` carries an open-ended `metadata` object (`additionalProperties: true`) for partner-side annotations the API does not interpret — a CRM record id, an ERP cost-center code, a partner SKU. Locations do **not** have a `metadata` field; the asymmetry is intentional for v1.

On write, `metadata` must be a JSON object. Scalars, arrays, and booleans (e.g. `"metadata": "x"`, `"metadata": [1, 2]`, `"metadata": true`) are rejected at the validator boundary with `400 validation_error` / `invalid_value`. The `additionalProperties: true` declaration governs what's allowed _inside_ the object; the wrapper itself is type-restricted.

The pattern we recommend mirrors the schemas:

| Surface       | Where to put partner-side data                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Assets**    | `metadata` — free-form key/value, no schema, round-trips through `GET` → `PUT`.                  |
| **Locations** | `tags` — typed natural-key pairs (`tag_type`, `value`), enforced unique within the organization. |

Locations were not given an open `metadata` field because the practical "what would I stuff in here" use cases on a location (a CRM site id, a partner facility code) are already addressable through `tags` with a partner-defined `tag_type`. If you have a use case that genuinely needs schemaless side-channel data on a location, [contact us](mailto:support@trakrf.id) — same evaluation track as the v2 capability requests.

## Read shape vs. write shape

Request and response field _names_ match (e.g., `location_external_key` reads and writes under the same name), so the natural-key parts of a `PUT` round-trip without remapping. Read shape and write shape are not identical, though: read responses include fields that aren't part of the request schema — server-managed metadata (`id`, `created_at`, `updated_at`), derived fields (`tree_path`, `depth` on locations), and embedded sub-resources (`tags`). The exact set varies by resource.

The server **silently ignores** these read-only fields on `PUT`. A naive `GET` → mutate → `PUT` of the entire response object succeeds, so codegen-derived clients that re-send the full read shape don't have to strip first. The fields are flagged with `readOnly: true` in the OpenAPI spec; generated SDKs (typescript-fetch, openapi-generator) honor that marker and split read and write into distinct types, which keeps the request payload minimal at the type-system level.

A request body that resolves to **no writable fields** — `{}`, or a body containing only readOnly fields like `{"id":999}`, `{"created_at":"…"}`, or `{"tags":[]}` — returns `200` with the unchanged record. A verbatim `GET` → `PUT` round-trip with no edits in between is a legal no-op, not an error, so a "save" button that re-PUTs the loaded form without diffing against the original is fine.

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

Worked example, with two locations forming a parent / child pair:

| `external_key`                  | `tree_path`        |
| ------------------------------- | ------------------ |
| `WHS-01` (root)                 | `whs_01`           |
| `WHS-07-03` (child of `WHS-01`) | `whs_01.whs_07_03` |

The root's `tree_path` is its own normalized segment. A child's `tree_path` is its parent's `tree_path` plus a `.` and the child's normalized segment. Renaming `WHS-01` to `WHS-MAIN` rewrites the segment for the root **and the prefix** of every descendant in one transaction.

`depth` is the companion field. The root location has `depth: 1`; each child increments by 1 (`WHS-07-03` above has `depth: 2`). Like `tree_path`, `depth` is server-derived and read-only — clients can use it directly for indented rendering but should not try to set it on a write.

If you need ancestor `external_key`s (for breadcrumbs, parent lookups, or anything that touches your system of record), use `GET /api/v1/locations/{location_id}/ancestors` instead — it returns the full chain with each ancestor's untransformed `external_key`.

**Don't cache `tree_path`.** The value is derived, and renaming an `external_key` rewrites the `tree_path` on that location _and every descendant_ in one transaction. A client that pinned `tree_path` for hierarchy queries will silently desync after a rename. If you need stable hierarchy state, store the chain of `external_key`s (or the `id` chain via `/ancestors`) and re-derive on demand.

`tree_path` is also not an identifier — you can't look a location up by its `tree_path`. Use the [`?external_key=` filter](#natural-key-lookup-uses-external_key) on the locations list endpoint for natural-key lookups.

## Location tree endpoints {#location-tree-endpoints}

Three endpoints traverse the location hierarchy from a starting node. All three return the standard list envelope (`data`, `limit`, `offset`, `total_count`) and are gated by `locations:read`:

| Endpoint                                          | Returns                                                                              |
| ------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `GET /api/v1/locations/{location_id}/ancestors`   | Parent chain to the root, ordered nearest-first (immediate parent → … → root).       |
| `GET /api/v1/locations/{location_id}/children`    | Immediate children only. Single-level lookup.                                        |
| `GET /api/v1/locations/{location_id}/descendants` | The full subtree rooted at this location. Multi-level, includes children's children. |

```bash
# Walk the parent chain for breadcrumbs
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/42/ancestors"

# Subtree scope — every location reachable below this node
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/42/descendants"
```

These are distinct from the [`?parent_id=X` filter](./pagination-filtering-sorting#filtering) on `GET /api/v1/locations`. The filter is a single-level lookup against the parent reference — equivalent to `/{X}/children` for the immediate-child case. The dedicated endpoints are the right tool when you need explicit hierarchy traversal: `/ancestors` for breadcrumbs, `/descendants` for subtree scoping (e.g. "all assets anywhere under WAREHOUSE-WEST"), `/children` when you specifically want the one-level shape and don't want to think about whether the filter applies the [currently-effective predicate](#effective-dating-and-is-active) the same way.

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

**When integrating with a system of record (an ERP, a WMS, a partner database), supply the partner-side handle on create** — don't rely on the auto-mint. Auto-minted `ASSET-NNNN` values are deterministic per organization but they won't join cleanly to a SKU, an ERP code, or any other handle a downstream system already uses. The auto-mint exists for ad-hoc creates (a one-off entry from the SPA, a quick smoke test) where no partner-side join is needed.

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

## Effective dating and `is_active` {#effective-dating-and-is-active}

Assets and locations carry both an `is_active` boolean and a pair of `valid_from` / `valid_to` timestamps. They cover two independent dimensions:

- **`is_active`** — soft-delete / hide-from-list flag. An admin or automation toggles it directly.
- **`valid_from` / `valid_to`** — bitemporal effective dating, typically driven by lifecycle events (a vehicle entering service, an asset being decommissioned). See [Date fields](./date-fields) for the wire shape and input rules.

A row is **currently effective** when:

> (`valid_from` IS NULL OR `valid_from` ≤ now) AND (`valid_to` IS NULL OR `valid_to` > now)

The default scope on list endpoints applies this predicate — temporally inactive rows are filtered out regardless of `is_active`. The endpoints that filter:

- `GET /api/v1/assets`
- `GET /api/v1/locations`
- `GET /api/v1/locations/current`
- `GET /api/v1/assets/{asset_id}/history` (predicate applies to the joined location and to embedded tags)
- Embedded `tags` arrays on asset and location responses

Direct lookups by canonical `id` (`GET /api/v1/assets/{asset_id}`, `GET /api/v1/locations/{location_id}`) **do not** apply the predicate — a path-param read returns any non-deleted row. Clients holding a stale `id` can still inspect the record they remember, even after `valid_to` has passed.

`is_active` is an independent filter dimension. The default list scope returns currently-effective rows of either `is_active` value; pass `?is_active=true` (or `false`) to narrow further. The substring search (`?q=`) restricts tag-value matching to active and currently-effective tags — retired tags stay out of the search corpus by design.

If your business logic needs to surface an expired record (e.g., to render a "decommissioned on …" row in your UI), use the path-param read path or your own client-side filter — the list endpoints will not surface temporally inactive rows.

## Tags use a composite natural key

:::note "Tag" is a noun with two senses
In the API surface (and this page), **tag** is a typed data primitive: the `(tag_type, value)` pair attached to an asset or a location. In RFID-domain prose elsewhere on the docs site (and in user-facing UI copy), "tag" can also mean the physical hardware label being read by a scanner. Both senses are valid; this page operates on the data-primitive sense, and `tag_type` is what disambiguates which kind of physical artifact a given record represents (`rfid`, `ble`, or `barcode`).
:::

Tags follow the same principle as assets and locations, with a composite shape: a tag's natural key is the `(tag_type, value)` pair within an organization, enforced by the partial unique index `(org_id, tag_type, value) WHERE deleted_at IS NULL`. Inserting a duplicate live `(tag_type, value)` for the same organization returns `409 conflict`.

Don't conflate `external_key` with `tags[].value`: assets and locations have a single string natural key (`external_key`); tags have a composite one. The `value` field _inside_ a tag is the tag's own partner-supplied handle (an EPC, a beacon ID, a barcode), scoped by `tag_type`. The `external_key` _on_ an asset or location is the resource's partner-supplied handle, scoped by resource type. They sit at different levels and are not interchangeable — an asset's `external_key` and one of its tags' `value` answer different questions.

`tag_type` defaults to `rfid` when omitted on a write — the OpenAPI spec carries `default: rfid`, so a `POST /api/v1/assets/{asset_id}/tags` body of `{"value": "E2-..."}` is equivalent to `{"tag_type": "rfid", "value": "E2-..."}`. Codegen-derived clients surface the same default at the type-system level. Send `tag_type` explicitly when the tag is `ble` or `barcode`.

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

### Tag CRUD {#tag-crud}

Tags are managed as subresources of their parent asset or location. Two write endpoints per parent type, both idempotent on the read side and gated by the parent's write scope:

| Endpoint                                               | Required scope    | Behavior                                                                         |
| ------------------------------------------------------ | ----------------- | -------------------------------------------------------------------------------- |
| `POST /api/v1/assets/{asset_id}/tags`                  | `assets:write`    | Attach a tag to the asset. Body is `{tag_type, value}`; returns the new tag.     |
| `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`       | `assets:write`    | Detach a tag from the asset. Returns 204 whether or not the tag was associated.  |
| `POST /api/v1/locations/{location_id}/tags`            | `locations:write` | Attach a tag to the location. Same body and response shape as the asset variant. |
| `DELETE /api/v1/locations/{location_id}/tags/{tag_id}` | `locations:write` | Detach a tag from the location. Same idempotent semantics.                       |

Tag writes use the parent resource's write scope, not a separate `tags:write` — there is no per-tag scope.

```bash
# Attach an RFID tag to an asset
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"tag_type": "rfid", "value": "E2-8042-2D-19F0-AB10"}' \
     "$BASE_URL/api/v1/assets/4287/tags"
```

`tag_type` is an open enum (`rfid`, `ble`, `barcode`); each maps to a different physical artifact. The API does **not** validate the per-type shape of `value` — there's no length check that rejects a 12-byte EPC sent as `tag_type: barcode`, no UUID check on `ble`. The constraints are the global ones: `value` must be 1–255 characters and the `(tag_type, value)` pair must be unique within the organization for live (non-deleted) rows. Inserting a duplicate live pair returns `409 conflict`; the [errors](./errors) page covers the response shape.

`value` is matched **as an exact string** within `(org_id, tag_type)` for uniqueness, attach, and the embedded `tags[]` array on parent reads. There is no normalization (no case-folding, no whitespace stripping). Substring search across tag values is available only through the parent resource's [`?q=`](./pagination-filtering-sorting#substring-search) filter, which restricts to active and currently-effective tags.

`tag_type` defaults to `rfid` (covered above), so a body of `{"value": "E2-..."}` on an asset POST is equivalent to `{"tag_type": "rfid", "value": "E2-..."}`. Send `tag_type` explicitly when attaching `ble` or `barcode`.

## "Scan event" is a domain concept, not an API resource {#scan-event-vocabulary}

"Scan event" describes a reader-detected tag observation (RFID/BLE pings recorded by handhelds and fixed readers). The TrakRF docs and the TrakRF web app use the term throughout, but **scan events are not a top-level API resource**: there is no `scan_event` schema in the OpenAPI spec, no `/api/v1/scans` or `/api/v1/scan_events` endpoint, and no `scan_event_id` field on any response.

Scan-event-derived data is projected through two endpoints:

- `GET /api/v1/assets/{asset_id}/history` — the per-asset event timeline (timestamp, location, duration), authoritative for "what did this asset do over time?"
- `GET /api/v1/locations/current` — the latest snapshot per asset, authoritative for "where is each asset right now?"

Both are gated by the `history:read` scope (see [Authentication → Scopes](./authentication#scopes)) — the same scope, because both are projections of the same underlying event stream.

When [webhooks](./webhooks) ship, events will fire on scan events but the payloads address **assets and locations**, not scan events directly — there's no scan-event id to subscribe to or look up. An ingestor planning a scan-driven workflow should think in terms of asset history and current location, not in terms of a scan-event resource.
