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
    "title": "Invalid request",
    "status": 400,
    "detail": "external_key must be 1-255 characters",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

The field names are modeled on [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807) (Problem Details for HTTP APIs), but the envelope is **not** 7807-compliant: TrakRF serves `application/json` (not `application/problem+json`) and nests the fields under `error` rather than placing them at the top level. Clients wiring directly to a 7807 library should parse this shape themselves.

| Field        | Purpose                                                                                                                                                                                                                                 |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type`       | A machine-readable identifier — your code should branch on this, not on `title`. Extensible enum.                                                                                                                                       |
| `title`      | A short human-readable summary safe to log. **Fixed per `type`** — every response with the same `type` carries the same `title`. The variable explanation (which credential failed, which resource is missing, etc.) lives in `detail`. |
| `status`     | The HTTP status code. Always matches the response's status line.                                                                                                                                                                        |
| `detail`     | A longer human-readable explanation. Safe to log; may name the offending field or value.                                                                                                                                                |
| `instance`   | The request path that produced the error. Useful when the same error appears across multiple logs.                                                                                                                                      |
| `request_id` | A [ULID](https://github.com/ulid/spec) matching the `X-Request-ID` response header. Include this when filing support tickets.                                                                                                           |

## Error type catalog

| `type`                   | HTTP status | When you'll see it                                                                                                                                                                                                                               | Retry?                                 |
| ------------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------- |
| `validation_error`       | 400         | A specific field in the request was invalid — a body field, a query parameter, or an unknown JSON / query key. Carries `fields[]`; see [validation errors](#validation-errors).                                                                  | No — fix the request                   |
| `bad_request`            | 400         | Request was malformed in a way the API can't attribute to a specific field — invalid JSON, JSON-type mismatch, unparseable path segment. No `fields[]`.                                                                                          | No — fix the request                   |
| `unauthorized`           | 401         | Missing, malformed, revoked, or expired API key. The specific cause (missing header, wrong scheme, expired token, revoked key) is in `detail`.                                                                                                   | No — re-auth                           |
| `forbidden`              | 403         | Valid key but insufficient scope for this endpoint                                                                                                                                                                                               | No — needs a key with the right scope  |
| `not_found`              | 404         | Resource lookup failed (path-param `id`, `/lookup?external_key=`, or list filter that resolves to nothing)                                                                                                                                       | No — check the identifier              |
| `method_not_allowed`     | 405         | The route does not accept the HTTP method you used (e.g. `PATCH` on a collection that only supports `GET` and `POST`). Allowed methods are listed in the response `Allow` header.                                                                | No — use a supported method            |
| `conflict`               | 409         | Unique-constraint violation (typically a duplicate `external_key` on assets/locations or a duplicate `(tag_type, value)` on tags)                                                                                                                | No — reconcile with `GET` then `PUT`   |
| `unsupported_media_type` | 415         | Request body was sent with a `Content-Type` other than `application/json`. Set the header and retry.                                                                                                                                             | No — fix the `Content-Type`            |
| `missing_org_context`    | 422         | Authentication succeeded but the principal has no org context — typically a session JWT minted before an org was selected, or an API key whose org has since been deleted. Pick an org (UI) or re-mint the key against a live org (integrators). | No — establish org context, then retry |
| `rate_limited`           | 429         | You've hit the rate limit — see [Rate limits](./rate-limits)                                                                                                                                                                                     | Yes, after `Retry-After` seconds       |
| `internal_error`         | 500         | Unhandled server failure                                                                                                                                                                                                                         | Yes, with exponential backoff          |

### `validation_error` vs `bad_request`

The split between the two 400-class types is whether the API can name the offending input. Anything the schema validator catches, plus unknown JSON keys and unknown query parameters, returns `validation_error` with a populated `fields[]` array. Anything the API rejects at a structural level — invalid JSON syntax, a value the decoder rejects before knowing which field it belongs to, or an unparseable path segment — returns `bad_request` with no `fields[]`.

One quirk worth noting: sending the wrong JSON type for a body field (for example, a number where the schema expects a string) returns `bad_request`, not `validation_error` — the JSON decoder fails before per-field reporting is reliable. If you see `bad_request` on a body that looks well-formed, this is the most likely cause.

### Extensibility

The `type` enum is **extensible** — TrakRF may add new error types in any v1 release. Clients should handle unknown `type` values gracefully (fall through to a generic error handler based on HTTP status code, which is a closed enum).

## Validation errors

When `type` is `validation_error`, the envelope carries an additional `fields` array with one entry per invalid field:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "Request did not pass validation",
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

| Field     | Purpose                                                                                                                                                                                                          |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `field`   | The JSON field name of the offending request attribute (e.g. `external_key`, `name`). Values are the snake_case JSON keys defined by the endpoint's request schema, not Go struct names or JSON-pointer paths. |
| `code`    | A machine-readable code — your validation UI can branch on this. Extensible enum.                                                                                                                                |
| `message` | A human-readable message safe to show the end user.                                                                                                                                                              |
| `params`  | Optional. Field-specific constraint metadata (e.g. `max_length`, `allowed_values`, `min`, `max`). Schema varies per field — treat unknown keys gracefully.                                                       |

Current `code` values (extensible):

- `required` — the field is missing and mandatory
- `invalid_value` — the value is not one of the allowed values, fails a format check (email, URL, UUID), or fails a validation TrakRF has not mapped to a more specific code
- `too_short` — string or collection length below the minimum
- `too_long` — string or collection length above the maximum
- `too_small` — numeric value below the minimum
- `too_large` — numeric value above the maximum

The `code` enum is extensible — TrakRF may add new validation codes in any v1 release. Treat unknown codes as generic invalid-value errors and surface the `message` field.

### Query-parameter validation errors

List endpoints validate their query string the same way. The `field` value in the `fields` array is the query-parameter name, and `detail` summarizes the first problem. A few you'll see in practice:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Invalid request",
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
    "title": "Invalid request",
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
    "title": "Invalid request",
    "status": 400,
    "detail": "Invalid 'from' timestamp; RFC3339 required",
    "instance": "/api/v1/assets/ASSET-0001/history",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "from",
        "code": "invalid_value",
        "message": "Invalid 'from' timestamp; RFC3339 required"
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
- **Network timeouts (no response):** Retry with backoff. Treat the first attempt as "unknown state" — for idempotent methods (`GET`, `PUT`, `DELETE`), retry is safe. For `POST`, retry may create duplicates if you didn't supply an `external_key`; see [Idempotency](#idempotency).

## Idempotency

The TrakRF v1 API does **not** support the `Idempotency-Key` header. Retry safety comes from HTTP semantics and natural-key constraints:

- **`POST /assets`, `POST /locations`** — retrying with the same `external_key` hits the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` and returns `409 conflict`. Detect the 409, then `GET /api/v1/{resource}/lookup?external_key=...` to recover the canonical `id` and `PUT` to reconcile. **If you omit `external_key` on a POST `/assets` retry, you may create duplicates** — the server will mint a fresh `ASSET-NNNN` each time. For retry-critical workflows, always supply an `external_key`.
- **`PUT`** — HTTP-semantically idempotent. Safe to retry.
- **`DELETE`** — idempotent. A second delete returns `404 not_found` (not `204`) so you can detect state drift; both outcomes are fine to treat as "deleted."

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
