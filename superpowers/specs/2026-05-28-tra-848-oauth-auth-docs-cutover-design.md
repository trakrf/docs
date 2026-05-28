# TRA-848 — Integrator auth docs cutover to OAuth2 client_credentials

**Date:** 2026-05-28
**Status:** Design approved, spec under review
**Depends on:** TRA-846 (oauth/token grant flow) and TRA-847 (opaque client_secret + api-key creation) — both merged + verified on preview.

## Problem

The integrator auth docs describe the pre-846/847 model: an API key *is* a long-lived JWT, sent directly as `Authorization: Bearer`. The platform now uses an OAuth2 `client_credentials` flow:

- Credentials are an opaque `{client_id, client_secret}` pair (not a JWT).
- They are exchanged at `POST /api/v1/oauth/token` for a short-lived access token (a JWT).
- A long-lived JWT presented as Bearer is now rejected.

The docs must teach the new flow so a new integrator (TeamCentral.ai, first partner, launch ~2026-06-01) can authenticate end-to-end against preview from the docs alone, without reading source.

## Confirmed implementation contract

Verified against `~/platform` code and the published spec at `${appHost}/api/openapi.yaml` (the path `docusaurus.config.ts` ingests).

- **Mint** (app UI, Account menu → API Keys → New key): returns once
  - `client_id` = the key's `jti` (UUID)
  - `client_secret` = opaque `trakrf_` + 64 hex chars; SHA-256 hashed server-side; shown exactly once
- **Exchange** `POST /api/v1/oauth/token`, JSON body, `ErrorResponse` on failure:
  - `grant_type=client_credentials` + `client_id` + `client_secret` → `{access_token, refresh_token, token_type:"Bearer", expires_in:900}`
  - `grant_type=refresh_token` + `refresh_token` → same shape, rotated
- **Tokens:**
  - `access_token` = short-lived JWT, 15 min (`expires_in: 900`)
  - `refresh_token` = opaque 64-hex, 30-day TTL, **single-use rotation** — replaying a used refresh token returns 401 and revokes the whole chain
- **Status codes** on `/oauth/token`: 200 ok, 400 validation/unsupported `grant_type`, 401 invalid credentials/refresh token.
- Schemas in spec: `auth.TokenRequest`, `auth.TokenResponse`.

## Design decisions

1. **Minting stays UI-only in public docs.** Real HTTP key-management endpoints exist (`POST/GET/DELETE /api/v1/orgs/{id}/api-keys`) but are tagged `internal` (absent from the public spec) and gated on `keys:admin` or a session-admin. `keys:admin` is not in the public scope picker, so public integrators cannot reach them. This matches industry norms (Stripe/Twilio/GitHub: dashboard-minted credentials, programmatic everything-else).
2. **TeamCentral topology justifies UI-only.** They integrate with a known/small set of orgs, so one-time UI minting per org is acceptable. Multi-tenant programmatic provisioning is a deferred future enhancement, not a launch requirement.
3. **Source of truth = published public spec**, not the contract sketch. Worked examples use verified placeholder values.

## Scope

**Rewrite (canonical):**
- `docs/api/authentication.md`

**Update (onboarding paths that actively teach auth end-to-end):**
- `docs/api/quickstart.mdx`
- `docs/getting-started/api.mdx`

**Light sweep (incidental examples):**
- Other API pages that use a `$TRAKRF_API_KEY` env var in curl/code examples. Replace with a short-lived access-token variable (`$TRAKRF_ACCESS_TOKEN`) so we never teach hardcoding a 15-min token. Mechanical; preserves surrounding prose. Pages identified: `postman.mdx`, `http-method-coverage.md`, `pagination-filtering-sorting.md`, `data-model.md`, `date-fields.md`, `resource-identifiers.md`, `changelog.md` (each reviewed individually — only example blocks change).
- `private-endpoints.md` needs slightly more than an example swap: its "Programmatic access" section frames the API key itself as the credential. Reconcile that prose to "mint `client_id`/`client_secret`, exchange for an access token" while keeping the public/internal endpoint table and the `/orgs/me` section intact.

**Out of scope:**
- Documenting `/orgs/{id}/api-keys` management endpoints (stay internal).
- Any backend/spec change (e.g., making `keys:admin` grantable).
- Multi-tenant key provisioning.

## New `authentication.md` structure

1. **Overview** — OAuth2 `client_credentials`: mint a `client_id`/`client_secret` once, exchange for a short-lived access token, send that token as `Authorization: Bearer`.
2. **Mint credentials** — Account menu → API Keys → New key → choose scopes → receive `client_id` + opaque `client_secret` (shown once; store immediately). Org-scoping and revoke/re-mint guidance retained.
3. **Get an access token** — `POST /api/v1/oauth/token`, `grant_type=client_credentials`; worked curl + JSON response.
4. **Use the access token** — `Authorization: Bearer <access_token>`; curl/Python/JS examples updated to obtain-then-use.
5. **Refresh** — `grant_type=refresh_token`; worked curl; new pair returned each time.
6. **Security properties** (ticket-required) — 15-min access tokens; single-use refresh rotation; replay → 401 + chain revocation; secret hashed server-side and shown once; store credentials in a secrets manager.
7. **Retained, lightly adapted** — Scopes table + `x-required-scopes`; Base URL; server-to-server/CORS; environment variables; 401 detail strings; testing connectivity.
8. **Removed** — "API key is a JWT"; "use the returned JWT directly as Bearer"; the "no programmatic minting by trust-boundary" rationale framing.

## Worked example values (verified)

- `client_id`: `6f1c2a8e-7d3b-4e90-9a11-2c4d5e6f7a8b`
- `client_secret`: `trakrf_9f8e7d6c5b4a39281706f5e4d3c2b1a0ffeeddccbbaa99887766554433221100`
- `access_token`: a JWT placeholder (`eyJ…`)
- `refresh_token`: 64-hex placeholder
- `expires_in`: `900`, `token_type`: `Bearer`

## Acceptance

- A new integrator following `authentication.md` can mint credentials, obtain an access token, call a public endpoint, and refresh — against preview — without reading source.
- No page instructs using a long-lived JWT directly as Bearer.
- Docs prose matches the published OpenAPI spec.
- `pnpm build`, `pnpm typecheck`, `pnpm lint` pass.

## Verification

- Run the worked curl examples against `https://app.preview.trakrf.id` to confirm shapes/status codes.
- Build the site and spot-check the rendered auth page + onboarding pages.
