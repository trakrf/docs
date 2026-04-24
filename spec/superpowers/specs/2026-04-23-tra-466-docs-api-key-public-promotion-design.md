# TRA-466 — docs: promote API-key management endpoints to public API (design)

**Linear:** [TRA-466](https://linear.app/trakrf/issue/TRA-466) — sub-issue of TRA-210
**Blocked-by (platform side):** `trakrf/platform` [PR #197](https://github.com/trakrf/platform/pull/197) — must merge before this docs PR merges. No customers yet, so a brief window where the docs PR is open but the platform PR is unmerged is acceptable.
**Related:** [TRA-415](https://linear.app/trakrf/issue/TRA-415) — which originally classified `/api/v1/orgs/{id}/api-keys` as Internal. This PR reverses that classification for the key-management rows.
**Ship-gate context:** The key-management endpoints are the unlock for programmatic key rotation (TeamCentral iPaaS connector, CI/CD, Terraform/Pulumi). The docs PR makes the promotion visible to integrators.

## Goal

Update the public docs so that once platform PR #197 lands, `POST/GET/DELETE /api/v1/orgs/{id}/api-keys` read as first-class public endpoints with a clear programmatic-rotation workflow, and the old "API-key management is Internal" language is gone. Document a small session-JWT caveat on public endpoints while we're here, since the blackbox pass surfaced it and integrators will otherwise be surprised by it.

## Scope

One PR, one branch, four content files plus the auto-refreshed spec artifacts. Per project convention: conventional commits scoped `docs(tra-466)`, incremental commits (no squash).

**Branch:** `miks2u/tra-466-docs-promote-api-key-management` (already created off `main`; worktree at `.worktrees/tra-466-docs`).

**In scope:**

- `docs/api/authentication.md` — add `keys:admin` to the Scopes table; add a "Programmatic key rotation" section; add a short session-JWT-on-public-endpoints note.
- `docs/api/private-endpoints.md` — remove the `/api/v1/orgs/{id}/api-keys` row and the `## API-key management is Internal` section.
- `docs/api/CHANGELOG.md` — one `Unreleased → Added` entry announcing the promotion and the new scope.
- `static/api/openapi.{json,yaml}` — refreshed via `scripts/refresh-openapi.sh` **after** platform PR #197 merges and the preview build picks it up. Mechanical, not hand-edited.

**Out of scope:**

- Any change to `authentication.md`'s "Mint your first API key" section (UI-centric, still correct).
- Screenshots (the existing TRA-408 TODO comment stays).
- Edits to `quickstart.md`, `webhooks.md`, `rate-limits.md`, `errors.md`, `versioning.md`, `pagination-filtering-sorting.md`, `resource-identifiers.md`, `postman.mdx`, or `README.md` — unrelated to this promotion.
- OAuth2 client credentials flow, service accounts, or webhook-based key-expiry notifications (listed as out-of-scope in the Linear issue).
- Any edit to `tests/blackbox/BB.md` — there's a separate uncommitted change in that file that we're not touching.

## Platform-side ground truth (from PR #197, 2026-04-23)

Verified against the PR body and changed-files list on `trakrf/platform#197`. Quoting the parts the docs need to pin to:

### New scope

- **`keys:admin`** — grants create / list / revoke on `/api/v1/orgs/{id}/api-keys` in the key's own org.
- **Self-minting is allowed:** a `keys:admin` key can mint another key with `keys:admin`. This is deliberate — it enables iPaaS / CI self-rotation without a human in the loop. Leak containment relies on short expiry + revocation audit trail, not on forbidding self-minting.

### Auth model on these endpoints

- Middleware: new `RequireOrgAdminOrKeysAdmin` — accepts **either** a session JWT from an org admin **or** an API key with `keys:admin`. Session path delegates to the existing `RequireOrgAdmin`.
- Key path: handler resolves creator from whichever principal authenticated the request. A concurrent revoke between middleware and handler returns `401`, not `500`.
- Rate limit + SentryContext: applied via `EitherAuth + RateLimit + SentryContext` in the main router (the api-keys routes are carved out of the session-only `orgs` subtree into `RegisterAPIKeyRoutes`).

### OpenAPI

- swaggo `@Tags` changes from `api-keys,internal` to `api-keys,public` on all three handlers.
- `openapi.public.{json,yaml}` in the platform repo gains ~290 JSON / ~179 YAML lines for these endpoints. The docs site refreshes its own `static/api/openapi.{json,yaml}` from `https://app.preview.trakrf.id/api/v1/openapi.{json,yaml}` via `scripts/refresh-openapi.sh`.

### Session-JWT behavior on public endpoints (blackbox finding, pre-existing)

Not changed by PR #197, but noted in the Linear issue for documentation. Session JWTs are accepted as `Authorization: Bearer <session-jwt>` on public API endpoints with no scope enforcement (effectively unscoped access for the 1h JWT lifetime). This is expected behavior for the SPA; integrators should still use scoped API keys.

## Changes to `docs/api/authentication.md`

### Change A1 — add `keys:admin` to the Scopes table

In the table at lines 39–46, insert a new row. `keys:admin` sits at the bottom of the table (below `scans:write`) to keep the read/write pairs visually intact:

```markdown
| `keys:admin` | Admin | `POST /orgs/{id}/api-keys`, `GET /orgs/{id}/api-keys`, `DELETE /orgs/{id}/api-keys/{keyId}` |
```

Also extend the "few non-obvious pairings" bullet list below the table with one bullet:

> - **`keys:admin`** is the only "admin" scope in v1 — it gates key creation, listing, and revocation on the caller's own org. A `keys:admin` key may mint another key with `keys:admin`, enabling unattended self-rotation. See [Programmatic key rotation](#programmatic-key-rotation).

### Change A2 — add a `## Programmatic key rotation` section

New section, inserted between `## Key lifecycle` (current lines 91–97) and `## Base URL` (current line 99). The existing `## Key lifecycle` bullets describe rotation conceptually but direct the reader at a web UI flow. This new section gives the API-only recipe:

```markdown
## Programmatic key rotation {#programmatic-key-rotation}

Production integrations (iPaaS connectors, CI/CD, Terraform/Pulumi) should rotate their API keys on a schedule rather than relying on administrator web-UI action. TrakRF supports unattended rotation via the `keys:admin` scope.

The workflow is **create-new → cut-over → revoke-old**, which keeps the integration valid throughout:

1. **List existing keys** — `GET /api/v1/orgs/{id}/api-keys` returns the key metadata (name, scopes, created / last-used, expiration). The JWT itself is never included.
2. **Mint a replacement** — `POST /api/v1/orgs/{id}/api-keys` with `{"name": "<integration>-rotated-<YYYY-MM-DD>", "scopes": [...], "expires_at": "<future>"}`. The response body carries the full JWT **once**; persist it to your secrets store immediately.
3. **Cut over** — deploy the new JWT to the integration. Both keys are valid during the overlap.
4. **Revoke the old key** — `DELETE /api/v1/orgs/{id}/api-keys/{keyId}`. Any subsequent request with the old JWT returns `401 unauthorized`.

### Self-rotation

A key with `keys:admin` can mint another key with `keys:admin`. That means an integration holding a `keys:admin` key can rotate itself on a schedule without an administrator in the loop — mint the replacement, cut over, revoke the old key, all from one integration process.

Because a `keys:admin` key is effectively a rotation-capable credential, treat it like any other high-value secret: short expiry (90 days or less), store it in a secrets manager, and review the key-revocation audit trail during incident response.

### Required scopes on `/api/v1/orgs/{id}/api-keys`

These endpoints accept either:

- An **API key** with the `keys:admin` scope, **or**
- A **session JWT** from an organization administrator (the path the web UI uses).

Requests authenticated with an API key that lacks `keys:admin` return `403 forbidden` with `"Missing required scope: keys:admin"`. Requests with a non-admin session JWT return `403 forbidden` via the org-admin check.

### Example: rotate a key from a script

\`\`\`bash

# 1. Mint the replacement

NEW_KEY=$(curl -s -H "Authorization: Bearer $TRAKRF_API_KEY" \
               -H "Content-Type: application/json" \
               -d '{"name":"rotated-'"$(date -u +%Y-%m-%d)"'","scopes":["assets:read","keys:admin"],"expires_at":"2026-07-22T00:00:00Z"}' \
 "$BASE_URL/api/v1/orgs/$ORG_ID/api-keys" \
 | jq -r '.data.jwt')

# 2. Deploy $NEW_KEY to the integration, then rotate $TRAKRF_API_KEY in your secrets manager.

# 3. Revoke the old key once the cutover is confirmed:

curl -X DELETE -H "Authorization: Bearer $NEW_KEY" \
     "$BASE_URL/api/v1/orgs/$ORG_ID/api-keys/$OLD_KEY_ID"
\`\`\`

The shapes of the response envelopes are shown in the [API reference](/api).
```

Request/response field names (`expires_at`, `data.jwt`, `keyId`) will be re-verified against the refreshed `openapi.{json,yaml}` once platform PR #197 merges and `refresh-openapi.sh` pulls the spec. If any field name differs from the above, the example code block is corrected in place; the narrative prose does not change.

### Change A3 — session-JWT-on-public-endpoints note

Add a short paragraph at the end of the existing `## Server-to-server design` section (current line 118), before `## Environment variables`. Keep it inline in the existing section rather than creating a new section — it's a caveat, not a separate concept.

```markdown
**Session JWTs are also accepted** on public endpoints (same `Authorization: Bearer <jwt>` form), because the web app and the API share a router. A session JWT is effectively unscoped for its 1-hour lifetime and is only convenient for ad-hoc UI-driven requests; integrators should use API keys so that auth is durable and scope-limited.
```

## Changes to `docs/api/private-endpoints.md`

### Change P1 — remove the `/orgs/{id}/api-keys` row

Delete the row at line 26:

```
| `/api/v1/orgs/{id}/api-keys`   | GET, POST, DELETE | Settings → API Keys UI | Internal                         | Internal — see API-key note below         |
```

No other row in the table changes.

### Change P2 — remove the `## API-key management is Internal` section

Delete the entire section, currently lines 44–52 (header `## API-key management is Internal {#api-key-management}` through the "Ask for a rotation primitive" bullet). The rotation story now lives in `authentication.md`, and the section's premise (that these endpoints are Internal) is no longer true.

No replacement section is added — `private-endpoints.md` is a list of endpoints that are actually private; once these rows leave, there's nothing left to say on this page about them.

### Non-changes on this page

- `## Response shape: /orgs/me` — unaffected; remains accurate.
- `## Classification policy` — unaffected; still the policy.
- The `:::caution Internal endpoints` admonition at the top — unaffected; still applies to the remaining rows.

## Changes to `docs/api/CHANGELOG.md`

One bullet under **Unreleased → Added** (current lines 23–27), keeping the style of the existing bullets:

```markdown
- `POST /api/v1/orgs/{id}/api-keys`, `GET /api/v1/orgs/{id}/api-keys`, and `DELETE /api/v1/orgs/{id}/api-keys/{keyId}` are now public, authenticated with the new **`keys:admin`** scope (or a session JWT from an org administrator). A `keys:admin` key may mint another `keys:admin` key, enabling unattended rotation for iPaaS, CI/CD, and IaC workflows. See [Authentication → Programmatic key rotation](./authentication#programmatic-key-rotation).
```

## Changes to `static/api/openapi.{json,yaml}`

Run `./scripts/refresh-openapi.sh` **after** platform PR #197 merges to main and `https://app.preview.trakrf.id/api/v1/openapi.{json,yaml}` has picked up the change (the preview rebuild happens on merge). Commit the resulting diff with `chore(api): sync preview spec from platform@<sha>` — same message pattern used in commits `c360911` and `2c342c0`. No manual edits to these files.

## Non-changes (explicit)

- No change to `## Mint your first API key` in `authentication.md` — the web-UI flow it describes still works (the SPA uses the session-admin path of `EitherAuth`). The programmatic flow is a new section, not a replacement.
- No change to the `X-API-Key` `:::caution` block — still accurate.
- No change to the Scopes table's "open enum" disclaimer — the new `keys:admin` scope is consistent with that disclaimer, not an exception to it.
- No edit to `docs/api/errors.md` — PR #197's `403 "Missing required scope: keys:admin"` already follows the shape documented there; no new code or type to list.
- No edit to `tests/blackbox/BB.md` — there's an unrelated uncommitted change staged in `main`; leave it for its own flow.
- No screenshot refresh — the existing TRA-408 TODO comment remains the single outstanding screenshot task.
- No `sidebars.ts` change — both `authentication.md` and `private-endpoints.md` already appear in the API sidebar and are staying there.

## Verification

**Pre-commit (local, in the worktree):**

- `pnpm typecheck` — passes (no TypeScript changes expected, but catches any accidental config breakage).
- `pnpm build` — passes, no broken links (`onBrokenLinks: "throw"` is on in `docusaurus.config.ts`).
- `pnpm dev` — visually inspect:
  - `/docs/api/authentication`: Scopes table has the new `keys:admin` row; the new "Programmatic key rotation" section renders with the anchor `#programmatic-key-rotation`; the `[Programmatic key rotation](#programmatic-key-rotation)` link from the Scopes bullet resolves.
  - `/docs/api/private-endpoints`: the `orgs/{id}/api-keys` row is gone; the old `#api-key-management` section is gone; the remaining page still renders cleanly (no stray anchor references from other pages).
  - `/docs/api/changelog`: new Unreleased bullet renders; the `./authentication#programmatic-key-rotation` link resolves.

**Pre-ship (against preview deployment):**

- After platform PR #197 merges, run `./scripts/refresh-openapi.sh` and verify the diff contains the three api-key paths under `"paths"` in `static/api/openapi.json`.
- Load `/api` (Redoc) on the preview docs deploy; confirm the three api-key endpoints appear in the sidebar, their `keys:admin` scope is listed, and their request/response schemas render.
- Hit the platform preview with a `keys:admin`-scoped API key: `GET /api/v1/orgs/{id}/api-keys` returns 200; same request with a key lacking `keys:admin` returns `403` with `"Missing required scope: keys:admin"`.

**Ship gate:**

- Cross-check the prose in the new Programmatic key rotation section against the actual Redoc-rendered request/response schemas — field names (`expires_at`, `data.jwt`, `keyId` vs. alternatives) must match what the spec declares. If they don't, the example code block is the thing that changes.

## Rollout

1. Commit the four content edits on `miks2u/tra-466-docs-promote-api-key-management`, each with its own `docs(tra-466): ...` conventional-commit subject.
2. Once platform PR #197 merges to main and the preview deploy picks it up, run `./scripts/refresh-openapi.sh` and commit the spec diff as `chore(api): sync preview spec from platform@<sha>`.
3. Open PR to `main` with a summary that references TRA-466 and the platform PR (linked both directions).
4. Merge after `pnpm build` + preview deploy confirm the Redoc page reflects the new endpoints. Per project convention: no squash merge, no push to main.

## Risks

- **Docs ship ahead of platform.** Mitigated by keeping the docs PR un-merged until platform #197 merges, and by re-running `refresh-openapi.sh` against the merged preview rather than against a stale local spec. With no customers yet, the cost of a brief inversion is low — the risk here is really about the `/api` Redoc reference looking wrong, not about breaking an integrator.
- **Field-name drift in the example.** The `POST /api/v1/orgs/{id}/api-keys` request / response shapes, the DELETE sub-path (`/api-keys/{keyId}`), and optional fields like `expires_at` are pinned from the PR body and the existing rotation narrative, not from a reading of the merged handler code. If the final merged spec disagrees on any of these, the example curl block, the `DELETE` entry in the Scopes table row, and the POST body in the example are one-line fixes. The verification step calls this out explicitly — the refreshed `static/api/openapi.{json,yaml}` is the source of truth and the example must match it before ship.
- **Scope-table style inconsistency.** The existing Scopes table uses a read/write pair pattern. `keys:admin` is a single-access-level scope that doesn't fit the pair pattern. Resolved by placing it at the bottom and adding an explanatory bullet in the non-obvious-pairings list rather than restructuring the table. If a future scope follows the same pattern (e.g. `orgs:admin`), the table may want a column or subsection reorganization — not in scope here.
- **Classification-page emptiness.** Removing the api-keys row and its section leaves `private-endpoints.md` with fewer rows and no admonitions beyond the top-of-page caution. This is intentional — the page is a live classification, not a narrative, so rows leave when they're promoted. No structural change needed.
