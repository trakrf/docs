---
sidebar_position: 1
---

# Authentication

The TrakRF API uses **API keys** to authenticate every request. API keys are JSON Web Tokens (JWTs) scoped to a single organization and a set of permissions.

## Where keys come from

TrakRF API keys are minted from the SPA's **Account menu → API Keys → New Key**. The token is shown once at creation — save it immediately.

This is by design. We don't offer programmatic key minting because possession of an API-creating API would defeat the trust boundary: any compromised key could be used to mint a more-privileged one. The SPA's session-authenticated mint flow keeps key issuance tied to user identity, consistent with how Stripe gates dashboard-only key issuance.

If you have a use case that genuinely requires programmatic provisioning (per-tenant SaaS automation, CI rigs that need ephemeral keys), [contact us](mailto:support@trakrf.id) — we'll consider it for v2 based on demand.

## Mint your first API key {#mint-your-first-api-key}

1. Sign in (production: [app.trakrf.id](https://app.trakrf.id); preview: [app.preview.trakrf.id](https://app.preview.trakrf.id)). Both hosts run the same UI and flow — use the one that matches your account. See [Base URL](#base-url) for the matching API host.
2. Open the **Account menu** in the top-right corner and choose **API Keys**. (The left-nav **Settings** page is for device configuration — signal power, session, worker log level — not key management.)
3. **If your account belongs to multiple organizations,** API keys are scoped to whichever organization is currently selected in the Account menu. Check the organization switcher before clicking **New key** — a key minted under the wrong organization cannot be reassigned.
4. Click **New key**. Give it a descriptive name (e.g. `"prod-integration"` or `"local-dev"`) and pick the scopes the integration needs — only the scopes required for the endpoints you'll call. See the [Scopes](#scopes) table below.
5. Submit. The full JWT is displayed **once** at creation. Copy it to your secrets store immediately; it cannot be shown again.
6. Use it as the `Authorization: Bearer <key>` header on every API request. See [Request header](#request-header) for the exact format.

<!-- TODO: screenshot of Account menu → API Keys → New key dialog; capture via scripts/refresh-screenshots.sh pattern. -->

:::tip Misminted scopes? Revoke and re-mint
Scopes are baked into the JWT at creation and cannot be edited afterward — there is no "edit key" flow. If you mint a key with the wrong scopes (or against the wrong organization, or with the wrong expiration), [revoke it](#listing-revocation-spa-side) from the same **Account menu → API Keys** view and mint a fresh one. Both keys remain valid until you revoke, so the cutover is non-disruptive: mint the new key, swap it into your secrets store, then revoke the old one.
:::

## Request header

Every authenticated request must include the API key as a Bearer token in the `Authorization` header:

```
Authorization: Bearer <your-api-key-jwt>
```

The header name is `Authorization`; the scheme is `Bearer`. A JWT directly follows the scheme with a single space separator.

:::caution `X-API-Key` is not accepted
Despite the credential being called an "API key," the server only honors the `Authorization: Bearer` form. Sending the JWT as `X-API-Key: <jwt>` (or any other header) returns `401 unauthorized` with title `"Unauthorized"` and detail `"Use Authorization: Bearer <token>"`. If you see that detail, check the header name and scheme before rotating the key.
:::

## Scopes

Each key is issued with one or more scopes. The API rejects requests whose key lacks the scope required by the endpoint (`403 forbidden` with `"Missing required scope: <scope>"`). Current scopes and the endpoints they gate:

### UI labels vs scope strings {#ui-labels}

The **New key** form in the web app lets you pick a resource (Assets / Locations / History) and an access level (None / Read / Read + Write). Each combination maps to one or two of the scope strings used throughout these docs and in API responses.

| UI form (resource × level) | Scopes granted                      |
| -------------------------- | ----------------------------------- |
| Assets → Read              | `assets:read`                       |
| Assets → Read + Write      | `assets:read`, `assets:write`       |
| Locations → Read           | `locations:read`                    |
| Locations → Read + Write   | `locations:read`, `locations:write` |
| History → Read             | `history:read`                      |

Selecting **None** for a resource grants no scope for that resource. Selecting **Read + Write** always grants both the read and the write scope — there is no write-only level today.

| Scope             | Access | Endpoints (representative)                                                                                                     |
| ----------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `assets:read`     | Read   | `GET /assets`, `GET /assets/{asset_id}`                                                                                        |
| `assets:write`    | Write  | `POST /assets`, `PATCH /assets/{asset_id}`, `POST /assets/{asset_id}/rename`, `DELETE /assets/{asset_id}`                      |
| `locations:read`  | Read   | `GET /locations`, `GET /locations/{location_id}`                                                                               |
| `locations:write` | Write  | `POST /locations`, `PATCH /locations/{location_id}`, `POST /locations/{location_id}/rename`, `DELETE /locations/{location_id}` |
| `history:read`    | Read   | `GET /reports/asset-locations`, `GET /assets/{asset_id}/history`                                                               |

A few non-obvious pairings worth calling out:

- **`/reports/asset-locations`** is gated by **`history:read`**, not `locations:read`. The snapshot is derived from scan events, so it lives under the history scope.
- **`/assets/{asset_id}/history`** is gated by **`history:read`** for the same reason — it's a projection of scan events, not a property of the asset.

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

All lifecycle actions — creation, listing, rotation, revocation — happen in the SPA. There is no programmatic API for key management; see [Where keys come from](#where-keys-come-from) for the design rationale.

- **Creation:** keys are minted by an organization administrator. The full JWT is shown **once** at creation time — copy it immediately to your secrets store.
- **Listing:** the key's prefix and metadata (name, scopes, created / last-used timestamps) remain visible to administrators; the full JWT is never shown again.
- **Rotation:** create a new key, update your integration, then revoke the old one. TrakRF does not support in-place key rotation; create-new-revoke-old keeps both keys valid during the cutover.
- **Revocation:** an administrator can revoke a key at any time. Revoked keys produce `401 unauthorized` on every subsequent request.
- **Expiration:** keys do not expire by default — leaving the field blank (the **Never** option in the SPA picker) mints a permanent credential with **no `exp` claim** in the JWT. Picking an explicit expiration populates `exp` as a numeric Unix timestamp; the absence of the claim is the "no expiry" signal, not a sentinel value or a `null`. Generated clients that auto-refresh on `exp` will treat a no-`exp` key as immortal and never trigger their own rotation logic. For any key beyond a throwaway local-dev credential, set an explicit expiration (e.g. 90 days) and schedule the rotation. Expired keys return `401 unauthorized`.

### Listing and revocation are SPA-side {#listing-revocation-spa-side}

Listing existing keys, viewing key metadata (name, scopes, created / last-used / expires timestamps), and revoking a key are all browser affordances in the SPA's **Account menu → API Keys** view, not API endpoints. There is no `GET /api/v1/keys` or `DELETE /api/v1/keys/{id}` on the public surface in v1 — see [Where keys come from](#where-keys-come-from) for the design rationale (the same trust-boundary argument that gates programmatic key minting also gates programmatic key listing and revocation).

**Practical implication for partners automating rotation:** any rotation workflow that needs to enumerate or revoke prior keys has to drive the SPA flow (manual or scripted via a session login), or maintain its own out-of-band record of which key handles map to which integrations. If you have a use case that genuinely requires programmatic listing or revocation, [contact us](mailto:support@trakrf.id) — same evaluation track as programmatic key minting.

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

**Session JWTs are also accepted** on public endpoints (same `Authorization: Bearer <jwt>` form), because the web app and the API share a router. A session JWT is effectively unscoped for its 1-hour lifetime and is only convenient for ad-hoc UI-driven requests; integrators should use API keys so that auth is durable and scope-limited. (One exception: `/orgs/me` accepts API keys only — see [Private endpoints → Response shape: `/orgs/me`](./private-endpoints#orgs-me).)

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
