---
ticket: TRA-587
parent: TRA-583
date: 2026-05-07
status: design
---

# TRA-587 — BB16 S8 — read ↔ write field asymmetry, mark readOnly fields (docs side)

## Goal

Close the trakrf-docs side of TRA-587 now that the platform PR (#268) has merged. Two acceptance criteria from the ticket fall to docs:

1. Pull the refreshed OpenAPI spec so the bundled `static/api/openapi.{json,yaml}` and Postman collection reflect the `readOnly: true` markers added on `asset.PublicAssetView` and `location.PublicLocationView`.
2. Document the Option A behavior (strict reject of unknown fields) on the resource-identifiers page, with explicit per-resource read-only field lists for assets and locations.

## Background

The platform PR went with **Option A** — the v1 service returns `400 validation_error` for unknown fields on `PUT`, including server-managed fields like `id`, `created_at`, `updated_at`, `tags`, `tree_path`, `depth`. Generated SDKs (typescript-fetch, openapi-generator) honor the spec's `readOnly: true` markers and split read and write types so the strip is enforced at compile time. Hand-rolled clients have to strip explicitly.

`docs/api/resource-identifiers.md` already has a substantial **"Read shape vs. write shape"** subsection covering this asymmetry — it predates the platform fix and was written when the readOnly markers were the planned-but-not-yet-shipped state. Now that the markers are live, the section needs two surgical updates:

- An explicit sentence that the spec carries `readOnly: true` markers (today the page implies this when it says "in a generated TypeScript client with strict typing, the read response type and the write request type are distinct" — but never names the mechanism).
- A per-resource read-only field list for **locations** matching the existing per-resource list for assets. Today locations is described as prose ("notably the derived `tree_path` and `depth` in addition to the metadata fields"); per the platform handoff comment, integrators shouldn't have to grep the OpenAPI spec to know what to strip.

The Option A vs Option B decision is settled. The ticket's fallback rule was Option A unless TRA-592 (personas / sync-workflow lens) lands first and flips the call. TRA-592 is still in Backlog. Option A → Option B is the non-breaking direction; the docs guidance documented now stays correct after a future flip (clients that strip read-only fields will continue to work under Option B, even if the strip becomes optional).

## Scope

### 1. Refresh OpenAPI spec

Run `pnpm refresh-openapi` to fetch the latest `openapi.public.{json,yaml}` from `trakrf/platform@main`. This regenerates the Postman collection and updates `platform-meta.json`. Commit as a `chore(api): refresh openapi spec from platform main` commit so the spec refresh is reviewable independently of the prose changes.

The TRA-587 readOnly markers themselves were already pulled in by yesterday's TRA-588 refresh (commit 88b0e2c). The new refresh picks up incremental drift (path-param naming consistency in the platform spec) along with confirming the readOnly state.

### 2. Edit `docs/api/resource-identifiers.md`, "Read shape vs. write shape" section

Three targeted prose edits, scoped to lines 93–138 of the existing file:

**a. Name the mechanism.** Add a sentence noting the OpenAPI spec marks server-managed fields with `readOnly: true`, and that this is what enables the SDK type-system split. Keeps the existing "what to do" guidance; just names the "how" so integrators reading the spec see the markers and know they're load-bearing.

**b. Make the locations read-only set explicit.** Replace the prose "Locations have a larger read-only set (notably the derived `tree_path` and `depth` in addition to the metadata fields)" with a one-line list mirroring the asset list two paragraphs earlier: `id`, `created_at`, `updated_at`, `tree_path`, `depth`, `tags`. Keep the surrounding context about derived fields and per-resource SDK guidance.

**c. Light copy edit.** Tighten any sentences in the section that read awkwardly after edits (a) and (b).

### 3. No CHANGELOG entry

`docs/api/CHANGELOG.md` is reserved for v1 launch (TBD). Option A is the existing service behavior and the readOnly markers are an additive spec annotation — nothing changed for integrators that wasn't true yesterday. The documentation update is the change.

## Out of scope

- Doc edits to other pages. The Read/Write asymmetry topic is fully owned by `resource-identifiers.md`; no cross-references to update.
- Hunting additional read-only fields on other public schemas. Per the platform handoff comment, `apikey.PublicAPIKeyView` doesn't exist on the public spec (TRA-578 flipped api-keys to internal-only), and no other schemas surfaced.
- Codegen smoke test. The ticket lists a typescript-fetch codegen smoke as acceptance, but that runs on the platform CI side; docs CI doesn't generate clients.

## Acceptance

- [ ] `static/api/openapi.{json,yaml}` and the Postman collection are refreshed from platform main; `platform-meta.json` updated.
- [ ] `docs/api/resource-identifiers.md` "Read shape vs. write shape" section explicitly names the spec's `readOnly: true` markers and lists the per-resource read-only fields for both assets and locations.
- [ ] `pnpm build` succeeds; Redoc renders the refreshed spec without errors.
- [ ] PR opened against main with conventional-commit title.

## References

- Platform PR: trakrf/platform#268 (merged)
- Parent: TRA-583 (BB16 launch readiness epic)
- Related: TRA-592 (personas + use cases, sync-workflow lens — non-blocking)
- Page being edited: `docs/api/resource-identifiers.md`, "Read shape vs. write shape" subsection
