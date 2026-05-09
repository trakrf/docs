---
ticket: TRA-640
title: BB21 docs sweep — pagination tables, location tree, tag CRUD, identifier rules
status: design
date: 2026-05-09
---

# Goal

Consolidate the BB21 documentation findings into a single trakrf-docs PR. Source: `BB21 FINDINGS.md` sections 1.1–1.7, 2.4 (docs side), 2.5, 4.1. Sibling [TRA-641](https://linear.app/trakrf/issue/TRA-641) (platform PR [#287](https://github.com/trakrf/platform/pull/287)) merged first; this PR consumes the renamed sort enum and the new symmetric mutex on `/assets`.

The acceptance bar is that BB22 should be able to discover every finding above by reading prose pages alone, without falling back to the OpenAPI spec.

# Pre-implementation audit — what's already done

The recent TRA-636 cluster-sweep covered several of these items in passing. Verified before drafting copy:

| Item | Status before this PR | Verdict |
| --- | --- | --- |
| 1.4 — `external_key` character-set restriction | `resource-identifiers.md` §`external_key value rules` (L227+) documents the regex, the reserved-character table, and accepted/rejected examples | Partial — covered mid-page, ticket asks for it "up front" |
| 1.5 — server-mints `ASSET-NNNN` when omitted | `resource-identifiers.md` §`Asset external_key is optional` (L205+) covers the auto-mint behavior | Partial — missing the "supply explicit keys for upstream-system joins" note |
| 1.6 — `tree_path` derivation rule | `resource-identifiers.md` L197 documents lowercase + hyphen→underscore + `.`-join with a WAREHOUSE-WEST example | Partial — ticket asks for the specific WHS-01 / WHS-07-03 worked example |
| 1.7 — `depth` field | `resource-identifiers.md` shows `depth: 2` in the locations JSON example (L183) and mentions `depth` as derived ancestor metadata (L162) | Partial — never explicitly states "root is 1, children increment" |
| 1.3 — tag data primitive (composite natural key) | `resource-identifiers.md` §`Tags use a composite natural key` (L280+) covers the `(tag_type, value)` model, uniqueness, `tag_type` default, two-senses callout | Partial — CRUD endpoints, write scope, and value matching not stated |
| 1.2 — `/ancestors` exists | `resource-identifiers.md` L191–195 mentions `/ancestors` for multi-hop traversal | Partial — `/children` and `/descendants` not mentioned in any prose page; relationship to `?parent_id=X` not explained |
| 4.1 — `asset_deleted_at` visibility | `resource-identifiers.md` L107 mentions it as the present-as-null example on `report.PublicCurrentLocationItem` | Partial — neither page states the `include_deleted=true` precondition; `date-fields.md` L7 still implies a general `deleted_at` exists |
| 2.4 docs side — mutex rule | Behavior is now symmetric on `/locations` and `/assets` after platform [#287](https://github.com/trakrf/platform/pull/287); no global rule documented | Net new |
| 2.5 — round-tripping rule | `resource-identifiers.md` §`Read shape vs. write shape` (L124+) covers it well from the resource angle | Partial — ticket asks for a global callout on `pagination-filtering-sorting`, the natural lookup destination for "what does this list/PUT do with my fields" |
| 1.1 — pagination filter tables | `pagination-filtering-sorting.md` filter table omits `external_key` (`/assets`, `/locations`); no per-endpoint sort-field table | Net new |
| 2.6 sort enum rename | Spec mirror refreshed in this branch; pagination prose hasn't yet referenced the new enum names | Net new — add to the per-endpoint sort table |

# In-scope changes

## `pagination-filtering-sorting.md`

**Filter table — add `external_key` (1.1).** Add `external_key` (repeatable) to the `/assets` and `/locations` rows. The third filter table column already calls out repeatability for the `*_id` / `*_external_key` pairs; new entry follows the same shape.

**Per-endpoint sort fields — new subsection under `## Sorting` (1.1, 2.6).** Today the Sorting section says "Sortable fields vary per resource; the interactive reference at `/api` lists the exact set each endpoint accepts." Add an explicit per-endpoint table so a prose-led reader doesn't have to bounce to the spec viewer:

| Endpoint | Sort fields |
| --- | --- |
| `GET /api/v1/assets` | `external_key`, `name`, `created_at`, `updated_at` (each with `-` prefix for descending) |
| `GET /api/v1/locations` | `external_key`, `name`, `tree_path`, `created_at`, `updated_at` |
| `GET /api/v1/locations/current` | `last_seen`, `asset_external_key`, `location_external_key` (post-[TRA-641](https://linear.app/trakrf/issue/TRA-641) names) |
| `GET /api/v1/assets/{asset_id}/history` | `timestamp` |

Cross-check the actual enum sets against the refreshed spec mirror before committing — table is the source-of-truth view, not a guess.

**`/history` row in the filter table (1.1).** History endpoint already has a row for `from`/`to`. Add a footnote (or inline callout) noting it accepts the standard `limit`/`offset`/`sort` from the global Pagination and Sorting sections — same envelope as every other list endpoint.

**New subsection: round-tripping read responses on PUT (2.5).** Three short paragraphs near the top of the page (after the Response envelope section, before Pagination), or at the end as a "Validator behavior" subsection. The cleaner placement is a new `## Validator behavior on writes` section at the bottom, since this isn't list-endpoint behavior. Two rules to state:

1. Read-only response fields are silently ignored on PUT — a verbatim `GET` → `PUT` round-trip is a legal no-op. Cross-link to `resource-identifiers#read-shape-vs-write-shape` for the per-resource read-only set.
2. Truly unknown fields (typos, off-resource names) are rejected with `400 validation_error` / `fields[].field` naming the offender.

Decision recorded: place this section in pagination-filtering-sorting per the ticket, even though resource-identifiers is also a natural home — pagination is what BB cycle reviewers and AI partners reach for when reasoning about request/response shape across endpoints, and the cross-link makes the per-resource detail one click away.

**New subsection: paired-by-id-and-by-natural-key filters (2.4 docs).** Place near the Filter table (it's a filter rule, not a sort rule). Two-paragraph callout:

1. Whenever a list endpoint accepts both an id form and a natural-key form for the same logical relationship (`location_id` / `location_external_key` on `/assets`; `parent_id` / `parent_external_key` on `/locations`), the two forms are mutually exclusive in a single request — sending both returns `400 validation_error`. State the rule once for all such pairs rather than per-parameter.
2. To filter for the union, repeat one form: `?location_id=42&location_id=43`.

Note: this is distinct from the FK pair on a write body, where both `location_id` and `location_external_key` may be sent and are cross-validated for agreement (covered in `resource-identifiers#foreign-key-fields-in-responses-come-as-flat-scalar-pairs`). The list-filter mutex and the write-body cross-validation are different rules; the new section will say so explicitly.

## `resource-identifiers.md`

**1.4 — character-set callout up front.** Add a single sentence to the "String-handle concepts at a glance" section noting the constraint and pointing at `#external_key-value-rules`. Don't move the section itself — the table of accepted/rejected examples and the reserved-character rationale belong with the depth coverage in `external_key value rules`. The lede addition is a discoverability hook only.

**1.5 — explicit-keys note.** Add one sentence to the `## Asset external_key is optional` section: when integrating with an upstream system of record, supply the partner-side handle on create rather than relying on the auto-mint, since auto-minted `ASSET-NNNN` values won't join cleanly to a SKU/ERP code.

**1.6 — WHS-01 / WHS-07-03 worked example.** The current paragraph uses `WAREHOUSE-WEST` to illustrate the per-segment transformation, but never shows a multi-segment path. Add the explicit two-row table the ticket asks for, immediately after the prose rule:

| `external_key` | `tree_path` |
| --- | --- |
| `WHS-01` (root) | `whs_01` |
| `WHS-07-03` (child of `WHS-01`) | `whs_01.whs_07_03` |

Keep the WAREHOUSE-WEST sentence — it explains the per-segment derivation; the WHS table shows the multi-segment join. Both are doing different work.

**1.7 — `depth` explicit doc.** Inside the `Locations: parent_id and parent_external_key` section (where `depth: 2` already appears in the JSON example), add one sentence: root locations have `depth: 1`; children increment from there. Note that `depth` is read-only (already covered as part of the location read-only set at L162).

**1.2 — Location tree endpoints subsection.** New `## Location tree endpoints` section after the `Locations: parent_id and parent_external_key` section. Three endpoints with what they return, an example request/response shape (one is enough — they all use the standard list envelope), and a contrast paragraph:

- `/{location_id}/ancestors` walks parent chain to root (1 → root, ordered nearest-to-farthest)
- `/{location_id}/children` returns immediate children only (single-level)
- `/{location_id}/descendants` returns the full subtree (multi-level)

Then: "These are distinct from the `?parent_id=X` filter on `GET /api/v1/locations`. The filter is a single-level lookup against the parent reference — equivalent to `/{X}/children` for the immediate-child case. The dedicated endpoints are the right tool when you need explicit hierarchy traversal (breadcrumbs, subtree scope, ancestor chain)."

Both gated by `locations:read`. Note the existing brief `/ancestors` mention at L191 stays — it's a forward-reference into the new section.

**1.3 — Tag CRUD subsection.** Append to the existing `## Tags use a composite natural key` section. Today that section covers the data primitive and uniqueness; it doesn't cover the CRUD lifecycle. Add a `### Tag CRUD` subsection covering:

- `POST /api/v1/assets/{asset_id}/tags` and `POST /api/v1/locations/{location_id}/tags` — body is `shared.TagRequest` (`tag_type`, `value`); 201 returns `shared.Tag`. Gated by `assets:write` / `locations:write` respectively (the parent resource's write scope, not a separate `tags:write`).
- `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}` and the location equivalent — 204 whether or not the tag was associated (idempotent — already documented in errors.md L278). Gated by `assets:write` / `locations:write`.
- `tag_type` enum values (`rfid`, `ble`, `barcode`) and what they mean for the data model (each is a different physical artifact; the `value` shape differs by type — EPC for `rfid`, beacon ID for `ble`, scanned string for `barcode` — but the API does not validate the per-type shape, only the regex and length constraint).
- `value` is matched as an exact string within `(org_id, tag_type)`. There is no normalization (no case-folding, no whitespace stripping). Substring matching only happens through the `?q=` filter on the parent resource — see `pagination-filtering-sorting#substring-search`.
- Uniqueness on `(org_id, tag_type, value)` for live (non-deleted) rows. Inserting a duplicate live tag returns `409 conflict`.

One short curl example for the create path (POST). DELETE example is one line and lives in errors.md already (cross-link).

**4.1 — soft-delete model consolidation.** Update L107's brief mention to state the visibility rule explicitly: `asset_deleted_at` is **only** present on `report.PublicCurrentLocationItem` (the row shape returned by `/api/v1/locations/current`) **and** only when the request includes `include_deleted=true`. There is no general `deleted_at` field on assets, locations, or tags on the public API — soft-deleted records drop out of list responses entirely (the partial unique index `… WHERE deleted_at IS NULL` is the storage-side contract; the API surface mirrors it). The single inspection path for a soft-deleted asset is the path-param read by `id`, which returns the record without a `*_deleted_at` field.

## `date-fields.md`

**4.1 — fix the "audit timestamps" sentence + cross-link.** Today L7 says "Audit timestamps (`created_at`, `updated_at`, `deleted_at`) follow a different convention and are not covered here." That implies `deleted_at` is a generally visible audit field, which it isn't. Replace with:

> Audit timestamps (`created_at`, `updated_at`) follow a different convention and are not covered here. Soft-deletion is not surfaced as a general field — see [Resource identifiers → soft-delete visibility](./resource-identifiers#…) for where `asset_deleted_at` appears on the public surface.

Anchor target depends on the heading I land on in resource-identifiers; I'll set it to the section heading I use there.

## Per-file audit-adjacent sweep

For each touched file, scan for adjacent small-callout omissions while in the editor. Findings recorded in PR description, fixed only if trivially in scope; anything substantive opens a follow-up.

# Out of scope (declared)

- OpenAPI spec or backend behavior changes — covered by sibling [TRA-641](https://linear.app/trakrf/issue/TRA-641) / platform [#287](https://github.com/trakrf/platform/pull/287).
- Restructuring `resource-identifiers.md` into per-resource sub-pages — page is long but the cross-references hold; restructure is a separate doc-architecture decision.
- Building out the per-endpoint reference inside `pagination-filtering-sorting.md` — the per-endpoint sort table covers the BB21-flagged gap; per-endpoint deep-dive belongs in dedicated resource pages if/when those land.
- Adding tag CRUD to the Quickstart — Quickstart already covers the asset/location lifecycle; tag CRUD is a resource-identifiers concern.

# Acceptance

- [ ] All in-scope items above land in the named files in a single PR.
- [ ] `pnpm build` passes with no broken-link warnings (cross-links to new anchors resolve).
- [ ] `pnpm lint` clean.
- [ ] Spec mirror refresh from platform [#287](https://github.com/trakrf/platform/pull/287) is in the PR (own commit, `chore(api): …`).
- [ ] PR description records what was already-done, what's net-new, and the per-file adjacent-sweep findings.
- [ ] Linear comment on close references the PR and notes BB22 verification status (carry forward — verification runs against the next preview deploy).
