# TRA-799 — Remove asset current-location from the documented API surface

## Origin

Platform PR #384 (TRA-799) makes an asset's current location *fact data*, not a
dimension attribute. Three integrator-visible contract changes ship together:

1. **Asset response shape** — `location_id` and `location_external_key` are
   removed from the asset resource. `GET /api/v1/assets` and
   `GET /api/v1/assets/{asset_id}` no longer return any location field. Current
   location is read only from the scan-data surface that already exists:
   `GET /api/v1/reports/asset-locations` (latest-per-asset) and
   `GET /api/v1/assets/{asset_id}/history` (the latest row).
2. **Asset write** — `location_id` / `location_external_key` in a `POST` or
   `PATCH` body are rejected `400 validation_error` / `code: read_only` on
   *presence*. Previously create rejected them on presence and PATCH echo-checked
   them (accept-if-matches / reject-if-differs). With location gone from the read
   shape there is nothing to echo, so both verbs now pre-decode reject uniformly.
3. **Asset list filter** — the `?location_id` / `?location_external_key` query
   filters on `GET /api/v1/assets` are removed. Filtering assets by current
   location is itself fact-shaped; it moves to
   `GET /api/v1/reports/asset-locations?location_id=...`.

The reporting endpoints (`/reports/asset-locations`, `/assets/{id}/history`) are
**unchanged** — they remain the system of record for asset location, and their
`AssetLocationItem` / `AssetHistoryItem` rows keep `location_id` /
`location_external_key`.

Pre-launch change — removing response fields is free now, breaking once external
integrators are on the API.

## Scope

This is the **docs-only** companion to platform PR #384. The platform code,
migration, delete-guard rewrite, and frontend changes land in PR #384. This repo
carries the prose changes to `docs/api/`. The OpenAPI-driven interactive
reference at `/api` is generated from the spec synced from the platform repo and
updates with that sync — it is **not** hand-edited here.

## What makes this non-trivial

`docs/api/resource-identifiers.md` uses the asset `location_id` /
`location_external_key` pair as its **primary teaching example** for several
patterns: foreign-key flat-scalar pairs in responses, the "present as `null`"
behavior, the accept-if-matches / reject-if-differs PATCH rule, and "list filters
accept both forms." Removing the field is not a delete — those examples must be
re-anchored on FK pairs that still exist.

### Editorial decision: re-anchoring teaching examples

Two real FK pairs survive TRA-799 and can carry the teaching load:

- **`parent_id` / `parent_external_key` on `LocationView`** — a flat-scalar FK
  pair on a *response*, present-as-`null` for a root location. This is the
  re-anchor for "FK fields come as flat scalar pairs" and the "present as
  `null`" table. It is writable (re-parent on PATCH), so it does *not*
  illustrate the read-only / accept-if-matches behavior.
- **`location_id` / `location_external_key` on `AssetLocationItem`** (the
  `/reports/asset-locations` row) — a flat-scalar FK pair, read-only,
  present-as-`null` when the location is soft-deleted. This is the re-anchor for
  "list filters accept both forms" (the report keeps both filter forms).

Asset `location_id` / `location_external_key` stop being a "paired FK
relationship" in the response/filter sense. On the write surface they remain two
fields that both reject on presence — documented as a uniform `read_only`
rejection on `POST` and `PATCH`, no longer as accept-if-matches.

### Editorial decision: changelog entry

TRA-799 removes response fields — the most integrator-impacting class of
contract change. A new entry is added at the top of the `v1.0 — Launch` section
of `docs/api/changelog.md`, consistent with how the analogous BB40 master-data /
scan-data bifurcation was logged. Prior entries (BB40, BB63's `readOnly`
annotation entry) are historical record and are **not** rewritten.

## Per-file changes

### `docs/api/data-model.md`

The asset detail view is no longer a scan-data consumption endpoint.

- Scan-data consumption table: drop the `GET /api/v1/assets/{asset_id}` row;
  the table keeps `/assets/{id}/history` and `/reports/asset-locations`.
- "The asset view's embedded location fields share the same lineage" sentence
  and the "single-asset view exposes location as flat scalars" paragraph:
  remove — the asset view no longer embeds location.
- "What you cannot do" bullets: the `POST` bullet stays. Rewrite the `PATCH`
  bullet — drop the accept-if-matches / verbatim-round-trip wording; `PATCH`
  now rejects `location_id` / `location_external_key` on presence, same as
  `POST`. The intro sentence ("If you tried to `POST` or `PATCH` `location_id`")
  stays correct.
