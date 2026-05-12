---
sidebar_position: 8
title: Changelog
---

# Changelog

This log records changes to the TrakRF public API under `/api/v1/` that affect integrators. Entries follow the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) convention with the v1 stability commitment in [Versioning](./versioning): within v1, changes are additive only — no silent breaking changes. Deprecations are flagged at least six months before sunset via RFC 8594 headers.

## v1.0 — Launch (TBD)

Initial public API release. Stable contract for paths, field names, response shapes, and error envelopes per the [v1 stability commitment](./versioning).

### Pre-launch hardening (BB27 / contract-test follow-ups)

These changes flowed into the `v1.0.0` spec and into shipped behavior ahead of launch. Listed here for partners tracking the docs / spec mirror; none are breaking against a `v1.0.0`-or-later baseline.

**Spec hygiene**

- **`info.version: 1.0.0`** (was `v1`). URL versioning under `/api/v1/` is unchanged; the spec-document version and the URL version evolve independently.
- **Integer path-param `maximum: 2147483647`** (was `9007199254740991`). Path-param `id`s are now bounded by the underlying `int4` column. Values in the previously-accepted range `(2^31 - 1, 2^53 - 1]` return `400 validation_error` with `params.max=2147483647` instead of falling through to a `500 internal_error` from the database driver.
- **Every integer field declares `format: int32`.** Code generators emit width-bounded `int32` types — `number` in TS, `int` in Python, `int32` in Go/Java — rather than a permissive `integer`. No runtime behavior change.
- **Every operation declares a `default` response** pointing at the `ErrorResponse` envelope. Code generators that emit discriminated-union response types now get a real catch-all branch.
- **Date / date-time properties carry RFC 3339 `example:` values.** Visible in Redoc's example panel.

**`PATCH` round-trip and read-only handling**

- **Full-object `PATCH` round-trip is now supported.** Sending `external_key`, `tags`, or any other read-only field (`id`, `created_at`, `updated_at`, `*_deleted_at`, `tree_path`, `depth`) in a `PATCH` body returns `200` with the field silently ignored. Mutate `external_key` via `POST /api/v1/{resource}/{id}/rename` and tags via `POST /api/v1/{resource}/{id}/tags` (and the `DELETE` counterparts). Reverses earlier guidance that called these fields "rejected with `400 immutable_field`" / "rejected with `400 invalid_value`." See [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) for the per-resource read-only set.
- **`immutable_field` validation code retired.** No remaining emitter; previously only fired for `external_key` on `PATCH`. Clients that branched on the code can drop the case.

**FK and validator consistency**

