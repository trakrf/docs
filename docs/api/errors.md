---
sidebar_position: 5
---

# Errors

Every non-2xx response from the TrakRF API returns a JSON body in a consistent error envelope. This page catalogs the error types you'll see and recommends retry behavior for each.

## Envelope shape

Non-2xx responses return `Content-Type: application/json` with the error object nested under a top-level `error` key:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "external_key must be at most 255 characters",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

On `validation_error`, `detail` echoes the first offending field's `message` verbatim (and appends `(and N more validation errors)` when more than one field is invalid). The per-field structure lives in `fields[]` — see [Validation errors](#validation-errors) below.

The field names are modeled on [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807) (Problem Details for HTTP APIs), but the envelope is **not** 7807-compliant: TrakRF serves `application/json` (not `application/problem+json`) and nests the fields under `error` rather than placing them at the top level. Clients wiring directly to a 7807 library should parse this shape themselves.

| Field        | Purpose                                                                                                                                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`       | A machine-readable identifier — your code should branch on this, not on `title`. Extensible enum.                                                                                                                                       |
| `title`      | A short human-readable summary safe to log. **Fixed per `type`** — every response with the same `type` carries the same `title`. The variable explanation (which credential failed, which resource is missing, etc.) lives in `detail`. |
| `status`     | The HTTP status code. Always matches the response's status line.                                                                                                                                                                        |
| `detail`     | A longer human-readable explanation. Safe to log; may name the offending field or value.                                                                                                                                                |
| `instance`   | The request path that produced the error. Useful when the same error appears across multiple logs.                                                                                                                                      |
| `request_id` | A [ULID](https://github.com/ulid/spec) matching the `X-Request-ID` response header. Include this when filing support tickets.                                                                                                           |

### Canonical titles

`error.title` is fixed per `error.type`. Generated clients can rely on the pairing — branch on `type`, log `title`, surface `detail` to humans.

| `error.type`             | `error.title`            |
| ------------------------ | ------------------------ |
| `validation_error`       | `Validation failed`      |
| `bad_request`            | `Bad request`            |
| `unauthorized`           | `Unauthorized`           |
| `forbidden`              | `Forbidden`              |
| `not_found`              | `Not found`              |
| `method_not_allowed`     | `Method not allowed`     |
| `conflict`               | `Conflict`               |
| `unsupported_media_type` | `Unsupported media type` |
| `missing_org_context`    | `Missing org context`    |
| `rate_limited`           | `Rate limited`           |
| `internal_error`         | `Internal server error`  |

Per-call specifics (the offending field, the unparseable value, the resource id that didn't resolve) live in `detail` or `fields[]`, never in `title`.

### Filing support tickets {#filing-support-tickets}

When filing a support ticket, include the `error.request_id` value (or the equivalent **`x-request-id`** response header) — that ULID is the TrakRF service's in-band correlation id and is what support uses to find your call in service-side logs.

The hosting edge layer adds a separate **`x-railway-request-id`** response header on top of every response. It is **not** the service-side correlation id — it identifies the request to the Railway edge, not to the TrakRF service. Logging or quoting `x-railway-request-id` instead of `x-request-id` will send support triage to the wrong log surface.

| Header                 | Source               | Use for                                                                                         |
| ---------------------- | -------------------- | ----------------------------------------------------------------------------------------------- |
| `x-request-id`         | TrakRF service       | Filing support tickets; matches `error.request_id` in the envelope. **This is the one to log.** |
| `x-railway-request-id` | Railway hosting edge | Hosting-level diagnostics only. Not used for TrakRF service-side correlation.                   |

## Error type catalog

| `type`                   | HTTP status | When you'll see it                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Retry?                                                                            |
| ------------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| `validation_error`       | 400         | A specific field in the request was invalid — a body field, a query parameter, or an unknown JSON / query key. Carries `fields[]`; see [validation errors](#validation-errors).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | No — fix the request                                                              |
| `bad_request`            | 400         | Request was malformed at decode time — invalid JSON syntax, or a JSON value that didn't match the expected type for a body field. No `fields[]`; the offending field name (when known) is in `detail`. See [validation_error vs bad_request](#validation_error-vs-bad_request).                                                                                                                                                                                                                                                                                                                                                                                                                                          | No — fix the request                                                              |
| `unauthorized`           | 401         | Missing, malformed, revoked, or expired API key. The specific cause (missing header, wrong scheme, expired token, revoked key) is in `detail`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | No — re-auth                                                                      |
| `forbidden`              | 403         | Valid key but insufficient scope for this endpoint                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | No — needs a key with the right scope                                             |
| `not_found`              | 404         | Resource lookup failed — an in-range path-param `id` that doesn't resolve (`GET /api/v1/assets/99999`) or a sub-resource path doesn't exist (`GET /api/v1/assets/99999/history`). An out-of-range or non-numeric path-param `id` (e.g. `0`, `-5`, `2147483648`, `abc`) returns `400 validation_error` against the spec's path-param bounds, not 404 — see [path-parameter validation errors](#path-and-query-parameter-validation-errors). A list filter that resolves to zero rows returns 200 with empty `data[]`, not 404.                                                                                                                                                                                            | No — check the identifier                                                         |
| `method_not_allowed`     | 405         | The route does not accept the HTTP method you used (e.g. `PATCH` on a collection that only supports `GET` and `POST`). Allowed methods are listed in the response `Allow` header and mirrored in `detail` (e.g. `Allowed methods: GET, HEAD, POST`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | No — use a supported method                                                       |
| `conflict`               | 409         | Two cause classes. **Unique-constraint violation** — typically a duplicate `external_key` on `POST` or `POST /…/rename` for assets/locations, or a duplicate `(tag_type, value)` on tags. **Referential-integrity violation** — `DELETE /api/v1/locations/{location_id}` rejects when the location has active descendant locations or active placed assets; see [Locations: delete semantics](./resource-identifiers#locations-delete-semantics).                                                                                                                                                                                                                                                                        | No — reconcile (unique: `GET` then `PATCH`; referential: remove dependents first) |
| `unsupported_media_type` | 415         | Request body was sent with a `Content-Type` the endpoint doesn't accept, or the header is missing entirely. `POST` requires `application/json`; `PATCH` requires `application/merge-patch+json` ([RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396)) exclusively — sending `application/json` to a `PATCH` endpoint returns `415` with `detail: "Content-Type must be application/merge-patch+json"`, and sending `application/merge-patch+json` to a `POST` endpoint returns `415` with `detail: "Content-Type must be application/json"`. A missing `Content-Type` header is rejected on every write method. See [HTTP method coverage → Request body Content-Type per method](./http-method-coverage#patch-content-type). | No — fix the `Content-Type`                                                       |
| `missing_org_context`    | 422         | Authentication succeeded but the principal has no organization context — typically a session JWT minted before an organization was selected, or an API key whose organization has since been deleted. Fires only on `GET /api/v1/orgs/me`: every other operation requires an active org context to dispatch at all, so the same underlying condition surfaces there as `403 forbidden` or `404 not_found` depending on the resource. Pick an organization (UI) or re-mint the key against a live organization (integrators).                                                                                                                                                                                             | No — establish organization context, then retry                                   |
| `rate_limited`           | 429         | You've hit the rate limit — see [Rate limits](./rate-limits)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Yes, after `Retry-After` seconds                                                  |
| `internal_error`         | 500         | Unhandled server failure                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Yes, with exponential backoff                                                     |

### HTTP method coverage

The catalog above covers `405 method_not_allowed`. `HEAD` and `OPTIONS` are not enumerated per path in the OpenAPI reference — they're handled uniformly across every endpoint and documented at [HTTP method coverage](./http-method-coverage). The short version: `HEAD` is supported wherever `GET` is declared and behaves identically minus the response body; `OPTIONS` is reserved for CORS preflight; the `Allow` header on a `405` response (mirrored in `error.detail`) is the runtime way to discover what each path supports.

### `validation_error` vs `bad_request`

The split between the two 400-class types is **parse-time vs. validate-time**. `bad_request` is returned when the request couldn't be parsed at all — invalid JSON syntax, or a body field whose value couldn't be decoded as the expected type — so the API can't enumerate which fields failed. `fields[]` is not populated; `detail` describes the parse error (and names the offending field when the decoder can identify it). `validation_error` is returned when the request parsed cleanly but one or more field values failed validation against the schema — body-field violations, query-parameter violations, path-parameter violations against the declared bounds, plus unknown JSON keys and unknown query parameters. `fields[]` is populated with one entry per offending field.

Branch on `error.type` first (`bad_request` → log `detail`, fix the request shape; `validation_error` → iterate `fields[]`, branch on each `code`). The pattern keeps your error handler tolerant of new field-level codes appearing in `validation_error` without changing how you handle decoder-level failures.

Type mismatches on body fields take this `bad_request` path because they fail at decode time, before the schema validator runs that would otherwise produce `fields[]`. The offending field name is surfaced in `detail` when the decoder can identify it:

```json
{
  "error": {
    "type": "bad_request",
    "title": "Bad request",
    "status": 400,
    "detail": "Body field \"external_key\" could not be decoded as the expected type",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

When the mismatch is at the top level (the request body itself is the wrong JSON type — for example an array where an object is expected), `detail` falls back to a generic message:

```json
{
  "error": {
    "type": "bad_request",
    "title": "Bad request",
    "status": 400,
    "detail": "Request body could not be decoded as the expected type",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

Genuinely malformed JSON (truncated input, syntax errors, EOF mid-token) returns the same envelope with `detail: "Request body is not valid JSON"`.

A `PATCH` request whose body is the literal JSON token `null` is a related but distinct case — `null` is valid JSON, and [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396) defines a top-level `null` merge-patch as a directive that empties the target. TrakRF does not honor that directive: the request is rejected with `400 bad_request` and `detail: "Request body must be a JSON object (RFC 7396)"`. Same envelope shape as the parse-failure cases above, distinct wording so a caller that sees the message can tell a syntax error apart from a "wrong top-level shape" rejection. To clear individual writable-nullable fields, send `{ "field": null }`, not a top-level `null` body.

### Extensibility

The `type` enum is **extensible** — TrakRF may add new error types in any v1 release. Clients should handle unknown `type` values gracefully (fall through to a generic error handler based on HTTP status code, which is a closed enum).

The OpenAPI spec marks `error.type` with `x-extensible-enum: true`, but mainstream codegen tools don't honor that extension — see [Versioning → Open (extensible) enums in v1](./versioning#open-extensible-enums-in-v1) for the codegen caveat and recommended client-side pattern.

## Validation errors

:::tip Branch on `fields[].code`, not `title` or `detail`
For `validation_error` responses, the stable contract for programmatic handling is `fields[].code` per offending field — that's the extensible-enum value codegen and validation UIs should switch on. `title` is fixed per `error.type` ([canonical titles](#canonical-titles)) and carries no per-field information; `detail` summarizes the first problem in human prose and is safe to log or surface, but its wording is not a contract. When the offending field matters (which it usually does for `validation_error`), iterate `fields[]` and branch on `code`.
:::

When `type` is `validation_error`, the envelope carries an additional `fields` array with one entry per invalid field. `detail` bubbles the first field's `message` so single-field cases read naturally without descending into `fields[]`; multi-field cases append `(and N more validation errors)` so a logged `detail` still flags that more issues are present:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "external_key must be at most 255 characters (and 1 more validation error)",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "external_key",
        "code": "too_long",
        "message": "external_key must be at most 255 characters",
        "params": { "max_length": 255 }
      },
      {
        "field": "tag_type",
        "code": "invalid_value",
        "message": "tag_type is not a valid value",
        "params": { "allowed_values": ["rfid", "ble", "barcode"] }
      }
    ]
  }
}
```

Field entries:

| Field     | Purpose                                                                                                                                                                                                        |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `field`   | The JSON field name of the offending request attribute (e.g. `external_key`, `name`). Values are the snake_case JSON keys defined by the endpoint's request schema, not Go struct names or JSON-pointer paths. |
| `code`    | A machine-readable code — your validation UI can branch on this. Extensible enum.                                                                                                                              |
| `message` | A human-readable message safe to show the end user.                                                                                                                                                            |
| `params`  | Optional. Field-specific constraint metadata (e.g. `max_length`, `allowed_values`, `min`, `max`). Schema varies per field — treat unknown keys gracefully.                                                     |

Current `code` values (extensible):

- `required` — the JSON key was absent from the request body. Distinct from explicit-`null` on a non-nullable field, which surfaces as `invalid_value` (see next entry). Empty strings on length-bearing fields are a third distinct case — see `too_short` below.
- `invalid_value` — a value-validation failure: the value was sent as explicit `null` on a non-nullable field, isn't one of the allowed values, fails a format check (email, URL, UUID), fails an enum check, or fails a validation TrakRF has not mapped to a more specific code. Use this code's path when the field _name_ was recognized but the value was wrong; see `unknown_field` for the unrecognized-name case. Integrators branching on `code` per the [tip above](#validation-errors) should treat the null-on-non-nullable case as a value error, not a missing-field error.
- `unknown_field` — the request body contains a top-level key the schema does not declare. Distinct from `invalid_value` so integrators can branch on "typo'd field name" vs. "wrong value." Emitted by the strict-decoder pass that drives [`additionalProperties: false`](./pagination-filtering-sorting#validator-behavior-on-writes) on write request bodies; `fields[].field` names the offending key.
- `too_short` — the field was present in the request body with a length below the documented minimum (e.g. `"name": ""` on a `min_length: 1` string field). Distinct from `required`, which covers the absent-key and explicit-`null` cases. `params.min_length` carries the constraint value.
- `too_long` — string or collection length above the maximum
- `too_small` — numeric value below the minimum
- `too_large` — numeric value above the maximum
- `fk_not_found` — a foreign-key field references a row that doesn't resolve. Returned uniformly across the surrogate form (`location_id: 99999999`) and the natural-key form (`location_external_key: "NOPE-XYZ"`); `fields[].field` names the form the caller sent. Branch on the code, not on which variant produced it. Applies to `POST` and `PATCH` bodies on `/assets` and `/locations`.
- `ambiguous_fields` — both forms of a paired surrogate / natural-key relationship were supplied on a surface that requires one or the other. The surfaces that emit this code: `POST /api/v1/assets` and `POST /api/v1/locations` (request body — `location_id` vs `location_external_key`, `parent_id` vs `parent_external_key`); the `GET` list filters on `/assets` and `/locations` (same pairs as query params); and `PATCH /api/v1/locations/{location_id}` when both `parent_id` and `parent_external_key` are supplied with **differing** values (matching values are silently accepted as a single re-parent operation). `PATCH /api/v1/assets/{asset_id}` does **not** emit this code on the location FK pair — `location_id` and `location_external_key` aren't part of `UpdateAssetRequest`, so they follow the [accept-if-matches, reject-if-differs](./resource-identifiers#read-shape-vs-write-shape) rule independently per field and a differing value generates a per-field `read_only` entry. See [Resource identifiers → Paired-key behavior per verb](./resource-identifiers#paired-key-behavior-per-verb) for the full matrix. `fields[]` carries one entry per offending parameter so a validation UI can highlight both.
- `read_only` — a `PATCH` body included a read-only field whose value differs from the current resource state. The fields that emit this code: the four server-managed fields (`id`, `created_at`, `updated_at`, `deleted_at`) on both resources; the `tags` collection on both resources; and the natural-key reference fields — `external_key` (assets and locations), `parent_external_key` (locations), and `location_id` / `location_external_key` (assets). The accompanying `message` names the proper write path or clarifies that the field is server-managed — `POST /api/v1/{resource}/{id}/rename` for the `*_external_key` fields, the `/tags` subresource endpoints for `tags`, "record a scan event" for the asset `location_*` fields, and a "server-managed; use `DELETE` to soft-delete / submit the current value or omit" wording for the four server-managed fields. Echoing the current value back is silently stripped under the accept-if-matches half of the rule — `read_only` only fires when the body value diverges from the live resource. Distinct from `unknown_field` (the field name isn't declared at all) and from `invalid_value` (the value failed a content check) so integrators can branch on "this field has a dedicated write path" specifically.

The `code` enum is extensible — TrakRF may add new validation codes in any v1 release. Treat unknown codes as generic invalid-value errors and surface the `message` field.

### Path- and query-parameter validation errors {#path-and-query-parameter-validation-errors}

List endpoints validate their query string the same way, and every endpoint validates path parameters against the spec's declared bounds (numeric path-param `id`s must be `1..2147483647`). The `field` value in the `fields` array is the parameter name (the path-param name, e.g. `asset_id`, or the query-param name, e.g. `limit`), and `detail` summarizes the first problem. A few you'll see in practice:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "asset_id must be ≤ 2147483647",
    "instance": "/api/v1/assets/2147483648",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "asset_id",
        "code": "too_large",
        "message": "asset_id must be ≤ 2147483647",
        "params": { "max": 2147483647 }
      }
    ]
  }
}
```

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "limit must be ≤ 200",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "limit",
        "code": "too_large",
        "message": "limit must be ≤ 200"
      }
    ]
  }
}
```

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "unknown sort field: bogus",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "sort",
        "code": "invalid_value",
        "message": "unknown sort field: bogus"
      }
    ]
  }
}
```

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "Invalid 'from' timestamp; expected RFC 3339, e.g. 2026-04-21T00:00:00.000Z",
    "instance": "/api/v1/assets/ASSET-0001/history",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "from",
        "code": "invalid_value",
        "message": "Invalid 'from' timestamp; expected RFC 3339, e.g. 2026-04-21T00:00:00.000Z"
      }
    ]
  }
}
```

