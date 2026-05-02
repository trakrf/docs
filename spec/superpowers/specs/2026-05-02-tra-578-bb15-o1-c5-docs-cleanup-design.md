---
ticket: TRA-578
parent: TRA-575
date: 2026-05-02
status: design
---

# TRA-578 — BB15 O-1 + C-5 docs follow-up

## Goal

Bring `trakrf-docs` into alignment with platform PR [#262](https://github.com/trakrf/platform/pull/262), which:

1. **O-1** — flipped all four `/api/v1/orgs/{id}/api-keys*` operations to internal (no longer in the public OpenAPI spec).
2. **C-5** — renamed scope `scans:read` → `history:read` end-to-end (DB migration, Go middleware, frontend UI label).

The platform PR's "Out of scope" block enumerates the docs work; this spec extends that list with the cascade deletions needed to keep the Authentication doc internally consistent once the programmatic-mint surface is gone.

## Background

### O-1 — finishing TRA-568

TRA-568 dropped `/api/v1/auth/login` and `BearerAuth` from the public spec but left `POST /api/v1/orgs/{id}/api-keys` (and the GET/DELETE/by-jti siblings) public. Net effect: docs simultaneously claimed "v1 does not provide a programmatic key-mint endpoint" while publishing one. TRA-578 closes that gap on the platform side; this PR brings the docs in line.

### C-5 — finishing TRA-571

TRA-571 dropped `scans:write` from the API key minting UI for the same shape — no public endpoint required it. `scans:read` survived as a phantom-resource anachronism gating endpoints under `/locations/current` and `/assets/{id}/history`. TRA-578 renamed the scope; this PR propagates the rename through user-facing docs.

### Cascade rationale

The platform PR enumerated four docs touch points (Authentication trim, Quickstart/getting-started rename, private-endpoints add, spec refresh). My audit surfaces three additional dead-anchor / contradiction sources that fall out of the O-1 cut:

- The `keys:admin` row in the scopes table — gates only internal endpoints now.
- The `### Identifying a key` section — discusses the `id` vs. `jti` revocation routes that are no longer reachable from the public surface.
- `resource-identifiers.md` line 210 ("Authentication keys are different") — references the now-internal `/by-jti/{jti}` route.

Cascading these (Option A from the brainstorm) keeps the doc consistent with the "browser-mediated by design" framing TRA-568 committed to. The alternative (surgical-only) leaves contradictions readers will rightly file as bugs.

## Verified spec state (post-refresh, platform@b0db561)

```
$ jq -r '.paths | keys[] | select(test("api-keys"))' static/api/openapi.json
(no output)

$ grep -oE '"(scans:read|history:read)"' static/api/openapi.json | sort -u
"history:read"
```

`/api/v1/orgs/{id}/api-keys*` paths absent from public spec; `scans:read` not present anywhere; `history:read` is the canonical scope literal. Spec refresh dropped 539 lines from `openapi.json` / 347 from `openapi.yaml`. Already on the branch.

## Changes

### File 1: `docs/api/authentication.md`

#### Rename `scans:read` → `history:read` (UI labels and scopes tables)

UI labels table (line 52): change

```
| Scans → Read               | `scans:read`                        |
```

to

```
| History → Read             | `history:read`                      |
```

Scopes table (line 62): change

```
| `scans:read`      | Read   | `GET /locations/current`, `GET /assets/{id}/history`, scan-event endpoints                                                   |
```

to

```
| `history:read`    | Read   | `GET /locations/current`, `GET /assets/{id}/history`                                                                         |
```

(Drops the "scan-event endpoints" tail — there are none on the public surface, which was the whole reason for the rename.)

Non-obvious-pairings bullets (lines 67–68): rename `scans:read` → `history:read` (×2). Keep the rationale ("derived from scan events" / "projection of scan events") — the underlying data is unchanged; only the scope label is.

#### Remove `keys:admin` and the entire programmatic-mint surface

Delete:

- Line 44 (UI labels intro): the trailing sentence "`keys:admin` is not exposed in the form — admin-tier keys are minted via API, see [Programmatic key rotation](#programmatic-key-rotation)."
- Line 63: the `keys:admin` row from the scopes table.
- Line 69: the third bullet in the non-obvious-pairings list (the `keys:admin` callout).
- Lines 119–128: the entire `### Identifying a key {#identifying-a-key}` section (id vs. jti, both DELETE routes, design rationale for the split).
- Lines 130–176: the entire `## Programmatic key rotation {#programmatic-key-rotation}` H2 — including `### Self-rotation`, `### Required scopes on /api/v1/orgs/{id}/api-keys`, and `### Example: rotate a key from a script`.

The `## Key lifecycle` section (lines 110–117) stays — it describes lifecycle from the integrator's perspective without committing to a programmatic surface. Update the **Rotation** bullet (line 113) only if it still references the now-deleted programmatic flow; current text ("create a new key, update your integration, then revoke the old one") is operationally correct under the browser-mediated model and stays.

#### Anchor / link audit

After deletions, search the docs corpus for `#programmatic-key-rotation` and `#identifying-a-key` anchors. None expected outside this file (per pre-edit grep), but the cascade is a one-time chance to confirm.

### File 2: `docs/api/private-endpoints.md`

#### Add four api-keys rows to the Endpoint list

Insert into the table (alphabetical placement, after `/api/v1/orgs/{id}`):

```
| `/api/v1/orgs/{id}/api-keys`                  | POST, GET | SPA avatar menu → API Keys | Internal | Internal |
| `/api/v1/orgs/{id}/api-keys/{key_id}`         | DELETE    | SPA avatar menu → API Keys | Internal | Internal |
| `/api/v1/orgs/{id}/api-keys/by-jti/{jti}`     | DELETE    | SPA avatar menu → API Keys | Internal | Internal |
```

The "Used by" cell uses the user-facing UI path (the SPA route), matching the convention of other Internal rows. The Status and Classification columns both read "Internal" per existing pattern.

No prose change to the surrounding sections — `## Programmatic access`, `## Response shape: /orgs/me`, `## Classification policy` all stand.

### File 3: `docs/api/resource-identifiers.md`

#### Drop the "Authentication keys are different" trailing section

Delete lines 209–211 (the H2 `## Authentication keys are different` and its single paragraph). The section's only purpose was to differentiate api-keys from the assets/locations/tags identifier model — and to point integrators at `/by-jti/{jti}`. With api-keys off the public surface, neither claim has a reader.

If the page feels truncated after the drop, the preceding `## Tags use a composite natural key` section is a clean stop — tags are the last public-surface resource with a non-trivial identifier story.

### File 4: `docs/getting-started/api.mdx`

#### Replace `scans:read` with `history:read`

- Line 39: rewrite the parenthetical scope-explanation. Current:

  > choose scopes (`scans:read` alone is enough for this quickstart — the `/locations/current` endpoint is gated by `scans:read`; grant `assets:read` and `locations:read` if you plan to hit the other read endpoints), and submit.

  Change both `scans:read` literals to `history:read`. UI selector wording also flips: "**History → Read** alone is enough for this quickstart". Keep the grant-also-others tail.

- Line 51: "It's cheap, requires `scans:read`" → "requires `history:read`".
- Line 79: `"Missing required scope: scans:read"` → `"Missing required scope: history:read"`.
- Line 89: same in the JSON error-body example.

### File 5: `docs/api/quickstart.mdx`

#### Replace `scans:read` with `history:read`

- Line 35: in the scopes-listing sentence, change `scans:read` → `history:read`.

### File 6 (already on branch): `static/api/*`

`platform-meta.json` shows `b0db561`. `openapi.{json,yaml}` lost the api-keys paths and the `scans:read` enum; postman regenerated. Stage and ship as-is.

### Out of scope

- Adding a screenshot of the renamed `History → Read` scope row. The doc already carries a `<!-- TODO: screenshot -->` comment from prior work — that's a separate sweep.
- Touching `docs/api/CHANGELOG.md` or root `CHANGELOG.md` — both are pre-launch placeholders ("v1.0 — Launch (TBD)" and "[Unreleased]"). Per project policy, no public changelog entry until launch.
- Backporting the rename to historical changelog notes that don't exist yet.
- Reviving any "self-rotation" / "rotation-capable credential" prose. The browser-mediated model has no equivalent.
- Re-organizing the Authentication doc's section order. The deletions leave a clean flow: `Mint → Header → Scopes → Examples → Key lifecycle → Base URL → Server-to-server → Env vars → Testing connectivity`. No restructure needed.

## Acceptance criteria

- [ ] `docs/api/authentication.md`: scopes table contains `history:read`, not `scans:read`; no `keys:admin` row; no `### Identifying a key` section; no `## Programmatic key rotation` H2 (or its three sub-sections).
- [ ] `docs/api/authentication.md`: UI labels table shows `History → Read | history:read`.
- [ ] `docs/api/private-endpoints.md`: Endpoint list includes the three api-keys rows (POST/GET, DELETE-by-id, DELETE-by-jti) all classified Internal.
- [ ] `docs/api/resource-identifiers.md`: no `## Authentication keys are different` section.
- [ ] `docs/getting-started/api.mdx` and `docs/api/quickstart.mdx`: zero remaining `scans:read` literals.
- [ ] No remaining `#programmatic-key-rotation` or `#identifying-a-key` anchor references in the docs corpus.
- [ ] `static/api/platform-meta.json` carries `b0db561`.
- [ ] `pnpm build` passes (typecheck, broken-link check, Redocly bundle).
- [ ] PR opens against `main`; user reviews before merge.

## References

- Parent ticket: TRA-575 (BB15 launch readiness epic)
- Source: BB15 [FINDINGS.md](https://github.com/trakrf/platform/blob/main/FINDINGS.md), findings O-1 and C-5
- Platform PR: trakrf/platform#262 (`b0db561`)
- Predecessors that closed too narrowly: TRA-568 (W1+C6 cleanup), TRA-571 (`scans:write` removal)
- Sibling docs follow-up just landed: TRA-573 (BB14 W3/W4/W5)