- "Consumption pattern guidance": the last sentence of the batch-lookup
  paragraph ("For a single asset, `GET /api/v1/assets/{asset_id}` returns the
  same location fields directly on the asset view") — rewrite to point a
  single-asset location lookup at `/reports/asset-locations` (filter by
  `asset_id`) or the per-asset `/history`.

### `docs/api/resource-identifiers.md`

- **"List filters accept both forms"** — re-anchor the worked example from
  `GET /api/v1/assets?location_id=` to `GET /api/v1/reports/asset-locations`
  (filter by `location_id` / `location_external_key`).
- **"Foreign-key fields in responses come as flat scalar pairs"** — re-anchor
  the JSON example from an asset response to a `LocationView` response showing
  `parent_id` / `parent_external_key`. Rewrite the "two paired-FK shapes" /
  read-vs-write contrast: the surviving response-shape FK pair is location
  parentage (writable master-data); the asset side is gone.
- **"Present as `null`" table** — remove `location_id`, `location_external_key`
  from the row (no longer on `AssetView`); keep `parent_id`,
  `parent_external_key`, `description`, `valid_to`.
- **`AssetView` / `AssetLocationItem` nullability paragraph** — drop asset-side
  location references; the `AssetLocationItem` (report) location nullability
  stays.
- **Ancestor-identifiers-across-tombstones section** — remove the sentence
  about `location_external_key` projecting through on
  `GET /api/v1/assets?include_deleted=true`; keep the `parent_external_key` on
  locations behavior and the `/reports/asset-locations` null-projection.
- **"Scope of `POST` and `PATCH /api/v1/assets/{asset_id}`" admonition** —
  rewrite: `location_id` / `location_external_key` are not part of the asset
  resource at all (not the read shape, not `CreateAssetWithTagsRequest`, not
  `UpdateAssetRequest`); both verbs reject on presence with
  `400 validation_error` / `code: read_only`. Keep the ingestion-path error
  detail; add the pointer to the reporting endpoints.
- **"Read shape vs. write shape" accept-if-matches rule + table** — remove asset
  `location_*` from the accept-if-matches / reject-if-differs set (no read value
  to match). The set becomes `id`, `created_at`, `updated_at`, `deleted_at`,
  `external_key`, `tags`. Keep a table row for asset `location_id` /
  `location_external_key` but document it as reject-on-presence on `POST` and
  `PATCH`, distinct from the accept-if-matches fields.
- **Write-surface bullet for asset `location_*`** — drop
  `GET /api/v1/assets/{id}` from the consumption-endpoint list; keep
  `/assets/{id}/history` and `/reports/asset-locations`.
- **Verbatim `GET` → `PATCH` round-trip example** — remove `location_id`,
  `location_external_key` from the read-only-fields comment (they are not on the
  GET response anymore); keep `tags`, `external_key`, `parent_external_key`.
- **`UpdateAssetRequest` bullet** — `location_*` is absent from the read shape
  *and* both write schemas; only a hand-built payload that invents the field
  hits `read_only`. Adjust wording accordingly.
- **Asset / location asymmetry paragraph** — keep the master-data / scan-data
  framing; adjust so it no longer implies asset location appears on the read
  shape.
- **"Paired-key behavior per verb" section + matrix** — asset location is no
  longer a paired FK relationship for read or filter purposes. Rewrite the
  matrix so the paired-FK rows cover location `parent_id` /
  `parent_external_key` and the `/reports/asset-locations` filter pairs; collapse
  the asset `location_*` contract to a single statement: rejected on presence on
  `POST` and `PATCH`, not a read field, not a list filter.
- **Locations delete-semantics** — remove the "assets placed at a deleted
  location (`location_id` populated, `location_external_key` null)" sentence;
  the asset no longer carries the pair.
- **"Active placed assets" lookup line** — change
  `GET /api/v1/assets?location_id={location_id}` to
  `GET /api/v1/reports/asset-locations?location_id={location_id}` (the
  `/assets` filter is gone).
- **`external_key`-typed filter enumeration** — `?location_external_key=` is now
  only on `/reports/asset-locations`, not `/assets`; tighten the per-endpoint
  filter mapping sentence.

### `docs/api/pagination-filtering-sorting.md`

- **Filter-param table** — remove `location_id` (repeatable) /
  `location_external_key` (repeatable) from the `GET /api/v1/assets` row; the
  `/reports/asset-locations` row keeps both.
- **"Paired-by-id-and-by-natural-key filters are mutually exclusive"** — drop
  `/assets` from the list of endpoints carrying a `location_id` /
  `location_external_key` filter pair; the pairs are now on
  `/reports/asset-locations` (asset and location) and `/locations` (parent).
- **"Repeatable filters" examples** — the two curl examples filter `/assets` by
  `location_external_key` / `location_id`; re-point at
  `/reports/asset-locations` (which still has repeatable location filters).
- **"Validator behavior on writes"** — remove asset `location_*` from the
  accept-if-matches / reject-if-differs prose; the `POST`-side paragraph
  already states presence-rejection — generalize it to cover `PATCH` as well.
- **"Worked examples per resource → Assets"** — the example filters `/assets` by
  `location_external_key`; replace with a location-free asset-list example
  (e.g. `?is_active=true&sort=-created_at`) and, if useful, a cross-reference to
  the asset-locations report example for location filtering.

### `docs/api/quickstart.mdx`

- **§3 round-trip PATCH paragraph** — remove `location_id`,
  `location_external_key` from the read-only-fields-that-echo-safely list; they
  are not on the read shape.
- **Following paragraph** — the "Differing values on the truly server-managed
  fields (... the scan-derived `location_id` / `location_external_key` on
  assets) return `code: read_only`" clause: drop the asset `location_*` mention
  from the accept-if-matches framing. The "Asset location specifically cannot be
  set via `PATCH` ... derived from scan events" sentence stays (still true).

### `docs/api/errors.md`

- **`invalid_context` — list-filter-on-wrong-endpoint** — the filter-param
  enumeration lists `location_id` / `location_external_key`; they are now
  reports-endpoint filters only, not `/assets`. Adjust the enumeration so it no
  longer implies `/assets` carries them.
- **`ambiguous_fields`** — remove `/assets` from the surfaces that emit the code
  on the `location_id` vs `location_external_key` pair (the `/assets` location
  filter is gone). Update the `PATCH /api/v1/assets/{asset_id}` clause: asset
  `location_*` reject on presence, not under accept-if-matches.
- **`read_only`** — asset `location_id` / `location_external_key` now fire
  `read_only` on presence on **both** `POST` and `PATCH` (the prose currently
  says `PATCH` fires only on divergence under accept-if-matches). Update.

### `docs/api/design-notes.md`

- The accept-if-matches / reject-if-differs field list ("`id`, `created_at`,
  `deleted_at`, `location_id`, `location_external_key`, `tags`, `external_key`")
  — remove asset `location_id` / `location_external_key`; they are no longer
  read-shape fields subject to that rule.

### `docs/api/changelog.md`

Add one new entry at the top of `## v1.0 — Launch (TBD)`, above the BB66 entry:
asset location removed from the asset resource response and asset-list filter;
read it from `/reports/asset-locations` / `/assets/{id}/history`; `POST` and
`PATCH` reject `location_id` / `location_external_key` uniformly on presence.
Pre-launch; no `v1.0.0`-or-later wire baseline to break.

## Out of scope

- `docs/api/date-fields.md` — its `location_id` / `location_external_key` JSON
  samples are `/reports/asset-locations` and history rows, which are unchanged.
- `docs/api/id-format.md` — its `location_id` references describe the
  reports-endpoint filter and the asset write-surface presence-rejection, both
  still accurate.
- `docs/api/http-method-coverage.md`, `authentication.md` — no asset-location
  references.
- `static/api/openapi.{json,yaml}` and the `/api` interactive reference — spec
  synced from the platform repo; updates with that sync.
- Manual location entry / location-observation provenance model — a deferred
  future epic on the platform side; no doc change here.

## Verification

- `pnpm build` succeeds (Docusaurus build catches broken internal links).
- `git grep -nE 'location_id|location_external_key' docs/api/` — every
  remaining hit is a path parameter (`{location_id}`), a `parent_*` reference, a
  `LocationView` field, or a `/reports/asset-locations` / `/history` filter or
  row. No hit describes an asset response field or an `/assets` list filter.
- No internal anchor links left dangling by removed/renamed sections.

## Acceptance

- [ ] Asset response shape documented with no `location_id` /
      `location_external_key`; current location documented as read from
      `/reports/asset-locations` and `/assets/{id}/history`.
- [ ] `POST` and `PATCH` documented as rejecting `location_id` /
      `location_external_key` on presence with `400` / `code: read_only`.
- [ ] `?location_id` / `?location_external_key` removed from the documented
      `GET /api/v1/assets` filter surface; reports endpoint documented as the
      location-filter path.
- [ ] FK-pair / present-as-`null` / accept-if-matches teaching examples
      re-anchored on surviving FK pairs; no dangling asset-location example.
- [ ] Changelog entry added; prior entries untouched.
- [ ] `pnpm build` passes; `git grep` audit clean.
