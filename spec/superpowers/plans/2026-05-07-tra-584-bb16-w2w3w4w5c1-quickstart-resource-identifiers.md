---
ticket: TRA-584
parent: TRA-583
date: 2026-05-07
spec: ../specs/2026-05-07-tra-584-bb16-w2w3w4w5c1-quickstart-resource-identifiers-design.md
status: plan
---

# TRA-584 — BB16 W2/W3/W4/W5/C1 docs sweep — implementation plan

Branch: `miks2u/tra-584-bb16-w2w3w4w5c1-quickstart-and-resource-identifiers-docs` (worktree at `.worktrees/tra-584`).

## Step 1 — design doc commit

- File: `spec/superpowers/specs/2026-05-07-tra-584-bb16-w2w3w4w5c1-quickstart-resource-identifiers-design.md` (already written)
- Commit: `docs(spec): TRA-584 BB16 W2/W3/W4/W5/C1 quickstart + resource-identifiers design`

## Step 2 — plan doc commit

- File: `spec/superpowers/plans/2026-05-07-tra-584-bb16-w2w3w4w5c1-quickstart-resource-identifiers.md` (this file)
- Commit: `docs(plan): TRA-584 BB16 W2/W3/W4/W5/C1 quickstart + resource-identifiers plan`

## Step 3 — W2 prose edits

Edit two files in one commit:

- `docs/api/quickstart.mdx` step 3 lead paragraph: append the "use an API key here" sentence with link to `private-endpoints#orgs-me`. Exact wording in design doc.
- `docs/api/authentication.md` line 135: append the "(One exception: `/orgs/me` accepts API keys only…)" parenthetical with the same anchor.

Verify:

- `grep -n "rejects session JWTs" docs/api/quickstart.mdx` returns one hit.
- `grep -n "One exception:.*orgs/me" docs/api/authentication.md` returns one hit.
- Both hits link to `./private-endpoints#orgs-me`.

Commit: `docs(quickstart,auth): note /orgs/me requires API key (TRA-584 W2)`

## Step 4 — W3 quickstart 401 sample

Edit `docs/api/quickstart.mdx` ~lines 76-87: replace the JSON sample so `title` reads `Unauthorized` and `detail` reads `Authorization header is required`. Surrounding prose stays put.

Verify:

- `grep -n "Unauthorized" docs/api/quickstart.mdx` returns the new sample's title line.
- `grep -n "Authentication required" docs/api/quickstart.mdx` returns no hits.
- `grep -n "Use Authorization: Bearer" docs/api/quickstart.mdx` returns no hits.

Commit: `docs(quickstart): align 401 sample with canonical error catalog (TRA-584 W3)`

## Step 5 — W4 resource-identifiers description-as-optional

Edit `docs/api/resource-identifiers.md`:

- Update the `Omitted when unset` table row (current line 83) to lead with `description, valid_to ...`.
- Update the prose paragraph immediately after the table to name `description` and `valid_to` explicitly.

Verify:

- `grep -n "description" docs/api/resource-identifiers.md` shows the field in the omit-when-unset row.
- `pnpm build` does not flag broken anchors or table syntax.

Commit: `docs(resource-ids): document description as omit-when-unset (TRA-584 W4)`

## Step 6 — W5 pagination prose substring

Edit `docs/api/pagination-filtering-sorting.md`:

- Line 110: replace `fuzzy search` with `substring search (case-insensitive)`.
- Line 124: drop the now-redundant "`q` is case-insensitive and matches substrings." sentence.

Verify:

- `git grep -n "fuzzy" docs/api/` returns no hits.
- `pnpm build` succeeds.

Commit: `docs(pagination): say substring not fuzzy for q parameter (TRA-584 W5)`

## Step 7 — C1 polysemic-id callout

Edit `docs/api/resource-identifiers.md`: add a new `### Numeric id collides across resource types` subsection between **Path-param lookup uses `id`** and **Natural-key lookup uses `/lookup?external_key=`**. Wording in design doc.

Verify:

- `grep -n "collides across resource types" docs/api/resource-identifiers.md` returns one hit.
- `grep -n "790505327" docs/api/resource-identifiers.md` returns one hit (the BB16 example value).
- `pnpm build` shows the new heading in the page TOC.

Commit: `docs(resource-ids): callout that numeric id collides across types (TRA-584 C1)`

## Step 8 — verification

- `pnpm build` — must be clean.
- `pnpm lint` — must be 0 errors.
- Visual spot-check is optional; the changes are content-only and the build pass exercises every internal link.

## Step 9 — push and open PR

- `git push -u origin miks2u/tra-584-bb16-w2w3w4w5c1-quickstart-and-resource-identifiers-docs`
- `gh pr create` against `main` with title:
  - `docs: TRA-584 BB16 W2/W3/W4/W5/C1 quickstart + resource-identifiers sweep`
- Body: per-finding bullets summarizing the design doc's table.

## Out of scope

Same as the design doc: no spec or service changes; no W1 (TRA-590); no path-param renames (TRA-586); no schema rename of integer `id`.

## Risks

- **Anchor `#orgs-me` lookup.** The design relies on the existing `private-endpoints.md` `{#orgs-me}` anchor. Confirmed present at line 37 of that file pre-edit.
- **Markdown table rendering.** The W4 edit changes a table cell. Double-check Docusaurus renders the new pipe-aligned row cleanly via `pnpm build` rather than just eyeballing the source.
- **Spec drift.** TRA-585 brought the spec to `platform@b1c952f`. If anyone refreshes the spec mid-PR, the W4 claim about `description` being optional is anchored to that SHA. If the platform later marks `description` required, the doc is wrong. Mitigation: link the design doc's verification snippet so future spec refreshes can re-check the assumption against the new spec.
