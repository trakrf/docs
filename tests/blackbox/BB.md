# trakrf API — black-box evaluation

You have a TrakRF login at `$API_TEST_APP_URL` (`$API_TEST_LOGIN` / `$API_TEST_PASS`). See if this tool can connect to your systems.

You know nothing about TrakRF. Everything you report comes from what you can
verify — not prior knowledge.

**Allowed tools — work only from what a customer developer has:**

- The SPA at `$API_TEST_APP_URL` (log in with the credentials in `$API_TEST_LOGIN` / `$API_TEST_PASS`)
- The public docs site at `$API_TEST_DOCS_URL`
- The API itself (same base URL as the SPA)
- HTTP clients you'd reach for naturally — curl, Postman, or any language's
  HTTP library
- Standard OpenAPI codegen tools (openapi-generator-cli, openapi-typescript,
  swagger-codegen) operating on the public spec
- File operations in your current working directory (for notes, scratch files,
  and the final FINDINGS.md)

**Everything else is out of scope.** If you're about to use a tool that isn't on the list above, stop.

If you find yourself blocked by a UI step during onboarding, document the friction but don't try to circumvent it (e.g., by reverse-engineering the SPA bundle to find internal endpoints). The SPA flow is the supported onboarding path; reverse-engineering Internal endpoints generates findings about contracts we've explicitly disowned.

## Out-of-scope workflow observations

The following are acknowledged design state, not workflow gaps. Do not flag as findings:

- **No programmatic API key mint.** Key issuance is bound to user identity through the SPA, by design. The SPA mint flow is the supported onboarding path for both human and automated/headless callers — automated callers mint a key out-of-band and store it in their secrets infrastructure (this matches how Stripe API keys work). A programmatic seam is YAGNI for v1; the team will revisit if a customer surfaces real demand.
- **`/auth/login` is Internal.** Listed in `private-endpoints.md` as Internal / subject to change without notice. Do not investigate, integrate against, or report on it. Treat as out-of-scope even though it appears in the docs.
- **No session-only key list/revoke endpoints in the API.** Listing and revocation are SPA-side affordances only. Documented as session-only, not exposed to the API surface.

Document the existence of these constraints in your environment summary if relevant for context, but they should not appear in the findings sections.

## Environment

`.envrc` + `.env.local` expose four vars via direnv:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `API_TEST_LOGIN` — admin account email
- `API_TEST_PASS` — admin account password

**Do not echo `API_TEST_PASS` or pass it as a literal in tool-call arguments.** Reference it through env var expansion or your language's env-reading APIs.

## Tooling notes

When this evaluation runs through a Playwright MCP-driven browser harness, the literal-password rule above and the supported SPA mint flow are jointly unsatisfiable: the `browser_type` tool has no env-variable substitution, so the password has to appear in the call as a literal. A real customer developer typing into a real browser doesn't hit this — it's a tooling artifact, not a TrakRF design issue. A loopback HTTP shim that reads the password server-side and injects it into the page via `<script src=...>` or `fetch(...)` is blocked by Chrome's Private Network Access policy when initiated from the public docs origin; don't re-attempt that path.

Within the Playwright MCP environment, the literal-password constraint may be relaxed for **a single `browser_type` call to the SPA mint/login form's password field**, under these conditions:

- The literal appears in exactly one tool call — the password field of the SPA login/mint form.
- The password is not echoed back into chat output.
- The password is not written to disk — no scratch files, notes, `FINDINGS.md`, or screenshots that capture the field.

The exception does not extend to any other tool call. `curl`, `fetch`, file writes, log statements, and any other surface where the literal could land remain forbidden. This is one named hole in the harness boundary, not a license to spread the literal through the run.

## Mission

Read the docs. Set up an API key. Call the API. Evaluate the experience.

Use whichever HTTP client / language you'd naturally reach for. The variation between test runs is intentional.

**Focus on documentation and workflow gaps, not just API bugs.** At each step ask: could a new developer get from "I have a login" to "I am calling the API" using only what the docs say? Where do they have to guess, get stuck, or contact support?

Verify every claim in the docs against the live service. When the docs and the service disagree, that is a primary finding. Check both the OpenAPI spec AND the prose quickstart / tutorial pages — the two can drift independently. Generated-client users hit the spec; humans following the prose pages hit the prose.

**If onboarding fails before you can authenticate against the API, that is the report.** Document the failure point with verbatim error output and stop. Do not infer findings about endpoints you couldn't reach. A short report that says "I could not get past step 3 of the quickstart, here is exactly what I saw" is more useful than a long report padded with speculation.

