# TRA-634 — Decode-error wording — implementation plan

Spec: [2026-05-09-tra-634-decode-error-wording-design.md](../specs/2026-05-09-tra-634-decode-error-wording-design.md)

Branch: `miks2u/tra-634-polish-cluster-c-decode-error-wording-for-body-type-mismatch`
Worktree: not used (per user direction; isolated session).

## Commits

Two commits, in order, on the branch above.

### 1. `chore(api): refresh OpenAPI spec mirror to pick up platform PR #283`

Touches:

- `static/api/platform-meta.json` — commit SHA → `4cf2956`
- `static/api/trakrf-api.postman_collection.json` — Postman regen (sample-data + UUID churn only; openapi.{yaml,json} byte-identical)
- `static/api/openapi.json`, `static/api/openapi.yaml` — confirmed unchanged (PR #283 is code-only); not in diff

Done by `scripts/refresh-openapi.sh` against `trakrf/platform@main`.

### 2. `docs(api): TRA-634 — distinct decode-error wording for body type-mismatch`

Two surgical edits in `docs/api/errors.md`:

#### Edit A — catalog row (line 62)

Replace the `When you'll see it` cell content for the `bad_request` row.

Old: `Request was malformed in a way the API can't attribute to a specific field — invalid JSON syntax, or a JSON-type mismatch (e.g. a number where the schema expects a string). No `fields[]`.`

New: `Request was malformed at decode time — invalid JSON syntax, or a JSON value that didn't match the expected type for a body field. No `fields[]`; the offending field name (when known) is in `detail`. See [validation_error vs bad_request](#validation_error-vs-bad_request).`

#### Edit B — `validation_error vs bad_request` subsection (line 77)

Replace the second paragraph (the "quirk worth noting" sentence).

Old: `One quirk worth noting: sending the wrong JSON type for a body field (for example, a number where the schema expects a string) returns `bad_request`, not `validation_error` — the JSON decoder fails before per-field reporting is reliable. If you see `bad_request` on a body that looks well-formed, this is the most likely cause.`

New (rough shape — final wording in the actual edit):

> Type mismatches on body fields take this `bad_request` path because they fail at decode time, before the schema validator runs that would otherwise produce `fields[]`. The offending field name is surfaced in `detail` when the decoder can identify it:
>
> ```json
> {
>   "error": {
>     "type": "bad_request",
>     "title": "Bad request",
>     "status": 400,
>     "detail": "Body field \"external_key\" could not be decoded as the expected type",
>     "instance": "/api/v1/assets",
>     "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
>   }
> }
> ```
>
> When the mismatch is at the top level (the request body itself is the wrong JSON type — for example an array where an object is expected), `detail` falls back to a generic message:
>
> ```json
> {
>   "error": {
>     "type": "bad_request",
>     "title": "Bad request",
>     "status": 400,
>     "detail": "Request body could not be decoded as the expected type",
>     "instance": "/api/v1/assets",
>     "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX"
>   }
> }
> ```
>
> Genuinely malformed JSON (truncated, syntax-broken, EOF mid-token) returns the same envelope with `detail: "Request body is not valid JSON"`.

## Verification

- `pnpm build` — clean. The catalog-row anchor `#validation_error-vs-bad_request` is generated from the existing `### validation_error vs bad_request` heading; Docusaurus auto-slug must resolve. Confirm no broken-link warnings in output.
- `git diff --stat` — only `docs/api/errors.md` in the docs commit; only `static/api/platform-meta.json` + `static/api/trakrf-api.postman_collection.json` in the chore commit.
- `grep -rEn "JSON decoder fails before|can't attribute to a specific field" docs/` — must return no hits after edit B + edit A.

## PR

- Title: `docs(api): TRA-634 — distinct decode-error wording for body type-mismatch`
- Body: short summary, list the two edits, mention TRA-543/TRA-581 close transitively, link platform PR #283.
- Single PR per ticket acceptance.
- Pushed to remote, no merge — user reviews and merges.
