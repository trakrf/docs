---
title: TRA-789 BB67 docs — Errors-page read_only/invalid_context catalog correction, parent_external_key writability, q parameter documentation
date: 2026-05-18
linear: TRA-789
parent_linear: TRA-788
status: in-flight
---

# TRA-789 BB67 docs design

Three docs-only items rolled up from the BB67 multi-org parallel triage. No platform PR — the committed customer-facing spec already encodes the post-TRA-780 / TRA-787 contract (verified in TRA-789 platform-audit comment). Pure trakrf-docs work.

## Scope

### F1 — Errors page mislabels external_key / tags PATCH rejection code

The `read_only` catalog entry in `docs/api/errors.md` still claims `external_key` (assets, locations) and `tags` (assets, locations) emit `code: read_only` on PATCH divergence. Post-TRA-780 (BB63 F4), both fields emit `code: invalid_context` — they are settable on the surface, just not via PATCH (the canonical write paths are `POST /api/v1/{resource}/{id}/rename` for `external_key`, `POST /api/v1/{resource}/{id}/tags` and `DELETE .../tags/{tag_id}` for `tags`).

The mislabel is contract-class for typed clients: a codegen-driven `switch` over `FieldErrorCode` written from the Errors page would never reach the `read_only` arm for the two most common natural-mistake PATCH bodies (verbatim GET → PATCH echoes of `external_key` or `tags`). Those rejections fall into the typed client's `default` or fallthrough arm despite being the case the page singles out for typed branching.

The `invalid_context` catalog entry only documents the TRA-777 use case (list-filter parameter on a detail endpoint). It needs the second framing too — fields handed off to a dedicated write subresource.

### F2 — Errors page lists parent_external_key as read-only; it's writable

The same `read_only` entry on `docs/api/errors.md` lists `parent_external_key` (locations) among the natural-key reference fields that emit `code: read_only`. This is wrong: `parent_external_key` is fully writable on `PATCH /api/v1/locations/{location_id}` (re-parenting via natural key), symmetric with `parent_id` and with the `CreateLocationRequest` write surface. `ambiguous_fields` is the only validation that fires on the pair, and only when the two forms disagree (matching values are silently normalized to a single re-parent).

A docs-driven integrator reading the Errors page would conclude PATCHing `parent_external_key` will be rejected and either defensively avoid the field (lose the natural-key write path) or never re-parent via PATCH. The page should simply not list it.

### F3 — Document the q query parameter

The `q` query parameter on `GET /api/v1/assets`, `GET /api/v1/locations`, and `GET /api/v1/reports/asset-locations` is already documented in `docs/api/pagination-filtering-sorting.md` (substring-search section with a per-endpoint field-set matrix). Two gaps remain after the platform-audit comment on the ticket:

1. **Asymmetry not made explicit.** The matrix shows the reports endpoint matches fewer fields than assets/locations (no `description`, asset-side identifying fields only), but doesn't call out the asymmetry as a thing integrators should watch for. A reader assuming uniform behavior could write code that breaks when crossing endpoint families.
2. **Single-value semantics undocumented.** The OpenAPI declares `q` as a single string; the runtime takes the first `?q=` value if multiple are supplied. The current prose doesn't say so, leaving the multi-value-semantics question open.

## Audit sweep (per F1 verification)

Drift across sibling pages where the same outdated `read_only` claim or `parent_external_key`-as-read-only listing appears:

