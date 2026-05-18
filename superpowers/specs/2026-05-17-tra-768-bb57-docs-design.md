# TRA-768 — BB57 docs: metadata asymmetry design note + changelog updates for TRA-767 + F5 housekeeping

## Context

Sibling docs ticket to TRA-767 (platform PR [trakrf/platform#368](https://github.com/trakrf/platform/pull/368), merged). The platform PR shipped three error-string changes (F1 `valid_from` recommendation, F2 body-decode `bad_request` enrichment, F3 PATCH `external_key` rename hint body shape) and took the **docs-narrow fallback** on F4 (validator aggregation) because the apparent "short-circuit" traces to `encoding/json`'s `UnmarshalJSON` contract — aggregating cross-field errors would require a parallel `map[string]json.RawMessage` decode pass, well beyond the ticket's scope framing.

The platform PR also handed off **F5 housekeeping** to this PR: persist the SQL cleanup scripts to `tests/blackbox/.fixtures/` (gitignored) and update `BB_PRE_KEY.md`'s asset count (was 31, actual seeded count is 27).

## Scope

Single PR against `trakrf/docs`.

### 1. F1 — assets/locations `metadata` asymmetry design note

Add a new section to `docs/api/design-notes.md`. Wording follows the ticket draft:

> **Locations omit free-form metadata by design**
>
> The asset surface (Create/Update/View) carries a `metadata` object for arbitrary integration-defined attributes. The location surface does not — `metadata` is intentionally absent from `CreateLocationWithTagsRequest`, `UpdateLocationRequest`, and `LocationView`. Locations are hierarchical anchors and are expected to stay austere; application-specific labels on a location should be attached via the location's `tags` subresource (`POST /api/v1/locations/{location_id}/tags`), and application-specific data about what's _at_ a location should live on the asset rows scanned there. If you find yourself wanting `location.metadata`, consider whether the data belongs on tags or on the assets instead.

Voice-match to the existing design-notes entries (terse, integrator-second-person, cross-link the relevant doc surfaces). Place after the existing `descendant_count_affected` section.

### 2. F2 — changelog entry for TRA-767 platform changes

Add a new dated section to `docs/api/changelog.md` styled on existing "fix wave" entries (BB42, BB39, BB36). Title:

> `### BB57 fix wave — error UX hygiene (valid_from, bad_request, rename hint, validator aggregation docs-narrow)`

Four sub-bullets:

1. **`valid_from` sentinel-rejection wording aligned with null-rejection wording on non-nullable timestamps.** Cite the contradictory-guidance failure mode the prior wording produced. POST gets "omit the field to use the server default"; PATCH gets "omit the field to leave unchanged." Nullable timestamps (`valid_to`) still recommend `"use JSON null"`. Programmatic clients branch on `error.type` / `fields[].code` — `detail` is explanatory only — so the change is wire-shape-neutral.
2. **Body-decode `bad_request` `detail` now names the expected JSON type when the decoder knows it.** Example: `Body field "is_active" could not be decoded as the expected type (boolean)`. Closes the asymmetric-diagnostic gap between the validation-stage envelope (which surfaces type via `params`) and the decode-stage envelope (which previously withheld it). Envelope `type` and `fields[]` shape are unchanged — clients that branch on `error.type` continue to work.
3. **PATCH read-only `external_key` error hint now includes the rename body shape inline.** New wording: `external_key is immutable via PATCH; use POST /api/v1/{resource}/{id}/rename with body {"external_key": "<new value>"} to change it`. Applies symmetrically on assets and locations. Saves the round-trip where integrators substitute `new_external_key` and bounce off the rename validator.
4. **`Errors → Envelope shape` (`docs/api/errors.md#envelope-shape`) prose narrowed to match service behavior on validator aggregation.** Most field validators short-circuit at the first miss (structural to Go's `encoding/json` behavior); cross-field validators — notably `ambiguous_fields` on a paired natural-key conflict — emit multiple `fields[]` entries with the `(and N more validation errors)` suffix on `detail`. The prior wording read as if aggregation was uniform across all body-validation paths; clients should branch on the `fields[]` array length to detect the multi-field case rather than assuming all violations on a body land in a single response.

Cross-link to `/docs/api/errors` from items 1, 2, and 4.

### 3. F4 docs-narrow — `docs/api/errors.md` prose update

Rewrite the load-bearing claim at `errors.md:26`:

> Previous: "On `validation_error`, `detail` echoes the first offending field's `message` verbatim (and appends `(and N more validation errors)` when more than one field is invalid). The per-field structure lives in `fields[]`."
>
> New: "On `validation_error`, `detail` echoes the first offending field's `message` verbatim. Most field-level validators short-circuit at the first miss, so `fields[]` typically carries a single entry on a body invalid on multiple fields; cross-field validators (notably `ambiguous_fields` on a paired natural-key conflict) emit multiple `fields[]` entries and append `(and N more validation errors)` to `detail`. Branch on `fields[]` array length to detect the multi-field case. The per-field structure lives in `fields[]` — see the Validation errors section below."

The matching paragraph at `errors.md:146` ("`detail` bubbles the first field's `message`...") gets a parallel adjustment so the two sections agree on the same short-circuit-vs-cross-field framing.

Audit other on-page mentions of multi-field aggregation for consistency; bring them into alignment if found.

### 4. F5 — fixture cleanup script persistence + count fix

Three changes:

- **`.gitignore`**: add `tests/blackbox/.fixtures/` with an exception for `tests/blackbox/.fixtures/README.md` so the directory's purpose can be committed while the SQL artifacts stay gitignored.
- **`tests/blackbox/.fixtures/README.md`**: explain the directory's purpose — persistent, gitignored landing zone for fixture-maintenance SQL produced during BB cycles. Reachable across reboots; not part of the published docs build.
- **`tests/blackbox/BB_PRE_KEY.md`**: change "Assets — 31 per org" to "Assets — 27 per org" and update the OC/CD breakdown. Per the platform PR's post-cleanup count: 11 OC-origin (`ASSET-0001..0011`), 9 CD-origin under the `ASSET-NNNN` namespace above the OC ceiling (`ASSET-0012..0020`), and 7 CD-origin under the `CD-ASSET-NNNN` namespace (the rows that would have collided with OC). 11 + 9 + 7 = 27.

The actual SQL cleanup script gets written to the **main checkout** at `/home/mike/trakrf-docs/tests/blackbox/.fixtures/bb57-cleanup.sql` via an absolute path (not into the worktree, which would be discarded with the worktree at PR merge). The file is gitignored once the PR merges, so the path is stable across reboots and worktree churn.

The SQL bundles F5a (delete 4 cruft assets per org with scan-history cascade), F5b (reset `ASSET-0001.name` to `"Asset 1"`), and F5c (fix `CD-WHS-01.description` typo `Primary warehiouse` → `Primary warehouse`). The platform PR already ran this cleanup against the live preview; this script is the reproducible record for future fixture-maintenance work.

## Out of scope

- No platform code changes. F4 service-path refactor is explicitly handed off as a future consideration (the platform PR description has the rationale).
- No Linear ticket references in the public docs surface (`docs/api/*`). Internal docs and the spec/plan files may reference TRA-NNN freely.
- No further refactoring of the changelog page format.

## Acceptance

- `pnpm build` clean.
- `pnpm lint` clean (Prettier).
- Design note appears in design-notes preview render at `/api/design-notes`.
- Changelog entry appears in changelog preview render at `/api/changelog`.
- `errors.md` envelope-shape claim now accurately describes service behavior post-fallback.
- `BB_PRE_KEY.md` count line reads `27 per org` with the correct OC/CD breakdown.
- `tests/blackbox/.fixtures/` exists with a README; `bb57-cleanup.sql` lives in the main checkout.
- PR opened against `main`; reviewer-checkable preview deploy.
