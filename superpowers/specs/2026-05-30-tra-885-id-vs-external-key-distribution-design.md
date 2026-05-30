---
title: TRA-885 — Distinguish distributed surrogate id from sequential external_key
date: 2026-05-30
ticket: TRA-885
status: draft
---

# TRA-885 — Distinguish the distributed surrogate `id` from the dense `external_key`

## Problem

The id-format prose says "The TrakRF id namespace is **randomly distributed** across a
wide range." That is true of the surrogate `id` (int64, high-entropy, scattered across the
range) but the sentence never names the field, so the "randomly distributed" claim silently
carries onto `external_key` — which is deliberately *not* random. `external_key` is a
per-organization, dense, low-valued auto-mint (`ASSET-NNNN` / `LOC-NNN`) that fills the
lowest unused slot.

This blur produced a false contract finding in round 2.4/2.5: one track read a dense,
sequential-looking `external_key` (e.g. `LOC-004`) as evidence of a sequential *surrogate-id*
allocator, when the same object carried `id` `2667778952943111` (sparse, scattered). The two
identifiers have opposite allocation semantics on the same row.

## Goal

Make the two identifier tiers unambiguous in consumer docs:

- Never describe "the id" as randomly distributed without naming the field.
- State explicitly: surrogate `id` is a high-entropy key distributed across the range;
  `external_key` is a per-org, dense, gap-filling auto-mint (lowest unused slot).
- Make clear `external_key` ordering is **not random**, and a dense / low-valued
  `external_key` does **not** imply a sequential `id` allocator.

## Scope boundary

- Docs-only, consumer-facing.
- Scoped to the `id`-vs-`external_key` allocation distinction.
- **No** claim about cross-type `id` uniqueness either way — TRA-886 moves surrogate ids to a
  single shared sequence (globally unique ids), so per-type-uniqueness language would be stale
  on arrival.
- Do not reintroduce the word "sequence"/"sequential" for `external_key` in a way that implies
  Postgres-`nextval`-style monotonic allocation — changelog.md:152 deliberately replaced
  "per-organization sequence" with non-monotonic, lowest-unused-slot wording. The fix
  preserves that: the contrast is **entropy** (scattered vs dense), not monotonicity.

## Approach

Two surgical prose edits. No new sections, no structural change.

### Edit 1 — `docs/api/id-format.md` (the load-bearing fix)

The sentence at the top of "Why int64, and why the 2⁵³−1 cap":

> The TrakRF id namespace is randomly distributed across a wide range, not monotonically
> assigned from `1`.

Rewrite to (a) name the field — this is about the **surrogate `id`** — and (b) draw the
explicit contrast with `external_key` so a reader can't carry the "random" property across.
Add a one-line clarification that `external_key`'s dense, low-valued ordering is a different
tier and does not describe `id`.

### Edit 2 — `docs/api/resource-identifiers.md`, "Numeric `id` is a surrogate key" section

This is the natural home for the contrast on the read side. Add a sentence distinguishing the
two tiers: `id` is high-entropy and scattered across the int64 range; `external_key` is the
per-org dense auto-mint documented under auto-mint, and a dense `external_key` does not imply
a sequential `id` allocator. Cross-link the auto-mint section already on the page.

### Not touched

- `docs/api/versioning.md` — does not repeat the "randomly distributed" claim; nothing to fix.
- The `external_key` auto-mint section — already precise ("lowest unused slot among live rows,"
  non-monotonic, recyclable). No change needed; Edit 2 cross-links to it.

## Prose source

Operator-confirmed wording requested from cc2cc agent **bb-253** (round 2.5 bb-251/252/253
convergence participant). Final wording reconciles the ticket's "sequential" framing with the
changelog.md:152 non-monotonic stance — characterizing `external_key` as **dense / low-valued /
gap-filling**, contrasted against the **high-entropy / scattered** `id`, without resurrecting
the monotonic-counter implication.

## Verification

- `pnpm build` passes (Redocusaurus + broken-link check).
- Manual read-through: no remaining unqualified "the id is randomly distributed" sentence;
  every distribution claim names its field; no cross-type uniqueness language introduced.

## Evidence (from ticket)

Corroborated live on BB2 (`LOC-004`/`005` + distributed `id`) and BB3 (`ASSET-0021` + 36-sample
scatter, spread 4.1e15, 0 collisions at steady state).