- **`docs/api/pagination-filtering-sorting.md:234`** — "Validator behavior on writes" section lists `tags`, `external_key`, and `parent_external_key` under "read-only fields" and claims a uniform `code: read_only` rejection. Needs the BB63 split per F1 + the parent_external_key removal per F2.
- **`docs/api/http-method-coverage.md:44`** — PATCH content-type section claims `code: read_only` on rejection with `/rename` and `/tags` subresource hints. Wrong code post-BB63. Mentions `parent_external_key` as "natural-key reference (read-only)". Needs F1 + F2 fix.
- **`docs/api/resource-identifiers.md:300`** — In the `UpdateLocationRequest` paragraph: "A differing `external_key` field is still surfaced as `400 read_only`". Drift — should be `400 invalid_context` post-BB63. (The parent_external_key half of this paragraph is already correct.)
- **`docs/api/resource-identifiers.md:301`** — Asset write-schema paragraph mentions a uniform `400 read_only` covering `external_key`, `location_id`, `location_external_key`, `tags`. The location_* half is still correct (scan-derived → `read_only`); the `external_key` / `tags` half is drift. Light-touch fix.
- **`docs/api/resource-identifiers.md:257`** — Brief lumping of `tags`, `external_key`, `*_external_key`, `location_*` as "other read-only fields" that admit a single byte form. Spirit OK (they don't accept variant byte forms the way datetime instants do), but lumps fields under "read-only" without acknowledging the code split. Light-touch fix.
- **`docs/api/design-notes.md:76`** — `updated_at` optimistic-concurrency note characterizes `id`, `created_at`, `deleted_at`, `location_id`, `location_external_key`, `tags`, `external_key` as "other read-only fields" that don't change on PATCH. Spirit is correct (none change on PATCH; reject-if-differs is integrator bug, not concurrency conflict), but the framing is loose. Light-touch fix: parenthetical that some emit `code: invalid_context` rather than `code: read_only`.

Pages already correct (per BB63 split, verified by audit): `data-model.md` (line 25, 52-53), `quickstart.mdx` (line 141, 158), `resource-identifiers.md` (lines 235, 253, 255, 214, 303, 323), `date-fields.md` (line 10), `errors.md` (line 217 — `read_only` mention is correctly scoped to asset `location_*`), `errors.md` (line 324 — `updated_at` is server-managed).

## Approach

**Surgical edits only.** The Errors page's `read_only` and `invalid_context` catalog entries are the canonical reference; the audit-sweep sites are derivative drift. Fix the canonical first, then walk the drift list. No restructuring, no new sections, no recap text that duplicates the Errors-page catalog.

**Canonical references on the Errors page**:
- `read_only` field list: `id`, `created_at`, `updated_at`, `deleted_at` (both resources); asset `location_id`, `location_external_key`.
- `invalid_context` framing: two semantic categories — (a) known parameter in wrong surface (TRA-777, unchanged); (b) field handed off to a dedicated write subresource (TRA-780 — new) — list `external_key` (via `/rename`), `tags` (via `/tags` subresource on POST and `DELETE …/tags/{tag_id}`).

**Code-split phrasing on derivative pages**: use a uniform short hook like "rejects with `code: read_only` for server-managed fields, `code: invalid_context` for sub-resource-mutable fields (`external_key`, `tags`)" rather than repeating the full BB63 split.

**F3 changes**: extend the existing substring-search subsection with an explicit asymmetry callout and a single-value-semantics line. Keep the existing matrix.

## No changelog

None of F1/F2/F3 is a runtime behavior change. The wire contract is what it has been since BB63 / BB66; only the prose is being aligned. No changelog entry.

## Verification

- Render `/docs/api/errors`: `read_only` list = six fields (no `external_key`, no `tags`, no `parent_external_key`).
- `invalid_context` entry has both semantic categories (filter-in-wrong-context + subresource-handoff) with fields and write paths.
- Render `/docs/api/pagination-filtering-sorting`: `q` matrix unchanged, asymmetry callout present, single-value note present.
- Audit-sweep sites all show `invalid_context` for `external_key`/`tags` divergence and `read_only` only for server-managed / asset `location_*`.
- `pnpm build` succeeds with no broken links.
- No Linear ticket references in the rendered docs body (per project convention).

## Acceptance

- Single docs PR against `trakrf/docs:main`.
- Preview build renders cleanly.
- Ticket stays open until docs ship per project rule; closure is paired with the merge / cycle close.

## Cross-references

- Parent: TRA-788 (BB67 multi-org triage rollup).
- BB63 F4 (TRA-780) introduced the `read_only` → `invalid_context` split for sub-resource-mutable fields. This is the residual prose-audit drift.
- BB66 (TRA-787) closed several adjacent prose drifts; the Errors-page catalog wasn't in that wave.
