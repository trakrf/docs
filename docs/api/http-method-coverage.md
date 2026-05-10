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

## `OPTIONS` — reserved for CORS preflight

`OPTIONS` is reserved for CORS preflight. Browser clients hitting the API across origins issue an automatic `OPTIONS` request before the actual call; the server responds:

- `204 No Content` with `Access-Control-Allow-*` headers when the origin and method are allowed.
- `204 No Content` with no CORS headers when they aren't.

`OPTIONS` is not part of the resource API surface and is not a way to introspect a path's supported methods. Server-to-server clients won't normally invoke it; if you're writing a non-browser client, treat `OPTIONS` as if it doesn't exist on this API.

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

`HEAD` appears in `Allow` wherever `GET` does. `OPTIONS` does not appear — see above for why.

## Related

- [Errors → Error type catalog](./errors#error-type-catalog) — the `405 method_not_allowed` row and envelope shape.
