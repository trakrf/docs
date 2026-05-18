---
ticket: TRA-780
date: 2026-05-18
---

# TRA-780 BB63 docs — `WWW-Authenticate` 401 header, empty-object PATCH, changelog wave entry

Docs-side of the paired TRA-780 ticket. Platform PR (trakrf/platform#375) ships four service / spec changes (F1 readOnly annotations on AssetView/LocationView, F2 `ErrorEnvelope` hoist, F3 name validator message rewrite, F4 `read_only` → `invalid_context` semantic split for sub-resource-mutable fields). This PR adds two prose items and one changelog wave entry covering the integrator-visible F1 / F2 / F4 surface.

## Scope

Three changes against `trakrf/docs`:

1. **F5 — `WWW-Authenticate` prose** on `docs/api/errors.md`. The spec has always declared the header on every 401, and the service has always emitted it; the human-prose page never named it. Add a small subsection within the `Error type catalog` H2 documenting the RFC 7235 challenge contract alongside the envelope.
2. **F6 — empty-object PATCH prose** on `docs/api/errors.md`. The page documents the `null` PATCH rejection (`400 bad_request`) but never explicitly names the `{}` case (`200`, unchanged resource per RFC 7396). Extend the existing null-body paragraph to cover both top-level shapes back-to-back.
3. **Changelog wave entry** on `docs/api/changelog.md` for the platform PR's three integrator-visible items. F1 (readOnly annotations), F2 (`ErrorEnvelope` named schema), F4 (`read_only` / `invalid_context` split). F3 (name validator message wording) is below the changelog threshold per the platform owner — the four rejection classes are already documented in the BB62 follow-up entry, and the message text is explanatory, not contractual.

## F5 — `WWW-Authenticate` prose

Insertion point: a new H3 subsection `### 401 challenge: WWW-Authenticate header` inside the `## Error type catalog` H2, placed between the existing `### HTTP method coverage` subsection and `### validation_error vs bad_request`. Sits adjacent to the catalog's 401 row, ahead of the rest of the catalog discussion.

The new subsection covers two layers of the 401 contract — the envelope (already on the catalog row) and the standard RFC 7235 challenge header. Names the realm, names which clients care, and points handlers at `error.detail` for the specific cause string (the canonical wording already lives in the BB36 changelog entry).

Draft prose:

> Every 401 response includes a `WWW-Authenticate: Bearer realm="trakrf-api"` header per [RFC 7235](https://datatracker.ietf.org/doc/html/rfc7235), alongside the envelope `error.detail` describing the specific cause (missing header, malformed scheme, expired token, revoked key — see the [BB36 detail-string harmonization](./changelog#bb36-fix-wave--401-unauthorized-detail-strings-harmonized-across-endpoints)). Clients that challenge the user for credentials should surface the `realm` value; clients retrying programmatically should branch on `error.type` (`unauthorized`) and read `error.detail` for the specific cause string.

Adjusted to the established voice on the page (third-person, present-tense, no second-person "you" where the rest of the section uses indirect address).

## F6 — empty-object PATCH prose

Insertion point: the existing paragraph at `errors.md:150` already covers the `null`-body case. Extend that paragraph with a sentence on `{}` so a reader scanning either keyword finds both top-level shapes back-to-back. No new subsection — same logical block (`validation_error` vs `bad_request` → bottom of the residual `bad_request` discussion).

Draft additions to the existing paragraph:

> A `PATCH` request whose body is the literal JSON token `null` is a related but distinct case … (existing prose preserved) … not a top-level `null` body.
>
> A `PATCH` body of the empty object `{}` is the [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396) identity transform — the server applies a no-op merge and returns `200` with the resource unchanged (no `updated_at` advance, no envelope). Distinct from the rejected-as-`bad_request` `null` body above: `{}` is a valid JSON object containing zero merge directives, which RFC 7396 defines as a no-op. Clients that have nothing to update should skip the round-trip entirely; clients that need a "touch" semantic for cache invalidation should rely on `GET` rather than PATCH-with-`{}`.

Two paragraphs because the existing one is already dense; splitting keeps each rejection / acceptance case visually distinct.

## Changelog wave entry

New section at the top of the `## v1.0 — Launch (TBD)` block, above the `### BB62 follow-up` entry currently in pole position. Heading:

> `### BB63 fix wave — readOnly annotations on Asset / Location read views, ErrorEnvelope named schema, read_only vs invalid_context split`

Single intro paragraph framing the three items as a contract-class fix (F1 — annotation gap on four fields), a spec-hygiene refactor (F2 — `ErrorResponse.error` hoist), and a semantic split on a code-overload (F4). Pre-launch breaking on F2 (class rename on generators) and F4 (clients branching on the specific `code` value for these fields) — both worth taking now rather than post-launch when partners have already pinned against the older shape.

Three bullets, one per F item, modeled on the BB62 fix wave entry pattern:

- **F1 bullet** — names the four fields (`AssetView.location_id`, `AssetView.location_external_key`, `AssetView.tags`, `LocationView.tags`), names the OpenAPI 3.0 `readOnly: true` semantic, names the strict-typed-client effect (PATCH-construction-time client-side rejection), reaffirms runtime unchanged. Cross-link to [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape).
- **F2 bullet** — names the new `ErrorEnvelope` schema, names the `$ref` rewiring on `ErrorResponse.error`, names the generator-side class-rename effect (`ErrorResponseError` → `ErrorEnvelope` on `openapi-generator-cli` python), notes the description-text preservation. Wire shape unchanged. Pre-launch is the right time to take this churn. Cross-link to [Errors → Envelope shape](./errors#envelope-shape).
- **F4 bullet** — names the semantic split, enumerates the four affected (field × verb) cells, contrasts against the fields that stay on `read_only`, names the detail-string preservation (clients displaying `detail` continue to work). Handlers branching on `code` for these specific fields should update their `read_only` arm to also accept `invalid_context`. Cross-link to [Errors → Validation errors](./errors#validation-errors) (where the `invalid_context` catalog entry was broadened in the [BB62 audit follow-on](./changelog#bb62-fix-wave--body-decode-failures-normalized-to-validation_error-new-invalid_context-code-for-known-field-wrong-context-rejections)).

Exact wording matches voice / density of the BB62 entry — bold lead sentence, integrator-impact paragraph, cross-links to the load-bearing per-field-code section and the read/write-shape section. F3 (name validator message wording) is intentionally omitted — message text is explanatory, not contractual, and the underlying rejection classes are already documented in the BB62 follow-up entry directly above.

## Out of scope

- No spec / runtime edits — those ship in platform PR #375.
- No new pages, no nav changes, no restructuring of `errors.md` beyond the inserted subsection and the appended paragraph.
- No Linear ticket references in the prose (per repo convention).
- F3 changelog entry — below threshold per platform owner; the rejection classes are documented in the BB62 follow-up entry, and the message text is explanatory not contractual.

## Verification

- `pnpm typecheck` and `pnpm build` clean — Docusaurus catches broken anchors and dead cross-links.
- Manual: render `/docs/api/errors` and `/docs/api/changelog` locally; confirm the new F5 subsection lands between the existing `HTTP method coverage` block and `validation_error vs bad_request`; confirm the F6 paragraph extends the null-body discussion cleanly; confirm the BB63 wave entry sits above BB62 follow-up.
- Preview deploy via Cloudflare Pages on merge; subsequent BB cycle against the deployed preview verifies platform behavior matches the changelog wording (orthogonal to this PR — platform PR #375 already ships the behavior).

## Commits

1. `docs(api): TRA-780 BB63 F5 — document WWW-Authenticate challenge header on 401 responses`
2. `docs(api): TRA-780 BB63 F6 — document empty-object PATCH as RFC 7396 identity transform`
3. `docs(api): TRA-780 BB63 — changelog entry for readOnly annotations, ErrorEnvelope hoist, read_only/invalid_context split`

Order matches reading order in the PR diff — content first, changelog last (so a reviewer scrolling top-to-bottom in the diff sees the new docs prose before the summary entry that describes the platform-side changes).
