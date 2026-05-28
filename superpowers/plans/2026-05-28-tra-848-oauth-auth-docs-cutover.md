# TRA-848 — OAuth2 Auth Docs Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the integrator auth docs from the legacy "API key is a JWT, used directly as Bearer" model to the OAuth2 `client_credentials` flow (mint `client_id`/opaque `client_secret` → exchange at `/oauth/token` → short-lived access-token Bearer → refresh).

**Architecture:** `docs/api/authentication.md` is rewritten as the canonical reference. The two onboarding walkthroughs are updated where they bootstrap auth. Incidental curl examples on other pages get a mechanical env-var rename so we never teach hardcoding a 15-minute token. Key-management endpoints stay internal (UI-only minting). A changelog entry records the change.

**Tech Stack:** Docusaurus (Markdown/MDX), pnpm. No app code. "Tests" = `pnpm build` / `pnpm typecheck` / `pnpm lint`, grep guards for forbidden strings, and live curl probes against preview.

**Reference:** Design spec at `superpowers/specs/2026-05-28-tra-848-oauth-auth-docs-cutover-design.md`. Verified contract values are reproduced in each task below.

**Working directory:** worktree `/home/mike/trakrf-docs/.claude/worktrees/tra-848-oauth-auth-cutover` on branch `worktree-tra-848-oauth-auth-cutover`.

---

## Verified contract (single source of truth for all tasks)

- **Mint** (app UI → Account menu → API Keys → New key) returns ONCE:
  - `client_id` = the key's `jti` (a UUID), e.g. `6f1c2a8e-7d3b-4e90-9a11-2c4d5e6f7a8b`
  - `client_secret` = opaque `trakrf_` + 64 hex chars, e.g. `trakrf_9f8e7d6c5b4a39281706f5e4d3c2b1a0ffeeddccbbaa99887766554433221100`; SHA-256 hashed server-side; shown once.
- **Exchange** `POST /api/v1/oauth/token` (JSON in, `error` envelope out):
  - `client_credentials`: body `{grant_type, client_id, client_secret}` → `{access_token, refresh_token, token_type:"Bearer", expires_in:900}`
  - `refresh_token`: body `{grant_type, refresh_token}` → same shape, rotated
- `access_token` = short-lived JWT (15 min). `refresh_token` = opaque 64-hex (30 days), single-use; replay → 401 + revokes the chain.
- Status codes on `/oauth/token`: 200 / 400 (validation, unsupported `grant_type`) / 401 (invalid creds or refresh token).
- Example env var going forward: `$TRAKRF_ACCESS_TOKEN` (a short-lived access token), replacing `$TRAKRF_API_KEY`.

---

## Baseline (do first)

- [ ] **Step B1: Install deps in the worktree**

Run: `cd /home/mike/trakrf-docs/.claude/worktrees/tra-848-oauth-auth-cutover && pnpm install`
Expected: completes; `node_modules/` present.

- [ ] **Step B2: Confirm a clean build baseline before edits**

Run: `pnpm build`
Expected: build succeeds. If it fails on `main` before any edits, STOP and report — do not attribute a pre-existing failure to this work.

- [ ] **Step B3: Verify the live contract on preview (so examples match reality)**

```bash
# Empty body → 400
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://app.preview.trakrf.id/api/v1/oauth/token -H "Content-Type: application/json" -d '{}'
# Bad client_credentials → 401 invalid client credentials
curl -s -X POST https://app.preview.trakrf.id/api/v1/oauth/token -H "Content-Type: application/json" \
  -d '{"grant_type":"client_credentials","client_id":"nope","client_secret":"nope"}'
```
Expected: `400`, then a 401 `error` envelope with `"detail":"Invalid client credentials"`. Confirms the endpoint and shapes before writing examples.

---

## Task 1: Rewrite `docs/api/authentication.md` (canonical)

**Files:**
- Modify (full rewrite): `docs/api/authentication.md`

- [ ] **Step 1.1: Replace the entire file with the new content below**

Write `docs/api/authentication.md` to exactly:

````markdown
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

