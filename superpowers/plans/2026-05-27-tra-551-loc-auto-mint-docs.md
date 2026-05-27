# TRA-551 — location auto-mint docs (LOC-NNN finalization) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the public docs (`docs/api/*`) to match the finalized location `external_key` auto-mint format shipped in platform PR #418 — `LOC-NNN` (3 digits, first mint `LOC-001`), narrower than `ASSET-NNNN` (4 digits) by deliberate triage decision because locations are typically named-and-known artifacts where auto-mint is the exception, not the norm.

**Architecture:** Surgical edit pass across four pages — `resource-identifiers.md`, `errors.md`, `date-fields.md`, `changelog.md`. The auto-mint section on `resource-identifiers.md` is the load-bearing surface and gains a one-sentence asymmetry-rationale note plus the digit-count-agnostic clarification (the namespace pattern accommodates `LOC-1000+` once the 3-digit space is exhausted; the `^LOC-\d{3,}$` pattern that the backend tests against is the contract, not strict 3-digit width). The other three pages are find-and-replace of the literal `LOC-NNNN` / `LOC-0001` strings. New changelog entry sits under `## v1.0 — Launch (TBD)`, peer to the other unlabeled launch-window entries (no BB-cycle prefix; this is closing out a previously-shipped item, not a BB-cycle ship). No Linear ticket identifiers appear in user-facing copy.

**Tech Stack:** Docusaurus 3, MDX/Markdown only — no code changes. Validate with `pnpm build` and `pnpm typecheck`.

---

## File Structure

Modified files (no creates, no deletes):

- `docs/api/resource-identifiers.md` — auto-mint section, intro line, code-comment, system-of-record paragraph
- `docs/api/errors.md` — idempotency bullet for `POST /assets`, `POST /locations`
- `docs/api/date-fields.md` — example payload `external_key` values
- `docs/api/changelog.md` — new entry under `## v1.0 — Launch (TBD)`

Plan artifact:

- `superpowers/plans/2026-05-27-tra-551-loc-auto-mint-docs.md` (this file — already created, not part of the work)

---

## Task 1: Update the load-bearing auto-mint section in `resource-identifiers.md`

**Files:**
- Modify: `docs/api/resource-identifiers.md:16` (one inline reference)
- Modify: `docs/api/resource-identifiers.md:485-492` (auto-mint intro paragraph + table + recycle note)
- Modify: `docs/api/resource-identifiers.md:509` (bash code-comment)
- Modify: `docs/api/resource-identifiers.md:521` (system-of-record paragraph)

- [ ] **Step 1: Edit line 16 — change the namespace pair in the intro**

Replace:

```
Both are write-routable: caller-supplied on create, or server-minted from a per-organization `ASSET-NNNN` / `LOC-NNNN` namespace when `external_key` is omitted — see [auto-mint behavior](#external_key-is-optional-on-create).
```

with:

```
Both are write-routable: caller-supplied on create, or server-minted from a per-organization `ASSET-NNNN` / `LOC-NNN` namespace when `external_key` is omitted — see [auto-mint behavior](#external_key-is-optional-on-create).
```

- [ ] **Step 2: Edit line 485 — the prose lead-in for the auto-mint table**

Replace:

```
`external_key` is **optional on `POST` for assets and locations alike**. Supply your own value to anchor the row to a partner-side handle (a SKU, an ERP code, an operator-typed location label, a row from a planned-layout export), or omit the field on the request body and the server assigns the lowest unused slot in the per-organization `ASSET-NNNN` / `LOC-NNNN` namespace. Each resource type has its own format and its own namespace:
```

with:

```
`external_key` is **optional on `POST` for assets and locations alike**. Supply your own value to anchor the row to a partner-side handle (a SKU, an ERP code, an operator-typed location label, a row from a planned-layout export), or omit the field on the request body and the server assigns the lowest unused slot in the per-organization `ASSET-NNNN` / `LOC-NNN` namespace. Each resource type has its own format and its own namespace:
```

- [ ] **Step 3: Edit the resource table (line 490) + add asymmetry note immediately after**

Replace the existing table:

```
| Resource | Auto-minted format | Namespace scope  |
| -------- | ------------------ | ---------------- |
| Asset    | `ASSET-NNNN`       | per-organization |
| Location | `LOC-NNNN`         | per-organization |
```

with:

