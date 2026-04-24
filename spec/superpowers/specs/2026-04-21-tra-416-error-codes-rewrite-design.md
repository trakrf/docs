# TRA-416 — error-codes.md rewrite (design)

**Linear:** [TRA-416](https://linear.app/trakrf/issue/TRA-416) — sub-issue of TRA-210
**Blocked-by (now resolved):** [TRA-407](https://linear.app/trakrf/issue/TRA-407) — merged in `trakrf/platform` at `6def23f` (2026-04-21).
**Related:** [TRA-408](https://linear.app/trakrf/issue/TRA-408) — other API-docs corrections (done). Deliberately left these two sections untouched to avoid rewriting twice.
**Ship-gate context:** TRA-416 + TRA-400 are the ship gate for a channel-partner-ready public API; the definition of done is a clean black-box test run by a fresh integrator.

## Goal

Update `docs/api/error-codes.md` so the two sections that describe the validation envelope and the request-id format match what the TrakRF public API actually emits post-TRA-407. Close the docs-vs-service gap that would otherwise trip a black-box integrator.

## Scope

One PR, one branch, one file (`docs/api/error-codes.md`). Every change lands as its own conventional-commit scoped `tra-416`. No squash merges (per project convention).

**Branch:** `docs/tra-416-error-codes-rewrite` (already created off `main`).

**In scope:**

- `## Validation errors` section (current lines 50–88) — example envelope, field-entry description, code enum list.
- `## Request IDs` section (current lines 109–113) — one clarification sentence on inbound echo behavior.

**Out of scope:**

- `## Envelope shape` section — already matches the service. No edits.
- Every other section (`## Error type catalog`, `## Retry guidance`, `## Idempotency`, `## Deprecation notices`) — not in TRA-416 scope.
- Any other `docs/api/*.md{,x}` file. Rest-of-docs sweeps already happened under TRA-408.
- Platform-owned files (`static/api/openapi.{json,yaml}`, `static/api/trakrf-api.postman_collection.json`). These regenerate from `trakrf/platform` and hand-edits would be overwritten.

## Platform-side ground truth (2026-04-21)

Verified against the landed TRA-407 code in `trakrf/platform`.

### Validation envelope (`trakrf/platform` paths)

- `backend/internal/models/errors/errors.go` defines `ErrorResponse.Fields []FieldError` with `omitempty`.
- `backend/internal/util/httputil/validation.go::RespondValidationError` writes the validation envelope:
  - `title` = `"Validation failed"`
  - `detail` = `"Request did not pass validation"`
  - `fields[]` populated from `validator.ValidationErrors`.
- `JSONTagNameFunc` makes `field` carry the JSON tag (e.g. `org_name`), **not** the Go struct field name, and **not** a JSON-pointer path. For nested structs the default `validator.FieldError.Field()` returns the leaf name — not `"metadata.foo.bar"`.

### Code enum the service actually emits

From `tagToCode` + `codeForTag` in `validation.go`:

| code            | When emitted                                                         |
| --------------- | -------------------------------------------------------------------- |
| `required`      | tags `required`, `required_without`, `required_with`                 |
| `invalid_value` | tags `email`, `oneof`, `url`, `uuid`, and any unknown tag (fallback) |
| `too_short`     | tag `min` on string/slice kinds                                      |
| `too_long`      | tag `max` on string/slice kinds                                      |
| `too_small`     | tags `min` (numeric), `gte`, `gt`                                    |
| `too_large`     | tags `max` (numeric), `lte`, `lt`                                    |

**Codes the current docs list but the service never emits:** `invalid_format`, `out_of_range`. Remove.
**Codes the service emits but the current docs don't list:** `too_small`, `too_large`. Add.

### Message format

`messageForField` emits short ASCII strings that include the field name, e.g.:

- `required` → `"org_name is required"`
- `too_short` → `"password must be at least 8 characters"`
- `too_long` → `"identifier must be at most 255 characters"`
- `too_small` → `"count must be >= 1"`
- `too_large` → `"count must be <= 100"`
- `invalid_value` → `"email is not a valid value"`

No unicode symbols (`≤` / `≥`), no copy like `"must be one of: asset"`. Docs examples must match.

### Request ID

- `backend/internal/middleware/middleware.go::RequestID`:
  - If inbound `X-Request-ID` is present, echo it verbatim (no format validation).
  - Otherwise generate via `oklog/ulid/v2` (`ulid.MustNew(ulid.Timestamp(time.Now()), ulidEntropy)`), 26-char Crockford base32.
- `backend/internal/cmd/serve/contract_smoke_test.go::TestContract_RequestIDIsULIDAndPropagates` locks in the ULID shape.
- The `X-Request-ID` response header and the `error.request_id` body field always carry the same value.

## Changes to `docs/api/error-codes.md`

### Change 1 — Validation envelope example JSON

**Current (approx lines 54–69):**

```json
{
  "error": {
    "type": "validation_error",
    "title": "Invalid request",
    "status": 400,
    "detail": "Request validation failed",
    "instance": "/api/v1/assets",
    "request_id": "01J...",
    "fields": [
      {
        "field": "identifier",
        "code": "too_long",
        "message": "must be ≤255 characters"
      },
      {
        "field": "type",
        "code": "invalid_value",
        "message": "must be one of: asset"
      }
    ]
  }
}
```

**Rewrite to:**

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "Request did not pass validation",
    "instance": "/api/v1/assets",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "identifier",
        "code": "too_long",
        "message": "identifier must be at most 255 characters"
      },
      {
        "field": "type",
        "code": "invalid_value",
        "message": "type is not a valid value"
      }
    ]
  }
}
```

Why each edit:

- `title` / `detail` strings match `RespondValidationError` exactly.
- `request_id` uses the same 26-char Crockford-base32 placeholder shape as the `Envelope shape` section (keeps the page internally consistent).
- `message` strings use the ASCII wording `messageForField` actually emits, including the leading field name.

### Change 2 — Field entries table

**Current (approx lines 73–77):** `field` column claims:

> JSON-pointer path to the invalid field (e.g. `identifier`, `metadata.foo.bar`).

**Rewrite to:**

> The JSON field name of the offending request attribute (e.g. `identifier`, `org_name`). Values are the snake_case JSON keys defined by the endpoint's request schema, not Go struct names or JSON-pointer paths.

No changes to the `code` and `message` rows.

### Change 3 — Current `code` values list

**Current (approx lines 81–86):**

- `required` — the field is missing and mandatory
- `invalid_value` — not one of the allowed values
- `too_short` — below the minimum length
- `too_long` — above the maximum length
- `invalid_format` — didn't match a pattern (e.g. identifier character set)
- `out_of_range` — numeric value outside the allowed range

**Rewrite to:**

- `required` — the field is missing and mandatory
- `invalid_value` — the value is not one of the allowed values, fails a format check (email, URL, UUID), or fails a validation TrakRF has not mapped to a more specific code
- `too_short` — string or collection length below the minimum
- `too_long` — string or collection length above the maximum
- `too_small` — numeric value below the minimum
- `too_large` — numeric value above the maximum

Keep the existing paragraph that follows (lines 88 / "extensible enum — clients should treat unknown codes as generic invalid-value errors and surface the `message`") unchanged. It remains accurate and is the whole reason we can add codes later without breaking anyone.

### Change 4 — Request IDs section

**Current (approx lines 112–113):**

> If your client supplies an inbound `X-Request-ID` header, it's accepted and echoed back. Otherwise a new ULID is generated server-side.

**Rewrite to:**

> If your client supplies an inbound `X-Request-ID` header, it is echoed back unchanged — TrakRF does not validate its format. Clients that supply their own IDs are encouraged to use ULIDs so log tooling remains consistent. When no inbound header is supplied, TrakRF generates a ULID server-side.

Single-sentence clarification. No table or structural change.

## Non-changes (explicit)

- No change to the `## Envelope shape` example — its `title: "Invalid request"` is intentionally a **non-validation** 400 example and is unaffected by TRA-407.
- No change to the `## Error type catalog` table.
- No change to `## Retry guidance`, `## Idempotency`, or `## Deprecation notices`.
- No change to `openapi.{json,yaml}` or the Redoc-rendered reference. Platform regenerated the Fields[] schema in commit `d582f18` (trakrf/platform) before PR #172 merged; the Redoc page already reflects the correct shape.

