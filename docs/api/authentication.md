---
sidebar_position: 1
---

# Authentication

The TrakRF API uses the **OAuth2 `client_credentials`** flow. You mint a long-lived `client_id` + `client_secret` pair once from the web app, exchange that pair for a short-lived **access token** at `POST /api/v1/oauth/token`, and send the access token as an `Authorization: Bearer` header on every request. Access tokens are JSON Web Tokens (JWTs) scoped to a single organization and a set of permissions.

## How authentication works

1. **Mint credentials** in the app — you receive a `client_id` and an opaque `client_secret`. This pair is long-lived; store it in a secrets manager.
2. **Exchange** the pair for an access token at `POST /api/v1/oauth/token` (`grant_type=client_credentials`).
3. **Call the API** with `Authorization: Bearer <access_token>`.
4. **Refresh** before the access token expires (`grant_type=refresh_token`), or just request a new pair-exchange.

The `client_id`/`client_secret` are your durable credential; access tokens are short-lived (15 minutes) and disposable.

## Mint your first API key {#mint-your-first-api-key}

API credentials are minted from the SPA's **Account menu → API Keys → New Key**. The `client_secret` is shown once at creation — save it immediately.

Minting happens in the web app, not via the API. Programmatic key issuance is intentionally not exposed on the public surface: possession of a key-minting API would defeat the trust boundary, since any compromised credential could mint a more-privileged one. The session-authenticated mint flow keeps issuance tied to a signed-in user, consistent with how Stripe and similar services gate dashboard-only credential issuance.

If you have a use case that genuinely requires programmatic provisioning (per-tenant SaaS automation that mints a credential per customer org), [contact us](mailto:support@trakrf.id) — we'll evaluate exposing it.

