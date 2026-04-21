# trakrf API — error-codes.md conformance probe

Your job is to verify that the live TrakRF API behaves the way `docs/api/error-codes.md` claims. Treat every claim in that page as a hypothesis to check against the running service. **Do not read any issue trackers, pull requests, source code, or internal documentation.** Your only inputs are the docs URL, the app URL, and the credentials.

## Environment

`.envrc` + `.env.local` expose four vars via direnv:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `API_TEST_LOGIN` — admin account email
- `API_TEST_PASS` — admin account password

**Do not echo `API_TEST_PASS` or pass it as a literal in tool-call arguments.** Reference it through env var expansion or your language's env-reading APIs.

## Scope

Confirm or falsify the claims in the `## Validation errors` and `## Request IDs` sections of `$API_TEST_DOCS_URL/docs/api/error-codes`. Ignore the rest of the page.

## Probe plan

Use whichever HTTP client / language you'd naturally reach for. You will need a valid API key — mint one via the UI using the docs' own instructions, then attach it to every request.

Exercise the validation envelope by sending deliberately-broken request bodies to at least two endpoints that accept writes (e.g. `POST /api/v1/assets`, `POST /api/v1/auth/signup`). Cover these failure modes across your attempts:

- A required field omitted.
- A string field shorter than the minimum length.
- A string field longer than the maximum length.
- A numeric field outside its allowed range (both below and above, on whichever endpoint exposes numeric bounds).
- A value that fails an `email` / `url` / `uuid` format check.
- A value outside a finite set (e.g. an `enum` / `oneof`).

For the request-ID behavior, make two calls against any endpoint:

1. No `X-Request-ID` header supplied.
2. `X-Request-ID: probe-abc-123` (a deliberately non-ULID value).

## Claims to verify

For every validation-error response:

- `error.type` is `"validation_error"`.
- `error.title` equals `"Validation failed"` exactly.
- `error.detail` equals `"Request did not pass validation"` exactly.
- `error.fields` is a non-empty array.
- Each `error.fields[i].field` value is a bare JSON field name (e.g. `org_name`), not a JSON-pointer path like `/metadata/foo/bar` or a Go struct name.
- Each `error.fields[i].code` is one of: `required`, `invalid_value`, `too_short`, `too_long`, `too_small`, `too_large`. **Flag any other value.**
- Each `error.fields[i].message` is ASCII-only (no `≤` / `≥` or other unicode symbols) and begins with the field name.
- The six failure modes listed above map to the codes the docs imply (`required` → missing required; length → `too_short` / `too_long`; numeric range → `too_small` / `too_large`; format / enum → `invalid_value`). **Flag any mapping that disagrees.**

For every response (not just errors):

- Response carries an `X-Request-ID` header.
- On error responses, `error.request_id` equals the `X-Request-ID` header value for the same response.
- When no inbound `X-Request-ID` is supplied, the server-generated value is a 26-character Crockford base32 string (`[0-9A-HJKMNP-TV-Z]{26}` — note the excluded letters I, L, O, U).
- When inbound `X-Request-ID: probe-abc-123` is supplied, the response's `X-Request-ID` is exactly `probe-abc-123` (echoed unchanged, not replaced).

## Report findings

Lead with any claim that was **falsified** — that is the primary finding. For each falsified claim, include:

- The request (method, path, headers, redacted body).
- The response (status, headers, body).
- The specific docs sentence that disagrees with the observed behavior.

Then list claims that were **confirmed** as a compact checklist. Anything you could not probe (e.g. no endpoint available that accepts a numeric field with a `max` bound) — say so explicitly; do not silently skip it.

## Cleanup

Delete any API keys or artifacts you create before ending the session. Leave pre-existing artifacts alone.
