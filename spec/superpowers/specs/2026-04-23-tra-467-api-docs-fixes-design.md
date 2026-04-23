# TRA-467 — API docs fixes: env auto-detect, multi-org warning, scope labels, 401 title variance (design)

**Linear:** [TRA-467](https://linear.app/trakrf/issue/TRA-467) — sub-issue of TRA-210
**Source:** black-box evaluation #5 (2026-04-23), findings F4–F7
**Related (just shipped):** [TRA-466](https://linear.app/trakrf/issue/TRA-466) — API-key management promotion. This PR does not touch the sections TRA-466 added (Programmatic key rotation, keys:admin row in Scopes).

## Goal

Land four docs-vs-service mismatches from the 2026-04-23 black-box pass, and piggyback one small enhancement to the black-box test harness (OpenAPI contract pass) that was written alongside the eval.

1. **F4** — Quickstart pages default-suggest production (`app.trakrf.id`), but every current test account lives on preview. A dev reading top-to-bottom signs up against the wrong env.
2. **F5** — API keys are scoped to whichever org is selected in the avatar menu at creation time. For multi-org admins there is no warning to check the org switcher first.
3. **F6** — Docs use scope strings (`scans:read`, `assets:write`). The **New key** form uses `Assets / Locations / Scans × None / Read / Read+Write`. No mapping is documented, and the create form has no tooltips.
4. **F7** — The 401 `title` string varies across causes (`Use Authorization: Bearer <token>`, `Invalid or expired token`, `Missing authorization header`, `Authentication required`). `type: unauthorized` is stable. Docs show one example and don't warn integrators to match on `type`.

## Scope

One PR, one branch, one worktree. Conventional commits, incremental (no squash). Per the project convention and the pre-launch nav-over-URL-stability memory — nav/structure changes are fine if they improve the reading experience.

**Branch:** `miks2u/tra-467-api-docs-fixes`
**Worktree:** `.worktrees/tra-467` (created off `main`)

**Commit plan (one feature per commit):**

1. `feat(tra-467): env-aware docs components (useDeployEnv hook + MDX helpers)` — hook + four React components. No doc changes yet.
2. `docs(tra-467): auto-detect env on API quickstart pages (F4)` — convert quickstart pages to `.mdx`; use the new components; add the env-aware step-1 callout.
3. `docs(tra-467): note multi-org key scoping gotcha (F5)` — three short insertions.
4. `docs(tra-467): document UI-to-scope mapping for New key form (F6)` — new table + lede before existing Scopes table.
5. `docs(tra-467): note 401 title variance, match on type (F7)` — two small edits to errors.md.
6. `docs(tra-467): changelog entry` — `Unreleased → Changed`.
7. `test(tra-467): document OpenAPI contract check pass in blackbox harness` — already-uncommitted BB.md change, landed as its own commit.

**In scope:**

- `src/hooks/useDeployEnv.ts` (new)
- `src/components/EnvBaseURL.tsx` (new)
- `src/components/EnvBaseURLBlock.tsx` (new)
- `src/components/EnvLabel.tsx` (new)
- `src/components/EnvSignInLink.tsx` (new)
- `src/components/EnvSwitcher.tsx` (new)
- `docs/api/quickstart.md` → `docs/api/quickstart.mdx` (rename + edit)
- `docs/getting-started/api.md` → `docs/getting-started/api.mdx` (rename + edit)
- `docs/api/authentication.md` (F5 sentence, F6 subsection)
- `docs/api/errors.md` (F7 edits)
- `docs/api/CHANGELOG.md` (one entry)
- `tests/blackbox/BB.md` (the existing uncommitted enhancement, committed as its own step)

**Out of scope:**

- Screenshots. The `<!-- TODO: screenshot -->` comment in `authentication.md` stays untouched.
- Sidebar / nav structure.
- Any edit to `authentication.md`'s Key lifecycle, Programmatic key rotation, or Scopes-table rows — those are TRA-466 territory.
- `static/api/openapi.{json,yaml}` and any platform-side change.
- OAuth2 / service accounts / webhook-based key-expiry notifications (out of scope per Linear).

## Design

### F4 — env auto-detection

The docs site is deployed per environment: `main` → `docs.trakrf.id`, `preview` → `docs.preview.trakrf.id`. Runtime URL parsing is enough — no build-time plumbing needed. Rule: take `window.location.hostname` and `s/^docs\./app./`. Generalizes to any future subdomain (e.g. `docs.staging.trakrf.id` → `app.staging.trakrf.id`) with zero code change.

#### `src/hooks/useDeployEnv.ts`

React hook, single source of truth. Returns:

```ts
type DeployEnv = {
  appHost: string;         // e.g. "https://app.preview.trakrf.id"
  envLabel: "production" | "preview" | "unknown";
  override: "production" | "preview" | null;  // from localStorage
  setOverride: (env: "production" | "preview") => void;
  clearOverride: () => void;
};
```

Resolution order at read time:

1. `localStorage.getItem("trakrf-env")` — if `"production"` or `"preview"`, use it.
2. Else parse `window.location.hostname`: strip a leading `docs.`, prepend `https://app.`. Label = `"preview"` if the hostname contains `.preview.`, else `"production"`.
3. SSR / first-render: return production defaults. The hook reads `typeof window` and re-renders on hydration; a one-frame flicker on preview is acceptable for docs pages.

Override writes dispatch a `storage`-like event so every mounted `EnvSwitcher` / `EnvBaseURL*` on the page updates in sync.

#### Components

All four are thin wrappers over the hook:

- **`<EnvBaseURL />`** — inline span, renders just `https://app.trakrf.id` or `https://app.preview.trakrf.id`.
- **`<EnvLabel />`** — inline span, renders just `production` or `preview`. Used in sentences that have to name the env (the step-1 callout, sign-in links).
- **`<EnvBaseURLBlock />`** — a single shell block:
  ```bash
  export BASE_URL=https://app.preview.trakrf.id
  ```
  Replaces the current two-block "pick one of these" pattern.
- **`<EnvSignInLink>children</EnvSignInLink>`** — anchor to `{appHost}` with the children as link text.
- **`<EnvSwitcher />`** — small pill control, rendered inside the step-1 callout on each quickstart page:
  > `Environment: Preview ▾` → dropdown `Production / Preview / Reset to auto-detect`.

  Styling uses existing Infima / Docusaurus tokens — no new CSS file required beyond a small module.

#### Page edits — `docs/api/quickstart.md` → `.mdx`

Replace the opening of the page with a new ordered step 1:

```mdx
## 1. Pick your environment

You're reading <EnvLabel /> docs. Examples on this page target <EnvBaseURL /> — the app host that matches this docs site.

<EnvSwitcher />

If your account lives on the other environment, use the switcher above — the examples and links below will update.
```

Renumber the remaining steps from 2. The existing "Set your base URL" section collapses to a one-liner plus `<EnvBaseURLBlock />`.

Inline "sign in … (production: app.trakrf.id; preview: app.preview.trakrf.id)" parentheticals in step 2 collapse to:

> Sign in with an admin account (<EnvSignInLink><EnvLabel /> app</EnvSignInLink>).

The TL;DR paragraph at the top stays in place; the `$BASE_URL` references in curl blocks are unchanged (they already use the variable, which the reader now exports with the right value via the block in step 1).

#### Page edits — `docs/getting-started/api.md` → `.mdx`

Same pattern, one wrinkle: the "What you'll need" list says "Sign up at [app.trakrf.id]". Signup is prod-only in practice (preview accounts are issued), so keep the signup link hard-coded to production, but reword to clarify:

> - A TrakRF account. If you were given preview credentials, you already have one — skip to step 1. Otherwise [sign up at app.trakrf.id](https://app.trakrf.id).

Step 1 "Pick your environment" is added in the same shape as the api/quickstart version. Subsequent steps gain the same `<EnvSignInLink>` / `<EnvBaseURLBlock />` treatment.

### F5 — multi-org key-minting warning

One sentence, placed three times (short pointer on the third):

**`docs/api/authentication.md#mint-your-first-api-key`** — insert after step 2 ("Open the **avatar menu** …") as a new step or a bolded callout inside step 2:

> If your account belongs to multiple organizations, API keys are scoped to whichever org is currently selected in the avatar menu. Check the org switcher before clicking **New key** — a key minted under the wrong org cannot be reassigned.

**`docs/api/quickstart.md`** (now `.mdx`) — same sentence in step 2, inline before "Click **New key**".

**`docs/getting-started/api.md`** (now `.mdx`) — abbreviated:

> Keys are scoped to the org selected in the avatar menu. If you admin multiple orgs, check the switcher first. ([details](../api/authentication#mint-your-first-api-key))

### F6 — UI-to-scope mapping

Insert a new subsection in `docs/api/authentication.md#scopes` **before** the existing scopes table (which stays unchanged):

```md
### UI labels vs scope strings {#ui-labels}

The **New key** form in the web app lets you pick a resource (Assets / Locations / Scans) and an access level (None / Read / Read+Write). Each combination maps to one or two of the scope strings used throughout these docs and in API responses. `keys:admin` is not exposed in the form — admin-tier keys are minted via API, see [Programmatic key rotation](#programmatic-key-rotation).

| UI form (resource × level)   | Scopes granted                      |
| ---------------------------- | ----------------------------------- |
| Assets → Read                | `assets:read`                       |
| Assets → Read+Write          | `assets:read`, `assets:write`       |
| Locations → Read             | `locations:read`                    |
| Locations → Read+Write       | `locations:read`, `locations:write` |
| Scans → Read                 | `scans:read`                        |
| Scans → Read+Write           | `scans:read`, `scans:write`         |

Selecting **None** for a resource grants no scope for that resource. Selecting **Read+Write** always grants both the read and the write scope — there is no write-only level today.
```

### F7 — 401 title variance

Two small edits in `docs/api/errors.md`.

**1. Envelope shape table — `type` row.** Replace:

> A machine-readable identifier — your code should branch on this. Extensible enum.

with:

> A machine-readable identifier — your code should branch on this, not on `title`. Extensible enum.

**2. Envelope shape table — `title` row.** Replace:

> A short human-readable summary safe to log.

with:

> A short human-readable summary safe to log. May vary between instances of the same `type` (for example, 401 responses carry different titles for missing-header vs expired-token vs revoked-key).

**3. Error-type catalog — `unauthorized` row, "When you'll see it" cell.** Append:

> The `title` varies by cause (missing header, invalid token, expired, revoked) — match on `type`, not `title`.

No new section, no example re-authoring. The existing 401 sample body stays.

### CHANGELOG

One entry in `docs/api/CHANGELOG.md` under `Unreleased → Changed`:

```md
### Changed

- API quickstart and Getting-started → API pages now auto-detect environment from the docs hostname (`docs.trakrf.id` → production app, `docs.preview.trakrf.id` → preview app), with a switcher for cross-environment readers ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F4).
- Added a multi-organization warning on the API-key minting steps: keys are scoped to whichever org is selected in the avatar menu at creation time ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F5).
- Added a UI-form-to-scope-string mapping table on Authentication → Scopes ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F6).
- Errors → Envelope clarified that `title` is descriptive and varies; clients should match on `type` ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F7).
```

### Black-box harness enhancement (piggyback)

Commit the existing uncommitted diff to `tests/blackbox/BB.md` as its own `test(tra-467):` commit. The diff adds an "OpenAPI spec contract check" section (fetch spec, walk paths, CRUD lifecycle, pagination boundaries) and retargets the findings writeup to `FINDINGS.md`. No design work needed — ship as-is.

## Verification

- `pnpm typecheck` — passes with the new hook + components.
- `pnpm lint` — prettier-clean.
- `pnpm build` — both `main` and `preview` branches build without `onBrokenLinks: throw` tripping. The two `.md` → `.mdx` renames must keep their sidebar positions / slugs (filename change only, frontmatter unchanged).
- Local `pnpm dev` sanity checks:
  - Load `/docs/api/quickstart` on `localhost` — `envLabel` falls back to "production" by default (hostname doesn't match the rule). Confirm switcher flips `<EnvBaseURL />` / `<EnvBaseURLBlock />` / `<EnvSignInLink />` in sync.
  - Set `localStorage.trakrf-env = "preview"` → reload → everything flips. Clear override → reverts.
  - Verify no sidebar/nav breakage after the `.mdx` renames.
- Hydration: preview-hostname reader sees one-frame flicker from prod → preview. Acceptable; note in the commit message.

## Risks

- **First `.tsx`/`.mdx` pattern for docs content.** Only `postman.mdx` currently mixes MDX; the rest is plain Markdown. This adds a small React surface (one hook, four components) that future doc fixes may want to reuse — fine, but a larger footprint than a pure-Markdown version of the fix would be.
- **Hydration flicker** on preview docs. Mitigation: the fallback is production, which matches the majority of anonymous readers. Preview readers are mostly evaluators running through a quickstart; a half-second flicker is not a blocker.
- **Localhost dev shows production defaults.** The `s/^docs\./app./` rule doesn't match `localhost`. That's fine — dev preview should never be interpreted as a real env. Document this in the hook's JSDoc.
- **localStorage override key collision.** Namespaced `trakrf-env` is specific enough. Documented in the hook.

## Acceptance

- The four Linear DoD bullets are satisfied:
  - Quickstart: environment choice at top of page ✓ (F4, both pages)
  - API keys docs/quickstart: multi-org warning sentence ✓ (F5, three sites)
  - Auth docs: scope string mapping table or note ✓ (F6)
  - Error docs: note that 401 `title` varies, match on `type` ✓ (F7)
- BB.md harness enhancement lands as a separate commit on the same branch.
- No TRA-466 content is touched.
