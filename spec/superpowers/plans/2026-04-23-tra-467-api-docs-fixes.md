# TRA-467 API Docs Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land findings F4–F7 from black-box eval #5 (2026-04-23): env auto-detection on the two quickstart pages, multi-org key-minting warning, UI-label-to-scope-string mapping, and a 401 `title`-variance note. Piggyback the pre-existing blackbox OpenAPI contract-check enhancement as its own commit. Spec: `spec/superpowers/specs/2026-04-23-tra-467-api-docs-fixes-design.md`.

**Architecture:** F4 introduces a small React surface in `src/hooks/` and `src/components/`: a `useDeployEnv` hook (React 19 `useSyncExternalStore`, SSR-safe) plus five thin components used inside the affected MDX pages. The hook resolves environment via `localStorage('trakrf-env')` override → else `window.location.hostname` with `s/^docs\./app./`. F5–F7 are pure markdown edits. One BB.md commit finishes the branch.

**Tech Stack:** Docusaurus 3.9.2 (classic preset + redocusaurus), React 19, TypeScript, pnpm. No new runtime deps. Verification is `pnpm typecheck` + `pnpm build` + `pnpm dev` visual inspection, consistent with the project's existing verification pattern (no test runner set up in this repo).

---

## Prerequisites

- On branch `miks2u/tra-467-api-docs-fixes` in worktree `.worktrees/tra-467` (already created off `main`, spec commit `af7315d` on it). Confirm with `git branch --show-current && git log -1 --oneline`.
- `pnpm install` has been run and `node_modules/` is populated in the worktree.
- You are in `/home/mike/trakrf-docs/.worktrees/tra-467`. All paths below are relative to that cwd.

---

### Task 0: Baseline green

**Files:** none modified.

- [ ] **Step 1: Confirm branch + head**

Run: `git branch --show-current && git log -1 --oneline`
Expected:

```
miks2u/tra-467-api-docs-fixes
af7315d docs(tra-467): design spec for API docs fixes (F4-F7 + BB.md harness bump)
```

- [ ] **Step 2: Verify typecheck passes on clean tree**

Run: `pnpm typecheck`
Expected: 0 errors. No output from `tsc` on success.

- [ ] **Step 3: Verify build passes on clean tree**

Run: `pnpm build`
Expected: build completes; no "Broken link" errors; produces `build/` directory. This establishes that any build failure later is caused by our edits, not pre-existing breakage.

- [ ] **No commit** — baseline only.

---

### Task 1: Create the `useDeployEnv` hook

**Files:**

- Create: `src/hooks/useDeployEnv.ts`

The hook is the single source of truth for environment detection. It uses React 19's `useSyncExternalStore` so components re-render consistently when the override changes, and so SSR has a deterministic server snapshot.

- [ ] **Step 1: Create the hook file**

Create `src/hooks/useDeployEnv.ts` with this exact content:

```ts
import { useSyncExternalStore } from "react";

/**
 * Environment detected from the docs hostname, with localStorage override.
 *
 * Resolution order:
 *   1. localStorage["trakrf-env"] if set to "production" or "preview"
 *   2. Parse window.location.hostname: strip leading "docs.", prepend "app."
 *      (docs.trakrf.id → app.trakrf.id; docs.preview.trakrf.id → app.preview.trakrf.id)
 *   3. SSR / non-matching hostname (e.g. localhost): fall back to production
 *
 * The hook listens on cross-tab storage events and an in-page custom event so
 * every consumer stays in sync when the user flips the EnvSwitcher.
 */
export type DeployEnvLabel = "production" | "preview";

export type DeployEnv = {
  /** Full origin, e.g. "https://app.preview.trakrf.id" */
  appHost: string;
  /** "production" | "preview" */
  envLabel: DeployEnvLabel;
  /** The localStorage override, or null if auto-detecting */
  override: DeployEnvLabel | null;
  /** Persist an override and notify other hook instances */
  setOverride: (env: DeployEnvLabel) => void;
  /** Clear the override, returning to auto-detect */
  clearOverride: () => void;
};

const STORAGE_KEY = "trakrf-env";
const CHANGE_EVENT = "trakrf-env-change";

const PROD_HOST = "https://app.trakrf.id";
const PREVIEW_HOST = "https://app.preview.trakrf.id";

function readOverride(): DeployEnvLabel | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (raw === "production" || raw === "preview") return raw;
  return null;
}

function detectFromHostname(): DeployEnvLabel {
  if (typeof window === "undefined") return "production";
  const host = window.location.hostname;
  // docs.preview.trakrf.id → preview; docs.trakrf.id → production
  // localhost / any non-matching host → production (sensible dev default)
  if (host.startsWith("docs.preview.") || host.startsWith("app.preview.")) {
    return "preview";
  }
  return "production";
}

function getSnapshot(): string {
  const override = readOverride();
  const env = override ?? detectFromHostname();
  return env;
}

function getServerSnapshot(): string {
  return "production";
}

function subscribe(callback: () => void): () => void {
  const onStorage = (e: StorageEvent) => {
    if (e.key === STORAGE_KEY || e.key === null) callback();
  };
  const onCustom = () => callback();
  window.addEventListener("storage", onStorage);
  window.addEventListener(CHANGE_EVENT, onCustom);
  return () => {
    window.removeEventListener("storage", onStorage);
    window.removeEventListener(CHANGE_EVENT, onCustom);
  };
}

export function useDeployEnv(): DeployEnv {
  const envLabel = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot,
  ) as DeployEnvLabel;

  const appHost = envLabel === "preview" ? PREVIEW_HOST : PROD_HOST;
  const override = readOverrideSafe();

  const setOverride = (env: DeployEnvLabel) => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(STORAGE_KEY, env);
    window.dispatchEvent(new Event(CHANGE_EVENT));
  };

  const clearOverride = () => {
    if (typeof window === "undefined") return;
    window.localStorage.removeItem(STORAGE_KEY);
    window.dispatchEvent(new Event(CHANGE_EVENT));
  };

  return { appHost, envLabel, override, setOverride, clearOverride };
}

// Reads override safely on both server and client; used to populate the
// `override` field in the returned object without another store subscription.
function readOverrideSafe(): DeployEnvLabel | null {
  if (typeof window === "undefined") return null;
  return readOverride();
}
```

