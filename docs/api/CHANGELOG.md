---
sidebar_position: 8
title: Changelog
---

# Changelog

This log records changes to the TrakRF public API under `/api/v1/` that affect integrators. Changes to the first-party web app, internal-only endpoints, or anything behind session cookies (see [Private endpoints](./private-endpoints)) are out of scope here.

Entries follow the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) convention with the v1 stability commitment in [Versioning](./versioning): within v1, changes are additive only — no silent breaking changes. Deprecations are flagged at least six months before sunset via RFC 8594 headers.

Each entry covers:

- **Added** — new endpoints, fields, parameters, or enum values
- **Deprecated** — surface that still works but is scheduled for removal (includes sunset date)
- **Removed** — surface past its sunset date (major version only)
- **Fixed** — corrections that align shipped behavior with documented behavior and do not change the contract

## Unreleased

Tracked but not yet in a release tag. Merged changes land here first, then move to a dated section on each platform release.

### Changed — pre-launch v1 vocabulary cleanup

The following are pre-launch vocabulary cleanup, not v1 breaks. The v1 stability commitment in [Versioning](./versioning) begins at public launch. These changes land before launch so the shipped v1 surface is the long-term shape.

- **Canonical `id` + `external_key` rename** ([TRA-549](https://linear.app/trakrf/issue/TRA-549)). Public response surfaces now expose canonical integer `id` (server-assigned, used in URL path params, FK fields, and response keys) and string `external_key` (customer-assigned natural key). Replaces the prior `identifier` (string canonical) / `surrogate_id` (int suppressed) model. See [Resource identifiers](./resource-identifiers) for the full convention.
  - Across assets, locations, reports, and tag schemas: `identifier` → `external_key`, `surrogate_id` → `id`. Path params use `{id}` (int) on every single-resource route.
  - Foreign-key fields are flat scalar pairs: `current_location_id` + `current_location_external_key` on assets, `parent_id` + `parent_external_key` on locations, `location_id` + `location_external_key` + `asset_id` + `asset_external_key` on reports.
  - List filters that reference related resources accept both forms where applicable: e.g. `?location_id=42` and `?location_external_key=WAREHOUSE-7` on `GET /api/v1/assets`.
  - Round-trip consistency: request and response field names match, so generated clients can `GET` a resource and `PUT` it back without remapping.
- **New `/lookup` endpoints for natural-key access** ([TRA-549](https://linear.app/trakrf/issue/TRA-549)). `GET /api/v1/assets/lookup?external_key=...` and `GET /api/v1/locations/lookup?external_key=...` return a single live resource (200) or 404. Equality match only, live rows only, multiple natural-key params or none returns 400.
- **Asset `external_key` is optional on create** ([TRA-549](https://linear.app/trakrf/issue/TRA-549)). Omitting `external_key` on `POST /api/v1/assets` triggers a server-assigned value in the format `ASSET-NNNN` from a per-organization sequence. Locations still require an explicit `external_key`.
- **Tag schemas renamed** ([TRA-549](https://linear.app/trakrf/issue/TRA-549)): `shared.TagIdentifier` → `shared.Tag`, `shared.TagIdentifierRequest` → `shared.TagRequest`. Tag responses expose canonical `id` (int) for path-param access (e.g. `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`).
- **Tag composite natural-key uniqueness enforced** ([TRA-561](https://linear.app/trakrf/issue/TRA-561)). Partial unique index `(org_id, tag_type, value) WHERE deleted_at IS NULL` rejects duplicate live `(tag_type, value)` pairs within an organization with `409 conflict`.
- **API key revocation split into two routes** ([TRA-549](https://linear.app/trakrf/issue/TRA-549)). `DELETE /api/v1/orgs/{id}/api-keys/{key_id}` accepts the integer `key_id` only; revocation by UUID `jti` moves to `DELETE /api/v1/orgs/{id}/api-keys/by-jti/{jti}`. Replaces the prior dual-input `key_id` that flattened to `string` in generated SDKs and broke int-path lookups in typed clients.
- **Tag path param naming** ([TRA-549](https://linear.app/trakrf/issue/TRA-549)). The camelCase `tagSurrogateId` path param on tag-removal routes is now snake_case `tag_id`, matching `key_id` / `org_id` conventions elsewhere on the surface.

### Added

- `POST /api/v1/locations` now accepts `parent_identifier` (natural key) to create a child location in one call. Previously the only parent field (`parent_location_id`, an internal numeric FK) was not exposed to API consumers, and parent-related payload keys were silently ignored. See the updated request schema in the [API reference](/api).
- `POST /api/v1/inventory/save` now accepts `location_identifier` (string) and `asset_identifiers` (string array), matching the identifier convention used everywhere else in the v1 surface. The numeric `location_id` / `asset_ids` fields still work for backward compatibility but are no longer shown in the published spec.
- The `type` field on assets enumerates its allowed values (`asset`, `person`, `inventory`) in the OpenAPI spec, and validation errors on unknown values return the allowed set in the `fields[].params` object.
- `POST /api/v1/orgs/{id}/api-keys`, `GET /api/v1/orgs/{id}/api-keys`, and `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` are now public, authenticated with the new **`keys:admin`** scope (or a session JWT from an org administrator). A `keys:admin` key may mint another `keys:admin` key, enabling unattended rotation for iPaaS, CI/CD, and IaC workflows. See [Authentication → Programmatic key rotation](./authentication#programmatic-key-rotation).
- `DELETE /api/v1/orgs/{id}/api-keys/{keyID}` now accepts either the integer surrogate `id` or the UUID `jti` for `{keyID}` — both forms revoke the same key. Documented in [Authentication → Identifying a key](./authentication#identifying-a-key) ([TRA-501](https://linear.app/trakrf/issue/TRA-501), [TRA-504](https://linear.app/trakrf/issue/TRA-504)).
- Pagination envelope (`limit`, `offset`, `total_count`) added on `GET /api/v1/locations/{identifier}/{ancestors,children,descendants}`, `GET /api/v1/orgs/{id}/api-keys`, and `GET /api/v1/assets/{identifier}/history`. Every list endpoint now uses the standard envelope; the previous "non-paginated exceptions" carve-out on the [Pagination](./pagination-filtering-sorting) page has been removed ([TRA-503](https://linear.app/trakrf/issue/TRA-503), [TRA-504](https://linear.app/trakrf/issue/TRA-504)).
- Three new `error.type` values in the [Errors](./errors) catalog: `method_not_allowed` (HTTP 405), `unsupported_media_type` (HTTP 415), and `missing_org_context` (HTTP 422). The `type` enum was already documented as extensible — see [Errors → Extensibility](./errors#extensibility) ([TRA-541](https://linear.app/trakrf/issue/TRA-541), [TRA-537](https://linear.app/trakrf/issue/TRA-537)).

### Changed

- API quickstart and Getting-started → API pages now auto-detect environment from the docs hostname (`docs.trakrf.id` → production app, `docs.preview.trakrf.id` → preview app), with a switcher for cross-environment readers ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F4).
- Added a multi-organization warning on the API-key minting steps: keys are scoped to whichever org is selected in the avatar menu at creation time ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F5).
- Added a UI-form-to-scope-string mapping table on Authentication → Scopes ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F6).
- Added **[Date fields](./date-fields)** — a new API-reference page documenting the `valid_from` / `valid_to` convention: `valid_from` always present as RFC3339, `valid_to` omitted when unset, inbound `FlexibleDate` parsing with US-first slash-date ambiguity warning ([TRA-472](https://linear.app/trakrf/issue/TRA-472)).
- API quickstart step 5 ("Mint an API key") now names the **Expires** picker, enumerates its options (Never / 30 days / 90 days / 1 year / Custom), and recommends 90 days as the production default ([TRA-449](https://linear.app/trakrf/issue/TRA-449), [TRA-504](https://linear.app/trakrf/issue/TRA-504)).
- [Errors](./errors) now documents the optional `params` object on `validation_error.fields[]` entries — field-specific constraint metadata such as `max_length`, `allowed_values`, `min`, `max`. The field has shipped for some time but was undocumented in the API reference ([TRA-504](https://linear.app/trakrf/issue/TRA-504)).

### Fixed

- `X-RateLimit-Remaining` now stays bounded by `X-RateLimit-Limit` (per IETF draft-ietf-httpapi-ratelimit-headers). Previously a fresh key could return `remaining=119` against `limit=60`, because the header surfaced the internal burst-bucket size instead of advertised quota. The burst safety margin still exists — it's just hidden from the header, where it only confused clients.
- `X-RateLimit-Reset` is now the wall-clock time at which `Remaining` will next equal `Limit`, rather than the time at which the internal bucket refills to burst. Previously `reset` crept forward by one second on every request, making `sleep(reset - now)` a zero-second no-op that defeated the back-pressure signal. Clients that respected the header were, in effect, not being told when to pause.
- `GET /api/v1/locations/{identifier}/ancestors`, `/children`, and `/descendants` now populate the `parent` field with the parent's natural key (omitted on root nodes), matching `GET /api/v1/locations/{identifier}` and `GET /api/v1/locations`. Previously every node returned `parent: null` regardless of depth.
- `GET /api/v1/locations/{identifier}/ancestors`, `/children`, and `/descendants` now accept API-key auth with `locations:read` scope, matching the other location reads. Previously these sub-routes were registered on the session-auth router only, so valid API keys returned `401` with a misleading "Bearer token is invalid or expired" message.
- `POST /api/v1/assets` now defaults `is_active` to `true` when the field is omitted, so API-created assets appear in the default `GET /api/v1/assets` list view without an extra round-trip. Previously omitted fields hit the Go zero value (`false`) and the newly created asset was hidden.
- `POST /api/v1/assets` and `POST /api/v1/locations` now default `valid_from` to the current time when the field is omitted. Previously omitted fields hit the Go zero value (`0001-01-01T00:00:00Z`), which surfaced as an invalid-looking date in responses.
- `valid_from` and `valid_to` now follow a single convention across every resource: `valid_from` is always present as RFC3339 UTC, `valid_to` is omitted from responses when the record has no expiry. Zero-time (`0001-01-01T00:00:00Z`) and far-future sentinels (`2099-12-31T...`) no longer appear on the wire, and no response returns `"valid_to": null`. Existing rows were backfilled by a one-way migration ([TRA-468](https://linear.app/trakrf/issue/TRA-468)).
- All non-2xx responses now match the [Errors](./errors) envelope contract: `title` is fixed per `error.type`, and the variable explanation lives in `detail`. Previously most 401 auth-rejection paths and the not-found handler placed the variable string in `title` with an empty `detail`, breaking handlers that followed the documented guidance to branch on `body.error.detail` ([TRA-538](https://linear.app/trakrf/issue/TRA-538)).
- `405 Method Not Allowed` responses now carry the standard error envelope (`error.type: "method_not_allowed"`). Previously 405 returned an empty body, which broke generated clients that deserialize an envelope on every non-2xx ([TRA-541](https://linear.app/trakrf/issue/TRA-541)).
- `415 Unsupported Media Type` responses now emit `error.type: "unsupported_media_type"` (matching the response status). Previously the envelope said `error.type: "bad_request"`, so clients branching on `error.type` could not distinguish a malformed-JSON 400 from a wrong-`Content-Type` 415 ([TRA-541](https://linear.app/trakrf/issue/TRA-541)).
- Handler paths that fail after authentication succeeds because the principal lacks an org context — a session JWT minted before an org was selected, or an API key whose org has since been deleted — now return `422 missing_org_context` instead of a misleading `401 unauthorized`. The credential was valid; the recoverable state is "establish org context and retry" ([TRA-537](https://linear.app/trakrf/issue/TRA-537)).

## v1.0.0 — 2026-04-20

Initial public availability. The `/api/v1/` surface launches with API-key authentication, per-key rate limiting, read and write endpoints for assets and locations, and the generated OpenAPI reference.

### Added

- **API-key authentication** — JWT-based keys minted from **Settings → API Keys** at [app.trakrf.id](https://app.trakrf.id), sent as `Authorization: Bearer <jwt>`. Scoped per endpoint family (`assets:read`, `assets:write`, `locations:read`, `locations:write`, `scans:read`). See [Authentication](./authentication).
- **Read endpoints** for the core resources:
  - `GET /api/v1/assets`, `GET /api/v1/assets/{identifier}`, `GET /api/v1/assets/{identifier}/history`
  - `GET /api/v1/locations`, `GET /api/v1/locations/{identifier}`
  - `GET /api/v1/locations/{identifier}/ancestors`, `/children`, `/descendants`
  - `GET /api/v1/locations/current` — snapshot of where each asset was last seen
- **Write endpoints** for assets and locations:
  - `POST /api/v1/assets`, `PUT /api/v1/assets/{identifier}`, `DELETE /api/v1/assets/{identifier}`
  - `POST /api/v1/assets/{identifier}/identifiers`, `DELETE /api/v1/assets/{identifier}/identifiers/{identifierId}`
  - `POST /api/v1/locations`, `PUT /api/v1/locations/{identifier}`, `DELETE /api/v1/locations/{identifier}`
  - `POST /api/v1/locations/{identifier}/identifiers`, `DELETE /api/v1/locations/{identifier}/identifiers/{identifierId}`
  - `POST /api/v1/inventory/save` — bulk scan ingest
- **Shared response envelope** — list responses return `{ "data": [...], "limit", "offset", "total_count" }`; single-resource responses return `{ "data": {...} }`. See [Pagination, filtering, sorting](./pagination-filtering-sorting).
- **Shared error envelope** — `{ "error": { "type", "title", "status", "detail", "instance", "request_id" } }` on every non-2xx response, plus `fields[]` on `validation_error`. Field names are modeled on RFC 7807 but the envelope is JSON-wrapped, not `application/problem+json`. See [Errors](./errors).
- **Per-key rate limiting** — token bucket, default 60/min steady-state with 120-burst, surfaced via `X-RateLimit-Limit` / `X-RateLimit-Remaining` / `X-RateLimit-Reset` on every response and `Retry-After` on 429. See [Rate limits](./rate-limits).
- **Request IDs** — every response includes `X-Request-ID` (ULID). Inbound `X-Request-ID` is echoed back for client-supplied correlation IDs.
- **Interactive reference** — the OpenAPI 3.0 spec is generated from the Go handlers and rendered at [`/api`](/api) (Redoc). Raw spec available at [`/api/openapi.json`](/api/openapi.json) and [`/api/openapi.yaml`](/api/openapi.yaml).
- **Postman collection** — regenerated alongside the spec; see [Postman collection](./postman).

### Fixed

- `POST /api/v1/locations` now returns `409 conflict` (not `500 internal_error`) on duplicate identifiers, matching the behavior of `POST /api/v1/assets`.
- `403 forbidden` is used (instead of `400 bad_request`) when a valid key attempts to access a resource in a different organization.
- Write endpoints use `{identifier}` path parameters consistently with read endpoints.

### Notes

- **No webhooks in v1.** Outbound webhook delivery is planned for a future release; see [Webhooks](./webhooks) for the current placeholder page.
- **No language SDKs in v1.** Use the Postman collection or generate a client from the OpenAPI spec with your preferred codegen tool.
- **Idempotency keys are not supported.** Retry safety comes from HTTP semantics and unique-identifier constraints; see [Errors → Idempotency](./errors#idempotency).
