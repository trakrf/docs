---
sidebar_position: 3
title: ID format
---

# ID format: int64 wire, int32 runtime

Every surrogate id on the TrakRF v1 API — primary keys (`id`), foreign-key references (`parent_id`, `location_id`, `asset_id`, `tag_id`, `org_id`), and the numeric path / query parameters that consume them — is declared `format: int64` on the OpenAPI spec. The service-side runtime accepts values up to **2³¹−1** (`2147483647`) today; values above that bound are rejected with `400 validation_error` / `code: too_large`. This page documents the gap between the wire width and the runtime ceiling, why it exists, and the error envelope you'll see if a client sends a value above the runtime bound.

## The contract at a glance

| Layer       | Width                           | Note                                                                                                     |
| ----------- | ------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Wire (spec) | int64 (`format: int64`)         | Generated SDKs surface ids as `Long` (Java/Kotlin), `bigint`-capable `number` (TS), `int` (Python), etc. |
| Runtime     | int32 ceiling (`1..2147483647`) | Values above the ceiling return `400` with `code: too_large` and `params.max: 2147483647`.               |
| Storage     | int32 (Postgres `int4`)         | Underlying database column. Drives the runtime ceiling.                                                  |

The wider wire type is a **long-horizon contract**, not a claim that current ids exceed int32. ID generation stays within the int32 range during v1 — the runtime ceiling is documented and stable for v1.

## Why the wire is wider than the runtime

The TrakRF id namespace is randomly distributed across the int32 range, not monotonically assigned from `1`. The current cardinality leaves ample headroom for v1, but a future migration to int64 — driven by namespace exhaustion or a strategy shift toward externally-supplied randomized ids — would be a breaking change for typed clients if the spec declared `int32` today:

- Java `Integer` would need to migrate to `Long`.
- Kotlin `Int` would need to migrate to `Long`.
- C# `int` would need to migrate to `long`.
- TypeScript clients using `number` would need to guard against values above `Number.MAX_SAFE_INTEGER` (2⁵³−1).

Declaring `int64` on the wire from v1 launch defers all of those breaks. Generated SDK regeneration on the int32 → int64 storage cutover becomes a zero-change ABI for the integer-handling code: clients are already typed wide enough.

The runtime ceiling captures the current storage reality. A client that synthesizes ids on its own side (uncommon — ids are server-assigned) or pastes an unintended value into a path-param URL gets a clean `400` rather than a server-side overflow.

## Error envelope: `too_large` on path / body / query

Sending an id above `2147483647` on any surface — path-param, request body, or query parameter — returns `400 validation_error` with `code: too_large` and `params.max: 2147483647`:

```http
GET /api/v1/assets/2147483648
```

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

The same envelope applies to request-body ids (`parent_id` on `POST /api/v1/locations`) and to list-filter query parameters that take an id (`?location_id=`, `?parent_id=`). `location_id` is not a writable field on the asset surface — it's scan-data, not master-data; see [Data model](./data-model) — so the request-body too-large path doesn't apply to it on asset POST or PATCH (the field rejects on presence with `read_only`, not on range with `too_large`). Branch on `code: too_large` and `params.max` rather than parsing the `message` string — see [Errors → Validation errors](./errors#validation-errors) for the catalog.

Out-of-range path-param ids (zero, negative, the `2³¹` overflow case shown above) take the `validation_error` path with `params.max`, **not** `404 not_found`. The `404` path is reserved for in-range ids that don't resolve to an existing row. See [Errors → Path- and query-parameter validation errors](./errors#path-and-query-parameter-validation-errors) for the broader path-param bounds rule.

## What this means for clients

- **Typed-client integrators** — your generated client already represents ids at int64 width. Path- and query-parameter id schemas additionally declare `maximum: 2147483647` so a value above the runtime cap surfaces at the client-validation layer (when the generator honors `maximum`) instead of round-tripping to a server-side `400 too_large`. Request-body id fields stay descriptive int64 with no maximum, so a body-supplied id above the cap still reaches the server and returns the same `400` envelope. Treat the int64 type as the contract; the runtime cap is a service-side constraint you only need to plan around if you synthesize ids yourself.
- **Pasting / URL construction** — when an id reaches your code from a URL or a CSV row, validate it fits in int32 before sending. The `400` envelope above tells you when you missed.
- **No migration planning required for v1** — TrakRF's v1 stability commitment ([Versioning](./versioning)) covers both the wire type (won't narrow) and the runtime ceiling (won't tighten without a major-version cut). If the runtime ceiling widens during v1, that's an additive change — clients already typed wide enough see no impact.

## Cross-references

- [Resource identifiers → Numeric `id` is a surrogate key](./resource-identifiers#numeric-id-is-a-surrogate-key) — what surrogate ids mean on the read side.
- [Errors → Path- and query-parameter validation errors](./errors#path-and-query-parameter-validation-errors) — the broader bounds-checking rule and a worked example.
- [Versioning → Stability commitment (v1)](./versioning#stability-commitment-v1) — the additive-only stance covering both wire type and runtime ceiling.
