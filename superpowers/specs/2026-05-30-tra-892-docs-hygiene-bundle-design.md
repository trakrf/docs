# TRA-892 — Docs-hygiene bundle: 3 one-line API-docs fixes + groom the `contact.url` deferral

**Date:** 2026-05-30
**Ticket:** TRA-892
**Type:** Docs-only PR (4 wording/backlog edits) + one Linear grooming comment

## Problem

The 2.6.1 black-box fleet (runs bb-261/262/263, svc `v1.1.1-165-g8ca09556`) surfaced four
documentation-hygiene items. **None gate the prod launch** — zero service/contract defects
were found. Each is a one-line wording correction or backlog grooming, safe to land any time.

## Prerequisite verification (done before writing)

Verified each claim against the live preview (`app.preview.trakrf.id`) and the current docs:

| Claim to verify                                   | Finding                                                                                                                                                                                  | Consequence                                                                                |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `AssetView` has no `location_id` field            | Confirmed — current location is exposed only on `GET /reports/asset-locations` and `GET /assets/{id}/history` (`tracking:read`); `resource-identifiers.md` already states this correctly | Fix only the BB onboarding-wrapper shorthand (item 1)                                      |
| Empty `PATCH {}` still advances `updated_at`      | Confirmed by ticket's live evidence (200, `updated_at` drift); `quickstart.mdx:167` already documents the always-advance behavior in full                                                | Add a one-line qualifier at the compressed mention `quickstart.mdx:145-146` (item 2)       |
| Docs-origin `/health.json` lacks API/spec version | Confirmed — docs origin returns only the docs build stamp; `app` origin `/health.json` carries `version` + `spec_refreshed_at`                                                           | Point BB's version check at the app origin (item 3)                                        |
| `info.contact.url` restored by design             | Confirmed — live spec serves `info.contact.url: https://trakrf.id` (Stripe pattern: marketing root + `support@trakrf.id`), restored via platform TRA-882 (PR #440)                       | The `BACKLOG.md` "restore the URL when a helpdesk lands" deferral is now obsolete (item 4) |

## Scope — four edits

### Item 1 — `tests/blackbox/BB_PRE_KEY.md` (fixture-data section)

`:47` currently reads as if `location_id` is a field on the asset object. Reword to state the
current location is resolved from scan history via the asset-locations report / history
endpoints, **not a field on the asset object**. Also reconcile `:49`'s parallel
"materialized `location_id` on every asset" phrasing so the doc stays internally consistent
after the item-1 fix (otherwise the two lines contradict). Both are minimal; the determinism
promise (every fixture asset has a resolvable current location) is preserved, only the
"it's a field" implication is removed.

### Item 2 — `docs/api/quickstart.mdx` (§ minimal PATCH)

`:145-146` compresses "`{}` is a documented no-op" too far. Reword to "a documented no-op
**against settable fields** (it still advances `updated_at`)". Chosen over "link to the design
note" because the same code block's prose at `:167` already deep-links
`design-notes#updated_at-is-an-optimistic-concurrency-token-on-patch`; the inline qualifier
closes the gap where a reader stops at the comment.

### Item 3 — `tests/blackbox/BB.md` (context-block version check)

`:209` tells the BB harness to fetch the spec/build version from `$API_TEST_DOCS_URL/health.json`,
which carries only the docs build stamp. Repoint it at `$API_TEST_APP_URL/health.json` (the
authoritative `version` + `spec_refreshed_at` surface) and note that the docs origin only
carries the docs build stamp, so the cohort stops filing "version missing" where-to-look nits.
Chosen over surfacing the API/spec version on the docs host — that is an infra/build change
outside doc-hygiene scope, and the ticket explicitly offers the BB.md correction as the
alternative.

### Item 4 — groom the `contact.url` deferral

TRA-743 (which removed `info.contact.url`) is **already Done**; the URL has since been restored
by design (TRA-882). So "close as resolved" reduces to grooming the residue:

- **Docs:** remove the now-stale `tests/blackbox/BACKLOG.md:47` row ("Restore `info.contact.url`
  … when a helpdesk lands"). The deferred work is done — keeping the row would advertise a
  removal that no longer reflects reality.
- **Linear:** add a comment to TRA-743 recording the course reversal (URL restored by design,
  Stripe pattern, `https://trakrf.id`) and that the BACKLOG deferral has been removed as obsolete.
  No state change — the ticket is already Done.

## Out of scope

- Surfacing API/spec version on the docs host (item 3's other option) — infra/build change.
- Any platform/spec change — `info.contact.url` is already correct on the live spec; no paired
  platform edit is needed for any item.
- Touching `tests/blackbox/.env.local` — already re-keyed this session, unrelated.

## Verification

- `pnpm build` and `pnpm lint` pass (Redocusaurus fetches the live spec at build time; no spec
  change here, so the build is unaffected).
- The three doc edits are wording-only; the BACKLOG edit removes one table row.
- TRA-743 grooming comment posted.