## OpenAPI spec contract check

After your exploratory evaluation, run a mechanical pass against the published OpenAPI spec. An integration partner will auto-generate a connector from this spec — if the spec and the service disagree, the connector breaks.

### 1. Fetch the spec

The OpenAPI spec is published at `$API_TEST_DOCS_URL/api/openapi.yaml` (JSON variant: `$API_TEST_DOCS_URL/api/openapi.json`). If that path 404s, that is itself a finding worth reporting. If the docs don't link to it from a discoverable location, that's also a finding.

The docs origin 302-redirects these paths to the platform's canonical spec on `app.{env}.trakrf.id/api/v1/openapi.{yaml,json}` — single source of truth, no mirror. Standard tooling follows the redirect transparently (curl with `-L`, every OpenAPI codegen client, every API-explorer import-by-URL flow). The spec at this URL is the contract you're testing against.

### 2. Walk every path

For each endpoint in the spec, make a real call (with your API key) and verify:

- Does the endpoint respond at all? (404 = spec lies about the route)
- Does the response status code match one of the declared responses?
- Does the response body shape match the declared schema? Look for: undocumented fields in the response, fields declared in the schema but missing from the response, type mismatches (string vs number vs null).
- Does the response include any headers the spec doesn't declare? Compare against the spec's declared response headers — rate-limit headers, request-id, auth challenge headers, retry-after, etc.

### 3. CRUD lifecycle with round-trip verification

For resources that support create/read/update/delete: create a resource, read it back, update it, read again, delete it, confirm deletion. Verify each step's response matches the spec. Clean up anything you create.

**Then run round-trip mutation probes** — the failure modes here are silent and a careful integrator will hit them:

- **Full-object round-trip.** GET a resource. Modify one or two fields. Send the whole object back via the update verb. GET again. Are unchanged fields preserved? Did the modified fields persist? Did any field silently drop or revert?
- **Read-only field round-trip.** Take the GET response. Re-send it verbatim via the update verb (including any `id`, `created_at`, `updated_at`, `*_deleted_at` fields). Does the service accept it? Reject it? Silently strip the read-only fields? The behavior should match what the spec/docs describe.
- **Nested-collection round-trip.** If the response includes nested collections (tags, identifiers, children, ancestors), modify the collection (add/remove an item) and send the whole object back. Does the update verb honor the collection edit, or are nested collections write-only via subresources? If the latter, is that asymmetry documented?
- **Empty-body update.** Send `{}` to the update verb. What happens? 200 with unchanged state? 400 with a "no fields to update" message? Whichever it is, does it match the docs?

### 4. Verb semantics against RFC

Check that HTTP verbs match the operation semantics:

- If the operation body description uses partial-update language ("only fields included…", "merge", "patch"), the verb should be `PATCH` per RFC 5789 with `Content-Type: application/merge-patch+json` per RFC 7396.
- If the operation body description says "replace" or "set" the resource, the verb should be `PUT` per RFC 7231 §4.3.4 (full-replace).
- Flag any mismatch — `PUT` with PATCH semantics or `PATCH` with PUT semantics. Generated typed clients model verb semantics differently and will produce wrong-shaped methods if the verb is wrong.

### 5. Mutability probes on natural-key fields

For every field the docs describe as a "natural key," "identifier," or "join key" (e.g., `external_key`, code fields, slug-like identifiers):

- Try mutating the field via the update verb. Does the service accept it? If yes, what happens to dependent state? Derived fields like `tree_path`? Scan history attached to the old key? Downstream joins?
- If mutation is supported, is the operation distinguishable from a regular update? Different verb? Different scope? Separate `/rename` operation? Different audit log entry?
- If mutation is not supported, does the service reject it with a clear error envelope? Is the immutability documented?
- If the field is documented as immutable but the service allows it, that's a finding. If the docs are silent and the service allows it, that's also a finding — silent mutability of a join key is a data-integrity footgun.

### 6. Cross-resource asymmetry probes

Compare create-shape, update-shape, and field-shape across analogous resources (assets/locations, etc.):

