# TRA-816 — Soft-delete cascades to attached tags

## Origin

Platform PR #397 (TRA-816, merged) fixes a soft-delete cascade bug. When an
asset or location is soft-deleted, the rows in `trakrf.tags` that point to it
are now soft-deleted in the same transaction with the same `deleted_at`.
Previously the tag rows stayed live with their parent id still pointing at the
soft-deleted parent, which kept the `(org_id, tag_type, value) WHERE
deleted_at IS NULL` partial-unique slot occupied — so the tag's natural-key
value could not be reattached to any other entity in the same org. A one-shot
migration sweeps the existing orphan rows (190 on preview at write time → 0).

Two server-side message defences ship alongside the cascade:

1. `lookupTagConflict` now filters soft-deleted parents on the JOIN, so a
   stale orphan that slips through cannot leak a hidden entity's name in the
   `409 conflict` detail string. After the cascade fix this code path is
   unreachable; the filter is defence-in-depth against future orphan
   regressions.
2. Frontend `checkTagConflict` shows a "no longer have access" message when
   the lookup envelope is missing entity context. Frontend-internal; no public
   API surface.

## Scope

This is the **docs-only** companion to platform PR #397. The platform code,
migration, backend cascade, and frontend defences land in PR #397. This repo
carries the prose changes to `docs/api/`. The OpenAPI-driven interactive
reference at `/api` is generated from the spec synced from the platform repo
and updates with that sync — it is **not** hand-edited here.

The fix is **narrow on the public docs surface**. The docs already describe
the intended behavior: `docs/api/resource-identifiers.md` states that natural
keys are enforced by partial unique indexes on `WHERE deleted_at IS NULL`, so
a soft-delete frees the handle for reuse. The platform was not matching that
contract for tags whose parent was soft-deleted; the cascade brings runtime
behavior in line with documented behavior. There is no field-shape change, no
new field, no new endpoint, no new error code.

## Editorial decisions

### Changelog entry

The cascade closes a real integrator-visible inconsistency — a tag's natural
key was not reusable after a parent soft-delete despite the page on tags
claiming it would be. A changelog entry under `## v1.0 — Launch (TBD)` calls
out (a) the cascade as the durable fix, (b) the one-shot sweep migration as
the way the existing orphan footprint is cleared, and (c) the
`lookupTagConflict` defence as the reason an integrator who saw an orphan-
named 409 detail in preview won't see one again. Framed as a pre-launch fix;
no `v1.0.0`-or-later wire baseline to break. Consistent with how prior
"docs-already-said-the-right-thing, platform now matches" entries have been
logged (the BB42 `tag_type` strict-required fix is the nearest precedent).

### Tags-section tightening

`docs/api/resource-identifiers.md` Tag CRUD section (`#tag-crud`, around line
636) lists the four tag write endpoints and their idempotency semantics but
does not state what happens to attached tag rows when the **parent** asset or
location is soft-deleted. The current prose implies the answer through the
general "soft-delete frees the handle for reuse" framing on line 28, but for
tags the answer requires a cascade step that's worth one explicit sentence:
when a parent is soft-deleted, the platform soft-deletes its attached tag
rows in the same transaction with the same `deleted_at`, releasing the
natural-key slot for immediate reattachment on another entity in the same
org. One sentence appended to the Tag CRUD prose below the endpoint table.

### Out of scope: errors.md

The `409 conflict` row in the `docs/api/errors.md` error type catalog (line
80) and the tag-conflict detail-string changelog entry (line 291) already
describe the contract accurately: a duplicate `(tag_type, value)` returns
`409 conflict` with `detail` naming the conflicting `tag` (not "identifier").
The orphan-named detail string the platform was emitting on the buggy path is
not, and was never, the documented contract — it was a leak from a JOIN that
forgot to filter `deleted_at`. The cascade plus the `lookupTagConflict` JOIN
fix bring the runtime back to the documented shape; no errors.md edit
follows.

### Out of scope: data-model.md, design-notes.md

Neither page describes tag-parent cascade behavior. Adding the concept here
would be net-new prose not anchored in the current page's framing — the tag
cascade fits the resource-identifiers Tag CRUD section, which already covers
tag write semantics. Leave both pages alone.

### Out of scope: frontend conflict UX