1. Sign in (production: [app.trakrf.id](https://app.trakrf.id); preview: [app.preview.trakrf.id](https://app.preview.trakrf.id)). Both hosts run the same UI and flow — use the one that matches your account. See [Base URL](#base-url) for the matching API host.
2. Open the **Account menu** in the top-right corner and choose **API Keys**. (The left-nav **Settings** page is for device configuration — signal power, session, worker log level — not key management.)
3. **If your account belongs to multiple organizations,** credentials are scoped to whichever organization is currently selected in the Account menu. Check the organization switcher before clicking **New key** — a credential minted under the wrong organization cannot be reassigned.
4. Click **New key**. Give it a descriptive name (e.g. `"prod-integration"` or `"local-dev"`) and pick the scopes the integration needs — only the scopes required for the endpoints you'll call. See the [Scopes](#scopes) table below.
5. Submit. The response shows a `client_id` and a `client_secret` **once**:
   - `client_id` — a stable UUID identifying the credential (e.g. `6f1c2a8e-7d3b-4e90-9a11-2c4d5e6f7a8b`).
   - `client_secret` — an opaque secret of the form `trakrf_` followed by 64 hex characters. It is stored only as a hash and **cannot be shown again**. Copy it to your secrets store immediately.
6. Exchange the pair for an access token (next section) and use that token as `Authorization: Bearer <access_token>`.

:::tip Misminted scopes? Revoke and re-mint
Scopes are fixed at creation and cannot be edited afterward — there is no "edit key" flow. If you mint a credential with the wrong scopes (or against the wrong organization, or with the wrong expiration), revoke it from the same **Account menu → API Keys** view and mint a fresh one. The old and new credentials are both valid until you revoke, so the cutover is non-disruptive: mint the new credential, swap it into your secrets store, then revoke the old one.
:::

## Get an access token

Exchange your `client_id` + `client_secret` for an access token at `POST /api/v1/oauth/token` with `grant_type=client_credentials`. The request and response are JSON; set `$BASE_URL` per [Base URL](#base-url).

```bash
curl -X POST "$BASE_URL/api/v1/oauth/token" \
  -H "Content-Type: application/json" \
  -d '{
        "grant_type": "client_credentials",
        "client_id": "6f1c2a8e-7d3b-4e90-9a11-2c4d5e6f7a8b",
        "client_secret": "trakrf_9f8e7d6c5b4a39281706f5e4d3c2b1a0ffeeddccbbaa99887766554433221100"
      }'
```

A successful exchange returns:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<short-lived-access-jwt>",
  "refresh_token": "f3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "token_type": "Bearer",
  "expires_in": 900
}
```

- `access_token` — a short-lived JWT (15 minutes). Send it as `Authorization: Bearer <access_token>`.
- `refresh_token` — an opaque, single-use token (30-day lifetime) used to obtain the next access token without re-sending your `client_secret`. See [Refresh an access token](#refresh-an-access-token).
- `expires_in` — access-token lifetime in seconds (`900` = 15 minutes).

A `400` means the body failed validation or `grant_type` was unsupported; a `401` (`detail: "Invalid client credentials"`) means the `client_id`/`client_secret` pair did not verify. Errors use the standard [error envelope](./errors).

## Request header

Every authenticated request must include the **access token** as a Bearer token in the `Authorization` header:

```
Authorization: Bearer <your-access-token>
```

The header name is `Authorization`; the scheme is `Bearer`. The access-token JWT directly follows the scheme with a single space separator. Do **not** send your `client_secret` here — only the access token returned from `/oauth/token`.

:::caution `X-API-Key` is not accepted
The server only honors the `Authorization: Bearer` form. Sending the token as `X-API-Key: <token>` (or any other header) returns `401 unauthorized` with detail `"Use Authorization: Bearer <token>"`. If you see that detail, check the header name and scheme.
:::

### 401 response detail strings {#unauthorized-detail-strings}

The 401 envelope carries one of these `error.detail` strings depending on the failure mode. All return `error.type: "unauthorized"` and the standard `WWW-Authenticate: Bearer realm="trakrf-api"` header per [RFC 7235](https://datatracker.ietf.org/doc/html/rfc7235):

| Failure mode                                | `error.detail`                        |
| ------------------------------------------- | ------------------------------------- |
| Missing `Authorization` header              | `"Missing authorization header"`      |
| Malformed bearer or invalid / expired token | `"Invalid or expired token"`          |
| Wrong scheme (e.g. `X-API-Key: <token>`)    | `"Use Authorization: Bearer <token>"` |

Branch on `error.type` for the canonical signal — that's the field that locks to a stable contract. The `detail` strings are accurate diagnostic prose suitable for logging, but they are not part of the response contract and may evolve in wording. If your integration classifies 401s for routing or retry, key on `type` and treat `detail` as human-readable context.

An expired access token returns `401` with `detail: "Invalid or expired token"` — that's the signal to refresh (see below) and retry.

## Refresh an access token {#refresh-an-access-token}

Before the 15-minute access token expires, exchange your `refresh_token` for a fresh pair — no `client_secret` required:

```bash
curl -X POST "$BASE_URL/api/v1/oauth/token" \
  -H "Content-Type: application/json" \
  -d '{
        "grant_type": "refresh_token",
        "refresh_token": "f3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      }'
```

The response shape is identical to the `client_credentials` exchange: a new `access_token` **and a new `refresh_token`**. Refresh tokens are **single-use** — each refresh rotates the token, so store the new `refresh_token` and discard the old one. Presenting an already-used refresh token returns `401` and **revokes the entire token chain** as a replay-detection measure; if that happens, start over from a `client_credentials` exchange.

## Security properties

- **Short-lived access tokens.** Access tokens live 15 minutes, limiting the blast radius of a leaked token.
- **Opaque, hashed secret.** The `client_secret` is a high-entropy opaque value stored only as a SHA-256 hash and shown exactly once. TrakRF cannot recover it; if lost, revoke and re-mint.
- **Single-use refresh rotation.** Every refresh issues a new `refresh_token`; replaying an old one is treated as a compromise signal and revokes the chain.
- **Scope-limited.** Each credential carries only the scopes selected at mint time (see [Scopes](#scopes)); the access token inherits them.
- **Store credentials in a secrets manager** — never in source control. Treat the `client_secret` like a password and the `access_token` like a session token.

## Scopes

Each credential is issued with one or more scopes. The API rejects requests whose access token lacks the scope required by the endpoint (`403 forbidden` with `"Missing required scope: <scope>"`). The scopes are fixed on the credential at mint time and carried into every access token minted from it.

### UI labels vs scope strings {#ui-labels}

The **New key** form in the web app lets you pick a resource (Assets / Locations / Tracking) and an access level (None / Read / Read + Write). Each combination maps to one or two of the scope strings used throughout these docs and in API responses.

| UI form (resource × level) | Scopes granted                      |
| -------------------------- | ----------------------------------- |
| Assets → Read              | `assets:read`                       |
| Assets → Read + Write      | `assets:read`, `assets:write`       |
| Locations → Read           | `locations:read`                    |
| Locations → Read + Write   | `locations:read`, `locations:write` |
| Tracking → Read            | `tracking:read`                     |

Selecting **None** for a resource grants no scope for that resource. Selecting **Read + Write** always grants both the read and the write scope — there is no write-only level today.

The table below is the human-readable summary; the machine-readable canonical source is the [`x-required-scopes` extension](#x-required-scopes-on-operations) on each operation in the OpenAPI spec. The runtime enforces what the spec declares, and codegen ingestors should read the extension directly. If the table ever drifts from the extension, the spec wins.

| Scope             | Access | Endpoints (representative)                                                                                                                                                                                            |
| ----------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `assets:read`     | Read   | `GET /assets`, `GET /assets/{asset_id}`                                                                                                                                                                               |
| `assets:write`    | Write  | `POST /assets`, `PATCH /assets/{asset_id}`, `POST /assets/{asset_id}/rename`, `DELETE /assets/{asset_id}`, `POST /assets/{asset_id}/tags`, `DELETE /assets/{asset_id}/tags/{tag_id}`                                  |
| `locations:read`  | Read   | `GET /locations`, `GET /locations/{location_id}`                                                                                                                                                                      |
| `locations:write` | Write  | `POST /locations`, `PATCH /locations/{location_id}`, `POST /locations/{location_id}/rename`, `DELETE /locations/{location_id}`, `POST /locations/{location_id}/tags`, `DELETE /locations/{location_id}/tags/{tag_id}` |
| `tracking:read`   | Read   | `GET /reports/asset-locations`, `GET /assets/{asset_id}/history`                                                                                                                                                      |

`tracking:read` gates the two endpoints that answer "where are things — now and over time." It covers both the time-series history feed (`/assets/{asset_id}/history`) and the current-state snapshot report (`/reports/asset-locations`), because both views are derived from the same underlying scan-event stream. The name reflects that data lineage: it's permission to read tracking data, not just historical data.

A few non-obvious pairings worth calling out:

- **Tag subresource operations** inherit their parent resource's `:write` scope. Attaching or detaching a tag on an asset (`POST /api/v1/assets/{asset_id}/tags`, `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`) requires `assets:write`; the location-side equivalents require `locations:write`. There is no separate `tags:write` scope — granting it would split the write authority for a single resource across two scope strings, which the platform deliberately avoids.
- **`/reports/asset-locations`** is gated by **`tracking:read`**, not `locations:read` (and not `assets:read`). The endpoint's URL says "reports," the response rows are asset-at-location pairs, but the scope follows the **data lineage**: every field on every row is derived from the scan-event stream — `asset_last_seen` is the timestamp of the most recent scan event for that asset, and the `location_id` / `location_external_key` on the row is the location of that scan. Granting `assets:read` or `locations:read` does **not** unlock this endpoint; you need `tracking:read`.
- **`/assets/{asset_id}/history`** is gated by **`tracking:read`** for the same reason — it's a projection of scan events, not a property of the asset.

Additional scopes may be added in any v1 release. Clients should tolerate unknown scope strings without breaking (see [Versioning → Open enums](./versioning#open-extensible-enums-in-v1)).

### `x-required-scopes` on operations

Every operation in the public spec carries an `x-required-scopes` extension listing the scope strings the endpoint requires (e.g. `x-required-scopes: [assets:write]` on `POST /api/v1/assets`). An empty array — `x-required-scopes: []` — means "any authenticated token works, no scope required" and currently appears only on `GET /api/v1/orgs/me`, the lightweight health-check endpoint integrators hit to confirm a token is live. The extension is present on every operation precisely so the absence of a required scope is a positive signal (empty array) rather than a missing-field ambiguity.

This is the canonical machine-readable scope source. Codegen ingestors, policy tooling, and scope-aware partners minting minimal-scope credentials should read this extension rather than parsing the **Required scope:** marker in each operation's prose description. The OpenAPI spec's `BearerAuth` scheme (HTTP Bearer, JWT format) can't express scope-per-operation by itself; the extension fills that gap.

The table above and the **Required scope:** markers in operation descriptions are the canonical reference for human readers. Both views are auto-derived from the same server-side annotations at spec-publish time and must stay in sync — any drift between prose and extension is a spec-generation bug, not a documentation choice.

### Internal scope: `keys:admin` {#internal-scopes}

A sixth scope, `keys:admin`, exists in the platform but does not appear in the public spec or the **New Key** picker. It gates the SPA-side key administration surface (mint, list, revoke). The scope is granted implicitly to authenticated session JWTs inside the web app; it is not selectable when minting an API credential and is not required by any documented public endpoint. Integrators do not need to request, hold, or branch on this scope. It is documented here only so the five-row table above isn't read as the platform's complete scope list.

## Example requests

Examples use `$BASE_URL` — set it to `https://app.trakrf.id` for production or `https://app.preview.trakrf.id` for preview accounts. See [Base URL](#base-url). They assume `$TRAKRF_ACCESS_TOKEN` holds a current access token from [Get an access token](#get-an-access-token).

### curl

```bash
curl -H "Authorization: Bearer $TRAKRF_ACCESS_TOKEN" \
     "$BASE_URL/api/v1/assets"
```

### Python (requests)

```python
import os
import requests

base_url = os.environ["TRAKRF_BASE_URL"]
headers = {"Authorization": f"Bearer {os.environ['TRAKRF_ACCESS_TOKEN']}"}
response = requests.get(f"{base_url}/api/v1/assets", headers=headers)
response.raise_for_status()
print(response.json())
```

### JavaScript (fetch)

```javascript
const baseUrl = process.env.TRAKRF_BASE_URL;
const res = await fetch(`${baseUrl}/api/v1/assets`, {
  headers: { Authorization: `Bearer ${process.env.TRAKRF_ACCESS_TOKEN}` },
});
if (!res.ok) throw new Error(`API error: ${res.status}`);
const data = await res.json();
```

## Credential lifecycle

All lifecycle actions — creation, listing, rotation, revocation — happen in the SPA. There is no programmatic API for credential management; see [Mint your first API key](#mint-your-first-api-key) for the design rationale.

- **Creation:** credentials are minted by an organization administrator. The `client_secret` is shown **once** at creation time — copy it immediately to your secrets store.
- **Listing:** a credential's `client_id` and metadata (name, scopes, created / last-used timestamps) remain visible to administrators; the `client_secret` is never shown again.
- **Rotation:** create a new credential, update your integration, then revoke the old one. TrakRF does not support in-place secret rotation; create-new-revoke-old keeps both credentials valid during the cutover.
- **Revocation:** an administrator can revoke a credential at any time. Revoked credentials fail the `client_credentials` exchange (`401`), and any outstanding refresh-token chains are invalidated.
- **Expiration:** credentials do not expire by default — leaving the field blank (the **Never** option in the SPA picker) mints a permanent credential. Picking an explicit expiration sets an expiry after which the `client_credentials` exchange returns `401`. For any credential beyond a throwaway local-dev one, set an explicit expiration (e.g. 90 days) and schedule the rotation.

### Listing and revocation are SPA-side {#listing-revocation-spa-side}

Listing existing credentials, viewing metadata (name, scopes, created / last-used / expires timestamps), and revoking a credential are browser affordances in the SPA's **Account menu → API Keys** view, not public API endpoints. Any rotation workflow that needs to enumerate or revoke prior credentials has to drive the SPA flow (manual or scripted via a session login), or maintain its own out-of-band record of which credential handles map to which integrations. If you have a use case that genuinely requires programmatic listing or revocation, [contact us](mailto:support@trakrf.id).

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

Preview-scoped credentials will not authenticate against production and vice versa — make sure `BASE_URL` matches the environment your credential was minted on.

**The API and the SPA share the same origin.** `$BASE_URL` resolves to the application host that also serves the web app — `app.trakrf.id` is both the SPA URL and the API host, and the OpenAPI spec's `servers[]` entries match these hosts one-for-one. Generated clients can point at `servers[0]` directly; the `/api/v1/` prefix is the only path differentiation between SPA routes and API routes.

## Server-to-server design {#server-to-server}

TrakRF's public API is built for **server-to-server** integration: partners typically call it from their own backend, where API credentials never leave the server. That describes how the API is most commonly used — it is not an access restriction. Cross-origin browser requests are permitted (`Access-Control-Allow-Origin: *`).

Bearer tokens are attached explicitly to each request via the `Authorization` header. The API uses no cookies, no HTTP Basic auth, and no other ambient credentials — so a bearer token can't be exposed through a cross-origin read the way a session cookie can, because the browser never attaches it automatically. CORS is therefore not a credential-protection mechanism here, and we don't treat it as one. Keeping tokens safe is the client's responsibility: don't embed long-lived secrets in client-side code, and rely on refresh-token rotation to keep access tokens short-lived (15 minutes).

**Session JWTs are also accepted** on most public endpoints (same `Authorization: Bearer <jwt>` form), because the web app and the API share a router. A session JWT is effectively unscoped for its short lifetime and is only convenient for ad-hoc UI-driven requests; integrators should use the `client_credentials` flow so that auth is durable and scope-limited. (One exception: `/orgs/me` accepts API-credential access tokens only — see [Private endpoints → Response shape: `/orgs/me`](./private-endpoints#orgs-me).)

## Environment variables

Store your `client_id`/`client_secret` in a secrets manager — **never in source control**. The access token is short-lived; obtain it at runtime via the `client_credentials` exchange rather than committing it. The examples on this site assume `$TRAKRF_ACCESS_TOKEN` holds a current access token:

```bash
# Obtain an access token (see "Get an access token") and capture it:
export TRAKRF_ACCESS_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Because access tokens expire after 15 minutes, scripts that run longer should re-exchange (or refresh) rather than relying on a stale exported value.

## Testing connectivity

Once you have an access token, verify it with curl:

```bash
curl -i -H "Authorization: Bearer $TRAKRF_ACCESS_TOKEN" \
     "$BASE_URL/api/v1/assets?limit=1"
```

A `200 OK` with a JSON body confirms the token and scope are correct. A `401 unauthorized` indicates a missing, malformed, or expired token (re-exchange and retry); `403 forbidden` indicates the credential lacks the scope required for that endpoint.
