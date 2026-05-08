---
ticket: TRA-604, TRA-605
parent: TRA-596
date: 2026-05-08
status: design
---

# TRA-604+TRA-605 — BB17 W4 — wrong-method 405 spec refresh

## Goal

Catch the trakrf-docs site up to platform PR #273, which fixed two
wrong-method routing bugs:

- **TRA-604** — `r.Route(...)` mounts under `/api/v1/orgs/{id}` ran
  `middleware.Auth` before chi's MethodNotAllowed handler, so wrong
  methods leaked `401 unauthorized` instead of `405 method_not_allowed`.
- **TRA-605** — `r.Get("/api/*", …)` 404 catchall shadowed registered
  POST/DELETE-only paths (GET → 404 instead of 405) and polluted `Allow`
  headers with phantom `GET, HEAD` entries on legitimate 405s.

The platform fix is purely a wrong-method failure-mode correction. No
endpoint shape changed; no integrator who was issuing the right method
on the right path sees any difference. The docs side is therefore
spec-refresh-only.

## Verified state (post-spec-refresh)

`pnpm refresh-openapi` against `platform@4e04cfb` produced one functional
spec change: the `orgs.me` operation gained a `405 method_not_allowed`
response (with the `Allow` header schema). The other wrong-method
surfaces in TRA-604 (`/orgs/{id}/api-keys`, `/orgs/{id}/members`,
invitations) live behind session JWT auth and aren't part of the public
filtered spec, so they don't show up in our `static/api/openapi.*`.

The TRA-605 surfaces (`/assets/{id}/tags`, `/locations/{id}/tags`, etc.)
were already in the public spec without explicit `405` responses; the
platform team did not add them in PR #273. That's consistent with how
the spec already documents these write-only operations — the 405 is a
generic chi-level response that the spec doesn't enumerate per
operation. Errors that flow through the central `errors.ErrorResponse`
schema are documented generically on the
[Errors](/docs/api/errors) page, which already lists
`method_not_allowed` with the `Allow` header semantics.

## Decision: no prose edits

The TRA-604 ticket comment flagged a conditional doc impact ("if we
publish a common-errors or troubleshooting page, the wrong-method case
is now correctly classified as 405 rather than 401"). That page does
not exist, and the existing `errors.md` already documents the 405
shape correctly:

> `method_not_allowed` — 405 — The route does not accept the HTTP
> method you used … Allowed methods are listed in the response
> `Allow` header and mirrored in `detail`.

That description was true *as documented* before PR #273; the platform
fix brings runtime behavior into alignment with the docs, not the
other way round. No prose surfaces are stale.

The CHANGELOG entry is also a no-op: the v1 stability commitment is
about path/field/shape stability, and a 401→405 status correction on
wrong methods is a bug fix to an undocumented failure mode, not a
breaking change.

## Changes

### File 1: `static/api/openapi.{json,yaml}` + Postman + `platform-meta.json`

Already refreshed in this branch's first commit (`platform@4e04cfb`).
Diff: +18/-0 lines net on the spec (a single `405` response block on
the `orgs.me` operation), plus the always-noisy regenerated Postman
collection.

### No other files

No prose edits. No changelog entry. No nav changes.

## Acceptance

- `static/api/openapi.{json,yaml}` reflects `platform@4e04cfb`.
- `static/api/platform-meta.json` records the new SHA.
- `static/api/trakrf-api.postman_collection.json` regenerated.
- `pnpm build` passes.
- Existing 405 documentation in `docs/api/errors.md` remains accurate
  with no edits required.

## Plan structure

Two waves:

1. **Spec refresh** (already executed) — single commit, the regenerated
   files only.
2. **Verify + ship** — `pnpm build`, push, PR.
