---
sidebar_position: 1
title: Quickstart
---

# Quickstart

Goes from "I just signed up" to "I called the TrakRF API and got a `200` back" in about ten minutes, with nothing but an HTTP client.

If you're already familiar with API-key-authenticated REST APIs, the TL;DR is: mint a JWT at **Settings → API Keys**, send it as `Authorization: Bearer <jwt>`, and hit `https://app.trakrf.id/api/v1/...`. The full walkthrough follows.

## 1. Mint an API key

1. Sign in at [app.trakrf.id](https://app.trakrf.id) with an admin account.
2. Go to **Settings** → **API Keys** in the left nav.
3. Click **Create Key**. Give it a descriptive name (e.g. `"local-dev"`). For this quickstart, `assets:read` and `locations:read` are enough; see [Authentication → Scopes](./authentication#scopes) for the full list.
4. Submit. The full JWT is displayed **once**. Copy it immediately — it cannot be shown again.
5. Save it to an environment variable:

   ```bash
   export TRAKRF_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```

Full detail: [Authentication → Mint your first API key](./authentication#mint-your-first-api-key).

## 2. First read call

`GET /api/v1/locations/current` returns a snapshot of where TrakRF last saw each asset. It's cheap, needs only `locations:read`, and tells you end-to-end that your key works:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/locations/current
```

A successful response looks like:

```json
{
  "data": [
    {
      "asset": "ASSET-0001",
      "location": "LOC-0001",
      "last_seen": "2026-04-20T14:32:18Z"
    }
  ],
  "limit": 50,
  "offset": 0,
  "total_count": 1
}
```

Troubleshooting the first call:

- `401 unauthorized` — the key is missing, malformed, or revoked. Re-check the `Authorization` header.
- `403 forbidden` — the key lacks `locations:read`. Create a new key with the right scope.
- `429 rate_limited` — you're over budget; wait the `Retry-After` seconds. See [Rate limits](./rate-limits).

## 3. Round-trip: create, read, update, delete

This walks through the write path end-to-end with an asset. It needs `assets:write` on the key (and `assets:read` if you want to verify via GET).

```bash
# Create
curl -X POST https://app.trakrf.id/api/v1/assets \
  -H "Authorization: Bearer $TRAKRF_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
        "identifier": "ASSET-QUICKSTART",
        "name": "Quickstart test asset",
        "type": "generic"
      }'

# Read it back
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets/ASSET-QUICKSTART

# Update
curl -X PUT https://app.trakrf.id/api/v1/assets/ASSET-QUICKSTART \
  -H "Authorization: Bearer $TRAKRF_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Quickstart test asset (renamed)"}'

# Delete
curl -X DELETE https://app.trakrf.id/api/v1/assets/ASSET-QUICKSTART \
  -H "Authorization: Bearer $TRAKRF_API_KEY"
```

Each request echoes back the resource (or `204 No Content` on delete) wrapped in the standard `{ "data": ... }` envelope.

## 4. Alternative: Postman

Prefer a GUI? The same API surface is available as a ready-to-import Postman collection:

1. Download [`trakrf-api.postman_collection.json`](/api/trakrf-api.postman_collection.json).
2. In Postman, **Import → File** and select it.
3. Set the collection variables:
   - `baseUrl` → `https://app.trakrf.id/api/v1`
   - `apiKey` → the JWT from step 1
4. Collection auth is preconfigured as a Bearer token referencing `{{apiKey}}`.

Full detail: [Postman collection](./postman).

## 5. Raw spec for codegen

If you'd rather generate a typed client, the OpenAPI spec is available in both formats:

- [`/api/openapi.json`](/api/openapi.json) (JSON)
- [`/api/openapi.yaml`](/api/openapi.yaml) (YAML)

Feed either into `openapi-generator-cli`, NSwag, `oapi-codegen`, etc. to scaffold client code in your language. The spec is regenerated from the Go handlers on every platform release, so the generated client stays in sync with the running service.

## Next steps

- [Interactive reference](/api) — every endpoint, request/response shape, try-it-now widget
- [Authentication](./authentication) — scopes, key lifecycle, rotation
- [Pagination, filtering, sorting](./pagination-filtering-sorting) — conventions for list endpoints
- [Resource identifiers](./resource-identifiers) — why you key on `identifier`, not `surrogate_id`
- [Errors](./errors) — envelope, catalog, retry guidance
- [Rate limits](./rate-limits) — budgets, headers, `Retry-After`
- [Versioning](./versioning) — v1 stability commitment
