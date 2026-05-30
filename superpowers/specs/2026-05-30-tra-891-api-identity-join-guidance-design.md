# TRA-891 — Correct API integration identity guidance: join on natural keys, demote surrogate `id`

**Date:** 2026-05-30
**Ticket:** TRA-891 (revises TRA-885)
**Type:** Docs-only PR (verified — see Edit-site determination)

## Problem

TRA-885 shipped a line advising integrators to use the surrogate `id` as their durable
foreign key when mirroring TrakRF data. That contradicts the intended model: integrators
should join on natural/business keys (`external_key`), and the surrogate `id` is a stable
internal anchor for reconciliation — **not** the integrator's business foreign key. Telling
partners to key their system of record on our `id` manufactures a dependency on an opaque
internal identifier, which is exactly the coupling we want to avoid before launch.

This spec corrects that line, reframes `id`, adds join guidance, and demotes `id` on the
versioning page.

## Prerequisite verification (done before writing)

The ticket requires docs to describe real behavior, not aspiration. Verified against the
live spec at `https://app.preview.trakrf.id/api/openapi.yaml` (the source Redocusaurus
builds from) and the current docs prose:

| Claim to verify | Finding | Consequence |
| --- | --- | --- |
| `external_key` present + returned on assets | `AssetView.external_key`, `required` | Document join on `external_key` ✓ |
| `external_key` present + returned on locations | `LocationView.external_key`, `required` (ticket flagged this "unconfirmed") | **Confirmed present** — safe to document the locations join ✓ |
| `customer_identifier` field exists on the API | **0 occurrences** in the spec | The API field is `external_key`. The ticket's "(customer_identifier)" is platform/DB column terminology — do **not** introduce `customer_identifier` into public docs |
| Users are a public, joinable resource | `/api/v1/users/me` and `/users/me/current-org` are **Internal**; no public `User`/`UserView` schema; no `email` join surface | **Do not** add per-entity "join users on email/id" guidance — there is no public users resource to join |
| Organizations are a public, joinable resource with a `slug` | Only `/api/v1/orgs/me` is public (singleton, key-scoped); `OrgView` = `{id, name, scopes, api_key_id}`; **no `slug`**, no public org list/get-by-id | **Do not** add "join orgs on slug/id" guidance — `slug` does not exist on the public surface, and an integrator is always scoped to its own org |
| Wrong "durable foreign key" advice also in OpenAPI field descriptions? | **No** — only in docs-repo prose (`resource-identifiers.md`, `changelog.md`) | This is a **docs-only PR**; no paired platform edit needed |
| Delta / incremental sync advertised anywhere? | **Not advertised** (no `delta`, `updated_since`, cursor-sync capability claims) | Nothing to retract and nothing to add — do not introduce a "not-yet-supported" mention for a capability we never claimed |

### Deviation from the ticket's literal scope (intentional)

The ticket lists per-entity join guidance for four entity types. Verification shows only
**assets** and **locations** are public joinable resources carrying the relevant field
(`external_key`). **Users** and **organizations** are not part of the public integration
surface (users are internal-only; the public org surface is the singleton `/orgs/me` with
no `slug`). Per the ticket's own instruction — *"do not document a join key that is not
present"* / *"describe real behavior, not aspiration"* — the user/org email-vs-id and
slug-vs-id guidance is **omitted** rather than published as aspiration. The general rule
(join on a stable natural key where one exists; where none does, `id` is the durable
handle) is stated, which covers the intent without inventing a public surface.

This is flagged here and in the PR for reviewer (ticket-author) sign-off at the merge gate.

## Changes

All edits are docs-repo prose. Branch: `docs/tra-891-identity-join-guidance`.

### 1. `docs/api/resource-identifiers.md` — the launch-relevant fix (do first)

**§ "Numeric `id` is a surrogate key" (line ~58).** Remove the final sentence
*"Use `id` as your durable foreign key when you mirror TrakRF data."* Replace with a reframe:

- `id` is server-assigned, opaque, stable, and not arbitrarily rekeyed — usable as a
  **sync / reconciliation anchor** when you mirror TrakRF data.
- It is **not** your business foreign key. Join your system of record on the natural key
  (`external_key`) where one exists; reach for `id` only as the durable handle when no
  natural key is available.

Keep the existing factual properties (globally unique, opaque, minted from a non-reseeded
shared sequence) — those are correct and were just affirmed by TRA-885. Only the
prescriptive "use it as your FK" framing changes. Do **not** escalate the wording into an
absolute permanence guarantee.

**§ intro (line ~7).** Light touch only — the existing framing already names `external_key`
as "canonical for partner-side joins / the natural key," which is correct. Ensure nothing in
the intro implies `id` is the partner-side join key.

### 2. New subsection in `resource-identifiers.md` — per-entity join guidance

Add a short subsection near the surrogate-key section stating the rule explicitly:

- **Assets / locations:** join on `external_key` (your handle: SKU, asset tag, ERP code,
  facility code).
- **General rule:** join on a stable natural key where one exists; where none does, `id` is
  the durable handle — used as a reconciliation anchor, not exported as a business key.
- Note that the public integration surface is assets, locations, and tags; users and
  organization administration are not public joinable resources in v1 (an integration is
  scoped to a single organization via its API key).

### 3. `docs/api/changelog.md` (line ~18)

Reword the TRA-885 changelog entry to drop *"and use it as your durable foreign key"* /
*"use it as your durable foreign key."* Keep the global-uniqueness/opaque/permanent facts;
remove only the FK prescription so the changelog doesn't re-assert the corrected advice.

### 4. `docs/api/versioning.md` — demote `id`

Add a short note (under the stability commitment) that the surrogate `id` is a stable
internal anchor, **not** the integrator's business foreign key — integrators should key
their own systems on natural keys (`external_key`). The page already states the
additive-only / RFC 8594 breaking-change policy, so no new policy is needed. **Do not** add
an absolute `id`-permanence guarantee to the contract — that would re-sell the dependency
this ticket removes.

## Out of scope

- `external_key` uniqueness enforcement (a platform constraint) — separate follow-up.
- Membership / access audit log — separate follow-up.
- Any OpenAPI field-description edits (none needed; advice lives only in docs prose).
- Per-entity join guidance for users/orgs as joinable resources (not present on the public
  surface — see verification).

## Validation

- `pnpm build` succeeds (Redocusaurus fetches the live spec; the prose edits are
  Markdown-only and must not break the build).
- `pnpm typecheck` / `pnpm lint` clean.
- Internal doc links resolve (the new subsection anchor, and any cross-links to it).
- Manual read-through: the corrected pages no longer advise `id`-as-foreign-key anywhere,
  and the reframe reads coherently against the surrounding text.
