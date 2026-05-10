---
ticket: TRA-652, TRA-653
title: BB24 docs + spec polish — asset_deleted_at prose, rate-limits pacing, X-API-Key cross-reference, WWW-Authenticate spec refresh
status: design
date: 2026-05-10
---

# Goal

Single trakrf-docs PR folding two BB24 sibling tickets:

- **TRA-652** — three docs prose findings (F1 `asset_deleted_at` always-present mismatch, F2 rate-limits pacing recommendation, F3 X-API-Key cross-reference under quickstart troubleshooting).
- **TRA-653** — refresh the OpenAPI spec mirror to pick up platform [#294](https://github.com/trakrf/platform/pull/294), which declares `WWW-Authenticate` on every 401. Pure mirror refresh; the platform PR also did the adjacent-surface audit for 403 / 429 / 5xx / Location-on-201 and recorded "no spec gap" — see the [Linear comment](https://linear.app/trakrf/issue/TRA-653) and the platform PR description.

The acceptance bar is that BB25 should be able to discover the corrected behavior by reading prose pages alone, without consulting the OpenAPI spec or the live service. No backend, SPA, or spec edits in this repo — pure docs prose plus the spec-mirror chore.

# Pre-implementation audit

| Finding                                           | Where it lives today                                                                                                                                       | Verdict                                                                                                                                                                                                                                                   |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F1 — `asset_deleted_at` always-present            | `resource-identifiers.md` L124 ("Without that flag … the field is absent from the row. With the flag, the field is always present")                        | Wrong. Live service: field is always present on every row, `null` for live, populated for soft-deleted. The flag controls whether soft-deleted rows appear at all, not whether the field is rendered.                                                     |
| F2 — rate-limits preemptive pacing recommendation | `rate-limits.md` L36 (header table), L41–48 (preemptive pattern), L80 ("Read `X-RateLimit-Remaining` proactively")                                         | Wrong. `Remaining` only decrements once the bucket has drained the burst margin; preemptive pacing on it can't trip until throttling is already imminent. Rewrite around 429 + `Retry-After`.                                                             |
| F3 — X-API-Key callout discoverability            | `authentication.md` L42–44 (`:::caution X-API-Key is not accepted` admonition with the trigger string `Use Authorization: Bearer <token>`)                 | Discoverability gap. `quickstart.mdx` step 2 troubleshooting (L64–69) lists 401 / 429 / CORS but not the alternate-header miscue. A developer who curl'd with `X-API-Key` searches the trigger string and lands on authentication.md only after two hops. |
| TRA-653 — `WWW-Authenticate` declared on 401      | `static/api/openapi.{json,yaml}` declares only `X-RateLimit-*` and `X-Request-Id` on 401 responses (current mirror snapshot pre-refresh, commit `d08003e`) | Net new — mirror refresh from `trakrf/platform@8cca418` adds `WWW-Authenticate: Bearer realm="trakrf-api"` on all 20 public 401s.                                                                                                                         |

Adjacent-fix scan for the named findings (per ticket guidance):

- **F1 adjacency.** `date-fields.md` L7 already cross-links to `resource-identifiers#soft-delete-visibility` with no mention of the broken "field is absent" rule — fine, no edit. `pagination-filtering-sorting.md` L79–91 covers the `include_deleted=true` toggle in terms of "whether soft-deleted rows appear" — already correct, no edit. The bug is contained to `resource-identifiers.md` L124.
- **F2 adjacency.** Grep for `X-RateLimit-Remaining` and `preemptive` across `docs/`: only `rate-limits.md` recommends Remaining-based pacing. `quickstart.mdx` L67 mentions `Retry-After` as the 429 wait signal, which is the correct advice. No other prose page perpetuates the pattern.
- **F3 adjacency.** Grep for `X-API-Key` across `docs/`: only `authentication.md` mentions it. `errors.md` 401 catalog row at L63 names "wrong scheme" generically ("Missing, malformed, revoked, or expired API key. The specific cause … is in `detail`") — fine to leave; the catalog is intentionally generic about per-detail strings. The fix is the quickstart cross-reference, as the ticket scoped.
- **TRA-653 adjacency.** Platform PR #294 already audited 403 / 429 / 5xx / Location-on-201 and recorded findings on the Linear ticket (no residue). Nothing more to do on the docs side beyond the mirror refresh.

# In-scope changes

## `docs/api/resource-identifiers.md` — F1

Replace the current §`Soft-delete is not a general field` paragraph (around L124) with a corrected version that:

1. Keeps the "narrowly scoped" framing — `asset_deleted_at` only on `report.PublicCurrentLocationItem`.
2. **Inverts the conditional.** The field is **always present** on rows that appear in the response — `null` for live assets, populated with the deletion timestamp for soft-deleted ones. The OpenAPI spec marks it `required` on `report.PublicCurrentLocationItem`, matching live behavior.
3. **Reframes the flag.** `?include_deleted=true` controls whether soft-deleted asset rows appear in the response at all — without the flag, soft-deleted rows are filtered out, but live rows still carry `asset_deleted_at: null`. The flag does not change the field's presence on a row that's already in the response.

Anchor `#soft-delete-visibility` is preserved (existing cross-link target from `date-fields.md` and `errors.md` neighborhoods).

The neighboring paragraph at L126 (path-param read returns 404 once soft-deleted) stays — separate point about a separate path. No edit needed there.

## `docs/api/rate-limits.md` — F2

Three coordinated edits, all of them rewrites of existing prose (no new sections):

**Header table (L33–37).** Update the `X-RateLimit-Remaining` row description to be accurate without prescribing pacing on it: drop "stays at `Limit` while you're inside the burst safety margin" as the headline behavior, and instead state "Decrements only after the burst margin is consumed, so a value of `Limit` does not mean you have a full request budget — it means you are still inside the burst headroom." This keeps the fact about the header truthful without selling it as a pacing input.

**Preemptive pattern paragraph (L41–48).** Remove the `if remaining < some_threshold: time.sleep(max(0, reset - now))` snippet entirely. Replace with a one-paragraph framing that names the trap explicitly: because `Remaining` doesn't decrement until the bucket has drained through the burst margin, watching it for preemptive pacing only triggers once a 429 is already imminent. The integrator-correct signal is the 429 itself plus `Retry-After`. Keep the existing observation that headers ride on every response (L39) — that fact is still useful for budget-tracking dashboards / observability, just not for pacing.

**Recommended client behavior list (L78–82).** Replace the second bullet ("Read `X-RateLimit-Remaining` proactively") with a bullet that frames the headers as observability signal, not a pacing input: "Treat `X-RateLimit-Remaining` and `X-RateLimit-Reset` as observability signals (dashboards, request-budget metrics) rather than pacing inputs. Pace on 429 + `Retry-After` instead." Keep bullet 1 (back off on 429) — already correct. Keep bullet 3 (429 is client-side) — already correct.

**Burst safety margin paragraph (L50).** Rewrite to align with the header-row reframe: state explicitly that the bucket holds 2× `Limit` tokens, that `Remaining` is reported as `min(bucket, Limit)` so the header never exceeds the steady-state cap, and link this to why preemptive `Remaining`-based pacing is the wrong signal (a hammer test confirmed `Remaining` stays at `Limit` until the bucket drains through the burst margin).

## `docs/api/quickstart.mdx` — F3

Add a fourth troubleshooting bullet at L64–69. The existing list is `401`, `429`, CORS. New bullet, placed after the 401 entry to keep it grouped with the auth misconfigurations:

> - `401 unauthorized` with `detail: "Use Authorization: Bearer <token>"` — the JWT was sent under `X-API-Key` (or another header). The server only accepts the `Authorization: Bearer` form. See [Authentication → Request header](./authentication#request-header).

The cross-link target is the §`Request header` heading anchor — the `:::caution X-API-Key is not accepted` admonition lives inside that section.

## OpenAPI spec mirror refresh (TRA-653)

Single chore commit on this PR: re-run `pnpm refresh-openapi` against `trakrf/platform@main`, picking up commit `8cca418` (platform PR #294 merge commit). The diff is mechanical:

- `static/api/openapi.{json,yaml}` — adds `WWWAuthenticate` to `components.headers` and references it from every 401 response (20 occurrences in the public surface).
- `static/api/trakrf-api.postman_collection.json` — regenerated.
- `static/api/platform-meta.json` — commit / source_url / spec_refreshed_at bumped.

No other paths touched. The platform PR description already enumerated the adjacent-surface audit; nothing more to do in this repo.

## Per-file audit-adjacent sweep

For each touched prose file, scan adjacent paragraphs while in the editor — record any trivial inline fixes in the PR description, leave anything substantive for a follow-up.

# Out of scope (declared)

- BB.md update for the F4 onboarding meta-friction recording — covered by [TRA-654](https://linear.app/trakrf/issue/TRA-654) (already shipped as PR #100).
- Adding a separate `X-RateLimit-Burst-Remaining` header — explicitly considered and declined in the TRA-652 ticket text. Adds API surface to make a recommendation work that the integrator-correct pattern (429-driven) already covers.
- Restructuring `rate-limits.md` — the page is short and the rewrite is in-place; no architectural changes.
- Backfilling errors.md with the X-API-Key trigger string — ticket scoped F3 to a quickstart cross-reference; the errors catalog is intentionally generic about per-detail strings.

# Acceptance

- [ ] All in-scope items above land in the named files in a single PR.
- [ ] Spec mirror refresh from platform PR #294 is in the PR (own commit, `chore(api): …`).
- [ ] `pnpm build` passes with no broken-link warnings.
- [ ] `pnpm lint` clean.
- [ ] PR description records what's net-new and the per-file adjacent-sweep findings.
- [ ] Linear comment on close references the PR and notes BB25 verification status (carries forward to the next preview deploy).