```
| Resource | Auto-minted format | Namespace scope  |
| -------- | ------------------ | ---------------- |
| Asset    | `ASSET-NNNN`       | per-organization |
| Location | `LOC-NNN`          | per-organization |

The location format is intentionally narrower than the asset format — locations are typically named-and-known artifacts (warehouse rooms, dock doors, zones) for which the partner-side handle already exists in facilities documentation, so auto-mint is the exception rather than the norm and a 3-digit slot suffices for the typical "ad-hoc-from-the-SPA" volume. Both formats are digit-count-agnostic on the read side: the auto-mint contract is "fixed prefix, decimal slot," not "fixed total width." Once the 3-digit space is exhausted the next mint is `LOC-1000`, then `LOC-1001`, with no migration or zero-pad reflow; the same property holds for `ASSET-NNNN` past `ASSET-9999`. Don't anchor client-side parsing on `\d{3}` or `\d{4}` strictness — match `^LOC-\d{3,}$` / `^ASSET-\d{4,}$` (or, more durably, ignore the slot count and treat the value as opaque).
```

- [ ] **Step 4: Edit line 509 — the bash example comment**

Replace:

```
# Same shape on locations — omit external_key to receive a LOC-NNNN value
```

with:

```
# Same shape on locations — omit external_key to receive a LOC-NNN value
```

- [ ] **Step 5: Edit line 521 — system-of-record paragraph**

Replace:

```
**When integrating with a system of record (an ERP, a WMS, a partner database, a layout / floor-plan tool), supply the partner-side handle on create** — don't rely on the auto-mint. Auto-minted `ASSET-NNNN` / `LOC-NNNN` values are per-organization-unique among live rows but they won't join cleanly to a SKU, a facility code, an ERP location, or any other handle a downstream system already uses, and they may recycle a slot vacated by a soft-deleted row (see the namespace note above) — neither property is what a partner-side audit log expects from an `id`-shaped identifier.
```

with:

```
**When integrating with a system of record (an ERP, a WMS, a partner database, a layout / floor-plan tool), supply the partner-side handle on create** — don't rely on the auto-mint. Auto-minted `ASSET-NNNN` / `LOC-NNN` values are per-organization-unique among live rows but they won't join cleanly to a SKU, a facility code, an ERP location, or any other handle a downstream system already uses, and they may recycle a slot vacated by a soft-deleted row (see the namespace note above) — neither property is what a partner-side audit log expects from an `id`-shaped identifier.
```

- [ ] **Step 6: Verify no stale `LOC-NNNN` strings remain in the file**

Run: `grep -n "LOC-NNNN" docs/api/resource-identifiers.md`
Expected: no output (exit 1).

- [ ] **Step 7: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(api): finalize location auto-mint format to LOC-NNN

Aligns the resource-identifiers page with the location external_key
auto-mint format shipped server-side: LOC-NNN (3 digits, first mint
LOC-001) instead of LOC-NNNN (4 digits). Adds a paragraph after the
auto-mint table explaining the asset/location asymmetry — locations are
typically named-and-known artifacts so a 3-digit slot suffices for the
typical ad-hoc volume — and notes that both formats are digit-count-
agnostic past the natural width (LOC-1000+, ASSET-10000+) so client
parsers should match \\\\d{3,} / \\\\d{4,} rather than fixed widths."
```

---

## Task 2: Update the idempotency reference in `errors.md`

**Files:**
- Modify: `docs/api/errors.md:327`

- [ ] **Step 1: Edit line 327**

Replace:

```
- **`POST /assets`, `POST /locations`** — retrying with the same `external_key` hits the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` and returns `409 conflict`. Detect the 409, then `GET /api/v1/{resource}?external_key=...` and read `.data[0].id` to recover the canonical `id`, then `PATCH` to reconcile. **If you omit `external_key` on a retry, you may create duplicates** — the server will mint a fresh value (`ASSET-NNNN` for assets, `LOC-NNNN` for locations) on each attempt. For retry-critical workflows, always supply an `external_key`.
```

with:

```
- **`POST /assets`, `POST /locations`** — retrying with the same `external_key` hits the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` and returns `409 conflict`. Detect the 409, then `GET /api/v1/{resource}?external_key=...` and read `.data[0].id` to recover the canonical `id`, then `PATCH` to reconcile. **If you omit `external_key` on a retry, you may create duplicates** — the server will mint a fresh value (`ASSET-NNNN` for assets, `LOC-NNN` for locations) on each attempt. For retry-critical workflows, always supply an `external_key`.
```

- [ ] **Step 2: Verify**

Run: `grep -n "LOC-NNNN" docs/api/errors.md`
Expected: no output (exit 1).

- [ ] **Step 3: Commit**

```bash
git add docs/api/errors.md
git commit -m "docs(api): use LOC-NNN in idempotency retry-mint reference

The auto-mint format for locations is LOC-NNN (3 digits), not LOC-NNNN.
Matches resource-identifiers.md."
```

---

## Task 3: Update the example payload in `date-fields.md`

**Files:**
- Modify: `docs/api/date-fields.md:35` (one example), `docs/api/date-fields.md:42` (second example)

- [ ] **Step 1: Edit line 35**

Replace:

```
      "external_key": "LOC-0001",
