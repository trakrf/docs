---
ticket: TRA-584
parent: TRA-583
date: 2026-05-07
status: design
---

# TRA-584 — BB16 W2/W3/W4/W5/C1 — Quickstart and resource-identifiers docs sweep

## Goal

Five docs-side fixes to the TrakRF API concept guides, surfaced by the BB16 dogfood pass. They share the same review surface (`docs/api/*`) and benefit from a single PR + build cycle. **No platform or spec changes** — the spec/service are already correct on every finding here; the work is bringing prose into line with what the service actually does.

## Background

BB16 testing exposed five places where the docs site contradicts live service behavior. Each is a small prose edit against an existing concept page. The TRA-585 sibling ticket landed the spec-side cleanup; this one closes the prose-side gaps.

| Finding | Page                                                                       | Nature of fix                                                                                                   |
| ------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| W2      | `quickstart.mdx` (step 3) + `authentication.md` (server-to-server section) | Add inline note that `/orgs/me` rejects session JWTs and requires an API key                                    |
| W3      | `quickstart.mdx` (step 3 troubleshooting block)                            | Update 401 sample to match the canonical error catalog (`Unauthorized` / `Authorization header is required`)    |
| W4      | `resource-identifiers.md` (response-shape table)                           | Move `description` out of the "and most scalars" implicit always-present bucket; document it as omit-when-unset |
| W5      | `pagination-filtering-sorting.md` (`q` section)                            | Replace "fuzzy search" wording with "substring search (case-insensitive)" to match spec and service             |
| C1      | `resource-identifiers.md` (new short subsection)                           | Add a callout: integer `id` is unique per resource type only; cross-type collisions can occur                   |

## Verified state (pre-edit)

```
$ grep -n "session JWT" docs/api/authentication.md docs/api/private-endpoints.md docs/api/quickstart.mdx
docs/api/authentication.md:135: claim "session JWTs are also accepted on public endpoints"
docs/api/private-endpoints.md:51: documents the /orgs/me exception in a :::note
docs/api/quickstart.mdx: no mention of session JWTs in step 3

$ sed -n '74,89p' docs/api/quickstart.mdx
# 401 sample: title="Authentication required", detail="Use Authorization: Bearer <token>"
# Canonical (errors.md row 45): unauthorized -> "Unauthorized"
# Live service (BB16): detail="Authorization header is required"

$ awk 'NR==81' docs/api/resource-identifiers.md
# Always-present row lists id, name, external_key, created_at, updated_at, is_active, valid_from
# followed by "(and most scalars)". The "and most scalars" wording sweeps `description`
# into always-present, but service marks it optional and omits it when empty.

$ grep -n "substring\|fuzzy" docs/api/pagination-filtering-sorting.md static/api/openapi.yaml
docs/api/pagination-filtering-sorting.md:110: prose says "q performs a fuzzy search"
docs/api/pagination-filtering-sorting.md:124: prose also says "q is case-insensitive and matches substrings"
static/api/openapi.yaml: every q description reads "substring search (case-insensitive)..."
# Two prose lines disagree with each other; the spec is canonical and uses substring.
```

`description` is confirmed optional in the spec: not listed in `required` for `asset.PublicAssetView` (lines 81-92 of `static/api/openapi.yaml`) or `location.PublicLocationView` (lines 317-328). Spec and service are already in agreement; this is purely a doc fix.

## Changes

### File 1: `docs/api/quickstart.mdx`

#### W2: step 3 says "use an API key here, not a session JWT"

The current step 3 prose pitches `/orgs/me` as the canonical "verify your key" endpoint without warning that the SPA's session JWT — which works on every other public endpoint — fails here with `401`. Surface the exception inline so a reader who copy-pastes their browser's `Authorization` header against this curl gets a heads-up instead of a confusing `401`.

Edit the lead paragraph of step 3 (~line 48) to add one sentence at the end:

> `GET /api/v1/orgs/me` returns the organization the API key is scoped to. It's the canonical "tell me about myself" endpoint, requires no specific scope, and confirms end-to-end that your key authenticates against the right environment. **Use an API key here — `/orgs/me` rejects session JWTs from the web app, even though most other public endpoints accept them.** See [Private endpoints → Response shape: `/orgs/me`](./private-endpoints#orgs-me) for the precise rule.

This is a single-sentence addition; no other prose in step 3 needs to move.

#### W3: 401 sample matches live service

Replace the JSON sample block at ~lines 76-87 to use the canonical title and the live-service detail:

```json
{
  "error": {
    "type": "unauthorized",
    "title": "Unauthorized",
    "status": 401,
    "detail": "Authorization header is required",
    "instance": "/api/v1/orgs/me",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
  }
}
```

Two field changes: `title` from `Authentication required` → `Unauthorized` (matches `docs/api/errors.md` line 45 canonical pairing); `detail` from `Use Authorization: Bearer <token>` → `Authorization header is required` (matches what the live service emits when the header is omitted, observed in BB16). Surrounding prose stays put.

### File 2: `docs/api/authentication.md`

#### W2: inline `/orgs/me` exception in the session-JWT paragraph

The "Session JWTs are also accepted" sentence at line 135 is the one place a reader who's reasoning from this page gets the wrong impression about `/orgs/me`. Add a parenthetical at the end of the same sentence rather than introducing a new paragraph — the exception is a footnote on the rule, not a topic of its own.

Edit line 135:

