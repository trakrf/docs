# trakrf API black-box harness — backlog

Project-specific operational artifact alongside [BB.md](./BB.md). BB.md is methodology (forkable across API projects); this file is TrakRF-specific content: internal-only deliberate states and deferred work with explicit triggers for revisit.

Customer-visible deliberate states do **not** live here — they go to [`/docs/api/design-notes`](../../docs/api/design-notes.md).

## Internal-only deliberate states

Items not surfaced to integrators because they describe how the harness operates rather than how the API is designed.

| State                                       | Origin        | Rationale                                                                                                                                                                                                                                |
| ------------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BSL licensing wrinkle on evaluator probes   | BB.md design  | Code is publicly available under BSL but most evaluators won't pull and inspect the repo before forming first impressions. The persona constraint replicates this. Internal methodology consideration; not a customer-facing design choice. |

If future cycles surface other internal-only deliberate states, add them here. Anything integrator-visible goes to `/docs/api/design-notes`.

## Deferred work

Items with real fixes that cost-benefit deliberately deferred. Each entry has an explicit trigger condition; the registry is groomed at post-launch milestones and whenever a trigger fires.

| Work                                                                                          | Origin                | Trigger to revisit                                                                                                                                                                                                                                                          |
| --------------------------------------------------------------------------------------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bigint storage migration                                                                      | TRA-720               | When cloud catches up to preview schema state AND customer volume hits the int32 ceiling (or enterprise data-residency requirements force it sooner). Retires the wire-vs-runtime int64 soft contract entirely; path-param maximum constraint (TRA-726) removed in same PR. |
| OpenAPI 3.1 migration                                                                         | BB37 F5 context       | When the generator ecosystem stabilizes 3.1 support across all targets we care about. Fixes `datamodel-codegen` nullable handling without per-generator workarounds; would let us drop the nullable design note from `/docs/api/design-notes`.                              |
| Path-param maximum constraint removal                                                         | BB37 F2 / TRA-726     | Same trigger as bigint storage migration (TRA-720). Documented in TRA-726 acceptance criteria.                                                                                                                                                                              |
| Add `x-extensible-enum: true` annotations to `tag_type` discriminator and `OrgView.scopes`    | BB39 F7               | Same trigger as the OpenAPI 3.1 migration above. 3.1's `const` keyword and improved discriminator support let us express closed/open splits cleanly; a standalone annotation now would carry forward, but the 3.1 migration retires the question.                          |
| Tighten `AssetLocationItem.asset_id` and `.asset_external_key` to non-nullable                | BB39 F8               | When confident no data path produces null in these columns. Currently empirically null-free across observed data, but tightening is a breaking change for clients that have already taught themselves to null-check. Revisit during a v2 boundary or when v1 data semantics are fully audited. |
