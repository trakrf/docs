# TRA-634 — Decode-error wording for body type-mismatch (Cluster C)

## Status

Pre-launch. Platform-side fix already shipped in
[trakrf/platform PR #283](https://github.com/trakrf/platform/pull/283).
This spec covers the docs-side leftover under
[TRA-638](https://linear.app/trakrf/issue/TRA-638) (BB21 consolidation
drop, cluster C).

Source bucket items absorbed when this lands: TRA-543 §1.12 (BB12) and
TRA-581 §D-8 (BB15) — literal duplicate findings, both close on this PR.

## Goal

Reflect the new `bad_request` `detail` wording on
`docs/api/errors.md`. The page currently implies type-mismatch errors
are anonymous (offending field never surfaced). Post-#283, the field
name IS surfaced — in `detail`, not `fields[]`.

Three `400` cases on body decode that the page must distinguish:

1. **Malformed JSON / EOF / truncated** → `bad_request` /
   `Request body is not valid JSON` (unchanged)
2. **Valid JSON, wrong field type** → `bad_request` /
   `Body field "<name>" could not be decoded as the expected type`
3. **Valid JSON, top-level type mismatch (no field name)** →
   `bad_request` / `Request body could not be decoded as the expected type`
4. **Unknown field** → `validation_error` with `fields[]` (unchanged,
   already documented in the validation-errors section)

Cases 2 + 3 are the new wording; case 1 is unchanged; case 4 is the
contrast already on the page.

## Non-goals

- No edits to the OpenAPI spec beyond the `scripts/refresh-openapi.sh`
  pull. PR #283 was code-only — the spec mirror is byte-identical;
  only `platform-meta.json` (commit SHA pointer) and the regenerated
  Postman collection (sample-data churn) change.
- No new section heading. The three-case split is teachable inline
  in the existing `validation_error vs bad_request` subsection.
- No edits to TRA-543 / TRA-581 — they close transitively via TRA-638.

## File map and per-file changes

### `static/api/openapi.{json,yaml}`, `static/api/platform-meta.json`, `static/api/trakrf-api.postman_collection.json`

Refreshed via `scripts/refresh-openapi.sh`. Diff is metadata + Postman
sample-data only; openapi.{yaml,json} are byte-identical. Committed
separately as `chore(api): refresh OpenAPI spec mirror …` so the
docs-prose commit is reviewable on its own.

### `docs/api/errors.md`

Two surgical edits.

**Catalog row, line 62 (`bad_request`):**

Before:
> Request was malformed in a way the API can't attribute to a specific field — invalid JSON syntax, or a JSON-type mismatch (e.g. a number where the schema expects a string). No `fields[]`.

After:
> Request was malformed at decode time — invalid JSON syntax, or a JSON value that didn't match the expected type for a body field. No `fields[]`; the offending field name (when known) is in `detail`. See [validation_error vs bad_request](#validation_error-vs-bad_request).

The "can't attribute to a specific field" claim is no longer true for
case 2; the new wording lifts that and points at the subsection where
the worked examples live. (Existing anchor `#validation_error-vs-bad_request`
is auto-generated from the existing heading.)

**`validation_error vs bad_request` subsection, lines 73–77:**

Keep the lead paragraph (line 75) — its high-level rule still holds.
Replace the trailing "quirk" paragraph (line 77) with a short worked
example showing the two new `detail` forms.

Before:
> One quirk worth noting: sending the wrong JSON type for a body field (for example, a number where the schema expects a string) returns `bad_request`, not `validation_error` — the JSON decoder fails before per-field reporting is reliable. If you see `bad_request` on a body that looks well-formed, this is the most likely cause.

After: a short paragraph + two fenced JSON examples. The named-field
form (`Body field "external_key" could not be decoded as the expected
type`) and the top-level form (`Request body could not be decoded as
the expected type`). The "JSON decoder fails before per-field
reporting is reliable" rationale is replaced — type-mismatch failures
don't go through the schema validator, which is why they surface
under `bad_request` rather than `validation_error`. JSON examples
follow the page's existing teaching style (validation_error already
has four worked examples); decided autonomously per user direction.

## Acceptance

Maps directly to the ticket's acceptance criteria:

- [x] decode.go renders distinct messages — handled by platform PR #283
- [x] tests updated — handled by platform PR #283
- [x] no error-envelope regression — confirmed via PR #283 description
- [ ] **single PR for docs side** — this PR
- [ ] catalog row no longer claims "can't attribute to a specific field" universally
- [ ] subsection shows the new `detail` wording in worked examples
- [ ] `pnpm build` clean (anchor `#validation_error-vs-bad_request` resolves)

## Out-of-scope cross-checks (audit-adjacent, completed)

- Searched `docs/`, `static/`, `tests/` for stale `"not valid JSON"` /
  `"Body field"` example payloads — none found, no other prose hits.
- No example request-bodies in docs currently demonstrate "wrong
  type → not valid JSON".
- Cluster B (TRA-633) and Cluster F (TRA-637) are independent and
  out of scope here.