- **FK envelope is consistent across surrogate and natural-key forms.** A non-existent `location_id` (or `parent_id`) returns the same `400 validation_error` envelope as a non-existent `location_external_key` (or `parent_external_key`); previously the surrogate-key form fell through to `500 internal_error`. (The specific `FieldError.code` reshaped again under [TRA-681](https://linear.app/trakrf/issue/TRA-681) — see below.)
- **`description: ""` is rejected with `too_short`.** Sending an empty string on `POST` or `PATCH` for `description` returns `400 validation_error` / `code: too_short` / `params.min_length=1`, matching every other length-bearing string field. Send explicit `null` to clear the field.
- **`too_short` is now uniform on length-bearing required fields.** `POST /api/v1/assets {}` previously emitted `fields[0].code = required`; all length-bearing required fields now emit `too_short` consistently, matching the [errors page](./errors#validation-errors).
- **`valid_from: null` accepted on `POST`, rejected on `PATCH`.** See [Date fields → `valid_from: null` on Create vs. Update](./date-fields#valid_from-null-on-create-vs-update). Useful for ETL or migration code that emits explicit `null` for "use server default."

**Errors and conflict messages**

- **`5xx` responses no longer leak database driver strings in `error.detail`.** `error.detail` on `500` is a fixed generic string; the underlying cause is logged server-side and correlatable through the `request_id` in the envelope.
- **Tag conflict error strings use "tag," not "identifier."** A duplicate `(tag_type, value)` on `POST /api/v1/{resource}/{id}/tags` returns `detail: "tag rfid:E2-… already exists"`. String-matching on the literal word `tag` is now correct everywhere caller-visible.

**Spec hygiene — Phase 3.5 (Schemathesis gate flip)**

Final spec + validator changes flowing into `v1.0.0` ahead of flipping the Schemathesis contract-test gate to blocking ([TRA-678](https://linear.app/trakrf/issue/TRA-678)).

- **Breaking change for generated clients: the `sort` query parameter shape changed from array to comma-separated string.** Regenerate clients from the updated spec. The wire form integrators send is unchanged (`?sort=-created_at,external_key`); the spec now declares `sort` as `type: string` with a CSV-shaped `pattern:` regex instead of `type: array` with `style: form, explode: false`. Generated clients that previously typed `sort` as `string[]` will now type it as `string`. Hand-rolled clients building the query string directly are unaffected.
- **Write request bodies declare `additionalProperties: false`.** Unknown top-level keys in `POST` and `PATCH` bodies are rejected at the schema boundary with `400 validation_error` rather than silently accepted. The existing [silent-accept rule for read-only fields](./pagination-filtering-sorting#validator-behavior-on-writes) is unchanged — those are not "unknown" keys, they're declared `readOnly: true` on the read shape.
- **Printable-string validation on body strings and `q` filters.** `name`, `description`, tag `value`, and the `q` substring-search query param reject NUL bytes and other ASCII control characters at the validator with `400 validation_error`. Previously these could reach the storage layer and surface as `500 internal_error` from a downstream `invalid_text_representation` (SQLSTATE 22021).
- **RFC 3339 `pattern:` on every `format: date-time` property.** Date-time fields now carry a strict regex `pattern:` in addition to the `format:` keyword, so codegen tools that honor `pattern` reject malformed timestamps client-side; the server already validated the RFC 3339 profile and continues to return `400 validation_error` for bad input.
- **Surrogate-id query filters and `offset` are int4-bounded.** `*_id` query filter items declare `minimum: 1` / `maximum: 2147483647`; `offset` declares `minimum: 0` / `maximum: 2147483647`. Out-of-range values return `400 validation_error` rather than overflowing into the database driver.

**FK error codes and paired-key contract reshape ([TRA-681](https://linear.app/trakrf/issue/TRA-681))**

Three contract-shaped decisions from the Phase 3.5 fix-wave were reshaped per design review to align with BB27 framing and the existing immutable-`external_key` pattern. None of these are breaking against a `v1.0.0`-or-later baseline.

- **`fk_not_found` returns `400 validation_error`.** A non-existent `location_id` (or `parent_id`) and a non-existent `location_external_key` (or `parent_external_key`) both return the same `400 validation_error` / `code: fk_not_found` envelope, on `POST` and `PATCH`. The `409 conflict` envelope is reserved for true state-conflict cases (`POST` collisions on `external_key`, the [non-leaf-location delete](./resource-identifiers#locations-delete-semantics) check). `fk_not_found` is a new `FieldError.code` value; clients integrating against a Phase 3.5 pre-release that briefly routed FK-not-found through `409 conflict` should branch on the new typed code.
- **Natural-key FK form is read-only on `PATCH`.** `location_external_key` (on assets) and `parent_external_key` (on locations) are silently stripped from `PATCH` request bodies regardless of whether they agree with the surrogate `*_id` form. Mutate the relationship via the surrogate form (`location_id`, `parent_id`); the natural-key form is recomputed by the server on read. The previous "send both if they agree, 400 on disagree" contract is retired — disagreement is now silently ignored on `PATCH`, matching the read-only-strip pattern that already covers `id`, `created_at`, `updated_at`, `*_deleted_at`, `tree_path`, `depth`, `external_key`, and `tags`. See [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape).
- **`POST` body and `GET` list filter reject both-supplied with `ambiguous_fields`.** The surrogate / natural-key forms are mutually exclusive on `POST /api/v1/assets`, `POST /api/v1/locations`, and the `GET` list filters on `/assets` and `/locations`. Sending both returns `400 validation_error` / `code: ambiguous_fields` with one `fields[]` entry per offending parameter. The `POST` rule is encoded directly in the OpenAPI spec (`not: required: [location_id, location_external_key]` on `CreateAssetWithTagsRequest` and the location equivalent); the `GET`-filter rule is enforced handler-side because OpenAPI 3 cannot express mutual exclusion on query parameters. `ambiguous_fields` is a new `FieldError.code` value. See [Resource identifiers → Paired-key behavior per verb](./resource-identifiers#paired-key-behavior-per-verb) for the full matrix.

**BB27 consolidated cleanup ([TRA-679](https://linear.app/trakrf/issue/TRA-679))**

Eight BB27 post-launch findings rolled into a single consolidated fix wave. None are breaking against a `v1.0.0`-or-later baseline.

- **`deleted_at` is the per-resource soft-delete field name.** `AssetView` and `LocationView` now carry `deleted_at` directly — the `asset_`/`location_` prefix has been dropped on the per-resource views. The cross-resource report row `AssetLocationItem` (on `/reports/asset-locations`) keeps `asset_deleted_at` because it merges fields from multiple resources and needs the disambiguation. Codegen-derived clients regenerated against the post-TRA-679 spec see the field name change on `AssetView` / `LocationView` only; the report shape is unchanged. See [Resource identifiers → Soft-delete visibility on lists](./resource-identifiers#soft-delete-visibility) for the naming asymmetry rule.
- **Sub-resource list endpoints declare a fixed sort order.** `/api/v1/locations/{location_id}/ancestors`, `/children`, and `/descendants` now declare their natural sort order via OpenAPI `description` — `depth` ascending (ancestors), `name` ascending (children), depth-first tree order (descendants), each with `id` ascending as a deterministic tiebreaker. No `sort` query parameter is exposed on these three; sending one returns `400 validation_error` against the spec. See [Pagination, filtering, sorting → Sub-resource list endpoints use a fixed sort order](./pagination-filtering-sorting#sub-resource-list-endpoints-use-a-fixed-sort-order).
- **`Location` header policy on `201 Created` is documented.** Top-level `POST` creates (`/assets`, `/locations`) return a `Location` header pointing at the canonical resource URL. Sub-resource `POST` creates (`/tags` on assets and locations) omit the header by design — tags have no top-level canonical URL, and the parent URL is already known to the caller. The policy is enforced by the Spectral rule `trakrf-location-header-on-201-top-level-create` on the spec. See [HTTP method coverage → `Location` header on `201 Created`](./http-method-coverage#location-header-on-201-created).
- **Body-decoder date error message rewritten.** The validator message on a malformed `format: date-time` field is now `"{field} must be an RFC 3339 timestamp"` (was: `"RFC3339 date or datetime string"`). Date-only input (`2026-05-10`) is still rejected — the previous "date or datetime" wording was inaccurate. The per-query message on `GET /api/v1/assets/{asset_id}/history?from=...` is unchanged (`"Invalid 'from' timestamp; expected RFC 3339, e.g. 2026-04-21T00:00:00Z"`). Date-only support is not on v1; if you need it, send `T00:00:00Z` explicitly.
- **`OPTIONS` preflight clarification.** The API is server-to-server only — no third-party origins are permitted. Preflights always return `204 No Content` with no `Access-Control-Allow-Origin` (and no other `Access-Control-Allow-*` headers); there is no allowlist that produces a populated CORS envelope. The "204 with CORS headers when allowed" wording was misleading and has been removed. See [HTTP method coverage → `OPTIONS`](./http-method-coverage#options--cors-preflight-always-204-with-no-allow-origin).
- **`duration_seconds` semantics documented.** `AssetHistoryItem.duration_seconds` (already in the spec) is the whole-second dwell at the **previous** location, measured from the previous scan-event timestamp to this row's `timestamp`. Always present, `null` only on the earliest scan event in the asset's history (no previous location to measure against). See [Date fields → `duration_seconds`](./date-fields#duration_seconds-on-asset-history-rows).
- **`/reports/asset-locations` scope rationale.** The endpoint is gated by `history:read`, not `locations:read` or `assets:read`, because every field on every row is derived from the scan-event stream (`last_seen`, `location_id`, `location_external_key`). The endpoint URL says "reports" and the rows are asset-at-location pairs, but the scope follows the data lineage. See [Authentication → Scopes](./authentication#scopes).
- **Composite natural keys covered in the resource-identifiers overview.** The `Tag` natural key — the polymorphic `(tag_type, value)` pair, scoped per organization — is now summarized in [Resource identifiers → Natural keys per resource](./resource-identifiers#natural-keys-per-resource) alongside the asset / location `external_key` form. The detailed [Tags use a composite natural key](./resource-identifiers#tags-use-a-composite-natural-key) section is unchanged.
