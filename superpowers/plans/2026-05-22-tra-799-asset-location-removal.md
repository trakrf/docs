# TRA-799 — Asset current-location removal docs sweep — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Update `docs/api/` so the asset resource no longer documents a current
location — read it from the scan-data endpoints — and `POST` / `PATCH` reject
`location_id` / `location_external_key` uniformly on presence.

**Architecture:** Prose-only sweep across seven `docs/api/` files plus a new
changelog entry. The hard part is `resource-identifiers.md`, which uses asset
`location_*` as its primary teaching example for several patterns; those examples
re-anchor on `LocationView.parent_*` and the `/reports/asset-locations` row.
Verification is `pnpm build` (catches broken internal links) plus a `git grep`
audit. Design spec:
`superpowers/specs/2026-05-22-tra-799-asset-location-removal-design.md`.

**Tech Stack:** Docusaurus, Markdown / MDX, pnpm.

---

## Task 1: Commit the design artifacts

**Files:**
- Create: `superpowers/specs/2026-05-22-tra-799-asset-location-removal-design.md` (done)
- Create: `superpowers/plans/2026-05-22-tra-799-asset-location-removal.md` (this file)

- [ ] **Step 1: Commit**

```bash
git add superpowers/specs/2026-05-22-tra-799-asset-location-removal-design.md \
        superpowers/plans/2026-05-22-tra-799-asset-location-removal.md
git commit -m "docs(api): TRA-799 — design spec + plan for asset current-location removal"
```

---

## Task 2: `docs/api/data-model.md`

The asset detail view stops being a scan-data consumption endpoint.

**Files:**
- Modify: `docs/api/data-model.md`

