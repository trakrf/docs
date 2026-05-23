# TRA-816 Tag-Cascade Docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document the soft-delete-cascade-to-tags fix shipped in platform PR #397 — one new changelog entry plus one tightening sentence in the resource-identifiers Tag CRUD section.

**Architecture:** Two text-only edits in `docs/api/`. No spec, no schema, no new field. Each edit anchors on existing prose; both are pre-launch, no `v1.0.0`-baseline break.

**Tech Stack:** Docusaurus (markdown / MDX), pnpm.

---

### Task 1: Add Tag CRUD cascade sentence to resource-identifiers.md

**Files:**

- Modify: `docs/api/resource-identifiers.md` (Tag CRUD section, around line 647, between the "Tag writes use the parent resource's write scope" paragraph and the "The same endpoint accepts all three kinds" paragraph)

- [ ] **Step 1: Read the surrounding prose to confirm exact line context**

Run: `grep -n "Tag writes use the parent\|The same endpoint accepts all three kinds\|Tag CRUD" docs/api/resource-identifiers.md`
Expected: shows `### Tag CRUD {#tag-crud}` heading, the `Tag writes use the parent…` line, and the `The same endpoint accepts all three kinds…` line in adjacent positions.

- [ ] **Step 2: Insert the cascade sentence**

Use Edit tool on `docs/api/resource-identifiers.md`.

`old_string`:

```
Tag writes use the parent resource's write scope, not a separate `tags:write` — there is no per-tag scope.

The same endpoint accepts all three kinds — the discriminator travels in the body:
```

`new_string`:

```
Tag writes use the parent resource's write scope, not a separate `tags:write` — there is no per-tag scope.

Soft-deleting a parent asset or location cascades to its attached tag rows in the same transaction with the same `deleted_at`, releasing the `(org_id, tag_type, value)` natural-key slot for immediate reattachment on another entity in the same organization. The cascaded tag rows follow the same [soft-delete visibility](#soft-delete-visibility) rules as their parent — hidden by default on the parent's read shape, surfaceable through `?include_deleted=true` on list surfaces that accept it.

The same endpoint accepts all three kinds — the discriminator travels in the body:
```

- [ ] **Step 3: Verify the anchor `#soft-delete-visibility` exists on the page**

Run: `grep -n '#soft-delete-visibility' docs/api/resource-identifiers.md`
Expected: at least two hits — the heading definition (`### Soft-delete visibility on lists {#soft-delete-visibility}`) and one or more existing cross-links.

- [ ] **Step 4: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "$(cat <<'EOF'
docs(api): TRA-816 — note parent soft-delete cascades to attached tag rows

One sentence added to the Tag CRUD section: when a parent asset or
location is soft-deleted, its attached tag rows are soft-deleted in the
same transaction with the same deleted_at, so the (org_id, tag_type,
value) natural-key slot is released for immediate reattachment on
another entity in the same org. Cross-links the existing soft-delete
visibility section for the read-side counterpart.
EOF
)"
```

---

### Task 2: Add changelog entry for the cascade fix

**Files:**

- Modify: `docs/api/changelog.md` (top of `## v1.0 — Launch (TBD)` section, above `### BB1 hygiene` at line 14)

- [ ] **Step 1: Confirm the BB1 hygiene heading is still at line 14**

Run: `grep -n "^### BB1 hygiene\|^### Asset current location" docs/api/changelog.md | head -5`
Expected: `### BB1 hygiene` appears as the first entry under `## v1.0 — Launch (TBD)`; `### Asset current location removed from the asset resource` appears immediately below it.

- [ ] **Step 2: Insert the new entry above the BB1 hygiene one**

Use Edit tool on `docs/api/changelog.md`.

`old_string`:

```
Initial public API release. Stable contract for paths, field names, response shapes, and error envelopes per the [v1 stability commitment](./versioning).

### BB1 hygiene — Try-it wording dropped, `invalid_context` added to versioning open-enums list, `datamodel-codegen` version string unmangled
```

`new_string`:

```
Initial public API release. Stable contract for paths, field names, response shapes, and error envelopes per the [v1 stability commitment](./versioning).

### Tag rows cascade-soft-delete with their parent asset or location

Soft-deleting an asset or location now cascades to the attached tag rows in the same transaction with the same `deleted_at`, releasing the `(org_id, tag_type, value)` partial-unique slot the tag was holding. Brings runtime behavior in line with the existing [Tags use a composite natural key](./resource-identifiers#tags-use-a-composite-natural-key) contract — the page documented that soft-delete frees the natural-key handle for reuse, the platform was leaving orphan tag rows live and blocking reuse. Pre-launch fix; no `v1.0.0`-or-later wire baseline to break.

- **Cascade on parent soft-delete.** `DELETE /api/v1/assets/{asset_id}` and `DELETE /api/v1/locations/{location_id}` soft-delete every tag row attached to the parent at the same instant, sharing the parent's `deleted_at`. After the cascade the tag's `(org_id, tag_type, value)` slot is free, and the same value can be attached to another asset or location in the org without a 409. See [Resource identifiers → Tag CRUD](./resource-identifiers#tag-crud) for the prose.
- **One-shot sweep for the existing orphan footprint.** A migration ships in the same release that soft-deletes the pre-fix orphan rows (tag rows whose parent asset or location is already soft-deleted), so the natural-key slots they were occupying are released as part of the deploy. Integrators who saw a `409 conflict` on `POST /api/v1/{resource}/{id}/tags` naming a tag holder they could not see in any list (the `?external_key=...` lookup returned an empty array, the path-param `GET` returned `404 not_found`) can re-try the attach after the deploy.
- **Conflict 409 detail does not leak hidden entity names.** Defence-in-depth: the server-side conflict lookup that builds the `409 conflict` detail string now filters soft-deleted parents on the join, so any future regression where an orphan tag row slips through returns the generic 409 (`detail: "tag <type>:<value> already exists"`, per the [errors page](./errors#error-type-catalog)) rather than naming a parent the caller has no way to address. The cascade above closes the path that produced these messages; the join filter ensures the message shape stays correct if a new code path ever reintroduces the bug.
```

- [ ] **Step 3: Verify the changelog still parses (no broken anchors, no duplicated headings)**

Run: `grep -nE "^### " docs/api/changelog.md | head -10`
Expected: the new `### Tag rows cascade-soft-delete with their parent asset or location` is the first entry; `### BB1 hygiene` is second; `### Asset current location removed from the asset resource` is third.

- [ ] **Step 4: Commit**

```bash
git add docs/api/changelog.md
git commit -m "$(cat <<'EOF'
docs(api): TRA-816 — changelog entry for tag-cascade soft-delete fix

New entry under v1.0 Launch: parent soft-delete now cascades to
attached tag rows, the existing orphan footprint is swept by the
release migration, and the conflict-detail join filter ensures
soft-deleted parent names cannot leak into 409 detail strings. Frames
the fix as bringing runtime in line with the existing
soft-delete-frees-the-handle contract on the Tag CRUD page.
EOF
)"
```

---

### Task 3: Build verification

**Files:**

- None (read-only verification)

- [ ] **Step 1: Run the Docusaurus production build**

Run: `pnpm build 2>&1 | tail -30`
Expected: build completes with `[SUCCESS]` line; no `Error:` lines; no broken internal links flagged on `resource-identifiers` or `changelog`.

- [ ] **Step 2: Sanity-grep the edits**

Run: `grep -nE 'cascade|orphan' docs/api/changelog.md docs/api/resource-identifiers.md`
Expected: the new cascade-related hits appear in `changelog.md` (the new entry) and `resource-identifiers.md` (the new Tag CRUD sentence). No pre-existing prose contradicts them.

- [ ] **Step 3: Confirm no stale references**

Run: `grep -nE 'soft.?delete.*tag|tag.*soft.?delete' docs/api/*.md docs/api/*.mdx | grep -v changelog.md | grep -v resource-identifiers.md | head -20`
Expected: no hits that describe the *old* (orphan-leaking) behavior. Hits that document the general soft-delete contract for assets and locations are fine.

---

### Task 4: Push branch and open PR

**Files:**

- None (git + gh)

- [ ] **Step 1: Push the branch**

Run: `git push -u origin docs/tra-816-tag-cascade`
Expected: branch created on origin, no errors.

- [ ] **Step 2: Open the PR**

Run:

```bash
gh pr create --title "docs(api): TRA-816 — tag-cascade soft-delete docs" --body "$(cat <<'EOF'
## Summary

Docs companion to platform PR #397 (TRA-816, merged). Narrow scope:

- New changelog entry under `## v1.0 — Launch (TBD)` describing the parent-soft-delete cascade to attached tags, the one-shot sweep migration, and the conflict-detail join filter.
- One sentence added to `docs/api/resource-identifiers.md` Tag CRUD section noting the cascade and cross-linking the existing soft-delete visibility paragraph.

The documented contract on the Tag CRUD page already said the natural-key slot is freed on soft-delete; the platform was failing to match that on the parent-cascade path. These edits close the inference gap and log the fix.

Closes [TRA-816](https://linear.app/trakrf/issue/TRA-816).

## Test plan

- [x] `pnpm build` succeeds with no broken internal links.
- [x] `git grep` audit: no stale prose contradicts the new cascade contract.
- [ ] Reviewer eyes on the changelog phrasing and the placement of the new Tag CRUD sentence.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed; PR opens in draft-or-ready state per repo default.

- [ ] **Step 3: Capture the PR URL**

Echo or note the URL returned by `gh pr create` for the final session summary.
