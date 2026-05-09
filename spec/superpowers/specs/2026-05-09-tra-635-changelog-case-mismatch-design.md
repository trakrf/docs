---
ticket: TRA-635
title: Polish Cluster D — fix /docs/api/changelog link case mismatch
status: design
date: 2026-05-09
---

# Goal

Make `/docs/api/changelog` resolve. Today the file is `docs/api/CHANGELOG.md`, which Docusaurus exposes only at the uppercase URL `/docs/api/CHANGELOG`. Align the slug with the lowercase convention used everywhere else in the API doc tree.

# Approach — Option A (rename to lowercase)

The ticket called this out as the recommendation, and the audit confirms it: every sibling file in `docs/api/` (`authentication.md`, `errors.md`, `quickstart.mdx`, `resource-identifiers.md`, …) is lowercase, and every internal link target across `docs/api/` already uses lowercase relative slugs. `CHANGELOG.md` is the lone holdout. A rename closes the gap with one file move plus six call-site updates and zero behavior change.

Option B (keep uppercase, add a redirect) was rejected: it leaves the file inconsistent with the tree, and nothing else in the project relies on uppercase slugs that would justify perpetuating the pattern.

# In-scope changes

1. `git mv docs/api/CHANGELOG.md docs/api/changelog.md`
2. `sidebars.ts` — `"api/CHANGELOG"` → `"api/changelog"` (entry order/label unchanged; the sidebar already says "Changelog").
3. `docs/api/README.md` — one link: `[Changelog](./CHANGELOG)` → `[Changelog](./changelog)`.
4. `docs/api/versioning.md` — five links: `[CHANGELOG](./CHANGELOG)` → `[Changelog](./changelog)` (lowercase the link text too so the prose reads as a word, not a filename SHOUTING).

# Sibling audit

Per the standing audit-immediate-category rule, I swept the rest of the docs tree for the same review pattern (uppercase doc filename in an otherwise-lowercase sidebar):

| File | Status | Reason |
|---|---|---|
| `docs/api/CHANGELOG.md` | **In scope** | The named target. |
| `docs/app-tour/AUTHORING.md` | **In scope** | Same pattern: uppercase filename sitting in `appTourSidebar` next to `home`, `inventory`, `locate`, … all lowercase. No incoming links to break. Folding in costs one rename and one sidebar edit. |
| `docs/api/README.md` | Out of scope (intentional) | Docusaurus convention for category root pages. Renaming would break the `apiSidebar` `link: { type: "doc", id: "api/README" }` entry and is not the same review pattern. |
| `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `README.md` (repo root) | Out of scope | Repo-root files, not part of the Docusaurus `docs/` tree. They follow GitHub convention, not URL-slug convention. |

I also re-verified the BB15 concept-guide slugs flagged in the ticket description (`identifiers` vs `resource-identifiers`, `pagination` vs `pagination-filtering-sorting`). Both were corrected upstream; every current `[…](./resource-identifiers)` and `[…](./pagination-filtering-sorting)` reference round-trips correctly. No remaining concept-guide case mismatches.

# Acceptance

- [ ] `/docs/api/changelog` resolves (200, not 404).
- [ ] `/docs/api/CHANGELOG` no longer exists (Docusaurus won't double-publish).
- [ ] `pnpm build` passes with no broken-link warnings.
- [ ] Sibling `docs/app-tour/authoring.md` resolves; `AUTHORING` slug is gone.
- [ ] PR description records what was audited and what was deferred (with reasons).
