# TRA-472 — Document the `valid_from` / `valid_to` convention (design)

**Linear:** [TRA-472](https://linear.app/trakrf/issue/TRA-472) — sub-issue of [TRA-468](https://linear.app/trakrf/issue/TRA-468)
**Repo:** `trakrf-docs` (this repo). Platform change landed separately as [PR #198](https://github.com/trakrf/platform/pull/198), merged 2026-04-23.
**Date:** 2026-04-24
**Status:** Approved — ready for implementation plan

## Goal

Add a short, standalone "Date fields" page to the public API reference that documents the `valid_from` / `valid_to` convention normalized by [TRA-468](https://linear.app/trakrf/issue/TRA-468). Integrators should be able to answer three questions from this one page:

1. What does the response look like — is `valid_to` always there or sometimes omitted?
2. What am I allowed to send on input — RFC3339? date-only? US slash format?
3. Where do the old sentinels (`0001-01-01`, `2099-12-31`) fit? (Answer: they don't, by contract.)

## Blocking conditions

- ✅ [Platform PR #198](https://github.com/trakrf/platform/pull/198) merged 2026-04-23T23:43:59Z.
- ⚠️ Preview-deploy verification: live `GET /api/v1/locations` and `POST /api/v1/assets` round-trip must confirm the documented shape before this PR ships. See Verification below. Hold the merge if the wire format doesn't yet match the docs.

## Scope

One PR, one branch, one worktree. Conventional commits, incremental (no squash).

- **Branch:** `miks2u/tra-472-date-fields-docs`
- **Worktree:** `.worktrees/tra-472` (created off `origin/main`)

**Commit plan:**

1. `docs(tra-472): design spec for valid_from/valid_to convention page` — this file.
2. `docs(tra-472): add Date fields page to API reference` — creates `docs/api/date-fields.md`, wires into `sidebars.ts`.
3. `docs(tra-472): changelog entry for date fields page` — one bullet under `Unreleased → Added`.

**In scope:**

- `docs/api/date-fields.md` (new page)
- `sidebars.ts` (one-line insertion)
- `docs/api/CHANGELOG.md` (one bullet)
- `spec/superpowers/specs/2026-04-24-tra-472-date-fields-design.md` (this file)

**Out of scope (explicit):**

- `static/api/openapi.yaml` — the date-only examples (`"2025-01-01"`) in request/response schemas contradict the "outbound always RFC3339" rule. This is a platform-side issue (the spec is generated from `backend/internal/handlers/swaggerspec/openapi.public.yaml` and synced here via `scripts/refresh-openapi.sh`). Suggested follow-up: file a new Linear ticket on the platform team to fix example values and add `description` fields to the `valid_from` / `valid_to` schema entries.
- `created_at` / `updated_at` / `deleted_at` audit timestamps — a different pattern (always present, never business-logic), deliberately carved out of TRA-468 and restated as out of scope here. A future "data model" doc can cover them.
- `valid_from < valid_to` validation rules — out of scope per TRA-468.
- Any platform or UI change.
- Enumeration of all 9 `FlexibleDate` input formats. We document the 3 integrators should rely on; the rest exist for tolerance but are not part of the integrator contract.

## Design

### Page placement

- **Location:** `docs/api/date-fields.md`
- **Front matter:** `sidebar_position: 4`
- **Sidebar slot** (in `sidebars.ts`, `apiSidebar` → `API Documentation` items list): between `api/resource-identifiers` and `api/pagination-filtering-sorting`.
- **Resulting reading order:** Quickstart → Authentication → Resource identifiers → **Date fields** → Pagination/filtering/sorting → Errors → Rate limits → Versioning → Changelog → Webhooks → Postman → Private endpoints.

Rationale: every cross-cutting field convention has its own short page (identifiers, pagination, errors, rate limits, versioning). Date fields is the same shape. Per the user's nav-over-URL-stability preference, the site is pre-launch so the new URL cost is zero.

### Page content outline

Target length: roughly the size of `docs/api/rate-limits.md`. Tone matches existing API pages — declarative, short paragraphs, one runnable example per concept.

1. **Lede (2–3 sentences)** — "Every timestamped resource in v1 uses the same two effective-date fields: `valid_from` and `valid_to`. This page describes their shape on the wire and what the API accepts on input. Audit timestamps (`created_at` / `updated_at` / `deleted_at`) follow a different convention and are not covered here."

2. **The two fields at a glance** — one table:

   | Field | Always present? | Type on response | Meaning |
   | --- | --- | --- | --- |
   | `valid_from` | Yes | RFC3339 UTC | When the record became effective. Defaults to the creation time on insert. |
   | `valid_to` | No — omitted when unset | RFC3339 UTC | When the record expires. **Absent key = no expiry.** |

   Plus prose: the API never returns `0001-01-01T00:00:00Z` zero-time, never returns a `2099-12-31` far-future sentinel, never returns `"valid_to": null`. If a client sees any of those, it's a bug — report it. Reference [TRA-468](https://linear.app/trakrf/issue/TRA-468) via the Changelog.

3. **Outbound: always RFC3339** — one paragraph. Side-by-side response snippet with two records in one list, one with `valid_to` set and one with `valid_to` absent. The comment on the second record calls out that the key is missing entirely, not `null`.

4. **Inbound: `FlexibleDate` (writes)** — recommend RFC3339 as canonical. Short table listing the three formats the ticket calls out:

   | Format | Example |
   | --- | --- |
   | RFC3339 (recommended) | `2026-04-24T15:30:00Z` |
   | ISO 8601 date-only | `2026-04-24` |
   | US `MM/DD/YYYY` | `04/24/2026` |

   One sentence after the table: "A handful of other regional variants (`DD/MM/YYYY`, `DD.MM.YYYY`, etc.) also parse for convenience, but the three above are the formats you should rely on."

   **Docusaurus admonition, level `warning`:**

   > **Slash dates are parsed US-first.** `04/05/2026` is parsed as April 5, not May 4. If your sender does not always emit US-format dates, send RFC3339 (`2026-04-05T00:00:00Z`) or ISO 8601 (`2026-04-05`) to avoid silent month/day confusion.

5. **Examples** — one `curl` block: `POST /api/v1/assets` with `valid_from` in RFC3339 and no `valid_to`, followed by `GET /api/v1/assets/{identifier}` showing the response with `valid_to` absent. Inline comment on the response block reiterates that the absent key is the contract.

6. **What changed** — one line: "See the [Changelog](./CHANGELOG) entry for the backend cleanup ([TRA-468](https://linear.app/trakrf/issue/TRA-468)) that made this convention uniform across all resources."

### Changelog entry

Under `Unreleased → Added` in `docs/api/CHANGELOG.md`:

> - Added **[Date fields](./date-fields)** — documents the `valid_from` / `valid_to` convention: `valid_from` always present as RFC3339, `valid_to` omitted when unset, inbound `FlexibleDate` parsing with US-first slash-date ambiguity warning ([TRA-472](https://linear.app/trakrf/issue/TRA-472)).

## Verification

**Build / lint:**

- `pnpm build` (Docusaurus catches broken internal links, missing sidebar entries, front-matter errors)
- `pnpm lint`

**Visual (pnpm dev):**

- New page renders at `/docs/api/date-fields`.
- Sidebar shows the new entry in the correct slot.
- The `:::warning` admonition renders as a callout, not as raw markdown.
- Internal link to `CHANGELOG` resolves.

**Preview-deploy reality check (the ticket's second blocking gate):**

Before declaring the PR mergeable, run against `api.preview.trakrf.id`:

1. `GET /api/v1/locations` — inspect every node; none should carry `valid_from = 0001-01-01T00:00:00Z`, none should carry `valid_to = 2099-12-31...`, and nodes without an expiry should have no `valid_to` key at all (not `"valid_to": null`).
2. `POST /api/v1/assets` with only `valid_from` set, then `GET /api/v1/assets/{identifier}` — confirm the response omits `valid_to`.

If either check fails, hold the docs PR: the ticket explicitly requires the backend reality to match the documented convention before merge.

## Definition of done

- New page `docs/api/date-fields.md` published with the content outlined above.
- Sidebar shows the new page in the correct slot.
- Changelog entry under `Unreleased → Added`.
- `pnpm build` and `pnpm lint` clean.
- Preview-deploy curls confirm the documented shape is live.
- PR opened against `main`, not merged until the preview check is green.
- Platform-side follow-up (OpenAPI example fixes) filed as a separate Linear ticket — mentioned in PR description, not required to close TRA-472.
