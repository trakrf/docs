# trakrf API black-box harness — backlog

Project-specific operational artifact alongside [BB.md](./BB.md). BB.md is methodology (forkable across API projects); this file is TrakRF-specific content: internal-only deliberate states and deferred work with explicit triggers for revisit.

Customer-visible deliberate states do **not** live here — they go to [`/docs/api/design-notes`](../../docs/api/design-notes.md).

## Internal-only deliberate states

Items not surfaced to integrators — either harness operating concerns, or API design choices whose affected audience is too narrow to warrant a customer-facing design note.

| State                                     | Origin       | Rationale                                                                                                                                                                                                                                   |
| ----------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BSL licensing wrinkle on evaluator probes | BB.md design | Code is publicly available under BSL but most evaluators won't pull and inspect the repo before forming first impressions. The persona constraint replicates this. Internal methodology consideration; not a customer-facing design choice. |

### UpdateRequest schemas intentionally omit `additionalProperties: false`

**State:** `UpdateAssetRequest` and `UpdateLocationRequest` do not declare `additionalProperties: false` in the OpenAPI spec, despite their Create counterparts (`CreateAssetRequest`, `CreateLocationRequest`) doing so. The asymmetry is visible to anyone diffing the schemas.

**Disposition:** Not drift. Deliberate per TRA-719 B1 (2026-05-14), citing TRA-710 (BB33 F2). The service performs unknown-field rejection at the runtime validator (`validation_error` / `unknown_field`); the spec leaves the property bag open so strict generators (Pydantic `extra='forbid'`, Java/Kotlin strict mode, `openapi-generator` with `disallowAdditionalPropertiesIfNotPresent=true`) do not reject `GET → PATCH` round-trip clients at construction time when read-only echo fields are present on the GET response. The rationale also lives in a `postprocess.go` comment in the platform repo.

**For BB cycles:** Confirm runtime unknown-field rejection still fires by probing `PATCH /api/v1/assets/{id}` (and the location equivalent) with `{"wat": 1}` and asserting a `validation_error` envelope with `fields[0].code: "unknown_field"`. Do not flag the spec asymmetry between Create and Update schemas as drift.

If future cycles surface other internal-only deliberate states, add them here. Anything integrator-visible goes to `/docs/api/design-notes`.

## Deliberate fixture states

Test-org artifact states that BB cycles will observe but should not flag as service or contract findings. Each entry records the state, why it's expected, and the post-launch path to resolve it.

### Soft-deleted fixture accumulation in the test org

**State:** Soft-deletes accumulate in the test org across BB cycles by design — [BB.md](./BB.md) instructs each cycle not to clean prior cycles' artifacts. As of BB44: `GET /assets?include_deleted=true` returns `total_count: 270` against `total_count: 8` for the default live view (~33× expansion); smaller-scale accumulation on locations.

**Disposition:** Not a service finding and not a contract finding. BB cycles should surface this only as fixture-maintenance for the orchestrator — do not file as a finding against `/assets`, `/locations`, or the soft-delete model.

**Eventual fix (post-launch):** Build a deliberately scoped test fixture — target ~hundreds of assets and 20–30 locations with at least a 2-deep hierarchy — and reset the test org as part of fixture provisioning so every BB cycle starts from a known-good baseline. Held back from launch scope as a "good in theory, not needed to ship" item.

## Deferred work

Items with real fixes that cost-benefit deliberately deferred. Each entry has an explicit trigger condition; the registry is groomed at post-launch milestones and whenever a trigger fires.

| Work                                                                                       | Origin          | Trigger to revisit                                                                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------ | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OpenAPI 3.1 migration                                                                      | BB37 F5 context | When the generator ecosystem stabilizes 3.1 support across all targets we care about. Fixes `datamodel-codegen` nullable handling without per-generator workarounds; would let us drop the nullable design note from `/docs/api/design-notes`.    |
| Add `x-extensible-enum: true` annotations to `tag_type` discriminator and `OrgView.scopes` | BB39 F7         | Same trigger as the OpenAPI 3.1 migration above. 3.1's `const` keyword and improved discriminator support let us express closed/open splits cleanly; a standalone annotation now would carry forward, but the 3.1 migration retires the question. |