- [ ] **Step 2: Run typecheck**

Run: `pnpm typecheck`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add src/hooks/useDeployEnv.ts
git commit -m "$(cat <<'EOF'
feat(tra-467): add useDeployEnv hook for env-aware docs components

Runtime detection from docs.* hostname → app.* app host, with
localStorage override. SSR defaults to production. Uses
useSyncExternalStore so multiple consumers stay in sync.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create the five env-aware components

**Files:**

- Create: `src/components/EnvLabel.tsx`
- Create: `src/components/EnvBaseURL.tsx`
- Create: `src/components/EnvBaseURLBlock.tsx`
- Create: `src/components/EnvSignInLink.tsx`
- Create: `src/components/EnvSwitcher.tsx`
- Create: `src/components/EnvSwitcher.module.css`

Each component is a thin wrapper over `useDeployEnv()`. They are imported at the top of the MDX pages that use them (no Docusaurus swizzle needed).

- [ ] **Step 1: Create `src/components/EnvLabel.tsx`**

```tsx
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

/** Inline span rendering just "production" or "preview". */
export default function EnvLabel(): JSX.Element {
  const { envLabel } = useDeployEnv();
  return <span>{envLabel}</span>;
}
```

- [ ] **Step 2: Create `src/components/EnvBaseURL.tsx`**

```tsx
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

/** Inline span rendering the env-appropriate app host, e.g. https://app.preview.trakrf.id */
export default function EnvBaseURL(): JSX.Element {
  const { appHost } = useDeployEnv();
  return <code>{appHost}</code>;
}
```

- [ ] **Step 3: Create `src/components/EnvBaseURLBlock.tsx`**

```tsx
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

/**
 * Shell code block that exports BASE_URL for the env-matching app host.
 * Replaces the previous two-block "pick one of these" pattern.
 */
export default function EnvBaseURLBlock(): JSX.Element {
  const { appHost } = useDeployEnv();
  return (
    <pre>
      <code>{`export BASE_URL=${appHost}`}</code>
    </pre>
  );
}
```

- [ ] **Step 4: Create `src/components/EnvSignInLink.tsx`**

```tsx
import type { ReactNode } from "react";
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

type Props = { children: ReactNode };

/** Anchor to the env-appropriate app host. Children are the link text. */
export default function EnvSignInLink({ children }: Props): JSX.Element {
  const { appHost } = useDeployEnv();
  return (
    <a href={appHost} target="_blank" rel="noreferrer">
      {children}
    </a>
  );
}
```

- [ ] **Step 5: Create `src/components/EnvSwitcher.module.css`**

```css
.switcher {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.75rem;
  border: 1px solid var(--ifm-color-emphasis-300);
  border-radius: 999px;
  background: var(--ifm-background-surface-color);
  font-size: 0.9rem;
  line-height: 1;
  margin: 0.75rem 0;
}

.label {
  color: var(--ifm-color-emphasis-700);
  font-weight: 500;
}

.select {
  border: none;
  background: transparent;
  color: var(--ifm-color-primary);
  font: inherit;
  cursor: pointer;
  padding: 0 0.25rem;
}

.select:focus-visible {
  outline: 2px solid var(--ifm-color-primary);
  outline-offset: 2px;
  border-radius: 4px;
}
```

