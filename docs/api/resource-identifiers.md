---
sidebar_position: 3
---

# Resource identifiers

Every resource in the TrakRF API has **two** IDs:

| ID             | Type    | Where you see it                 | How you use it                                                                                                                                                                      |
| -------------- | ------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `identifier`   | string  | URL path params, response bodies | The business-meaningful ID (e.g. `ASSET-0001`, `LOC-0001`). This is the one clients key on.                                                                                         |
| `surrogate_id` | integer | Response bodies only             | Stable integer ID retained for backward compatibility with earlier TrakRF tooling. Visible so clients that already correlate on it keep working; `identifier` is the canonical key. |

This page explains where each form appears, why integrators should key on `identifier`, and what the additional hierarchy-helper fields on locations mean.

## URL path parameters — `identifier` only

Single-resource read endpoints take the `identifier` (string) as the URL path parameter:

```bash
# Correct — takes the business identifier
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/ASSET-0001"
```

The integer `surrogate_id` is **not** accepted on reads:

```bash
# Wrong — returns 404 not_found
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/27545709"
```

This applies to every GET endpoint with a path param:

- `GET /api/v1/assets/{identifier}`
- `GET /api/v1/assets/{identifier}/history`
- `GET /api/v1/locations/{identifier}`

### Identifiers are case-sensitive {#case-sensitivity}

Identifiers on the path are matched exactly as stored. `GET /api/v1/assets/ASSET-0001` returns `200`; `GET /api/v1/assets/asset-0001` returns `404 not_found`. Pick a casing convention at the point you `POST` the resource (the request-body `identifier` is what subsequent reads must quote) and stick with it — the API does not normalize case on lookup.

## Response bodies

Responses return both IDs so clients that need to correlate across related records (e.g. joining asset history back to a specific asset record) can use the stable `surrogate_id` as a foreign key:

```json
{
  "data": {
    "identifier": "ASSET-0001",
    "surrogate_id": 27545709,
    "name": "Warehouse forklift",
    "current_location": "LOC-0001"
  }
}
```

**Clients should key on `identifier`.** `surrogate_id` is retained for backward compatibility with earlier TrakRF tooling — it's stable across updates to a given record, but opaque to integrators, not guaranteed stable across environments, and not accepted on any public URL path.

## Location hierarchy fields (`path`, `depth`) {#location-hierarchy-fields}

Location responses include two additional fields that describe where the node sits in the location tree:

| Field   | Type    | Meaning                                                                                                                                                              |
| ------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `path`  | string  | The location's position in the tree as a dot-separated [`ltree`](https://www.postgresql.org/docs/current/ltree.html) label path, e.g. `WAREHOUSE-A.AISLE-3.SHELF-B`. |
| `depth` | integer | The number of labels in `path` — `1` for a root location, `2` for its direct children, and so on.                                                                    |

Example (abbreviated) from `GET /api/v1/locations`:

```json
{
  "data": [
    {
      "identifier": "WAREHOUSE-A",
      "name": "Warehouse A",
      "path": "WAREHOUSE-A",
      "depth": 1,
      "parent": null
    },
    {
      "identifier": "SHELF-B",
      "name": "Shelf B",
      "path": "WAREHOUSE-A.AISLE-3.SHELF-B",
      "depth": 3,
      "parent": "AISLE-3"
    }
  ]
}
```

Each label in `path` preserves the original casing and hyphens of the corresponding `identifier` — `WAREHOUSE-A` stays `WAREHOUSE-A`, not `warehouse_a`. `path` is a derived helper for tree traversal, not a second identifier. Don't try to look up a location by its `path` — URL path params still take the `identifier` (see [URL path parameters](#url-path-parameters--identifier-only)).

These fields are most useful for UI renderers that want to sort or indent a flat list by tree position without making follow-up calls. For explicit hierarchy traversal, prefer the dedicated endpoints (`GET /api/v1/locations/{identifier}/ancestors`, `/children`, `/descendants`) — see [Pagination, filtering, sorting](./pagination-filtering-sorting) for envelope and filtering conventions.

## Writes (PUT, DELETE)

The published OpenAPI spec at [`/api`](/api) currently shows `{id}` on write-path parameters. This will align with the read-path `{identifier}` convention under [TRA-407](https://linear.app/trakrf/issue/TRA-407). Until that lands, the interactive reference is authoritative for the exact shape each write endpoint accepts. This page will be updated when the alignment ships.

## Session-auth-only exception

There is one SPA-only path that takes the integer `surrogate_id`:

- `GET /api/v1/assets/by-id/{surrogate_id}/history`

This path is accessible **only** with session cookies (used by the first-party TrakRF web app). API-key requests receive `401 unauthorized`. Integrators using API keys should always use `GET /api/v1/assets/{identifier}/history` with the string identifier. See [Private endpoints](./private-endpoints) for the full list of SPA-only paths.
