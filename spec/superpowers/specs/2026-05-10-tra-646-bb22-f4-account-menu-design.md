---
ticket: TRA-646
title: BB22 F4 — "avatar menu" → "Account menu" prose sweep
status: design
date: 2026-05-10
---

# Goal

Promote BB22 finding F4 (the only pre-launch-actionable item left in TRA-646's backlog after platform PR [#291](https://github.com/trakrf/platform/pull/291) merged) into a docs-only PR. The SPA's account button has accessible name `Account menu` — its visual rendering is the user's email initial inside a circle, with no avatar image. The current docs prose calls this affordance the "avatar menu," which a new dev grepping the SPA cannot find. Rename "avatar menu" → "Account menu" everywhere it appears in the public-docs prose.

This is the docs half of the BB22 spec-hygiene drop. The platform side (S1, S2, S3, S4, S7) shipped in PR #291 and is reflected in the OpenAPI mirror refresh on the prior commit of this branch.

# Scope

## Public docs prose — rename "avatar menu" → "Account menu"

Six occurrences across four files:

1. `docs/api/authentication.md` L11 — minting flow intro.
2. `docs/api/authentication.md` L20–21 — mint walkthrough step 2 plus the multi-org organization-switcher caveat.
3. `docs/api/authentication.md` L26 — HTML-comment screenshot TODO. Update so a future grep for "Account menu" still finds the placeholder.
4. `docs/api/authentication.md` L29 — wrong-scope re-mint instruction.
5. `docs/api/authentication.md` L126 — listing/revocation pointer to the SPA.
6. `docs/api/quickstart.mdx` L14 and L32 — quickstart entry-paragraph and step-2 minting instruction.
7. `docs/api/private-endpoints.md` L15 — private-endpoints page's pointer back to the public auth page.
8. `docs/getting-started/api.mdx` L18 — getting-started prerequisites bullet.

Wording: drop "avatar menu" entirely and use "Account menu" verbatim — matches the SPA's accessible name, makes a grep land, and the visual (initial-in-circle) is not an avatar in the photo sense, so calling it one was always slightly off. No need to mention both terms; "Account menu" is the single canonical phrasing going forward.

## Out of scope

- The platform spec changes (S1/S2/S3/S4/S7) ship in the OpenAPI mirror refresh on the prior commit. No prose-side adjacent edits required — `errors.md` already documents 405 (L66), 422 `missing_org_context` including the deleted-org case (L69), and the RFC 8594 deprecation/sunset/410 flow (L292–301); `versioning.md` already documents the same flow (L84–101); `resource-identifiers.md` and `versioning.md` already describe the additive contract that S4 codifies in the spec; `quickstart.mdx` L141 already covers the codegen Bearer story that S7's hint complements. The platform changes are spec-mirror-only on the docs side.
- TRA-646 stays open per the parent ticket's "no batch close" rule. After this PR merges only the C1/C2/C3 not-actionable observations remain.
- Screenshot regeneration for the L26 TODO — separate workstream (`scripts/refresh-screenshots.sh`), not blocking this PR.

# Audit-adjacent check

Verified before editing:

- `grep -rni avatar docs src` — every occurrence is in scope above (4 files, 8 lines). No stray uses in components, sidebars, or doc fragments.
- `grep -rn "Account menu" docs src` — empty. This PR introduces the canonical phrasing for the first time; no risk of inconsistent prior usage.
- `errors.md` L75 ("two HTTP methods are intentionally **not** enumerated per path") still reads correctly post-S1: the call-out is about HEAD/OPTIONS, not 405. No edit.
- `authentication.md` 401 references (L43, L121, L122, L170) are about missing/malformed/revoked/expired keys, not about deleted-org context. The platform's S2 401→422 alignment for the deleted-org branch matches the existing `errors.md` L69 catalog claim already; no prose to chase.
- `quickstart.mdx` L141 codegen paragraph and L78 `Authorization header is required` example are unaffected by the S7 spec-description hint — that hint surfaces on the API reference page that renders the spec.
