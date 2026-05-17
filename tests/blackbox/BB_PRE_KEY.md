# trakrf API — black-box evaluation (pre-key track)

You have a pre-minted API key for one of three parallelism-fixture orgs. Use it to exercise the API contract. This is the **contract track**: you skip the onboarding/mint workflow entirely and run the shared methodology in [BB.md](./BB.md) against a deterministic fixture. Parallel sessions can run this track simultaneously, each pinned to a different fixture org.

The onboarding experience (login → mint → first call) is evaluated by [BB_MINT_KEY.md](./BB_MINT_KEY.md). Don't duplicate that work here — if you incidentally observe an onboarding gap while orienting, note it briefly but stay focused on contract probes.

## Environment

`.envrc` + `.env.local` expose:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `BB_ORG` — selector: `BB1`, `BB2`, or `BB3`. Set by the orchestrator launching the session; each parallel session is assigned exactly one.
- `BB1_API_KEY` / `BB2_API_KEY` / `BB3_API_KEY` — persistent JWTs for each fixture org. Use the one matching `$BB_ORG`.
- `BB1_ORG_ID` / `BB2_ORG_ID` / `BB3_ORG_ID` — numeric `org_id` for each fixture, useful for traceability and cross-checks.

Resolve `$BB_ORG` once at session start. Read the value of `${BB_ORG}_API_KEY` (e.g., if `BB_ORG=BB2`, use `$BB2_API_KEY`) and pass it as the `Authorization: Bearer …` token on every call. Record `$BB_ORG` and the corresponding `${BB_ORG}_ORG_ID` in the FINDINGS.md context block so triage can correlate runs.

If `$BB_ORG` is unset, stop and report — the orchestrator did not assign this session a fixture, and guessing is wrong.

There is no SPA login on this track. The fixture key is everything you need; do not attempt to use `API_TEST_LOGIN` / `API_TEST_PASS`.

## Fixtures

BB1, BB2, and BB3 carry identical, deterministic data. You can assert against literal values; shape-discovery passes are unnecessary.

**Locations — 8 per org, two side-by-side subtrees:**

- OC subtree (2 nodes): `WHS-01` "Main Warehouse" → `WHS-07-03` "Warehouse 7 Bay 3"
- CD subtree (6 nodes): `CD-WHS-01` "Warehouse" → `BAY-07` "Bay 7" → `SHELF-0001` "Bay 7 Shelf 1"; `LOC-0001` "The Universe" → `LOC-003` "milky way galaxy"; standalone `LOC-002` "Other universe"
- Every `parent_location_id` resolves within the same org. Tree integrity is verified on seed.

**Assets — 31 per org:**

- 11 OC-origin, 20 CD-origin. CD-origin assets that would have collided with OC use a `CD-` prefix: `CD-ASSET-0001` through `CD-ASSET-0007`.
- All assets start with `current_location_id = NULL`. Once scan history lands (next), some will resolve to a current location.

**Scans:** TBD. Fake `asset_scans` (~25/asset over 90 days, ~775/org) will be added next and will populate `current_location_id` per asset. Until then, `tracking:read` coverage is provisional — exercise the endpoint shape, but assert sparingly against scan-derived state.

**Tags:** not copied. Tags are not in v1 public-API scope.

## Key scope and lifecycle

The fixture key on each org is `bb-parallel-permanent`, no expiry, with scopes:

```
assets:read, assets:write, locations:read, locations:write, tracking:read
```

No `*:delete`, no `tags:*`. Two consequences:

- **403 probes are easy.** Forcing a 403 against any delete or tags endpoint is straightforward — the key is intentionally narrow.
- **You cannot exercise DELETE.** Stop at "create → read → update → read" for any CRUD lifecycle on this track. The DELETE leg is reserved for [BB_MINT_KEY.md](./BB_MINT_KEY.md), where the admin-minted key can include `*:delete`. Note the coverage gap in FINDINGS.md context but do not treat it as a finding — it's a deliberate split between the two tracks.

The fixture key is **platform-managed and persistent**. Do not revoke it. Do not delete the org. Do not delete pre-existing assets or locations. Clean up only what your session creates — anything you POST during the run is yours to DELETE-equivalent (`current_location_id = NULL` reset, archive, etc.) or otherwise revert before exiting.

## Mission

Resolve `$BB_ORG`, load `${BB_ORG}_API_KEY`, confirm you can reach `/health.json` and `/api/openapi.yaml`, then **read [BB.md](./BB.md) top to bottom and execute the shared methodology** against the fixture.

**If authentication fails before you can hit endpoints (key invalid, scope mismatch, `org_id` mismatch with the key, etc.), that is the report.** Document the failure point with verbatim error output and stop. A short report saying "the `$BB_ORG` key returns 401/403 against `/api/v1/assets`, here is exactly what I saw" is more useful than a speculative report against endpoints you couldn't reach.

Lean on the determinism of the fixture: literal-value assertions against the seeded `external_key`s are cheaper and more diagnostic than rediscovering shape each run. If a literal assertion fails (e.g., `WHS-01` is missing, `tree_path` doesn't match the documented derivation), that's a finding worth tracing to either a seed drift or a service-vs-docs disagreement.
