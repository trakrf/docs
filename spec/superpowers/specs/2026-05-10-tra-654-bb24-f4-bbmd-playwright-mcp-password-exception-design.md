---
ticket: TRA-654
title: BB24 F4 — BB.md Playwright MCP password-literal exception
status: design
date: 2026-05-10
---

# Goal

Add a single named exception to `tests/blackbox/BB.md`'s password-literal rule for the Playwright MCP-driven browser harness, so future BB cycles stop re-discovering the friction surfaced as F4 in the BB24 eval.

The acceptance bar (from [TRA-654](https://linear.app/trakrf/issue/TRA-654)): BB.md acknowledges the tooling tension, names the conditions under which the literal-password constraint can be relaxed, and explicitly forbids relaxing it in any other tool call. The rest of BB.md's password discipline stays intact.

No platform, spec, or other docs changes. Sibling tickets [TRA-652](https://linear.app/trakrf/issue/TRA-652) (BB24 docs sweep) and [TRA-653](https://linear.app/trakrf/issue/TRA-653) (BB24 spec polish) are out of scope.

# Pre-implementation audit — what's already in BB.md

`tests/blackbox/BB.md` has one line on the password constraint today (L43, inside the `## Environment` section):

> **Do not echo `API_TEST_PASS` or pass it as a literal in tool-call arguments.** Reference it through env var expansion or your language's env-reading APIs.

Nothing else in the file mentions tooling-level conflicts, the Playwright MCP harness, or the SPA-mint flow's incompatibility with literal-substitution rules. Net new content for this PR.

# In-scope changes

## `tests/blackbox/BB.md`

**New `## Tooling notes` top-level section.** Insert between the existing `## Environment` section (ends L43 with the "Do not echo" warning) and `## Mission` (L45). Sibling-level to Environment so the harness exception is discoverable as its own concept while sitting immediately adjacent to the password rule it qualifies.

Three paragraphs:

1. **Name the conflict.** BB.md's literal-password rule and the SPA mint flow are jointly unsatisfiable under a Playwright MCP-driven browser harness — the `browser_type` tool has no env-variable substitution. A real customer developer typing into a real browser doesn't hit this; it's a tooling artifact, not a TrakRF design issue. Mention that a loopback HTTP shim that reads the password server-side and injects via `<script src=...>` / `fetch(...)` is blocked by Chrome's Private Network Access policy from the public docs origin (so future cycles don't repeat the BB24 attempt).
2. **State the bounded exception.** Within the Playwright MCP environment, the literal-password constraint may be relaxed for a single `browser_type` call to the SPA mint/login form's password field. Conditions: the literal appears in exactly one tool call (the password field), is not echoed back into chat output, and is not written to disk (no scratch files, notes, FINDINGS.md, or screenshots that capture the field).
3. **Explicit forbiddance elsewhere.** The exception does not extend to any other tool call: curl, fetch, file writes, log statements, and any other surface where the literal could land remain forbidden. One named hole in the harness boundary, not a license to spread the literal through the run.

Wording is plain prose, no code fences. The section title matches the ticket's suggested "Tooling notes" label so future BB authors searching for the term find it.

# Out of scope

- Changing the `Do not echo` line on L43. The new section qualifies it; the line itself stays as the unconditional rule, with the Tooling notes section providing the single exception.
- Changing `## Allowed tools` (L8–L20). Playwright MCP is implicitly an automation harness; the allowlist is framed for the human-developer baseline and shouldn't be expanded to name harness tools.
- Changing the SPA-mint onboarding flow. Out of scope per the ticket — that flow is the right call for human developers.
- Updating `private-endpoints.md`, `quickstart.mdx`, or any public docs page. The exception is BB.md-internal and lives in the eval harness, not the customer-facing docs.

# Verification

After the edit:

- `pnpm typecheck` and `pnpm lint` (BB.md is not built, but run the standard pre-PR checks for hygiene).
- Re-read the section in context to confirm: (a) the conflict is named, (b) the exception conditions are explicit, (c) the boundary is unambiguous, (d) the rest of BB.md's password discipline reads as intact.

# Cadence

Two commits, single PR, no squash:

1. `docs(spec): TRA-654 — design for BB.md Playwright MCP password exception`
2. `docs(api): TRA-654 — BB24 F4 BB.md Playwright MCP password literal exception`

Branch: `miks2u/tra-654-bb24-f4-bbmd-playwright-mcp-password-exception`.
