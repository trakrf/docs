---
sidebar_position: 8
title: HTTP method coverage
---

# HTTP method coverage

Two HTTP methods are intentionally **not** enumerated per path in the [OpenAPI reference](/api) — they're handled uniformly across every endpoint, and listing them per path would balloon the spec without telling integrators anything new. This page documents how the API handles them and how to discover what each path supports without parsing the spec.

## `HEAD` — wherever `GET` is declared

`HEAD` is supported on every endpoint that declares `get`. The server transparently strips the response body and returns the same status and headers as the matching `GET`. Authentication, scope checks, rate-limit accounting, and `404` / `405` behavior all match `GET` exactly.

Use `HEAD` for cheap existence and auth probes that don't need the payload — health checks, key validity probes, "does this asset id resolve?" — without paying the response-encoding cost.

```bash
# Cheap existence probe
curl -I -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287"
```

`HEAD` is not enumerated as a separate operation per path — assume it wherever `GET` is declared.

## `OPTIONS` — uniformly 405 on the public surface {#options}

The TrakRF API is **server-to-server only — no third-party browser origins are permitted**, so the production and preview deploys ship with CORS disabled. Under that posture, `OPTIONS` is treated as an unsupported verb and returns `405 Method Not Allowed` with an `Allow` header listing the methods the path actually supports — the same shape as any other `405` ([Discovering supported methods at runtime](#discovering-supported-methods-at-runtime)). There is no `Access-Control-Allow-Origin` (and no other `Access-Control-Allow-*` headers). A browser issuing the automatic preflight before a cross-origin call sees the `405`, refuses the actual call, and surfaces a CORS error to your console — which is the intended outcome. Call the API from a backend service instead (see [Authentication → Server-to-server design](./authentication#server-to-server)).

CORS-enabled deploys (not used for public traffic today) keep the standard `204 No Content` preflight response with `Access-Control-Allow-Methods` and friends — included here only to explain why a self-hosted or future-environment caller might see a different shape than production.

Server-to-server clients won't normally invoke `OPTIONS` at all; the `Allow` header on any `405` is the runtime way to discover supported methods, and `OPTIONS` is one of the verbs that produces such a `405`.

## Request body `Content-Type` per method {#patch-content-type}

The TrakRF API enforces a strict media type per write method, matching what the OpenAPI spec declares for each operation's `requestBody.content`. Sending the wrong type returns `415 unsupported_media_type` with a method-aware detail string ([Errors → unsupported_media_type](./errors#error-type-catalog)).

| Method   | Required `Content-Type`        | Body shape                                                                    |
| -------- | ------------------------------ | ----------------------------------------------------------------------------- |
| `POST`   | `application/json`             | Full resource (create) or operation payload (`/rename`, `/tags`).             |
| `PATCH`  | `application/merge-patch+json` | JSON Merge Patch ([RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396)). |
| `DELETE` | — (no body)                    | —                                                                             |

`PATCH` requires `application/merge-patch+json` **exclusively** — sending a `PATCH` body with `application/json` returns `415 unsupported_media_type` with `detail: "Content-Type must be application/merge-patch+json on PATCH operations"`. The merge-patch media type is the surface signal of the merge-patch semantics: omitted fields stay as-is, `null` clears a writable-nullable field, round-trip-safe read-only fields (`id`, timestamps, `location_external_key` on assets) are silently dropped, and fields with a dedicated mutation surface (`tags`, `external_key`, `parent_external_key` on locations) return `400 validation_error`. See [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) for the body rules. POST endpoints (`/assets`, `/locations`, `/rename`, `/tags`) require `application/json` and reject `application/merge-patch+json` for the same reason in reverse.

A `charset=utf-8` parameter on the media type is accepted; any other media type — `text/plain`, `multipart/form-data`, a typo'd subtype — returns `415` regardless of method.

**A missing `Content-Type` header is also rejected.** `POST` and `PATCH` requests that omit the header entirely return `415 unsupported_media_type` with the same method-aware detail string. The "Required `Content-Type`" column above is the value you must send — not "what's accepted if you choose to send one." The only write surface that accepts a non-JSON body is the internal bulk-CSV upload at `/api/v1/assets/bulk` (`multipart/form-data`); every public-surface write requires the JSON media type declared for its method.

TypeScript integrators using [`openapi-fetch`](https://openapi-ts.dev/openapi-fetch/) need a small middleware to flip `Content-Type` on `PATCH` — see [Quickstart → TypeScript with `openapi-fetch`](./quickstart#openapi-fetch) for a drop-in snippet. Other TypeScript codegen targets (`openapi-generator-cli`'s `typescript-fetch`) and Python's `openapi-generator` handle merge-patch correctly out of the box.

## Discovering supported methods at runtime

To probe which methods a path supports without consulting the spec, send any request that triggers a `405` and read the response `Allow` header (per [RFC 7231 §6.5.5](https://datatracker.ietf.org/doc/html/rfc7231#section-6.5.5)). The same value lands in the error envelope's `detail`, so a JSON-only client can branch without reading raw headers:

```bash
curl -i -X PATCH -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets"
```

```text
HTTP/1.1 405 Method Not Allowed
Allow: GET, HEAD, POST
Content-Type: application/json
```

```json
{
  "error": {
    "type": "method_not_allowed",
    "title": "Method not allowed",
    "status": 405,
    "detail": "Allowed methods: GET, HEAD, POST",
    "instance": "/api/v1/assets"
  }
}
```

`HEAD` appears in `Allow` wherever `GET` does. `OPTIONS` is not listed in `Allow` either — it's the verb that produces the `405` on CORS-disabled deploys (see [OPTIONS](#options) above).

## `Location` header on `201 Created`

Top-level `POST` creates return a `Location` header pointing at the canonical resource URL — `POST /api/v1/assets` and `POST /api/v1/locations` both set `Location: /api/v1/{resource}/{id}` on the `201` response, mirroring the `{ "data": { "id": ..., ... } }` body. Use either signal to discover the freshly-assigned id; an integrator who already reads the response body doesn't need the header.

Sub-resource `POST` creates — `POST /api/v1/assets/{asset_id}/tags` and `POST /api/v1/locations/{location_id}/tags` — do **not** set a `Location` header. The parent URL is already known to the caller, and tags have no top-level canonical URL of their own (see [Tag CRUD](./resource-identifiers#tag-crud)) — emitting a header pointing to the parent or to a non-routable per-tag path would mislead more than help. The omission is by design and is enforced by a Spectral rule on the spec; future sub-resource creates will follow the same policy.

## Related

- [Errors → Error type catalog](./errors#error-type-catalog) — the `405 method_not_allowed` row and envelope shape.
