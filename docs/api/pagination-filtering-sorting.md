---
sidebar_position: 4
title: Pagination, filtering, sorting
---

# Pagination, filtering, sorting

All list endpoints in the TrakRF v1 API follow the same shape: offset-based pagination, repeatable filters, and comma-separated sort fields. This page documents the conventions and shows worked examples per resource.

## Response envelope

Every list endpoint returns the same envelope:

```json
{
  "data": [
    /* resource objects */
  ],
  "limit": 50,
  "offset": 0,
  "total_count": 1873
}
```

| Field         | Meaning                                                                                                          |
| ------------- | ---------------------------------------------------------------------------------------------------------------- |
| `data`        | The page of results. Always an array. Empty pages return `[]`, never `null`.                                     |
| `limit`       | The page size the server honored (echoes your request or the default).                                           |
| `offset`      | The offset the server honored.                                                                                   |
| `total_count` | Total matching rows across the full filtered result set. Use this to compute page counts or show "N of M" in UI. |

## Pagination

Offset-based. Two query params control the page:

| Param    | Default | Max   | Notes                                                                                                                                                                                                               |
| -------- | ------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `limit`  | `50`    | `200` | Page size. Values over 200 are rejected with `400 validation_error` (`fields[].code = too_large`). See [Errors → Path- and query-parameter validation errors](./errors#path-and-query-parameter-validation-errors). |
| `offset` | `0`     | —     | Rows to skip. `offset=50&limit=50` gets the second page.                                                                                                                                                            |

Shell examples below use a `$BASE_URL` env var — set it to `https://app.trakrf.id` for production or `https://app.preview.trakrf.id` for preview. See [Authentication → Base URL](./authentication#base-url).

```bash
# First page (default limit)
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets"

# Second page of 100
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?limit=100&offset=100"
```

**Iterating a large result set:** loop until `offset + len(data) >= total_count`:

```python
offset = 0
limit = 200
while True:
    resp = requests.get(url, params={"limit": limit, "offset": offset},
                        headers={"Authorization": f"Bearer {key}"}).json()
    for row in resp["data"]:
        process(row)
    offset += len(resp["data"])
    if offset >= resp["total_count"] or not resp["data"]:
        break
```

### Consistency note

Offset pagination reflects the table state at each request. If rows are inserted or deleted between pages, results can shift — a row near the page boundary might be seen twice or skipped. For workloads that need strict consistency across pages, filter by a time range (`from`/`to` on `GET /api/v1/assets/{asset_id}/history`) or by a stable identifier range rather than paginating a mutable result set.

## Filtering

Filter parameters are specific to each resource. All filters are query parameters; when a filter accepts multiple values, pass the parameter multiple times (not comma-separated).

**Default scope.** Every list endpoint applies a [currently-effective predicate](./resource-identifiers#effective-dating-and-is-active) on top of any filter you pass — rows with `valid_to` in the past or `valid_from` in the future are excluded by default. The path-param read paths (`GET /api/v1/assets/{asset_id}`, `GET /api/v1/locations/{location_id}`) do not apply this predicate; use them to inspect a record you already hold an `id` for.

:::caution `is_active` and `include_deleted` are independent toggles
`is_active` is a domain field — whether a resource is currently active per business logic. `include_deleted` is a lifecycle/system toggle — whether soft-deleted rows appear in the response at all. Both `/assets` and `/locations` (and `/reports/asset-locations`) accept `include_deleted=true` (default `false`); the four combinations of `is_active=*&include_deleted=true` are independent and all valid.

- `?is_active=false` on `/assets` does **not** return soft-deleted rows — it returns currently-effective rows whose `is_active` flag is `false`. Soft-deleted rows are filtered out regardless of `is_active`; pass `?include_deleted=true` to surface them.
- `?include_deleted=true` returns currently-effective rows AND soft-deleted rows. Each row carries a deletion timestamp — `deleted_at` on the per-resource lists `/assets` and `/locations`, `asset_deleted_at` on the cross-resource report `/reports/asset-locations` — `null` for live rows, populated with the deletion timestamp for soft-deleted ones. Null-check the field, don't key-check. See [Resource identifiers → Soft-delete visibility on lists](./resource-identifiers#soft-delete-visibility) for why the per-resource form drops the prefix.
  :::

| Endpoint                                | Filter params                                                                                                                                        |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /api/v1/assets`                    | `external_key` (repeatable), `location_id` (repeatable), `location_external_key` (repeatable), `is_active`, `include_deleted` (default `false`), `q` |
| `GET /api/v1/locations`                 | `external_key` (repeatable), `parent_id` (repeatable), `parent_external_key` (repeatable), `is_active`, `include_deleted` (default `false`), `q`     |
| `GET /api/v1/reports/asset-locations`   | `location_id` (repeatable), `location_external_key` (repeatable), `include_deleted` (default `false`), `q`                                           |
| `GET /api/v1/assets/{asset_id}/history` | `from`, `to` (RFC 3339 timestamps); also accepts the standard `limit` / `offset` / `sort` from the [Pagination](#pagination) section                 |

The `external_key` filter on `/assets` and `/locations` is the [`?external_key=` natural-key lookup](./resource-identifiers#natural-key-lookup-uses-external_key) — repeatable as `?external_key=A&external_key=B` for batch resolution.

### Paired-by-id-and-by-natural-key filters are mutually exclusive

When a list endpoint accepts both an id form and a natural-key form for the same logical relationship — `location_id` / `location_external_key` on `/assets`, `parent_id` / `parent_external_key` on `/locations` — the two forms are **mutually exclusive in a single request**. Sending both returns `400 validation_error` with `code: ambiguous_fields` and one `fields[]` entry per offending param. State the rule once for all such pairs rather than per-parameter.

To filter for the union of two values, repeat **one** form: `?location_id=42&location_id=43`. To filter for the union across both forms, resolve to one form first (typically `id`, since the natural-key lookup gives you the `id` for free).

The same `ambiguous_fields` rule applies to `POST` request bodies on `/assets` and `/locations` (surrogate XOR natural-key — pick one). `PATCH` does **not** emit `ambiguous_fields` — natural-key reference fields follow the uniform [accept-if-matches, reject-if-differs](./resource-identifiers#read-shape-vs-write-shape) rule independently per field, so both forms supplied with matching values are silently accepted, and a differing value generates a per-field `read_only` entry. See [Resource identifiers → Paired-key behavior per verb](./resource-identifiers#paired-key-behavior-per-verb) for the full matrix and the `fk_not_found` envelope returned when either form references a non-existent row.

### Repeatable filters

Repeat the parameter to express "any of":

```bash
# Assets currently at LOC-A OR LOC-B (by external_key)
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?location_external_key=LOC-A&location_external_key=LOC-B"

# Same intent, by canonical id
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?location_id=42&location_id=43"
```

Comma-separated values in a single `location_external_key=LOC-A,LOC-B` parameter are **not** parsed as multiple filters — the server sees a single value with a literal comma. For `external_key`-typed filters (`external_key`, `location_external_key`, `parent_external_key`) this returns `400 validation_error` / `code: invalid_value` because the comma is outside the [`external_key` regex](./resource-identifiers#external_key-value-rules); the same boundary applies to slashes, colons, spaces, and any other reserved character. Pass the parameter once per value to express "any of".

### Boolean filters

Pass `true` or `false`. Omitting `is_active` returns rows of either value (the default scope still applies the [currently-effective predicate](./resource-identifiers#effective-dating-and-is-active) — `is_active` is an independent dimension). Omitting `include_deleted` defaults to `false` (soft-deleted rows are filtered out):

```bash
# Active currently-effective assets only (default soft-delete behavior)
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?is_active=true"

# Include soft-deleted rows alongside live ones; null-check deleted_at on each row
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?include_deleted=true"
```

### Substring search

`q` performs a substring search (case-insensitive) across the resource's most commonly queried fields:

| Endpoint                              | Fields matched                                           |
| ------------------------------------- | -------------------------------------------------------- |
| `GET /api/v1/assets`                  | `name`, `external_key`, `description`, active tag values |
| `GET /api/v1/locations`               | `name`, `external_key`, `description`, active tag values |
| `GET /api/v1/reports/asset-locations` | asset `name`, asset `external_key`, active tag values    |

```bash
# Find assets whose name, external_key, description, or tag value matches "forklift"
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?q=forklift"
```

### Time range (history)

`GET /api/v1/assets/{asset_id}/history` accepts `from` and `to` as [RFC 3339](https://datatracker.ietf.org/doc/html/rfc3339) timestamps (a subset of ISO 8601). The server validates the RFC 3339 profile — e.g. `2026-04-01T00:00:00Z` or `2026-04-01T09:00:00-04:00`. Either bound may be omitted:

```bash
# Since the start of 2026-04
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287/history?from=2026-04-01T00:00:00Z"
```

:::tip Common confusion: `from`/`to` is not `valid_from`/`valid_to`
`from` / `to` (history query parameters) and `valid_from` / `valid_to` (resource schema fields) share a similar shape but answer different questions. The two pairs visually collapse in URL paths and log lines (`from=2026-04-01T00:00:00Z` is one trim away from `valid_from=2026-04-01T00:00:00Z`), so it's worth knowing which is which:

| Pair                      | Where it lives                                          | What it bounds                                                                                                   |
| ------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `from` / `to`             | Query params on `GET /api/v1/assets/{asset_id}/history` | The **observation window** — which scan events to include in the response. Scan timestamps, not effective dates. |
| `valid_from` / `valid_to` | Resource schema fields ([Date fields](./date-fields))   | The resource's **effective-dating bounds** — when the asset itself became and stops being effective.             |

The history endpoint applies the [currently-effective predicate](./resource-identifiers#effective-dating-and-is-active) to the joined location and embedded tags inside each event, but the `from` / `to` query params are independent of that. Renaming the history pair to something like `since` / `until` is a v2 consideration; in v1 the names are what they are.
:::

## Sorting

All list endpoints take a `sort` parameter. Comma-separated for multi-key sorts, `-` prefix for descending:

```bash
# Newest first
?sort=-created_at

# By name ascending
?sort=name

# Newest first, then external_key as tiebreaker
?sort=-created_at,external_key
```

Sortable fields vary per resource. The exact enum each endpoint accepts:

| Endpoint                                | Sort fields (each also accepts `-` prefix for descending)  |
| --------------------------------------- | ---------------------------------------------------------- |
| `GET /api/v1/assets`                    | `external_key`, `name`, `created_at`, `updated_at`         |
| `GET /api/v1/locations`                 | `external_key`, `name`, `created_at`                       |
| `GET /api/v1/reports/asset-locations`   | `last_seen`, `asset_external_key`, `location_external_key` |
| `GET /api/v1/assets/{asset_id}/history` | `timestamp`                                                |

Unknown sort fields on an endpoint with a sort allowlist return `400 validation_error` with `fields[].message: "unknown sort field: <name>"` — fix the field name and retry. Generated clients with strict typing reject unknown sort fields at compile time; weaker generators receive the 400 from the server. When no `sort` is supplied, results default to the resource's natural ordering — `external_key` ascending, with `id` ascending as a deterministic tiebreaker, on the asset and location collections; `/reports/asset-locations` defaults to `-last_seen`.

### Sub-resource list endpoints use a fixed sort order

The three location-tree subresource lists — `/ancestors`, `/children`, `/descendants` — paginate but do **not** accept a `sort` query parameter. Each has a single natural order that's the only meaningful one for its shape, and the order is encoded directly in the OpenAPI `description` for the operation.

| Endpoint                                          | Fixed sort order                                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `GET /api/v1/locations/{location_id}/ancestors`   | Root first (walking up the `parent_id` chain), `id` ascending as a tiebreaker.              |
| `GET /api/v1/locations/{location_id}/children`    | `name` ascending, `id` ascending as a tiebreaker.                                           |
| `GET /api/v1/locations/{location_id}/descendants` | Depth-first tree order (preorder traversal of the subtree), `id` ascending as a tiebreaker. |

The `id` tiebreaker makes the order deterministic across pages. Sending `?sort=...` on any of these three returns `400 validation_error` with `fields[].message: "sort parameter not supported on this endpoint"` — distinct from the `"unknown sort field: <name>"` wording emitted on endpoints _with_ a sort allowlist, so a client doesn't misread the rejection as a typo in the field name. Generated clients won't produce the option in the first place because the parameter isn't declared in the OpenAPI spec.

## Validator behavior on writes

Three rules govern how the validator handles `POST` and `PATCH` request bodies. They're separate from list-endpoint filters but they're the next thing partners ask about once they've done a `GET` and want to write back, so they live here:

**Read-only fields on `PATCH` follow a uniform accept-if-matches, reject-if-differs rule.** Server-managed metadata (`id`, `created_at`, `updated_at`, `deleted_at`), the `tags` collection, and every natural-key reference field (`external_key` on both resources, `parent_external_key` on locations, `location_id` and `location_external_key` on assets) obey the same contract: a body value matching the current resource state is silently normalized out (the request returns `200` and other fields apply normally), and a differing value returns `400 validation_error` / `code: read_only` with a `message` naming the proper write path (`POST /{resource}/{id}/rename` for `*_external_key`, the `/tags` subresource for `tags`, "record a scan event" for asset `location_*`, "server-managed" wording for `id` / timestamps). A naive `GET` → `PATCH` of the entire response object **works without scrubbing** — every read-only field echoes silently because its value matches the current state. The per-resource set and per-field hints live in [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape).

**Truly unknown fields are rejected.** A field name that doesn't appear on either the read or the write schema (a typo, an off-resource field, a `metadata`-on-locations attempt) returns `400 validation_error` with `fields[].code: unknown_field`. Distinct from `read_only` (the field is declared on the read shape and has a different mutation surface) and from `invalid_value` (the field name was recognized but the value was wrong) so a validation UI can branch on the cause.

## Worked examples per resource

### Assets

List active assets currently at one of two locations (by `external_key`), newest first, 100 per page:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?is_active=true&location_external_key=LOC-A&location_external_key=LOC-B&sort=-created_at&limit=100"
```

### Locations

List immediate children of a parent location (filtered by the parent's `external_key`), sorted by `external_key`:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations?parent_external_key=WAREHOUSE-A&sort=external_key&limit=200"
```

For explicit ancestor/descendant traversal, use the dedicated endpoints: `GET /api/v1/locations/{location_id}/ancestors`, `/children`, `/descendants`.

### Asset-locations report

Where each asset was last seen — one row per asset. Filter by the location(s) you care about:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/reports/asset-locations?location_external_key=DOCK-1&sort=-last_seen"
```

### History

Asset movement history over a window, newest event first (path takes the canonical integer asset `id`):

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287/history?from=2026-04-01T00:00:00Z&to=2026-04-30T23:59:59Z&sort=-timestamp&limit=200"
```

## Related

- [Quickstart](./quickstart) — first successful call
- [Resource identifiers](./resource-identifiers) — canonical `id`, natural-key `external_key`, and the `?external_key=` list filter
- [Errors](./errors) — what `400 bad_request` on a malformed filter or sort looks like
- [Interactive reference](/api) — per-endpoint parameter catalog
