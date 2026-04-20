---
sidebar_position: 3
---

# Resource identifiers

Every resource in the TrakRF API has **two** IDs:

| ID | Type | Where you see it | How you use it |
|---|---|---|---|
| `identifier` | string | URL path params, response bodies | The business-meaningful ID (e.g. `ASSET-0001`, `LOC-0001`). This is the one clients key on. |
| `surrogate_id` | integer | Response bodies only | Internal-use stable ID; visible so you can correlate across related responses, but not required on the wire. |

This page explains where each form appears and why integrators should key on `identifier`, not `surrogate_id`.

## URL path parameters — `identifier` only

Single-resource read endpoints take the `identifier` (string) as the URL path parameter:

```bash
# Correct — takes the business identifier
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets/ASSET-0001
```

The integer `surrogate_id` is **not** accepted on reads:

```bash
# Wrong — returns 404 not_found
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets/27545709
```

This applies to every GET endpoint with a path param:

- `GET /api/v1/assets/{identifier}`
- `GET /api/v1/assets/{identifier}/history`
- `GET /api/v1/locations/{identifier}`

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

**Clients should key on `identifier`.** `surrogate_id` is stable across updates to a given record but is opaque to integrators and not guaranteed stable across environments.

## Writes (PUT, DELETE)

The published OpenAPI spec at [`/api`](/api) currently shows `{id}` on write-path parameters. This will align with the read-path `{identifier}` convention under [TRA-407](https://linear.app/trakrf/issue/TRA-407). Until that lands, the interactive reference is authoritative for the exact shape each write endpoint accepts. This page will be updated when the alignment ships.

## Session-auth-only exception

There is one SPA-only path that takes the integer `surrogate_id`:

- `GET /api/v1/assets/by-id/{surrogate_id}/history`

This path is accessible **only** with session cookies (used by the first-party TrakRF web app). API-key requests receive `401 unauthorized`. Integrators using API keys should always use `GET /api/v1/assets/{identifier}/history` with the string identifier. See [Private endpoints](./private-endpoints) for the full list of SPA-only paths.
