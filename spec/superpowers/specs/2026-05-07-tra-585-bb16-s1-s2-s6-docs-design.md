---
ticket: TRA-585
parent: TRA-583
date: 2026-05-07
status: design
---

# TRA-585 — BB16 S1/S2/S6 docs follow-up

## Goal

Bring `trakrf-docs` into alignment with platform PR [#265](https://github.com/trakrf/platform/pull/265), which closed seven BB16 spec findings (S1/S2/S3/S4/S5/S6/S10) in a single OpenAPI annotation pass. Of the seven, three have any docs surface to update on this side: S1 (verification only), S2 (verification only), and S6 (one prose edit). The remaining four (S3 `Location` header, S4 415, S5 429 on `/orgs/me`, S10 `q` wording) are spec-only and ride along on the spec refresh.

## Background

Platform PR #265 (merged) reshaped the public spec without changing service behavior. The Linear ticket comment from the platform author flagged exactly three items as docs-side work: S1 (errors envelope description now matches docs prose verbatim), S2 (scope info moved from `security` blocks into operation descriptions), and S6 (tag-association DELETE is now declared as fully idempotent). The other four findings are pure spec annotations the docs site picks up automatically when the static spec is refreshed and Swagger UI re-renders it.

| Finding | Spec change | Docs surface |
| ------- | ----------- | ------------ |
| S1 | `errors.ErrorResponse` description rewritten to match the wording on `docs/api/errors` | `docs/api/errors.md` already says this — verification only |
| S2 | Scope arrays stripped from `security`; `**Required scope:** <scope>` prepended to each operation `description` | `docs/api/authentication.md` carries a hand-authored scopes table; nothing in markdown references the spec's `security` block — verification only |
| S3 | `Location` header declared on POST 201 responses | Spec-only — picked up by refresh |
| S4 | 415 declared on every operation that accepts a body | Spec-only — picked up by refresh |
| S5 | 429 + `Retry-After` declared on `GET /api/v1/orgs/me` | Spec-only — picked up by refresh |
| S6 | Tag-delete declares 204 only; idempotency note in operation description | `docs/api/errors.md` Idempotency section makes a sweeping DELETE claim that is no longer true for tag-delete — single prose edit |
| S10 | `q` parameter wording aligned across all three list endpoints | Spec-only — picked up by refresh |

## Verified docs state (pre-refresh, platform@cbffa1e)

```
$ sed -n '11,26p' docs/api/errors.md
# Envelope shape paragraph already states "modeled on RFC 7807 (Problem
# Details for HTTP APIs), but the envelope is not 7807-compliant: TrakRF
# serves application/json (not application/problem+json) and nests the
# fields under error rather than placing them at the top level."
# This is the prose the platform author copied into the new spec
# description, so docs side is already correct — S1 is purely verification.

$ grep -n "DELETE" docs/api/errors.md
217:- **`DELETE`** — idempotent. A second delete returns `404 not_found`
    (not `204`) so you can detect state drift; both outcomes are fine
    to treat as "deleted."
# Sweeping claim — true for top-level /assets/{id}, /locations/{id};
# no longer true for /assets/{id}/tags/{tag_id} or
# /locations/{id}/tags/{tag_id}, which now return 204 whether or not
# the tag was associated. S6 fix below.

$ git grep -n 'security' docs/api | grep -v 'security@trakrf\|SECURITY\|securely'
# Returns no hits that reference the spec's security block as a source
# of scope info — the scopes table in authentication.md is hand-authored.
# S2 is purely verification.
```

## Changes

### File 1: `docs/api/errors.md`

#### S6: split the DELETE idempotency bullet

The current line in the Idempotency section conflates two now-distinct DELETE behaviors. Top-level resource delete (assets, locations) is unchanged: 204 first, 404 second. Tag-association delete is fully idempotent: 204 every call. Splitting the bullet is the surgical fix.

Replace the single bullet at `docs/api/errors.md:217`:

```
- **`DELETE`** — idempotent. A second delete returns `404 not_found`
  (not `204`) so you can detect state drift; both outcomes are fine
  to treat as "deleted."
```

with two bullets, in this order (top-level first, then the tag-association case as a sub-distinction):

```
- **`DELETE /api/v1/assets/{id}`, `DELETE /api/v1/locations/{id}`** —
  idempotent in the "ends up gone" sense. A second delete returns
  `404 not_found` (not `204`) so you can detect state drift; both
  outcomes are fine to treat as "deleted."
- **`DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`,
  `DELETE /api/v1/locations/{location_id}/tags/{tag_id}`** —
  tag-association delete is fully idempotent: returns `204` whether
  or not the tag was associated. No 404-suppression retry logic
  needed.
```

Wording is intentionally close to the operation-description note the platform author landed in the spec (`Idempotent: returns 204 whether or not the tag was associated. Repeated calls are safe.`) so the two surfaces stay in sync.

### File 2: `static/api/openapi.{json,yaml}` + Postman collection

`scripts/refresh-openapi.sh` against `trakrf/platform@main` (post-#265 merge — at the time of writing, `b1c952f`). Picks up:

- S1 (`errors.ErrorResponse` description rewrite)
- S2 (scope arrays removed from `security`; `**Required scope:** <scope>` in every operation description)
- S3 (`Location` header on POST `/assets` and POST `/locations` 201s)
- S4 (415 declared on every body-accepting operation)
- S5 (429 + `Retry-After` on `GET /api/v1/orgs/me`)
- S6 (404 dropped from tag-delete; idempotency note in operation description)
- S10 (`q` parameter wording aligned, `(case-insensitive)` qualifier on all three list endpoints)

Updates `static/api/platform-meta.json` with the new SHA.

### Out of touch

- `docs/api/authentication.md` scopes table — hand-authored, unaffected by the security-block reshape. Already accurate against post-#265 spec.
- `docs/api/resource-identifiers.md` tag mentions (lines 199, 201, 214) — discuss tag identifier shape, not retry semantics. No edit needed.
- `docs/api/rate-limits.md` — already says every endpoint counts against the bucket; S5 just brings the `/orgs/me` spec declaration into line with that prose.
- The "parent-missing returns 404" tag-delete edge case — flagged in PR #265 comments as a possible follow-up handler change. Not in the spec, so not a docs concern this round.

## Sequencing

Single PR, single spec-refresh cycle. Commit order following TRA-579 / TRA-580 convention:

1. design doc
2. plan doc
3. doc edit (`docs/api/errors.md` idempotency bullet split)
4. spec refresh as the last commit (`chore(spec): refresh openapi from platform@<sha>`)

This keeps the spec-derived assertion in the doc commit (S6 idempotency wording) checkable against the spec at the same SHA.

## Acceptance

- [ ] `static/api/openapi.{json,yaml}` carry the new `errors.ErrorResponse` description (no longer claims full RFC 7807), no `[<scope>]` arrays in `security` blocks, `**Required scope:**` in operation descriptions, `Location` headers on POST 201s, 415 on body-accepting operations, 429 on `/orgs/me`, no 404 on tag-delete, and aligned `q` parameter wording.
- [ ] `docs/api/errors.md` Idempotency section has two DELETE bullets that distinguish top-level resource delete from tag-association delete.
- [ ] `git grep '404 not_found.*tags' docs/` returns no hits (no stale claim that tag-delete returns 404).
- [ ] `pnpm build` clean; `pnpm lint` 0 errors.

## Out of scope

- Switching from http-bearer to oauth2 (post-launch).
- Param renames `{id}` → `{asset_id}` etc. — TRA-586.
- `readOnly: true` annotations — TRA-587.
- BB16 quickstart / resource-identifiers prose sweep — TRA-584 (W2/W3/W4/W5/C1).
- Handler-side parent-missing 404 cleanup — possible separate ticket per PR #265 comments.
- Backfilling specs for prior PRs (per `feedback_no_spec_backfill`).

## References

- Platform PR: [#265](https://github.com/trakrf/platform/pull/265) — `feat(api): TRA-585 BB16 spec response declarations and security scheme`
- Sibling docs PR (pattern): [#67](https://github.com/trakrf/docs/pull/67) — TRA-580 BB15 S-2/S-3 + C-1/C-2/C-3 docs follow-up
- Parent epic: TRA-583 (BB16 launch readiness)
- Related: TRA-584 (BB16 W2/W3/W4/W5/C1 — quickstart + resource-identifiers sweep)