- [ ] **Step 6: Create `src/components/EnvSwitcher.tsx`**

```tsx
import {
  useDeployEnv,
  type DeployEnvLabel,
} from "@site/src/hooks/useDeployEnv";
import styles from "./EnvSwitcher.module.css";

type SwitcherValue = DeployEnvLabel | "auto";

/**
 * Pill control that shows the currently resolved environment and lets the
 * reader override it (persisted via localStorage). Renders the same label the
 * hook resolves so SSR and hydrated output match.
 */
export default function EnvSwitcher(): JSX.Element {
  const { envLabel, override, setOverride, clearOverride } = useDeployEnv();
  const value: SwitcherValue = override ?? "auto";

  const onChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const next = e.target.value as SwitcherValue;
    if (next === "auto") clearOverride();
    else setOverride(next);
  };

  return (
    <span className={styles.switcher}>
      <span className={styles.label}>Environment: {envLabel}</span>
      <select
        className={styles.select}
        value={value}
        onChange={onChange}
        aria-label="Switch docs environment"
      >
        <option value="auto">Auto-detect</option>
        <option value="production">Production</option>
        <option value="preview">Preview</option>
      </select>
    </span>
  );
}
```

- [ ] **Step 7: Typecheck**

Run: `pnpm typecheck`
Expected: 0 errors.

- [ ] **Step 8: Build**

Run: `pnpm build`
Expected: build completes with no errors. Nothing imports these components yet, so they don't ship in any page; this step confirms TypeScript + Docusaurus accept them.

- [ ] **Step 9: Commit**

```bash
git add src/components/EnvLabel.tsx src/components/EnvBaseURL.tsx src/components/EnvBaseURLBlock.tsx src/components/EnvSignInLink.tsx src/components/EnvSwitcher.tsx src/components/EnvSwitcher.module.css
git commit -m "$(cat <<'EOF'
feat(tra-467): add env-aware MDX helper components

EnvLabel, EnvBaseURL, EnvBaseURLBlock, EnvSignInLink, EnvSwitcher.
Each wraps useDeployEnv. EnvSwitcher renders a small pill dropdown
persisting the reader's choice to localStorage.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: F4 — convert `docs/api/quickstart.md` to `.mdx` and wire env detection

**Files:**

- Rename: `docs/api/quickstart.md` → `docs/api/quickstart.mdx`
- Modify: `docs/api/quickstart.mdx`

The rename uses `git mv` so history is preserved. After the rename, the only edits are: add MDX imports at the top, add a new "Pick your environment" step 1, collapse the two-block base-URL section, and swap inline `(production: x; preview: y)` parentheticals for `<EnvSignInLink>`.

- [ ] **Step 1: Rename file**

Run:

```bash
git mv docs/api/quickstart.md docs/api/quickstart.mdx
```

Expected: no output; `git status` shows `renamed: docs/api/quickstart.md -> docs/api/quickstart.mdx`.

- [ ] **Step 2: Add MDX imports below the frontmatter**

Open `docs/api/quickstart.mdx`. The current frontmatter ends at line 4 (`---`). Insert the following immediately after line 4, before the `# Quickstart` heading:

```mdx
import EnvLabel from "@site/src/components/EnvLabel";
import EnvBaseURL from "@site/src/components/EnvBaseURL";
import EnvBaseURLBlock from "@site/src/components/EnvBaseURLBlock";
import EnvSignInLink from "@site/src/components/EnvSignInLink";
import EnvSwitcher from "@site/src/components/EnvSwitcher";
```

Leave one blank line before `# Quickstart`.

- [ ] **Step 3: Replace "## 1. Set your base URL" section with "## 1. Pick your environment"**

Find the existing section (currently starts at `## 1. Set your base URL` around line 12 and ends before `## 2. Mint an API key`). Replace the entire section — heading, prose, both shell blocks, and the trailing paragraph about preview-scoped keys — with:

```mdx
## 1. Pick your environment

You're reading <EnvLabel /> docs. Examples on this page target <EnvBaseURL /> — the app host that matches this docs site.

<EnvSwitcher />

If your account lives on the other environment, use the switcher above — the examples and links below will update.

<EnvBaseURLBlock />

Preview-scoped keys will not authenticate against production and vice versa; the switcher above keeps the curl snippets aligned with whichever world your key was minted on.
```

- [ ] **Step 4: Collapse the sign-in parenthetical in step 2**

In section `## 2. Mint an API key`, step 1 currently reads:

```
1. Sign in with an admin account (production: [app.trakrf.id](https://app.trakrf.id); preview: [app.preview.trakrf.id](https://app.preview.trakrf.id)).
```

Replace with:

```mdx
1. Sign in with an admin account on the <EnvSignInLink><EnvLabel /> app</EnvSignInLink>.
```

- [ ] **Step 5: Verify build**

Run: `pnpm build`
Expected: build completes; no broken-link errors. The MDX imports compile. If you see "Module not found" on any `@site/src/components/...` path, confirm Task 2 created them and the import path matches exactly.

- [ ] **Step 6: Commit**

```bash
git add docs/api/quickstart.mdx docs/api/quickstart.md
git commit -m "$(cat <<'EOF'
docs(tra-467): auto-detect env on API quickstart (F4)

Convert quickstart.md to .mdx so it can use the env-aware components.
Replaces "Set your base URL" (two shell blocks, reader-picks-one) with
"Pick your environment" driven by the docs hostname and overridable
via the in-page switcher. Inline "production: x; preview: y"
parentheticals collapse to EnvSignInLink.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Note: `git mv` stages both the deletion and addition; the `git add` above is defensive and won't hurt if redundant.

---

### Task 4: F4 — convert `docs/getting-started/api.md` to `.mdx` and wire env detection

**Files:**

- Rename: `docs/getting-started/api.md` → `docs/getting-started/api.mdx`
- Modify: `docs/getting-started/api.mdx`

Same shape as Task 3 with one difference: this page's "What you'll need" prelude has a signup link that must stay pinned to production (preview has no self-serve signup — preview accounts are issued).

- [ ] **Step 1: Rename file**

Run:

```bash
git mv docs/getting-started/api.md docs/getting-started/api.mdx
```

- [ ] **Step 2: Add MDX imports below frontmatter**

Insert after the frontmatter closing `---`, before the `# Getting started — using the API` heading:

```mdx
import EnvLabel from "@site/src/components/EnvLabel";
import EnvBaseURL from "@site/src/components/EnvBaseURL";
import EnvBaseURLBlock from "@site/src/components/EnvBaseURLBlock";
import EnvSignInLink from "@site/src/components/EnvSignInLink";
import EnvSwitcher from "@site/src/components/EnvSwitcher";
```

- [ ] **Step 3: Edit "What you'll need" signup bullet**

Find the bullet currently reading:

```
- A TrakRF account. Sign up at [app.trakrf.id](https://app.trakrf.id) if you don't have one yet.
```

Replace with:

```
- A TrakRF account. If you were given preview credentials, you already have one — skip to step 1. Otherwise [sign up at app.trakrf.id](https://app.trakrf.id).
```

The signup link stays hardcoded to production because preview has no public self-serve signup.

- [ ] **Step 4: Replace "## 1. Set your base URL" with "## 1. Pick your environment"**

Find `## 1. Set your base URL` (currently around line 16) through the end of that section (the paragraph about preview-scoped keys). Replace the whole section with:

```mdx
## 1. Pick your environment

You're reading <EnvLabel /> docs. Examples on this page target <EnvBaseURL /> — the app host that matches this docs site.

<EnvSwitcher />

If your account lives on the other environment, use the switcher above — the examples and links below will update.

<EnvBaseURLBlock />

Preview-scoped keys will not authenticate against production and vice versa; the switcher above keeps the curl snippets aligned with whichever world your key was minted on.
```

- [ ] **Step 5: Collapse the sign-in parenthetical in step 2**

In section `## 2. Mint your first API key`, step 1 currently reads:

```
1. Sign in at the web app (production: [app.trakrf.id](https://app.trakrf.id); preview: [app.preview.trakrf.id](https://app.preview.trakrf.id)).
```

Replace with:

```mdx
1. Sign in at the <EnvSignInLink><EnvLabel /> web app</EnvSignInLink>.
```

- [ ] **Step 6: Verify build**

Run: `pnpm build`
Expected: build completes with no broken-link errors.

- [ ] **Step 7: Commit**

```bash
git add docs/getting-started/api.mdx docs/getting-started/api.md
git commit -m "$(cat <<'EOF'
docs(tra-467): auto-detect env on getting-started API page (F4)

Same treatment as api/quickstart.mdx. Signup link stays pinned to
production since preview has no self-serve signup.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: F5 — multi-org key-minting warning

**Files:**

- Modify: `docs/api/authentication.md`
- Modify: `docs/api/quickstart.mdx`
- Modify: `docs/getting-started/api.mdx`

One full sentence on the canonical `authentication.md` location, the same sentence in `quickstart.mdx`, and a short pointer on `getting-started/api.mdx`.

- [ ] **Step 1: Insert full sentence in `docs/api/authentication.md`**

In `## Mint your first API key`, step 2 currently reads:

```
2. Open the **avatar menu** in the top-right corner and choose **API Keys**. (The left-nav **Settings** page is for device configuration — signal power, session, worker log level — not key management.)
```

