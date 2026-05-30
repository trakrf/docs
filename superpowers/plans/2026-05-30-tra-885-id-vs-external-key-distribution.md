# TRA-885 — `id` vs `external_key` Implementation Plan

> **For agentic workers:** Consumer-docs prose change across three files. No unit-test harness for
> docs; verification is `pnpm build` (Redocusaurus + broken-link check) plus a read-through
> against the spec. Source of truth: bb-253 round-2.5 §0 convergence + Mike's in-session
> confirmation (the TRA-885 ticket is stale).

**Goal:** State the identifier contract precisely — surrogate `id` is globally unique / opaque /
permanent (never reused); `external_key` auto-mint is `MAX(live key) + 1` (permanent middle-delete
gaps, only highest-freed reused) — and remove the stale "randomly distributed" and "lowest unused
slot / gap-filling" wording.

**Architecture:** Three files. id-format.md (field-name the distribution claim + a distinction
note); resource-identifiers.md (globally-unique `id` framing + MAX+1 auto-mint mechanism);
changelog.md (new entry + fix two stale "lowest unused slot" assertions). No structural change.

**Tech Stack:** Docusaurus, Markdown, Redocusaurus, pnpm.

---

## Constraints

- `id`: globally unique across all resource types, opaque, permanent, **never reused** (no hard
  delete; single shared id sequence never reseeded). Gated: PR does not merge until TRA-886 is
  prod-live + Mike's diff approval.
- `external_key`: `MAX(live key) + 1`, zero-padded `ASSET-%04d` / `LOC-%03d`; permanent
  middle-delete gaps; only the current highest live key's number is freed for re-issue; separate
  caller-resupply path for soft-deleted key strings. Keep "non-monotonic / not a Postgres
  sequence"; drop "lowest unused slot," "gap-filling," "recyclable-implies-refill."
- Docs-only.

## Task 1 — `docs/api/id-format.md` ✅

- Replaced the standalone "randomly distributed" sentence (`:26`) with the field-named `id`
  framing (high-entropy, globally unique, opaque, permanent/never-reused).
- Added a `:::note` pinning `id` ≠ `external_key`, cross-linking the auto-mint section.

## Task 2 — `docs/api/resource-identifiers.md` ✅

- "Numeric `id` is a surrogate key" para: per-type-scoping → globally unique / opaque / permanent;
  use `id` as durable FK.
- Auto-mint section: replaced the "lowest unused slot among live rows" paragraph with the `MAX(live
  key) + 1` mechanism (permanent gaps, highest-freed reused, zero-padding), plus the contrast to
  the never-reused `id`.
- System-of-record note: "may recycle a slot" → "not a stable reference; `MAX+1` can re-issue a
  deleted top-of-range number."

## Task 3 — `docs/api/changelog.md` ✅

- New top entry: `id` globally unique/opaque/permanent (tied to single shared sequence) +
  `external_key` `MAX+1` correction.
- Fixed the LOC-NNN-finalize entry and the BB52 non-monotonic-wording entry: "lowest unused slot"
  → `MAX(live key) + 1`.

## Task 4 — Verify & commit

- [ ] `pnpm build` passes (Redocusaurus + broken-link check; new anchors resolve).
- [ ] Read-through: no "randomly distributed" standalone; no "lowest unused slot / gap-filling"
      except where quoted-as-corrected in the new changelog entry; every claim names its field.
- [ ] Commit; open PR; **hold for Mike's diff review** (no merge until TRA-886 prod-live).
