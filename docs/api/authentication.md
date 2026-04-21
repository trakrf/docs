---
sidebar_position: 1
---

# Authentication

The TrakRF API uses **API keys** to authenticate every request. API keys are JSON Web Tokens (JWTs) scoped to a single organization and a set of permissions.

## Mint your first API key {#mint-your-first-api-key}

API keys are created by an organization administrator in the TrakRF web app:

1. Sign in at [app.trakrf.id](https://app.trakrf.id) with an admin account.
2. In the left nav, go to **Settings** → **API Keys**.
3. Click **Create Key**. Give it a descriptive name (e.g. `"prod-integration"` or `"local-dev"`) and pick the scopes the integration needs — only the scopes required for the endpoints you'll call. See the [Scopes](#scopes) table below.
4. Submit. The full JWT is displayed **once** at creation. Copy it to your secrets store immediately; it cannot be shown again.
5. Use it as the `Authorization: Bearer <key>` header on every API request. See [Request header](#request-header) for the exact format.

<!-- TODO: screenshot of Settings → API Keys create-key flow; capture via scripts/refresh-screenshots.sh pattern. Tracked as a follow-up to TRA-408. -->

## Request header

Every authenticated request must include the API key as a Bearer token in the `Authorization` header:

```
Authorization: Bearer <your-api-key-jwt>
```

The header name is `Authorization`; the scheme is `Bearer`. A JWT directly follows the scheme with a single space separator.

## Scopes

Each key is issued with one or more scopes. The API rejects requests whose key lacks the scope required by the endpoint (`403 forbidden`). Current scopes:

| Scope             | Grants                                                           |
| ----------------- | ---------------------------------------------------------------- |
| `assets:read`     | List and retrieve assets; read asset history                     |
| `assets:write`    | Create, update, delete assets                                    |
| `locations:read`  | List and retrieve locations; read the current-locations snapshot |
| `locations:write` | Create, update, delete locations                                 |
| `scans:read`      | Read logical scan events and reports                             |

Additional scopes may be added in any v1 release. Clients should tolerate unknown scope strings without breaking (see [Versioning → Open enums](./versioning#open-extensible-enums-in-v1)).

## Example requests

### curl

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets
```

### Python (requests)

```python
import os
import requests

headers = {"Authorization": f"Bearer {os.environ['TRAKRF_API_KEY']}"}
response = requests.get("https://app.trakrf.id/api/v1/assets", headers=headers)
response.raise_for_status()
print(response.json())
```

### JavaScript (fetch)

```javascript
const res = await fetch("https://app.trakrf.id/api/v1/assets", {
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
- **Expiration:** keys do not expire by default. Administrators can optionally set an expiration date at creation time.

## Base URL

- **Production:** `https://app.trakrf.id`
- **Preview (per-PR test deploys):** `https://app.preview.trakrf.id`

All API endpoints live under the `/api/v1/` prefix. The interactive reference at [`/api`](/api) lists the complete endpoint catalog.

## Environment variables

Store API keys in environment variables or a secrets manager — **never in source control**. The examples above assume `TRAKRF_API_KEY` is set:

```bash
export TRAKRF_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

## Testing connectivity

Once you have a key, verify it with the interactive reference at [`/api`](/api) — click any endpoint's **Try it** button and paste your key. Or curl:

```bash
curl -i -H "Authorization: Bearer $TRAKRF_API_KEY" \
     https://app.trakrf.id/api/v1/assets?limit=1
```

A `200 OK` with a JSON body confirms the key and scope are correct. A `401 unauthorized` indicates a missing, malformed, or revoked key; `403 forbidden` indicates the key lacks the scope required for that endpoint.