The `detail` and `message` strings are stable enough to surface to an end user, but for programmatic handling branch on `type` and `fields[].code` — those are the contract.

## Retry guidance

Use the retry column in the catalog above as the default, but these patterns apply more broadly:

- **4xx other than 429:** Never retry blindly. These indicate a problem with the request the server cannot fix by seeing it again. Fix the request and retry once.
- **429:** Wait `Retry-After` seconds, then retry. Exponential backoff with jitter is appropriate if you're hitting the limit repeatedly. See [Rate limits](./rate-limits).
- **500:** Retry with exponential backoff, starting at 1 second, doubling to ~30s, with jitter. Surface the failure after 3-5 attempts.
- **Network timeouts (no response):** Retry with backoff. Treat the first attempt as "unknown state" — for idempotent methods (`GET`, `PATCH`, `DELETE`), retry is safe. For `POST`, retry may create duplicates if you didn't supply an `external_key`; see [Idempotency](#idempotency).

## Idempotency

The TrakRF v1 API does **not** support the `Idempotency-Key` header. Retry safety comes from HTTP semantics and natural-key constraints:

- **`POST /assets`, `POST /locations`** — retrying with the same `external_key` hits the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` and returns `409 conflict`. Detect the 409, then `GET /api/v1/{resource}?external_key=...` and read `.data[0].id` to recover the canonical `id`, then `PATCH` to reconcile. **If you omit `external_key` on a retry, you may create duplicates** — the server will mint a fresh value (`ASSET-NNNN` for assets, `LOC-NNNN` for locations) on each attempt. For retry-critical workflows, always supply an `external_key`.
- **`POST /assets/{asset_id}/rename`, `POST /locations/{location_id}/rename`** — idempotent in the value-matches sense: a same-value rename (new `external_key` equals the current one) returns `200` with the unchanged resource (and, for locations, `descendant_count_affected: 0`). A retry that hits a now-different value returns `409 conflict` against the per-org uniqueness index — recover by reading the current `external_key` via `GET` and deciding whether to abort or pick a different target. See [Resource identifiers → Renaming an `external_key`](./resource-identifiers#renaming-an-external_key).
- **`PATCH /assets/{asset_id}`, `PATCH /locations/{location_id}`** — JSON Merge Patch (RFC 7396) bodies are idempotent: applying the same patch twice yields the same final state as applying it once. Safe to retry.
- **`DELETE /api/v1/assets/{asset_id}`, `DELETE /api/v1/locations/{location_id}`** — idempotent in the "ends up gone" sense. A second delete returns `404 not_found` (not `204`) so you can detect state drift; both outcomes are fine to treat as "deleted." On locations specifically, the first call may return `409 conflict` if the location has active descendant locations or active placed assets — see [Locations: delete semantics](./resource-identifiers#locations-delete-semantics). The retry-safety guarantee covers the `404` path-shape only; a 409 will keep returning 409 until the dependents are reassigned or removed.
- **`DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`, `DELETE /api/v1/locations/{location_id}/tags/{tag_id}`** — idempotent in the "ends up gone" sense, matching the top-level resource DELETE pair above. First successful detach returns `204`; subsequent calls return `404 not_found` so a retry can distinguish "I just removed it" from "it was never there." The cross-asset / cross-org case (a tag id that exists but is not attached to this asset, or belongs to a different organization) also surfaces as 404.

Explicit `Idempotency-Key` header support is on the v1.x roadmap if customer pain materializes.

## Request IDs

Every response includes an `X-Request-ID` header with a ULID. The same ULID appears in the `request_id` field of any error envelope. When filing a support ticket, include this ID — it lets TrakRF staff find the exact request in logs without grepping.

If your client supplies an inbound `X-Request-ID` header, it is echoed back unchanged — TrakRF does not validate its format. Clients that supply their own IDs are encouraged to use ULIDs so log tooling remains consistent. When no inbound header is supplied, TrakRF generates a ULID server-side.

## Deprecation notices

When TrakRF retires an endpoint (typically at a v2 cutover), responses from the deprecated endpoint carry two extra headers per [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594):

```
Deprecation: true
Sunset: Wed, 11 Nov 2026 23:59:59 GMT
```

The minimum gap between `Deprecation` and `Sunset` is six months. After the sunset date, the endpoint returns `410 Gone`. No endpoints are currently deprecated at v1 launch; this mechanism is in place so future use doesn't surprise integrators.
