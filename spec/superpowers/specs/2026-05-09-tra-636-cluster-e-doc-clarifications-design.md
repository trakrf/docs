---
ticket: TRA-636
title: Polish Cluster E — doc clarifications batch (multi-file)
status: design
date: 2026-05-09
---

# Goal

Close the long tail of "1-line callout missing" findings re-raised across BB12–BB20 cycles. ~19 line items grouped by file. Single trakrf-docs PR; one review pass.

# Pre-implementation audit — what's already done

A non-trivial number of items in the ticket were addressed by earlier polish drops since the finding was first written. Verified before drafting copy:

| Item                                       | Status before this PR                                                                         | Verdict        |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- | -------------- |
| BB20 §F5 — strike NFC from prose           | Platform PR #286 merged 2026-05-09; spec mirror sync covers this PR                           | Refresh only   |
| BB20 §F6 / §2.7 — server-minted `external_key` format in resource-identifiers prose | resource-identifiers.md L197 already documents `ASSET-NNNN` from per-org sequence | Already done   |
| BB20 §F7 — `tree_path` derivation rule (lowercase + hyphen→underscore)              | resource-identifiers.md L187 already documents both transforms                    | Already done   |
| §1.9 — idempotent tag-association DELETE   | errors.md L278 already says "returns 204 whether or not the tag was associated"               | Already done   |
| D-3 — both FK fields together is consistency-checked, not mutually exclusive | resource-identifiers.md L156 already says "Sending both is allowed when they agree"; "mutually exclusive" no longer appears in any docs page | Already done |
| D-12 — `/lookup` no-params bad_request vs validation_error | `/lookup` endpoint was removed in TRA-600; no references remain in spec or docs              | Moot           |
| O-3 — concept-guide slug case sweep        | Every entry in `sidebars.ts` and every file under `docs/api/` is lowercase; TRA-635 fixed CHANGELOG | Already done |
| S3 — `parent_id: null` on PUT              | UpdateLocationRequest declares `parent_id: nullable`; resource-identifiers.md L158 already documents PUT-null clears the parent | Already done |

That leaves the items below as the actual scope of this PR.

# In-scope changes

## `getting-started/api.mdx` (W2)

Reconcile the "verify your key works" first call to `GET /api/v1/orgs/me`. Today the page recommends `GET /api/v1/locations/current`, which depends on `history:read` and on the org having scan history. `/orgs/me` requires no scope and is the canonical "tell me about myself" probe — and it's what `quickstart.mdx` and `authentication.md` already recommend.

Replacing `/locations/current` (not deleting the page, since it tracks the integration plan and pairs with `getting-started/ui.mdx`). The 403 walkthrough loses its `history:read` thread, so swap that example for a `401` walkthrough that's more universally relevant to the first-call moment. Tighten the response shape example to match the `{"data": {"id", "name"}}` envelope `/orgs/me` actually returns.

## `authentication.md`

**§1.3 — misminted-key recovery.** Add a one-paragraph note inside "Mint your first API key" (or the start of "Key lifecycle") spelling out that scopes can't be edited after creation: revoke the misminted key and mint a new one. Existing prose mentions both halves separately but doesn't tie them together as a recovery path.

**S-5 — `expires_at` semantics.** Extend the existing **Expiration** bullet at L118 with the tail end of the story: explicit expirations populate the JWT's `exp` claim; the **Never** option omits the claim entirely. There is no separate `expires_at` field on the public surface — listing/inspection happens via the SPA, which renders the same information from the underlying claim. (One-line clarification, no new section.)

## `resource-identifiers.md`

**3.7 — `tag_type` defaults to `rfid`.** Add to the "Tags use a composite natural key" section: when omitted on a create, the server defaults `tag_type` to `rfid`. The OpenAPI spec carries `default: rfid`, so codegen-derived clients also surface the default at the type-system level.

**V1 — three views of the natural key.** Today the doc covers three independent string-handle concepts in three sections: `external_key` itself (lede), `*_external_key` FK fields (L69+), and `tree_path` derived label-paths (L160+). Add a single short paragraph after the lede that names all three and points at the dedicated section for each. This is the "name the asymmetry once" callout the ticket asked for, not a structural rewrite.

**V4 (TRA-570) — tag overload disambiguation.** Add one paragraph at the top of "Tags use a composite natural key": the noun "tag" is overloaded across the docs — in the data model it's the `(tag_type, value)` primitive, in RFID-domain prose it's a hardware label. Both senses appear; the data-primitive sense is what the API surface refers to.

**V4 (TRA-597) — `external_key` vs `tags[].value`.** Co-located with the V4 paragraph above. Assets and locations have a single string natural key (`external_key`); tags have a composite one (`(tag_type, value)`). Don't conflate `external_key` (resource-level partner handle) with `tags[].value` (tag-level partner handle inside a typed pair).

**C-8 — `external_key` and `id` asymmetry.** Soften the lede claim that "both are first-class" — replace with the actual asymmetry: `id` is canonical at the URL surface (path params, FK joins), `external_key` is canonical for partner-side joins (system-of-record, integrations). Both are durable; neither is a fallback for the other; but they are not equivalent. The rest of the page already operates on this distinction; the lede should match.

## `errors.md`

**D-7 — `fields[].code` is the stable contract for `validation_error`.** The "do not branch on `error.detail`" guidance is already in the existing prose (implicit in `title` being fixed per `type` at L31). The missing piece is the positive: for `validation_error` specifically, branch on `fields[].code`, not on `title` and not on `detail`. Add a one-line callout at the top of the "Validation errors" section.

## `pagination-filtering-sorting.md` (C3)

Add a one-line callout to the "Time range (history)" subsection (L126+) noting that `from` / `to` (history query params) and `valid_from` / `valid_to` (effective-date schema fields) share a similar shape but mean different things — observation window vs. effective-dating bounds. This is the easy-to-mistake-from-context scenario the ticket flagged.

## Per-file audit-adjacent sweep

For each touched file, scan for adjacent small-callout omissions (e.g., when fixing `tag_type` default, scan for other open-enum fields whose defaults are undocumented). Findings recorded in PR description.

# Out of scope (declared)

- Restructuring the natural-key story into a single canonical section. V1 asked for "reconcile or document the asymmetry"; documenting it is a one-paragraph cross-reference, restructuring is a separate doc-architecture decision.
- Building out `docs/user-guide/reports-exports.md` (currently a placeholder). C3 is satisfied by the disambiguation in `pagination-filtering-sorting.md`; the reports user-guide page is its own scope.
- Moving the idempotent-DELETE callout from errors.md into resource-identifiers.md or quickstart.mdx — already exhaustively documented in errors.md, additional callouts would duplicate.

# Acceptance

- [ ] Each listed item lands in the named file as a one-line / one-paragraph addition.
- [ ] `pnpm build` passes with no broken-link warnings.
- [ ] `pnpm lint` clean.
- [ ] PR description records what was already-done and what was changed, per file.
- [ ] Spec mirror reflects platform PR #286 (NFC strike).
