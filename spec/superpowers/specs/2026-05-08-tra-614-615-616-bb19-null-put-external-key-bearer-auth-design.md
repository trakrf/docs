---
ticket: TRA-614, TRA-615, TRA-616
parent: TRA-613
date: 2026-05-08
status: design
---

# TRA-614 + TRA-615 + TRA-616 — BB19 §S1/§S5+§C2+§S8/§S6 — null-tolerant PUT + external_key pattern + BearerAuth scheme — design

## Goal

Catch trakrf-docs up to platform PR #275 (merged on `main`, resolves to commit `1026812`). Three coupled BB19 fixes shipped together; this docs PR teaches the new rules in one prose pass.

1. **§S1 (TRA-614)** — `description`, `location_id`, `location_external_key` (asset) and `description`, `parent_id`, `parent_external_key` (location) now accept JSON `null` on `PUT` and clear the column. `valid_to` already accepted `null` (BB18); this brings the rest of the read-side-nullable fields in line. Spec marks the corresponding `Update*Request` and `*CreateWithTagsRequest` properties `nullable: true`. Platform also surfaced a cross-field validation: when both `location_id` and `location_external_key` are sent in one request, they must agree — disagreement (one `null`, the other set) returns `400 invalid_value` with detail `"location_id and location_external_key disagree"` (same shape for parent on locations).
2. **§S5 + §C2 + §S8 (TRA-615)** — `external_key` is now constrained by pattern `^[A-Za-z0-9-]+$` (alphanumerics + hyphen only). Reserved characters: space, slash, colon, period, underscore. Period is reserved because it's the `tree_path` segment separator; underscore is reserved because it's the segment-internal separator after normalization. Invalid input now returns `400 validation_error` (was `500 internal_error` for space/slash/colon). Renaming an external_key still rewrites that node's and all descendants' `tree_path` values — documented as expected, with cache-invalidation guidance for clients.
3. **§S6 (TRA-616)** — public security scheme renamed `APIKey` → `BearerAuth`. Cosmetic for `openapi-typescript` (which ignores the security block) but class-emitting codegen tools (`openapi-generator-cli`'s typescript-fetch, python, java) now produce a configuration object with bearer-shaped naming (e.g., `Configuration.accessToken` rather than `Configuration.apiKey`). Wire format unchanged — still `Authorization: Bearer <jwt>`.

The trakrf-docs repo currently teaches around these contracts but doesn't yet:

- explain how to **clear** a nullable write field by sending `null` (clearing semantics aren't documented for any of the six fields, including `valid_to` from BB18);
- describe the cross-field disagreement error shape on FK pairs — the current rule on `resource-identifiers.md` line 141 reads "Don't send both for the same relationship in one request — the server validates them as mutually exclusive," which is wrong: sending both is allowed when the values agree, and the failure mode for disagreement has a specific 400 envelope worth naming;
- specify the `external_key` value rules — the current text only documents how `external_key` is *used* (lookup, FK pair), never what characters are valid;
- explain `tree_path` rename behavior or warn against caching `tree_path` (the page does cover the lossy-derivation point, but not the rewrite-on-rename consequence);
- mention that codegen consumers see Bearer-shaped configuration objects after the spec refresh.

## Scope

### 1. OpenAPI spec refresh

Already pulled by `bash scripts/refresh-openapi.sh` against `platform@main` (resolves to `1026812`). Picks up:
- `pattern: ^[A-Za-z0-9-]+$` on every `external_key` / `*_external_key` write property (asset + location create/update);
- `nullable: true` on `description`, `location_id`, `location_external_key`, `parent_id`, `parent_external_key` write properties;
- security scheme rename `APIKey` → `BearerAuth` (every operation's `security:` block flips with it);
- regenerated Postman collection.

Single `chore(api):` commit, reviewable independently from prose.

### 2. `docs/api/resource-identifiers.md`

Three coupled additions/edits:

**Read shape vs. write shape (around line 141)** — replace the existing "Don't send both" prose with a more accurate three-rule statement:

- Either form of the FK pair is accepted on write — send `location_id` if you have it, `location_external_key` if that's what the user typed.
- Sending **both** is allowed when they agree (server cross-validates). Disagreement (e.g., `location_id: 42, location_external_key: null`) returns `400 invalid_value` with `detail` like `"location_id and location_external_key disagree"`.
- Sending **`null`** on one or both forms clears the relationship. Same applies to `description` (asset + location). For locations, the same rules cover the `parent_id` / `parent_external_key` pair.

Add a brief callout listing the writable-nullable set so integrators know the round-trip-with-null story without re-reading the BB18 plus BB19 changelog: asset writable-nullables are `description`, `location_id`, `location_external_key`, `valid_to`; location writable-nullables are `description`, `parent_id`, `parent_external_key`, `valid_to`. Send `null` to clear; the read response carries `null` after the clear.

**New `## external_key` section** — add a section between "Asset `external_key` is optional" (line 176) and "`is_active` is authoritative" (line 198). Documents:

- Pattern: `^[A-Za-z0-9-]+$` — alphanumerics + hyphen only.
- Reserved characters and why: period is the `tree_path` segment separator; underscore is the segment-internal separator (after `external_key`'s hyphens are substituted to underscore in the derivation); space, slash, colon are URL-/log-/path-hostile.
- Invalid input returns `400 validation_error` / `invalid_value`. Examples: `BB With Spaces`, `BB/slash`, `BB:colon`, `BB.dotted`, `BB_underscored` all reject.
- Note that case is preserved as written (`MyAsset` and `myasset` are distinct external_keys), but `tree_path` lower-cases all segments — see the `tree_path` derivation note below.

**Tree-path section (lines 170–174)** — the existing prose already covers lossy lowercase + hyphen-to-underscore derivation. Update for the new pattern reality:

- Drop the "outright wrong if any ancestor's `external_key` contains a literal period" warning — periods are now forbidden, so this case can't arise.
- Drop the "lossy on `external_key`s that already contain underscores" caveat — underscores are now forbidden too.
- Keep the case-sensitivity caveat — `WAREHOUSE` and `warehouse` are distinct keys but produce the same tree-path segment.
- Add: renaming an `external_key` rewrites that node's `tree_path` and every descendant's `tree_path`. Clients that cache `tree_path` will silently desync after a rename. Don't cache it — query by `external_key` chain or use `GET /api/v1/locations/{id}/ancestors`.

### 3. `docs/api/quickstart.mdx` — codegen note

Section §5 ("Raw spec for codegen") currently lists generators in one sentence with no callout about what shape the auth config takes. Add a one-line note that generated SDKs surface the credential as a Bearer access token (e.g., `Configuration.accessToken` for `openapi-generator-cli typescript-fetch`); the wire format remains `Authorization: Bearer <jwt>`. This pre-empts the "auth setup took an hour" friction TRA-616 names.

No change to `authentication.md` — the credential is still called an API key (a JWT scoped to an org); only the spec scheme name (consumed by codegen) changed. Customer-facing concept is unchanged.

## Out of scope

- **Existing-data data migration (TRA-620)** — 11 preview location rows with underscored external_keys (B1_S1, OFFICE_1, etc.) will fail PUT round-trip until renamed. Filed as a separate ticket and queued for the platform side; per project memory ("pre-launch, fix state not docs"), the data state gets reseeded, not documented.
- **Broad-probe 500 follow-ups (TRA-619)** — two pre-existing 500 paths (PUT body strips to no writable fields; scalar string into `jsonb` metadata). Not regressions of #275; tracked separately.
- **`authentication.md` rewrite** — the credential is conceptually still an API key. The scheme rename is a codegen detail, not a customer-facing rebrand. No change to the auth page.
- **Internal `SessionAuth` rename** — the platform also renamed the internal session-JWT scheme. Stripped from the public spec; no public docs reference the internal scheme name.
- **API CHANGELOG entry** — pre-launch (v1 not yet released). Per standing project memory, fix the state, don't backfill changelog entries before launch.

## Acceptance

- `static/api/platform-meta.json` records `platform@1026812`.
- `pnpm build` passes with no broken-link warnings.
- `grep -n "mutually exclusive" docs/api/resource-identifiers.md` returns 0 hits (or the prose has been rewritten so the assertion is correct).
- `grep -n "disagree" docs/api/resource-identifiers.md` returns at least 1 hit naming the conflict-shape detail.
- `grep -n "\^\[A-Za-z0-9-\]" docs/api/resource-identifiers.md` returns at least 1 hit (the pattern is documented).
- `grep -n "tree_path.*cache\|cache.*tree_path" docs/api/resource-identifiers.md` returns at least 1 hit (cache-invalidation note).
- `grep -n "Configuration\.accessToken\|Bearer access token" docs/api/quickstart.mdx` returns at least 1 hit.
- TRA-614, TRA-615, TRA-616 moved to Done after merge.