The TrakRF API is intended for **server-to-server** integration. Responses do not include `Access-Control-Allow-Origin` headers, so browser-based JavaScript calls are blocked by the browser's CORS policy. Call the API from a backend service and never ship credentials or access tokens in client-side code — the CORS block is also a guardrail against leaking credentials to end-user devices.

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
````

- [ ] **Step 1.2: Guard against leftover legacy framing**

Run:
```bash
grep -nE "API key.*is a JWT|your-api-key-jwt|use (it|the returned JWT) as|TRAKRF_API_KEY" docs/api/authentication.md
```
Expected: no matches. If any match, fix the prose before continuing.

- [ ] **Step 1.3: Build + lint**

Run: `pnpm build && pnpm lint`
Expected: both pass.

- [ ] **Step 1.4: Commit**

```bash
git add docs/api/authentication.md
git commit -m "docs(api): rewrite authentication for OAuth2 client_credentials flow (TRA-848)"
```

---

## Task 2: Update `docs/api/quickstart.mdx` auth bootstrap

**Files:**
- Modify: `docs/api/quickstart.mdx` (auth-bootstrap prose + all `$TRAKRF_API_KEY` example occurrences)

- [ ] **Step 2.1: Update the intro TL;DR (line ~20)**

Replace:
```
If you're already familiar with API-key-authenticated REST APIs, the TL;DR is: send your key as `Authorization: Bearer <jwt>` and hit `$BASE_URL/api/v1/...`. The full walkthrough follows.
```
With:
```
If you're already familiar with OAuth2 `client_credentials`, the TL;DR is: POST your `client_id`/`client_secret` to `$BASE_URL/api/v1/oauth/token`, then send the returned `access_token` as `Authorization: Bearer <access_token>` to `$BASE_URL/api/v1/...`. The full walkthrough follows.
```

- [ ] **Step 2.2: Rewrite §2 "Verify your key works" credential setup (lines ~34–53)**

Replace the section from the `## 2. Verify your key works` heading through the first `curl ... /orgs/me` block (the lines covering the `:::note Browser required` admonition, the `export TRAKRF_API_KEY=...` block, and the intro sentence before the curl) with:

````markdown
## 2. Verify your credentials work

If you don't already have credentials, sign in to the <EnvSignInLink><EnvLabel /> app</EnvSignInLink>, open the **Account menu → API Keys → New Key**, name the key, pick scopes, and submit. The `client_id` and `client_secret` are shown once at creation — copy the `client_secret` immediately; it cannot be shown again. Full walkthrough: [Authentication → Mint your first API key](./authentication#mint-your-first-api-key).

