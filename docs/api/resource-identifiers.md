---
sidebar_position: 3
---

# Resource identifiers

Every asset and location has two identifiers. The integer `id` is **canonical at the URL surface** — server-assigned, immutable, and the form path-param routes and foreign-key fields use. The string `external_key` is **canonical for partner-side joins** — your handle, the natural key for tying a TrakRF record to a row in your system of record (a SKU, an asset tag, a manufacturer serial number, an ERP code). Both are durable; both round-trip on every response; neither is a fallback for the other. They are not equivalent, though: an `id` is unique to TrakRF storage and meaningless outside it; an `external_key` is yours and is the only form your warehouse software, ERP, or operator will recognize. Pick the form the next system over recognizes.

## String-handle concepts at a glance

Two string-handle concepts appear across these resources, and they're close enough together to blur. Briefly:

- **`external_key`** — the resource's own natural key (this page, top-to-bottom).
- **`*_external_key` foreign-key fields** — flat-scalar references _to_ another resource's `external_key` from a record that holds the relationship. Examples: `location_external_key` on assets, `parent_external_key` on locations. Covered under [Foreign-key fields in responses](#foreign-key-fields-in-responses-come-as-flat-scalar-pairs).

Both are write-routable: caller-supplied on create, or server-minted from a per-organization `ASSET-NNNN` / `LOC-NNNN` namespace when `external_key` is omitted — see [auto-mint behavior](#external_key-is-optional-on-create). For ancestor chains and breadcrumbs on locations, walk the `parent_id` chain via the [tree endpoints](#location-tree-endpoints); there is no derived display-path field on the response.

### Natural keys per resource

Every resource on the public surface has a natural key — the caller-meaningful handle that lets you address a row without holding its surrogate `id`. Two shapes appear:

| Resource | Natural key                   | Uniqueness scope | Lookup surface                                                                                   |
| -------- | ----------------------------- | ---------------- | ------------------------------------------------------------------------------------------------ |
| Asset    | `external_key` (string)       | per organization | `GET /api/v1/assets?external_key=...`                                                            |
| Location | `external_key` (string)       | per organization | `GET /api/v1/locations?external_key=...`                                                         |
| Tag      | `(tag_type, value)` composite | per organization | parent resource (`/assets/{id}/tags` or `/locations/{id}/tags`); no top-level discovery endpoint |

Asset and location natural keys are single-string handles; tags are polymorphic, so the natural key is a `(tag_type, value)` pair — the same `value` can exist under different `tag_type`s in the same organization without conflict. All three are enforced by partial unique indexes on `WHERE deleted_at IS NULL`, so the constraint applies to live rows only and a soft-delete frees the handle for reuse.

The single-string form is covered in [Natural-key lookup uses `?external_key=`](#natural-key-lookup-uses-external_key); the composite tag form is covered in [Tags use a composite natural key](#tags-use-a-composite-natural-key).

**Character set.** `external_key` (and every `*_external_key` foreign-key field) is constrained to alphanumerics and the hyphen — `^[A-Za-z0-9-]+$`, length 1–255. Underscore, period, slash, colon, and whitespace are reserved. See [`external_key` value rules](#external_key-value-rules) for the full table and the rationale for each reserved character.

**`external_key` and `tags[].value` are not symmetric.** Both are partner-supplied string handles, but their input rules diverge — and the gap is wide enough that a value valid as a tag will 400 as an `external_key`. Worth pinning up front so a CSV importer or migration script doesn't push the same column through both surfaces unmodified:

| Surface        | Length | Pattern                                                                                                                                      | Examples that pass                                                              | Examples that pass on tags but fail on `external_key`                               |
| -------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `external_key` | 1–255  | `^[A-Za-z0-9-]+$` (alnum, `-`)                                                                                                               | `SKU-7421-A`, `BACK-STORAGE-2`                                                  | —                                                                                   |
| `tags[].value` | 1–255  | Any character _except_ C0 controls (NUL through US, plus DEL).<br/>Tab (`\t`), newline (`\n`), and carriage return (`\r`) **are** permitted. | `E2-8042-2D-19F0-AB10`, `a/b/c`, `X With Space`, `bin#3`, `漢字`, `multi\nline` | `a/b/c`, `X With Space`, `bin#3`, `漢字`, `multi\nline` (all 400 as `external_key`) |

The Tag pattern is encoded in the spec as `^[^\x00-\x08\x0B\x0C\x0E-\x1F\x7F]*$` — every printable character is allowed, plus the three whitespace bytes that legitimately appear in scanned payloads (tab, newline, CR). Other C0 controls (NUL, VT, FF, etc.) and DEL are rejected because they have no semantic place in a barcode/RFID/BLE identifier and would foul log lines, terminal output, or shell quoting downstream.

The asymmetry is intentional. `external_key` flows into URL paths and log lines where the reserved characters would force quoting, so the input is constrained to URL-safe alphanumerics and the hyphen. `tags[].value` is opaque payload to the API (an EPC, a beacon ID, a barcode, sometimes a vendor-specific composite with internal separators) and the service does not interpret its shape — only its length and the C0-control rule above. **If your tag value happens to match the `external_key` pattern, that's a coincidence, not a guarantee**; round-tripping a tag value through the `external_key` surface still needs validation. See [`external_key` value rules](#external_key-value-rules) for the full reserved-character rationale and [Tags use a composite natural key](#tags-use-a-composite-natural-key) for the tag side.

## Path-param lookup uses `id`

Single-resource endpoints take the canonical integer `id`:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287"
```

This is the conventional REST shape and the URL stays valid even if the asset's `external_key` changes. Use it when you have an `id` already in hand — typically because you got it from a list response, a previous create, or a record cached in your own database.

### Numeric `id` is a surrogate key

Numeric `id` values are surrogate keys — unique within their entity type, not across types. The same integer can exist as both an asset id and a tag id; that's expected behavior. The API disambiguates by URL position (`/assets/{asset_id}`, `/locations/{location_id}/tags/{tag_id}`) or query-parameter name (`location_id`, `parent_id`), so an id is never passed without its entity context at the API boundary. Client code matches ids to entity type — standard surrogate-key discipline.

The wire width of every surrogate id is **int64** (`format: int64` on the spec); the runtime ceiling is **2³¹−1**. The gap is deliberate — see [ID format: int64 wire, int32 runtime](./id-format) for the rationale, the `too_large` error envelope, and what it means for typed-client codegen.

## Natural-key lookup uses `?external_key=`

When you have the natural key but not the canonical `id`, filter the list endpoint by `external_key`:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?external_key=SKU-7421-A"
```

The list envelope returns 0 or 1 matches in `data` (the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` caps live rows at one per key). An empty array is the miss signal — there is no `404` for a natural-key miss on this filter. Soft-deleted rows are not addressable through it; if you need to inspect a deleted record, look it up by `id`. The filter also composes with the default temporal scope — a row whose `valid_from` is in the future, or whose `valid_to` has elapsed, is invisible to this lookup even when the natural key matches. See [Pagination, filtering, sorting → Filtering](./pagination-filtering-sorting#filtering) for the rule and the surrogate-id recovery path.

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

The two paired-FK shapes look symmetric on the read side but their write surfaces differ: **asset `location_id` / `location_external_key` are scan-data and not settable through the public API** — neither `POST` nor `PATCH` accepts them, see [Data model](./data-model) — while **location `parent_id` is master-data and fully writable** (set on create, re-parent on PATCH by sending a new id, or `null` to detach to root). See [Read shape vs. write shape](#read-shape-vs-write-shape) for the per-resource write surface.

That makes two response-shape behaviors that coexist on these resources, and it's worth knowing which is which:

| Behavior              | Fields                                                                                                                                     | Test for         |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------- |
| **Always present**    | `id`, `name`, `external_key`, `created_at`, `updated_at`, `is_active`, `valid_from` (and most scalars)                                     | the value itself |
| **Present as `null`** | `location_id`, `location_external_key`, `parent_id`, `parent_external_key`, `description`, `valid_to` (and other unset-but-emitted fields) | `field === null` |

Every field on `AssetView` and `LocationView` is **required** in the OpenAPI spec — generated SDKs will surface them as non-optional with a nullable type. Null-check, don't key-check. The same `required`-with-nullable pattern holds on the per-entity `deleted_at` field ([below](#soft-delete-visibility)). `AssetLocationItem` follows the same `required`-everywhere rule but with a narrower null surface — `asset_id` and `asset_external_key` are required _and_ non-nullable (the report only ever returns one row per scanned asset, so the asset side of the join is structurally non-null), while `location_id`, `location_external_key`, and `asset_deleted_at` are required and nullable for their own reasons (covered below). When in doubt, check the field's documentation page — [Date fields](./date-fields) covers `valid_to`, this page covers FK pairs and the soft-delete model.

### Soft-delete visibility on lists {#soft-delete-visibility}

Soft-deleted records are filtered out of list responses by default — every list endpoint applies a `WHERE deleted_at IS NULL` predicate at the storage layer. To opt in, pass `?include_deleted=true` on any of the three list surfaces: `GET /api/v1/assets`, `GET /api/v1/locations`, and `GET /api/v1/reports/asset-locations`. The toggle is consistent across endpoints — same name, same default (`false`), same independence from `is_active` (see [Boolean filters](./pagination-filtering-sorting#boolean-filters)).

Each row carries a deletion timestamp. The field name depends on whether you're reading a per-resource list or a cross-resource report:

| Endpoint                              | Schema              | Deletion field     |
| ------------------------------------- | ------------------- | ------------------ |
| `GET /api/v1/assets`                  | `AssetView`         | `deleted_at`       |
| `GET /api/v1/locations`               | `LocationView`      | `deleted_at`       |
| `GET /api/v1/reports/asset-locations` | `AssetLocationItem` | `asset_deleted_at` |

Per-resource views drop the prefix because the row is already inside the resource's own namespace — `AssetView.deleted_at` is unambiguously the asset's deletion timestamp. The cross-resource report row merges fields from multiple resources, so the prefix is load-bearing: `AssetLocationItem.asset_deleted_at` disambiguates from any location-side fields embedded in the same row, and reserves room for future per-row deletion timestamps from the location side without a rename.

The field is **always present on every row** — `null` for live records, populated with the deletion timestamp for soft-deleted ones. The OpenAPI spec marks it as `required` and `nullable: true`; codegen-derived clients surface it as a non-optional nullable field, same pattern as the FK pairs above. It is flagged `readOnly: true` in the spec, so a verbatim `GET` → `PATCH` round-trip continues to succeed (see [Read shape vs. write shape](#read-shape-vs-write-shape)).

`?include_deleted=true` controls **whether soft-deleted rows appear at all**, not whether the field is rendered. Without the flag, soft-deleted rows are filtered out and only live rows come back (each still carrying the deletion field as `null`). With the flag, soft-deleted rows are included alongside live ones, with their populated deletion timestamp distinguishing them. Null-check the field, don't key-check.

The path-param read by `id` (`GET /api/v1/assets/{asset_id}`, `GET /api/v1/locations/{location_id}`) applies the `WHERE deleted_at IS NULL` predicate at the storage layer and returns `404 not_found` once the row has been soft-deleted — the path-param read skips the currently-effective predicate (covered under [Effective dating and `is_active`](#effective-dating-and-is-active)) but not the soft-delete predicate. Dedicated by-id inspection of a soft-deleted record is roadmap, not v1; the list endpoints with `?include_deleted=true` are the public surface for "show me what's been retired." `?include_deleted` is a list-only filter, so passing it on a detail endpoint returns `400 validation_error` / `code: invalid_context` with a diagnostic naming the recovery path. To retrieve a specific soft-deleted row, use the natural key on the list endpoint: `GET /api/v1/{resource}?external_key=<key>&include_deleted=true`. Recovery by surrogate `id` isn't supported because soft-delete frees the natural-key namespace for reuse, so a stale `id` may race a freshly-minted live row with the same `external_key` — see [auto-mint namespace recycles on soft-delete](#external_key-is-optional-on-create).

#### Ancestor identifiers are preserved across tombstones {#soft-delete-ancestor-projection}

The natural-key form of the parent / location reference is projected through the join regardless of whether the referenced row is soft-deleted. On `GET /api/v1/locations?include_deleted=true`, a child whose parent is soft-deleted still carries the parent's `external_key` as its `parent_external_key` — the value lives on the parent row and is read across the `WHERE deleted_at IS NULL` cut. The same projection applies to `location_external_key` on `GET /api/v1/assets?include_deleted=true` when the asset's current location has been soft-deleted. Two reasons it works this way:

1. The string handle is the partner-side join key — losing it across a tombstone would break downstream reconciliation precisely when integrators most need it (post-cleanup audits, retroactive lookups).
2. The FK-pair invariant — both surrogate and natural-key form are non-null together or null together — stays intact. Without this projection, you'd see a `parent_id != null AND parent_external_key == null` shape that contradicts the contract documented under [Foreign-key fields in responses](#foreign-key-fields-in-responses-come-as-flat-scalar-pairs).

**Exception: `GET /api/v1/reports/asset-locations`.** The cross-resource report intentionally projects `location_external_key` as `null` when the location row has been soft-deleted, because the report is current-state-of-the-world and a soft-deleted location is, by definition, no longer current. Integrators who need the raw natural-key identifier across a tombstone should fall back to `GET /api/v1/locations?include_deleted=true&id=<location_id>` (or the per-asset `GET /api/v1/assets/{asset_id}` followed by `GET /api/v1/locations/{location_id}` on the surrogate) — the per-resource list preserves the value where the report drops it.

## Asset `metadata` vs. location `tags`: side-channel data {#asset-metadata-vs-location-tags}

`AssetView` carries an open-ended `metadata` object (`additionalProperties: true`) for partner-side annotations the API does not interpret — a CRM record id, an ERP cost-center code, a partner SKU. **Locations are pure tree nodes and do not carry caller-defined metadata** — `LocationView` has no `metadata` field. The asymmetry is intentional for v1: use a tag (`tags[]`) or `external_key` as the join surface to upstream systems for any location-side handle you'd otherwise want to stash on the row itself.

On write, `metadata` must be a JSON object. Scalars, arrays, and booleans (e.g. `"metadata": "x"`, `"metadata": [1, 2]`, `"metadata": true`) are rejected at the validator boundary with `400 validation_error` / `invalid_value`. The `additionalProperties: true` declaration governs what's allowed _inside_ the object; the wrapper itself is type-restricted.

### `metadata` is stored opaquely {#metadata-opaque}

The `metadata` field is stored opaquely. `PATCH` replaces the entire `metadata` object with the value sent — **the server performs no merging within the `metadata` field, even inside a JSON Merge Patch request**. The RFC 7396 deep-merge semantic stops at the top-level field boundary; `metadata` is treated as a single opaque value at that boundary, not a nested document to merge into.

```bash
# Existing on the asset:
#   "metadata": {"erp_id": "E-99", "owner": "ops"}

# PATCH sends a new metadata value:
curl -X PATCH "$BASE_URL/api/v1/assets/$ASSET_ID" \
  -H "Authorization: Bearer $TRAKRF_API_KEY" \
  -H "Content-Type: application/merge-patch+json" \
  -d '{"metadata": {"owner": "logistics"}}'

# Result on the asset:
#   "metadata": {"owner": "logistics"}   ← "erp_id" is gone
```

Clients that need to preserve existing keys should:

1. `GET` the resource and read the current `metadata` object.
2. Compute the desired result client-side using whatever merge strategy is appropriate (deep-merge, shallow-merge, replace, or anything in between).
3. Send the resulting object as the `metadata` value on `PATCH`.

This puts the merge strategy in the client's hands — TrakRF does not assume which one is right for your data. To clear `metadata` entirely on PATCH, send `{}` — both the create and update request schemas declare `metadata` as a non-nullable object, so the empty object is the documented "no keys" shape and `metadata: null` is rejected on both `POST` and `PATCH`.

The pattern we recommend mirrors the schemas:

| Surface       | Where to put partner-side data                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Assets**    | `metadata` — free-form key/value, no schema, round-trips through `GET` → `PATCH`.                |
| **Locations** | `tags` — typed natural-key pairs (`tag_type`, `value`), enforced unique within the organization. |

Locations were not given an open `metadata` field because the practical "what would I stuff in here" use cases on a location (a CRM site id, a partner facility code) are already addressable through `tags` with a partner-defined `tag_type`. Reintroduction of an opaque `metadata` field on locations is a v1.1 consideration, not a v1 commitment — generated clients should not assume the field will appear and should branch on its presence if a future spec adds it. If you have a use case that genuinely needs schemaless side-channel data on a location today, [contact us](mailto:support@trakrf.id) — same evaluation track as the v2 capability requests.

## Read shape vs. write shape

Asset and location updates use `PATCH /api/v1/{resource}/{id}` with `Content-Type: application/merge-patch+json` (JSON Merge Patch, [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396)).

:::important Scope of `POST` and `PATCH /api/v1/assets/{asset_id}`
Neither `POST` nor `PATCH` moves an asset. `location_id` and `location_external_key` appear on the read shape but are absent from both `CreateAssetWithTagsRequest` and `UpdateAssetRequest`. On `POST`, sending either field returns `400 validation_error` / `code: read_only`; on `PATCH`, a value that differs from the current state returns the same envelope under the [accept-if-matches, reject-if-differs](#read-shape-vs-write-shape) rule. The error detail names the ingestion paths: "asset location is collected through scan event ingestion (fixed-reader MQTT pipeline or handheld UI submission) and is not directly settable through the public API." See [Data model](./data-model) for the master / scan bifurcation framing.

The asset write surface is `name`, `description`, `is_active`, `metadata`, `valid_from`, `valid_to` (plus `external_key` and `tags` on `POST`). Mutate `external_key` post-create via `POST /api/v1/assets/{asset_id}/rename`; mutate `tags` via the tag subresource ([Tag CRUD](#tag-crud)).
:::

:::important Scope of `PATCH /api/v1/locations/{location_id}`
Location PATCH **does** move the location in the tree. Both `parent_id` (surrogate) and `parent_external_key` (natural key) are writable on `UpdateLocationRequest` — symmetric with `CreateLocationRequest` — and either form accepts `null` to detach the location to root. Send one form or the other in a single body; supplying both with matching values is accepted (silently normalized to a single re-parent operation), and supplying both with differing values returns `400 validation_error` / `code: ambiguous_fields`. The asymmetry with the asset side is deliberate — asset location is scan-derived; location parentage is a partner-managed tree.

The location PATCH writable surface is `name`, `description`, `is_active`, `parent_id` **or** `parent_external_key`, `valid_from`, `valid_to`. Mutate `external_key` via `POST /api/v1/locations/{location_id}/rename`; mutate `tags` via the tag subresource.
:::

Three rules cover the body semantics:

- **Field present, scalar value** — set the field to that value.
- **Field present, value `null`** — clear the field. Only legal for writable-nullable fields (listed at the end of this section); sending `null` for a non-nullable field returns `400 validation_error` / `code: invalid_value` (distinct from `required`, which fires when the key is absent — see [Errors → Validation errors](./errors#validation-errors)).
- **Field omitted** — leave the existing value unchanged.

An empty body (`{}`) is a documented no-op against settable fields: the server applies the merge, returns `200`, and no settable field changes. `updated_at` does advance — see the [Read shape vs. write shape](#read-shape-vs-write-shape) section below for the uniform-advance model. This is also the floor case for the "no writable fields" rule below.

Request and response field _names_ match for every writable field. Read responses carry fields that aren't part of the request schema — server-managed metadata, the natural-key form of paired FKs, and the `tags` collection — and every one of those fields obeys a single uniform rule on `PATCH`:

**Accept-if-matches, reject-if-differs.** A body value that matches the current resource state is silently normalized out (so the update applies cleanly, ignoring the read-only field); a value that differs is rejected with `400 validation_error` and a `message` naming the proper write path. The rejection `code` splits along whether the field has a partner-mutable write path: truly server-managed fields (`id`, `created_at`, `updated_at`, `deleted_at`, and the scan-derived `location_id` / `location_external_key`) return `code: read_only`; fields that are settable on the surface but via a different verb (`external_key` via `/rename`, `tags` via the `/tags` sub-resource) return `code: invalid_context`. Both codes share the per-field rejection message; client handlers that surface `detail` to humans need not branch, while handlers branching on `code` get the routing signal directly. The per-field rejection message is listed in the table immediately below.

| Field                   | Surface                             | Reject-if-differs `message` names                                                                                                                                                                      |
| ----------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`                    | `PATCH /assets`, `PATCH /locations` | `id` is server-assigned and immutable; submit the resource's current `id` or omit the field.                                                                                                           |
| `created_at`            | `PATCH /assets`, `PATCH /locations` | `created_at` is server-managed and immutable; submit the resource's current `created_at` or omit the field.                                                                                            |
| `updated_at`            | `PATCH /assets`, `PATCH /locations` | `updated_at` is server-managed; `PATCH` advances it implicitly. Submit the resource's current `updated_at` or omit the field.                                                                          |
| `deleted_at`            | `PATCH /assets`, `PATCH /locations` | `deleted_at` is server-managed; use `DELETE /api/v1/{resource}/{id}` to soft-delete. Submit the resource's current `deleted_at` or omit the field.                                                     |
| `tags`                  | `PATCH /assets`, `PATCH /locations` | Tags are managed via `POST /api/v1/{resource}/{id}/tags` and `DELETE /api/v1/{resource}/{id}/tags/{tag_id}`.                                                                                           |
| `external_key`          | `PATCH /assets`, `PATCH /locations` | The matching rename endpoint: `POST /api/v1/{resource}/{id}/rename`.                                                                                                                                   |
| `location_id`           | `POST /assets`, `PATCH /assets`     | "asset location is collected through scan event ingestion (fixed-reader MQTT pipeline or handheld UI submission) and is not directly settable through the public API." See [Data model](./data-model). |
| `location_external_key` | `POST /assets`, `PATCH /assets`     | Same as `location_id`.                                                                                                                                                                                 |

Both `parent_id` and `parent_external_key` on `PATCH /locations` are **not** in this rule — they are both fully writable (either form re-parents; supplying both with matching values is accepted, supplying both with differing values returns `ambiguous_fields`). The rename endpoint changes the row's own `external_key`, not its parentage.

The `location_*` cases on assets share their detail string because TrakRF is record-of-origin for asset location data: current location is collected through scan event ingestion (fixed-reader MQTT or handheld UI submission), not a partner-side write. Neither `POST` nor `PATCH` moves an asset — the symmetry is intentional and reflects the master-data / scan-data bifurcation. See [Data model](./data-model) for the full framing and [Scan events are a domain concept](#scan-event-vocabulary) for the vocabulary.

:::note Verbatim GET → PATCH round-trips work without scrubbing
No client-side scrubbing is required for any read-only field. A verbatim `GET` → `PATCH` round-trip succeeds without modification — every read-only field whose value matches the current resource state is silently normalized out, and any differing value rejects with `code: read_only` or `code: invalid_context` (per the [code split above](#read-shape-vs-write-shape)) plus a hint pointing at the proper write path. Strict-typed codegen (Pydantic, Java, Go with generated structs) already reshapes into the write schema (`UpdateAssetRequest` / `UpdateLocationRequest`), so the read-only fields are excluded at the SDK boundary; hand-rolled clients sending the full read shape don't need a strip step at all.

Any accepted PATCH advances `updated_at` to the current server time on success. The model is uniform across body shapes — empty body (`{}`), verbatim writable echo of current values, partial mutation, and full mutation all advance the timestamp. The 400-rejection paths (read-only field mismatch with `code: read_only` or `code: invalid_context`, validation failure on a settable field, or any other 4xx) don't advance `updated_at` because the operation never reached storage. The mental model is filesystem `touch` semantics: any successful write event advances the modification time regardless of whether content changed. See [Errors → Idempotency](./errors#idempotency) for the consequence on cached-body retry patterns — specifically, a retry whose body echoes `updated_at` from a successful first call will fail with stale-token rejection.

For `created_at`, `updated_at`, and `deleted_at` the match is by instant rather than wire bytes: any RFC 3339 representation of the same point in time is accepted. A client that deserializes the GET response into a typed `datetime` and re-serializes via the language default (Go `time.Time.MarshalJSON` emits `+00:00`; Pydantic v2's `model_dump(mode='json')` emits `.NNNNNN+00:00`) round-trips cleanly even though the bytes differ from the server's canonical `Z` shape; a differing instant still rejects with `read_only`. The other read-only fields (`id`, `tags`, `external_key`, `*_external_key`, `location_*`) admit a single byte form for any given value, so byte-canonical comparison is correct for them.
:::

The rejected fields each have a dedicated mutation surface:

- **`external_key`** — mutate via `POST /api/v1/assets/{asset_id}/rename` or `POST /api/v1/locations/{location_id}/rename`. See [Renaming an `external_key`](#renaming-an-external_key) for the operation shape and the partner-side join-disconnect contract.
- **`parent_external_key`** — writable on `PATCH /locations` (symmetric with create): send either `parent_id` or `parent_external_key` to re-parent (`null` on either form clears the FK; supplying both with matching values is accepted, supplying both with differing values returns `ambiguous_fields`). The rename endpoint changes the row's own `external_key`, not its parentage; to make the value that reads back as `parent_external_key` change without re-parenting, rename the parent row itself via `POST /api/v1/locations/{parent_id}/rename`.
- **`location_id` / `location_external_key`** (assets) — scan-data, not master-data. Asset location is collected through scan event ingestion (fixed-reader MQTT pipeline or handheld UI submission); the public API does not expose a direct write path. See [Data model](./data-model) for the master / scan bifurcation and the consumption endpoints (`GET /api/v1/assets/{id}`, `GET /api/v1/assets/{id}/history`, `GET /api/v1/reports/asset-locations`).
- **`tags`** — mutate via `POST /api/v1/assets/{asset_id}/tags` and `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}` (and the location counterparts). See [Tag CRUD](#tag-crud).

A request body that resolves to **no writable fields** — `{}`, a body containing only round-trip-safe fields, or a body whose natural-key reference fields all match the current state — returns `200` with the unchanged record.

Strict-unknown-field validation still applies for fields that are **not** declared on either the read or the write schema — a typo'd or off-resource field name returns `400 validation_error` with `fields[].code: unknown_field`. See [Errors → Validation errors](./errors#validation-errors); the validator behavior is also covered globally in [Pagination, filtering, sorting → Validator behavior on writes](./pagination-filtering-sorting#validator-behavior-on-writes).

```bash
# Minimal PATCH: only the field being changed. Omitted fields stay as-is.
# Asset writable fields:    name, description, is_active, metadata, valid_from, valid_to.
# Location writable fields: name, description, is_active, parent_id OR parent_external_key, valid_from, valid_to.
curl -X PATCH \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/merge-patch+json" \
     -d '{"description": "back-stockroom shelf 3, bin B"}' \
     "$BASE_URL/api/v1/assets/4287"
```

For a verbatim `GET` → `PATCH` round-trip — useful when an integration's data model mirrors the read shape one-to-one — send the response body straight back. Every read-only field echoes through silently because its value matches the current state:

```bash
# GET → mutate → PATCH round-trip. Every read-only field — id, timestamps,
# tags, external_key, location_id, location_external_key, and (for locations)
# parent_external_key — silently match-strips server-side.
curl -sH "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287" \
| jq '.data | .description = "back-stockroom shelf 3, bin B"' \
| curl -X PATCH \
       -H "Authorization: Bearer $TRAKRF_API_KEY" \
       -H "Content-Type: application/merge-patch+json" \
       -d @- \
       "$BASE_URL/api/v1/assets/4287"
```

The split is encoded in the spec where it can be: the server-managed surrogate id and timestamps carry `readOnly: true`, which drives typed codegen tools to omit them from request shapes. The natural-key reference fields and `tags` are handled differently per schema, with a corresponding integrator-side asymmetry:

- **`UpdateLocationRequest` keeps `parent_id` and `parent_external_key`** because they are themselves writable on PATCH for re-parenting. A differing `external_key` field is still surfaced as `400 validation_error` (`code: invalid_context` — `external_key` is settable via `/rename`, just not via this verb) by the [accept-if-matches](#read-shape-vs-write-shape) rule, but the parent FK pair travels through the write schema by design.
- **`UpdateAssetRequest` declares only `[description, is_active, metadata, name, valid_from, valid_to]`** — the natural-key reference fields (`external_key`, `location_id`, `location_external_key`) and `tags` are **not** declared on the write schema. Strict-typed SDKs (Pydantic models, generated Java POJOs, Go structs built from the spec) reshape into `UpdateAssetRequest` before sending, so these fields are scrubbed client-side by construction and the wire-level rejection (`400 validation_error` with `code: invalid_context` on `external_key` and `tags`, `code: read_only` on the scan-derived `location_*` pair) never reaches the integrator from a typed SDK call path.

**The asset / location asymmetry is by design.** The two resources sit on opposite sides of a load-bearing product decision: **asset location is scan-data** (the reader fleet is the record of origin — partner integrations consume location data; they do not write it through the public API), while **location parentage is master-data** (the location tree is a hierarchy an operator or upstream layout tool maintains directly, so creation and re-parenting on the public API is the right write surface). See [Data model](./data-model) for the framing across the rest of the surface. The schema split surfaces that difference in the type system: typed SDKs surface `parent_id` / `parent_external_key` as writable fields on locations and don't surface a writable location FK on assets at all (absent from both `CreateAssetWithTagsRequest` and `UpdateAssetRequest`), so an integrator copy-pasting one resource's write code at the other doesn't accidentally model a write that doesn't exist. The wire-level `400 read_only` on asset `location_*` fields names the ingestion paths in the error detail — fixed-reader MQTT or handheld UI submission — and is the safety net for hand-rolled callers; the schema-level absence is the load-bearing layer for typed clients.

The practical consequence: the [accept-if-matches, reject-if-differs](#read-shape-vs-write-shape) wire-level rule is real, but most integrators won't observe the reject side through their SDK on the asset surface. Only hand-rolled callers (curl, raw `fetch`, hand-built `requests` payloads) send the unscrubbed read shape and see the `400` directly. The full [verbatim `GET` → `PATCH` round-trip](#read-shape-vs-write-shape) still succeeds across both call paths: strict-typed SDKs scrub the unwritable fields before the request leaves the client; hand-rolled callers send everything and the server silently strips matching read-only values.

Future resources may grow their own read-only fields; don't memorize per-resource lists — derive them from the spec, or rely on a generated client.

### Paired-key behavior per verb {#paired-key-behavior-per-verb}

Each paired FK relationship — `location_id` / `location_external_key` on assets, `parent_id` / `parent_external_key` on locations — has different contracts per HTTP verb:

| Surface                                | one form supplied                                                                                                  | both forms supplied (agree)                                          | both forms supplied (disagree)                                      |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `POST /assets` body                    | `400 validation_error / read_only` (asset location is scan-data, not master-data — see [Data model](./data-model)) | same (both fields rejected with one `fields[]` entry each)           | same                                                                |
| `POST /locations` body                 | accept                                                                                                             | accept (silently normalized to a single re-parent operation)         | `400 validation_error / ambiguous_fields`                           |
| `PATCH /assets/{id}` body              | accept-if-matches on either form; `400 read_only` if either differs                                                | accept-if-matches (both stripped); `400 read_only` if either differs | `400 read_only` (each differing field generates a `fields[]` entry) |
| `PATCH /locations/{id}` body           | both `parent_id` and `parent_external_key` writable; either re-parents (or accepts `null` to detach)               | accept (silently normalized to a single re-parent operation)         | `400 validation_error / ambiguous_fields`                           |
| `GET` list filter (assets / locations) | accept                                                                                                             | `400 validation_error / ambiguous_fields`                            | `400 validation_error / ambiguous_fields`                           |

The `POST /locations` body follows the same accept-matching / reject-differing rule as the PATCH body: supply one form or supply both with values that name the same parent (silently normalized to a single re-parent operation), and only a value disagreement returns `400 validation_error / ambiguous_fields`. On `GET` filter surfaces the rule is stricter — supplying both forms is rejected outright regardless of value agreement, with `fields[]` carrying one entry per offending parameter so a validation UI can highlight both. The `GET`-filter rule is enforced handler-side because OpenAPI 3 cannot express mutual exclusion on query parameters, and there is no "normalize to one" semantic on query strings the way there is on a re-parent write.

`POST /assets` is **not** a paired-key surface for location at all — neither `location_id` nor `location_external_key` is declared on `CreateAssetWithTagsRequest`, so both fields surface the strict-unknown-field rejection as `400 read_only` (the same error the PATCH side returns under accept-if-matches / reject-if-differs). The symmetry between POST and PATCH on the asset write surface reflects the master-data / scan-data bifurcation: asset location is scan-derived, not partner-set, on either verb. See [Data model](./data-model).

`PATCH` follows the uniform [accept-if-matches, reject-if-differs](#read-shape-vs-write-shape) rule for the two asset-side natural-key reference fields. The asset side does not expose a writable surrogate for location — current location is collected through scan event ingestion, so neither `location_id` nor `location_external_key` can move an asset via `PATCH`. The location side keeps both `parent_id` and `parent_external_key` writable for re-parenting; supplying both with matching values is accepted (silently normalized to a single re-parent), and only a value disagreement returns `ambiguous_fields`. The rename endpoint changes `external_key`, not parentage.

A foreign-key value that refers to a non-existent (or soft-deleted) row — `location_id: 99999999` or `location_external_key: "NOPE-XYZ"` — returns `400 validation_error` with `code: fk_not_found` regardless of which form you sent; `fields[].field` names the form. Branch on `code`, not on which FK variant the caller chose. `fk_not_found` is checked after the accept-if-matches step on `PATCH`, so a bogus FK value that happens to match the current state (e.g., echoing a `null` from a relationship that's already unset) is silently stripped before any FK resolution runs.

To **clear** a relationship on `PATCH`, send `null` on either writable form: `PATCH {"parent_id": null}` and `PATCH {"parent_external_key": null}` both clear a location's parent, and the server recomputes the other form to `null` on the next read. The clear-with-null pattern matches every other writable-nullable field — `PATCH {"description": null}` clears the description; `PATCH {"valid_to": null}` clears the expiry. Sending an empty string (`""`) for a length-bearing nullable like `description` is **rejected** with `400 validation_error` / `code: too_short`, matching every other length-bearing field — send explicit `null` to clear, not `""`. Asset writable-nullables are `description`, `valid_to`; location writable-nullables are `description`, `parent_id` or `parent_external_key`, `valid_to`. Asset location is **not** a writable-nullable — clearing it is not a PATCH operation; record a scan event instead. After a clear, the field reads back as `null` (see [Always present vs. present-as-null](#foreign-key-fields-in-responses-come-as-flat-scalar-pairs) above; for `valid_to` specifically see [Date fields](./date-fields)).

## Renaming an `external_key` {#renaming-an-external_key}

`external_key` is your join key — the form your ERP, WMS, or operator recognizes — and the rest of this page treats it that way. Because partner-side systems are likely to have indexed or cached records under the existing key, **`external_key` is immutable on `PATCH`**. The platform exposes a dedicated rename operation per resource type so the mutation is explicit at the URL surface and visible in audit logs.

:::caution Renaming disconnects downstream joins
A partner system that has cached or indexed records under the old `external_key` will silently desynchronize across a rename. Treat rename as a coordinated cutover — notify the downstream consumer, or re-export from TrakRF after the rename — not a casual edit.
:::

### Asset rename

```bash
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"external_key": "SKU-7421-B"}' \
     "$BASE_URL/api/v1/assets/4287/rename"
```

The response is the updated `AssetView`, wrapped in the standard `{ "data": ... }` envelope. Required scope is `assets:write` — the same scope as `PATCH /api/v1/assets/{asset_id}`. The operation is logged distinctly from a PATCH in audit trails by virtue of its dedicated URL surface (`/rename` vs the parent path), so no audit-schema extension is needed for integrators ingesting the audit stream.

The response envelope also carries `descendant_count_affected: 0` for shape uniformity with the [location rename response](#location-rename) — assets have no hierarchy, so the value is always `0`. A client that consumes both rename endpoints can read `descendant_count_affected` off either response without branching on resource type, then act on it only when non-zero.

### Location rename {#location-rename}

Location rename mutates only the renamed row's `external_key`. Descendants are not modified on the server — the location hierarchy is keyed on the surrogate `parent_id`, so descendants stay correctly parented across a rename. The response still surfaces `descendant_count_affected` so an integrator who maintains derived natural-key joins on their own side knows how many rows under the renamed node may need refreshing:

```bash
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"external_key": "WAREHOUSE-MAIN"}' \
     "$BASE_URL/api/v1/locations/7/rename"
```

```json
{
  "data": {
    "id": 7,
    "external_key": "WAREHOUSE-MAIN",
    "name": "Warehouse, west annex"
  },
  "descendant_count_affected": 23
}
```

`descendant_count_affected` is the live count of descendant rows reachable through the `parent_id` chain — the renamed row itself is **not** included. The TrakRF response carries `parent_id` (surrogate) and `parent_external_key` (the renamed value will propagate through `parent_external_key` on descendants automatically because that field is recomputed on read). A non-zero value is your cue to refresh any subtree state your own side caches under the old natural key. Zero means there are no descendants — for example, a leaf-location rename — and no client-side refresh is needed.

A same-value rename (new `external_key` equals the current one) is fully idempotent: returns `200` with `descendant_count_affected: 0`, no audit-log noise to special-case, and **`updated_at` does not advance** — the row is observably unchanged. Safe to retry on partial-failure without branching for "already at the target value," and a cached-body `PATCH` after a same-value rename retry remains safe because the cached `updated_at` still matches the live value. A real rename (new value differs from current) advances `updated_at` like any other write, so any cached body needs a re-`GET` before the next `PATCH` — see [Round-trip: `GET` → mutate → `PATCH`](./quickstart#round-trip-patch) for the optimistic-concurrency framing.

### Uniqueness collisions return `409`

The new `external_key` must satisfy the same per-org uniqueness rule as create — the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL`. A collision returns `409 conflict` with the standard error envelope, matching how `POST /api/v1/assets` and `POST /api/v1/locations` handle the same collision. Resolve the conflict (rename or retire the conflicting row first), then retry.

### `external_key` in a `PATCH` body is rejected

An `external_key` value differing from the current resource state in a `PATCH /api/v1/assets/{asset_id}` (or location) body returns `400 validation_error` / `code: invalid_context` with a `message` naming the rename endpoint, under the uniform [accept-if-matches, reject-if-differs](#read-shape-vs-write-shape) rule for natural-key reference fields. The `invalid_context` value (introduced for "known field, wrong verb" rejections — see [Errors → Validation errors](./errors#validation-errors)) signals that the field is settable on the surface, just not via this verb. Echoing the current `external_key` back through `PATCH` is silently stripped, so a verbatim round-trip is safe; the only way to actually change the value is `POST /api/v1/{resource}/{id}/rename`.

### Out of scope for v1

- **Bulk rename.** Single-row only. Loop client-side for multi-row scenarios; each call is its own transaction.
- **Cross-org rename.** `external_key` uniqueness is per-org by construction; there is no concept of "rename across organizations."

## Locations: `parent_id` and `parent_external_key`

Locations follow the same flat-scalar pattern for their parent reference. A location response includes both `parent_id` and `parent_external_key` whenever the location has a parent:

```json
{
  "data": {
    "id": 42,
    "external_key": "BACK-STORAGE-2",
    "name": "Back storage, bay 2",
    "parent_id": 7,
    "parent_external_key": "WAREHOUSE-WEST"
  }
}
```

Set either `parent_id` or `parent_external_key` on create or update to nest under an existing parent. Root locations (no parent) carry both fields as `null`. They're never absent from the response — null-check, don't key-check.

`PATCH /api/v1/locations/{location_id}` must reference a non-descendant location on `parent_id` (or `parent_external_key`). An assignment that would create a cycle in the parent chain — `parent_id` set to the location's own `id` (1-hop self-parent), or to any location reachable through the existing subtree rooted at the location being reparented (N-hop transitive) — returns `409 conflict` with a specific `detail` naming both endpoints of the cycle. Valid non-descendant reparenting and root promotion (`parent_id: null`) succeed unchanged. See [Errors → `conflict`](./errors#error-type-catalog).

`parent_id` and `parent_external_key` are one-hop only — they describe the immediate parent, not the chain to the root. For multi-hop traversal use the dedicated endpoint:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/42/ancestors"
```

If you need ancestor `external_key`s (for breadcrumbs, parent lookups, or anything that touches your system of record), `GET /api/v1/locations/{location_id}/ancestors` returns the full parent chain. For indent-rendering a flat list of locations, walk the `parent_id` chain client-side from the cached list — the location count per organization is small enough that client-side derivation is cheap and the surrogate `parent_id` is stable across renames.

**Case-distinct external keys are distinct locations.** `WAREHOUSE-WEST` and `warehouse-west` are two different rows under the per-org partial unique index on `(org_id, external_key) WHERE deleted_at IS NULL`. They can coexist as siblings under the same parent. Tagging conventions that mix case (`SKU-WHS-01` vs. `sku-whs-01`) won't silently merge — pick a convention to keep partner-side joins predictable, but the platform doesn't enforce one.

## Location tree endpoints {#location-tree-endpoints}

Three endpoints traverse the location hierarchy from a starting node. All three return the standard list envelope (`data`, `limit`, `offset`, `total_count`) and are gated by `locations:read`:

| Endpoint                                          | Returns                                                                                                                                                                                                                                                                                 |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /api/v1/locations/{location_id}/ancestors`   | Parent chain returned root-first (walking up the `parent_id` chain to the tree root), with `id` ascending as a deterministic tiebreaker. To render a breadcrumb left-to-right (root → current), iterate the response array in natural order and append the current location at the end. |
| `GET /api/v1/locations/{location_id}/children`    | Immediate children only. Single-level lookup.                                                                                                                                                                                                                                           |
| `GET /api/v1/locations/{location_id}/descendants` | The full subtree rooted at this location. Multi-level, includes children's children.                                                                                                                                                                                                    |

```bash
# Walk the parent chain for breadcrumbs
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/42/ancestors"

# Subtree scope — every location reachable below this node
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/42/descendants"
```

These are distinct from the [`?parent_id=X` filter](./pagination-filtering-sorting#filtering) on `GET /api/v1/locations`. The filter is a single-level lookup against the parent reference — equivalent to `/{X}/children` for the immediate-child case. The dedicated endpoints are the right tool when you need explicit hierarchy traversal: `/ancestors` for breadcrumbs, `/descendants` for subtree scoping (e.g. "all assets anywhere under WAREHOUSE-WEST"), `/children` when you specifically want the one-level shape and don't want to think about whether the filter applies the [currently-effective predicate](#effective-dating-and-is-active) the same way.

## Locations: delete semantics {#locations-delete-semantics}

`DELETE /api/v1/locations/{location_id}` returns `204` only when the location is a true leaf — no active descendant locations and no assets placed directly at it. Otherwise the server rejects with `409 conflict` and the standard error envelope. Bulk cascade is not supported in v1 — there is no `?cascade=true` query parameter, and the responsibility for reassigning or removing dependents stays on the caller.

The handler runs two pre-checks per call, descendants first. The two cases produce **distinct `detail` strings** so integrators can branch on which constraint failed without parsing free-form text fragments:

| Cause                                          | `error.detail`                                                                                          |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Active descendant locations exist              | `location has descendant locations; reassign or remove them before deleting (cascade is not supported)` |
| Active assets placed directly at this location | `location has assets placed at it; move or remove them before deleting (cascade is not supported)`      |

"Active" here means `deleted_at IS NULL` — soft-deleted descendants and soft-deleted placed assets do **not** block the delete (they already drop out of every list response per [Soft-delete is not a general field](#soft-delete-visibility)). A location whose only children are themselves soft-deleted is still a valid leaf for delete purposes.

The rejection preserves the FK-pair invariant the rest of this page documents. If the server allowed the delete to proceed silently, descendants would survive with `parent_id` pointing at a deleted row and `parent_external_key` becoming `null` — a `parent_id != null AND parent_external_key == null` shape that's undefined under [the FK-pair contract](#foreign-key-fields-in-responses-come-as-flat-scalar-pairs). The same shape would appear on assets placed at a deleted location (`location_id` populated, `location_external_key` null). The 409 keeps both invariants intact.

Sample 409 response:

```json
{
  "error": {
    "type": "conflict",
    "title": "Conflict",
    "status": 409,
    "detail": "location has descendant locations; reassign or remove them before deleting (cascade is not supported)",
    "instance": "/api/v1/locations/42",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

To pre-check before deleting, use the existing read endpoints to enumerate the blockers:

- Active descendant locations: [`GET /api/v1/locations/{location_id}/descendants`](#location-tree-endpoints) returns the full subtree.
- Active placed assets: `GET /api/v1/assets?location_id={location_id}` (or `GET /api/v1/reports/asset-locations?location_id={location_id}` for the report shape).

Reassign or remove the dependents (move placed assets out via a scan event recorded at the new location — `PATCH /api/v1/assets/{asset_id}` cannot change asset location; reparent the descendant locations via `PATCH /api/v1/locations/{location_id}` with a new `parent_id`, or delete them the same way), then retry the delete on the leaf.

## `external_key` is optional on create — both resources auto-mint {#external_key-is-optional-on-create}

`external_key` is **optional on `POST` for assets and locations alike**. Supply your own value to anchor the row to a partner-side handle (a SKU, an ERP code, an operator-typed location label, a row from a planned-layout export), or omit the field on the request body and the server assigns the lowest unused slot in the per-organization `ASSET-NNNN` / `LOC-NNNN` namespace. Each resource type has its own format and its own namespace:

| Resource | Auto-minted format | Namespace scope  |
| -------- | ------------------ | ---------------- |
| Asset    | `ASSET-NNNN`       | per-organization |
| Location | `LOC-NNNN`         | per-organization |

The pick is "lowest unused slot among live rows," not a monotonic counter: the namespace is governed by the same partial unique index that backs `external_key` uniqueness (`(org_id, external_key) WHERE deleted_at IS NULL`), so a slot freed by soft-deleting every live row that holds it becomes immediately eligible to be minted again. Don't model the namespace as Postgres-`nextval`-style append-only — auto-mint may pick a key whose namespace slot was previously occupied by one or more soft-deleted rows. The system-of-record guidance below (supply the partner-side handle on create) is the load-bearing rule for any caller that needs a stable, never-recycled identifier.

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

# Same shape on locations — omit external_key to receive a LOC-NNNN value
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "Back storage, bay 2"}' \
     "$BASE_URL/api/v1/locations"
```

A caller-supplied `external_key` that collides with an existing live row of the same resource type returns `409 conflict` against the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL`. Once a row is soft-deleted its `external_key` becomes immediately available for reuse. Full create flows live in the [Quickstart](./quickstart).

**Optional means omit, not empty string.** The auto-mint path fires only when the request body has no `external_key` key at all. Sending `"external_key": ""` (or any whitespace-only value) returns `400 validation_error` with `code: too_short` — the same rejection `PATCH /api/v1/assets/{asset_id}` and `PATCH /api/v1/locations/{location_id}` produce, on the same envelope. CSV importers and form handlers that emit empty strings on blank inputs need to omit the key entirely, or they'll 400 on every blank row instead of receiving a server-minted value.

**When integrating with a system of record (an ERP, a WMS, a partner database, a layout / floor-plan tool), supply the partner-side handle on create** — don't rely on the auto-mint. Auto-minted `ASSET-NNNN` / `LOC-NNNN` values are per-organization-unique among live rows but they won't join cleanly to a SKU, a facility code, an ERP location, or any other handle a downstream system already uses, and they may recycle a slot vacated by a soft-deleted row (see the namespace note above) — neither property is what a partner-side audit log expects from an `id`-shaped identifier. The auto-mint is the right call for ad-hoc creates (a one-off entry from the SPA, a quick smoke test, a row pasted in from a CSV with no upstream key). In practice the supply-your-own pattern dominates on locations, which are more often planned-layout than ad-hoc, while assets see more auto-mint use when no upstream SKU yet exists.

## `external_key` value rules {#external_key-value-rules}

`external_key` is constrained by the regex `^[A-Za-z0-9-]+$` — alphanumerics and hyphen only, length 1–255. The OpenAPI spec declares this `pattern` on every write schema (`POST` and `PATCH` on assets and locations, plus the `*_external_key` foreign-key fields). The same regex is enforced on `external_key`-typed list filters (`?external_key=`, `?location_external_key=`, `?parent_external_key=` on `/assets`, `/locations`, and `/reports/asset-locations`) — an invalid value returns `400 validation_error` / `code: invalid_value` at the boundary rather than silently returning an empty result set. Invalid input on write returns `400 validation_error` with `code: invalid_value`.

The reserved characters and why they're reserved:

| Character             | Reason it's reserved                                                                                                    |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `.` (period)          | path-/URL-hostile and reserved for future structural use (segment separators, file-extension idioms in partner systems) |
| `_` (underscore)      | reserved alongside `-` so partner systems standardizing on one separator don't see the other as a near-match collision  |
| ` ` (space), `/`, `:` | URL-, log-, and path-hostile; reserved to avoid surprise quoting                                                        |

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

`external_key` is **case-preserving and case-sensitive** on storage — `MyAsset` and `myasset` are distinct keys, and `WAREHOUSE-WEST` and `warehouse-west` coexist as distinct locations under the per-org partial unique index. The case mapping is preserved verbatim on every response. Pick a casing convention for your own integration to keep partner-side joins predictable, but the platform doesn't enforce one and won't silently merge case-distinct keys.

## Effective dating and `is_active` {#effective-dating-and-is-active}

Assets and locations carry both an `is_active` boolean and a pair of `valid_from` / `valid_to` timestamps. They cover two independent dimensions:

- **`is_active`** — soft-delete / hide-from-list flag. An admin or automation toggles it directly.
- **`valid_from` / `valid_to`** — bitemporal effective dating, typically driven by lifecycle events (a vehicle entering service, an asset being decommissioned). See [Date fields](./date-fields) for the wire shape and input rules.

A row is **currently effective** when:

> (`valid_from` IS NULL OR `valid_from` ≤ now) AND (`valid_to` IS NULL OR `valid_to` > now)

The default scope on list endpoints applies this predicate — temporally inactive rows are filtered out regardless of `is_active`. The surfaces that apply the currently-effective predicate by default:

- `GET /api/v1/assets`
- `GET /api/v1/locations`
- `GET /api/v1/reports/asset-locations`
- `GET /api/v1/assets/{asset_id}/history` (predicate applies to the joined location and to embedded tags)
- Embedded `tags` arrays on asset and location responses

Direct lookups by canonical `id` (`GET /api/v1/assets/{asset_id}`, `GET /api/v1/locations/{location_id}`) **do not** apply the predicate — a path-param read returns any non-deleted row. Clients holding a stale `id` can still inspect the record they remember, even after `valid_to` has passed.

`is_active` is an independent filter dimension. The default list scope returns currently-effective rows of either `is_active` value. The endpoints that accept `?is_active=` as a caller filter are a narrower set than the list above:

- `GET /api/v1/assets` — pass `?is_active=true` or `?is_active=false` to narrow further.
- `GET /api/v1/locations` — same.

`GET /api/v1/reports/asset-locations` and `GET /api/v1/assets/{asset_id}/history` apply the currently-effective predicate but do **not** declare `is_active` as a query parameter — passing `?is_active=` to either returns `400 validation_error` / `code: unknown_field`. The two embedded-`tags[]`-array surfaces don't accept query parameters at all; they ride on the parent resource response.

The substring search (`?q=`) restricts tag-value matching to active and currently-effective tags — retired tags stay out of the search corpus by design.

If your business logic needs to surface an expired record (e.g., to render a "decommissioned on …" row in your UI), use the path-param read path or your own client-side filter — the list endpoints will not surface temporally inactive rows.

### `/reports/asset-locations` scopes to currently-effective assets {#asset-locations-effective-scope}

`GET /api/v1/reports/asset-locations` applies the currently-effective predicate to the **asset side** of every row by default: a row appears only when the asset's `valid_from` is in the past AND its `valid_to` is `null` or in the future. The location-side join is also filtered through the same predicate per the bulleted list above. A row's `asset_deleted_at: null` is **not** a "currently effective" signal — it only means the asset isn't soft-deleted; the asset's `valid_to` may still have elapsed independently, in which case the row is dropped from the response. Soft-delete (`deleted_at` / `asset_deleted_at`) and temporal validity (`valid_from` / `valid_to`) are independent dimensions ([Three axes of liveness](./pagination-filtering-sorting#three-axes-of-liveness)).

To surface temporally inactive assets in the report — for retrospective "where did asset X end up before it was decommissioned" reporting — fall back to `GET /api/v1/assets/{asset_id}/history`, which carries scan-event rows without an effective-asset predicate on the asset itself.

## Tag is a polymorphic resource

`Tag` is a polymorphic resource attached to an asset or a location. The `tag_type` discriminator selects one of three kinds:

- `rfid` — RFID transponder, surfaced in generated clients as `RfidTag` (and `RfidTagRequest`)
- `ble` — Bluetooth Low Energy beacon, surfaced as `BleTag` (and `BleTagRequest`)
- `barcode` — 1D/2D barcode, surfaced as `BarcodeTag` (and `BarcodeTagRequest`)

All three kinds share the same wire shape and the same endpoints. The `/assets/{asset_id}/tags` and `/locations/{location_id}/tags` subresources accept and return all three kinds; the kind travels in the request body via `tag_type`, not in the URL. There is no per-kind subresource (no `/tags/rfid`, no `/tags/ble`) and no per-kind path variation.

At the spec level, `Tag` and `TagRequest` are `oneOf` discriminated unions over the three named subtypes above, with `tag_type` as the discriminator (`propertyName: tag_type`; mapping entries `rfid` / `ble` / `barcode`). Generated SDKs surface the three subtypes by name and narrow on `tag_type` — TypeScript clients get a discriminated union usable with `switch (tag.tag_type)`, Python clients get three concrete model classes plus the `Tag` union alias. Server-side, the resource is one row shape and the storage layer is uniform across kinds; the polymorphism is a client-side type-discoverability split, not a wire-format change.

`tag_type` is an **open (extensible) enumeration** per the [versioning policy](./versioning#open-extensible-enums-in-v1) on the **read direction**. The current set is `rfid` / `ble` / `barcode`; new variants may be added in any additive v1 minor revision without a major-version cut. Integrators consuming responses should handle unknown `tag_type` values gracefully — pass the row through untouched and fall through to a generic shape, rather than treating it as a server bug. Code that exhaustively switches on `tag_type` should include a default branch.

The **write direction is closed**: `POST /assets/{asset_id}/tags`, `POST /locations/{location_id}/tags`, and the natural-key tuple `(tag_type, value)` accept only the currently-defined variants. A write with an unrecognized `tag_type` is rejected at the boundary with `400 validation_error` / `code: invalid_value` / `params.allowed_values: ["rfid", "ble", "barcode"]`. The asymmetry is intentional — forward-compatibility on read, strict validation on write — and will be retired by the `x-extensible-enum` annotation that the planned OpenAPI 3.1 migration introduces; until then, the schema description on `Tag` / `TagRequest` calls the asymmetry out in prose.

:::note Codegen artifact: per-variant `TagType` classes
Some strict-typed generators (notably `datamodel-codegen` for Pydantic) materialize the single-value `tag_type` constants on each variant as separate enum classes — `TagType`, `TagType2`, `TagType4` (or similarly numbered names) depending on declaration order. That naming is a generator artifact of the `oneOf` discriminator pattern, not a contract: the wire is a single discriminated union with three variants today. Treat the per-variant classes as SDK internals, not API surface.
:::

:::note "Tag" is a noun with two senses
In the API surface (and this page), **tag** is a typed data primitive: the `(tag_type, value)` pair attached to an asset or a location. In RFID-domain prose elsewhere on the docs site (and in user-facing UI copy), "tag" can also mean the physical hardware label a scanner reads. Both senses are valid; this page operates on the data-primitive sense, with `tag_type` selecting which kind of physical artifact a given record represents.
:::

## Tags use a composite natural key

Tags follow the same principle as assets and locations, with a composite shape: a tag's natural key is the `(tag_type, value)` pair within an organization, enforced by the partial unique index `(org_id, tag_type, value) WHERE deleted_at IS NULL`. Uniqueness is **within kind, not across kinds** — the same `value` may exist under different `tag_type`s without conflict (a barcode `"E2-8042"` and an RFID EPC `"E2-8042"` coexist as distinct rows). Inserting a duplicate live `(tag_type, value)` for the same organization returns `409 conflict`.

Don't conflate `external_key` with `tags[].value`: assets and locations have a single string natural key (`external_key`); tags have a composite one. The `value` field _inside_ a tag is the tag's own partner-supplied handle (an EPC, a beacon ID, a barcode), scoped by `tag_type`. The `external_key` _on_ an asset or location is the resource's partner-supplied handle, scoped by resource type. They sit at different levels and are not interchangeable — an asset's `external_key` and one of its tags' `value` answer different questions.

`tag_type` is **required on every write** — `POST /api/v1/assets/{asset_id}/tags` and `POST /api/v1/locations/{location_id}/tags` both reject a body that omits the field or sends it as `null` with `400 validation_error / code=required / field=tag_type`. The spec already declared `tag_type` required on each `*TagRequest` subtype for OpenAPI discriminator semantics, and the service now matches: hand-written raw-HTTP callers, codegen consumers, and `curl` all need to pass `tag_type` explicitly for every attach — there is no server-side default to RFID.

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

| Endpoint                                               | Required scope    | Behavior                                                                                                                             |
| ------------------------------------------------------ | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `POST /api/v1/assets/{asset_id}/tags`                  | `assets:write`    | Attach a tag to the asset. Body is `{tag_type, value}`; returns the new tag.                                                         |
| `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`       | `assets:write`    | Detach a tag from the asset. First call returns 204; a repeated call returns 404 — see [Errors → Idempotency](./errors#idempotency). |
| `POST /api/v1/locations/{location_id}/tags`            | `locations:write` | Attach a tag to the location. Same body and response shape as the asset variant.                                                     |
| `DELETE /api/v1/locations/{location_id}/tags/{tag_id}` | `locations:write` | Detach a tag from the location. Same 204-then-404 semantics as the asset variant.                                                    |

Tag writes use the parent resource's write scope, not a separate `tags:write` — there is no per-tag scope.

The same endpoint accepts all three kinds — the discriminator travels in the body:

```bash
# Attach an RFID tag to an asset
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"tag_type": "rfid", "value": "E2-8042-2D-19F0-AB10"}' \
     "$BASE_URL/api/v1/assets/4287/tags"

# Attach a BLE beacon to the same asset
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"tag_type": "ble", "value": "C0:1A:DA:7E:F0:01"}' \
     "$BASE_URL/api/v1/assets/4287/tags"

# Attach a barcode to a location
curl -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"tag_type": "barcode", "value": "0123456789012"}' \
     "$BASE_URL/api/v1/locations/82/tags"
```

`tag_type` is an **open (extensible) discriminator enum** ([Tag is a polymorphic resource](#tag-is-a-polymorphic-resource) covers the forward-compat contract). The current variants — `rfid`, `ble`, `barcode` — each map to a different physical artifact and to a named subtype in the discriminated union (`RfidTag`, `BleTag`, `BarcodeTag`). New variants may be added in any v1 minor revision; the typed-client regeneration step is the integrator's signal that a new variant has shipped. The API does **not** validate the per-kind shape of `value` — there's no length check that rejects a 12-byte EPC sent as `tag_type: barcode`, no UUID check on `ble`. The constraints are the global ones: `value` must be 1–255 characters and the `(tag_type, value)` pair must be unique within the organization for live (non-deleted) rows. Inserting a duplicate live pair returns `409 conflict`; the [errors](./errors) page covers the response shape.

`value` is matched **as an exact string** within `(org_id, tag_type)` for uniqueness, attach, and the embedded `tags[]` array on parent reads. There is no normalization (no case-folding, no whitespace stripping). Substring search across tag values is available only through the parent resource's [`?q=`](./pagination-filtering-sorting#substring-search) filter, which restricts to active and currently-effective tags.

`tag_type` is required on every attach (covered above) — a raw-HTTP body of `{"value": "E2-..."}` on an asset POST returns `400 validation_error / code=required / field=tag_type`. Generated SDKs already require it because the discriminated subtypes declare `tag_type` `required`; hand-written HTTP clients must send it explicitly.

## "Scan event" is a domain concept, not an API resource {#scan-event-vocabulary}

"Scan event" describes a reader-detected tag observation (RFID/BLE pings recorded by handhelds and fixed readers). The TrakRF docs and the TrakRF web app use the term throughout, but **scan events are not a top-level API resource**: there is no `scan_event` schema in the OpenAPI spec, no `/api/v1/scans` or `/api/v1/scan_events` endpoint, and no `scan_event_id` field on any response.

Scan-event-derived data is projected through two endpoints:

- `GET /api/v1/assets/{asset_id}/history` — the per-asset event timeline (timestamp, location, duration), authoritative for "what did this asset do over time?"
- `GET /api/v1/reports/asset-locations` — the latest snapshot per asset, authoritative for "where is each asset right now?"

Both are gated by the `tracking:read` scope (see [Authentication → Scopes](./authentication#scopes)) — the same scope, because both are projections of the same underlying event stream.

When [webhooks](./webhooks) ship, events will fire on scan events but the payloads address **assets and locations**, not scan events directly — there's no scan-event id to subscribe to or look up. An ingestor planning a scan-driven workflow should think in terms of asset history and current location, not in terms of a scan-event resource.