Append a new item immediately **after** this step (so it becomes the new step 3, and the existing steps 3–5 renumber to 4–6):

```
3. **If your account belongs to multiple organizations,** API keys are scoped to whichever org is currently selected in the avatar menu. Check the org switcher before clicking **New key** — a key minted under the wrong org cannot be reassigned.
```

Then renumber the existing `3.`, `4.`, `5.` to `4.`, `5.`, `6.` in the same list.

- [ ] **Step 2: Insert full sentence in `docs/api/quickstart.mdx`**

In `## 2. Mint an API key`, insert a new item between the existing step 2 ("Open the **avatar menu**…") and the existing step 3 ("Click **New key**…"). Renumber subsequent items. The target shape after editing is:

```mdx
1. Sign in with an admin account on the <EnvSignInLink><EnvLabel /> app</EnvSignInLink>.
2. Open the **avatar menu** in the top-right corner and choose **API Keys**. (The left-nav **Settings** page is for device configuration — not key management.)
3. **If your account belongs to multiple organizations,** keys are scoped to whichever org is currently selected in the avatar menu. Check the org switcher before clicking **New key**. See [Authentication → Mint your first API key](./authentication#mint-your-first-api-key) for detail.
4. Click **New key**. […existing step 3 content, renumbered…]
```

Renumber remaining steps in the list accordingly.

- [ ] **Step 3: Insert short pointer in `docs/getting-started/api.mdx`**

In `## 2. Mint your first API key`, after step 2 (the "Open the avatar menu" step), insert:

```mdx
3. Keys are scoped to the org selected in the avatar menu. If you admin multiple orgs, check the switcher first. ([details](../api/authentication#mint-your-first-api-key))
```

Renumber remaining steps in the list accordingly.

- [ ] **Step 4: Verify build**

Run: `pnpm build`
Expected: no broken-link errors. The `./authentication#mint-your-first-api-key` and `../api/authentication#mint-your-first-api-key` anchors both point at an existing heading with existing id `mint-your-first-api-key`.

- [ ] **Step 5: Commit**

```bash
git add docs/api/authentication.md docs/api/quickstart.mdx docs/getting-started/api.mdx
git commit -m "$(cat <<'EOF'
docs(tra-467): note multi-org key scoping gotcha (F5)

Keys are minted against whichever org is selected in the avatar
menu. Add a warning in the canonical authentication.md location plus
one in each quickstart page (short pointer on the getting-started
page).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: F6 — UI-to-scope mapping table in `docs/api/authentication.md`

**Files:**

- Modify: `docs/api/authentication.md`

Insert a new `### UI labels vs scope strings` subsection immediately **before** the existing scopes table in `## Scopes`. The existing table is not modified.

- [ ] **Step 1: Locate insertion point**

The target is the `## Scopes` section in `docs/api/authentication.md`. The section currently reads:

```
## Scopes

Each key is issued with one or more scopes. The API rejects requests whose key lacks the scope required by the endpoint (`403 forbidden` with `"Missing required scope: <scope>"`). Current scopes and the endpoints they gate:

| Scope             | Access | Endpoints (representative) |
| ... (rest of the existing table)
```

- [ ] **Step 2: Insert the new subsection**

Insert the following block between the opening paragraph ("Each key is issued…") and the existing table, on its own lines (blank line before and after):

```markdown
### UI labels vs scope strings {#ui-labels}

The **New key** form in the web app lets you pick a resource (Assets / Locations / Scans) and an access level (None / Read / Read+Write). Each combination maps to one or two of the scope strings used throughout these docs and in API responses. `keys:admin` is not exposed in the form — admin-tier keys are minted via API, see [Programmatic key rotation](#programmatic-key-rotation).

| UI form (resource × level) | Scopes granted                      |
| -------------------------- | ----------------------------------- |
| Assets → Read              | `assets:read`                       |
| Assets → Read+Write        | `assets:read`, `assets:write`       |
| Locations → Read           | `locations:read`                    |
| Locations → Read+Write     | `locations:read`, `locations:write` |
| Scans → Read               | `scans:read`                        |
| Scans → Read+Write         | `scans:read`, `scans:write`         |

Selecting **None** for a resource grants no scope for that resource. Selecting **Read+Write** always grants both the read and the write scope — there is no write-only level today.
```

- [ ] **Step 3: Verify build**

Run: `pnpm build`
Expected: no broken-link errors. `#programmatic-key-rotation` already exists (added by TRA-466).

- [ ] **Step 4: Commit**

