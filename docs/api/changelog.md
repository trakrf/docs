---
sidebar_position: 8
title: Changelog
---

# Changelog

This log records changes to the TrakRF public API under `/api/v1/` that affect integrators. Entries follow the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) convention with the v1 stability commitment in [Versioning](./versioning): within v1, changes are additive only — no silent breaking changes. Deprecations are flagged at least six months before sunset via RFC 8594 headers.

## v1.0 — Launch (TBD)

Initial public API release. Stable contract for paths, field names, response shapes, and error envelopes per the [v1 stability commitment](./versioning).

### Pre-launch hardening (BB27 / contract-test follow-ups)

These changes flowed into the `v1.0.0` spec and into shipped behavior ahead of launch. Listed here for partners tracking the docs / spec mirror; none are breaking against a `v1.0.0`-or-later baseline.

**Spec hygiene**

- **`info.version: 1.0.0`** (was `v1`). URL versioning under `/api/v1/` is unchanged; the spec-document version and the URL version evolve independently.
- **Integer path-param `maximum: 2147483647`** (was `9007199254740991`). Path-param `id`s are now bounded by the underlying `int4` column. Values in the previously-accepted range `(2^31 - 1, 2^53 - 1]` return `400 validation_error` with `params.max=2147483647` instead of falling through to a `500 internal_error` from the database driver.
- **Every integer field declares `format: int32`.** Code generators emit width-bounded `int32` types — `number` in TS, `int` in Python, `int32` in Go/Java — rather than a permissive `integer`. No runtime behavior change.
- **Every operation declares a `default` response** pointing at the `ErrorResponse` envelope. Code generators that emit discriminated-union response types now get a real catch-all branch.
- **Date / date-time properties carry RFC 3339 `example:` values.** Visible in Redoc's example panel.

**`PATCH` round-trip and read-only handling**

- **Full-object `PATCH` round-trip is now supported.** Sending `external_key`, `tags`, or any other read-only field (`id`, `created_at`, `updated_at`, `*_deleted_at`, `tree_path`, `depth`) in a `PATCH` body returns `200` with the field silently ignored. Mutate `external_key` via `POST /api/v1/{resource}/{id}/rename` and tags via `POST /api/v1/{resource}/{id}/tags` (and the `DELETE` counterparts). Reverses earlier guidance that called these fields "rejected with `400 immutable_field`" / "rejected with `400 invalid_value`." See [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) for the per-resource read-only set.
- **`immutable_field` validation code retired.** No remaining emitter; previously only fired for `external_key` on `PATCH`. Clients that branched on the code can drop the case.

**FK and validator consistency**

- **FK envelope is consistent across surrogate and natural-key forms.** A non-existent `location_id` (or `parent_id`) returns the same `400 validation_error` / `invalid_value` envelope as a non-existent `location_external_key` (or `parent_external_key`); previously the surrogate-key form fell through to `500 internal_error`.
- **`description: ""` is rejected with `too_short`.** Sending an empty string on `POST` or `PATCH` for `description` returns `400 validation_error` / `code: too_short` / `params.min_length=1`, matching every other length-bearing string field. Send explicit `null` to clear the field.
- **`too_short` is now uniform on length-bearing required fields.** `POST /api/v1/assets {}` previously emitted `fields[0].code = required`; all length-bearing required fields now emit `too_short` consistently, matching the [errors page](./errors#validation-errors).
- **`valid_from: null` accepted on `POST`, rejected on `PATCH`.** See [Date fields → `valid_from: null` on Create vs. Update](./date-fields#valid_from-null-on-create-vs-update). Useful for ETL or migration code that emits explicit `null` for "use server default."

**Errors and conflict messages**

- **`5xx` responses no longer leak database driver strings in `error.detail`.** `error.detail` on `500` is a fixed generic string; the underlying cause is logged server-side and correlatable through the `request_id` in the envelope.
- **Tag conflict error strings use "tag," not "identifier."** A duplicate `(tag_type, value)` on `POST /api/v1/{resource}/{id}/tags` returns `detail: "tag rfid:E2-… already exists"`. String-matching on the literal word `tag` is now correct everywhere caller-visible.

**Spec hygiene — Phase 3.5 (Schemathesis gate flip)**

Final spec + validator changes flowing into `v1.0.0` ahead of flipping the Schemathesis contract-test gate to blocking ([TRA-678](https://linear.app/trakrf/issue/TRA-678)).

- **Breaking change for generated clients: the `sort` query parameter shape changed from array to comma-separated string.** Regenerate clients from the updated spec. The wire form integrators send is unchanged (`?sort=-created_at,external_key`); the spec now declares `sort` as `type: string` with a CSV-shaped `pattern:` regex instead of `type: array` with `style: form, explode: false`. Generated clients that previously typed `sort` as `string[]` will now type it as `string`. Hand-rolled clients building the query string directly are unaffected.
- **Write request bodies declare `additionalProperties: false`.** Unknown top-level keys in `POST` and `PATCH` bodies are rejected at the schema boundary with `400 validation_error` rather than silently accepted. The existing [silent-accept rule for read-only fields](./pagination-filtering-sorting#validator-behavior-on-writes) is unchanged — those are not "unknown" keys, they're declared `readOnly: true` on the read shape.
- **Printable-string validation on body strings and `q` filters.** `name`, `description`, tag `value`, and the `q` substring-search query param reject NUL bytes and other ASCII control characters at the validator with `400 validation_error`. Previously these could reach the storage layer and surface as `500 internal_error` from a downstream `invalid_text_representation` (SQLSTATE 22021).
- **RFC 3339 `pattern:` on every `format: date-time` property.** Date-time fields now carry a strict regex `pattern:` in addition to the `format:` keyword, so codegen tools that honor `pattern` reject malformed timestamps client-side; the server already validated the RFC 3339 profile and continues to return `400 validation_error` for bad input.
- **Surrogate-id query filters and `offset` are int4-bounded.** `*_id` query filter items declare `minimum: 1` / `maximum: 2147483647`; `offset` declares `minimum: 0` / `maximum: 2147483647`. Out-of-range values return `400 validation_error` rather than overflowing into the database driver.
