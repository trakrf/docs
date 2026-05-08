# Plan: TRA-631 — BB.md out-of-scope + cross-reference guardrail

## Files touched

- `tests/blackbox/BB.md` — two new sections.
- (No other files expected — audit findings logged in PR body.)

## Edit 1 — Out-of-scope workflow observations

**Where**: After the paragraph at L22 (the "If you find yourself blocked by a UI step during onboarding…" paragraph). This sits between the **Allowed tools** block and the **Environment** heading. Placing it here means the tester reads "what's allowed" → "what's not in scope to flag at all" → "what env you have" before the Mission section.

**Header level**: `##` (matches Environment, Mission, etc.).

**Content** (final phrasing — closely follows the ticket draft, normalized to BB.md voice):

```markdown
## Out-of-scope workflow observations

The following are acknowledged design state, not workflow gaps. Do not flag as findings:

- **No programmatic API key mint.** Key issuance is bound to user identity through the SPA, by design. The SPA mint flow is the supported onboarding path for both human and automated/headless callers — automated callers mint a key out-of-band and store it in their secrets infrastructure (this matches how Stripe API keys work). A programmatic seam is YAGNI for v1; the team will revisit if a customer surfaces real demand.
- **`/auth/login` is Internal.** Listed in `private-endpoints.md` as Internal / subject to change without notice. Do not investigate, integrate against, or report on it. Treat as out-of-scope even though it appears in the docs.
- **No session-only key list/revoke endpoints in the API.** Listing and revocation are SPA-side affordances only. Documented as session-only, not exposed to the API surface.

Document the existence of these constraints in your environment summary if relevant for context, but they should not appear in the findings sections.
```

**Coherence with L22 paragraph**: The L22 line already tells the tester not to reverse-engineer Internal endpoints and to "document the friction but don't try to circumvent it." That stays — UI friction during onboarding (e.g., a broken signup page, an unclear API-keys screen) is still a valid finding. What the new section disowns is treating the _existence_ of an SPA-only mint flow, or the _existence_ of `/auth/login` as Internal, as workflow gaps.

## Edit 2 — Cross-reference guardrail

**Where**: Inside the **Report findings** section (currently L72), as a short subsection or blockquote ahead of the existing "Write up findings to FINDINGS.md…" sentence. Putting it inside Report findings means the tester encounters it at the moment they're about to formalize claims.

**Header level**: `###` (sits under `## Report findings`, alongside `### Context block` and `### Terminology coherence pass`).

**Content**:

```markdown
### Before flagging a docs gap

If you're about to write "X is never documented," search the docs site for X first and read at least the first hit. The docs span multiple pages — absence in `quickstart.mdx` doesn't mean absence in `resource-identifiers.md` or elsewhere. The motivating example: a recent cycle reported `tree_path` as undocumented while `resource-identifiers.md` carries the canonical definition.
```

The motivating-example sentence cites the BB20 F7 case so future testers see _why_ the rule exists.

## Audit findings (will be reported in PR body, not edited here)

| Target                                      | Outcome                                                                                                                                                                                            |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rest of BB.md                               | L22 onboarding-friction paragraph remains coherent with new section. No conflicts.                                                                                                                 |
| `docs/api/private-endpoints.md`             | Already frames Internal endpoints as permanent (lines 7-11, 53-60: "subject to change without notice"; classification policy is Public vs Internal with no transitional bucket). No change needed. |
| `tests/blackbox/.envrc` + `.env.local`      | Minimal — only env-var loading and four credentials. No auth-setup guidance to align. No change needed.                                                                                            |
| Top-level `.envrc` + `.env.example`         | Loads `.env.local`; vars are deploy URL + docs-tour user creds. No tester-facing auth guidance to align. No change needed.                                                                         |
| BLACKBOX.md template (referenced in memory) | Not present in this repo (`find` returns no match). Lives in superpowers/platform infrastructure. Out of scope for trakrf/docs PR — flag in PR body for follow-up if a copy needs alignment there. |

## Verification

- `pnpm build` — confirm Docusaurus build still succeeds (BB.md is in `tests/blackbox/`, outside the docs site root, so no link-graph effect, but build is the standard go/no-go gate).
- `pnpm lint` — Markdown/Prettier formatting on the touched file.
- Visual diff of BB.md to confirm:
  - New `## Out-of-scope workflow observations` lands between allowed-tools paragraph and `## Environment`.
  - New `### Before flagging a docs gap` lands inside `## Report findings`, before the existing FINDINGS.md sentence.

## Out of scope (per ticket)

- API behavior changes (programmatic mint, key list/revoke).
- Renaming or relocating Internal endpoints.
- Customer-facing auth docs.
