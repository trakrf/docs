# TRA-892 Docs-Hygiene Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land four BB-fleet doc-hygiene corrections (3 wording one-liners + remove one stale backlog row) and groom the `contact.url` deferral in Linear.

**Architecture:** Docs-only edits in `trakrf/docs`. No spec/platform change — `info.contact.url` is already correct live. Verification is `pnpm build` + `pnpm lint` (no test suite for prose) plus targeted greps confirming each before/after.

**Tech Stack:** Docusaurus / Redocusaurus, pnpm, Markdown/MDX. Linear MCP for the grooming comment.

---

## File Structure

- Modify: `tests/blackbox/BB_PRE_KEY.md` — fixture-data wording (item 1)
- Modify: `docs/api/quickstart.mdx` — minimal-PATCH comment (item 2)
- Modify: `tests/blackbox/BB.md` — context-block version check (item 3)
- Modify: `tests/blackbox/BACKLOG.md` — remove obsolete deferral row (item 4a)
- Linear: comment on TRA-743 (item 4b)

---

### Task 1: `BB_PRE_KEY.md` — location is a scan projection, not an asset field

**Files:**

- Modify: `tests/blackbox/BB_PRE_KEY.md:47` and `:49`

- [ ] **Step 1: Edit line 47.** Replace:

```
- Every asset has `location_id` resolved from scan history — no asset on this fixture reads as `location_id: null`.
```

with:

```
- Every asset has a resolvable current location, but location is **not** a field on the asset object — it is resolved from scan history via the asset-locations report (`GET /api/v1/reports/asset-locations`) and per-asset history (`GET /api/v1/assets/{asset_id}/history`), both gated `tracking:read`. No fixture asset reads as location-unknown.
```

- [ ] **Step 2: Reconcile line 49** so it does not re-imply a field on the asset. Replace:

```
**Scans:** populated. Each org carries ~25 `asset_scans` per asset over a 90-day window (~675 per org), and the materialized `location_id` on every asset reflects the most-recent scan.
```

with:

```
**Scans:** populated. Each org carries ~25 `asset_scans` per asset over a 90-day window (~675 per org), and the current location reported for every asset (via the scan-data endpoints above) reflects its most-recent scan.
```

(Leave the rest of line 49 — the `tracking:read` sentence — unchanged.)

- [ ] **Step 3: Verify.** Run: `grep -n "location_id\` resolved\|materialized \`location_id\`" tests/blackbox/BB_PRE_KEY.md`
      Expected: no matches (both imprecise phrasings gone).

---

### Task 2: `quickstart.mdx` — `{}` no-op qualifier

**Files:**

- Modify: `docs/api/quickstart.mdx:146`

- [ ] **Step 1: Edit line 146.** Replace:

```
# nullable field; `{}` is a documented no-op.
```

with:

```
# nullable field; `{}` is a documented no-op against settable fields (it still advances `updated_at`).
```

- [ ] **Step 2: Verify.** Run: `grep -n "documented no-op" docs/api/quickstart.mdx`
      Expected: the line now contains "against settable fields (it still advances `updated_at`)".

---

### Task 3: `BB.md` — point version check at the app origin

**Files:**

- Modify: `tests/blackbox/BB.md:209`

- [ ] **Step 1: Edit line 209.** Replace:

```
- Spec/build version — fetch `$API_TEST_DOCS_URL/health.json` and record what it returns. If `/health.json` 404s, that's a finding; record what you did get.
```

with:

```
- Spec/build version — fetch `$API_TEST_APP_URL/health.json` (the app origin carries `version` + `spec_refreshed_at`; the docs origin's `/health.json` carries only the docs build stamp). Record what it returns. If `/health.json` 404s, that's a finding; record what you did get.
```

- [ ] **Step 2: Verify.** Run: `grep -n "Spec/build version" tests/blackbox/BB.md`
      Expected: line now references `$API_TEST_APP_URL/health.json`.

---

### Task 4: `BACKLOG.md` — remove the obsolete `contact.url` deferral row

**Files:**

- Modify: `tests/blackbox/BACKLOG.md:47`

- [ ] **Step 1: Delete the entire table row** beginning `| Restore \`info.contact.url\` on OpenAPI spec` (line 47). Remove the whole line; leave the table header (41-42) and the three preceding rows (43-46) intact.

- [ ] **Step 2: Verify.** Run: `grep -n "info.contact.url" tests/blackbox/BACKLOG.md`
      Expected: no matches. Run: `grep -c "^| " tests/blackbox/BACKLOG.md` and confirm the deferred-work table dropped by exactly one row.

---

### Task 5: Build + lint

- [ ] **Step 1:** Run: `pnpm build` Expected: success (no spec change; Redocusaurus fetches live spec).
- [ ] **Step 2:** Run: `pnpm lint` Expected: pass.

---

### Task 6: Commit + groom Linear

- [ ] **Step 1: Commit** the four file edits:

```bash
git add tests/blackbox/BB_PRE_KEY.md docs/api/quickstart.mdx tests/blackbox/BB.md tests/blackbox/BACKLOG.md
git commit -m "docs(api): TRA-892 BB-fleet hygiene — location-projection wording, PATCH no-op qualifier, BB version-check origin, retire contact.url deferral"
```

- [ ] **Step 2: Groom TRA-743 (already Done).** Add a Linear comment recording that `info.contact.url` was restored by design (TRA-882, Stripe pattern `https://trakrf.id`), so the `BACKLOG.md` "restore when a helpdesk lands" deferral has been removed as obsolete. No state change.

---

### Task 7: Push + PR (hold for approval before merge)

- [ ] **Step 1:** Push branch `docs/tra-892-docs-bundle`.
- [ ] **Step 2:** Open PR with the spec/plan link and the four-item summary. **Do not merge** — hold for user approval.
