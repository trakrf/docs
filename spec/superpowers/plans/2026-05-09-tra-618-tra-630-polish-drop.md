# TRA-618 + TRA-626 + TRA-630 — BB19/BB20 docs polish drop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one docs PR closing the docs-side leftovers from BB19/BB20 polish (TRA-618 W2/W3/W4/C3/C5, TRA-630 §C3/§C5) plus the OpenAPI spec mirror refresh that picks up platform PR #277 (TRA-626, TRA-618 §S3/§S4, TRA-630 §S5).

**Architecture:** No code; this is documentation surgery against `docs/api/`, `docs/user-guide/`, `docs/integrations/`, and the published spec mirror in `static/api/`. The spec is pulled, not edited; the prose changes are mechanical — UI label drift, an org→organization sweep across customer-facing files, two new short subsections in resource-identifiers.md and authentication.md, and a strengthened expiration caveat. One commit per file group keeps the diff reviewable.

**Tech Stack:** Docusaurus 3, Markdown / MDX, `pnpm`, prettier (formatter only — no test runner for prose; `pnpm build` and `pnpm lint` are the gates).

---

## File structure

| Layer                        | Files touched                                                                                                                                 | Reason                                                          |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| OpenAPI spec mirror          | `static/api/openapi.json`, `static/api/openapi.yaml`, `static/api/platform-meta.json`, `static/api/trakrf-api.postman_collection.json`        | Refresh from platform PR #277 via `scripts/refresh-openapi.sh`. |
| API docs (substantive edits) | `docs/api/authentication.md`, `docs/api/resource-identifiers.md`, `docs/api/errors.md`                                                        | New sections + label drift + cycle-citation rewrite.            |
| API docs (sweep edits)       | `docs/api/quickstart.mdx`, `docs/api/private-endpoints.md`, `docs/api/webhooks.md`                                                            | One- or two-line org→organization swaps + Read+Write.           |
| Non-API docs (sweep edits)   | `docs/user-guide/asset-management.md`, `docs/integrations/index.md`                                                                           | One-line org→organization swaps.                                |
| Spec/plan artifacts          | `spec/superpowers/specs/2026-05-09-tra-618-tra-630-polish-drop-design.md`, `spec/superpowers/plans/2026-05-09-tra-618-tra-630-polish-drop.md` | Already written; commit alongside the docs PR.                  |

No new files, no new components, no test infrastructure changes.

---

## Task 1: Branch + spec mirror refresh

**Files:**

- Modify: `static/api/openapi.json`
- Modify: `static/api/openapi.yaml`
- Modify: `static/api/platform-meta.json`
- Modify: `static/api/trakrf-api.postman_collection.json`

- [ ] **Step 1: Create branch off main**

```bash
git switch -c miks2u/tra-618-tra-630-bb19-bb20-polish-drop
```

- [ ] **Step 2: Confirm branch is clean and based on latest main**

Run: `git status && git log --oneline -1`
Expected: clean working tree; HEAD at the most recent main commit (`61668c7` or newer).

- [ ] **Step 3: Refresh the spec mirror**

Run: `./scripts/refresh-openapi.sh`
Expected output ends with `Wrote static/api/platform-meta.json (trakrf/platform@<sha>)`. The fetched paths list includes `/api/v1/assets`, `/api/v1/locations`, `/api/v1/locations/current`, `/api/v1/orgs/me`, etc.

- [ ] **Step 4: Sanity-check the diff**

Run: `git diff static/api/openapi.yaml | grep -E "^\+.*(minimum:|maximum:|format: date-time|explode:|style: form)" | head -30`
Expected: see `minimum: 1`, `maximum: 200`, `maximum: 2147483647`, `format: date-time`, `style: form`, `explode: true` / `explode: false` lines added — confirming platform PR #277 changes are in the fetched spec.

- [ ] **Step 5: Commit the spec refresh**