:::note Browser required to mint credentials
Minting credentials requires an interactive browser session — there is no programmatic mint endpoint by design. CI/headless setups should mint credentials out-of-band, store the `client_id`/`client_secret` in a secret store (env var, vault, GitHub Actions secret), and reference them from there. See [Authentication → Mint your first API key](./authentication#mint-your-first-api-key) for the rationale and a contact path if your use case genuinely needs programmatic provisioning.
:::

Exchange your credentials for a short-lived access token, and capture it for the rest of this page:

```bash
export TRAKRF_ACCESS_TOKEN=$(curl -s -X POST "$BASE_URL/api/v1/oauth/token" \
  -H "Content-Type: application/json" \
  -d '{
        "grant_type": "client_credentials",
        "client_id": "6f1c2a8e-7d3b-4e90-9a11-2c4d5e6f7a8b",
        "client_secret": "trakrf_9f8e7d6c5b4a39281706f5e4d3c2b1a0ffeeddccbbaa99887766554433221100"
      }' | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")
# Or, if jq is installed: ... | jq -r '.access_token'
```

The access token lives 15 minutes; re-run this exchange (or use the `refresh_token`) when it expires. Full detail: [Authentication → Get an access token](./authentication#get-an-access-token).

`GET /api/v1/orgs/me` (`getCurrentOrg` in generated clients) returns the organization your credentials are scoped to. It's the canonical "tell me about myself" endpoint, requires no specific scope, and confirms end-to-end that your access token authenticates against the right environment. **Use an API-credential access token here — `/orgs/me` rejects session JWTs from the web app, even though most other public endpoints accept them.** See [Private endpoints → Response shape: `/orgs/me`](./private-endpoints#orgs-me) for the precise rule.
````

- [ ] **Step 2.3: Update the §2 troubleshooting bullet about `X-API-Key` (line ~79)**

Replace `the JWT was sent under `X-API-Key`` wording so it reads "the access token was sent under `X-API-Key`". Exact replace:
```
- `401 unauthorized` with `detail: "Use Authorization: Bearer <token>"` — the JWT was sent under `X-API-Key` (or another header). The server only accepts the `Authorization: Bearer` form, despite the credential being called an "API key." See [Authentication → Request header](./authentication#request-header).
```
With:
```
- `401 unauthorized` with `detail: "Use Authorization: Bearer <token>"` — the token was sent under `X-API-Key` (or another header). The server only accepts the `Authorization: Bearer` form. See [Authentication → Request header](./authentication#request-header).
```

- [ ] **Step 2.4: Swap all remaining `$TRAKRF_API_KEY` → `$TRAKRF_ACCESS_TOKEN` in this file**

Run: `sed -i 's/\$TRAKRF_API_KEY/$TRAKRF_ACCESS_TOKEN/g' docs/api/quickstart.mdx`
Then verify: `grep -n "TRAKRF_API_KEY" docs/api/quickstart.mdx` → expected: no matches.

- [ ] **Step 2.5: Update §4 Postman var description (line ~169)**

Replace `- \`bearerToken\` → the JWT from step 2` with `- \`bearerToken\` → the \`access_token\` from step 2 (refresh it when it expires)`.

- [ ] **Step 2.6: Update §5 codegen credential sentence (line ~187)**

Replace `pass the API key minted in step 2 wherever the generated client expects an access token.` with `pass the access token obtained in step 2 wherever the generated client expects an access token; refresh it via the \`client_credentials\` / \`refresh_token\` exchange as needed.`

- [ ] **Step 2.7: Build, guard, commit**

Run:
```bash
pnpm build && grep -n "TRAKRF_API_KEY" docs/api/quickstart.mdx
```
Expected: build passes; no `TRAKRF_API_KEY` matches.
```bash
git add docs/api/quickstart.mdx
git commit -m "docs(api): update quickstart for OAuth2 token exchange (TRA-848)"
```

---

## Task 3: Update `docs/getting-started/api.mdx` auth bootstrap

**Files:**
- Modify: `docs/getting-started/api.mdx`

- [ ] **Step 3.1: Update "What you'll need" credential bullet (line ~18)**

Replace:
```
- A TrakRF account and an API key. <EnvSignInLink>Sign in (or sign up) at the <EnvLabel /> app</EnvSignInLink>, then mint a key from the **Account menu → API Keys → New Key** ([detail](../api/authentication#mint-your-first-api-key)). The token is shown once at creation — copy it immediately.
```
With:
```
- A TrakRF account and API credentials. <EnvSignInLink>Sign in (or sign up) at the <EnvLabel /> app</EnvSignInLink>, then mint a `client_id`/`client_secret` from the **Account menu → API Keys → New Key** ([detail](../api/authentication#mint-your-first-api-key)). The `client_secret` is shown once at creation — copy it immediately.
```

- [ ] **Step 3.2: Rewrite §2 "Make your first call" credential setup (lines ~36–47)**

Replace from `Save your API key to an environment variable for the rest of this page:` through the `export TRAKRF_API_KEY=...` block and into the `/orgs/me` intro sentence with:

````markdown
Exchange your credentials for a short-lived access token and save it for the rest of this page:

```bash
export TRAKRF_ACCESS_TOKEN=$(curl -s -X POST "$BASE_URL/api/v1/oauth/token" \
  -H "Content-Type: application/json" \
  -d '{
        "grant_type": "client_credentials",
        "client_id": "6f1c2a8e-7d3b-4e90-9a11-2c4d5e6f7a8b",
        "client_secret": "trakrf_9f8e7d6c5b4a39281706f5e4d3c2b1a0ffeeddccbbaa99887766554433221100"
      }' | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")
# Or, if jq is installed: ... | jq -r '.access_token'
```

Access tokens live 15 minutes; re-exchange when one expires. Full detail: [Authentication → Get an access token](../api/authentication#get-an-access-token).

The `/api/v1/orgs/me` endpoint returns the organization your credentials are scoped to. It's the canonical "tell me about myself" probe — requires no specific scope, depends on no prior data, and confirms end-to-end that your access token authenticates against the right environment. **Use an API-credential access token here — `/orgs/me` rejects session JWTs from the web app, even though most other public endpoints accept them.** See [Private endpoints → Response shape: `/orgs/me`](../api/private-endpoints#orgs-me) for the precise rule.
````

- [ ] **Step 3.3: Swap remaining `$TRAKRF_API_KEY` → `$TRAKRF_ACCESS_TOKEN`**

Run: `sed -i 's/\$TRAKRF_API_KEY/$TRAKRF_ACCESS_TOKEN/g' docs/getting-started/api.mdx`
Verify: `grep -n "TRAKRF_API_KEY" docs/getting-started/api.mdx` → no matches.

- [ ] **Step 3.4: Build, guard, commit**

Run: `pnpm build && grep -n "TRAKRF_API_KEY" docs/getting-started/api.mdx` (expect: pass, no matches)
```bash
git add docs/getting-started/api.mdx
git commit -m "docs(getting-started): update API front-door for OAuth2 token exchange (TRA-848)"
```

---

## Task 4: Mechanical sweep of incidental curl examples

These pages only reference `$TRAKRF_API_KEY` inside `Authorization: Bearer` curl examples — no auth prose to change.

**Files:**
- Modify: `docs/api/http-method-coverage.md` (2), `docs/api/pagination-filtering-sorting.md` (13), `docs/api/data-model.md` (1), `docs/api/date-fields.md` (2), `docs/api/resource-identifiers.md` (21)

- [ ] **Step 4.1: Swap the env var across all five files**

```bash
sed -i 's/\$TRAKRF_API_KEY/$TRAKRF_ACCESS_TOKEN/g' \
  docs/api/http-method-coverage.md \
  docs/api/pagination-filtering-sorting.md \
  docs/api/data-model.md \
  docs/api/date-fields.md \
  docs/api/resource-identifiers.md
```

- [ ] **Step 4.2: Verify none remain anywhere under docs/**

Run: `grep -rn "TRAKRF_API_KEY" docs/`
Expected: no matches (authentication.md, quickstart, getting-started already handled in Tasks 1–3).

- [ ] **Step 4.3: Build + commit**

Run: `pnpm build` (expect pass)
```bash
git add docs/api/http-method-coverage.md docs/api/pagination-filtering-sorting.md docs/api/data-model.md docs/api/date-fields.md docs/api/resource-identifiers.md
git commit -m "docs(api): use short-lived access-token env var in examples (TRA-848)"
```

---

## Task 5: Reconcile `docs/api/private-endpoints.md` and `docs/api/postman.mdx` prose

**Files:**
- Modify: `docs/api/private-endpoints.md` (Programmatic access section)
- Modify: `docs/api/postman.mdx` (token wording)

- [ ] **Step 5.1: Update private-endpoints "Programmatic access" (lines ~13–17)**

Replace:
```
For server-to-server or scripted integrations, the supported credential is an **API key** issued via the in-app **Account menu → API Keys** flow (see [Authentication](./authentication)). Session JWTs minted by `POST /api/v1/auth/login` exist to keep the first-party SPA logged in and may change without notice — they are not a public auth path.
```
With:
```
For server-to-server or scripted integrations, mint a `client_id`/`client_secret` pair via the in-app **Account menu → API Keys** flow and exchange it for a short-lived access token at `POST /api/v1/oauth/token` (see [Authentication](./authentication)). Session JWTs minted by `POST /api/v1/auth/login` exist to keep the first-party SPA logged in and may change without notice — they are not a public auth path.
```

- [ ] **Step 5.2: Verify the `/orgs/me` JWT references still read correctly**

The `/orgs/me` section refers to "the presented bearer" and "the JWT's `sub` claim" — these remain accurate because the access token IS a JWT. No change needed. Confirm by reading lines 50–63; do not edit unless a reference is now wrong.

- [ ] **Step 5.3: Update postman.mdx token wording**

Run: `grep -n "JWT\|API key\|bearerToken\|api key" docs/api/postman.mdx`
For each hit where the Postman `bearerToken` variable or "API key" is described as the credential sent on requests, adjust the prose so the bearer value is the **access token** obtained from `/oauth/token` (not the minted key directly). Keep spec-import and collection-variable mechanics intact. Make the minimal prose edits that remove the "the JWT/key is your bearer" implication.

- [ ] **Step 5.4: Build + commit**

Run: `pnpm build` (expect pass)
```bash
git add docs/api/private-endpoints.md docs/api/postman.mdx
git commit -m "docs(api): reconcile programmatic-access + Postman prose to token exchange (TRA-848)"
```

---

## Task 6: Add a changelog entry

**Files:**
- Modify: `docs/api/changelog.md` (prepend a new entry; do NOT rewrite past entries)

- [ ] **Step 6.1: Read the file to match its existing entry format**

Run: `sed -n '1,40p' docs/api/changelog.md` and mirror the heading/date style already in use.

- [ ] **Step 6.2: Add a top entry describing the auth model change**

Content (adapt heading style to match existing entries):
```markdown
## 2026-05-28 — OAuth2 `client_credentials` authentication

API authentication moved from "use your API key JWT directly as a Bearer token" to the OAuth2 `client_credentials` flow:

- Minting an API key now returns a `client_id` + opaque `client_secret` pair (shown once) instead of a JWT.
- Exchange the pair at `POST /api/v1/oauth/token` for a short-lived access token (15 min) plus a 30-day single-use refresh token.
- Send the **access token** as `Authorization: Bearer`. A long-lived key JWT is no longer accepted as a Bearer credential.

See [Authentication](./authentication) for the full flow.
```

- [ ] **Step 6.3: Build + commit**

Run: `pnpm build` (expect pass)
```bash
git add docs/api/changelog.md
git commit -m "docs(api): changelog entry for OAuth2 auth cutover (TRA-848)"
```

---

## Task 7: Final verification

- [ ] **Step 7.1: Full quality gate**

Run: `pnpm build && pnpm typecheck && pnpm lint`
Expected: all pass.

- [ ] **Step 7.2: Repo-wide forbidden-string guard**

Run:
```bash
grep -rn "TRAKRF_API_KEY" docs/
grep -rnE "use (your key|the returned JWT) as|API key is a JWT|your-api-key-jwt" docs/
```
Expected: no matches in either.

- [ ] **Step 7.3: Live contract spot-check against preview**

Re-run the Baseline B3 probes and confirm the documented status codes/shapes still hold. (Full `client_credentials` round-trip requires a real minted credential; if one is available in the test org, exchange it and confirm `access_token`/`refresh_token`/`expires_in:900`. Otherwise the 400/401 probes plus the published spec are sufficient evidence.)

- [ ] **Step 7.4: Visual spot-check**

Run: `pnpm serve` (or `pnpm dev`) and open the rendered Authentication, Quickstart, and Getting-started→API pages. Confirm: the four-step flow renders, code blocks are intact, internal anchors (`#get-an-access-token`, `#refresh-an-access-token`, `#mint-your-first-api-key`) resolve. Note explicitly if you cannot launch a browser to verify.

- [ ] **Step 7.5: Finish the branch**

Use superpowers:finishing-a-development-branch to open the PR (target `main`, conventional-commit title). Do NOT merge without explicit user confirmation.

---

## Self-review (against the spec)

- **Spec coverage:** authentication.md rewrite (Task 1) ✓; quickstart + getting-started updates (Tasks 2–3) ✓; light sweep (Task 4) ✓; private-endpoints + postman prose (Task 5) ✓; security-properties section (Task 1, §"Security properties") ✓; management endpoints kept internal (no task documents them) ✓; changelog (Task 6) ✓.
- **Placeholders:** worked example values are concrete and verified; access_token/refresh_token JWT vs opaque shapes are explicit. No TBD/TODO.
- **Type/name consistency:** env var is `$TRAKRF_ACCESS_TOKEN` everywhere; anchors `#get-an-access-token`, `#refresh-an-access-token`, `#mint-your-first-api-key` are defined in Task 1 and referenced in Tasks 2–3 and the verification guard.
- **Out of scope honored:** no backend/spec change; `/orgs/{id}/api-keys` not documented publicly.
