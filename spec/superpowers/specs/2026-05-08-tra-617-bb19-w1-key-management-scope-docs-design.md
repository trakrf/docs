---
ticket: TRA-617
parent: TRA-613
date: 2026-05-08
status: design
---

# TRA-617 — BB19 §W1 — Key management scope row in authentication docs — design

## Goal

Close the "Key management → Admin" gap in `docs/api/authentication.md`. Today the SPA's New API Key dialog has four resource dropdowns — Assets, Locations, History, **Key management** — but the docs only enumerate the first three. A partner reading the table can't tell what `keys:admin` does, whether to request it, or whether selecting it would be escalatory. This makes the docs incoherent with the SPA UI and risks AI integration partners failing closed when they encounter the unknown scope.

## Background — what `keys:admin` is

Confirmed via the platform repo (`backend/internal/models/apikey/apikey.go`, `frontend/src/components/apikeys/ScopeSelector.tsx`, `backend/internal/middleware/org_admin_or_keys_admin.go`):

- The scope-string is **`keys:admin`** (not `key_management:admin` or other variants).
- It gates the API-key management endpoints (`POST/GET/DELETE` on `/orgs/{org}/api_keys` family) under the `RequireOrgAdminOrKeysAdmin` middleware — accepts session-admin OR API-key-with-keys:admin.
- The endpoints exist in the platform but **TRA-578 explicitly stripped them from the public OpenAPI spec** ("the published spec must match Authentication's 'browser-mediated by design' claim"), making them dead surface for v1 partners. The SPA still emits `keys:admin` when the user selects "Admin" in the Key management dropdown because the SPA itself uses the scope internally; partners can mint a key with that scope but have no documented endpoint to point it at.

The user-facing answer is therefore **"reserved for a future programmatic key-minting capability (v2); gates nothing in the v1 public surface."** Per project memory ("pre-launch, fix state not docs"), the v1 docs should describe the v1 contract truthfully.

## Scope

### 1. `docs/api/authentication.md` — add the Key management row

Two coupled edits to the scopes section:

**UI labels table (around lines 50–58)** — add a "Key management → Admin" row with `keys:admin` as the granted scope. The "Read+Write always grants both" note in the surrounding prose stays correct as-is (Key management has only None / Admin, no Read / Write split).

**Scope table (around lines 60–66)** — add a `keys:admin` row. The `Access` column reads "Admin." The `Endpoints (representative)` column reads "(reserved — see note below)" with a footnote pointer rather than a fabricated endpoint list, because there is no public endpoint to name.

**New short subsection** below the existing "non-obvious pairings" callouts (after line 71) — a `### Key management is reserved for v2` (or similar heading) explaining:

- The `keys:admin` scope appears in the SPA dropdown but gates **no endpoint in the v1 public surface**. The matching API-key management endpoints are currently browser-mediated only (see [Where keys come from](#where-keys-come-from) for the design rationale).
- The scope is reserved for a future programmatic key-minting capability (v2). Until that lands and the endpoints are re-promoted, **v1 integrators should leave Key management set to None** — selecting Admin grants no additional capability and is not required for any documented endpoint.
- A key minted today with `keys:admin` is functionally equivalent to one without, on the public surface. (Don't dramatize the security boundary — the platform middleware accepts the scope but no public endpoint requires it.)

Cross-references unchanged — quickstart and getting-started/api already cite `#scopes` and `#ui-labels` as source of truth (post-TRA-609); they don't need to enumerate `keys:admin` themselves because they don't tell readers to mint a key with `keys:admin` for any walkthrough.

### 2. Adjacent audit (in scope of this ticket)

Audit every place a scope-string is named in prose or tables, confirm none teach `keys:admin` incorrectly, and decide fix-in-scope vs follow-up per surface:

| Surface | Audit result | Action |
| ------- | ------------ | ------ |
| `docs/api/quickstart.mdx` | Names `assets:write`, `assets:read`, `locations:read`, `history:read` in §3 + UI labels (post-TRA-609). No mention of `keys:admin`. | No change — quickstart's sample walkthrough doesn't use Key management; cross-link to authentication suffices. |
| `docs/getting-started/api.mdx` | Names `history:read` only, with UI label (post-TRA-609). | No change. |
| `docs/api/postman.mdx` | Doesn't enumerate scopes; collection-level auth is preconfigured `Bearer {{apiKey}}`. | No change. |
| `docs/api/private-endpoints.md` | Discusses `/orgs/me` (no scope) and SSO/OAuth gap (no scope-string). | No change. |
| `docs/api/README.md` | One-liner "API keys, Bearer headers, scopes, key lifecycle" pointing to authentication. | No change. |

The only docs surface that enumerates scope strings is `authentication.md`. All other surfaces correctly defer to it. This is the single fix-point.

### 3. Follow-up Linear ticket (filed at PR time)

Per the TRA-617 acceptance criterion ("If the audit reveals the scope gates nothing currently, file a follow-up to either remove the dropdown or land the gated functionality"), file a TrakRF Linear ticket with title in the shape of "decide pre-launch: hide Key management dropdown until v2, or promote api-keys endpoints to public spec." Link back from this PR. Out of scope to *resolve* — that's a platform decision. The doc framing in §1 is correct under either resolution.

## Out of scope

- **Resolving the v2 / hide-dropdown decision** — platform call. Filed as a follow-up.
- **Reframing `authentication.md` "Where keys come from"** — that section already describes browser-mediated key issuance; the new Key management subsection cross-links to it. No rewrite needed.
- **Mentioning the platform-internal `RequireOrgAdminOrKeysAdmin` middleware shape** — implementation detail; not partner-facing.
- **Wire-format / codegen changes** — TRA-616 already shipped the BearerAuth scheme rename; this is purely a scope-string-table addition.
- **API CHANGELOG entry** — pre-launch.

## Acceptance

- `docs/api/authentication.md` UI labels table includes a Key management → Admin row with `keys:admin`.
- The scope table includes a `keys:admin` row marked Admin with a "(reserved — see note below)" pointer.
- A short subsection explains the scope is reserved for v2 programmatic mint; v1 integrators should leave Key management at None.
- `pnpm build` passes with no broken-link warnings.
- `grep -n "keys:admin" docs/api/authentication.md` returns ≥3 hits (UI table, scope table, prose).
- `grep -n "Key management" docs/api/authentication.md` returns ≥2 hits (UI table row + heading).
- Adjacent audit table written into PR description; only authentication.md changes.
- Follow-up ticket filed for hide-dropdown vs v2-promote and linked from PR.
- TRA-617 moved to Done after merge.
