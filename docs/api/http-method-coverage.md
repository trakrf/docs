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
curl -I -H "Authorization: Bearer $TRAKRF_ACCESS_TOKEN" \
     "$BASE_URL/api/v1/assets/4287"
```

`HEAD` is not enumerated as a separate operation per path — assume it wherever `GET` is declared.

The spec carries no `head:` entries by design — declaring 22 of them would balloon the surface without adding contract that isn't already implied by the `GET` declarations. The runtime signal is the `Allow` header on a `405` response, which lists `HEAD` alongside the methods the route declares ([Discovering supported methods at runtime](#discovering-supported-methods-at-runtime)). **Generated typed clients (`openapi-generator-cli`, `openapi-fetch`, `oapi-codegen`, NSwag, etc.) will not expose a `HEAD` method on their client classes** because no spec entry drives the codegen; reach for raw `fetch` / `requests` / `http.NewRequest` when you need a `HEAD` probe from a generated SDK.

## `OPTIONS` — CORS preflight (`204`) {#options}

The API supports cross-origin browser access. A CORS preflight — an `OPTIONS` request on any `/api/v1/*` route — returns `204 No Content` with no body and no `Allow` header:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD, POST, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Request-ID
Access-Control-Max-Age: 3600
```

These `Access-Control-*` headers are present on every response, including unauthenticated ones (e.g. a `401`). The preflight is handled before authentication, so server-to-server clients — which never issue `OPTIONS` — are unaffected. See [Authentication → Server-to-server design](./authentication#server-to-server) for why permissive CORS is safe alongside bearer auth.

Because `OPTIONS` is answered as a preflight rather than routed as a normal verb, it never returns a `405` or an `Allow` header. To discover which methods a path supports at runtime, send a genuinely unsupported verb and read the `Allow` header on the `405` ([Discovering supported methods at runtime](#discovering-supported-methods-at-runtime)).

## Request body `Content-Type` per method {#patch-content-type}

The TrakRF API enforces a strict media type per write method, matching what the OpenAPI spec declares for each operation's `requestBody.content`. Sending the wrong type returns `415 unsupported_media_type` with a method-aware detail string ([Errors → unsupported_media_type](./errors#error-type-catalog)).

| Method   | Required `Content-Type`        | Body shape                                                                    |
| -------- | ------------------------------ | ----------------------------------------------------------------------------- |
| `POST`   | `application/json`             | Full resource (create) or operation payload (`/rename`, `/tags`).             |
| `PATCH`  | `application/merge-patch+json` | JSON Merge Patch ([RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396)). |
| `DELETE` | — (no body)                    | —                                                                             |

`PATCH` requires `application/merge-patch+json` **exclusively** — sending a `PATCH` body with `application/json` returns `415 unsupported_media_type` with `detail: "Content-Type must be application/merge-patch+json on PATCH operations"`. (The POST-side 415 detail omits the method suffix, emitting plain `"Content-Type must be application/json"`. Branch on `error.type`, not on `detail` — see [Errors → unsupported_media_type](./errors#error-type-catalog).) The merge-patch media type is the surface signal of the merge-patch semantics: omitted fields stay as-is, `null` clears a writable-nullable field, and fields not directly settable on `PATCH` are validated against current state — a value that matches the live resource is silently stripped (enabling verbatim `GET` → `PATCH` round-trips without client-side scrubbing), and a differing value returns `400 validation_error` with a `message` naming the dedicated write path. The rejection `code` splits along whether the field has a partner-mutable write path: truly server-managed fields (`id`, timestamps) and the scan-derived asset `location_*` fields return `code: read_only`; fields settable on the resource but via a different verb — `external_key` via `POST /{resource}/{id}/rename` and the `tags` collection via the `/tags` sub-resource (`POST` and `DELETE`) — return `code: invalid_context`. On locations, both `parent_id` and `parent_external_key` are fully writable on `PATCH` for re-parenting and are not part of this rule. See [Errors → Validation errors](./errors#validation-errors) for the code catalog and [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) for the body rules and the full per-field accounting. POST endpoints (`/assets`, `/locations`, `/rename`, `/tags`) require `application/json` and reject `application/merge-patch+json` for the same reason in reverse.

A `charset=utf-8` parameter on the media type is accepted; any other media type — `text/plain`, `multipart/form-data`, a typo'd subtype — returns `415` regardless of method.

**A missing `Content-Type` header is also rejected.** `POST` and `PATCH` requests that omit the header entirely return `415 unsupported_media_type` with the same method-aware detail string. The "Required `Content-Type`" column above is the value you must send — not "what's accepted if you choose to send one." The only write surface that accepts a non-JSON body is the internal bulk-CSV upload at `/api/v1/assets/bulk` (`multipart/form-data`); every public-surface write requires the JSON media type declared for its method.

TypeScript integrators using [`openapi-fetch`](https://openapi-ts.dev/openapi-fetch/) need a small middleware to flip `Content-Type` on `PATCH` — see [Quickstart → TypeScript with `openapi-fetch`](./quickstart#openapi-fetch) for a drop-in snippet. Other TypeScript codegen targets (`openapi-generator-cli`'s `typescript-fetch`) and Python's `openapi-generator` handle merge-patch correctly out of the box.

## Discovering supported methods at runtime

To probe which methods a path supports without consulting the spec, send any request that triggers a `405` and read the response `Allow` header (per [RFC 7231 §6.5.5](https://datatracker.ietf.org/doc/html/rfc7231#section-6.5.5)). The same value lands in the error envelope's `detail`, so a JSON-only client can branch without reading raw headers:

```bash
curl -i -X PATCH -H "Authorization: Bearer $TRAKRF_ACCESS_TOKEN" \
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

`HEAD` appears in `Allow` wherever `GET` does. `OPTIONS` is never listed in `Allow` — it's answered as a CORS preflight (`204`, see [OPTIONS](#options) above), not routed through the `405` path. Use any genuinely unsupported verb — like the `PATCH` probe above — to trigger the `405` that carries the `Allow` header.

## `Location` header on `201 Created`

Top-level `POST` creates return a `Location` header pointing at the canonical resource URL — `POST /api/v1/assets` and `POST /api/v1/locations` both set `Location: /api/v1/{resource}/{id}` on the `201` response, mirroring the `{ "data": { "id": ..., ... } }` body. Use either signal to discover the freshly-assigned id; an integrator who already reads the response body doesn't need the header.

Sub-resource `POST` creates — `POST /api/v1/assets/{asset_id}/tags` and `POST /api/v1/locations/{location_id}/tags` — also set a `Location` header pointing at the canonical subresource URL `/api/v1/{resource}/{id}/tags/{tag_id}`. The URL matches the path the `DELETE /api/v1/{resource}/{id}/tags/{tag_id}` endpoint accepts, so a caller that wants to detach a freshly-attached tag can follow the `Location` value verbatim. Tags have no top-level canonical URL of their own (see [Tag CRUD](./resource-identifiers#tag-crud)); the header points at the parent-qualified path, not a non-routable bare `/tags/{tag_id}`. The spec declares the header on both subresource POSTs alongside the existing top-level pair.

## Related

- [Errors → Error type catalog](./errors#error-type-catalog) — the `405 method_not_allowed` row and envelope shape.
