# TRA-617 BB19 §W1 — Key management scope row in authentication docs — Implementation Plan

**Goal:** Add the Key management → Admin / `keys:admin` row to the authentication scopes tables and explain it's reserved for a v2 programmatic key-minting capability that isn't part of the v1 public surface.

**Architecture:** Three sequential commits on a feature branch — design + plan + prose edit. Verification is `pnpm build`.

**Tech Stack:** Docusaurus 3.9, pnpm. No backend code, no spec refresh (the public OpenAPI doesn't expose `keys:admin` endpoints; that's the point).

---

## File Structure

| File | Change |
| --- | --- |
| `spec/superpowers/specs/2026-05-08-tra-617-bb19-w1-key-management-scope-docs-design.md` | Written, committed in Task 1 |
| `spec/superpowers/plans/2026-05-08-tra-617-bb19-w1-key-management-scope-docs.md` | This file, committed in Task 2 |
| `docs/api/authentication.md` | Add Key management → Admin row to UI labels table; add `keys:admin` row to scope table; add reserved-for-v2 subsection |

No other docs changes — adjacent audit confirmed authentication.md is the sole surface that enumerates scope-strings.

---

### Task 1: Commit the design doc

```bash
git add spec/superpowers/specs/2026-05-08-tra-617-bb19-w1-key-management-scope-docs-design.md
git commit -m "docs(spec): TRA-617 BB19 §W1 design — Key management scope row in authentication docs"
```

### Task 2: Commit this plan

```bash
git add spec/superpowers/plans/2026-05-08-tra-617-bb19-w1-key-management-scope-docs.md
git commit -m "docs(plan): TRA-617 BB19 §W1 plan — Key management scope row in authentication docs"
```

### Task 3: Edit `docs/api/authentication.md`

- **UI labels table** (around lines 50–58): add row `| Key management → Admin | \`keys:admin\` |` after the History row.
- **Scope table** (around lines 60–66): add row `| \`keys:admin\` | Admin | (reserved — see note below) |`.
- **Surrounding prose** (around line 58 — "Selecting None for a resource grants no scope... no write-only level today"): adjust to also note that Key management has only None / Admin (no Read / Write split).
- **New subsection after line 71** (after the non-obvious pairings list, before "Additional scopes may be added in any v1 release"): `### Key management is reserved for v2 {#key-management-reserved}` explaining the scope gates no v1 public endpoint, key issuance is browser-mediated (link to `#where-keys-come-from`), v1 integrators should leave Key management at None, a key minted with the scope is functionally equivalent to one without on the public surface.

Verify:

- `grep -n "keys:admin" docs/api/authentication.md` → ≥3 hits.
- `grep -n "Key management" docs/api/authentication.md` → ≥2 hits.
- `pnpm build` passes.

```bash
git add docs/api/authentication.md
git commit -m "docs(auth): add Key management → keys:admin scope row, mark reserved for v2 (TRA-617)"
```

### Task 4: Verify build

```bash
pnpm build
```

Must succeed with no broken-link warnings.

### Task 5: Push and open PR

```bash
git push -u origin miks2u/tra-617-bb19-w1-key-management-scope-docs
gh pr create --title "docs(auth): TRA-617 BB19 §W1 — Key management → keys:admin scope row" --body "..."
```

### Task 6: File follow-up Linear ticket

After PR is opened, create a Linear issue against TrakRF: "decide pre-launch: hide Key management SPA dropdown until v2, or promote /orgs/{org}/api_keys endpoints to public spec" — parented appropriately, linking back to this PR. Note the decision is a platform-side call; either resolution leaves the docs prose in §1 valid.

---

## Acceptance

- `pnpm build` passes.
- Authentication doc enumerates Key management → Admin / `keys:admin` in both scope tables.
- Reserved-for-v2 subsection explains the scope's v1 status truthfully.
- PR opened against `main`; adjacent-audit table in description.
- Follow-up Linear ticket filed and linked from PR.
