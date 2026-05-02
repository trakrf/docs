---
ticket: TRA-573
parent: TRA-566
date: 2026-05-02
status: design
---

# TRA-573 — BB14 doc/spec corrections (W3, W4, W5)

## Goal

Fix three documentation issues surfaced by BB14 against current platform behavior. All three would persist into BB15 regardless of the spec-refresh, so they're real fixes worth shipping pre-BB15.

The W5 spec-side work (declaring `sort` enums) shipped separately as platform PR #259 (`da6f832`) and is already pulled into this branch via the spec refresh. This design covers only the docs-side changes plus a small follow-on noting the new codegen-validation surface.

## Findings to address

### W3 — `location.path` formatting differs across rows

Seeded locations carry `path: "WHS-01"` (preserves case and hyphens). Newly-created locations carry `path: "bb14_slug_test"` (lowercased, hyphens-to-underscores). Same field, two formats visible to integrators.

**Disposition:** no doc change. We're pre-launch, so the inconsistency is fixed by reseeding to the canonical (lowercase + hyphen → underscore) format rather than by documenting a legacy carve-out. The existing `resource-identifiers.md` already documents the canonical transformation (line 161) and explicitly says `path` is not an identifier (line 165) — both of the ticket's "what to add" bullets are already covered. Reseeding is a separate platform/data concern, not in this PR's scope.

### W4 — PUT requires stripping six fields for locations, not four

The current "Read shape vs. write shape" section in `resource-identifiers.md` says "strip the four read-only fields" (asset-shaped) and tucks the locations 6-field caveat at the end. The asset-specific count misleads any integrator following the rule for locations.

**Disposition (per ticket):** rewrite as a generic rule rather than a per-resource count. Survives schema additions automatically; no per-resource enumeration to maintain.

### W5 — Pagination doc example 400s

`pagination-filtering-sorting.md` line 148 shows `?sort=-is_active,external_key`. Live service rejects `is_active` as an unknown sort field with 400. The spec-side gap (no enum declaration) was closed in platform PR #259; this ticket fixes the doc example.

**Disposition (per ticket):** replace with a valid sort field, verified against the current spec.

## Verified spec state (post-refresh, platform@da6f832)

The four list endpoints with declared sort enums:

| Endpoint | Sortable fields |
| --- | --- |
| `GET /api/v1/assets` | `external_key`, `name`, `created_at`, `updated_at` |
| `GET /api/v1/locations` | `path`, `external_key`, `name`, `created_at` |
| `GET /api/v1/locations/current` | `last_seen`, `asset`, `location` |
| `GET /api/v1/assets/{id}/history` | `timestamp` |

Each accepts the bare field name (ascending) or `-` prefix (descending). Wire format: comma-separated CSV (`style: form, explode: false`). No caller-visible behavior change from the platform PR — codegen now gets enum validation, that's it.

`is_active` is not in any sort enum. The ticket's suggested replacement `?sort=-created_at,external_key` is valid for assets.

## Scope decision

Three options were considered:

- **A.** Strict baseline — only W3 + W4 + W5 example fix.
- **B.** Baseline + add `assets/{id}/history` to the pagination doc's sortable-endpoint discussion (it now appears in the spec).
- **C.** Baseline + history sort + a sentence in the Sorting section noting that codegen / the interactive reference will reject unknown sort fields at compile time.

**Chosen: C.** The history-sort addition closes the same gap W5 just closed elsewhere (avoids leaving an in-spec endpoint undocumented). The codegen callout is a single sentence and serves the integrator directly.

## Changes

### File 1: `docs/api/resource-identifiers.md`

#### W4 — rewrite "Read shape vs. write shape" as a generic rule

Replace lines 87–132 (the entire "Read shape vs. write shape" section) with a generic statement of the rule, a single asset-specific worked example, and a note on the codegen vs. non-codegen experience.

The new section:

- Opens with: *Any field present in the GET response but not in the request schema is read-only and must be stripped before PUT.* Sending one returns `400 validation_error` with one `fields[]` entry per offending key (link to errors page for the envelope).
- Drops the "four fields" enumeration. Drops the trailing "same four-field strip applies to locations: id, created_at, updated_at, plus path and depth" paragraph.
- Keeps the worked `jq` example as a concrete illustration, with one sentence preceding it that says "for assets the read-only set today is `id`, `created_at`, `updated_at`, `tags`" — exemplary, not normative. The `jq` line then deletes that set explicitly.
- Closes with the codegen guidance the ticket calls out: TS strict-typed clients catch unknown fields at compile time; weaker generators send the field and receive a 400.
- Keeps the existing "Either form of the FK pair is accepted on write" paragraph (currently line 130) — that's about FK pairs, not read-only fields.

The asset-specific list inside the example is fine because it's framed as illustration of a generic rule, not the rule itself. New schemas auto-survive; integrators reading the rule know to derive their own diff.

### File 2: `docs/api/pagination-filtering-sorting.md`

#### W5 — fix the broken sort example

Line 148: replace

```
?sort=-is_active,external_key
```

with

```
?sort=-created_at,external_key
```

#### Surface `assets/{id}/history` sortability

The history endpoint accepts sort but the pagination doc doesn't mention it. The Sorting section's prose intro already says "All list endpoints take a `sort` parameter" so no change there — history is already a list endpoint per the rest of the doc. The fix is in the worked example: the "History" example (line 188) currently shows only `from`/`to`/`limit`; add `&sort=-timestamp` to demonstrate that sort works there too.

No per-endpoint sort-field table. The spec's enums are the single source of truth, surfaced through the interactive reference at `/api`; a duplicated table here would create a maintenance point and drift target.

#### Codegen-validation callout

Line 151 currently:

> Sortable fields vary per resource; the interactive reference at [`/api`](/api) lists the exact set each endpoint accepts. Unknown sort fields return `400 validation_error`.

Append one sentence:

> Generated clients with strict typing will reject unknown sort fields at compile time; weaker generators receive the 400 from the server.

This mirrors the W4 generic-rule guidance (compile-time vs. runtime feedback for codegen vs. non-codegen) and tells the integrator that the runtime 400 is now a fallback, not the only signal.

## Out of scope

- No service changes. `path` normalization, PUT strict-rejection, sort enum validation are all current canonical behavior.
- No legacy-data migration of seeded location paths.
- No per-endpoint sort-field table in the pagination doc — the spec is now the single source of truth via the interactive reference.
- No broader read/write asymmetry sweep across other resources — the W4 generic rule self-documents future schema additions.
- W1, S6, possibly C1/C2 from TRA-572 — expected to evaporate once the docs spec-refresh propagates (already pulled in this branch).
- Other BB14 findings (S1, S8) — separate tickets if they survive BB15.

## Acceptance criteria

- [ ] `resource-identifiers.md`: "Read shape vs. write shape" section rewritten as the generic strip-read-only-fields rule, asset list framed as illustration.
- [ ] `pagination-filtering-sorting.md`: broken `?sort=-is_active,external_key` example replaced with `?sort=-created_at,external_key`.
- [ ] `pagination-filtering-sorting.md`: history worked example demonstrates `sort=-timestamp`.
- [ ] `pagination-filtering-sorting.md`: codegen-vs-runtime sentence appended to the Sorting section's intro.
- [ ] `pnpm build` passes (typecheck, broken-link check, Redocly bundle).
- [ ] Spec refresh commit (already on the branch as `f29f148`) carries `platform@da6f832` in `static/api/platform-meta.json`.
- [ ] PR merged before BB15.

## References

- Parent ticket: TRA-566 (BB13 launch readiness)
- Source: TRA-572 BB14 findings, W3/W4/W5
- Sibling: TRA-569 (BB13 doc/service drift fixes — completes the resource-identifiers rule that S5 partially addressed)
- Platform PR for W5 spec-enum work: trakrf/platform#259 (`da6f832`)
- Spec-refresh disposition: TRA-445 (pull-only flow, this repo doesn't push spec changes)