> **Session JWTs are also accepted** on public endpoints (same `Authorization: Bearer <jwt>` form), because the web app and the API share a router. A session JWT is effectively unscoped for its 1-hour lifetime and is only convenient for ad-hoc UI-driven requests; integrators should use API keys so that auth is durable and scope-limited. **(One exception: `/orgs/me` accepts API keys only — see [Private endpoints → Response shape: `/orgs/me`](./private-endpoints#orgs-me).)**

Same anchor target as the Quickstart edit, so a reader landing from either page reaches the canonical statement in one click.

### File 3: `docs/api/resource-identifiers.md`

#### W4: document `description` as omit-when-unset

The response-shape table at lines 79-83 describes three coexisting field behaviors. The "always present" row's "(and most scalars)" tail implicitly classifies `description` as always present, but the spec marks it optional and the service omits it on rows where it's empty. Move it to the omit-when-unset row explicitly.

Replace the table's `Omitted when unset` row (current line 83) with:

```
| **Omitted when unset** | `description`, `valid_to` (and any optional field documented as omit-when-unset on its individual page) | key presence (`'k' in resp`) |
```

And update the prose immediately after the table (line 85) to acknowledge the addition:

> The omit-when-unset set is small and explicit. `description` and `valid_to` are the two on the asset and location response shapes today; both are absent from the response when no value is set, rather than emitted as `null`. When in doubt, check the field's documentation page — [Date fields](./date-fields) covers `valid_to`, this page covers FK pairs, and any field not called out elsewhere is in the always-present row.

The "(and most scalars)" qualifier on the always-present row stays — it remains accurate for the rest of the scalar set.

#### C1: polysemic-id callout

Add a new short subsection after **Path-param lookup uses `id`** (current line 18, before the **Natural-key lookup** heading on line 20). Heading and admonition:

```
### Numeric `id` collides across resource types

The integer `id` field on each schema is unique only within that resource type.
Numeric values can collide across types — an asset and a tag may share the same
integer `id`. (BB16 testing observed `790505327` as both an asset id and a
location-tag id within a single org.)

When passing ids between systems, qualify them with the resource type
(`asset_id`, `location_id`, `tag_id`). The string `external_key` field is
unique within an org *and* carries no cross-type ambiguity, so it's the safer
cross-resource identifier when types may be mixed in flight.
```

Placement rationale: the section comes immediately after "the integer `id` is the canonical handle" so the qualifier shows up before the reader internalizes a single-namespace mental model.

### Out of touch

- `docs/api/private-endpoints.md` — already documents the `/orgs/me` exception correctly. The new prose in `quickstart.mdx` and `authentication.md` deep-links into the existing `#orgs-me` anchor.
- `docs/api/errors.md` — canonical title table is already correct (`unauthorized` → `Unauthorized`). Quickstart is the divergent surface.
- `static/api/openapi.{json,yaml}` — already aligned with all five fixes (TRA-585 refresh). No spec touch this round.
- `docs/api/pagination-filtering-sorting.md` line 124 ("`q` is case-insensitive and matches substrings") — already correct. Only line 110's "fuzzy search" wording needs to flip.
- Schema-level rename of integer `id` → `asset_id` / `location_id` / `tag_id` is a v2-breaking change, deferred per the ticket's out-of-scope list.

### File 4: `docs/api/pagination-filtering-sorting.md`

#### W5: "substring" instead of "fuzzy"

Two-word fix at line 110:

> `q` performs a substring search (case-insensitive) across the resource's most commonly queried fields:

The companion sentence at line 124 ("`q` is case-insensitive and matches substrings.") becomes redundant once line 110 says the same thing. Drop line 124 to avoid restating the rule a few lines later — the prose tightens and there's no information loss.

## Sequencing

Single PR. Commit order following TRA-579 / TRA-580 / TRA-585 convention:

1. design doc commit
2. plan doc commit
3. one commit per finding for an easy review trail (W2, W3, W4, W5, C1) — five small commits

Splitting by finding rather than batching keeps each commit message close to the finding ID for traceability back to BB16 FINDINGS.md, and lets reviewers approve or roll back any single fix without unwinding the whole PR. No spec refresh on this PR — TRA-585 already pulled the post-#265 spec to `b1c952f`.

## Acceptance

- [ ] W2: Quickstart step 3 contains "use an API key here" / "rejects session JWTs" and links to `private-endpoints#orgs-me`. Authentication's session-JWT paragraph adds the parenthetical exception with the same link.
- [ ] W3: Quickstart 401 sample shows `"title": "Unauthorized"` and `"detail": "Authorization header is required"`.
- [ ] W4: `description` appears in the omit-when-unset row of the response-shape table; the prose paragraph names both `description` and `valid_to` explicitly. `git grep -n "description" docs/api/resource-identifiers.md` shows it in the omit-when-unset row, not the always-present row.
- [ ] W5: `git grep -n fuzzy docs/api/` returns no hits; the substring wording on line 110 of `pagination-filtering-sorting.md` matches the spec verbatim.
- [ ] C1: A new "Numeric `id` collides across resource types" subsection exists in `resource-identifiers.md` between the path-param and natural-key sections.
- [ ] `pnpm build` clean; `pnpm lint` 0 errors.

## Out of scope

- Schema-level rename of integer `id` field — v2 break, deferred.
- `q` description divergence across endpoints in the spec — closed by S10 in TRA-585's spec refresh.
- Service-side fixes — none required; spec and service are correct on all five findings.
- Backfilling W1 (Authentication SPA-first reframing) — owned by TRA-590.
- Path-param naming sweep `{asset_id}` / `{location_id}` — owned by TRA-586.

## References

- Parent: TRA-583 (BB16 launch readiness epic)
- Sibling: TRA-585 (BB16 S1/S2/S6 spec follow-up — already merged, brought spec to `platform@b1c952f`)
- Source: BB16 FINDINGS.md, findings W2, W3, W4, W5, C1
- Pattern: PR #68 (TRA-585) — same shape, single docs PR with design + plan + per-finding commits