```bash
git add docs/api/authentication.md
git commit -m "$(cat <<'EOF'
docs(tra-467): document UI form → scope string mapping (F6)

The New key form uses resource × level (Assets/Locations/Scans ×
None/Read/Read+Write); docs use scope strings. Add a mapping table
in the Scopes section so readers can align what they pick in the UI
with the strings they see in docs and API responses.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: F7 — 401 `title`-variance notes in `docs/api/errors.md`

**Files:**

- Modify: `docs/api/errors.md`

Three small in-place edits: tighten the `type` and `title` rows in the envelope-shape table, and append a note to the `unauthorized` row in the catalog.

- [ ] **Step 1: Edit the `type` row in the envelope-shape table**

Find the row (currently around line 30) that reads:

```
| `type`       | A machine-readable identifier — your code should branch on this. Extensible enum.                                             |
```

Replace with:

```
| `type`       | A machine-readable identifier — your code should branch on this, not on `title`. Extensible enum.                             |
```

- [ ] **Step 2: Edit the `title` row in the envelope-shape table**

Find the row (currently around line 31) that reads:

```
| `title`      | A short human-readable summary safe to log.                                                                                   |
```

Replace with:

```
| `title`      | A short human-readable summary safe to log. May vary between instances of the same `type` (for example, 401 responses carry different titles for missing-header vs expired-token vs revoked-key). |
```

- [ ] **Step 3: Edit the `unauthorized` row in the error-type catalog**

Find the row (currently around line 43) that reads:

```
| `unauthorized`     | 401         | Missing, malformed, revoked, or expired API key                                           | No — re-auth                          |
```

Replace with:

```
| `unauthorized`     | 401         | Missing, malformed, revoked, or expired API key. `title` varies by cause — match on `type`. | No — re-auth                          |
```

- [ ] **Step 4: Verify build**

Run: `pnpm build`
Expected: build completes; no broken-link errors.

- [ ] **Step 5: Commit**

```bash
git add docs/api/errors.md
git commit -m "$(cat <<'EOF'
docs(tra-467): note 401 title varies, match on type (F7)

Four 401 causes (missing header, invalid token, expired, revoked)
produce four different title strings. type: unauthorized is stable.
Clients should branch on type, not title.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Changelog entry

**Files:**

- Modify: `docs/api/CHANGELOG.md`

One entry under `Unreleased → Changed`.

- [ ] **Step 1: Read the current Unreleased section**

Run: `head -40 docs/api/CHANGELOG.md`
Expected: shows an `## Unreleased` heading followed by one or more subsections (`### Added`, `### Changed`, `### Fixed`, …).

- [ ] **Step 2: Add a `### Changed` subsection (or append to the existing one)**

If `### Changed` already exists under `## Unreleased`, append the four bullets below to it. Otherwise insert a new `### Changed` subsection (after `### Added` if present; otherwise immediately under `## Unreleased`):

```markdown
### Changed

- API quickstart and Getting-started → API pages now auto-detect environment from the docs hostname (`docs.trakrf.id` → production app, `docs.preview.trakrf.id` → preview app), with a switcher for cross-environment readers ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F4).
- Added a multi-organization warning on the API-key minting steps: keys are scoped to whichever org is selected in the avatar menu at creation time ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F5).
- Added a UI-form-to-scope-string mapping table on Authentication → Scopes ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F6).
- Errors → Envelope clarified that `title` is descriptive and varies; clients should match on `type` ([TRA-467](https://linear.app/trakrf/issue/TRA-467) — F7).
```

- [ ] **Step 3: Verify build**

Run: `pnpm build`
Expected: build completes; no broken-link errors. (The Linear URLs are external and not checked by `onBrokenLinks`.)

- [ ] **Step 4: Commit**

```bash
git add docs/api/CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs(tra-467): changelog entries for API docs fixes

Four Unreleased → Changed bullets covering F4 env auto-detect, F5
multi-org warning, F6 UI-to-scope mapping, F7 401 title variance.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Blackbox harness enhancement (piggyback commit)

**Files:**

- Modify: `tests/blackbox/BB.md`

The BB.md enhancement lives as an **uncommitted modification in the main working tree** at `/home/mike/trakrf-docs/tests/blackbox/BB.md` (the user's other checkout). Worktrees have independent working trees, so this diff is NOT visible from inside `.worktrees/tra-467`. We bring the content in by copying the file, then commit it here.

- [ ] **Step 1: Verify the uncommitted change exists in the main checkout**

Run: `git -C /home/mike/trakrf-docs status --porcelain tests/blackbox/BB.md`
Expected: ` M tests/blackbox/BB.md` (a single line showing the file is modified).

If the output is empty, the change was already committed somewhere on main — skip to Task 10 and flag the skip to the user.

- [ ] **Step 2: Inspect the diff to confirm it matches the pre-existing enhancement**

Run: `git -C /home/mike/trakrf-docs diff tests/blackbox/BB.md`
Expected: a diff adding a `## OpenAPI spec contract check` section with four numbered steps (Fetch spec / Walk every path / CRUD lifecycle / Pagination boundaries), and modifying the `## Report findings` paragraph to reference `FINDINGS.md` and "spec contract mismatches in their own section." No other edits.