```bash
git add static/api/openapi.json static/api/openapi.yaml static/api/platform-meta.json static/api/trakrf-api.postman_collection.json
git commit -m "chore(api): refresh OpenAPI spec mirror to pick up platform PR #277

TRA-618 §S3+§S4 (limit/offset/path-param bounds), TRA-626 (repeatable
filter arrays + from/to date-time format), TRA-630 §S5 (sort style/explode
pinning). Fetched via scripts/refresh-openapi.sh; no manual edits."
```

---

## Task 2: authentication.md — Read+Write label drift, session-only key affordances, Never-expiration caveat, org→organization

**Files:**

- Modify: `docs/api/authentication.md`

- [ ] **Step 1: Replace `Read+Write` → `Read + Write` (3 occurrences)**

Run:

```bash
grep -n "Read+Write" docs/api/authentication.md
```

Expected: lines 48, 53, 55, 59 (four matches; one is in a code-block-adjacent prose run).

Use `Edit` with `replace_all: true` on the literal string `Read+Write` → `Read + Write`. After the replace, re-run the grep:

```bash
grep -n "Read+Write" docs/api/authentication.md
```

Expected: no matches.

- [ ] **Step 2: §C5 — fix the three `org` prose instances on line 21**

Replace the bullet at line 21 by editing the exact paragraph:

Old:

```markdown
3. **If your account belongs to multiple organizations,** API keys are scoped to whichever org is currently selected in the avatar menu. Check the org switcher before clicking **New key** — a key minted under the wrong org cannot be reassigned.
```

New:

```markdown
3. **If your account belongs to multiple organizations,** API keys are scoped to whichever organization is currently selected in the avatar menu. Check the organization switcher before clicking **New key** — a key minted under the wrong organization cannot be reassigned.
```

- [ ] **Step 3: §W4 — strengthen the Expiration bullet with the codegen no-`exp` caveat**

Replace the existing Expiration bullet (currently on line ~129):

Old:

```markdown
- **Expiration:** keys do not expire by default — leaving the field blank at creation mints a permanent credential with no `exp` claim. For any key beyond a throwaway local-dev credential, set an explicit expiration (e.g. 90 days) and schedule the rotation. Expired keys return `401 unauthorized`.
```

New:

```markdown
- **Expiration:** keys do not expire by default — leaving the field blank (the **Never** option in the SPA picker) mints a permanent credential with no `exp` claim. Generated clients that auto-refresh on `exp` will treat such a key as immortal and never trigger their own rotation logic. For any key beyond a throwaway local-dev credential, set an explicit expiration (e.g. 90 days) and schedule the rotation. Expired keys return `401 unauthorized`.
```

- [ ] **Step 4: §W3 — insert the "Listing and revocation are SPA-side" subsection**

Append a new subsection immediately after the "Key lifecycle" bullet list (which currently ends with the Expiration bullet on line ~129) and before the "## Base URL" heading. Insert this block exactly as written:

```markdown
### Listing and revocation are SPA-side {#listing-revocation-spa-side}

Listing existing keys, viewing key metadata (name, scopes, created / last-used / expires timestamps), and revoking a key are all browser affordances in the SPA's **avatar menu → API Keys** view, not API endpoints. There is no `GET /api/v1/keys` or `DELETE /api/v1/keys/{id}` on the public surface in v1 — see [Where keys come from](#where-keys-come-from) for the design rationale (the same trust-boundary argument that gates programmatic key minting also gates programmatic key listing and revocation).

**Practical implication for partners automating rotation:** any rotation workflow that needs to enumerate or revoke prior keys has to drive the SPA flow (manual or scripted via a session login), or maintain its own out-of-band record of which key handles map to which integrations. If you have a use case that genuinely requires programmatic listing or revocation, [contact us](mailto:support@trakrf.id) — same evaluation track as programmatic key minting.
```

- [ ] **Step 5: Verify no other `\borg\b` customer-prose hits remain in this file**

Run:

```bash
grep -nE "\borg\b|\borgs\b" docs/api/authentication.md | grep -v "org_id\|/orgs/\|missing_org_context"
```

