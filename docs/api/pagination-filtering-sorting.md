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

### Non-paginated list exceptions {#non-paginated-exceptions}

The location-hierarchy traversal endpoints return a list envelope **without** `limit`, `offset`, or `total_count`:

- `GET /api/v1/locations/{identifier}/ancestors`
- `GET /api/v1/locations/{identifier}/children`
- `GET /api/v1/locations/{identifier}/descendants`

```json
{
  "data": [
    /* location objects */
  ]
}
```

Each response is a full tree segment (a path to the root, the direct children, or the entire subtree), not a page of a larger result set. Pagination doesn't apply — don't expect `total_count` to appear, and don't retry with `offset` to get more. If you need to paginate descendants of a large subtree, use `GET /api/v1/locations?parent={identifier}` (the filtered list form, which is paginated) instead.

## Pagination

Offset-based. Two query params control the page:

| Param    | Default | Max   | Notes                                                           |
| -------- | ------- | ----- | --------------------------------------------------------------- |
| `limit`  | `50`    | `200` | Page size. Values over 200 are rejected with `400 bad_request`. |
| `offset` | `0`     | —     | Rows to skip. `offset=50&limit=50` gets the second page.        |

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

Offset pagination reflects the table state at each request. If rows are inserted or deleted between pages, results can shift — a row near the page boundary might be seen twice or skipped. For workloads that need strict consistency across pages, filter by a time range (`from`/`to` on history endpoints) or by a stable identifier range rather than paginating a mutable result set.

## Filtering

Filter parameters are specific to each resource. All filters are query parameters; when a filter accepts multiple values, pass the parameter multiple times (not comma-separated).

| Endpoint                                  | Filter params                                     |
| ----------------------------------------- | ------------------------------------------------- |
| `GET /api/v1/assets`                      | `location` (repeatable), `is_active`, `type`, `q` |
| `GET /api/v1/locations`                   | `parent` (repeatable), `is_active`, `q`           |
| `GET /api/v1/locations/current`           | `location` (repeatable), `q`                      |
| `GET /api/v1/assets/{identifier}/history` | `from`, `to` (RFC 3339 timestamps)                |

### Repeatable filters

Repeat the parameter to express "any of":

```bash
# Assets currently at LOC-A OR LOC-B
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?location=LOC-A&location=LOC-B"
```

Comma-separated values in a single `location=LOC-A,LOC-B` parameter are **not** parsed as multiple filters — the server sees a single value with a literal comma.

### Boolean filters

Pass `true` or `false`. Omitting the filter returns all values (active and inactive):

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?is_active=true"
```

### Fuzzy search

`q` performs a fuzzy search across the resource's most commonly queried fields:

| Endpoint                        | Fields matched                      |
| ------------------------------- | ----------------------------------- |
| `GET /api/v1/assets`            | `name`, `identifier`, `description` |
| `GET /api/v1/locations`         | `name`, `identifier`, `description` |
| `GET /api/v1/locations/current` | asset `name`, asset `identifier`    |

```bash
# Find assets whose name, identifier, or description matches "forklift"
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?q=forklift"
```

`q` is case-insensitive and matches substrings.

### Time range (history)

`GET /api/v1/assets/{identifier}/history` accepts `from` and `to` as [RFC 3339](https://datatracker.ietf.org/doc/html/rfc3339) timestamps (a subset of ISO 8601). The server validates the RFC 3339 profile — e.g. `2026-04-01T00:00:00Z` or `2026-04-01T09:00:00-04:00`. Either bound may be omitted:

```bash
# Since the start of 2026-04
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/ASSET-0001/history?from=2026-04-01T00:00:00Z"
```

## Sorting

All list endpoints take a `sort` parameter. Comma-separated for multi-key sorts, `-` prefix for descending:

```bash
# Newest first
?sort=-created_at

# By type ascending, then name ascending
?sort=type,name

# Active status descending, then identifier ascending
?sort=-is_active,identifier
```

Sortable fields vary per resource; the interactive reference at [`/api`](/api) lists the exact set each endpoint accepts. Unknown sort fields return `400 bad_request`. When no `sort` is supplied, results default to the resource's natural ordering (typically identifier ascending).

## Worked examples per resource

### Assets

List active forklifts currently at one of two locations, sorted by most-recently-seen first, 100 per page:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?is_active=true&type=forklift&location=LOC-A&location=LOC-B&sort=-last_seen&limit=100"
```

### Locations

List all descendants of a parent location (via filter), sorted by identifier:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations?parent=WAREHOUSE-A&sort=identifier&limit=200"
```

For explicit ancestor/descendant traversal, use the dedicated endpoints: `GET /api/v1/locations/{identifier}/ancestors`, `/children`, `/descendants`.

### Current locations

Where each asset was last seen — one row per asset. Filter by the location(s) you care about:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/locations/current?location=DOCK-1&sort=-last_seen"
```

### History

Asset movement history over a window:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/ASSET-0001/history?from=2026-04-01T00:00:00Z&to=2026-04-30T23:59:59Z&limit=200"
```

## Related

- [Quickstart](./quickstart) — first successful call
- [Resource identifiers](./resource-identifiers) — `identifier` vs `surrogate_id`
- [Errors](./errors) — what `400 bad_request` on a malformed filter or sort looks like
- [Interactive reference](/api) — per-endpoint parameter catalog
