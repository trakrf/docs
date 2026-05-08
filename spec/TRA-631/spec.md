# Feature: BB.md out-of-scope workflow observations + cross-reference guardrail

## Metadata

**Workspace**: docs (tests/blackbox/)
**Type**: docs

## Outcome

`tests/blackbox/BB.md` tells the BB tester (an AI subagent) which acknowledged-final-design states are out of scope and to cross-reference docs before claiming "X is never documented." Recurring noise findings (SPA-only key mint, Internal `/auth/login`, no API list/revoke) and false-negative gaps (e.g. BB20 F7 `tree_path` "never documented" while it lives in `resource-identifiers.md`) stop being raised as workflow gaps.

## User Story

As the BB orchestrator triaging cycle findings
I want BB.md to pre-disclose known design states and require docs cross-reference
So that BB21+ stops re-raising the same final-design constraints and stops false "undocumented" claims

## Context

**Discovery**: The same SPA-only-mint observation has been re-raised across BB18 §1.5 (TRA-606), BB19 W3 (TRA-612), BB20 W1 (TRA-622), with the AI-trip tag escalating each cycle (No → No → Yes/pre-launch). Each cycle costs triage time and signal noise. Separately, BB20 F7 wrote "tree_path is never documented" while `resource-identifiers.md` already documents it (PR #81 verification). Both correctable through BB.md framing, not tester error — the tool is doing what BB.md asks.

**Current**: BB.md L22 already says "don't reverse-engineer Internal endpoints," but does not enumerate the specific final-design constraints that should not be flagged at all (vs. flagged as friction). It does not require multi-page docs cross-reference before "X is never documented" claims.

**Desired**: Two new sections. (1) Out-of-scope workflow observations — enumerates SPA-only mint, Internal `/auth/login`, no session-only key list/revoke endpoints in API as final design state, not findings. (2) Cross-reference guardrail — before writing "X is never documented," search the docs site and read at least the first hit.

## Technical Requirements

- Add **Out-of-scope workflow observations** section to `tests/blackbox/BB.md`, placed after the "Allowed tools" / `if you find yourself blocked` paragraph (so it follows naturally from the SPA-onboarding framing already there).
- Add **Before flagging a docs gap** section near "Report findings" or as a callout there.
- Phrasing per ticket draft is acceptable; final phrasing can vary as long as the three out-of-scope items are explicitly named (SPA-only mint, Internal `/auth/login`, session-only key list/revoke) and the cross-reference rule names "search the docs site" + "read at least the first hit."
- Audit pass per the ticket's "Audit adjacent" list:
  - Rest of BB.md for framing that conflicts with new "out-of-scope" language (the existing "document the friction" line about UI blocks should remain coherent — friction-during-onboarding is still a finding, but the SPA-only mint as a *design choice* is not).
  - `docs/api/private-endpoints.md` — verify no "temporary state" framing on Internal endpoints (already permanent: "subject to change without notice"; classification policy says Public vs Internal, no transitional bucket).
  - `.envrc` / `.env.local` template comments referencing auth setup — verify no stale guidance.
  - The BLACKBOX.md template referenced in project memory — confirm whether it lives in this repo or is platform/superpowers; document audit outcome in PR.

## Validation Criteria

- [ ] BB.md contains a section enumerating the three out-of-scope items
- [ ] BB.md contains the cross-reference guardrail before "report findings"
- [ ] No conflicting "temporary state" framing on Internal endpoints in `private-endpoints.md`
- [ ] `pnpm build` passes (Docusaurus link + structure check)
- [ ] PR body documents audit outcomes for BB.md neighbors, `private-endpoints.md`, env templates, and BLACKBOX.md template (in-repo or external)

## Success Metrics

- [ ] Next cycle (BB21) does not raise "no programmatic mint" or `/auth/login` Internal as workflow gaps
- [ ] Next cycle does not produce "X is never documented" claims for terms documented elsewhere on the docs site
- [ ] No regression in BB.md's existing onboarding-friction signal — UI dead-ends still get reported

## References

- Ticket TRA-631
- BB18 §1.5 (TRA-606), BB19 W3 (TRA-612), BB20 W1 + F7 (TRA-622) — motivating findings
- PR #81 — confirms `tree_path` is documented in `resource-identifiers.md`
- `tests/blackbox/BB.md` — file under edit
- `docs/api/private-endpoints.md` — audit target
