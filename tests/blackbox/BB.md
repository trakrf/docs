# trakrf API — black-box evaluation

Your manager saw TrakRF on LinkedIn and dropped you the creds: "see if this tool is any good and if it can connect to our systems."

You know nothing about TrakRF. Everything you report comes from what you can
verify — not prior knowledge.

**Allowed tools — work only from what a customer developer has:**
- The API itself (the URL in `API_TEST_APP_URL`)
- The public docs site (the URL in `API_TEST_DOCS_URL`)
- HTTP clients you'd reach for naturally — curl, Postman, or any language's
  HTTP library
- Standard OpenAPI codegen tools (openapi-generator-cli, openapi-typescript,
  swagger-codegen) operating on the public spec
- The credentials in `API_TEST_LOGIN` / `API_TEST_PASS`
- File operations in your current working directory (for notes, scratch files,
  and the final FINDINGS.md)

**Everything else is out of scope.** If you're about to use a tool that isn't
on the list above, stop. A developer who saw TrakRF on LinkedIn 10 minutes ago
doesn't have it.

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

**If onboarding fails before you can authenticate against the API, that is the report.** Document the failure point with verbatim error output and stop. Do not infer findings about endpoints you couldn't reach. A short report that says "I could not get past step 3 of the quickstart, here is exactly what I saw" is more useful than a long report padded with speculation.

## OpenAPI spec contract check

After your exploratory evaluation, run a mechanical pass against the published OpenAPI spec. An integration partner will auto-generate a connector from this spec — if the spec and the service disagree, the connector breaks.

1. **Fetch the spec.** The OpenAPI spec is published at `$API_TEST_DOCS_URL/redocusaurus/trakrf-api.yaml`. If that path 404s, that is itself a finding worth reporting. If the docs don't link to it from a discoverable location, that's also a finding.

2. **Walk every path.** For each endpoint in the spec, make a real call (with your API key) and verify:
   - Does the endpoint respond at all? (404 = spec lies about the route)
   - Does the response status code match one of the declared responses?
   - Does the response body shape match the declared schema? Look for: undocumented fields in the response, fields declared in the schema but missing from the response, type mismatches (string vs number vs null).

3. **CRUD lifecycle.** For resources that support create/read/update/delete: create a resource, read it back, update it, read again, delete it, confirm deletion. Verify each step's response matches the spec. Clean up anything you create.

4. **Pagination boundaries.** Page through at least one collection endpoint fully. Verify `total_count` matches the actual number of items returned across all pages. Test: `limit=1` (minimum page), `limit=200` (documented max), `limit=201` (should reject).

5. **Codegen smoke test.** Generate a client from the spec using whichever standard tool you'd naturally reach for (openapi-generator-cli, openapi-typescript, swagger-codegen, or equivalent). Run a CRUD lifecycle through the generated client against the live service. Report:
   - Compile errors or codegen failures
   - Runtime deserialization errors against real responses
   - Cases where a fetched object cannot be round-tripped back into a write call (field name mismatches between read and write schemas, type asymmetries, missing or polysemic identifiers)
   - Authentication setup friction — does the generated client know how to attach the API key from the spec alone, or did you have to wire it manually?

   This catches a different class of issue than the manual walk: type collisions, missing security blocks, polysemic field names that compile but produce nonsense at runtime.

Report spec-vs-service mismatches separately from the doc-vs-service findings in the exploratory pass. These are two different source-of-truth documents that can disagree with each other and with the live service.

## Report findings

Write up findings to FINDINGS.md at the end of the session. Lead with documentation and workflow gaps; treat API bugs as supporting evidence tied to the workflow step that surfaced them. Report spec contract mismatches in their own section.

### Context block (lead the report)

Begin FINDINGS.md with a context block recording:

- Environment URL (`API_TEST_APP_URL` value)
- Docs URL (`API_TEST_DOCS_URL` value)
- Spec/build version — fetch `$API_TEST_DOCS_URL/health.json` and record what it returns. If `/health.json` 404s, that's a finding; record what you did get.
- HTTP client(s) used in the exploratory pass (curl, Python `requests`, Node `fetch`, generated TypeScript client, etc.)
- Codegen tool and version used in step 5
- Date and time of the run (UTC)

Cycles aren't comparable without this. The orchestrator running the eval will add a cycle label (BB13, BB14, …) on triage; you don't need to assign one yourself.

### Terminology coherence pass

Independent of correctness, do one pass focused on vocabulary:

1. List every domain term that appears in the API surface (path params, field names, schema names, query params).
2. For each term, write a one-sentence definition based on context.
3. Flag any term that has multiple incompatible definitions across the spec, OR any term where two definitions only differ by qualifier ("customer X" vs "tag X") that gets stripped in code/URL surfaces.

Report these as "coherence findings" separately from correctness findings. A coherent vocabulary is a precondition for an AI-driven integration partner to reason about the API. Substring overlap defeats qualifier-based disambiguation in any context where the qualifier isn't visible (URL path segments, generated identifier types, log lines).

### Triage: would an AI integration partner trip on this?

For each finding, tag it with: would an AI-driven integration partner running ingestion against this API trip on it?

- **Yes** → pre-launch (Launch label, Todo).
- **No** — internal hygiene, polish, or DX improvement that doesn't break integration → post-launch (post-v1 label, Backlog).

Use this framing instead of abstract High/Medium/Low priority. Integration partners are the realistic first audience for the public API, and "trips an AI ingestor" is a concrete test that "Medium priority" is not.

## Cleanup

Delete any API keys or artifacts you create before ending the session. Leave pre-existing artifacts alone.
