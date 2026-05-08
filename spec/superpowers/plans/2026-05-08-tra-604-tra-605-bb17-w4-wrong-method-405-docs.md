# TRA-604+TRA-605 BB17 W4 — wrong-method 405 spec refresh — Implementation Plan

**Goal:** Catch trakrf-docs up to platform PR #273. Spec-refresh-only — no prose edits.

**Architecture:** Three sequential commits on a feature branch — design + plan + spec refresh (single autogen commit). Verification is `pnpm build`.

**Tech Stack:** Docusaurus 3.9, pnpm. No backend code.

---

## File Structure

| File | Change |
| --- | --- |
| `spec/superpowers/specs/2026-05-08-tra-604-tra-605-bb17-w4-wrong-method-405-docs-design.md` | Written, committed in Task 1 |
| `spec/superpowers/plans/2026-05-08-tra-604-tra-605-bb17-w4-wrong-method-405-docs.md` | This file, committed in Task 2 |
| `static/api/openapi.json` | Refreshed (`orgs.me` gains `405` response) |
| `static/api/openapi.yaml` | Refreshed |
| `static/api/trakrf-api.postman_collection.json` | Regenerated |
| `static/api/platform-meta.json` | Regenerated to `platform@4e04cfb` |

No `docs/` prose edits. The existing `errors.md` already documents `method_not_allowed` (405) with `Allow` header semantics — runtime behavior caught up to the docs, not the other way round.

---

### Task 1: Commit the design doc

```bash
git add spec/superpowers/specs/2026-05-08-tra-604-tra-605-bb17-w4-wrong-method-405-docs-design.md
git commit -m "docs(spec): TRA-604+TRA-605 BB17 W4 design — wrong-method 405 spec refresh"
```

### Task 2: Commit this plan

```bash
git add spec/superpowers/plans/2026-05-08-tra-604-tra-605-bb17-w4-wrong-method-405-docs.md
git commit -m "docs(plan): TRA-604+TRA-605 BB17 W4 plan — wrong-method 405 spec refresh"
```

### Task 3: Commit the spec refresh

Files refreshed by `bash scripts/refresh-openapi.sh` against `platform@4e04cfb`:
- `static/api/openapi.json` (+18 lines: `405` response on `orgs.me`)
- `static/api/openapi.yaml` (+11 lines)
- `static/api/trakrf-api.postman_collection.json` (regenerated)
- `static/api/platform-meta.json` (SHA bump)

```bash
git add static/api/openapi.json static/api/openapi.yaml static/api/trakrf-api.postman_collection.json static/api/platform-meta.json
git commit -m "chore(api): refresh openapi spec from platform main (TRA-604+TRA-605)"
```

### Task 4: Verify build

```bash
pnpm build
```

Must succeed with no broken-link warnings. The spec change adds a response shape; no internal links touched.

### Task 5: Push and open PR

```bash
git push -u origin miks2u/tra-604-tra-605-bb17-w4-wrong-method-405-docs
gh pr create --title "docs(api): TRA-604+TRA-605 BB17 W4 — refresh openapi spec for wrong-method 405 fix" --body "..."
```

---

## Acceptance

- `pnpm build` passes.
- `static/api/platform-meta.json` records `platform@4e04cfb`.
- `static/api/openapi.json` includes a `405` response on `orgs.me`.
- No prose edits in `docs/`.
- PR opened against `main`.
