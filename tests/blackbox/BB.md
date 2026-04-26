# trakrf API — black-box evaluation

Your manager saw TrakRF on LinkedIn and dropped you the creds: "see if this tool is any good and if it can connect to our systems."

You know nothing about TrakRF. Everything you report comes from what you can verify — not prior knowledge. **Do not read any issue trackers, pull requests, source code, or internal documentation.** Your only inputs are the docs URL, the app URL, and the credentials. If a tool gives you access to something a customer developer wouldn't have, don't use it.

## Environment

`.envrc` + `.env.local` expose four vars via direnv:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `API_TEST_LOGIN` — admin account email
- `API_TEST_PASS` — admin account password

**Do not echo `API_TEST_PASS` or pass it as a literal in tool-call arguments.** Reference it through env var expansion or your language's env-reading APIs.

## Mission

Read the docs. Set up an API key. Call the API. Evaluate the experience.

Use whichever HTTP client / language you'd naturally reach for. The variation between test runs is intentional.

**Focus on documentation and workflow gaps, not just API bugs.** At each step ask: could a new developer get from "I have a login" to "I am calling the API" using only what the docs say? Where do they have to guess, get stuck, or contact support?

Verify every claim in the docs against the live service. When the docs and the service disagree, that is a primary finding. Check both the OpenAPI spec AND the prose quickstart / tutorial pages — the two can drift independently. Generated-client users hit the spec; humans following the docs hit the prose pages.

## OpenAPI spec contract check

After your exploratory evaluation, run a mechanical pass against the published OpenAPI spec. An integration partner will auto-generate a connector from this spec — if the spec and the service disagree, the connector breaks.

1. **Fetch the spec.** The OpenAPI spec is published at `$API_TEST_DOCS_URL/redocusaurus/trakrf-api.yaml`. If that path 404s, that is itself a finding worth reporting. If the docs don't link to it from a discoverable location, that's also a finding.

2. **Walk every path.** For each endpoint in the spec, make a real call (with your API key) and verify:
   - Does the endpoint respond at all? (404 = spec lies about the route)
   - Does the response status code match one of the declared responses?
   - Does the response body shape match the declared schema? Look for: undocumented fields in the response, fields declared in the schema but missing from the response, type mismatches (string vs number vs null).

3. **CRUD lifecycle.** For resources that support create/read/update/delete: create a resource, read it back, update it, read again, delete it, confirm deletion. Verify each step's response matches the spec. Clean up anything you create.

4. **Pagination boundaries.** Page through at least one collection endpoint fully. Verify `total_count` matches the actual number of items returned across all pages. Test: `limit=1` (minimum page), `limit=200` (documented max), `limit=201` (should reject).

Report spec-vs-service mismatches separately from the doc-vs-service findings in the exploratory pass. These are two different source-of-truth documents that can disagree with each other and with the live service.

## Report findings

Write up findings to FINDINGS.md at the end of the session. Lead with documentation and workflow gaps; treat API bugs as supporting evidence tied to the workflow step that surfaced them. Report spec contract mismatches in their own section.

## Cleanup

Delete any API keys or artifacts you create before ending the session. Leave pre-existing artifacts alone.