If you see anything unrelated, stop and flag it — this task only ships the pre-existing enhancement.

- [ ] **Step 3: Copy the modified file into the worktree**

Run: `cp /home/mike/trakrf-docs/tests/blackbox/BB.md tests/blackbox/BB.md`
Expected: no output; `git status` in the worktree now shows `modified: tests/blackbox/BB.md`.

The main working tree is not modified by this copy — the user's uncommitted version there is untouched and will reconcile automatically once this branch merges to `main` (at that point, `git status` in `/home/mike/trakrf-docs` will go clean without any further action).

- [ ] **Step 4: Commit the file on this branch**

```bash
git add tests/blackbox/BB.md
git commit -m "$(cat <<'EOF'
test(tra-467): document OpenAPI contract-check pass in blackbox harness

Add a mandatory spec-walk pass to BB.md (fetch spec, walk paths, CRUD
lifecycle, pagination boundaries) and retarget findings to FINDINGS.md
with a separate section for spec-contract mismatches. Surfaced
alongside the 2026-04-23 eval; piggybacking onto the TRA-467 branch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Confirm branch is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`.

---

### Task 10: Dev-server visual inspection

**Files:** none modified.

Nothing ships without this step. The F4 flow is the most failure-prone (hydration + localStorage + dropdown) — exercise it live.

- [ ] **Step 1: Start the dev server**

Run: `pnpm dev`
Expected: dev server starts on `http://localhost:3000`.

- [ ] **Step 2: Open `/docs/api/quickstart`**

Visit `http://localhost:3000/docs/api/quickstart`. Verify:

- Step 1 reads "Pick your environment" and shows "You're reading production docs" (localhost falls back to production).
- The `<EnvBaseURL />` span inside the prose renders `https://app.trakrf.id`.
- The `<EnvBaseURLBlock />` renders a single shell block: `export BASE_URL=https://app.trakrf.id`.
- The `<EnvSwitcher />` pill shows "Environment: production" and a select with `Auto-detect / Production / Preview`.
- Step 2 "Sign in with an admin account on the production app" — the link points to `https://app.trakrf.id`.

- [ ] **Step 3: Toggle the switcher**

In the `<EnvSwitcher />` dropdown, pick **Preview**. Verify (without reloading):

- The switcher label updates to "Environment: preview".
- The `<EnvBaseURL />`, `<EnvBaseURLBlock />`, and `<EnvSignInLink />` on the page all update in sync to the preview host.
- `localStorage.trakrf-env` is `"preview"` (check DevTools Application → Local Storage).

- [ ] **Step 4: Reload with override persisted**

Reload the page. Verify the switcher still shows "preview" and all components still render preview values.

- [ ] **Step 5: Clear override**

Pick **Auto-detect** in the switcher. Verify:

- Label flips back to "Environment: production".
- All components revert to prod values.
- `localStorage.trakrf-env` is removed.

- [ ] **Step 6: Confirm the multi-org warning is visible**

On the same page, confirm step 3 of the "Mint an API key" section reads the multi-org warning sentence from Task 5.

- [ ] **Step 7: Open `/docs/getting-started/api` and repeat the spot-checks**

Verify:

- "What you'll need" list mentions "If you were given preview credentials, you already have one".
- Step 1 "Pick your environment" with switcher works identically.
- Signup link in "What you'll need" still points to `https://app.trakrf.id` regardless of switcher state.

- [ ] **Step 8: Open `/docs/api/authentication`**

Verify:

- New `### UI labels vs scope strings` subsection appears before the scopes table.
- Scopes table itself is unchanged (the TRA-466-added `keys:admin` row still present).
- `## Mint your first API key` shows the multi-org warning as a new step.

- [ ] **Step 9: Open `/docs/api/errors`**

Verify:

- `type` row of the envelope-shape table mentions "not on `title`".
- `title` row mentions "may vary between instances of the same `type`".
- `unauthorized` row in the catalog ends with "match on `type`".

- [ ] **Step 10: Open `/docs/api/changelog`**

Verify the four new bullets appear under `Unreleased → Changed` and all four TRA-467 anchor links resolve to the Linear issue URL.

- [ ] **Step 11: Stop the dev server**

`Ctrl+C` in the dev-server terminal. No commit — visual inspection only.

If any step fails, fix the underlying issue in the relevant task's files, re-run `pnpm build`, and repeat the check that failed.

---

### Task 11: Push branch and open the PR

**Files:** none modified locally; opens a PR on GitHub.

