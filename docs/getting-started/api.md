---
sidebar_position: 3
title: Using the API
---

# Getting started — using the API

This page takes you from "I just signed up" to "I called the TrakRF API and got a `200` back" in about 10 minutes, using only standard HTTP tools. It mirrors the [UI quickstart](./ui) — pick whichever track matches your integration plan.

:::note Preview environment
If your account lives on the preview stack, replace `app.trakrf.id` with `app.preview.trakrf.id` everywhere on this page. The API surface is identical; only the host differs.
:::

## What you'll need

- A TrakRF account. Sign up at [app.trakrf.id](https://app.trakrf.id) if you don't have one yet.
- An API client of your choice — `curl`, Postman, HTTPie, or your language's standard HTTP library. This guide uses `curl` in examples.
- 10 minutes.

## 1. Mint your first API key

1. Sign in at [app.trakrf.id](https://app.trakrf.id).
2. Open the **avatar menu** in the top-right corner and choose **API Keys**. (The left-nav **Settings** page configures devices — not keys.)
3. Click **New key**. Give it a descriptive name (e.g. "local dev"), choose scopes (`locations:read` and `scans:read` are enough for this quickstart — the endpoint you'll call is gated by `scans:read`), and submit.
4. **Copy the JWT immediately.** It's shown once at creation time and can't be recovered later.
5. Save it to an environment variable for the next steps:

   ```bash
   export TRAKRF_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```

Full detail: [Authentication → Mint your first API key](../api/authentication#mint-your-first-api-key).

## 2. Make your first call

The `/api/v1/locations/current` endpoint returns a snapshot of where TrakRF last saw each asset. It's cheap, requires `scans:read`, and gives you a live signal that your key works:

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

The `data` array holds one item per asset that has ever been scanned. Each item is `{ asset, location, last_seen }` where `asset` and `location` are the business **identifiers** (not integer surrogate IDs — see [Resource identifiers](../api/resource-identifiers) for why).

If you get a `401`, the key is malformed or not being sent in the header. If you get a `403`, the body will name the missing scope — for this endpoint it'll be `"Missing required scope: scans:read"`. If you get a `429`, you're being rate-limited — see [Rate limits](../api/rate-limits). If you're calling from browser JavaScript and getting a CORS error with no body, the API is server-to-server only ([details](../api/authentication#server-to-server)).

## 3. Interpret the response

The two key concepts integrators trip on:

- **`identifier` vs `surrogate_id`** — every resource has a human-meaningful string identifier (what you see in URLs and as `asset` / `location` values above) and an integer surrogate_id (returned in full resource objects). Always key on `identifier`. Full convention: [Resource identifiers](../api/resource-identifiers).
- **Response envelope** — most endpoints wrap payloads in `{ "data": ..., ... }`. List endpoints add pagination metadata (`limit`, `offset`, `total_count`) — see [Pagination, filtering, sorting](../api/pagination-filtering-sorting). The exception is `GET /api/v1/orgs/me` (see [Private endpoints: /orgs/me](../api/private-endpoints#orgs-me)).

## 4. Next steps

- **[API docs landing](../api/)** — concept-guide map and starting points.
- **[Interactive reference](/api)** — every endpoint, request/response shape, try-it-now widget.
- **[Pagination, filtering, sorting](../api/pagination-filtering-sorting)** — how to shape list queries.
- **[Postman collection](../api/postman)** — ready-to-import JSON.
- **[Rate limits](../api/rate-limits)** — request budgets, retry-after semantics.
- **[Errors](../api/errors)** — the common error envelope and how to handle each status.