- Required fields on create. If `Foo.external_key` is required on POST /foos but `Bar.external_key` is optional (or auto-minted) on POST /bars, that's asymmetric. Is the asymmetry documented with rationale? Is it deliberate or accidental?
- Validator strictness across resources. If `POST /foos` rejects empty-string for a field but `POST /bars` accepts it (or vice versa), that's asymmetric.
- Read/write field shape. Does `FooView` carry fields that `UpdateFooRequest` doesn't include? If so, are those fields read-only? Server-derived? Subresource-managed? Flag asymmetries that aren't explained.
- Verb coverage. Does every resource expose the same CRUD verbs? If `/foos/{id}` supports DELETE but `/bars/{id}` doesn't, that's asymmetric — and probably intentional, but the rationale should be visible.

### 7. Silent coercion probes on body fields

For every typed field in request bodies (especially `date-time`, `integer`, `boolean`, enum-typed), try:

- Loose forms of the type — date-only strings against `date-time`, slash-separated dates, scientific notation against `integer`, "true"/"false" strings against `boolean`. Does the validator reject, or silently coerce?
- Empty string. Many validators treat `""` as "field omitted" or substitute a default. If empty-string-as-default is the intent, that's fine and should be documented. If empty string is silently substituted for a server-computed default (auto-mint, "now" timestamp, zero value), that's a footgun for partial-row imports.
- Zero values and language sentinels — `0`, `null`, `0001-01-01T00:00:00Z` (Go zero-time), `1970-01-01T00:00:00Z` (Unix epoch as default). Does the service treat these as legitimate values or silently substitute a default?
- Precision edge cases — sub-second precision in timestamps, scientific notation in integers, very large integers, very small floats. Does the service round, truncate, reject, or coerce?

