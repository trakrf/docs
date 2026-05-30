# TRA-891 — API Identity Join Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the published advice that integrators should use the surrogate `id` as their durable foreign key; reframe `id` as an internal reconciliation anchor, add natural-key join guidance, and demote `id` on the versioning page.

**Architecture:** Docs-only prose edits across three Docusaurus Markdown pages plus the changelog. No code, no OpenAPI/platform edits (verified: the wrong advice lives only in docs prose; `external_key` is confirmed present+required on both `AssetView` and `LocationView`; `customer_identifier`/`slug`/public users resources do not exist on the API). "Tests" for a docs change are `pnpm build`, `pnpm lint`, internal-link resolution, and a manual read-through.

**Tech Stack:** Docusaurus 3, Markdown/MDX, Redocusaurus (fetches the live OpenAPI spec at build), pnpm.

---

## File Structure

- `docs/api/resource-identifiers.md` — fix the wrong `id`-as-FK sentence; add a "Joining your system of record" subsection. (Primary edit site.)
- `docs/api/changelog.md` — reword the TRA-885 changelog entry to drop the FK prescription.
- `docs/api/versioning.md` — add an `id`-demotion note under the stability commitment.

All three are existing prose pages; no new files, no restructure.

---

### Task 1: Remove the actively-wrong `id`-as-foreign-key sentence (launch-relevant, do first)

**Files:**
- Modify: `docs/api/resource-identifiers.md` (the "Numeric `id` is a surrogate key" section, ~line 58)

- [ ] **Step 1: Locate the exact current sentence**

Run: `grep -n "Use \`id\` as your durable foreign key when you mirror TrakRF data." docs/api/resource-identifiers.md`
Expected: one match at the end of the surrogate-key paragraph.

- [ ] **Step 2: Replace the final sentence of that paragraph**

Find this trailing sentence (keep everything before it unchanged):

```
client code matches ids to their entity type as standard surrogate-key discipline. Use `id` as your durable foreign key when you mirror TrakRF data.
```

Replace with:

```
client code matches ids to their entity type as standard surrogate-key discipline. `id` is a stable internal anchor — server-assigned, opaque, and not arbitrarily rekeyed — which makes it useful as a sync/reconciliation handle when you mirror TrakRF data. It is **not** your business foreign key: key your own system of record on the natural key (`external_key`) where one exists, and reach for `id` only as the durable handle when no natural key is available. See [Joining your system of record](#joining-your-system-of-record) for the per-resource rule.
```

- [ ] **Step 3: Verify the wrong advice is gone**

Run: `grep -rn "durable foreign key" docs/api/resource-identifiers.md`
Expected: no match (the phrase is removed from this file).

- [ ] **Step 4: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(api): stop advising id as the durable foreign key (TRA-891)"
```

---

### Task 2: Add the "Joining your system of record" subsection

**Files:**
- Modify: `docs/api/resource-identifiers.md` (insert between the end of the "Numeric `id` is a surrogate key" section and the "## Natural-key lookup uses `?external_key=`" heading, ~line 61)

- [ ] **Step 1: Find the insertion point**

Run: `grep -n "## Natural-key lookup uses" docs/api/resource-identifiers.md`
Expected: one match (`## Natural-key lookup uses \`?external_key=\``). Insert the new subsection immediately *before* this heading, after the blank line that follows the int64 paragraph (the paragraph ending "…typed-client codegen.").

- [ ] **Step 2: Insert the subsection**

Insert (note: `###` keeps it under the `## Path-param lookup uses \`id\`` section, beside "Numeric `id` is a surrogate key"):

```markdown
### Joining your system of record {#joining-your-system-of-record}

When you mirror TrakRF data into your own system, join on the **natural key**, not the surrogate `id`:

- **Assets and locations** — join on `external_key`, your own handle (a SKU, an asset tag, an ERP code, a facility code). It is the value your warehouse software, ERP, or operator already recognizes, and it round-trips on every response.
- **General rule** — join on a stable natural key where one exists; where none does, `id` is the durable handle. Use `id` as a reconciliation anchor in that case, not as a business key you export into other systems.

The public integration surface is assets, locations, and tags. Users and organization administration are not public joinable resources in v1 — an integration authenticates as a single organization through its API key (see [`/orgs/me`](./private-endpoints#orgs-me)), so there is no cross-org or cross-user join to maintain.
```

- [ ] **Step 3: Verify the anchor target exists for the Task 1 cross-link**

Run: `grep -n "joining-your-system-of-record" docs/api/resource-identifiers.md`
Expected: two matches — the `#joining-your-system-of-record` link from Task 1 and the `{#joining-your-system-of-record}` heading anchor here.

