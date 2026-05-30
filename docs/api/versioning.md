---
sidebar_position: 7
title: Versioning
---

# Versioning

The TrakRF API uses URL-path versioning (`/api/v1/`) with a strong stability commitment: within a major version, changes are **additive only**. This page spells out what "additive" means, how deprecations work, and which parts of the response shape are considered "closed" vs "open" — the distinction that lets clients stay forward-compatible.

## Stability commitment (v1)

The v1 stability commitment begins at public launch. Field renames and shape adjustments that landed before launch — including the canonical `id` + `external_key` rename ([Changelog](./changelog)) — are pre-stability vocabulary cleanup, not v1 breaks. Once launched, `/api/v1/` is stable per the rules below.

Within `/api/v1/`, TrakRF commits to the following:

**Will not change without a new major version:**

- Endpoint URL paths
- HTTP methods on existing endpoints
- Required request parameters (names, types, shape)
- Response field names and types for fields currently returned
- HTTP status codes used for success and well-known error classes (see [Errors](./errors))
- The response envelope shape (`{ "data": ..., "limit": ..., "offset": ..., "total_count": ... }` on list endpoints; `{ "data": ... }` on single-resource endpoints; `{ "error": { ... } }` on non-2xx — see [Errors](./errors))

**May change additively within v1:**

- New endpoints
- New optional request parameters
- New fields on response objects
- New values in **extensible enums** (see below)
- New error `type` values

Clients written against v1 will continue to work as TrakRF adds features. Clients that treat unknown response fields or unknown enum values as errors will not — so don't.

### The surrogate `id` is an internal anchor, not your join key

The `id` field is stable and won't be arbitrarily rekeyed, which makes it a usable sync / reconciliation anchor. It is **not** the integrator's business foreign key — don't key your own system of record on it. Join on the natural key (`external_key`) where one exists; see [Resource identifiers → Joining your system of record](./resource-identifiers#joining-your-system-of-record). The field-stability commitment above (names and types of returned fields don't change without a major version) is the contract that applies to `id`; TrakRF does not publish a permanence guarantee beyond it, because treating `id` as a durable external business key re-introduces the coupling the natural-key model is designed to avoid.

## Open vs closed enums

Enums on the wire come in two flavors, and the difference matters for client code:

|                 | Closed                            | Open (extensible)                                            |
| --------------- | --------------------------------- | ------------------------------------------------------------ |
| Stability       | Set of values is fixed for v1     | Set grows over time; new values may appear in any v1 release |
| Client handling | Safe to exhaustively switch/match | Must handle unknown values gracefully                        |
| OpenAPI marker  | Plain `enum`                      | `enum` + `x-extensible-enum: true`                           |

### Closed enums in v1

These enum sets will not grow within v1:

- **HTTP status codes** — TrakRF uses the standard HTTP status set. Status code 200 means success, 400 means client error, etc. The _set_ is closed even though individual endpoints may start or stop using a given code as the surface grows.
- **Pagination envelope fields** — `limit`, `offset`, `total_count`, `data` are the only keys on a list envelope.

### Open (extensible) enums in v1

These are designed to grow:

- **Error `type`** (`ErrorResponse.error.type`) — marked `x-extensible-enum: true` in the spec. Current values are documented in the [errors catalog](./errors#error-type-catalog); future values may appear in any v1 release. Clients should branch on HTTP status (closed) for retry/alerting policy and treat unknown `type` values as generic errors of that status class.
- **Validation field codes** (`fields[i].code` on `validation_error` responses) — current set is `required`, `invalid_value`, `unknown_field`, `invalid_context`, `too_short`, `too_long`, `too_small`, `too_large`, `fk_not_found`, `ambiguous_fields`, `read_only`. New codes may appear. Treat unknown codes as generic invalid-value and surface the `message` field.
- **`tag_type` discriminator** (`Tag.tag_type` on every tag variant; the `oneOf` discriminator mapping) — current values are `rfid`, `ble`, `barcode`. New variants may be added as additive minor revisions; integrators should treat unknown variants as forward-compatible and pass them through untouched. See [Resource identifiers → Tag is a polymorphic resource](./resource-identifiers#tag-is-a-polymorphic-resource).

The `x-extensible-enum: true` annotation captures intent but is not honored by today's mainstream OpenAPI codegen. `openapi-typescript@7.x` and `openapi-generator-cli` (Go, Java, Python targets among others) emit these as closed unions or fixed enum types; generated clients reject unknown values at parse time. Treat the annotation as documentation of TrakRF's stability contract, not as a generator hint — write client code against the [unknown-value pattern below](#how-to-handle-unknown-values-in-client-code), and bypass the generated enum type when surfacing the raw `type` / `code` value to your own logic.

**Scope strings are not an enum.** The scopes on an API-key response (`scopes` on `GET /orgs/me`, the scope columns in the UI) are a free-form array of strings — not a wire enum, so they carry no `x-extensible-enum` marker and aren't a closed set either. TrakRF may introduce new scopes (e.g. `reports:read`, `webhooks:write`) in any v1 release, so apply the same discipline: clients that display the scopes available to a key must render unknown scope strings as-is rather than filtering them out.

### How to handle unknown values in client code

The golden rule: **never treat an unknown enum value as a server bug**. Typical patterns:

```python
# Good: fall through to a generic handler
def handle_error(err):
    match err["status"]:
        case 429: return retry_after(err)
        case 500: return retry_with_backoff()
        case s if 400 <= s < 500: return surface_to_user(err["detail"])
        case _: return generic_error(err)

# Bad: this breaks when a new type is added
def handle_error(err):
    if err["type"] == "validation_error": ...
    elif err["type"] == "unauthorized": ...
    else: raise UnexpectedServerBehavior()  # <-- don't
```

For TypeScript, type the open enum as `"validation_error" | "bad_request" | ... | (string & {})` so unknown values remain assignable without loosening everything to `string`.

## Deprecation policy

When an endpoint or response field is slated for removal, TrakRF marks it deprecated _at least six months_ before the sunset date, following [RFC 8594](https://datatracker.ietf.org/doc/html/rfc8594):

```
HTTP/1.1 200 OK
Deprecation: true
Sunset: Wed, 11 Nov 2026 23:59:59 GMT
```

- `Deprecation: true` — the endpoint is still functional but scheduled for removal.
- `Sunset` — the last date the endpoint will return 2xx responses. After this date, requests return `410 Gone`.

The six-month gap is a floor, not a target. Breaking changes that can wait longer, will.

**How clients should respond:** log `Deprecation` / `Sunset` headers in your own monitoring so you get advance warning without constantly reading changelogs. When one appears, check the [Changelog](./changelog) for migration guidance.

**Current status:** no endpoints or fields are deprecated at v1 launch. This mechanism is in place so future deprecations don't surprise integrators.

## Major version bumps

A v2 would be introduced only for changes that genuinely can't be expressed additively — e.g. a restructured envelope, a changed auth model, removed fields. When that happens:

- v1 continues to operate under the RFC 8594 deprecation schedule (6+ months overlap).
- v2 is served at `/api/v2/` — paths never collide with v1.
- The migration path is documented in [Changelog](./changelog) before v2 ships.

No v2 is currently planned.

## Seeing changes as they land

- **Interactive reference** — [`/api`](/api) is regenerated from the Go handlers on every platform release, so it always reflects the running surface.
- **Raw spec** — <a href="/api/openapi.json"><code>/api/openapi.json</code></a> or <a href="/api/openapi.yaml"><code>.yaml</code></a> for diffing between releases with your own tooling.
- **Changelog** — [Changelog](./changelog) lists public-API-affecting changes with `added` / `deprecated` / `removed` categories.

## Related

- [Changelog](./changelog) — release-by-release record of added / deprecated / removed
- [Errors](./errors) — error `type` catalog (an extensible enum in practice)
- [Authentication](./authentication) — scope strings (a free-form string array, handled like an open enum)
