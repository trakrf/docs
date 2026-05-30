---
title: TRA-885 — Distinguish the globally-unique surrogate id from the MAX+1 external_key
date: 2026-05-30
ticket: TRA-885
status: converged
source: bb-253 round-2.5 convergence (§0 / locked copy); operator-confirmed by Mike in-session
---

# TRA-885 — `id` vs `external_key`: state the contract precisely

## Source of truth

**The TRA-885 ticket text is stale.** Mike directed (in dispatch and in-session) that the
authoritative wording comes from the **bb-253 round-2.5 convergence (§0 locked copy)** — that
session did the post-ticket investigation and wording-refinement. Where the ticket and §0
disagree, §0 + Mike's in-session confirmation win. Mike okayed updating the ticket itself.

Two places the ticket is stale:

1. Ticket says "Make NO claim about cross-type id uniqueness either way." → **Superseded.** Mike
   confirmed directly: **state global uniqueness explicitly** ("better to be explicit and head
   off potential confusion"). TRA-886 (single shared sequence, PR #443, Done) makes it true by
   construction.
2. Ticket / existing docs frame `external_key` auto-mint as "lowest unused slot / gap-filling."
   → **Wrong.** Platform code-confirmed (`assets.go:60` `GetNextAssetSequence`, `locations.go:57`
   `GetNextLocationSequence`): it is **`MAX(live key)+1`**. Independently code-read by docs,
   triple-confirmed by platform via bb-253.

## The two identifiers (locked §0 framing)

- **`id`** — high-entropy, server-assigned integer. **Globally unique across all resources**
  (no two rows of any type share an `id`) and **opaque** (don't parse it, order by it, or infer
  count or time from it). **Permanent: never changes, never reused — even after delete.** Use it
  as the durable foreign key when mirroring TrakRF data; address a resource via its typed
  endpoint (`GET /assets/{id}`).
- **`external_key`** — human-readable handle, unique within your org for a given resource type,
  among **live** (non-deleted) rows. Supply your own, or the server auto-assigns. **Auto-assigned
  values are not a stable sequence:** they are `MAX(live key)+1`, so deletes leave **permanent
  gaps** and a freed value can be reused — a server-assigned `external_key` you saw before can
  later refer to a *different* resource. Don't cache it as a long-lived reference or infer counts
  from it; use `id` for that.

## external_key auto-mint mechanism (platform-confirmed)

- Auto-assigned key = `MAX(existing live ASSET-NNNN / LOC-NNN for your org) + 1`, zero-padded
  `ASSET-%04d` / `LOC-%03d`.
- **Middle-delete gaps are permanent.** Delete `ASSET-0002` while `0003` lives → next mint =
  `MAX(0003)+1` = `0004`, never `0002`. Not backfilled.
- **Only deleting the current highest live key frees its number.** Delete top `0003` → next mint
  re-issues `0003`.
- **Separate, caller-initiated reuse path:** a caller may re-supply a soft-deleted row's key
  string (the partial unique index is `WHERE deleted_at IS NULL`, so deleted keys sit outside
  it). Distinct from auto-mint.
- Keep the "non-monotonic / not a Postgres sequence" framing (accurate, consistent with
  changelog.md:152). Drop "lowest unused slot," "gap-filling," and any
  "backfilled / recyclable-implies-refill" wording.

## Build scope

1. **`docs/api/id-format.md`** — replace the standalone "randomly distributed" sentence (:26)
   with the field-named `id` framing (high-entropy, **globally unique**, opaque, permanent).
   Add the reinforcement line: a dense / low-valued `external_key` implies nothing about `id` —
   the two are allocated independently.
2. **`docs/api/resource-identifiers.md`** — two fixes:
   - "Numeric `id` is a surrogate key" section: replace "unique within their entity type, not
     across types / the same integer can be both an asset id and a tag id" → **globally unique,
     opaque, permanent**.
   - auto-mint section + system-of-record note: replace "lowest unused slot / gap-filling /
     recyclable" with the `MAX+1` mechanism above.
3. **`docs/api/changelog.md`** — fix the stale "lowest unused slot among live rows" assertions in
   the existing LOC-NNN-finalize and non-monotonic-wording entries; add a new entry recording the
   `id` global-uniqueness framing (tied to TRA-886) and the `external_key` `MAX+1` correction.

## Scope boundary

- Docs-only, consumer-facing.
- `id` global-uniqueness claim is **gated**: the PR does not merge until TRA-886 is live (prod)
  and Mike approves the diff. Timing handled by the gate, not by omitting the claim.

## Verification

- `pnpm build` passes (Redocusaurus + broken-link check).
- Read-through: no "randomly distributed" standalone line; no "lowest unused slot / gap-filling"
  anywhere; every distribution/allocation claim names its field; global uniqueness stated in
  id-format and resource-identifiers, consistent.

## Evidence

- Platform code: `assets.go:60` / `locations.go:57` → `SELECT MAX(...) WHERE deleted_at IS NULL`
  then `+1`.
- TRA-886 (PR #443, Done): single shared sequence → globally unique `id` by construction.
- Live BB evidence (from ticket): BB2 `LOC-004/005` + distributed `id`; BB3 `ASSET-0021` +
  36-sample scatter, spread 4.1e15, 0 collisions.
