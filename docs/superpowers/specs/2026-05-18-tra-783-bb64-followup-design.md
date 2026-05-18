---
ticket: TRA-783
date: 2026-05-18
---

# TRA-783 BB64 follow-up — drop wire-idempotency; every accepted PATCH advances `updated_at`

Post-merge follow-up to BB64. Platform PR (trakrf/platform#376) ships the behavior change — every accepted PATCH advances `updated_at`, including the empty-body and verbatim-writable-echo cases — replacing the prior `IS DISTINCT FROM` short-circuit. The docs side cleans up the wire-idempotency claims threaded across four pages plus an integrator-visible changelog entry.

**PR base:** `docs/tra-782-bb64` (the open TRA-782 docs PR). The two PRs touch adjacent prose; basing TRA-783 on TRA-782 keeps the diff to the actual TRA-783 corrections. When TRA-782 merges, retarget to `main`.

## Scope

Five edits across four pages:

1. **`resource-identifiers.md`** — replace the wire-idempotency paragraph at `:255` with uniform-advance prose. Drop the byte-stable claim; describe the new model (every accepted PATCH advances `updated_at`); preserve the cross-link to errors.md idempotency for the retry-pattern consequence. Optionally tighten `:231` (the empty-body `{}` mention) to name that `updated_at` advances.
2. **`quickstart.mdx`** — rewrite the middle of the round-trip paragraph at `:143`. The current text claims "verbatim no-op body doesn't drift `updated_at`," describes the create-then-echo µs→ms-precision edge case as "the one exception," and asserts wire-idempotency on subsequent echoes. The new model has no exceptions and no special create-then-echo case — every accepted PATCH advances `updated_at`. The optimistic-concurrency framing stays (still accurate); the cross-link to the design-notes entry stays.
3. **`design-notes.md`** — audit the `updated_at`-as-optimistic-concurrency-token entry added in TRA-782. Initial read: the entry doesn't claim wire-idempotency anywhere. The pattern works regardless of whether matched-value PATCHes advance the token. Verify and adjust only if a wire-idempotency assumption slipped in.
4. **`errors.md`** — two updates:
    - **`:156`** — the F6 (TRA-780) paragraph documenting `{}` as RFC 7396 identity transform claims `updated_at` does not advance. Now wrong. Update to say `200` with no settable-field change but `updated_at` advances (the filesystem `touch` analog). Cross-link replaced from the BB39 follow-up entry (now superseded) to the new BB64 follow-up entry.
    - **`:324`** — the PATCH bullet in the Idempotency section claims "byte-equal including `updated_at`" and "cached-body retries that didn't race a concurrent write are safe." The byte-equal claim is gone; the cached-body retry guidance needs a substantive update because a retry whose body includes `updated_at` from a successful first call will now fail with stale-token rejection. Restate: PATCH is semantically idempotent on settable-field state; `updated_at` advances on every accepted PATCH; cached-body retries are safe only when the body omits `updated_at` (or the client re-GETs to refresh it before retrying).
5. **`changelog.md`** — new BB64 follow-up entry above the prior BB63 wave (which sits above BB62 follow-up). Single-bullet wave entry per the established pattern; explicit mention that this supersedes the BB39 follow-up R1 claim, with cross-link.

## Replacement prose drafts

### F1 — `resource-identifiers.md:255` replacement paragraph

> Any accepted PATCH advances `updated_at` to the current server time on success. The model is uniform across body shapes — empty body (`{}`), verbatim writable echo of current values, partial mutation, and full mutation all advance the timestamp. The 400-rejection paths (read-only field mismatch with `code: read_only` or `code: invalid_context`, validation failure on a settable field, etc.) don't advance `updated_at` because the operation never reached storage. The mental model is filesystem `touch` semantics: any successful write event advances the modification time regardless of whether content changed. See [Errors → Idempotency](./errors#idempotency) for the consequence on cached-body retry patterns — specifically, a retry whose body echoes `updated_at` from a successful first call will fail with stale-token rejection.

### F2 — `quickstart.mdx:143` replacement middle of paragraph

The existing paragraph spans several sentences mixing accept-if-matches framing, the wire-idempotency claim, the create-then-echo edge case, the µs→ms precision detail, the cached-body retry guidance, and the optimistic-concurrency framing. The new version keeps the optimistic-concurrency framing (still accurate) and the cross-link to the design note (still useful), but drops the wire-idempotency claim and the create-then-echo edge case (no longer exceptional). Replacement:

> When you cache a GET response and `PATCH` later, `updated_at` is the field that drifts on every accepted PATCH — the server advances it to the current time on every successful write, regardless of whether the body contained real mutations or matched-value echoes. A real intervening write by another caller is the case to plan for: the cached `updated_at` is now stale, so re-`GET` immediately before `PATCH` to refresh it, or strip it from the cached body before sending. This is optimistic concurrency working as designed — the accept-if-matches rule on `updated_at` is how the API detects lost updates from concurrent edits, and the always-advance behavior matches filesystem `touch` semantics (any successful write advances the modification time). For the lost-update detection pattern and a worked example, see [Design notes → `updated_at` is an optimistic-concurrency token on `PATCH`](./design-notes#updated_at-is-an-optimistic-concurrency-token-on-patch).

### F3 — `design-notes.md` audit

Verify the TRA-782 entry doesn't carry wire-idempotency assumptions. On re-read: the entry's opt-out paragraph says "the server will advance it on every successful write regardless" — that aligns with the new model. The rest of the entry describes the concurrency-token pattern (accept-if-matches on the body's `updated_at` value), which is independent of whether matched-value bodies advance the token. **No edit required** unless a closer re-read surfaces a stale claim.

### F4a — `errors.md:156` replacement

The current TRA-780 F6 prose:

> A `PATCH` body of the empty object `{}` is the [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396) identity transform — a valid JSON object carrying zero merge directives, which the spec defines as a no-op. The service applies the merge and returns `200` with the resource unchanged; `updated_at` does not advance (the storage `IS DISTINCT FROM` short-circuit covered in [BB39 follow-up — PATCH no-op short-circuit] zero-rows the UPDATE on a verbatim no-op body, and the empty body is a strict subset of that case). Distinct from the rejected `null`-body case above: `null` is a deletion directive on the target; `{}` is a directive list with no directives. Clients that have nothing to change should skip the round-trip rather than PATCH-with-`{}`; clients deliberately exercising the identity-transform path (smoke tests verifying connectivity or auth scope) can rely on the `200` shape.

Replacement:

> A `PATCH` body of the empty object `{}` is the [RFC 7396](https://datatracker.ietf.org/doc/html/rfc7396) identity transform — a valid JSON object carrying zero merge directives, which the spec defines as a no-op against the resource's settable-field state. The service applies the merge and returns `200`; no settable field changes, but `updated_at` advances to the current server time (the uniform behavior shipped in the [BB64 follow-up below] — every accepted PATCH advances `updated_at` regardless of body content, matching filesystem `touch` semantics). Distinct from the rejected `null`-body case above: `null` is a deletion directive on the target; `{}` is a directive list with no directives. Clients that have nothing to change should skip the round-trip rather than PATCH-with-`{}` — the round-trip cost plus the `updated_at` advance is observable churn on the row's last-modified timestamp; clients deliberately exercising the identity-transform path (smoke tests verifying connectivity or auth scope) can rely on the `200` shape.

### F4b — `errors.md:324` replacement bullet

Current:

> **`PATCH /assets/{asset_id}`, `PATCH /locations/{location_id}`** — JSON Merge Patch (RFC 7396) bodies are fully idempotent at the wire layer: applying the same patch twice yields the same final state as applying it once, **and** a verbatim no-op body (every settable field at its current value) leaves the row byte-equal including `updated_at`. The storage layer applies `IS DISTINCT FROM` per settable column and skips the UPDATE when nothing differs. Cached-body `PATCH` retries that didn't race a real concurrent write are safe; real changes still advance `updated_at` as normal.

Replacement:

> **`PATCH /assets/{asset_id}`, `PATCH /locations/{location_id}`** — JSON Merge Patch (RFC 7396) bodies are semantically idempotent on the resource's settable-field state: applying the same patch twice converges on the same final values. `updated_at` is not part of that idempotency guarantee — every accepted PATCH advances it to the current server time (see the [BB64 follow-up changelog entry] for the model and rationale). The retry-safety implication: a cached `PATCH` body that echoes `updated_at` from a successful first call will fail with `400 validation_error` / `code: read_only` on retry because the cached `updated_at` is now stale (the first call advanced it). Safe retry patterns are (a) omit `updated_at` from the body entirely — the server advances it regardless — or (b) re-`GET` immediately before the retry to refresh `updated_at`. Real-mutation retries face the same constraint, with the additional consideration that the retry may race a real intervening write by another caller, which the optimistic-concurrency token surfaces as the same stale-token rejection.

### F5 — Changelog entry

New section above `### BB63 fix wave — readOnly annotations on Asset and Location read views, ErrorEnvelope named schema, read_only vs invalid_context semantic split` (currently in pole position from the TRA-780 wave). Heading:

> `### BB64 follow-up — every accepted PATCH advances updated_at (drops wire-idempotency for no-op bodies)`

One-paragraph intro + single bullet. The intro names the predecessor (BB39 follow-up R1) being superseded, the integrator-visible consequence (cached-body retries that include `updated_at` now need refresh), and the filesystem-`touch` mental model. The bullet covers the behavior change with cross-links to the resource-identifiers update, the design-note, and the errors.md idempotency section.

Body:

> Single behavior change from a BB64 docs-side probe verification. The prior model — shipped in the BB39 follow-up wave below — short-circuited the storage UPDATE when no settable field's value differed from the current state, leaving `updated_at` byte-equal across verbatim no-op PATCHes. Probe verification post-BB64 found the short-circuit broke for `valid_from` / `valid_to` whenever the stored value carried sub-millisecond precision the wire didn't see (server-defaulted timestamps, sub-ms client input): the `IS DISTINCT FROM` check ran in storage coordinates against bytes the wire-truncated body didn't fully express, so a verbatim wire-level echo could still advance `updated_at`. Rather than carry the edge cases, the model simplifies: every accepted PATCH advances `updated_at`, no exceptions.
>
> - **Every accepted PATCH advances `updated_at`.** Empty body (`{}`), verbatim writable echo of current values, partial mutation, and full mutation all advance `updated_at` to the current server time on success. Rejected PATCHes (400 from a read-only field mismatch, validation failure on a settable field, or any other 4xx) do not advance — the operation never reached storage. The model matches filesystem `touch` semantics: any successful write event advances the modification time regardless of whether content changed. The [optimistic-concurrency-token contract on `updated_at`](./design-notes#updated_at-is-an-optimistic-concurrency-token-on-patch) is unchanged — submitting a stale `updated_at` still returns `400 validation_error` / `code: read_only` with the mismatch detail — but cached-body `PATCH` retries that include `updated_at` now need to refresh the token from a fresh `GET` before retrying (or omit `updated_at` from the body, letting the server advance it implicitly). Supersedes the BB39 follow-up R1 entry below ("PATCH idempotent on a verbatim no-op body"); the no-op short-circuit is gone. See [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) for the round-trip framing and [Errors → Idempotency](./errors#idempotency) for the cached-body retry-pattern consequence.

## Out of scope

- No platform / spec edits — platform PR #376 already ships the behavior change.
- No rename-endpoint changes — BB39 fix wave's same-value rename short-circuit is on a different code path and is unaffected.
- No edit to the prior BB39 follow-up R1 changelog entry — per Keep a Changelog convention, prior entries are historical. The new BB64 follow-up entry explicitly notes the supersession.
- No Linear ticket references in the prose (per repo convention).

## Verification

- `pnpm typecheck` and `pnpm build` clean — Docusaurus broken-link check covers the new cross-links (especially the in-file `#bb64-follow-up-*` anchor and the existing `./design-notes#updated_at-...`, `./errors#idempotency` anchors).
- Manual: render the five affected pages on the Cloudflare Pages preview; confirm prose reads cleanly and the wire-idempotency claims are uniformly replaced. Re-read the design-note to confirm no stale assumptions slipped in.
- Subsequent BB cycle against the deployed preview verifies the integrator-visible model matches the changelog wording (orthogonal — platform PR #376 already ships the behavior).

## Commits

1. `docs(api): TRA-783 BB64 follow-up — drop wire-idempotency claim across resource-identifiers, quickstart, errors`
2. `docs(api): TRA-783 BB64 follow-up — changelog entry for every-accepted-PATCH-advances-updated_at`

Two commits to keep the audit-driven prose corrections separate from the summary changelog entry. F3 (design-note audit) likely contributes zero diff; F4a / F4b are in errors.md so they fold into the first commit alongside F1 / F2.

## PR base

Open the PR with `base: docs/tra-782-bb64`. Reviewer sees only the TRA-783 diff. When TRA-782 merges to main, retarget base to `main` (or accept whatever GitHub auto-suggests). No rebase needed because TRA-782's commits become merge ancestors of main on merge.
