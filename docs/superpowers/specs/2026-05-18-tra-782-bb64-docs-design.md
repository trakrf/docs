---
ticket: TRA-782
date: 2026-05-18
---

# TRA-782 BB64 docs-only — quickstart PATCH echo prose tighten + `updated_at`-as-optimistic-concurrency-token design note

First docs-only ticket in the paired-ticket era. No platform PR, no changelog — both items document existing service behavior; no behavior change to record.

## Scope

Two changes against `trakrf/docs`:

1. **F1 — PATCH read-only echo prose tighten + post-TRA-780 code split.** Quickstart's round-trip section already correctly frames the accept-if-matches / reject-if-differs rule (lines 141, 143 — including a one-sentence mention of optimistic concurrency on `updated_at`). The remaining drift sits at quickstart line 158 ("every value echoes silently" reads as "all values silently ignored" rather than "matching values match-strip"), and across multiple pages the rejection `code` is still uniformly stated as `read_only` even though TRA-780 F4 split the runtime emission into `read_only` (truly server-managed) and `invalid_context` (sub-resource-mutable).
2. **F2 — new `/docs/api/design-notes` entry on `updated_at`-as-optimistic-concurrency-token.** Quickstart's round-trip paragraph briefly mentions optimistic concurrency on `updated_at`; a write-heavy integrator scanning design-notes for "what's the concurrency model?" should land on a dedicated entry that names the pattern, gives a worked example, and explains why the spec annotation (`readOnly: true`) doesn't convey the runtime contract on stale-value rejection.

## F1 — Audit and corrections

Three classes of edit:

### F1a — Tighten "every value echoes silently" phrasing

`quickstart.mdx:158`: the phrase "every value echoes silently" reads as universal-silent-ignore rather than match-strip-only. Tighten to "every read-only field whose value matches the current state echoes silently" or similar. This is the literal "silently ignores" framing the ticket names (paraphrased from quickstart prose, not lifted verbatim).

### F1b — Post-TRA-780 code-split corrections

Update specific references to `code: read_only` on fields that now emit `code: invalid_context` (per the TRA-780 platform F4 split):

| File | Line | Current | Post-TRA-780 |
| -- | -- | -- | -- |
| `quickstart.mdx` | 158 | `external_key` PATCH → `400 read_only` | `400 invalid_context` |
| `quickstart.mdx` | 158 | `tags` collection PATCH → `400 read_only` | `400 invalid_context` |
| `resource-identifiers.md` | 386 | `external_key` PATCH → `code: read_only` | `code: invalid_context` |
| `data-model.md` | 25 | `external_key` PATCH → `400 read_only` | `400 invalid_context` |

The truly-server-managed fields (`id`, `created_at`, `updated_at`, `deleted_at`, `location_id`, `location_external_key`) keep `code: read_only` per F4. The `location_*` cases on `PATCH /assets` (`resource-identifiers.md` table around line 317, prose at line 214, table cells at line 315/317) stay on `read_only` and need no edit.

### F1c — Generic accept-if-matches statements

`resource-identifiers.md:235` and `:253` describe the rule generically with a blanket `code: read_only`. The field-level split needs to surface here too — the cleanest move is one sentence at line 235 calling out the two codes and pointing at the table immediately below, then leaving the blanket `read_only` references in the surrounding prose intact (the table is the canonical mapping; the prose lines downstream of the table can continue to use `read_only` as the generic example without misleading anyone who's read the framing sentence first).

The reject-if-differs table at lines 237-246 currently maps field → reject-message. Adding a `code` column tightens the docs further but expands the change surface meaningfully. **Skipping the table column for this PR** — the framing sentence at :235 plus the per-field correction at :386 captures the load-bearing information. A follow-up audit could revisit if needed.

`resource-identifiers.md:257` ("a differing instant still rejects with `read_only`") is specifically about `created_at` / `updated_at` / `deleted_at` (the timestamp set), all of which stay on `read_only`. No edit.

`resource-identifiers.md:317` (table cell for `PATCH /assets/{id}` body with `location_id` / `location_external_key`) is about the scan-derived FK pair, which stays on `read_only`. No edit.

## F2 — Design-notes entry

New entry on `/docs/api/design-notes.md`, placed **after the existing Timestamps section** (`### Timestamps on the wire carry fixed millisecond precision`) for topical adjacency to `updated_at`. Section heading:

> ## `updated_at` is an optimistic-concurrency token on `PATCH`

Body sections:

1. **The spec annotation tells you half the story.** `readOnly: true` on `updated_at` correctly signals server-managed-on-write — codegen tools omit it from request shapes. What the annotation doesn't convey is the runtime contract when a hand-rolled caller (or a caller round-tripping the full read shape) does include it.
2. **The runtime contract: accept-if-matches / reject-if-differs.** Submitting the value last seen on GET is silently normalized out (PATCH proceeds as if the field was absent). Submitting a stale value (one another writer has since superseded) returns `400 validation_error` / `code: read_only` with a detail naming the mismatch — the exact lost-update detection signal a write-heavy integrator needs.
3. **Worked example.** GET / mutate / PATCH with `updated_at` from the GET response asserted in the body. Show the success path (no concurrent writer) and the rejection path (another writer landed first → 400 → refetch / reconcile / retry).
4. **Opting out.** If your client doesn't need lost-update detection (single-writer integrations, last-writer-wins acceptable), omit `updated_at` from the PATCH body — semantically equivalent to a fresh GET-and-echo since the server advances it on every successful write anyway.
5. **Cross-reference to the accept-if-matches rule.** The pattern is one instance of the uniform [accept-if-matches, reject-if-differs](./resource-identifiers#read-shape-vs-write-shape) rule that covers every read-only field, but `updated_at` is the one that **advances on every PATCH** and thus serves the concurrency-token role. The other read-only fields (`id`, `created_at`, `deleted_at`, `location_*`, `tags`, `external_key`) don't change on PATCH and reject only on integrator-side bugs.

Cross-link from `quickstart.mdx:143` (the existing one-sentence mention of optimistic concurrency) — add a brief inline "[design note]" or "see [Design notes → `updated_at` is an optimistic-concurrency token](./design-notes#updated_at-is-an-optimistic-concurrency-token-on-patch)" pointer so a reader following the quickstart round-trip lands on the dedicated entry.

## Out of scope

- No platform / spec edits — none required (both items document existing behavior).
- No changelog entry — no behavior change to record.
- No reject-if-differs table column expansion on `resource-identifiers.md` — captured as a possible follow-up if a future cycle surfaces the same gap.
- No Linear ticket references in the prose (per repo convention).

## Verification

- `pnpm typecheck` and `pnpm build` clean — Docusaurus broken-link check covers the new design-note anchor and the quickstart cross-link.
- Manual: render the three affected pages locally; confirm the F1 corrections read cleanly in context and the F2 design-note lands at the intended position with the worked-example codeblock formatted correctly.
- Preview deploy via Cloudflare Pages on merge.

## Commits

1. `docs(api): TRA-782 BB64 F1 — quickstart PATCH echo prose tighten ("matching values match-strip"); post-TRA-780 code split (external_key / tags → invalid_context)`
2. `docs(api): TRA-782 BB64 F2 — design-notes entry on updated_at as optimistic-concurrency token`

Two commits keep the F1 corrections (multi-file audit) separate from the F2 new-content addition. F1 first since it's the smaller surface area edit; F2 second since it adds a self-contained new section that doesn't depend on F1.