Expected: empty output (or only matches inside `org_id` / endpoint paths, which are technical surfaces and intentionally untouched).

- [ ] **Step 6: Build sanity check**

Run: `pnpm build 2>&1 | tail -20`
Expected: `[SUCCESS] Generated static files in "build".` No broken anchor warnings naming `mint-your-first-api-key`, `key-management-reserved`, `where-keys-come-from`, `listing-revocation-spa-side`, `ui-labels`.

- [ ] **Step 7: Format + commit**

```bash
pnpm dlx prettier --write docs/api/authentication.md
git add docs/api/authentication.md
git commit -m "docs(api): TRA-618 §W2+§W3+§W4+§C5 — auth label drift, session-only key affordances, Never expiration, org prose

- W2: align 'Read+Write' to SPA's 'Read + Write' label.
- W3: document that listing and revocation are SPA-side affordances; no
  /keys API in v1.
- W4: call out that 'Never' expiration mints a JWT with no exp claim,
  so generated-client auto-refresh never fires.
- C5: customer-facing prose 'org' -> 'organization' (3x on line 21)."
```

---

## Task 3: quickstart.mdx — Read+Write + org sweep

**Files:**

- Modify: `docs/api/quickstart.mdx`

- [ ] **Step 1: Replace `Read+Write` → `Read + Write` (1 occurrence)**

Edit the line at `docs/api/quickstart.mdx:89`. Old fragment:

```mdx
that's the **Assets** dropdown set to **Read+Write**.
```

New fragment:

```mdx
that's the **Assets** dropdown set to **Read + Write**.
```

- [ ] **Step 2: §C5 — fix `multi-org switcher` on line 32**

Edit the parenthetical near line 32. Old fragment:

```mdx
Full walkthrough (scope picker, expiration, multi-org switcher):
```

New fragment:

```mdx
Full walkthrough (scope picker, expiration, organization switcher):
```