- [ ] **Step 1: Confirm all commits are on the branch**

Run: `git log --oneline main..HEAD`
Expected: ten commits in this order (newest first):

```
<hash> test(tra-467): document OpenAPI contract-check pass in blackbox harness
<hash> docs(tra-467): changelog entries for API docs fixes
<hash> docs(tra-467): note 401 title varies, match on type (F7)
<hash> docs(tra-467): document UI form → scope string mapping (F6)
<hash> docs(tra-467): note multi-org key scoping gotcha (F5)
<hash> docs(tra-467): auto-detect env on getting-started API page (F4)
<hash> docs(tra-467): auto-detect env on API quickstart (F4)
<hash> feat(tra-467): add env-aware MDX helper components
<hash> feat(tra-467): add useDeployEnv hook for env-aware docs components
<hash> docs(tra-467): design spec for API docs fixes (F4-F7 + BB.md harness bump)
```

(Spec commit + nine implementation commits = ten total on the branch.)

- [ ] **Step 2: Confirm tree is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`; branch is not yet tracking a remote.

- [ ] **Step 3: Push the branch**

Run: `git push -u origin miks2u/tra-467-api-docs-fixes`
Expected: push succeeds.

- [ ] **Step 4: Open the PR**

Run:

```bash
gh pr create --title "docs(tra-467): API docs fixes — env auto-detect, multi-org warning, scope labels, 401 title variance" --body "$(cat <<'EOF'
## Summary

Ships findings F4–F7 from the 2026-04-23 black-box evaluation.

- **F4 — env auto-detection** on `docs/api/quickstart.mdx` and `docs/getting-started/api.mdx`. The docs site resolves env from its own hostname (`docs.trakrf.id` → production app, `docs.preview.trakrf.id` → preview app), with an in-page switcher for cross-environment readers. One new hook (`useDeployEnv`) and five small components.
- **F5 — multi-org warning** on the three places that walk a reader through minting a key. API keys carry whichever org is selected in the avatar menu at creation time; admins of multiple orgs now get a warning to check the switcher first.
- **F6 — UI-to-scope mapping** on `docs/api/authentication.md`. The **New key** form uses resource × level labels; docs and API responses use scope strings. Mapping table added before the existing scopes table.
- **F7 — 401 `title` variance** on `docs/api/errors.md`. Four 401 causes produce four different titles; `type: unauthorized` is stable. Envelope-shape and catalog rows updated so integrators branch on `type`.
- **Piggyback** — the pre-existing `tests/blackbox/BB.md` enhancement (OpenAPI contract-check pass) ships as its own commit on this branch.

Design spec: `spec/superpowers/specs/2026-04-23-tra-467-api-docs-fixes-design.md`
Plan: `spec/superpowers/plans/2026-04-23-tra-467-api-docs-fixes.md`

## Test plan

- [ ] `pnpm typecheck` passes.
- [ ] `pnpm build` passes (broken-link check enforces cross-page anchors).
- [ ] `pnpm dev` — `/docs/api/quickstart` step 1 reads "Pick your environment", switcher updates BASE_URL block and sign-in link in sync, override persists across reload.
- [ ] `pnpm dev` — `/docs/getting-started/api` same switcher behavior; "What you'll need" mentions preview credentials; signup link still points to production.
- [ ] `pnpm dev` — `/docs/api/authentication` shows the new "UI labels vs scope strings" subsection and the multi-org warning as a step in "Mint your first API key".
- [ ] `pnpm dev` — `/docs/api/errors` envelope `type`/`title` rows and `unauthorized` catalog row mention title variance / "match on `type`".
- [ ] `pnpm dev` — `/docs/api/changelog` has four TRA-467 bullets under `Unreleased → Changed`.
- [ ] Preview deploy at `docs.preview.trakrf.id` renders the env defaults as "preview" on a hard reload (no cached localStorage).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL is returned. Report the URL back to the user.

- [ ] **No commit** — branch push and PR are the deliverables.

---

## Notes

- **No squash merge** (per `CLAUDE.md`). Each task's commit preserves the rationale for its finding.
- **Do not push to `main`** (per `CLAUDE.md`).
- **The spec commit (`af7315d`) stays on the branch** — it's the design-of-record and ships with the PR.
- **Hydration flicker** on `docs.preview.trakrf.id`: the initial server render uses the production default, then hydrates to preview once `useSyncExternalStore` reads the live hostname. One frame; acceptable for a docs page. If a future test surfaces that the flicker is bad enough to fix, the follow-up is to add a build-time env var overriding the server snapshot — not worth doing pre-emptively.
- **localhost dev** defaults to production, not preview. There is no way to detect "I'm on a dev build targeting preview" from the hostname alone; if you need to exercise preview rendering locally, use the switcher (which persists via localStorage).