```

with:

```
      "external_key": "LOC-001",
```

- [ ] **Step 2: Edit line 42**

Replace:

```
      "external_key": "LOC-0002",
```

with:

```
      "external_key": "LOC-002",
```

- [ ] **Step 3: Verify**

Run: `grep -n "LOC-0001\|LOC-0002" docs/api/date-fields.md`
Expected: no output (exit 1).

- [ ] **Step 4: Commit**

```bash
git add docs/api/date-fields.md
git commit -m "docs(api): use LOC-001/LOC-002 in date-fields outbound example

Match the LOC-NNN (3 digit) location external_key format."
```

---

## Task 4: Add a changelog entry under `## v1.0 — Launch (TBD)`

**Files:**
- Modify: `docs/api/changelog.md` — insert a new `###` section immediately after `## v1.0 — Launch (TBD)` (line 10) and the section's intro paragraph (line 12), so the new entry sits above the existing "Tag rows cascade-soft-delete with their parent asset or location" entry. Pre-launch wave entries are unordered narratively; placing the newest at the top of the v1.0 section matches the existing pattern (the cascade entry is itself the most recent pre-launch ship).

- [ ] **Step 1: Read existing changelog lines 10-25 to confirm anchor for insert**

Run: `sed -n '10,25p' docs/api/changelog.md`
Expected: line 10 is `## v1.0 — Launch (TBD)`, line 12 is the intro paragraph "Initial public API release. Stable contract for paths, field names, response shapes, and error envelopes per the [v1 stability commitment](./versioning).", line 14 is `### Tag rows cascade-soft-delete with their parent asset or location`.

- [ ] **Step 2: Insert the new entry above the cascade entry**

Use Edit with `old_string` containing the cascade-entry header and `new_string` containing the new entry followed by the cascade-entry header.

`old_string`:

```
### Tag rows cascade-soft-delete with their parent asset or location
```

`new_string`:

```
### Location `external_key` auto-mint finalized to `LOC-NNN`

The location auto-mint format is `LOC-NNN` (3 digits, first mint `LOC-001` in a fresh organization), parallel to but intentionally narrower than `ASSET-NNNN`. The asymmetry reflects how the two resources are used in practice: assets accumulate ad-hoc creates without a pre-known partner-side handle (a quick scan-in from the SPA, a row pasted in from a CSV with no upstream SKU), while locations are typically named-and-known artifacts already documented in a facilities export, so auto-mint is the exception rather than the norm and the smaller slot suffices for the typical volume. Pre-launch correction; the [Resource identifiers](./resource-identifiers#external_key-is-optional-on-create) page previously described the location format as `LOC-NNNN` from the prior interim plumbing — no `v1.0.0`-or-later wire baseline to break.

- **Format and first mint.** Auto-mint produces `LOC-001` for the first omit-on-create in a fresh organization, then `LOC-002`, `LOC-003`, and so on, governed by the same "lowest unused slot among live rows" rule the [recycle paragraph on Resource identifiers](./resource-identifiers#external_key-is-optional-on-create) already documented for both resources. Soft-deleting the live row holding `LOC-005` makes that slot eligible for the next mint while soft-deleted rows can still hold the value; the partial unique index `(org_id, external_key) WHERE deleted_at IS NULL` is the system of record for "what slots are live."
- **Digit-count-agnostic past the natural width.** The `LOC-NNN` shape is the shape of the typical mint, not a width constraint on the value. Once the 3-digit space is exhausted in an organization the next mint is `LOC-1000`, then `LOC-1001`, with no migration or zero-pad reflow; the same property holds for `ASSET-NNNN` past `ASSET-9999`. Client-side parsers should match `^LOC-\d{3,}$` / `^ASSET-\d{4,}$` (or, more durably, treat the value as opaque) rather than anchoring on fixed-width digit groups. The new paragraph adjacent to the [auto-mint table](./resource-identifiers#external_key-is-optional-on-create) spells this out so a code generator emitting a strict-width validator doesn't reject a legitimately-minted `LOC-1042` after the 1000th create.
- **System-of-record guidance unchanged.** The load-bearing recommendation (supply the partner-side handle on create when integrating with an ERP / WMS / floor-plan tool — don't rely on the auto-mint) carries over verbatim; the auto-mint is the right call only for ad-hoc creates where no upstream handle yet exists. The recycle property and the namespace-shaped rather than counter-shaped wording from the [prior changelog entry on non-monotonic auto-mint](#bb52-docs--validation_error-vs-bad_request-envelope-split-non-monotonic-auto-mint-wording) both apply unchanged to the narrower location format.

### Tag rows cascade-soft-delete with their parent asset or location
```

