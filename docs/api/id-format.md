---
sidebar_position: 3
title: ID format
---

# ID format: int64 wire, int64 runtime

Every surrogate id on the TrakRF v1 API — primary keys (`id`), foreign-key references (`parent_id`, `location_id`, `asset_id`, `tag_id`, `org_id`), and the numeric path / query parameters that consume them — is declared `format: int64` with `maximum: 9007199254740991` on the OpenAPI spec. That declaration is uniform: response bodies, request bodies, `_id` query filters, and path parameters all carry the same type and the same ceiling, so there is no wire-vs-runtime width gap to reason about. The one bound worth knowing is **`9007199254740991` — JavaScript's `Number.MAX_SAFE_INTEGER` (2⁵³−1)** — the largest integer a browser SPA or any `number`-typed client can hold without precision loss. This page documents why the ceiling sits where it does and the error envelopes you'll see at the id boundaries.

:::note The int64 contract covers surrogate ids only
Non-id integer fields keep their natural width — for example `duration_seconds` is `int32` and is not a surrogate id. Don't generalize "ids are int64" to "every integer is int64."
:::

## The contract at a glance

| Layer       | Width / bound                                        | Note                                                                                    |
| ----------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Wire (spec) | int64 (`format: int64`), `maximum: 9007199254740991` | Generated SDKs surface ids as `Long` (Java/Kotlin), `number` (TS), `int` (Python), etc. |
| Runtime     | int64                                                | The service accepts and stores the full declared range; no narrower runtime ceiling.    |
| Storage     | int64 (Postgres `int8`)                              | Underlying database column.                                                             |

The declared `maximum` is the **JS-safe-integer cap** (2⁵³−1), not a storage limit — `int8` reaches 2⁶³−1. It is declared because the TrakRF SPA, and any client that holds ids in a JavaScript `number`, loses precision above 2⁵³−1; pinning the ceiling there keeps every minted id exactly representable on every client. ID generation stays within that bound for v1.

## Why int64, and why the 2⁵³−1 cap

The surrogate `id` is a high-entropy, server-assigned integer — **globally unique across every resource type** (no two rows, of any type, share an `id`), **opaque** (don't parse it, order by it, or infer a count or creation time from it), and **permanent** (it never changes and is never reused — the API never hard-deletes, and the shared id sequence is never reseeded). It is scattered across a wide range rather than monotonically assigned from `1`. Declaring `int64` from v1 launch means a future widening of the id space is a non-event for typed clients — they are already typed wide enough:

- Java / Kotlin clients surface ids as `Long`.
- C# clients surface `long`.
- TypeScript clients hold ids in `number`, exact up to 2⁵³−1 — exactly the declared `maximum`, so a value the spec admits is always a value the client can represent.

The `maximum: 9007199254740991` ceiling is the load-bearing half of that promise on the JS side: it guarantees the spec never admits an id a `number`-typed client would round. A client that synthesizes ids on its own side (uncommon — ids are server-assigned) should stay within the same bound.

:::note `id` is not `external_key`
This page is about the surrogate `id`. The string `external_key` (`ASSET-NNNN` / `LOC-NNN`) is a separate, per-organization handle with its own allocation — dense and low-valued, minted as `MAX(live key) + 1`. A dense or low-numbered `external_key` implies nothing about `id`; the two are allocated independently. See [Resource identifiers → `external_key` is optional on create](./resource-identifiers#external_key-is-optional-on-create).
:::

## Error envelopes at the id boundaries

Surrogate ids no longer carry a dedicated "too large" rejection. A syntactically valid id that doesn't resolve takes the ordinary lookup path for its surface:

| Surface                | Example                                          | Result                                                                      |
| ---------------------- | ------------------------------------------------ | --------------------------------------------------------------------------- |
| **Path parameter**     | `GET /api/v1/assets/2147483648`                  | `404 not_found` — in range, simply doesn't resolve to a row                 |
| **Query `_id` filter** | `GET /api/v1/locations?parent_id=2147483648`     | `200` with an empty `data[]` page — a filter that matches nothing           |
| **Request-body FK**    | `POST /api/v1/locations {"parent_id": 2147483648}` | `400 validation_error` / `code: fk_not_found` — the referenced row doesn't exist |

The bounds controls are unchanged:

| Input                                                   | Result                                          |
| ------------------------------------------------------- | ----------------------------------------------- |
| Path `0` or `-5`                                        | `400 validation_error` / `code: too_small`      |
| Non-numeric (`abc`) or an int64 overflow (20+ digits)   | `400 validation_error` / `code: invalid_value`  |

```http
GET /api/v1/assets/2147483648
```

```json
{
  "error": {
    "type": "not_found",
    "title": "Not found",
    "status": 404,
    "detail": "asset not found",
    "instance": "/api/v1/assets/2147483648",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

An id that overflows the int64 wire entirely (a 20-digit value that can't be parsed as int64) fails to decode and returns `400 validation_error` / `code: invalid_value`, not `404`. Zero and negative path ids fail the `minimum: 1` bound with `code: too_small`. Branch on `error.type` and `fields[].code` rather than parsing the `detail` string — see [Errors → Path- and query-parameter validation errors](./errors#path-and-query-parameter-validation-errors).

## What this means for clients

- **Typed-client integrators** — your generated client already represents ids at int64 width, and the `maximum: 9007199254740991` on the spec keeps every admissible id inside the JS-safe range for `number`-typed targets. Treat the int64 type as the contract; there is no runtime ceiling narrower than the wire to plan around.
- **Pasting / URL construction** — when an id reaches your code from a URL or a CSV row, a wrong value resolves to `404 not_found` (path), an empty page (query filter), or `fk_not_found` (request-body FK) rather than a range error. Validate that the value parses as an integer; the envelopes above tell you when it doesn't.
- **No migration planning required for v1** — TrakRF's v1 stability commitment ([Versioning](./versioning)) covers the wire type: it won't narrow. The id space stays within 2⁵³−1 for v1.

## Cross-references

- [Resource identifiers → Numeric `id` is a surrogate key](./resource-identifiers#numeric-id-is-a-surrogate-key) — what surrogate ids mean on the read side.
- [Errors → Path- and query-parameter validation errors](./errors#path-and-query-parameter-validation-errors) — the broader bounds-checking rule and worked examples.
- [Versioning → Stability commitment (v1)](./versioning#stability-commitment-v1) — the additive-only stance covering the wire type.