- [ ] **Step 1: Scan-data consumption table** — remove the
  `GET /api/v1/assets/{asset_id}` row (the one whose Shape cell reads "Current
  location embedded on the asset view (`location_id`, `location_external_key`)").
  Table keeps the `/assets/{id}/history` and `/reports/asset-locations` rows.

- [ ] **Step 2: Lineage paragraph after the table** — the sentence "The asset
  view's embedded location fields share the same lineage; the difference is read
  shape, not data source." is no longer true. Rewrite the paragraph so it
  describes the two `tracking:read` endpoints as the projections of the
  scan-event stream without referencing an asset-view location field.

- [ ] **Step 3: "single-asset view exposes location as flat scalars" paragraph**
  — remove it entirely. The asset view exposes no location field; the
  flat-scalar FK-pair cross-reference now belongs to `LocationView.parent_*`,
  documented on the resource-identifiers page.

- [ ] **Step 4: "What you cannot do" — `PATCH` bullet** — rewrite. Current text
  invokes the accept-if-matches / reject-if-differs rule and a "verbatim
  `GET` → `PATCH` round-trip that echoes the current location back is silently
  accepted." With location off the read shape there is nothing to echo: `PATCH`
  with `location_id` / `location_external_key` in the body returns
  `400 read_only` on presence, identical to `POST`. Keep the `POST` bullet and
  the "no public endpoint to record a scan event" bullet as-is.

- [ ] **Step 5: "Consumption pattern guidance" closing sentence** — the last
  sentence of the batch-lookup paragraph reads "For a single asset,
  `GET /api/v1/assets/{asset_id}` returns the same location fields directly on
  the asset view." Rewrite: a single asset's current location comes from
  `/reports/asset-locations` filtered by `asset_id` (or `asset_external_key`),
  or from the latest row of `/assets/{asset_id}/history`.

- [ ] **Step 6: Verify** — `git grep -n "location" docs/api/data-model.md`; every
  remaining hit is a path param, a `parent_*` reference, a `/reports/` or
  `/history` reference, or scan-data prose — none describes a field on the asset
  read shape.

- [ ] **Step 7: Commit**

```bash
git add docs/api/data-model.md
git commit -m "docs(api): TRA-799 — drop asset-view location from data-model scan-data section"
```

---

## Task 3: `docs/api/resource-identifiers.md`

Heaviest file. Work top-to-bottom so anchor references stay coherent.

**Files:**
- Modify: `docs/api/resource-identifiers.md`

- [ ] **Step 1: `*_external_key` foreign-key bullet (intro list)** — the example
  "`location_external_key` on assets, `parent_external_key` on locations" — drop
  the assets example; keep `parent_external_key` on locations.

- [ ] **Step 2: "List filters accept both forms" section** — re-anchor. The
  prose "For the assets list, filter by current location using either
  `location_id` or `location_external_key`" and its two curl examples move to
  `GET /api/v1/reports/asset-locations` (which keeps both repeatable location
  filter forms). State that the assets list itself no longer filters by
  location.

- [ ] **Step 3: "Foreign-key fields in responses come as flat scalar pairs"** —
  re-anchor the JSON example from an asset response to a `LocationView`
  response carrying `parent_id` (int) + `parent_external_key` (string). The
  surrounding prose ("Both fields are populated whenever the relationship
  exists ... unset → both `null`") stays true for `parent_*`. Rewrite the
  closing "two paired-FK shapes look symmetric ... write surfaces differ"
  sentence: the surviving response FK pair is location parentage, fully
  writable master-data; asset location is no longer on any response.

- [ ] **Step 4: "Always present / Present as `null`" table** — remove
  `location_id`, `location_external_key` from the **Present as `null`** row;
  keep `parent_id`, `parent_external_key`, `description`, `valid_to`.

- [ ] **Step 5: `AssetView` / `AssetLocationItem` required-fields paragraph** —
  remove asset-side location references. `AssetLocationItem` (the
  `/reports/asset-locations` row) keeps `location_id` / `location_external_key`
  as required-and-nullable — that sentence stays.

- [ ] **Step 6: Ancestor-identifiers-across-tombstones section** — remove the
  sentence "The same projection applies to `location_external_key` on
  `GET /api/v1/assets?include_deleted=true` when the asset's current location
  has been soft-deleted." Keep the `parent_external_key` projection on
  `/locations` and the `/reports/asset-locations` null-projection exception.

- [ ] **Step 7: ":::important Scope of `POST` and `PATCH /api/v1/assets/{asset_id}`"
  admonition** — rewrite the location sentences. `location_id` /
  `location_external_key` are not part of the asset resource at all: not the
  read shape, not `CreateAssetWithTagsRequest`, not `UpdateAssetRequest`. Both
  `POST` and `PATCH` reject either field on presence with
  `400 validation_error` / `code: read_only`; there is no accept-if-matches
  case because there is no read value to match. Keep the ingestion-path error
  detail; add that current location is read from `/reports/asset-locations` or
  `/assets/{id}/history`.

- [ ] **Step 8: "Accept-if-matches, reject-if-differs" rule paragraph** — remove
  "the scan-derived `location_id` / `location_external_key`" from the
  read-only-field set governed by this rule. The set is `id`, `created_at`,
  `updated_at`, `deleted_at` (return `read_only`) and `external_key`, `tags`
  (return `invalid_context`). Add a short note that asset `location_*` is a
  separate case — not on the read shape, rejected on presence on `POST` and
  `PATCH`.

- [ ] **Step 9: Read-only-field hint table** — the `location_id` and
  `location_external_key` rows. Keep both rows (the fields still reject) but the
  table's framing is "fields rejected on PATCH"; ensure the Surface column reads
  `POST /assets`, `PATCH /assets` and the prose/caption distinguishes these from
  the accept-if-matches rows — they reject on presence, not on divergence.

- [ ] **Step 10: Asset/location asymmetry paragraph(s)** (the "`UpdateAssetRequest`
  declares only [...]" bullet and the "asset / location asymmetry is by design"
  paragraph and the "practical consequence" paragraph) — adjust so they no
  longer state or imply that `location_id` appears on the asset read shape. The
  master-data / scan-data framing stays; `location_*` is absent from the read
  shape and both write schemas; only a hand-built payload inventing the field
  hits the `400 read_only`. Remove "scrubbed client-side by construction" /
  "send the unscrubbed read shape and see the 400" wording where it implies the
  field is on the GET response.

- [ ] **Step 11: Verbatim `GET` → `PATCH` round-trip example** — the bash comment
  listing read-only fields ("id, timestamps, tags, external_key, location_id,
  location_external_key, and (for locations) parent_external_key") — remove
  `location_id, location_external_key`; keep the rest.

- [ ] **Step 12: "Paired-key behavior per verb" section + matrix** — asset
  location is no longer a paired FK relationship for read or filter purposes.
  Rewrite: the intro "Each paired FK relationship" sentence drops the asset
  example. In the matrix, the `POST /assets` and `PATCH /assets/{id}` rows
  collapse to a uniform "`400 read_only` on presence of either field"; remove
  `/assets` from the `GET` list-filter row (only `/locations` and
  `/reports/asset-locations` carry location/parent filter pairs). Rewrite the
  two prose paragraphs after the matrix (`POST /assets` is not a paired-key
  surface; `PATCH` follows accept-if-matches) so the asset side is described as
  reject-on-presence on both verbs, not accept-if-matches. The `fk_not_found`
  paragraph: `location_id` / `location_external_key` no longer appear on an
  asset write body that resolves FKs — keep `fk_not_found` for the location
  `parent_*` case and the `/reports/asset-locations` filters.

- [ ] **Step 13: "clear a relationship on `PATCH`" paragraph** — it already says
  "Asset location is **not** a writable-nullable — clearing it is not a PATCH
  operation; record a scan event instead." Confirm this stays correct and the
  cross-reference anchor still resolves; no change expected beyond the anchors
  touched above.

- [ ] **Step 14: Locations delete-semantics** — remove the sentence "The same
  shape would appear on assets placed at a deleted location (`location_id`
  populated, `location_external_key` null)." Keep the `parent_*` invariant
  prose.

- [ ] **Step 15: "Active placed assets" lookup line** — change
  `GET /api/v1/assets?location_id={location_id}` to
  `GET /api/v1/reports/asset-locations?location_id={location_id}`; drop the
  now-removed `/assets` filter form.

- [ ] **Step 16: `external_key` value-rules paragraph** — the sentence mapping
  `external_key`-typed filters to endpoints ("`?external_key=`,
  `?location_external_key=`, `?parent_external_key=` on `/assets`,
  `/locations`, and `/reports/asset-locations`") — `?location_external_key=` is
  now only on `/reports/asset-locations`. Tighten the per-endpoint mapping.

- [ ] **Step 17: Verify** — re-grep:
  `git grep -nE 'location_id|location_external_key' docs/api/resource-identifiers.md`.
  Every hit must be a path param, a `parent_*` line, a `LocationView` field, an
  `AssetLocationItem` field, or a `/reports/asset-locations` filter — none an
  asset read-shape field or `/assets` list filter.

- [ ] **Step 18: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(api): TRA-799 — re-anchor FK-pair docs off asset location in resource-identifiers"
```

---

## Task 4: `docs/api/pagination-filtering-sorting.md`

**Files:**
- Modify: `docs/api/pagination-filtering-sorting.md`

- [ ] **Step 1: Filter-param table** — `GET /api/v1/assets` row: remove
  `location_id` (repeatable) and `location_external_key` (repeatable). Resulting
  filters: `external_key` (repeatable), `is_active`, `include_deleted`, `q`.
  The `/reports/asset-locations` row keeps its location pair.

- [ ] **Step 2: "Paired-by-id-and-by-natural-key filters are mutually
  exclusive" section** — the opening sentence enumerates pairs "—
  `location_id` / `location_external_key` on `/assets` and on
  `/reports/asset-locations`, `parent_id` / `parent_external_key` on
  `/locations`, `asset_id` / `asset_external_key` on
  `/reports/asset-locations`". Drop `on /assets` — the location pair survives on
  `/reports/asset-locations` only. Re-check the rest of the section for other
  `/assets` location-filter mentions.

- [ ] **Step 3: "Repeatable filters" examples** — the two curl examples
  ("Assets currently at LOC-A OR LOC-B" against `/api/v1/assets?location_*`) —
  re-point at `GET /api/v1/reports/asset-locations`, which keeps repeatable
  `location_external_key` / `location_id`. The comma-separated-values caveat
  paragraph below stays (it is about `external_key`-typed filters generally).

- [ ] **Step 4: "Validator behavior on writes" — first paragraph** — remove "the
  scan-derived `location_id` / `location_external_key` on assets" from the
  accept-if-matches / reject-if-differs field set. The `code: read_only` clause
  keeps `id` and timestamps.

- [ ] **Step 5: "Validator behavior on writes" — second paragraph** — currently
  `POST`-only ("On `POST`, the asset `location_*` fields are absent from
  `CreateAssetWithTagsRequest` ..."). Generalize to both verbs: `location_id` /
  `location_external_key` are absent from `CreateAssetWithTagsRequest` *and*
  `UpdateAssetRequest`; sending either on `POST` or `PATCH` returns
  `400 validation_error` / `code: read_only` on presence — no accept-if-matches
  half on either verb.

- [ ] **Step 6: "Worked examples per resource → Assets"** — the example "List
  active assets currently at one of two locations (by `external_key`) ..." uses
  `location_external_key` on `/assets`. Replace with a location-free asset-list
  example (active assets, newest first, 100 per page:
  `?is_active=true&sort=-created_at&limit=100`) and add a one-line pointer to
  the Asset-locations report example below for filtering by location.

- [ ] **Step 7: Verify** — grep the file; every `location_*` hit is a path param,
  a `/reports/asset-locations` filter, a `parent_*` ref, or history prose.

- [ ] **Step 8: Commit**

```bash
git add docs/api/pagination-filtering-sorting.md
git commit -m "docs(api): TRA-799 — drop asset location filter from pagination/filtering page"
```

---

## Task 5: Downstream cross-reference cleanup

`quickstart.mdx`, `errors.md`, `design-notes.md` each carry one or more
sentences asserting asset `location_*` is a read-shape field under
accept-if-matches. Fix all three together.

**Files:**
- Modify: `docs/api/quickstart.mdx`
- Modify: `docs/api/errors.md`
- Modify: `docs/api/design-notes.md`

- [ ] **Step 1: `quickstart.mdx` §3 round-trip paragraph** — remove
  `location_id`, `location_external_key` from the read-only-fields list that
  "echoing them straight back from a `GET` response is safe." The list keeps
  `id` / `created_at` / `updated_at` / `deleted_at`, `tags`, `external_key`.

- [ ] **Step 2: `quickstart.mdx` following paragraph** — the clause "Differing
  values on the truly server-managed fields (`id`, `created_at`, `updated_at`,
  `deleted_at`, and the scan-derived `location_id` / `location_external_key` on
  assets) return `code: read_only`" — drop the asset `location_*` mention from
  this accept-if-matches-framed sentence. The earlier standalone sentence
  "Asset location specifically cannot be set via `PATCH` under any form;
  current location is derived from scan events." stays.

- [ ] **Step 3: `errors.md` `invalid_context` catalog entry** — the
  list-endpoint-filter enumeration includes "`location_id` /
  `location_external_key`". These are now `/reports/asset-locations` filters
  only; adjust the enumeration so it does not imply `/assets` carries them.

- [ ] **Step 4: `errors.md` `ambiguous_fields` catalog entry** — remove `/assets`
  from the surfaces emitting the code on the `location_id` vs
  `location_external_key` pair (the `/assets` location filter is gone — the
  pair survives on `/reports/asset-locations`). Update the
  `PATCH /api/v1/assets/{asset_id}` sentence: asset `location_*` reject on
  presence, not "follow accept-if-matches ... a differing value generates a
  per-field `read_only` entry."

- [ ] **Step 5: `errors.md` `read_only` catalog entry** — the entry says asset
  `location_*` fire `read_only` on `POST` whenever present and on `PATCH` only
  when the value differs (accept-if-matches). Update: they fire on **presence**
  on both `POST` and `PATCH`. Remove the "echoing the current value back is
  silently stripped" half as it applies to asset `location_*` (it still applies
  to the four server-managed fields — keep that). The ingestion-path detail
  string stays.

- [ ] **Step 6: `design-notes.md` accept-if-matches field list** — the list
  "(`id`, `created_at`, `deleted_at`, `location_id`, `location_external_key`,
  `tags`, `external_key`)" — remove `location_id`, `location_external_key`.
  Re-check the surrounding sentence about the `code` split (server-managed →
  `read_only`, subresource-settable → `invalid_context`) still reads correctly
  without the asset location example.

- [ ] **Step 7: Verify** — grep all three files; no remaining sentence frames
  asset `location_*` as a read-shape / accept-if-matches field.

- [ ] **Step 8: Commit**

```bash
git add docs/api/quickstart.mdx docs/api/errors.md docs/api/design-notes.md
git commit -m "docs(api): TRA-799 — fix asset-location read-shape claims in quickstart/errors/design-notes"
```

---

## Task 6: `docs/api/changelog.md`

**Files:**
- Modify: `docs/api/changelog.md`

- [ ] **Step 1: Add a new entry** at the top of the `## v1.0 — Launch (TBD)`
  section, immediately above the `### BB66 docs sweep` heading. The entry
  records: `location_id` / `location_external_key` removed from the asset
  response (`GET /api/v1/assets`, `GET /api/v1/assets/{asset_id}`); the
  `?location_id` / `?location_external_key` filters removed from
  `GET /api/v1/assets`; `POST` and `PATCH` now reject `location_id` /
  `location_external_key` uniformly on presence with `400` / `code: read_only`;
  current location is read from `GET /api/v1/reports/asset-locations` and
  `GET /api/v1/assets/{asset_id}/history`. Note it is a pre-launch change with
  no `v1.0.0`-or-later wire baseline to break. Cross-link Data model and
  Resource identifiers. Match the voice and depth of the existing BB40
  master-data / scan-data entry. Do **not** edit any existing entry.

- [ ] **Step 2: Verify** — `pnpm build` resolves every internal link in the new
  entry.

- [ ] **Step 3: Commit**

```bash
git add docs/api/changelog.md
git commit -m "docs(api): TRA-799 — changelog entry for asset location removal"
```

---

## Task 7: Build verification and final audit

**Files:** none (verification only)

- [ ] **Step 1: Production build**

Run: `pnpm build`
Expected: build completes with no errors and no broken-link warnings.

- [ ] **Step 2: `git grep` audit**

Run: `git grep -nE 'location_id|location_external_key' docs/api/`
Expected: every hit is one of — a path parameter (`{location_id}`), a
`parent_id` / `parent_external_key` reference, a `LocationView` field, an
`AssetLocationItem` / `AssetHistoryItem` row field, or a
`/reports/asset-locations` / `/history` filter. No hit describes a field on the
asset read shape or a `GET /api/v1/assets` list filter.

- [ ] **Step 3: Lint (if configured)**

Run: `pnpm lint`
Expected: passes (or no lint script — skip).

- [ ] **Step 4: Open the PR** — push the branch and open a PR against `main`
  titled `docs(api): TRA-799 — remove asset current-location from the API docs`.
  PR body summarizes the three contract changes and links platform PR #384.
  Do not merge.

---

## Self-review notes

- **Spec coverage:** every per-file change in the spec maps to a task —
  data-model (T2), resource-identifiers (T3), pagination-filtering-sorting (T4),
  quickstart/errors/design-notes (T5), changelog (T6). Out-of-scope files
  (date-fields, id-format, http-method-coverage, authentication, OpenAPI spec)
  are correctly absent.
- **No placeholders:** every step names the exact file, the exact section, and
  the exact change. New prose is written at execution time against the named
  framing — acceptable here because the executor is the same agent holding the
  spec's editorial decisions.
- **Consistency:** the accept-if-matches field set after removal — `id`,
  `created_at`, `updated_at`, `deleted_at`, `external_key`, `tags` — is stated
  identically in T3 Step 8, T4 Step 4, T5 Steps 1–2/6. The post-change asset
  contract — "reject on presence on `POST` and `PATCH`" — is worded consistently
  across T2/T3/T4/T5.
