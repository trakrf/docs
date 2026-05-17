# trakrf API — black-box evaluation (pre-key track)

You have a pre-minted API key for one of three parallelism-fixture orgs. Use it to exercise the API contract. This is the **contract track**: you skip the onboarding/mint workflow entirely and run the shared methodology in [BB.md](./BB.md) against a deterministic fixture. Parallel sessions can run this track simultaneously, each pinned to a different fixture org.

The onboarding experience (login → mint → first call) is evaluated by [BB_MINT_KEY.md](./BB_MINT_KEY.md). Don't duplicate that work here — if you incidentally observe an onboarding gap while orienting, note it briefly but stay focused on contract probes.

## Environment

`.envrc` + `.env.local` expose:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `BB_ORG` — `BB1`, `BB2`, or `BB3`. The label for the fixture org this session is pinned to. Used for traceability in FINDINGS.md.
- `BB_API_KEY` — the persistent JWT for the assigned fixture org. Pass it as `Authorization: Bearer $BB_API_KEY` on every API call.
- `BB_ORG_ID` — numeric `org_id` for the assigned fixture (for cross-checks).

Record `$BB_ORG` and `$BB_ORG_ID` in the FINDINGS.md context block so triage can correlate runs across parallel sessions.

If `$BB_API_KEY` or `$BB_ORG` is unset, stop and report — the harness did not assign this session a fixture, and guessing is wrong.

There is no SPA login on this track. The fixture key is everything you need; `API_TEST_LOGIN` / `API_TEST_PASS` are not in the env on this track.

## Fixtures

BB1, BB2, and BB3 carry identical, deterministic data. You can assert against literal values; shape-discovery passes are unnecessary.

**Locations — 8 per org, two side-by-side subtrees:**

- OC subtree (2 nodes): `WHS-01` "Main Warehouse" → `WHS-07-03` "Warehouse 7 Bay 3"
- CD subtree (6 nodes): `CD-WHS-01` "Warehouse" → `BAY-07` "Bay 7" → `SHELF-0001` "Bay 7 Shelf 1"; `LOC-0001` "The Universe" → `LOC-003` "milky way galaxy"; standalone `LOC-002` "Other universe"
- Every `parent_id` resolves within the same org. Tree integrity is verified on seed. For ancestor chains and breadcrumbs, walk `parent_id` client-side or call `GET /api/v1/locations/{location_id}/ancestors`. There is no `tree_path` field — display paths are derived, not stored. See [resource-identifiers](../../docs/api/resource-identifiers.md).

**Assets — 27 per org:**

- 11 OC-origin (`ASSET-0001` … `ASSET-0011`), 9 CD-origin under the `ASSET-NNNN` namespace above the OC ceiling (`ASSET-0012` … `ASSET-0020`), and 7 CD-origin under the `CD-ASSET-NNNN` namespace (`CD-ASSET-0001` … `CD-ASSET-0007` — the rows that would have collided with OC). 11 + 9 + 7 = 27.
- Every asset has `location_id` resolved from scan history — no asset on this fixture reads as `location_id: null`.

**Scans:** populated. Each org carries ~25 `asset_scans` per asset over a 90-day window (~675 per org), and the materialized `location_id` on every asset reflects the most-recent scan. `tracking:read` coverage is in-scope — exercise both `/api/v1/assets/{asset_id}/history` and `/api/v1/reports/asset-locations` with literal-value assertions.

**Tags:** not copied. Tags are not in v1 public-API scope.

## Key scope and lifecycle

The fixture key on each org is `bb-parallel-permanent`, no expiry, with scopes:

```
assets:read, assets:write, locations:read, locations:write, tracking:read
```

These five scopes cover **every scope the public API surface checks** — including DELETE on assets and locations, which is gated on `assets:write` / `locations:write`, not on a `*:delete` class. There is no `*:delete` scope and no `tags:*` scope on the public surface. Tag operations on assets and locations are gated on the parent resource's `:write` scope; the canonical mapping is the scope table in [`/docs/api/authentication`](../../docs/api/authentication.md):

| Operation surface                                                                                           | Required scope    |
| ----------------------------------------------------------------------------------------------------------- | ----------------- |
| `GET /api/v1/assets`, `GET /api/v1/assets/{id}`                                                             | `assets:read`     |
| `POST /api/v1/assets`, `PATCH`, `DELETE`, `POST .../rename`, `POST .../tags`, `DELETE .../tags/{tag_id}`    | `assets:write`    |
| `GET /api/v1/locations`, `GET /api/v1/locations/{id}`                                                       | `locations:read`  |
| `POST /api/v1/locations`, `PATCH`, `DELETE`, `POST .../rename`, `POST .../tags`, `DELETE .../tags/{tag_id}` | `locations:write` |
| `GET /api/v1/reports/asset-locations`, `GET /api/v1/assets/{id}/history`                                    | `tracking:read`   |

Two consequences for the contract probes on this track:

- **403 is unreachable on the public surface with this key.** The fixture key is intentionally broad enough to cover the full public contract, so there's no endpoint it can be 403'd against. If 403 coverage is desired, the harness would need to provision a narrower-scope key alongside (e.g., mint an `assets:read`-only key via the SPA) — this track doesn't. Per BB.md § 8, note the gap briefly in FINDINGS.md context and move on; don't fabricate a scope mismatch you can't actually reach.
- **You may exercise DELETE, but only on rows your session created.** Every probe creates rows with a session-specific `external_key` prefix — those are unambiguously yours to DELETE as the canonical end of the create → read → update → read → **delete** lifecycle. **Never DELETE a pre-existing fixture row** (anything seeded for BB1/BB2/BB3 by the parallel-fixture setup). Parallel sessions share the fixture, and a fixture-row DELETE damages every concurrent run's state and orphans scan history. The mint-key track in [BB_MINT_KEY.md](./BB_MINT_KEY.md) covers DELETE against a freshly-minted scope and has no fixture-sharing concern; this track covers DELETE against session-scoped rows only.

The fixture key is **platform-managed and persistent**. Do not revoke it. Do not delete the org. Do not delete pre-existing assets or locations. Clean up only what your session creates — anything you POST during the run is yours to DELETE or otherwise revert before exiting.

## Mission

Load `$BB_API_KEY`, confirm you can reach `/health.json` and `/api/openapi.yaml`, then **read [BB.md](./BB.md) top to bottom and execute the shared methodology** against the fixture.

**If authentication fails before you can hit endpoints (key invalid, scope mismatch, `org_id` mismatch with the key, etc.), that is the report.** Document the failure point with verbatim error output and stop. A short report saying "the `$BB_ORG` key returns 401/403 against `/api/v1/assets`, here is exactly what I saw" is more useful than a speculative report against endpoints you couldn't reach.

Lean on the determinism of the fixture: literal-value assertions against the seeded `external_key`s are cheaper and more diagnostic than rediscovering shape each run. If a literal assertion fails (e.g., `WHS-01` is missing, `GET /api/v1/locations/{id}/ancestors` returns a chain that doesn't match the documented two-subtree hierarchy), that's a finding worth tracing to either a seed drift or a service-vs-docs disagreement.
