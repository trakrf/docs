# TRA-573 BB14 Doc/Spec Corrections — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the W4 (per-resource read-only field count) and W5 (broken sort example, missing history sort doc, no codegen-validation callout) documentation findings from BB14.

**Architecture:** Two existing files edited in place. W4 rewrites one section in `docs/api/resource-identifiers.md` to express a generic "strip read-only fields" rule rather than a per-resource count. W5 makes three small edits to `docs/api/pagination-filtering-sorting.md` (fix the broken example, surface history endpoint sortability, add a codegen-vs-runtime sentence). W3 collapsed to no-op pre-design (pre-launch reseed handles the seed-data quirk). The W5 spec-side enum work shipped via platform PR #259 and is already on this branch via the spec refresh commit.

**Tech Stack:** Docusaurus markdown. Build/lint via `pnpm build` (typecheck + Redocly bundle + broken-link check).

**Spec:** `spec/superpowers/specs/2026-05-02-tra-573-bb14-doc-corrections-design.md`

**Branch:** `chore/tra-573-bb14-doc-corrections` (already created; spec refresh `f29f148` and design `9e5dff7`/`8f68f35` already committed).

---

## File Map

- Modify: `docs/api/resource-identifiers.md` (lines 87–132 — entire "Read shape vs. write shape" section)
- Modify: `docs/api/pagination-filtering-sorting.md` (line 148, line 151, lines 188–191)

No new files. No test files (docs-only PR — verification is `pnpm build` + visual review of rendered output).

---

## Task 1: W4 — Rewrite "Read shape vs. write shape" as a generic rule

**Files:**
- Modify: `docs/api/resource-identifiers.md:87-132`

**Goal:** Replace the asset-specific "four read-only fields" framing with a generic "strip any field present in GET but not in the request schema" rule, with the asset list framed as illustration.

- [ ] **Step 1: Read the current section to capture exact context for the Edit**

Run: `Read docs/api/resource-identifiers.md offset=87 limit=50`

Confirm the section spans lines 87–132 and the surrounding lines (86: blank line above heading, 133: blank, 134: next `## Locations: parent_id...` heading) match what you see.

- [ ] **Step 2: Replace lines 87–132 with the rewritten section**

Use Edit with `old_string` containing lines 87–132 verbatim (the heading `## Read shape vs. write shape` through the trailing `...not accepted on write).` paragraph and the blank line after). Use `new_string`:

````markdown
## Read shape vs. write shape

Request and response field _names_ match (e.g., `current_location_external_key` reads and writes under the same name), so the natural-key parts of a `PUT` round-trip without remapping. Read shape and write shape are not identical, though: read responses include fields the server rejects on write — server-managed metadata (`id`, `created_at`, `updated_at`), derived fields (`path`, `depth` on locations), and embedded sub-resources (`tags`). The exact set varies by resource.

The general rule: **any field present in the GET response but not in the request schema is read-only and must be stripped before `PUT`.** A naive `GET` → mutate → `PUT` of the entire response object returns:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Invalid request",
    "status": 400,
    "detail": "unknown field 'id' in request body",
    "instance": "/api/v1/assets/4287",
    "request_id": "01J...",
    "fields": [
      {
        "field": "id",
        "code": "invalid_value",
        "message": "unknown field"
      }
    ]
  }
}
```

A naive PUT of every read-only field produces one `fields[]` entry per offending key — see [Errors → Validation errors](./errors#validation-errors) for the complete envelope shape.

For assets the read-only set today is `id`, `created_at`, `updated_at`, and `tags`. The minimal pattern with `jq`:

```bash
# Move an asset to a new location by its external_key
curl -sH "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287" \
| jq '.data | del(.id, .created_at, .updated_at, .tags)
       | .current_location_external_key = "PORTABLE-1437"' \
| curl -X PUT \
       -H "Authorization: Bearer $TRAKRF_API_KEY" \
       -H "Content-Type: application/json" \
       -d @- \
       "$BASE_URL/api/v1/assets/4287"