The shared concern: integrators paste localized or partial data into requests, get back records that look correct but were silently transformed. The behavior should be either strict (reject) or documented (here's exactly what we substitute and why).

### 8. Error envelope force-and-verify

For every error type declared in the spec (`validation_error`, `unauthorized`, `forbidden`, `not_found`, `conflict`, etc.), force the error and verify the envelope shape matches exactly:

- 401 — no auth header, malformed bearer, expired bearer, wrong-scheme header (`X-API-Key` instead of `Authorization`).
- 403 — valid auth but missing scope. (Requires minting a narrower key; if you can't, note that.)
- 400 — validation_error with each subtype (`required`, `too_short`, `too_long`, `too_small`, `too_large`, `invalid_value`, `unknown field`).
- 404 — resource id that doesn't exist.
- 405 — wrong method on a real path. Verify the `Allow` header.
- 409 — known conflict cases (duplicate `external_key`, non-leaf delete, etc.).
- 415 — wrong `Content-Type`.

Check: are all declared fields present (`type`/`title`/`status`/`detail`/`instance`/`request_id`)? Are validation errors well-formed (`fields[]` with `field`/`code`/`message`/`params`)? Are documented detail strings reproducible verbatim?

Also check the response headers on errors: are rate-limit headers present? Is `WWW-Authenticate` declared and emitted on 401? Is `X-Request-Id` present and traceable to the body's `request_id`?

### 9. Pagination boundaries

Page through at least one collection endpoint fully. Verify `total_count` matches the actual number of items returned across all pages. Test: `limit=1` (minimum page), `limit=200` (documented max), `limit=201` (should reject with `validation_error` / `too_large` and `params.max=200`). Test `limit=0` and `limit=-1` (should reject with `validation_error` / `too_small`). Test `offset` past `total_count` (should return empty page, not error).

### 10. Codegen smoke test (multi-stack)

Generate clients from the spec using **at least two** standard tools across different languages. The list to choose from:

- `openapi-typescript` + `openapi-fetch` (TypeScript types + thin runtime)
- `openapi-generator-cli` with Python target (full client with Pydantic models)
- `openapi-generator-cli` with Java/Kotlin target
- `swagger-codegen` with Go target
- Any other generator you'd reach for naturally

Running one codegen pass catches obvious shape issues. Running two catches generator-specific issues — TypeScript coerces types where Python's Pydantic strict mode rejects; Python's class naming reveals dotted-prefix issues that TypeScript flattens silently; Java's strict number types reveal int-vs-float ambiguity that JavaScript papers over.

For each generator, run a CRUD lifecycle through the generated client against the live service. Report:

- Compile errors or codegen failures.
- Runtime deserialization errors against real responses.
- Cases where a fetched object cannot be round-tripped back into a write call (field name mismatches between read and write schemas, type asymmetries, missing or polysemic identifiers).
- Authentication setup friction — does the generated client know how to attach the API key from the spec alone, or did you have to wire it manually?
- Generated identifier names — are model class names, method names, and field names clean and conventional in the target language? Flag double-prefixed names (e.g., `AssetPublicAssetView` where the spec schema is `asset.PublicAssetView`), unusual casing (`assets_create` where `createAsset` is conventional), or names that leak the backend's package/namespace structure into the client.

### 11. Multi-format spec consistency

The spec may be served in multiple formats (YAML, JSON, Redoc-served copy). Fetch each variant and compare:

- Are the artifacts byte-equivalent after canonical sort?
- Do numeric literals match across formats? YAML scientific notation (`2.147483647e+09`) parses as float in standard YAML loaders, even when paired with `type: integer` — flag any divergence between YAML and JSON variants for the same field.
- Do any artifacts contain hardcoded URLs that differ from the environment the spec is served from (preview spec hardcoding production docs URL, etc.)?
- Are all variants linked from at least one discoverable docs page? An undiscoverable artifact is a finding.

Report spec-vs-service mismatches separately from the doc-vs-service findings in the exploratory pass. These are two different source-of-truth documents that can disagree with each other and with the live service.

## Cross-document consistency check

The docs span multiple pages and the spec. Drift between them is a primary finding class. For each major page:

- Pick a non-trivial claim (a behavior, a constraint, a default value, an example). Verify it against the live service. Note any disagreement.
- Compare overlapping content between pages. If two pages document the same operation, do they say the same thing? Where they differ in detail, which is canonical?
- For prose pages that include code examples (`curl` invocations, generated client snippets), run the examples verbatim. Do they work? Do they produce the documented output?
- For docs that recommend a pattern (e.g., "watch X header to pace requests"), verify the pattern actually works against the live service. A documented but unworkable pattern is a finding.

The relationship between the spec and the prose is the load-bearing axis here. The spec is the contract for generated-client users; the prose is the contract for humans. Both audiences read the docs literally; both can be misled by the same prose for different reasons. Always check both.

## Report findings

### Consult the project registries before filing

Before classifying a finding as novel, consult both project registries:

1. [`/docs/api/design-notes`]($API_TEST_DOCS_URL/docs/api/design-notes) — customer-visible design choices. If the finding matches a documented choice, classify it as a **DESIGN NOTE** confirmation.
2. [`BACKLOG.md`](./BACKLOG.md) — internal-only deliberate states and deferred work. If the finding matches a registry entry, classify as **INTERNAL DELIBERATE STATE** or **DEFERRED WORK** accordingly.

Documented decisions shouldn't be re-litigated unless the underlying rationale has changed. See [Triage taxonomy](#triage-taxonomy) below for the exact FINDINGS.md format for each class.

BB.md itself is pure methodology — project-specific content (design choices, deferred work, internal deliberate states) lives in the two registries above, not in this file. The next API project forks BB.md unchanged and starts fresh `design-notes` and `BACKLOG.md` artifacts.

### Before flagging a docs gap

If you're about to write "X is never documented," search the docs site for X first and read at least the first hit. The docs span multiple pages — absence in `quickstart.mdx` doesn't mean absence in `resource-identifiers.md` or elsewhere. The motivating example: a recent cycle reported `tree_path` as undocumented while `resource-identifiers.md` carries the canonical definition.

Write up findings to FINDINGS.md at the end of the session. Lead with documentation and workflow gaps; treat API bugs as supporting evidence tied to the workflow step that surfaced them. Report spec contract mismatches in their own section.

### Context block (lead the report)

Begin FINDINGS.md with a context block recording:

- Environment URL (`API_TEST_APP_URL` value)
- Docs URL (`API_TEST_DOCS_URL` value)
- Spec/build version — fetch `$API_TEST_DOCS_URL/health.json` and record what it returns. If `/health.json` 404s, that's a finding; record what you did get.
- HTTP client(s) used in the exploratory pass (curl, Python `requests`, Node `fetch`, generated TypeScript client, etc.)
- Codegen tool(s) and version(s) used in step 10 — list each separately
- Date and time of the run (UTC)

Cycles aren't comparable without this. The orchestrator running the eval will add a cycle label (BB13, BB14, …) on triage; you don't need to assign one yourself.

### Terminology coherence pass

Independent of correctness, do one pass focused on vocabulary:

1. List every domain term that appears in the API surface (path params, field names, schema names, query params).
2. For each term, write a one-sentence definition based on context.
3. Flag any term that has multiple incompatible definitions across the spec, OR any term where two definitions only differ by qualifier ("customer X" vs "tag X") that gets stripped in code/URL surfaces.
4. Flag any term that is used as both a resource noun and a discriminator value within that resource (e.g., a `Tag` schema with a `tag_type` field where the resource accepts multiple `tag_type`s — the resource noun is polymorphic but reads as singular).
5. Flag any path tree that implies a different scope or schema namespace than the actual implementation (e.g., a path under `/locations/` whose response is asset-centric report data scoped to `history:read`).
6. Flag any derived field that's lossy and might be misused as a join key (e.g., a server-derived path that's case-folded or character-substituted from the original natural key — joining cross-system on the derived form will match more permissively than intended).

Report these as "coherence findings" separately from correctness findings. A coherent vocabulary is a precondition for an AI-driven integration partner to reason about the API. Substring overlap defeats qualifier-based disambiguation in any context where the qualifier isn't visible (URL path segments, generated identifier types, log lines).

### Triage taxonomy

Each finding gets explicit triage on two independent axes. The primary axis (severity) determines pre-ship vs post-ship; the secondary axis (economic disposition) determines whether to act on the finding or document a deliberate state.

#### Primary axis: severity (impact)

- **Contract breakage:** generated clients break, integrators get wrong behavior, the API surface lies about itself in a way that produces silent wrong-data. MUST fix pre-ship. The bar:
  - Would a careful integrator silently lose data, misclassify data, or write code that compiles but produces nonsense at runtime?
  - Would a generated client emit method/class names that an integrator would refactor before checking in?
  - Would the integrator have to read multiple pages or hit the service with trial-and-error to learn a contract the docs should have stated directly?
- **Hygiene / cosmetic:** the spec describes the same thing the service emits, just suboptimally. Doesn't break anything; could ship as-is. The bar:
  - Cosmetic naming or organization concerns that an integrator would file as feedback, not as a bug.
  - DX improvements that would be nice but don't block any documented use case.
  - Findings whose fix would be a breaking change with low integrator-impact.

Use this framing instead of abstract High/Medium/Low priority. Integration partners are the realistic first audience for the public API, and "would this trip an AI integration partner" is the concrete test behind the severity bar.

#### Secondary axis: economic disposition (cost-benefit)

- **Fix now:** cheap fix relative to permanent tracking cost. Do it regardless of severity.
- **Defer with intent:** real fix exists but cost-benefit deliberately chose to wait. Has a documented trigger condition for revisit (e.g., "when cloud catches up to preview AND customer volume hits threshold X").
- **Won't fix:** deliberate state, not a bug, just looks like one to a naive observer. Documented for future cycles. No trigger condition — would only revisit if underlying constraints change.

#### Interaction matrix

|                       | Fix now            | Defer with intent                                           | Won't fix                                                                                                                         |
| --------------------- | ------------------ | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| **Contract breakage** | Pre-ship (default) | Pre-ship anyway (unusual; means the fix is itself breaking) | (rare — would mean breakage is bounded and the fix is disruptive)                                                                 |
| **Hygiene**           | Pre-ship (cheap)   | Post-ship backlog ([`BACKLOG.md`](./BACKLOG.md))            | [`/docs/api/design-notes`]($API_TEST_DOCS_URL/docs/api/design-notes) (customer-facing) or [`BACKLOG.md`](./BACKLOG.md) (internal) |

Integrator-visible deliberate states live in `/docs/api/design-notes`. Harness-only deliberate states and deferred work with trigger conditions live in `BACKLOG.md`. BB.md does not duplicate either.

#### FINDINGS.md format

Each novel finding in FINDINGS.md is tagged with both axes:

```
F1. <finding title>. (Severity: contract breakage | hygiene; Disposition: fix now | defer | won't fix)
```

For known design notes surfaced again:

```
F1. <finding title>. (DESIGN NOTE — see /docs/api/design-notes; no action)
```

For internal-only deliberate states surfaced again:

```
F1. <finding title>. (INTERNAL DELIBERATE STATE — see BACKLOG.md; no action)
```

For deferred work surfaced again:

```
F1. <finding title>. (DEFERRED WORK — see BACKLOG.md, triggered by X; no action)
```

This makes the cycle's finding count honest: a probe that surfaces 5 things where 3 are design-note or backlog confirmations is "2 actionable findings + 3 confirmations," not "5 findings."

## Cleanup

Delete any API keys or artifacts you create before ending the session. Leave pre-existing artifacts alone.

If the test fixture has accumulated soft-deleted rows from prior cycles that interfere with your probes (e.g., `?include_deleted=true` returns dramatically more rows than the default), note it in the report but don't try to clean up prior cycles' artifacts — the orchestrator handles fixture maintenance.