The `checkTagConflict` fallback message change is frontend-internal — it
affects the TrakRF web app's conflict toast, not any wire-level shape an API
integrator would see. The trakrf-docs site documents the public API surface;
the web app's UI prose is out of scope here.

## Per-file changes

### `docs/api/changelog.md`

Add one entry at the top of `## v1.0 — Launch (TBD)`, above the existing
`### BB1 hygiene` entry. Title: `Tag rows cascade-soft-delete with their
parent asset/location`. Body: one short framing paragraph + 2-3 bullets. The
bullets cover:

- The cascade itself: parent soft-delete soft-deletes attached tag rows in
  the same transaction with the same `deleted_at`. Cross-link to
  [Resource identifiers → Tag CRUD](./resource-identifiers#tag-crud) where
  the behavior is documented in prose.
- The one-shot sweep migration: existing orphans are cleared as part of the
  fix, so the natural-key slots they were occupying are released. Integrators
  on preview who saw a "tag already exists" 409 naming an entity they could
  not see in any list can re-try the attach.
- The `409 conflict` detail string: after the cascade the orphan-name leak
  path is unreachable; a defence-in-depth JOIN filter in
  `lookupTagConflict` ensures any future regression returns the generic 409
  rather than naming a hidden entity. No documented detail-string shape
  changes — the contract on the [errors page](./errors#error-type-catalog)
  was already the post-fix shape.

Framing line: pre-launch fix; brings runtime in line with the existing
[partial-unique-on-`WHERE deleted_at IS NULL`](./resource-identifiers#tag-crud)
contract for tags.

### `docs/api/resource-identifiers.md`

One sentence added to the Tag CRUD section (`#tag-crud`), placed after the
endpoint table and the "Tag writes use the parent resource's write scope"
sentence (around line 647), before the `# Attach an RFID tag...` curl block.
Substance: when a parent asset or location is soft-deleted, attached tag rows
are soft-deleted in the same transaction with the same `deleted_at`, so the
`(org_id, tag_type, value)` slot is released for immediate reattachment on
another entity in the same organization. Cross-link to the
`include_deleted=true` paragraph on [Soft-delete visibility on lists](#soft-delete-visibility)
for the read-side counterpart (a soft-deleted tag is hidden from parent
read shapes by default and appears under `?include_deleted=true` on list
surfaces that accept it).

## Out of scope

- Frontend `checkTagConflict` fallback prose — web-app UI, not API docs.
- Spec / `static/api/openapi.{json,yaml}` edits — no schema, response, or
  error envelope change.
- `docs/api/data-model.md`, `docs/api/design-notes.md` — neither currently
  describes tag-parent cascade; no targeted improvement that serves this fix.
- `docs/api/errors.md` — the documented 409 shape is already the post-fix
  shape; the buggy detail-string variant was never the contract.
- A `BB`-numbered hygiene label — TRA-816 was surfaced incidentally while
  setting up the TRA-812 partial-failure walk, not from a black-box cycle
  finding. The changelog entry uses a descriptive heading, matching how
  TRA-799 ("Asset current location removed from the asset resource") was
  logged.

## Verification

- `pnpm build` succeeds (Docusaurus build catches broken internal links and
  anchors).
- `git grep -nE 'cascade|orphan|soft.delete' docs/api/` — every new hit is
  the new changelog entry or the new Tag CRUD sentence; no stale wording
  contradicts the cascade contract.
- The new Tag CRUD sentence references an existing anchor
  (`#soft-delete-visibility`); the build link-check verifies it resolves.

## Acceptance

- [ ] Changelog entry added at the top of `## v1.0 — Launch (TBD)`, above
      the `### BB1 hygiene` entry, with the cascade + sweep + 409-defence
      bullets and the cross-link to Tag CRUD.
- [ ] One sentence added to `docs/api/resource-identifiers.md` Tag CRUD
      section stating that parent soft-delete cascades to attached tag rows,
      with a cross-link to the `Soft-delete visibility on lists` paragraph.
- [ ] No other `docs/api/*.md` or `*.mdx` file edited.
- [ ] `pnpm build` passes; `git grep` audit clean.
- [ ] PR opened on `docs/tra-816-tag-cascade` against `main`, conventional-
      commit titles, links to TRA-816 in the PR body (not in public docs).
