---
ticket: TRA-775
date: 2026-05-18
---

# TRA-775 BB61 docs — tags PATCH echo set-equality changelog + errors.md worked example

Docs-side of the paired TRA-775 ticket. Platform PR (trakrf/platform#371) ships the behavior change — `tags` PATCH echo now compared as set-equality on full tag content via `httputil.SameTagSet`. This PR documents it.

## Scope

Two changes against `trakrf/docs`:

1. **F1 — changelog entry** on `docs/api/changelog.md` for the tags PATCH echo set-equality behavior change. Integrator-visible, strictly more permissive.
2. **F2 — worked example** on `docs/api/errors.md` in the `validation_error` vs `bad_request` section. Concrete `is_active: "true"` (bad_request) vs `name: ""` + `valid_from: ""` (validation_error) comparison, addressing a third-time-surfaced discoverability gap.

Also bundled (separate commit): the `just bb_cycle` recipe auto-launch change touched up earlier in this session — replaces the copy-paste session-start line with `direnv allow $target && cd $target && exec claude …`, plus `BB_NO_LAUNCH=1` test hook. Pure DX; orthogonal to the docs content but ships in the same PR because the user pre-staged it.

## F1 — changelog entry

New section at the top of the `## v1.0 — Launch (TBD)` block, above the BB58 section currently in pole position:

> ### BB61 fix wave — tags PATCH echo compared as set, concrete `validation_error` vs `bad_request` example

Single platform bullet on the tags echo, then a docs bullet on the errors example. Format mirrors the BB58 wave entry: bold lead sentence stating the behavior change, paragraph explaining the integrator surface, "Strictly more permissive" framing on the F1 item, cross-link to `[Errors → read_only](./errors#error-type-catalog)` and `[Resource identifiers → Tags](./resource-identifiers#tags-use-a-composite-natural-key)`.

The F2 bullet stays bundled in the same wave entry — it's the same triage cycle (BB61-3) and a docs change rather than a service change, but the changelog already pairs docs items with service items in the same wave entry (BB58 carries a service item plus a spec-emission item; BB57 carries three service items plus one docs-narrow item).

## F2 — errors.md worked example

Insertion point: immediately after the `:::warning Typed clients: don't iterate fields[] unconditionally` admonition at `errors.md:96-98`, before the existing prose paragraph at `:100` that starts "Type mismatches on body fields take this `bad_request` path…".

The existing section already shows JSON envelopes for `bad_request` (lines 102-113 field-level, 115-128 top-level). What's missing is a side-by-side worked example that lets a reader probing boolean coercion or value validation see their specific shape immediately. The BB61-3 author hit this with `is_active: "true"`, reproduced the exact example the BB52 paragraph already covered abstractly, and didn't bridge it — the docs need the bridge stated, not implied.

Block shape: a fenced "Example: comparing the two 400 envelopes" pair showing
- `POST /api/v1/assets` with `{"name": "x", "is_active": "true"}` → `400 bad_request` (decode failure, no `fields[]`)
- `POST /api/v1/assets` with `{"name": "", "valid_from": ""}` → `400 validation_error` (constraint failures with populated `fields[]`)

Close with a sentence reinforcing "branch on `error.type` before inspecting `fields[]`" — same point as the warning admonition, but reached via the concrete envelope shapes rather than the abstract typed-client framing. The two reach the same conclusion from different angles, which is the discoverability shape we want.

## Out of scope

- No edits to platform/spec — that's PR #371 (already merged into preview).
- No new pages, no nav changes, no restructuring of errors.md beyond the inserted block.
- No Linear ticket references in the prose (per repo convention).

## Verification

- `pnpm typecheck` and `pnpm build` clean — Docusaurus catches broken anchors and dead cross-links.
- Manual: render `/docs/api/errors` and `/docs/api/changelog` locally; confirm the new block lands in the right spot and the existing JSON examples below still flow.
- Preview deploy via Cloudflare Pages on merge; subsequent BB cycle against the deployed preview verifies integrator-visible behavior matches the changelog wording (orthogonal to this PR — platform PR #371 already shipped the behavior).

## Commits

1. `docs(api): TRA-775 BB61 F2 — concrete validation_error vs bad_request example in errors.md`
2. `docs(api): TRA-775 BB61 F1 — changelog entry for tags PATCH echo set-equality`
3. `chore(bb): just bb_cycle auto-launches the session — replaces copy-paste with exec claude`

Order matches reading order in the PR diff — content first, infrastructure last. The bb_cycle commit is split because it lives outside `docs/` and reviewers shouldn't have to scroll past it to read the docs change.