- [ ] **Step 4: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "docs(api): add per-resource natural-key join guidance (TRA-891)"
```

---

### Task 3: Reword the TRA-885 changelog entry

**Files:**
- Modify: `docs/api/changelog.md` (~line 18, the globally-unique-id bullet)

- [ ] **Step 1: Locate the FK prescription in the changelog**

Run: `grep -n "use it as your durable foreign key" docs/api/changelog.md`
Expected: one match within the "surrogate `id` is globally unique" bullet.

- [ ] **Step 2: Replace the trailing clause**

Find:

```
That cross-type collision is eliminated: ids are now minted from one shared sequence, so global uniqueness holds by construction. Treat `id` as opaque (don't parse it, order by it, or infer a count or creation time) and use it as your durable foreign key. See [ID format](./id-format)
```

Replace with:

```
That cross-type collision is eliminated: ids are now minted from one shared sequence, so global uniqueness holds by construction. Treat `id` as opaque (don't parse it, order by it, or infer a count or creation time) — it is a stable internal anchor for reconciliation, not your business foreign key; join your own systems on the natural key (`external_key`). See [ID format](./id-format)
```

- [ ] **Step 3: Verify no FK prescription remains**

Run: `grep -rn "durable foreign key" docs/api/`
Expected: no matches anywhere under `docs/api/`.

- [ ] **Step 4: Commit**

```bash
git add docs/api/changelog.md
git commit -m "docs(changelog): drop id-as-foreign-key advice from TRA-885 entry (TRA-891)"
```

---

### Task 4: Demote `id` on the versioning page

**Files:**
- Modify: `docs/api/versioning.md` (insert after the "## Stability commitment (v1)" section, before "## Open vs closed enums")

- [ ] **Step 1: Find the insertion point**

Run: `grep -n "^## Open vs closed enums" docs/api/versioning.md`
Expected: one match. Insert the new subsection immediately before this heading (after the "Clients written against v1 will continue to work… so don't." paragraph).

- [ ] **Step 2: Insert the demotion note**

```markdown
### The surrogate `id` is an internal anchor, not your join key

The `id` field is stable and won't be arbitrarily rekeyed, which makes it a usable sync / reconciliation anchor. It is **not** the integrator's business foreign key — don't key your own system of record on it. Join on the natural key (`external_key`) where one exists; see [Resource identifiers → Joining your system of record](./resource-identifiers#joining-your-system-of-record). The field-stability commitment above (names and types of returned fields don't change without a major version) is the contract that applies to `id`; TrakRF does not publish a permanence guarantee beyond it, because treating `id` as a durable external business key re-introduces the coupling the natural-key model is designed to avoid.
```

- [ ] **Step 3: Verify the cross-link target matches Task 2's anchor**

Run: `grep -n "resource-identifiers#joining-your-system-of-record" docs/api/versioning.md`
Expected: one match — the slug must equal the `{#joining-your-system-of-record}` anchor created in Task 2.

- [ ] **Step 4: Commit**

```bash
git add docs/api/versioning.md
git commit -m "docs(api): demote surrogate id on versioning page (TRA-891)"
```

---

### Task 5: Validate the build and links, then finalize

**Files:** none (verification only)

- [ ] **Step 1: Lint**

Run: `pnpm lint`
Expected: passes (no new errors). If Prettier reports formatting on the edited files, run `pnpm format` (or the repo's documented formatter) and amend the relevant commit.

- [ ] **Step 2: Typecheck**

Run: `pnpm typecheck`
Expected: passes.

- [ ] **Step 3: Production build (catches broken internal links / anchors)**

Run: `pnpm build`
Expected: build succeeds. Docusaurus fails the build on broken Markdown links, so a clean build confirms the `#joining-your-system-of-record` cross-links (Task 1, Task 4) and the `./private-endpoints#orgs-me` link resolve.

- [ ] **Step 4: Read-through verification**

Run: `grep -rn "durable foreign key\|as your.*foreign key\|use \`id\` as your" docs/api/`
Expected: no matches. Manually confirm: resource-identifiers.md reframe reads coherently; the new subsection states the assets/locations→`external_key` rule and the general rule; versioning.md note demotes `id` without adding a permanence guarantee.

- [ ] **Step 5: No further commit needed** unless Step 1 required a formatting fix; the four content commits from Tasks 1–4 stand.

---

## Self-Review

**Spec coverage:**
- "Remove `id`-as-FK advice (do first)" → Task 1 ✓
- Per-entity join guidance (assets/locations on `external_key`; general rule) → Task 2 ✓
- Reframe `id` (stable anchor, not business FK) → Task 1 + Task 2 + Task 4 ✓
- Versioning page: breaking-change policy (already present) + demote `id`, no absolute permanence guarantee → Task 4 ✓
- Delta sync → not advertised; nothing to add (per spec verification) — intentionally no task ✓
- Users/orgs join guidance → intentionally omitted (not public joinable resources); the omission is captured by Task 2's "not public joinable resources in v1" note ✓
- Edit-site/PR shape: docs-only, no platform edit → reflected in plan (no OpenAPI tasks) ✓

**Placeholder scan:** No TBD/TODO; every edit shows exact before/after prose. ✓

**Type/anchor consistency:** The anchor slug `joining-your-system-of-record` is defined in Task 2 and referenced identically in Task 1 and Task 4. The `./private-endpoints#orgs-me` anchor matches the existing `{#orgs-me}` in private-endpoints.md. ✓