## Verification

**Pre-commit (local):**

- `pnpm build` passes in `trakrf-docs/`.
- `pnpm dev` — visually inspect `/docs/api/error-codes`:
  - JSON blocks highlight cleanly.
  - Table renders with the reworded `field` description.
  - Code list includes `too_small` and `too_large`, omits `invalid_format` and `out_of_range`.

**Pre-ship (against preview deployment):**

- Deploy the PR preview; confirm `docs.preview.trakrf.id/docs/api/error-codes` matches.
- Hit the **platform** preview (`app.preview.trakrf.id`) with a deliberately-invalid `POST /api/v1/auth/signup` body; confirm the returned `error` payload matches the rewritten example in every field the docs now promise:
  - `error.title == "Validation failed"`
  - `error.detail == "Request did not pass validation"`
  - `error.fields[].code ∈ {required, invalid_value, too_short, too_long, too_small, too_large}`
  - `error.request_id` is a 26-char Crockford-base32 ULID and equals the `X-Request-ID` response header.
- Send a request with `X-Request-ID: client-supplied-abc123`; confirm it is echoed back verbatim in the response header.

**Ship gate (TRA-416 + TRA-400):**

- Re-run the black-box harness (`tests/blackbox/` in `trakrf-docs`) and confirm a clean run. This is the channel-partner readiness signal, not `pnpm build` alone.

## Rollout

1. Commit the four edits individually under `docs/tra-416-error-codes-rewrite`, each with a `docs(tra-416): ...` conventional-commit subject.
2. Open PR to `main` with summary + test plan.
3. On merge, the existing `sync-preview.yml` workflow publishes to `docs.preview.trakrf.id`; production publish happens on the next scheduled cross-repo sync.

## Risks

- **Redoc drift.** If Redoc ever renders a stale `openapi.{json,yaml}` version that still carries the old validation envelope, the prose will be right but the reference page will contradict it. Mitigated by verifying platform's regenerated `openapi.public.*` is in place before shipping; explicitly named as a check in the verification section.
- **Future code additions.** If platform adds an `invalid_format` or `out_of_range` code later, the docs will need another follow-up. The "extensible enum" paragraph already gives clients cover — the risk is docs drift, not a client break.
