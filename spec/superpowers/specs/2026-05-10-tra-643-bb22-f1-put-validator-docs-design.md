---
ticket: TRA-643
title: BB22 F1 — PUT validator splits silent-drop into round-trip-safe vs managed-via-subresource
status: design
date: 2026-05-10
---

# Goal

Update trakrf-docs prose to reflect platform PR [#288](https://github.com/trakrf/platform/pull/288) (merged 2026-05-10). The validator on `PUT /assets/{id}` and `PUT /locations/{id}` previously had a single global rule: any `readOnly: true` field was silently accepted and dropped. After the platform change, the rule splits in two:

1. **Round-trip-safe read-only** — `id`, `created_at`, `updated_at` (assets + locations), plus `tree_path`, `depth` (locations). Still silently accepted, still `readOnly: true` in the spec.
2. **Managed via subresource** — currently only `tags` on assets and locations. **Rejected** with `400 validation_error` / `invalid_value`. The OpenAPI spec drops `readOnly: true` from `tags` on `asset.PublicAssetView` / `location.PublicLocationView` so codegen-split SDKs surface `tags` in the request shape and consumers see the rejection signal.

The acceptance bar from the parent ticket: "the pagination-filtering-sorting docs page distinguishes the two categories of body field treatment with explicit prose", with `tags` named as the canonical example of category 2.

# Scope

## `pagination-filtering-sorting.md` — `## Validator behavior on writes`

Today's section states two rules: "read-only response fields are silently ignored on write" and "truly unknown fields are rejected." Restructure into three rules that match the new contract:

1. **Round-trip-safe read-only fields are silently accepted.** `id`, `created_at`, `updated_at` on assets and locations, plus `tree_path`, `depth` on locations. The naive `GET → mutate → PUT` round-trip is still a legal no-op for these.
2. **Managed-via-subresource fields are rejected.** Currently only `tags` on assets and locations. PUT a body containing `tags` and you get `400 validation_error` with `fields[].code = "invalid_value"`. Tag mutation goes through the subresource endpoints (`POST /assets/{asset_id}/tags`, `DELETE /assets/{asset_id}/tags/{tag_id}`, location counterparts). Cross-link to [Tag CRUD](./resource-identifiers#tag-crud).
3. **Truly unknown fields are rejected.** (Unchanged from today's prose; same `400 validation_error` envelope.)

State the rationale: the silent-drop is reserved for fields integrators can't avoid sending verbatim from a `GET` response (server-managed timestamps, derived ancestor metadata). Subresource-managed fields are intentionally surfaced as rejections so a read-modify-write integration that mutates `tags` and PUTs back gets a clear error rather than a silent no-op.

## `resource-identifiers.md` — `## Read shape vs. write shape`

Today's prose lists `tags` as one of the silently-ignored read-only fields and uses `{"tags":[]}` as an example of a no-op body. After the platform change this is wrong on multiple lines:

- L138 — "server silently ignores these read-only fields on PUT" → split into round-trip-safe (silently ignored) and managed-via-subresource (rejected).
- L140 — `{"tags":[]}` listed as a no-op body that returns 200 → drop this example. `{"tags":[]}` is now a 400.
- L145–155 — naive round-trip curl example claims `tags` is silently ignored → naive round-trip with verbatim GET body is now a 400. Either reframe to strip `tags` first (small change, preserves the example), or replace with prose that points partners at the explicit-strip pattern.
- L157–170 — `del(.id, .created_at, .updated_at, .tags)` jq strip example → still correct; reword the framing prose to call out that `tags` must be stripped (it's the rejection case) while the others may be kept (silent-drop case).
- L172 — "for assets the read-only set today is `id`, `created_at`, `updated_at`, and `tags`. For locations: ..., `tags`." → drop `tags` from both lists, since `tags` is no longer in the silent-drop set. Add a callout that `tags` is the managed-via-subresource case and link forward to [Tag CRUD](#tag-crud).
- L174 — "rely on a generated client" → still true (codegen now keeps `tags` writable in the request shape so SDK consumers see the rejection rather than a silent drop).

Decision: keep the naive round-trip example by stripping `tags` from the request body before PUT. This matches what platform PR #288's integration tests now do (`TestPutAsset_GETBodyRoundTrip_Succeeds` strips `tags`), and the example continues to demonstrate the verbatim-GET-then-mutate idiom that integrators reach for. The prose around it gains one sentence: `tags` is rejected, not silently dropped, so the GET→PUT idiom requires stripping it.

# Out of scope

- The OpenAPI spec mirror has already been refreshed (commit on this branch). No further spec edits.
- BB23 verification of the live behavior is the parent ticket's responsibility, not this PR.
- No other resources have managed-via-subresource fields today, so no further pages are affected.

# Audit-adjacent check

Verified before editing:

- `docs/api/errors.md` — generic validation_error / bad_request prose; no specific `tags`-on-PUT example. No edits needed.
- Search for `tags` across `docs/api/*.md` confirms only `resource-identifiers.md` (L140, L146, L163, L172) and `pagination-filtering-sorting.md` (validator section) reference `tags` in a writability context. The `## Tags use a composite natural key` section in `resource-identifiers.md` is correct as-is — it already directs partners to subresource endpoints for tag mutation.
- `quickstart.mdx`, `webhooks.md`, `private-endpoints.md`, `versioning.md`, `date-fields.md`, `authentication.md` — checked, no writability claims about `tags` to update.