(Drops the `multi-` prefix; the SPA picker is the same widget whether or not the user has multiple orgs, and "organization switcher" matches authentication.md's new wording.)

- [ ] **Step 3: §C5 — fix `the org you minted` on line 62**

Old fragment:

```mdx
If the `name` matches the org you minted the key under,
```

New fragment:

```mdx
If the `name` matches the organization you minted the key under,
```

- [ ] **Step 4: Verify no other prose `org` hits remain in this file**

Run:

```bash
grep -nE "\borg\b|\borgs\b" docs/api/quickstart.mdx | grep -v "/orgs/"
```

Expected: empty.

- [ ] **Step 5: Build sanity check**

Run: `pnpm build 2>&1 | tail -10`
Expected: success, no MDX parse errors.

- [ ] **Step 6: Format + commit**

```bash
pnpm dlx prettier --write docs/api/quickstart.mdx
git add docs/api/quickstart.mdx
git commit -m "docs(api): TRA-618 §W2 + TRA-630 §C5 — quickstart label drift + org prose

- W2: 'Read+Write' -> 'Read + Write' (matches SPA dropdown).
- C5: 'multi-org switcher' -> 'organization switcher'; 'the org you
  minted' -> 'the organization you minted'."
```

---

## Task 4: resource-identifiers.md — cycle-citation rewrite, metadata asymmetry, org sweep

**Files:**

- Modify: `docs/api/resource-identifiers.md`

- [ ] **Step 1: §C3 (BB19+BB20 §C1) — rewrite the cross-type-`id` collision paragraph**

Replace the block currently on lines 22–24. Keep the heading anchor (`### Numeric id collides across resource types`) so deep links stay valid.

Old block:

```markdown
### Numeric `id` collides across resource types

The integer `id` field on each schema is unique only within that resource type. Numeric values can collide across types — an asset and a tag may share the same integer `id`. (BB16 testing observed `790505327` as both an asset id and a location-tag id within a single org.)

When passing ids between systems, qualify them with the resource type (`asset_id`, `location_id`, `tag_id`). The string `external_key` field is unique within an org _and_ carries no cross-type ambiguity, so it's the safer cross-resource identifier when types may be mixed in flight.
```

New block:

```markdown
### Numeric `id` collides across resource types

Each integer `id` is unique only within its resource type. The same integer can appear as both an `asset_id` and a `tag_id` (or asset and location, etc.) within a single organization — they're independent sequences, and a low-millions value can show up on either surface.

When passing ids between systems, qualify them with the resource type (`asset_id`, `location_id`, `tag_id`) so a downstream consumer never has to guess which sequence the integer came from. The string `external_key` is unique within an organization _and_ carries no cross-type ambiguity, so it's the safer cross-resource identifier when types may be mixed in flight (audit logs, partner exports, ETL pipelines).
```

- [ ] **Step 2: §C5 — fix remaining `org` prose hits in this file**

Two sites:

- The `### Numeric id collides…` block above already replaces the two `single org` / `an org` prose mentions. Confirm nothing else slipped through.
- Line 182 already says "per-organization sequence" (correct, no change).
- Line 240 already says "within an organization" (correct, no change).

Run:

```bash
grep -nE "\borg\b|\borgs\b" docs/api/resource-identifiers.md | grep -v "/orgs/\|org_id\|missing_org_context"
```

Expected: empty.

- [ ] **Step 3: §C3 (BB20) — add the metadata-vs-no-metadata asymmetry subsection**

Insert a new short subsection immediately before the existing `## Read shape vs. write shape` heading (currently around line 101). Insert this block exactly as written:

```markdown
## Asset `metadata` vs. location `tags`: side-channel data {#asset-metadata-vs-location-tags}

`PublicAssetView` carries an open-ended `metadata` object (`additionalProperties: true`) for partner-side annotations the API does not interpret — a CRM record id, an ERP cost-center code, a partner SKU. Locations do **not** have a `metadata` field; the asymmetry is intentional for v1.

The pattern we recommend mirrors the schemas:

| Surface       | Where to put partner-side data                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Assets**    | `metadata` — free-form key/value, no schema, round-trips through `GET` → `PUT`.                  |
| **Locations** | `tags` — typed natural-key pairs (`tag_type`, `value`), enforced unique within the organization. |

Locations were not given an open `metadata` field because the practical "what would I stuff in here" use cases on a location (a CRM site id, a partner facility code) are already addressable through `tags` with a partner-defined `tag_type`. If you have a use case that genuinely needs schemaless side-channel data on a location, [contact us](mailto:support@trakrf.id) — same evaluation track as the v2 capability requests.
```

- [ ] **Step 4: Build + anchor sanity check**

Run: `pnpm build 2>&1 | tail -20`
Expected: success. No "anchor not found" warnings — the `#numeric-id-collides-across-resource-types` anchor is preserved by keeping the original heading text.

- [ ] **Step 5: Format + commit**

```bash
pnpm dlx prettier --write docs/api/resource-identifiers.md
git add docs/api/resource-identifiers.md
git commit -m "docs(api): TRA-618 §C3 + TRA-630 §C3+§C5 — id-collision rewrite + asset metadata asymmetry + org prose

- 618 §C3 (+ BB20 §C1 surrogate-key reframe): rewrite the numeric-id
  cross-type collision paragraph in customer voice; drop the BB16
  cycle citation and the literal '790505327' example.
- 630 §C3: document that assets carry free-form 'metadata' and
  locations do not — the asymmetry is intentional; locations use 'tags'
  for partner-side side-channel data.
- 630 §C5: 'single org' -> 'single organization', 'an org' ->
  'an organization' (covered by the rewrite block)."
```

---

## Task 5: errors.md — path-param 400 note + missing_org_context prose

**Files:**

- Modify: `docs/api/errors.md`

- [ ] **Step 1: Live-preview smoke check**

Confirm the new spec bounds actually surface as `400 validation_error` on the live preview before adding the wording. Run:

```bash
source .env
curl -sH "Authorization: Bearer $TRAKRF_API_KEY" "$TRAKRF_PREVIEW_URL/api/v1/assets/99999999999" | jq .error.type
```

Expected: `"validation_error"` (status code in the response will be 400). If the response is anything else (`"bad_request"`, `"not_found"`), **skip the path-param note in Step 2** and record the actual behavior in the PR description.

If the env vars aren't loaded, fall back to running the curl with the BASE_URL substituted manually. The point of this step is to verify the wording before committing it.

- [ ] **Step 2: Add the path-param out-of-range parenthetical to the `not_found` row**

Conditional on Step 1 returning `validation_error`. Edit the `not_found` row in the catalog table around line 65:

Old cell:

```markdown
| `not_found` | 404 | Resource lookup failed — path-param `id` doesn't resolve (`GET /api/v1/assets/99999`) or a sub-resource path doesn't exist (`GET /api/v1/assets/99999/history`). A list filter that resolves to zero rows returns 200 with empty `data[]`, not 404. | No — check the identifier |
```

New cell:

```markdown
| `not_found` | 404 | Resource lookup failed — path-param `id` doesn't resolve (`GET /api/v1/assets/99999`) or a sub-resource path doesn't exist (`GET /api/v1/assets/99999/history`). A list filter that resolves to zero rows returns 200 with empty `data[]`, not 404. Out-of-range numeric path params (e.g. `/api/v1/assets/99999999999`) are rejected as `400 validation_error` against the spec's `maximum: 2147483647` bound, not 404. | No — check the identifier |
```

- [ ] **Step 3: §C5 — expand `org` prose in the `missing_org_context` description**

Edit the row currently on line 69. Keep the type and title strings (`missing_org_context`, `Missing org context`) untouched in the canonical-titles table on line 51 — those are public contracts.

Old cell:

```markdown
| `missing_org_context` | 422 | Authentication succeeded but the principal has no org context — typically a session JWT minted before an org was selected, or an API key whose org has since been deleted. Pick an org (UI) or re-mint the key against a live org (integrators). | No — establish org context, then retry |
```

New cell:

```markdown
| `missing_org_context` | 422 | Authentication succeeded but the principal has no organization context — typically a session JWT minted before an organization was selected, or an API key whose organization has since been deleted. Pick an organization (UI) or re-mint the key against a live organization (integrators). | No — establish organization context, then retry |
```

- [ ] **Step 4: Verify the canonical-titles table is unchanged**

Run:

```bash
grep -n "missing_org_context\|Missing org context" docs/api/errors.md
```

Expected: line 51 still reads `| \`missing_org_context\` | \`Missing org context\` |` — type and title strings are public contracts and stay short-form.

- [ ] **Step 5: Build sanity check**

Run: `pnpm build 2>&1 | tail -10`
Expected: success.

- [ ] **Step 6: Format + commit**

```bash
pnpm dlx prettier --write docs/api/errors.md
git add docs/api/errors.md
git commit -m "docs(api): platform PR #277 follow-up + TRA-630 §C5 — out-of-range path-param 400 note + organization prose

- Note that out-of-range numeric path params (against the new
  maximum: 2147483647 bound from platform PR #277) surface as
  400 validation_error rather than 404 not_found. Verified on the
  live preview before shipping.
- 630 §C5: expand 'org' -> 'organization' in the missing_org_context
  catalog-row description. The error type and title strings stay
  short-form (public contract)."
```

---

## Task 6: private-endpoints.md + webhooks.md — org sweep

**Files:**

- Modify: `docs/api/private-endpoints.md`
- Modify: `docs/api/webhooks.md`

- [ ] **Step 1: private-endpoints.md L17 — `org-scoped` → `organization-scoped`**

Old fragment:

```markdown
If your integration needs human-on-behalf-of credentials rather than an org-scoped API key,
```

New fragment:

```markdown
If your integration needs human-on-behalf-of credentials rather than an organization-scoped API key,
```

- [ ] **Step 2: private-endpoints.md L29–30 — `SPA org switcher`/`SPA org picker`**

Edit the two table rows. The endpoint names contain `current-org` and `/orgs` (technical, untouched); the **Purpose** column changes:

Old fragments:

```markdown
| `/api/v1/users/me/current-org` | POST | SPA org switcher | Internal | Internal |
| `/api/v1/orgs` | GET | SPA org picker | Internal | Internal |
```

New fragments:

```markdown
| `/api/v1/users/me/current-org` | POST | SPA organization switcher | Internal | Internal |
| `/api/v1/orgs` | GET | SPA organization picker | Internal | Internal |
```

(Column padding will be re-flowed by prettier in step 5.)

- [ ] **Step 3: webhooks.md L40 — `per org` → `per organization`**

Old fragment:

```markdown
- **Registration:** register a target URL per org, with optional per-event filters.
```

New fragment:

```markdown
- **Registration:** register a target URL per organization, with optional per-event filters.
```

- [ ] **Step 4: Verify no other prose `org` hits remain in either file**

Run:

```bash
grep -nE "\borg\b|\borgs\b" docs/api/private-endpoints.md docs/api/webhooks.md | grep -v "/orgs/\|org_id\|/api/v1/orgs\|current-org\|missing_org_context"
```

Expected: empty.

- [ ] **Step 5: Build + format + commit**

Run:

```bash
pnpm build 2>&1 | tail -10
```

Expected: success.

```bash
pnpm dlx prettier --write docs/api/private-endpoints.md docs/api/webhooks.md
git add docs/api/private-endpoints.md docs/api/webhooks.md
git commit -m "docs(api): TRA-630 §C5 — organization prose in private-endpoints + webhooks

- private-endpoints.md: 'org-scoped' -> 'organization-scoped';
  'SPA org switcher/picker' -> 'SPA organization switcher/picker'.
- webhooks.md: 'per org' -> 'per organization'.

Endpoint paths (/api/v1/orgs, current-org) and field names are
public contracts and stay short-form."
```

---

## Task 7: user-guide + integrations — org sweep

**Files:**

- Modify: `docs/user-guide/asset-management.md`
- Modify: `docs/integrations/index.md`

- [ ] **Step 1: asset-management.md L34 — `fresh org` → `new organization`**

Old fragment:

```markdown
1. Open **Assets** from the left nav. On a fresh org you'll see a "No assets yet" empty state with a **Create Asset** button.
```

New fragment:

```markdown
1. Open **Assets** from the left nav. On a new organization you'll see a "No assets yet" empty state with a **Create Asset** button.
```

- [ ] **Step 2: integrations/index.md L15 — `against a TrakRF org` → `against a TrakRF organization`**

Old fragment:

```markdown
- **[Fixed reader setup](./fixed-reader-setup)** — deploying CS463 and similar fixed RFID readers against a TrakRF org.
```

New fragment:

```markdown
- **[Fixed reader setup](./fixed-reader-setup)** — deploying CS463 and similar fixed RFID readers against a TrakRF organization.
```

- [ ] **Step 3: Verify the comprehensive sweep is clean across non-API docs**

Run:

```bash
grep -rnE "\borg\b|\borgs\b" docs/user-guide/ docs/app-tour/ docs/getting-started/ docs/integrations/ 2>/dev/null | grep -v "/orgs/\|org_id\|missing_org_context"
```

Expected: empty.

- [ ] **Step 4: Build + format + commit**

```bash
pnpm build 2>&1 | tail -10
```

Expected: success.

```bash
pnpm dlx prettier --write docs/user-guide/asset-management.md docs/integrations/index.md
git add docs/user-guide/asset-management.md docs/integrations/index.md
git commit -m "docs(user-guide,integrations): TRA-630 §C5 — organization prose

- asset-management.md: 'fresh org' -> 'new organization'.
- integrations/index.md: 'a TrakRF org' -> 'a TrakRF organization'."
```

---

## Task 8: Commit the spec + plan

**Files:**

- Add: `spec/superpowers/specs/2026-05-09-tra-618-tra-630-polish-drop-design.md`
- Add: `spec/superpowers/plans/2026-05-09-tra-618-tra-630-polish-drop.md`

- [ ] **Step 1: Format the spec + plan**

Run: `pnpm dlx prettier --write spec/superpowers/specs/2026-05-09-tra-618-tra-630-polish-drop-design.md spec/superpowers/plans/2026-05-09-tra-618-tra-630-polish-drop.md`

- [ ] **Step 2: Commit**

```bash
git add spec/superpowers/specs/2026-05-09-tra-618-tra-630-polish-drop-design.md spec/superpowers/plans/2026-05-09-tra-618-tra-630-polish-drop.md
git commit -m "docs(spec): TRA-618 + TRA-626 + TRA-630 polish drop — design + plan

Design and implementation plan for the BB19/BB20 polish drop. Pairs
with the docs commits in this PR."
```

---

## Task 9: Final verification + open PR

**Files:** none (workflow only)

- [ ] **Step 1: Confirm all targeted greps are clean**

Run:

```bash
grep -rn "Read+Write" docs/ tests/
```

Expected: empty.

```bash
grep -rnE "\borg\b|\borgs\b" docs/ tests/blackbox/ 2>/dev/null | grep -v "/orgs/\|org_id\|missing_org_context\|Missing org context\|current-org\|#listing-revocation"
```

Expected: empty (or only matches inside intentionally-untouched technical surfaces — re-check each remaining hit before declaring clean).

- [ ] **Step 2: Final build + lint**

Run: `pnpm lint`
Expected: clean.

Run: `pnpm build`
Expected: success, no broken-anchor warnings.

- [ ] **Step 3: Visual spot-check with dev server**

Run: `pnpm dev` (in a background process; default port 3000)

Open in a browser:

- `http://localhost:3000/api/authentication` — confirm "Listing and revocation are SPA-side" subsection renders, "Read + Write" appears in the table, expiration bullet has the codegen caveat.
- `http://localhost:3000/api/resource-identifiers` — confirm the rewritten id-collision paragraph and the new "Asset metadata vs. location tags" subsection render with no anchor warnings.
- `http://localhost:3000/api/errors` — confirm the path-param 400 sentence reads correctly in the not_found row.
- `http://localhost:3000/api/quickstart` — confirm "Read + Write" reads correctly and the org prose flows.

Stop the dev server (`pkill -f "docusaurus start"` or interrupt the foreground process).

- [ ] **Step 4: Push and open PR**

```bash
git push -u origin miks2u/tra-618-tra-630-bb19-bb20-polish-drop
```

```bash
gh pr create --title "docs: TRA-618 + TRA-626 + TRA-630 — BB19/BB20 polish drop" --body "$(cat <<'EOF'
## Summary

One docs PR closing the docs-side leftovers from BB19/BB20 polish (TRA-618 §W2/§W3/§W4/§C3/§C5, TRA-630 §C3/§C5) plus the OpenAPI spec mirror refresh that picks up [platform PR #277](https://github.com/trakrf/platform/pull/277) (TRA-626 §S1/§S2, TRA-618 §S3/§S4, TRA-630 §S5).

- **Spec mirror refreshed** — `static/api/openapi.{json,yaml}` now declares `limit` min/max, path-param max, repeatable filter arrays, `from`/`to` `format: date-time`, and `sort` style/explode pinning.
- **TRA-618 §W2** — aligned `Read+Write` to the SPA's `Read + Write` label across `authentication.md` and `quickstart.mdx`.
- **TRA-618 §W3** — new "Listing and revocation are SPA-side" subsection in `authentication.md`.
- **TRA-618 §W4** — strengthened the Expiration bullet to call out that `Never` mints a JWT with no `exp` claim and breaks generated-client auto-refresh.
- **TRA-618 §C3 (+ BB20 §C1 surrogate-key reframe)** — rewrote the cross-type integer-`id` collision paragraph in customer voice; dropped the BB16 cycle citation.
- **TRA-630 §C3** — documented the intentional asymmetry that `PublicAssetView` carries `metadata` and `PublicLocationView` does not (use `tags` on locations for the same purpose).
- **TRA-630 §C5** — comprehensive `org` → `organization` sweep across `docs/api/`, `docs/user-guide/`, and `docs/integrations/`. Technical surfaces (`org_id`, `missing_org_context`, `org.OrgMeView`, endpoint paths, JWT claims) intentionally untouched.

## Out of scope (explicit closes)

- TRA-618 §C5 (`description` ambiguity between OpenAPI metadata key and resource field): cosmetic, won't-fix.
- TRA-618 §W5 (BB.md self-consistency): stale finding. The current `tests/blackbox/BB.md` does not mandate any first-call sequence; nothing to align.
- TRA-630 §F3 (server `detail` string for session-JWT-on-`/orgs/me`): platform-side fix; not docs.
- TRA-626 prose follow-up: `pagination-filtering-sorting.md` and `resource-identifiers.md` already describe repeatable filters and the RFC 3339 `from`/`to` format correctly. Spec refresh alone covers TRA-626.

## Test plan

- [ ] `pnpm lint` clean
- [ ] `pnpm build` clean (no broken-anchor warnings)
- [ ] Visual spot-check on `/api/authentication`, `/api/resource-identifiers`, `/api/errors`, `/api/quickstart`
- [ ] Live-preview smoke-check confirmed `GET /api/v1/assets/99999999999` returns `400 validation_error` (verified before shipping the path-param note in `errors.md`)
- [ ] Spec diff in `static/api/openapi.yaml` matches expected platform-PR-#277 changes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: Verify PR opened cleanly**

Run: `gh pr view --json url,title,state | jq`
Expected: `state: "OPEN"`, the URL points at github.com/trakrf/docs.

Capture the PR URL to share back to the user.

---

## Self-review

**Spec coverage check:**

- TRA-618 §W2 (Read+Write) — Tasks 2, 3 ✓
- TRA-618 §W3 (session-only key affordances) — Task 2 ✓
- TRA-618 §W4 (Never expiration codegen caveat) — Task 2 ✓
- TRA-618 §W5 (BB.md self-consistency) — explicitly closed as stale, no task ✓
- TRA-618 §C3 + BB20 §C1 (cycle citation rewrite) — Task 4 ✓
- TRA-618 §C5 (description ambiguity) — explicitly won't-fix, no task ✓
- TRA-626 (spec changes) — Task 1 ✓
- TRA-630 §C3 (metadata asymmetry) — Task 4 ✓
- TRA-630 §C5 (org → organization comprehensive sweep) — Tasks 2, 3, 4, 5, 6, 7 ✓
- TRA-630 §F3 (server detail string) — explicitly out-of-scope, no task ✓
- Spec mirror refresh — Task 1 ✓
- Errors path-param 400 follow-up (from PR #277 comment) — Task 5 ✓
- PR open — Task 9 ✓

**Placeholder scan:** none — every step contains the literal old/new text or the exact command + expected output.

**Type consistency:** subsection anchors (`#listing-revocation-spa-side`, `#asset-metadata-vs-location-tags`, `#numeric-id-collides-across-resource-types`) are referenced consistently. The renamed `multi-org switcher` → `organization switcher` is consistent across authentication.md and quickstart.mdx (Task 2 step 2 and Task 3 step 2).

**Order dependencies:** Task 1 (spec refresh) is independent. Tasks 2–7 are independent of each other (different files). Task 8 commits the spec/plan files (independent of code changes). Task 9 depends on all prior tasks. The plan can run mostly in parallel if a subagent driver wants to dispatch multiple workers, but the linear order is fine and keeps the diff easy to review.
