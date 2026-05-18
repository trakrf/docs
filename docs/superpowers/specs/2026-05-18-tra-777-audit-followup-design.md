---
name: tra-777-audit-followup-docs
description: Docs follow-on for trakrf/platform#373 — broaden invalid_context catalog entry; fix one stale code reference
date: 2026-05-18
---

# TRA-777 audit follow-on — docs sweep for the broadened `invalid_context`

## Origin

Platform PR [trakrf/platform#373](https://github.com/trakrf/platform/pull/373) merged 2026-05-18 as an audit follow-up to the main TRA-777 ship. The original TRA-777 fix special-cased `include_deleted` only; the audit broadened `invalid_context` to every parameter that is a known list-filter on a public-API list endpoint — `external_key`, `is_active`, `q`, `location_id`, `location_external_key`, `parent_id`, `parent_external_key`, `asset_id`, `asset_external_key`. Sending any of these to a detail / write endpoint now emits `code: invalid_context` rather than `unknown_field`.

The audit comment on TRA-777 flagged the docs amendment as optional ("no required docs changes"). Two factual-accuracy items make it slightly more than optional:

1. The `invalid_context` catalog entry in `docs/api/errors.md` says "Currently emitted on `include_deleted` against detail endpoints" — now too narrow.
2. `docs/api/resource-identifiers.md` still says `?include_deleted` on a detail endpoint returns `code: unknown_field` — stale; should be `invalid_context` (the original TRA-777 docs PR missed this site).
3. The TRA-777 changelog entry claims "an audit of the rest of the public surface found no other parameters with the same wrong-code drift today" — now contradicted by #373.

## Approach

Three targeted edits. No new sections, no new examples beyond what already exists.

### 1. `docs/api/errors.md` — `invalid_context` catalog entry

Rewrite the second sentence of the entry from a single-example framing to a category framing with representative names. Keep the `include_deleted` example because it carries the most specific diagnostic. Add the rest of the public list-filter set as a comma-joined list.

Replacement structure (CC's wording):

> `invalid_context` — a known parameter was sent on a surface where it is not allowed. Emitted when any of the public-API list-endpoint filter parameters (`external_key`, `is_active`, `parent_id`, `q`, the `*_external_key` natural-key forms, `include_deleted`, …) lands on a detail, write, or sub-resource endpoint that does not declare it. The accompanying `message` names the list endpoint where the parameter is honored (e.g. `GET /api/v1/assets`) when one can be derived from the request path; `include_deleted` carries its existing specialized "soft-deleted records are not retrievable by id" wording. Strict-typed clients switching over `code` should add an arm for this value to distinguish "known parameter, wrong context here" from `unknown_field` ("parameter the API does not declare at all").

Keep the cross-link to `unknown_field` (already in entry).

### 2. `docs/api/changelog.md` — TRA-777 BB62 entry

Replace the sentence:

> An audit of the rest of the public surface found no other parameters with the same wrong-code drift today; the shared validator helper that emits the code makes future additions a one-liner.

With:

> The shared validator helper now applies the new code uniformly: any of the public-API list-endpoint filter parameters landing on a detail, write, or sub-resource endpoint emits `invalid_context` (`include_deleted` keeps its specialized natural-key diagnostic; the rest carry a generic `see GET /api/v1/{resource}` message). Truly unknown query keys (`?wat=1`) continue to emit `unknown_field`.

Same release wave; editing the entry rather than adding a separate one keeps the changelog readable.

### 3. `docs/api/resource-identifiers.md` — `?include_deleted` on detail

Single-token fix: change `code: unknown_field` → `code: invalid_context` in the existing sentence at line 157. The surrounding prose ("with a diagnostic naming the recovery path") stays correct.

## Out of scope

- The `ParseListParams` `default:` branch documented in PR #373 as a deliberate carve-out — still emits `unknown_field` on sub-resource paths like `/api/v1/locations/{id}/ancestors`. Not user-visible enough today to warrant a doc note; if a future BB cycle surfaces it, file as its own ticket.
- The `see GET /api/v1/{resource}` message wording in the platform error envelope is not reproduced verbatim in the docs catalog — the catalog describes what the code means and points integrators at the list endpoint generically; reproducing the exact wording would couple docs to platform string churn.

## Verification

- `pnpm build` clean
- `pnpm lint` clean (prettier)
- Browser-render the three affected pages — `/docs/api/errors`, `/docs/api/changelog`, `/docs/api/resource-identifiers` — and confirm no orphan-link or anchor-rot from the edits.
