---
title: Design notes
---

# Design notes

These are choices we made on purpose, with reasons. Some look weird at first. If something in the API surprises you and you find yourself thinking "wait, why would they do that?" — chances are it's listed here with the explanation. If your eyebrow is raising about something not listed, that might be a real bug. [File it](mailto:support@trakrf.id).

## `HEAD` method not declared in the OpenAPI spec

`HEAD` is supported on every resource per [RFC 7231 §4.3.2](https://datatracker.ietf.org/doc/html/rfc7231#section-4.3.2) — every `GET` endpoint also accepts `HEAD` requests, returning identical headers and an empty body.

We don't declare `head:` operations in the OpenAPI spec. Declaring `HEAD` on 22 paths would balloon the spec for nearly zero codegen benefit — major typed generators (`openapi-typescript`, `openapi-generator-cli` python, `oapi-codegen`) don't expose `HEAD` on generated client classes regardless of whether it's declared.

For runtime discoverability, the `Allow` header on `405 Method Not Allowed` responses lists every supported method including `HEAD`. See [HTTP method coverage → `HEAD` wherever `GET` is declared](./http-method-coverage#head--wherever-get-is-declared) for usage and the runtime discovery pattern.

## Tag schema uses three single-value enums for the discriminator

The `Tag` polymorphic schema uses three single-value enum classes — `RfidTagRequest.tag_type: enum: [rfid]`, `BleTagRequest.tag_type: enum: [ble]`, `BarcodeTagRequest.tag_type: enum: [barcode]` — rather than a single shared discriminator field.

This is an OpenAPI 3.0 workaround for the `allOf`-with-siblings limitation: `tag_type` with `allOf` references plus sibling JSON Schema keywords breaks Pydantic-strict generators. The current three-enum pattern is the workaround that keeps the discriminator legible across all generators.

How different generators surface this:

- `openapi-typescript`: clean discriminated union.
- `openapi-generator-cli` python target: one model per variant — usable.
- `datamodel-codegen`: produces three separate enum classes (`TagType`, `TagType2`, `TagType4`), which reads confusingly — generator-specific quirk.

## Nullable fields use OpenAPI 3.0 `nullable: true`

We're on OpenAPI 3.0.3. Nullable response fields use `nullable: true` rather than the OpenAPI 3.1 type-union syntax (`type: ["string", "null"]`).

Generator behavior varies:

- **Verified-working:** `openapi-typescript@7.x` (emits `string | null`) and `openapi-generator-cli` python target (emits `Optional[StrictStr]`). Both round-trip CRUD against null-bearing responses unmodified.
- **Known-broken:** `datamodel-codegen` 0.57.0 emits nullable fields as non-Optional required types. Pydantic validation fails on every nullable field that's actually `null`.

For integrators using `datamodel-codegen`, switch to one of the verified-working targets, or apply `--use-annotated --use-union-operator` flags with custom post-processing.

We'll migrate to OpenAPI 3.1 type-union syntax when the generator ecosystem stabilizes 3.1 support across all targets we care about.

**Pairing with `openapi-fetch`?** The other stack-specific gotcha worth knowing about lives in the quickstart, not here: `openapi-fetch` is schema-agnostic at runtime and won't read `application/merge-patch+json` from the spec, so every `PATCH` returns `415` unless you override the request `Content-Type`. The [`mergePatchMiddleware` recipe](./quickstart#openapi-fetch) is a drop-in fix that handles every `PATCH` call site with a single `client.use(...)` registration.

## Timestamps on the wire carry fixed millisecond precision

Every outbound RFC 3339 timestamp the public API emits — `valid_from`, `valid_to`, `created_at`, `updated_at`, `deleted_at`, `event_observed_at`, `asset_last_seen` — uses fixed three-digit millisecond fractional precision (`.NNNZ`), never microsecond or nanosecond. Sub-millisecond input is accepted but truncated toward zero before emission; sub-microsecond input is further truncated at microsecond storage. The wire is intentionally narrower than storage: scan-event timestamps carry millisecond-scale network jitter from the reader path, so the bottom digits would be false precision relative to what reader clients can act on.

Full rules — inbound parsing, sentinel rejection, the storage-vs-wire boundary, and the audit-timestamp echo-or-omit contract — live on the dedicated page: see [Date fields](./date-fields).

## `updated_at` is an optimistic-concurrency token on `PATCH`

`updated_at` carries `readOnly: true` in the spec, which correctly tells codegen to omit it from request shapes — generated SDKs decode it from responses but won't include it in PATCH bodies they construct. The annotation alone, though, doesn't convey the runtime contract when a hand-rolled caller (or any caller round-tripping the full read shape) does include the field: the server applies the same [accept-if-matches, reject-if-differs](./resource-identifiers#read-shape-vs-write-shape) rule it applies to every other read-only field, and the rejection path is precisely the lost-update detection signal a write-heavy integration needs.

A PATCH whose body includes `updated_at` matching the resource's current value silently normalizes the field out — the PATCH proceeds as if `updated_at` were absent. A PATCH whose body includes a **stale** `updated_at` (a value an interim writer has since superseded) returns `400 validation_error` / `code: read_only` with `fields[0].message` naming the mismatch.

```http
GET /api/v1/assets/123
# response body excerpt:
# { "id": 123, "name": "Pallet jack 7", "updated_at": "2026-05-18T15:00:00.000Z", ... }

# ... your client makes local edits to the pallet-jack record ...

PATCH /api/v1/assets/123
Content-Type: application/merge-patch+json

{
  "description": "Awaiting servicing",
  "updated_at": "2026-05-18T15:00:00.000Z"
}
```

If no concurrent writer has touched the row in the interim, the PATCH succeeds and the response carries a new `updated_at`. If another writer has landed first, the same request returns `400 validation_error` with `fields[0]` describing the `updated_at` mismatch — the client refetches, reconciles its local edits against the new state, and retries.

**What the token detects, exactly.** `updated_at` tracks "a write request against this row succeeded" — not "the data on this row changed." A `PATCH {}` from a health probe, a writable-echo `PATCH` where every body field matches current state, and a no-content admin touch all advance `updated_at`; this is the filesystem `touch` analogy in full, and it's deliberate. The consequence for the concurrency-token use case: if any caller pokes the row between your `GET` and your `PATCH` (even with empty body), your `PATCH` carrying the GET-time `updated_at` fails with `code: read_only` on `updated_at` — correctly. There was an intervening successful write, and your submission was constructed against state that may no longer reflect the row's full history; the token did its job. If your integration needs "data has changed" detection rather than "a write request happened" detection, diff resource fields directly. The concurrency token gives you the latter, deliberately.

Opting out is the default for clients that don't need lost-update detection. Omit `updated_at` from the PATCH body (or strip it from the cached GET response before echoing); the server will advance it on every successful write regardless. Single-writer integrations and last-writer-wins workflows can ignore the field entirely without surprises.

The pattern is one instance of the uniform [accept-if-matches, reject-if-differs](./resource-identifiers#read-shape-vs-write-shape) rule covering every field not directly settable on `PATCH`, but `updated_at` is the only one that **advances on every successful PATCH** and therefore carries useful concurrency-token signal. The other affected fields (`id`, `created_at`, `deleted_at`, `tags`, `external_key`) don't change on PATCH, so a reject-if-differs on those signals an integrator-side bug rather than a concurrent-writer conflict. The `code` splits along the field's write path: server-managed fields return `read_only`; `external_key` and `tags` (settable via dedicated subresources) return `invalid_context` — see [Errors → Validation errors](./errors#validation-errors) for the catalog.

## `descendant_count_affected` on `RenameAssetResponse` is always `0`

The rename verb shares response shape across `POST /assets/{asset_id}/rename` and `POST /locations/{location_id}/rename`. Locations legitimately use `descendant_count_affected` to surface the live count of descendant rows reachable through the `parent_id` chain — a non-zero value is the client's cue to refresh any subtree state cached under the old natural key. Assets have no hierarchy, so the field always returns `0`.

The shared envelope is preserved for ergonomic symmetry: a client that consumes both rename endpoints can read `descendant_count_affected` off either response without branching on resource type, then act on it only when non-zero. On the asset side it is structural padding.

See [Resource identifiers → Location rename](./resource-identifiers#location-rename) for the location semantics.

## Locations omit free-form `metadata` by design

The asset surface (Create / Update / View) carries a `metadata` object for arbitrary integration-defined attributes. The location surface does not — `metadata` is intentionally absent from `CreateLocationWithTagsRequest`, `UpdateLocationRequest`, and `LocationView`. A `POST /api/v1/locations` body that includes `metadata: {...}` returns `400 validation_error` / `code: unknown_field`.

Locations are hierarchical anchors and are expected to stay austere. Application-specific labels on a location should be attached via the location's tags subresource (`POST /api/v1/locations/{location_id}/tags`), and application-specific data about what's _at_ a location should live on the asset rows scanned there. If you find yourself wanting `location.metadata`, the data probably belongs on tags or on the assets instead.
