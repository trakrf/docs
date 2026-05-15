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
- **Known-broken:** `datamodel-codegen@0.57.0` emits nullable fields as non-Optional required types. Pydantic validation fails on every nullable field that's actually `null`.

For integrators using `datamodel-codegen`, switch to one of the verified-working targets, or apply `--use-annotated --use-union-operator` flags with custom post-processing.

We'll migrate to OpenAPI 3.1 type-union syntax when the generator ecosystem stabilizes 3.1 support across all targets we care about.

## `descendant_count_affected` on `RenameAssetResponse` is always `0`

The rename verb shares response shape across `POST /assets/{asset_id}/rename` and `POST /locations/{location_id}/rename`. Locations legitimately use `descendant_count_affected` to surface the live count of descendant rows reachable through the `parent_id` chain — a non-zero value is the client's cue to refresh any subtree state cached under the old natural key. Assets have no hierarchy, so the field always returns `0`.

The shared envelope is preserved for ergonomic symmetry: a client that consumes both rename endpoints can read `descendant_count_affected` off either response without branching on resource type, then act on it only when non-zero. On the asset side it is structural padding.

See [Resource identifiers → Location rename](./resource-identifiers#location-rename) for the location semantics.
