# TRA-618 + TRA-626 + TRA-630 — BB19/BB20 docs polish drop

## Status

Pre-launch. Coordinated polish drop. Platform-side spec changes already
shipped via [trakrf/platform PR
#277](https://github.com/trakrf/platform/pull/277) (TRA-618 §S3+§S4,
TRA-626 §S1+§S2, TRA-630 §S5). This spec covers the docs-side leftovers.

Tickets:

- [TRA-618](https://linear.app/trakrf/issue/TRA-618) — BB19 v1.0.1 polish
  (W2/W3/W4/W5/C3/C5 docs items remain)
- [TRA-626](https://linear.app/trakrf/issue/TRA-626) — BB20 §S1+§S2 query
  parameter spec fixes (docs already correct per platform PR #277 comment;
  spec refresh + verification only)
- [TRA-630](https://linear.app/trakrf/issue/TRA-630) — BB20 polish (§C3
  metadata asymmetry, §C5 org/organization). §F3 is a platform-only fix
  and out of scope here.

## Goal

One docs PR that closes the docs-side items across the three tickets:

- Refresh the published OpenAPI spec mirror to pick up platform PR #277.
- Align UI label drift (Read+Write → Read + Write) with the SPA.
- Document session-only key affordances (list/revoke/expiration metadata).
- Strengthen the "Never expiration" caveat with the codegen no-`exp`
  implication.
- Customer-voice rewrite of the cross-type integer-`id` collision
  paragraph (drops the BB-cycle citation and the surrogate-key reframe
  noted in BB20 §C1).
- Document the intentional asymmetry that assets carry `metadata` and
  locations do not.
- Sweep customer-facing prose `org` → `organization` across `docs/api/`,
  `docs/user-guide/`, `docs/integrations/`, and `docs/getting-started/`.
  Keep technical surfaces (`org_id`, `missing_org_context`,
  `org.OrgMeView`, `/api/v1/orgs/{...}`, JWT claims) intact.
- TRA-618 §W5 (BB.md self-consistency vs. Quickstart) is moot: the
  current `tests/blackbox/BB.md` does not mandate any first-call
  sequence, so there is nothing to realign. Closed in PR description.

## Non-goals

- No SPA changes. SPA already labels the dropdown as `Read + Write` and
  uses `Organization` consistently; no front-end work is needed.
- No platform-side server changes. TRA-630 §F3 (`detail` string for
  session-JWT-on-`/orgs/me`) is platform work and not bundled here.
- No `description` ambiguity rewrite (TRA-618 §C5). Per ticket: cosmetic,
  flagged-only; close as won't-fix in PR description.
- No spec edits in `static/api/openapi.{yaml,json}` beyond the
  `scripts/refresh-openapi.sh` pull. The pulled file is the authoritative
  artifact.

## File map and per-file changes

### `static/api/openapi.{json,yaml}`, `static/api/platform-meta.json`, `static/api/trakrf-api.postman_collection.json`

Refresh from `trakrf/platform` `main` via `scripts/refresh-openapi.sh`.
This picks up:

- `limit` `minimum: 1, maximum: 200, default: 50` and `offset: minimum: 0`
  on every list endpoint.
- `minimum: 1, maximum: 2147483647` on every numeric path parameter.
- `location_id`, `location_external_key`, `external_key`, `parent_id`,
  `parent_external_key` declared as `type: array` with `style: form,
explode: true`.
- `from` and `to` on history declared `format: date-time`.
- `sort` annotation-driven `style: form, explode: false`.

No prose follow-up needed for any of these — the existing docs prose
already describes them correctly. The spec mirror is what generated
clients consume.

### `docs/api/authentication.md`

- **§W2 Read+Write label drift.** Replace the three `Read+Write` strings
  with `Read + Write` (with surrounding spaces) to match the SPA dropdown
  label. Affected: lines around the UI-labels-vs-scope-strings table and
  the surrounding prose.
- **§W3 Session-only key list/revoke.** Insert a new short subsection
  under "Key lifecycle" — heading "Listing and revocation are SPA-side."
  Body: viewing the key list, key metadata (created / last-used /
  expires), and revoking are session-authenticated SPA affordances. There
  is no API surface for these in v1; partners that need to automate
  rotation on a schedule must script the SPA mint flow or open a support
  ticket. Cross-link the existing "Where keys come from" rationale.
- **§W4 "Never" expiration.** Strengthen the existing Expiration bullet
  on line ~129 to add a one-sentence codegen caveat: choosing **Never**
  mints a JWT with **no `exp` claim**, so generated clients that
  auto-refresh on `exp` will treat the key as immortal and never trigger
  rotation. Recommend an explicit expiration for any non-throwaway key.
- **§C5 org → organization.** Line 21: replace three customer-prose
  occurrences ("the org currently selected", "the org switcher", "the
  wrong org") with the long form.

### `docs/api/quickstart.mdx`

- **§W2.** Line 89: `Read+Write` → `Read + Write` (one occurrence in
  prose, not in a code block).
- **§C5.** Line 32: `multi-org switcher` → `organization switcher` (the
  word "multi-" is redundant when the long form is used). Line 62: `the
org you minted` → `the organization you minted`.

### `docs/api/resource-identifiers.md`

- **§C3 (BB19) + BB20 §C1 — customer-voice rewrite of the
  cross-type-`id` paragraph.** Rewrite the `### Numeric id collides
across resource types` subsection to:
  - drop the parenthetical "(BB16 testing observed `790505327` …)" cycle
    citation;
  - reframe the example in customer voice ("the same integer can appear
    as both an `asset_id` and a `tag_id` within one organization");
  - keep the recommendation to qualify ids with the resource type;
  - keep the same sub-heading anchor so deep links are stable.
- **§C3 (BB20) — asset metadata vs. location absence.** Add a new short
  subsection (or callout) under the existing read-shape coverage,
  documenting that `PublicAssetView` carries a free-form `metadata`
  object (`additionalProperties: true`) for partner side-channel data and
  that `PublicLocationView` does not. Recommend: stuff partner-side ids
  on assets via `metadata`; on locations, use `tags` (typed natural-key
  pairs) for the same purpose. The asymmetry is intentional for v1.
- **§C5.** Lines 22 and 24: `single org` → `single organization`; `an
org` → `an organization`.

### `docs/api/errors.md`

- **Path-param out-of-range note.** Per platform PR #277 comment, add a
  one-sentence parenthetical to the `not_found` row in the catalog table
  (line ~65) clarifying that **out-of-range** numeric path-param values
  surface as `400 validation_error`, not 404 — the spec now declares
  `maximum: 2147483647` on numeric path params. Verify against the live
  preview before shipping the wording.
- **§C5.** Line 69 (the `missing_org_context` description): expand "no
  org context", "before an org was selected", "an API key whose org has
  been deleted", "Pick an org", "live org" to use `organization`. Keep
  the error type string `missing_org_context` and the title `Missing org
context` exactly as they appear in the canonical-titles table — those
  are public contracts.

### `docs/api/private-endpoints.md`

- **§C5.** Line 17: `org-scoped API key` → `organization-scoped API
key`. Lines 29 and 30: `SPA org switcher` → `SPA organization
switcher`; `SPA org picker` → `SPA organization picker`.

### `docs/api/webhooks.md`

- **§C5.** Line 40: `per org` → `per organization`.

### `docs/api/pagination-filtering-sorting.md`

No prose change required (audit verified the doc already describes
repeatable filters and the RFC 3339 `from`/`to` format correctly). The
spec refresh does the heavy lifting for generated clients.

### `docs/user-guide/asset-management.md`

- **§C5.** Line 34: `fresh org` → `new organization`.

### `docs/integrations/index.md`

- **§C5.** Line 15: `against a TrakRF org` → `against a TrakRF
organization`.

### `docs/getting-started/api.mdx`

No customer-prose `org` instance — the only match is `/api/v1/orgs/me`
inside backticks (technical surface, intentionally untouched).

### `tests/blackbox/BB.md` (eval orchestrator, internal)

No edit. The current file does not mandate any first-call sequence —
the §W5 conflict described in TRA-618 (BB.md says
`/api/v1/locations/current` first vs. Quickstart says `/api/v1/orgs/me`
first) is not present in the file as it stands. Confirmed via grep
across the entire `tests/blackbox/` tree. Item closed in PR description
with the note "stale finding — no edit needed."

## Audit-adjacent sweeps (per the standing CC fix-ticket directive)

- **`Read+Write` instances:** ripgrep `Read\+Write` across `docs/` and
  `tests/`. The pre-survey found four hits (3 in authentication.md, 1 in
  quickstart.mdx). All covered above.
- **Customer-prose `org` instances:** ripgrep `\borg\b|\borgs\b` across
  `docs/` and `tests/`, excluding technical surfaces (`org_id`, `org.`,
  `/orgs/`, `missing_org_context`, error-table rows). Pre-survey found
  hits in 8 files; all covered above.
- **Repeatable filter prose vs spec:** verified the existing
  pagination-filtering-sorting.md and resource-identifiers.md prose
  matches the new array-typed schema. No drift to fix.
- **Other date-string-shaped query params:** `from`/`to` on history are
  the only ones; covered. No other date-shaped query params in the
  spec.

## Verification

1. `pnpm lint` clean.
2. `pnpm build` clean (no broken anchors after the rewrites).
3. `pnpm dev` and visual-spot-check the affected pages render correctly.
4. Live-preview smoke-check: confirm `GET /api/v1/assets/99999999999`
   returns `400 validation_error` (not `400 bad_request`) before shipping
   the errors.md note. If the preview returns something else, drop the
   note.
5. Diff `static/api/openapi.yaml` to confirm the expected platform-PR-#277
   shape changes (limit bounds, path-param bounds, array-typed filters,
   date-time format, sort style/explode).

## Out-of-scope items (explicit close)

- TRA-618 §C5 (`description` ambiguity between OpenAPI metadata key and
  resource field): cosmetic, won't-fix. Note in PR description.
- TRA-630 §F3 (server `detail` string for session-JWT-on-`/orgs/me`):
  platform-side fix; not docs.
- TRA-618 §W5 (BB.md self-consistency): stale finding. The current
  `tests/blackbox/BB.md` does not mandate any first-call sequence;
  there is nothing to align. No edit.

## References

- Platform PR: <https://github.com/trakrf/platform/pull/277>
- TRA-618 ticket comment with §S3/§S4 closure summary
- TRA-626 ticket comment with §S1/§S2 closure summary and the
  `preserveCollectionFormat` generator note
- TRA-630 ticket comment with §S5 closure note