```

Locations have a larger read-only set (notably the derived `path` and `depth` in addition to the metadata fields), and future resources may have their own. Don't memorize per-resource lists — derive the strip set from the schema diff between the response object and the request body shape. In a generated TypeScript client with strict typing, the read response type and the write request type are distinct, so the compiler enforces the strip — there's no manual deletion to do. In a generated Python or Go client without strict input types, you'll need to pop the read-only fields explicitly before sending, or wrap the API in a typed model that excludes them at the call site.

Either form of the FK pair is accepted on write. Send `current_location_id` if you have it; send `current_location_external_key` if that's what the user typed. Don't send both for the same relationship in one request — the server validates them as mutually exclusive.

````

The new section: opens with the generic rule + a hint that "the exact set varies by resource"; keeps the unchanged 400-error JSON; reframes the `jq` example as an asset-specific illustration; explicitly mentions locations have a larger set without enumerating per-resource counts; keeps the codegen guidance and FK-pair paragraph; drops the trailing "same four-field strip applies to locations" paragraph (was line 132).

- [ ] **Step 3: Verify the edit landed cleanly**

Run: `Read docs/api/resource-identifiers.md offset=85 limit=55`

Confirm:
- `## Read shape vs. write shape` heading still present
- New opening paragraph reads "...read responses include fields the server rejects on write — server-managed metadata..."
- The bolded generic rule sentence is present
- The "for assets the read-only set today is..." sentence appears once
- The trailing "same four-field strip applies to `PUT /api/v1/locations/{id}`" sentence is **gone**
- The `## Locations: parent_id and parent_external_key` heading immediately follows the new section's last line + one blank line

- [ ] **Step 4: Commit**

```bash
git add docs/api/resource-identifiers.md
git commit -m "$(cat <<'EOF'
docs(resource-identifiers): rewrite read/write shape as generic rule (W4)

The previous wording said "strip the four read-only fields" with an
asset-specific list, then tucked a six-field carve-out for locations
at the end. Integrators following the rule blindly for locations
got it wrong on count.

Replaces the per-resource enumeration with a generic statement —
"any field present in the GET response but not in the request schema
is read-only" — and reframes the jq example as an illustration
specific to assets. Locations are mentioned as having a larger set
without enumerating it; the schema is the single source of truth.

Refs TRA-573.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: W5 fix #1 — Replace the broken `?sort=-is_active,external_key` example

**Files:**
- Modify: `docs/api/pagination-filtering-sorting.md:144-149`

**Goal:** The "Active status descending, then external_key ascending" example uses `is_active` as a sort key, which is not in any sort enum and 400s at runtime. Replace with a valid composite-sort example.

- [ ] **Step 1: Replace the broken example**

Use Edit on `docs/api/pagination-filtering-sorting.md`:

`old_string`:
```
# Active status descending, then external_key ascending
?sort=-is_active,external_key
```

`new_string`:
```
# Newest first, then external_key as tiebreaker
?sort=-created_at,external_key
```

Why this replacement: `created_at` is in the assets sort enum (verified: `external_key`, `name`, `created_at`, `updated_at`); `external_key` is also in the enum and works as a stable tiebreaker. Drops `is_active` — it's a filter, not a sort key.

- [ ] **Step 2: Verify**

Run: `Read docs/api/pagination-filtering-sorting.md offset=140 limit=15`

Confirm the example block now reads `?sort=-created_at,external_key` and the comment matches.

- [ ] **Step 3: Commit**

```bash
git add docs/api/pagination-filtering-sorting.md
git commit -m "$(cat <<'EOF'
docs(pagination): replace broken sort example with valid fields (W5)

The composite-sort example used is_active, which is a filter not a
sort key and 400s at runtime against the live service (no endpoint's
sort enum includes is_active). Replaces with -created_at,external_key
— both in the assets sort enum, both useful as a real composite sort.

Refs TRA-573.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: W5 fix #2 — Surface `assets/{id}/history` sortability in the worked example

