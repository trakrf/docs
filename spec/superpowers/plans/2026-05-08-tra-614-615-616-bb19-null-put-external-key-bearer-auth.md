# TRA-614 + TRA-615 + TRA-616 BB19 — null-tolerant PUT + external_key pattern + BearerAuth scheme — Implementation Plan

**Goal:** Catch trakrf-docs up to platform PR #275. Three coupled additions in `resource-identifiers.md` (FK disagree shape, external_key value rules, tree_path rename behavior) + one-line codegen note in `quickstart.mdx` + spec refresh.

**Architecture:** Five sequential commits on a feature branch — design + plan + spec refresh + prose edits + verification. Verification is `pnpm build`.

**Tech Stack:** Docusaurus 3.9, pnpm. No backend code.

---

## File Structure

| File | Change |
| --- | --- |
| `spec/superpowers/specs/2026-05-08-tra-614-615-616-bb19-null-put-external-key-bearer-auth-design.md` | Written, committed in Task 1 |
| `spec/superpowers/plans/2026-05-08-tra-614-615-616-bb19-null-put-external-key-bearer-auth.md` | This file, committed in Task 2 |
| `static/api/openapi.json` | Refreshed (pattern + nullable + BearerAuth) |
| `static/api/openapi.yaml` | Refreshed |
| `static/api/trakrf-api.postman_collection.json` | Regenerated |
| `static/api/platform-meta.json` | Bumped to `platform@1026812` |
| `docs/api/resource-identifiers.md` | Rewrite FK-pair write rule; add `## external_key value rules` section; update tree_path section for new pattern + rename behavior |
| `docs/api/quickstart.mdx` | Add Bearer-shaped codegen note in §5 |

---

### Task 1: Commit the design doc

```bash
git add spec/superpowers/specs/2026-05-08-tra-614-615-616-bb19-null-put-external-key-bearer-auth-design.md
git commit -m "docs(spec): TRA-614+615+616 BB19 design — null-tolerant PUT + external_key pattern + BearerAuth"
```

### Task 2: Commit this plan

```bash
git add spec/superpowers/plans/2026-05-08-tra-614-615-616-bb19-null-put-external-key-bearer-auth.md
git commit -m "docs(plan): TRA-614+615+616 BB19 plan — null-tolerant PUT + external_key pattern + BearerAuth"
```

### Task 3: Commit the spec refresh

Files refreshed by `bash scripts/refresh-openapi.sh` against `platform@1026812`:

- `static/api/openapi.json` — `pattern: ^[A-Za-z0-9-]+$` on every write `external_key`/`*_external_key`; `nullable: true` on `description`, `location_id`, `location_external_key`, `parent_id`, `parent_external_key` write properties; security scheme rename `APIKey` → `BearerAuth` (and per-operation `security:` blocks flipped accordingly).
- `static/api/openapi.yaml` — same.
- `static/api/trakrf-api.postman_collection.json` — regenerated.
- `static/api/platform-meta.json` — SHA bump to `1026812`.

```bash
git add static/api/openapi.json static/api/openapi.yaml static/api/trakrf-api.postman_collection.json static/api/platform-meta.json
git commit -m "chore(api): refresh openapi spec from platform main (TRA-614+615+616)"
```

### Task 4: Prose edits (single commit)

**`docs/api/resource-identifiers.md`:**

- **Line 141** ("Either form of the FK pair is accepted on write... Don't send both... mutually exclusive"): rewrite as three rules — (a) either form accepted; (b) sending both is allowed when they agree, disagreement returns `400 invalid_value` with `detail` like `"location_id and location_external_key disagree"`; (c) sending `null` clears (covers description + valid_to too — keep tight, link to the date-fields page for the `valid_to` story).
- **NEW** small subsection or callout naming the writable-nullable set per resource, so partners know the round-trip semantics in one place: asset has `description`, `location_id`, `location_external_key`, `valid_to`; location has `description`, `parent_id`, `parent_external_key`, `valid_to`. Place inline near the FK rule (no big new heading needed).
- **NEW `## external_key value rules` section** between line 196 (end of "Asset `external_key` is optional") and line 198 (start of "`is_active` is authoritative"). Content: pattern `^[A-Za-z0-9-]+$`; reserved chars (space, slash, colon, period, underscore) and the reason for each (period = segment separator; underscore = segment-internal separator after normalization; the rest are URL/log/path-hostile); invalid input returns `400 validation_error`; case is preserved on the key but lowercased in `tree_path`.
- **Tree-path section (lines 170–174)**: drop the "literal period" and "already-contain-underscores" caveats (now impossible under the pattern); keep the case-collision note; add rename-rewrites-descendants behavior with cache-invalidation guidance — recommend the ancestors endpoint or `?external_key=` lookup over caching `tree_path`.

**`docs/api/quickstart.mdx`:**

- **§5 "Raw spec for codegen"**: append a one-sentence note that generated SDKs surface the credential as a Bearer access token (e.g., `Configuration.accessToken` in `openapi-generator-cli`'s typescript-fetch target); wire format remains `Authorization: Bearer <jwt>`.

Verify:

- `grep -n "mutually exclusive" docs/api/resource-identifiers.md` → 0 hits, or rephrased so accurate.
- `grep -n "disagree" docs/api/resource-identifiers.md` → ≥1 hit.
- `grep -n "\^\[A-Za-z0-9-\]" docs/api/resource-identifiers.md` → ≥1 hit.
- `grep -ni "cache.*tree_path\|tree_path.*cache" docs/api/resource-identifiers.md` → ≥1 hit.
- `grep -n "Bearer access token\|Configuration\.accessToken" docs/api/quickstart.mdx` → ≥1 hit.

```bash
git add docs/api/resource-identifiers.md docs/api/quickstart.mdx
git commit -m "docs(api): null-tolerant PUT + external_key pattern + tree_path rename + BearerAuth codegen note (TRA-614+615+616)"
```

### Task 5: Verify build

```bash
pnpm build
```

Must succeed with no broken-link warnings.

### Task 6: Push and open PR

```bash
git push -u origin miks2u/tra-614-615-616-bb19-null-put-external-key-bearer-auth
gh pr create --title "docs(api): TRA-614+615+616 BB19 — null-tolerant PUT + external_key pattern + BearerAuth" --body "..."
```

---

## Acceptance

- `pnpm build` passes.
- `static/api/platform-meta.json` records `platform@1026812`.
- Resource-identifiers FK-pair write rule documents the disagree-shape error.
- Resource-identifiers has an `external_key` value-rules section naming the pattern and reserved characters.
- Resource-identifiers tree_path section warns against caching after a rename.
- Quickstart §5 names the Bearer-shaped codegen output.
- PR opened against `main`.