- [ ] **Step 3: Verify the entry inserted cleanly and the file still parses**

Run: `grep -n "^### " docs/api/changelog.md | head -5`
Expected: the first `### ` line is `### Location \`external_key\` auto-mint finalized to \`LOC-NNN\``, the second is `### Tag rows cascade-soft-delete with their parent asset or location`.

Run: `grep -c "LOC-NNNN" docs/api/changelog.md`
Expected: `1` — the single legacy mention in the BB52 paragraph at line 120 stays as-is (it is a historical reference to what the page previously said about both resources sharing the `ASSET-NNNN` / `LOC-NNNN` shape, accurate at the time the entry was written, and replacing it would rewrite history). The new entry above supersedes it for the location format.

- [ ] **Step 4: Commit**

```bash
git add docs/api/changelog.md
git commit -m "docs(api): changelog entry for LOC-NNN auto-mint finalization

Documents the 3-digit location auto-mint format and the deliberate
asymmetry with ASSET-NNNN. Pre-launch correction superseding the
previously-documented LOC-NNNN format."
```

---

## Task 5: Build and link-check the docs site

**Files:** None modified.

- [ ] **Step 1: Run typecheck**

Run: `pnpm typecheck`
Expected: clean exit, no TypeScript errors.

- [ ] **Step 2: Run lint**

Run: `pnpm lint`
Expected: clean exit (or no new findings beyond the pre-existing baseline).

- [ ] **Step 3: Run production build**

Run: `pnpm build`
Expected: clean exit; Docusaurus reports no broken links and no MDX compile errors. In particular the new in-page anchor `#external_key-is-optional-on-create` referenced from the changelog entry must resolve (it already exists in `resource-identifiers.md:483`).

- [ ] **Step 4: Spot-check no stale `LOC-NNNN` or `LOC-0001`/`LOC-0002` remain anywhere in docs**

Run: `grep -rn "LOC-NNNN\|LOC-0001\|LOC-0002" docs/`
Expected: a single hit on the BB52 historical paragraph in `docs/api/changelog.md` (preserved deliberately per Task 4 step 3); no hits anywhere else.

- [ ] **Step 5: Final summary commit (skip if no untracked artifacts)**

If `git status` is clean, this task is complete with no additional commit. Do not amend prior commits.

---

## Task 6: Open the docs PR against `main`

**Files:** None modified.

- [ ] **Step 1: Push the branch**

Run: `git push -u origin docs/tra-551-loc-auto-mint`

- [ ] **Step 2: Open the PR with `gh pr create`**

Run:

```bash
gh pr create --base main --title "docs(api): finalize location external_key auto-mint to LOC-NNN" --body "$(cat <<'EOF'
## Summary

Docs follow-on to platform PR trakrf/platform#418. The location `external_key` auto-mint format shipped as `LOC-NNN` (3 digits, first mint `LOC-001`), narrower than `ASSET-NNNN` (4 digits) by deliberate triage decision — locations are typically named-and-known artifacts (warehouse rooms, dock doors, zones) where auto-mint is the exception rather than the norm.

- `docs/api/resource-identifiers.md` — auto-mint table updated; new paragraph after the table explains the asset/location asymmetry rationale and the digit-count-agnostic property of both formats (past the natural width — `LOC-1000+`, `ASSET-10000+` — the pattern continues without zero-pad reflow, so client parsers should match `^LOC-\d{3,}$` / `^ASSET-\d{4,}$` rather than fixed-width groups).
- `docs/api/errors.md` — the retry-mint reference in the `POST /assets`, `POST /locations` idempotency bullet now reads `LOC-NNN`.
- `docs/api/date-fields.md` — outbound example payload uses `LOC-001` / `LOC-002`.
- `docs/api/changelog.md` — new entry under `## v1.0 — Launch (TBD)` documenting the finalization. No Linear identifiers in user-facing copy.

The BB52 historical paragraph in the changelog that mentions the previously-documented `LOC-NNNN` shape is preserved as-written — replacing it would rewrite history. The new entry above supersedes it for the current format.

## Test plan

- [x] `pnpm typecheck` — clean
- [x] `pnpm lint` — clean
- [x] `pnpm build` — clean, no broken links, MDX compiles
- [ ] Visual spot-check of the rendered auto-mint section once the preview deploy is up — confirm the new paragraph reads cleanly after the table and the in-page anchor from the changelog entry resolves
- [ ] Merge gated on platform PR #418 reaching preview (per project convention "docs ship behind preview, not prod")

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Note the PR URL for the user**

Capture stdout from the `gh pr create` invocation and surface the URL in the session summary.
