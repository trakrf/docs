---
sidebar_position: 1
---

# Authentication

The TrakRF API uses **API keys** to authenticate every request. API keys are JSON Web Tokens (JWTs) scoped to a single organization and a set of permissions.

## Mint your first API key {#mint-your-first-api-key}

API keys are created by an organization administrator in the TrakRF web app:

1. Sign in with an admin account (production: [app.trakrf.id](https://app.trakrf.id); preview: [app.preview.trakrf.id](https://app.preview.trakrf.id)). Both hosts run the same UI and flow — use the one that matches your account. See [Base URL](#base-url) for the matching API host.
2. Open the **avatar menu** in the top-right corner and choose **API Keys**. (The left-nav **Settings** page is for device configuration — signal power, session, worker log level — not key management.)
3. Click **New key**. Give it a descriptive name (e.g. `"prod-integration"` or `"local-dev"`) and pick the scopes the integration needs — only the scopes required for the endpoints you'll call. See the [Scopes](#scopes) table below.
4. Submit. The full JWT is displayed **once** at creation. Copy it to your secrets store immediately; it cannot be shown again.
5. Use it as the `Authorization: Bearer <key>` header on every API request. See [Request header](#request-header) for the exact format.

<!-- TODO: screenshot of avatar menu → API Keys → New key dialog; capture via scripts/refresh-screenshots.sh pattern. Tracked as a follow-up to TRA-408. -->

## Request header

Every authenticated request must include the API key as a Bearer token in the `Authorization` header:

```
Authorization: Bearer <your-api-key-jwt>
```

The header name is `Authorization`; the scheme is `Bearer`. A JWT directly follows the scheme with a single space separator.

:::caution `X-API-Key` is not accepted
Despite the credential being called an "API key," the server only honors the `Authorization: Bearer` form. Sending the JWT as `X-API-Key: <jwt>` (or any other header) returns `401 unauthorized` with `"Missing authorization header"`. If you see that message, check the header name and scheme before rotating the key.
:::

## Scopes

Each key is issued with one or more scopes. The API rejects requests whose key lacks the scope required by the endpoint (`403 forbidden` with `"Missing required scope: <scope>"`). Current scopes and the endpoints they gate:

| Scope             | Access | Endpoints (representative)                                                         |
| ----------------- | ------ | ---------------------------------------------------------------------------------- |
| `assets:read`     | Read   | `GET /assets`, `GET /assets/{identifier}`                                          |
| `assets:write`    | Write  | `POST /assets`, `PUT /assets/{identifier}`, `DELETE /assets/{identifier}`          |
| `locations:read`  | Read   | `GET /locations`, `GET /locations/{identifier}`                                    |
| `locations:write` | Write  | `POST /locations`, `PUT /locations/{identifier}`, `DELETE /locations/{identifier}` |
| `scans:read`      | Read   | `GET /locations/current`, `GET /assets/{identifier}/history`, scan-event endpoints |
| `scans:write`     | Write  | `POST /inventory/save`                                                             |

A few non-obvious pairings worth calling out:

- **`/locations/current`** is gated by **`scans:read`**, not `locations:read`. The snapshot is derived from scan events, so it lives under the scans scope.
- **`/assets/{identifier}/history`** is gated by **`scans:read`** for the same reason — it's a projection of scan events, not a property of the asset.
- **`/inventory/save`** is gated by **`scans:write`**, not `assets:write`. It ingests scan events, so writes land under the scans scope.

Additional scopes may be added in any v1 release. Clients should tolerate unknown scope strings without breaking (see [Versioning → Open enums](./versioning#open-extensible-enums-in-v1)).

## Example requests

Examples use `$BASE_URL` — set it to `https://app.trakrf.id` for production or `https://app.preview.trakrf.id` for preview accounts. See [Base URL](#base-url).

### curl

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets"
```

### Python (requests)

```python
import os
import requests

base_url = os.environ["TRAKRF_BASE_URL"]
headers = {"Authorization": f"Bearer {os.environ['TRAKRF_API_KEY']}"}
response = requests.get(f"{base_url}/api/v1/assets", headers=headers)
response.raise_for_status()
print(response.json())
```

### JavaScript (fetch)

```javascript
const baseUrl = process.env.TRAKRF_BASE_URL;
const res = await fetch(`${baseUrl}/api/v1/assets`, {
  headers: { Authorization: `Bearer ${process.env.TRAKRF_API_KEY}` },
});
if (!res.ok) throw new Error(`API error: ${res.status}`);
const data = await res.json();
```

## Key lifecycle

- **Creation:** keys are minted by an organization administrator. The full JWT is shown **once** at creation time — copy it immediately to your secrets store.
- **Listing:** the key's prefix and metadata (name, scopes, created / last-used timestamps) remain visible to administrators; the full JWT is never shown again.
- **Rotation:** create a new key, update your integration, then revoke the old one. TrakRF does not support in-place key rotation; create-new-revoke-old keeps both keys valid during the cutover.
- **Revocation:** an administrator can revoke a key at any time. Revoked keys produce `401 unauthorized` on every subsequent request.
- **Expiration:** keys do not expire by default — leaving the field blank at creation mints a permanent credential with no `exp` claim. For any key beyond a throwaway local-dev credential, set an explicit expiration (e.g. 90 days) and schedule the rotation. Expired keys return `401 unauthorized`.

## Base URL

- **Production:** `https://app.trakrf.id`
- **Preview (per-PR test deploys):** `https://app.preview.trakrf.id`

All API endpoints live under the `/api/v1/` prefix. The interactive reference at [`/api`](/api) lists the complete endpoint catalog. Shell examples in these docs use a `$BASE_URL` env var so the same commands work against either environment:

```bash
# Production
export BASE_URL=https://app.trakrf.id

# Preview
export BASE_URL=https://app.preview.trakrf.id
```

Preview-scoped keys will not authenticate against production and vice versa — make sure `BASE_URL` matches the environment your key was minted on.

## Server-to-server design {#server-to-server}

The TrakRF API is intended for **server-to-server** integration. Responses do not include `Access-Control-Allow-Origin` headers, so browser-based JavaScript calls are blocked by the browser's CORS policy. Call the API from a backend service and never ship API keys in client-side code — the CORS block is also a guardrail against leaking keys to end-user devices.

## Environment variables

Store API keys in environment variables or a secrets manager — **never in source control**. The examples above assume `TRAKRF_API_KEY` is set:

```bash
export TRAKRF_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

## Testing connectivity

Once you have a key, verify it with the interactive reference at [`/api`](/api) — click any endpoint's **Try it** button and paste your key. Or curl:

```bash
curl -i -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets?limit=1"
```

A `200 OK` with a JSON body confirms the key and scope are correct. A `401 unauthorized` indicates a missing, malformed, or revoked key; `403 forbidden` indicates the key lacks the scope required for that endpoint.