**Files:**
- Modify: `docs/api/pagination-filtering-sorting.md:184-191`

**Goal:** The history endpoint accepts `sort=timestamp` / `-timestamp` (declared in the spec post-PR-#259) but the worked example doesn't demonstrate it. Add `&sort=-timestamp` to make the sortability visible.

- [ ] **Step 1: Update the History worked example**

Use Edit on `docs/api/pagination-filtering-sorting.md`:

`old_string`:
```
### History

Asset movement history over a window (path takes the canonical integer asset `id`):

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287/history?from=2026-04-01T00:00:00Z&to=2026-04-30T23:59:59Z&limit=200"
```
```

`new_string`:
```
### History

Asset movement history over a window, newest event first (path takes the canonical integer asset `id`):

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/4287/history?from=2026-04-01T00:00:00Z&to=2026-04-30T23:59:59Z&sort=-timestamp&limit=200"
```
```

Two changes: prose intro adds "newest event first"; URL adds `&sort=-timestamp`. Sort key is `timestamp` — confirmed against the post-refresh spec enum for `GET /api/v1/assets/{id}/history`.

- [ ] **Step 2: Verify**

Run: `Read docs/api/pagination-filtering-sorting.md offset=183 limit=10`

Confirm the curl line includes `&sort=-timestamp` and the prose intro mentions "newest event first".

- [ ] **Step 3: Commit**

```bash
git add docs/api/pagination-filtering-sorting.md
git commit -m "$(cat <<'EOF'
docs(pagination): demonstrate sort=-timestamp on history worked example (W5)

The history endpoint accepts sort=timestamp / -timestamp at runtime
and now declares the enum in the spec (per platform PR #259). The
worked example didn't demonstrate it, leaving the sortability
discoverable only via the interactive reference. Adds -timestamp
to the example URL and updates the prose intro to match.

Refs TRA-573.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: W5 fix #3 — Add codegen-validation callout to the Sorting section

**Files:**
- Modify: `docs/api/pagination-filtering-sorting.md:151`

**Goal:** Tell integrators the runtime 400 is now a fallback, not the only signal — strict-typed codegen will catch unknown sort fields at compile time.

- [ ] **Step 1: Append the callout sentence**

Use Edit on `docs/api/pagination-filtering-sorting.md`:

`old_string`:
```
Sortable fields vary per resource; the interactive reference at [`/api`](/api) lists the exact set each endpoint accepts. Unknown sort fields return `400 validation_error`. When no `sort` is supplied, results default to the resource's natural ordering (typically `external_key` ascending).
```

`new_string`:
```
Sortable fields vary per resource; the interactive reference at [`/api`](/api) lists the exact set each endpoint accepts. Unknown sort fields return `400 validation_error`. Generated clients with strict typing reject unknown sort fields at compile time; weaker generators receive the 400 from the server. When no `sort` is supplied, results default to the resource's natural ordering (typically `external_key` ascending).
```

One sentence inserted between the existing 400-validation sentence and the default-ordering sentence. Mirrors the W4 generic-rule guidance (compile-time vs. runtime feedback) for the sort param.

- [ ] **Step 2: Verify**

Run: `Read docs/api/pagination-filtering-sorting.md offset=150 limit=4`

Confirm the new sentence "Generated clients with strict typing..." sits between the `400 validation_error` mention and the "When no `sort` is supplied" sentence.

- [ ] **Step 3: Commit**

```bash
git add docs/api/pagination-filtering-sorting.md
git commit -m "$(cat <<'EOF'
docs(pagination): note codegen catches unknown sort fields at build time (W5)

Now that the public spec declares sort enums per endpoint
(platform PR #259), strict-typed codegen (e.g. openapi-typescript)
will reject unknown sort fields at compile time. The runtime 400
is now a fallback for weaker generators, not the only signal.

Refs TRA-573.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Build verification

**Files:** none modified — this is a verification gate.

**Goal:** Confirm `pnpm build` passes (typecheck + Docusaurus build + Redocly bundle + broken-link check) before opening the PR.

- [ ] **Step 1: Run the build**

Run: `pnpm build`

Expected: build completes without errors. Specifically watch for:
- No broken-link warnings on the modified files
- No Redocly errors processing `static/api/openapi.json` (should be clean — refresh already validated)
- No markdown-lint or MDX parse failures

- [ ] **Step 2: If any failure, diagnose and fix**

If build fails:
- Markdown parse error → re-read the modified file around the failure line, look for stray backticks or unmatched code fences from the Edits
- Broken link → `pnpm dlx` `serve build` and verify the destination still exists (we didn't touch link targets, so this would be a pre-existing issue, not introduced by this PR — but flag it)

If you fix anything, add a fixup commit:
```bash
git add docs/api/<file>
git commit -m "fix(docs): <what>"
```

- [ ] **Step 3: If build passes, no commit needed**

Move on to PR creation.

---

## Task 6: Open PR

**Files:** none modified.

**Goal:** Push the branch and open a PR referencing TRA-573 with the verification checklist filled in.

- [ ] **Step 1: Push the branch**

Run:
```bash
git push -u origin chore/tra-573-bb14-doc-corrections
```

- [ ] **Step 2: Open the PR**

Run:
```bash
gh pr create --title "docs(api): TRA-573 BB14 doc corrections (W4 generic rule, W5 sort fixes)" --body "$(cat <<'EOF'
## Summary

Fixes BB14 findings W4 and W5 in the docs. W3 collapsed to no-op pre-design (pre-launch reseed handles the seed-data quirk; design spec captures the rationale).

- **W4** — `docs/api/resource-identifiers.md`: rewrite "Read shape vs. write shape" as a generic "strip any field present in GET but not in the request schema" rule. Drops the asset-specific "four fields" framing and the trailing six-fields-for-locations carve-out. Asset list reframed as illustration of the rule, not the rule itself.
- **W5** — `docs/api/pagination-filtering-sorting.md`: three small fixes.
  - Replace the broken `?sort=-is_active,external_key` example with `?sort=-created_at,external_key` (`is_active` is a filter, not a sort key — 400s at runtime).
  - Add `&sort=-timestamp` to the History worked example (the endpoint always supported it; the spec now declares it post-platform-PR #259).
  - Append a sentence noting that strict-typed codegen will reject unknown sort fields at compile time, mirroring the W4 generic-rule guidance.

The W5 spec-side enum work shipped separately via [trakrf/platform#259](https://github.com/trakrf/platform/pull/259) (`da6f832`) and is already on this branch via the spec refresh commit (`f29f148`).

Refs [TRA-573](https://linear.app/trakrf/issue/TRA-573). Parent: [TRA-566](https://linear.app/trakrf/issue/TRA-566).

## Test plan

- [x] `pnpm build` passes locally
- [x] `static/api/platform-meta.json` carries `platform@da6f832` (sort enums present)
- [ ] Reviewer skim of rendered `resource-identifiers.md` — Read shape vs. write shape section reads cleanly as a generic rule
- [ ] Reviewer skim of rendered `pagination-filtering-sorting.md` — the three W5 changes are visible

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Capture the PR URL**

The `gh pr create` command prints the PR URL on success. Note it for the user.

---

## Self-review checklist (for the plan author, not the executor)

- [x] Spec coverage: W3 (no-op, documented), W4 (Task 1), W5 fix-1 broken example (Task 2), W5 fix-2 history sort (Task 3), W5 fix-3 codegen callout (Task 4), build verification (Task 5), PR (Task 6) — all spec acceptance criteria mapped.
- [x] No placeholders — every Edit has full `old_string` / `new_string` content; every commit has a complete message.
- [x] Type/identifier consistency — sort fields named consistently (`created_at`, `external_key`, `timestamp`); file paths consistent throughout.
- [x] No "TBD" / "similar to" / "add appropriate" language.
