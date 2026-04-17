# App Tour Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the App Tour docs section (9 tabs × 2 viewports), build a re-runnable screenshot refresh script, and produce a first-pass authored tour of `app.preview.trakrf.id`.

**Architecture:** Two-track workflow. Track 1 (authoring): Claude Code drives Playwright MCP through the live preview app, captures PNG screenshots, and writes per-tab prose. Track 2 (refresh): a bash script using `uvx rodney` re-captures the 18 PNGs deterministically without touching prose. Supported by one React component (`AppTourGrid`), one markdown runbook, one `.env.example`, a sidebar entry, and README changes.

**Tech Stack:** Docusaurus 3.9 + React 19 + TypeScript (existing), bash + `uvx rodney` (screenshot refresh), Playwright MCP (authoring pass only), `pnpm` package manager.

**Spec:** [`spec/superpowers/specs/2026-04-17-app-tour-generation-design.md`](../specs/2026-04-17-app-tour-generation-design.md)

**Note on TDD:** This is a docs-site feature — no business logic and one tiny presentational React component. The "test" is `pnpm build` (catches MDX errors, broken links, missing images, type errors) and a live `pnpm dev` check. Unit tests for `AppTourGrid` would gain nothing beyond what the Docusaurus build already validates. Verification steps below lean on build + dev-server instead of unit tests.

---

## Task 1: Create feature branch

**Files:** none (git-only).

- [ ] **Step 1: Confirm clean working tree**

Run: `git status`
Expected: `nothing to commit, working tree clean` on branch `cleanup/merged` or `main`.

- [ ] **Step 2: Update main and branch off it**

```bash
git checkout main
git pull origin main
git checkout -b feature/tra-347-app-tour
```

- [ ] **Step 3: Verify branch**

Run: `git branch --show-current`
Expected output: `feature/tra-347-app-tour`

- [ ] **Step 4: Commit the design + plan docs as the first commit on the branch**

The spec and plan were written on the prior branch before this one existed. Move them into the feature branch cleanly:

```bash
git add spec/superpowers/specs/2026-04-17-app-tour-generation-design.md
git add spec/superpowers/plans/2026-04-17-app-tour-generation.md
git commit -m "docs: add app-tour generation spec and plan"
```

If `git status` shows these files already on the branch (they were untracked and carried over), just run the commit above.

---

## Task 2: Add `.env.example`

**Files:**
- Create: `.env.example`

- [ ] **Step 1: Create `.env.example`**

Write file `/.env.example`:

```
# Preview app URL for docs generation. Override if using a different environment.
TRAKRF_PREVIEW_URL=https://app.preview.trakrf.id

# Credentials for the docs-tour user. Leave blank on first run;
# the authoring pass will create the account via signup and fill these in.
TRAKRF_DOCS_USER_EMAIL=
TRAKRF_DOCS_USER_PASSWORD=
```

- [ ] **Step 2: Verify `.env` is already gitignored**

Run: `git check-ignore -v .env`
Expected: prints `.gitignore:XX:.env .env` (confirming match). If no match: STOP and add `.env` to `.gitignore`.

- [ ] **Step 3: Commit**

```bash
git add .env.example
git commit -m "chore: add .env.example for app-tour docs generation"
```

---

## Task 3: Create `AppTourGrid` React component

**Files:**
- Create: `src/components/AppTourGrid.tsx`
- Create: `src/components/AppTourGrid.module.css`

- [ ] **Step 1: Create `src/components/AppTourGrid.tsx`**

```tsx
import type { ReactNode } from "react";
import Link from "@docusaurus/Link";
import styles from "./AppTourGrid.module.css";

interface TourEntry {
  id: string;
  title: string;
  description: string;
}

const ENTRIES: TourEntry[] = [
  {
    id: "home",
    title: "Home",
    description: "Main dashboard with quick access to all features.",
  },
  {
    id: "inventory",
    title: "Inventory",
    description: "View scanned items and check what's missing from a list.",
  },
  {
    id: "locate",
    title: "Locate",
    description: "Find a specific item by walking the area with a handheld reader.",
  },
  {
    id: "barcode",
    title: "Barcode",
    description: "Use a phone camera to scan regular barcodes.",
  },
  {
    id: "assets",
    title: "Assets",
    description: "Create, view, and track asset records.",
  },
  {
    id: "locations",
    title: "Locations",
    description: "Create and organize the places where assets live.",
  },
  {
    id: "reports",
    title: "Reports",
    description: "View asset location reports and movement history.",
  },
  {
    id: "settings",
    title: "Settings",
    description: "Configure device and application settings.",
  },
  {
    id: "help",
    title: "Help",
    description: "Quick answers to common questions.",
  },
];

export default function AppTourGrid(): ReactNode {
  return (
    <div className={styles.grid}>
      {ENTRIES.map((entry) => (
        <Link
          key={entry.id}
          to={`/docs/app-tour/${entry.id}`}
          className={styles.card}
        >
          <img
            src={`/img/app-tour/${entry.id}-desktop.png`}
            alt={`${entry.title} screenshot`}
            className={styles.thumbnail}
          />
          <div className={styles.body}>
            <h3 className={styles.title}>{entry.title}</h3>
            <p className={styles.description}>{entry.description}</p>
          </div>
        </Link>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Create `src/components/AppTourGrid.module.css`**

```css
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1.25rem;
  margin: 2rem 0;
}

.card {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--ifm-color-emphasis-200);
  border-radius: 8px;
  overflow: hidden;
  text-decoration: none;
  color: inherit;
  transition:
    transform 120ms ease,
    box-shadow 120ms ease;
  background: var(--ifm-background-surface-color);
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.08);
  text-decoration: none;
  color: inherit;
}

.thumbnail {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 10;
  object-fit: cover;
  background: var(--ifm-color-emphasis-100);
}

.body {
  padding: 0.75rem 1rem 1rem;
}

.title {
  margin: 0 0 0.25rem;
  font-size: 1.05rem;
}

.description {
  margin: 0;
  font-size: 0.9rem;
  color: var(--ifm-color-emphasis-700);
}
```

- [ ] **Step 3: Typecheck passes**

Run: `pnpm typecheck`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/components/AppTourGrid.tsx src/components/AppTourGrid.module.css
git commit -m "feat: add AppTourGrid component for app-tour site-map"
```

---

## Task 4: Create placeholder images so build succeeds

**Files:**
- Create: `static/img/app-tour/<tab>-desktop.png` × 9
- Create: `static/img/app-tour/<tab>-mobile.png` × 9

**Why now:** The component references 9 image paths. Without placeholders, `pnpm build` would fail on broken image references once we add the pages. Placeholders get replaced in Task 9.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p static/img/app-tour
```

- [ ] **Step 2: Generate 18 placeholder PNGs**

Use an existing asset as the placeholder (any small PNG already in the repo works; avoid pulling in new deps).

```bash
for tab in home inventory locate barcode assets locations reports settings help; do
  cp static/img/logo.png "static/img/app-tour/${tab}-desktop.png"
  cp static/img/logo.png "static/img/app-tour/${tab}-mobile.png"
done
ls static/img/app-tour/
```

Expected: 18 files listed, one per `<tab>-desktop.png` / `<tab>-mobile.png` combination.

- [ ] **Step 3: Commit**

```bash
git add static/img/app-tour/
git commit -m "chore: seed placeholder app-tour images"
```

---

## Task 5: Create placeholder per-tab markdown files

**Files:**
- Create: `docs/app-tour/home.md`, `inventory.md`, `locate.md`, `barcode.md`, `assets.md`, `locations.md`, `reports.md`, `settings.md`, `help.md`

**Why placeholders first:** The sidebar (Task 7) will reference these 9 doc IDs. Creating skeletons now lets the build validate cross-references before any prose is written.

- [ ] **Step 1: Create the directory**

```bash
mkdir -p docs/app-tour
```

- [ ] **Step 2: Write each per-tab skeleton**

For `docs/app-tour/home.md`, `sidebar_position: 1`, `title: Home`, and description/prose placeholders. Repeat this exact structure for each tab with its own `sidebar_position`, `title`, and `id` — do NOT use a loop here, the files need to be in the repo so build validates them.

File: `docs/app-tour/home.md`

```md
---
sidebar_position: 1
title: Home
description: Main dashboard with quick access to all features.
---

# Home

## Desktop

![Home desktop screenshot](/img/app-tour/home-desktop.png)

## Mobile

![Home mobile screenshot](/img/app-tour/home-mobile.png)

## What this page does

_Pending authoring pass._

## How it fits in the app

_Pending authoring pass._

:::note
This page was generated as a first-pass tour. Human enhancement welcome.
:::
```

Repeat for the remaining 8 tabs, substituting the values from this table:

| file | sidebar_position | title | description |
|---|---|---|---|
| `home.md` | 1 | Home | Main dashboard with quick access to all features. |
| `inventory.md` | 2 | Inventory | View scanned items and check what's missing from a list. |
| `locate.md` | 3 | Locate | Find a specific item by walking the area with a handheld reader. |
| `barcode.md` | 4 | Barcode | Use a phone camera to scan regular barcodes. |
| `assets.md` | 5 | Assets | Create, view, and track asset records. |
| `locations.md` | 6 | Locations | Create and organize the places where assets live. |
| `reports.md` | 7 | Reports | View asset location reports and movement history. |
| `settings.md` | 8 | Settings | Configure device and application settings. |
| `help.md` | 9 | Help | Quick answers to common questions. |

Image references inside each file use the file's own base name, e.g. `inventory.md` references `/img/app-tour/inventory-desktop.png` and `/img/app-tour/inventory-mobile.png`. The `# H1` matches the `title` frontmatter value.

- [ ] **Step 3: Commit**

```bash
git add docs/app-tour/
git commit -m "feat: add app-tour per-tab skeleton pages"
```

---

## Task 6: Create site-map `docs/app-tour/index.md`

**Files:**
- Create: `docs/app-tour/index.md`

- [ ] **Step 1: Write `docs/app-tour/index.md`**

```md
---
sidebar_position: 0
title: App Tour
description: Visual walk-through of every screen in the TrakRF web app.
---

import AppTourGrid from "@site/src/components/AppTourGrid";

# App Tour

A visual walk-through of every screen in the TrakRF web app. Click any card for a closer look at that screen.

<AppTourGrid />
```

- [ ] **Step 2: Commit**

```bash
git add docs/app-tour/index.md
git commit -m "feat: add app-tour site-map index page"
```

---

## Task 7: Wire App Tour into sidebar and navbar

**Files:**
- Modify: `sidebars.ts`
- Modify: `docusaurus.config.ts`

- [ ] **Step 1: Add App Tour sidebar**

Replace `sidebars.ts` contents with:

```ts
import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  userGuideSidebar: [
    "getting-started",
    {
      type: "category",
      label: "User Guide",
      items: [
        "user-guide/reader-setup",
        "user-guide/asset-management",
        "user-guide/location-tracking",
        "user-guide/reports-exports",
        "user-guide/organization-management",
      ],
    },
  ],
  appTourSidebar: [
    "app-tour/index",
    "app-tour/home",
    "app-tour/inventory",
    "app-tour/locate",
    "app-tour/barcode",
    "app-tour/assets",
    "app-tour/locations",
    "app-tour/reports",
    "app-tour/settings",
    "app-tour/help",
  ],
  apiSidebar: [
    {
      type: "category",
      label: "API Documentation",
      items: [
        "api/authentication",
        "api/rest-api-reference",
        "api/webhooks",
        "api/rate-limits",
        "api/error-codes",
      ],
    },
  ],
  integrationsSidebar: [
    {
      type: "category",
      label: "Integration Guides",
      items: [
        "integrations/mqtt-message-format",
        "integrations/fixed-reader-setup",
      ],
    },
  ],
};

export default sidebars;
```

- [ ] **Step 2: Add App Tour to navbar**

In `docusaurus.config.ts`, within `themeConfig.navbar.items`, insert the App Tour entry between User Guide and API:

```ts
{
  type: "docSidebar",
  sidebarId: "appTourSidebar",
  position: "left",
  label: "App Tour",
},
```

The full `items` array after the change reads: User Guide, App Tour, API, Integrations, GitHub.

- [ ] **Step 3: Verify build passes end-to-end**

Run: `pnpm build`
Expected: `[SUCCESS] Generated static files in "build"`. No warnings about broken links or missing images. If the build surfaces unresolved `@site/src/components/AppTourGrid` or image errors, those are bugs in Tasks 3, 4, 5, or 6 — fix there, not here.

- [ ] **Step 4: Commit**

```bash
git add sidebars.ts docusaurus.config.ts
git commit -m "feat: add App Tour sidebar and navbar entry"
```

---

## Task 8: Create `scripts/refresh-screenshots.sh`

**Files:**
- Create: `scripts/refresh-screenshots.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Refresh all app-tour screenshots by driving Rodney against the preview app.
# Prose in docs/app-tour/*.md is untouched. See docs/app-tour/AUTHORING.md for the full workflow.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in credentials (or run the authoring pass first)." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

: "${TRAKRF_PREVIEW_URL:?TRAKRF_PREVIEW_URL missing from .env}"
: "${TRAKRF_DOCS_USER_EMAIL:?TRAKRF_DOCS_USER_EMAIL missing from .env}"
: "${TRAKRF_DOCS_USER_PASSWORD:?TRAKRF_DOCS_USER_PASSWORD missing from .env}"

TABS=(home inventory locate barcode assets locations reports settings help)
OUT_DIR="static/img/app-tour"
mkdir -p "$OUT_DIR"

cleanup() {
  uvx rodney stop >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo ">> starting rodney (headless)"
uvx rodney start

echo ">> logging in"
uvx rodney open "$TRAKRF_PREVIEW_URL"
uvx rodney waitload
uvx rodney wait "input[type=email], input[name=email]"
uvx rodney input "input[type=email], input[name=email]" "$TRAKRF_DOCS_USER_EMAIL"
uvx rodney input "input[type=password], input[name=password]" "$TRAKRF_DOCS_USER_PASSWORD"
uvx rodney click "button[type=submit]"
uvx rodney wait "nav, [data-testid=menu-item-home]"

for tab in "${TABS[@]}"; do
  echo ">> capturing $tab"
  uvx rodney open "${TRAKRF_PREVIEW_URL}/#${tab}"
  uvx rodney waitstable
  uvx rodney screenshot -w 1440 -h 900 "${OUT_DIR}/${tab}-desktop.png"
  uvx rodney screenshot -w 390 -h 844 "${OUT_DIR}/${tab}-mobile.png"
done

echo ">> done. 18 screenshots refreshed in ${OUT_DIR}/"
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x scripts/refresh-screenshots.sh
```

- [ ] **Step 3: Verify shell syntax**

Run: `bash -n scripts/refresh-screenshots.sh`
Expected: exit code 0, no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/refresh-screenshots.sh
git commit -m "feat: add refresh-screenshots.sh for app-tour image regen"
```

**Note:** End-to-end verification of this script happens in Task 9 below, as part of the authoring pass. The login-selector heuristics (`input[type=email]`, `button[type=submit]`) may need adjustment once the real login form is inspected — that refinement happens in Task 9 Step 2.

---

## Task 9: Execute the first-pass authoring run

**Files:**
- Modify: `.env` (local only — NEVER commit)
- Modify: `static/img/app-tour/*.png` (all 18 real screenshots)
- Modify: `docs/app-tour/home.md`, `inventory.md`, `locate.md`, `barcode.md`, `assets.md`, `locations.md`, `reports.md`, `settings.md`, `help.md` (fill in prose)
- Modify: `scripts/refresh-screenshots.sh` (adjust selectors if discovered during auth)

This task is manual/agent-driven. The executor navigates the live preview app via Playwright MCP and produces real content. Each step is self-contained.

- [ ] **Step 1: Prepare `.env`**

```bash
cp .env.example .env
```

Edit `.env` locally. If this is a brand-new docs user, generate:

```
TRAKRF_DOCS_USER_EMAIL=docs-tour-<YYYYMMDD>@example.com
TRAKRF_DOCS_USER_PASSWORD=<long random string>
```

Leave blank if you intend the signup flow to create and capture these.

- [ ] **Step 2: Sign up (first-time) via Playwright MCP**

Using the Playwright MCP browser tools:

1. `browser_navigate` to `TRAKRF_PREVIEW_URL`.
2. Follow the signup link on the login page (click "Sign up" or equivalent).
3. Use `browser_fill_form` to submit `TRAKRF_DOCS_USER_EMAIL` + `TRAKRF_DOCS_USER_PASSWORD`. If the form needs a name/org, fill plausible values (e.g., "TrakRF Docs Tour", "Docs Demo Org").
4. Complete any post-signup steps required to land on the main app (dismiss welcome modal, skip onboarding wizard, etc.).
5. If the email field on login/signup turns out NOT to match `input[type=email], input[name=email]`, or the submit button NOT `button[type=submit]`, update `scripts/refresh-screenshots.sh` in this same task to match the real selectors.
6. Once authenticated and the tab navigation is visible, write the final credentials back into `.env` locally.

- [ ] **Step 3: Capture real screenshots for all 18 files**

For each of the 9 tabs, in nav order (`home, inventory, locate, barcode, assets, locations, reports, settings, help`):

1. `browser_resize` to 1440×900.
2. `browser_navigate` to `${TRAKRF_PREVIEW_URL}/#${tab}`.
3. `browser_wait_for` until network is idle or a tab-specific element is visible (`[data-testid=menu-item-${tab}]` is a known anchor).
4. `browser_take_screenshot` → save to `static/img/app-tour/${tab}-desktop.png`, overwriting the placeholder.
5. `browser_resize` to 390×844.
6. `browser_navigate` to the same URL (forces a responsive remount).
7. Wait again.
8. `browser_take_screenshot` → `static/img/app-tour/${tab}-mobile.png`.

After all 9 tabs, verify:

```bash
ls -la static/img/app-tour/
```

Expected: 18 PNGs, none ~0 bytes.

- [ ] **Step 4: Observe each tab and write prose**

For each of the 9 `docs/app-tour/<tab>.md` files, replace both `_Pending authoring pass._` placeholders with real content:

- "What this page does": 2–4 sentences. Concrete — list the visible controls, empty-state copy, and what a user can do on this screen. No hedging; if the page shows "No assets yet", say that's the empty state.
- "How it fits in the app": 1–2 sentences. Connect this tab to adjacent tabs or a typical workflow (e.g., "Locate complements Inventory: find Inventory tells you what's there; Locate narrows in on a single item.").

Grounding sources:
- The live page itself (primary).
- `platform/frontend/src/components/TabNavigation.tsx` tooltips — useful one-liners but tend to be terse; expand.
- Adjacent components in `platform/frontend/src/components/` — e.g., `AssetsScreen.tsx`, `ReportsScreen.tsx` — scan for visible features but do not copy implementation details into docs.

Do NOT update the frontmatter `description` — those are already correct from the skeleton.

- [ ] **Step 5: Verify the screenshot-refresh script works end-to-end**

This is the acceptance test for Task 8 and for Task 9 Step 2's selector updates.

```bash
bash scripts/refresh-screenshots.sh
```

Expected: script exits 0, prints `>> done. 18 screenshots refreshed`, and `git diff --stat static/img/app-tour/` shows most PNGs unchanged-ish (Rodney's output may differ slightly from Playwright MCP's, which is fine; the point is successful capture, not byte-identical output).

If the script fails at login or navigation, debug and correct `scripts/refresh-screenshots.sh`. Re-run until clean.

- [ ] **Step 6: Build verification**

```bash
pnpm build
```

Expected: build succeeds with no broken-link or missing-image errors. Open `build/docs/app-tour/` in a browser (or via `pnpm serve`) to eyeball the site-map grid and a couple of detail pages.

- [ ] **Step 7: Dev-server spot-check**

```bash
pnpm dev
```

In a browser at `http://localhost:3000`:
- Visit `/docs/app-tour` — site-map grid shows 9 cards with real thumbnails.
- Click through to 2–3 tabs — verify desktop + mobile images render, prose is present, no `_Pending authoring pass._` leftovers.
- Check the navbar — "App Tour" link is visible.

Stop the dev server once verified.

- [ ] **Step 8: Confirm `.env` is NOT staged**

```bash
git status
```

Expected: `.env` does not appear in the changelist. If it does, STOP — the gitignore rule didn't match; investigate before proceeding.

- [ ] **Step 9: Commit in two logical chunks**

```bash
git add static/img/app-tour/
git commit -m "feat: capture real app-tour screenshots (desktop + mobile)"

git add docs/app-tour/ scripts/refresh-screenshots.sh
git commit -m "feat: write first-pass app-tour prose for all 9 tabs"
```

---

## Task 10: Write `docs/app-tour/AUTHORING.md` runbook

**Files:**
- Create: `docs/app-tour/AUTHORING.md`

**Why now (after the authoring pass):** Writing the runbook after having done the work once means the instructions reflect what actually happened, including selector quirks or signup-flow gotchas discovered in Task 9.

- [ ] **Step 1: Write `docs/app-tour/AUTHORING.md`**

```md
---
sidebar_position: 99
title: Authoring the App Tour
description: How to regenerate or refresh the App Tour docs section.
---

# Authoring the App Tour

This page explains how the App Tour was generated and how to regenerate or refresh it.

## Two workflows

**Full regenerate** — prose + images. One-shot, agent-driven. Use after significant UI redesigns when the old prose no longer describes what's on screen.

**Refresh screenshots only** — images only. Deterministic, bash-driven. Use after routine UI tweaks when the old prose is still accurate.

## Prerequisites

- `pnpm install` completed in the repo root.
- `uvx` available (for the refresh script).
- Chromium available (Playwright MCP for agent authoring; Rodney's own Chrome for the refresh script).
- `.env` present. Start by copying `.env.example`:

  ```bash
  cp .env.example .env
  ```

  If `TRAKRF_DOCS_USER_EMAIL` / `TRAKRF_DOCS_USER_PASSWORD` are blank, the agent-driven authoring pass will create a new account on the preview app and write the creds back into `.env`.

## Refresh screenshots only

```bash
bash scripts/refresh-screenshots.sh
```

That's the whole workflow. The script logs in, navigates to each of the 9 tabs, captures desktop (1440×900) and mobile (390×844) PNGs into `static/img/app-tour/`, and exits. Prose in `docs/app-tour/*.md` is not touched. Commit the image diff as `feat: refresh app-tour screenshots`.

If login selectors change upstream (the script uses `input[type=email]`, `input[type=password]`, `button[type=submit]` against `app.preview.trakrf.id`), update those in `scripts/refresh-screenshots.sh` and re-run.

## Full regenerate (agent-driven)

Ask Claude Code (or any agent with Playwright MCP) to follow this recipe:

1. Ensure `.env` exists and contains `TRAKRF_PREVIEW_URL`. Credentials may be blank on first run.
2. If credentials are blank: sign up a new docs-tour account via the preview app's signup form. Generate a unique email (`docs-tour-<date>@example.com`) and a random password. Persist both into `.env`.
3. For each of the 9 tabs, in nav order — `home, inventory, locate, barcode, assets, locations, reports, settings, help`:
   - Resize the browser to 1440×900.
   - Navigate to `${TRAKRF_PREVIEW_URL}/#<tab>`.
   - Wait for the page to stabilize (network idle, or `[data-testid=menu-item-<tab>]` visible).
   - Take a screenshot into `static/img/app-tour/<tab>-desktop.png`.
   - Resize to 390×844, navigate again to force responsive remount, wait, screenshot into `<tab>-mobile.png`.
   - Observe the page. Write 2–4 sentences into the "What this page does" section of `docs/app-tour/<tab>.md`. List concrete controls, empty-state copy, and any visible device-status indicators.
   - Write 1–2 sentences into the "How it fits in the app" section connecting this tab to adjacent tabs or a workflow.
4. Run `pnpm build` to verify. Then `pnpm dev` and eyeball the site-map + a few detail pages.
5. Commit images and prose separately for a clean history.

## Things to know

- **Empty-state honesty.** A fresh docs user owns no assets/locations/reports, so those tabs show "no data yet" UIs. A browser without a connected RFID reader shows "connect a device" states on Inventory / Locate / Barcode. Both are informative and match the new-user experience. If TRA-329 wants populated screenshots later, open a follow-up and seed the account before the capture.
- **Mobile viewport caveat.** Rodney's `screenshot -w -h` resizes the viewport before each capture; if the app's layout depends on viewport size at mount time, the mobile shot may be a scaled desktop. If that happens, the fix is in `scripts/refresh-screenshots.sh`: either re-navigate after resize (the agent authoring recipe already does this) or drive viewport emulation via Rodney's JS bridge.
- **Credentials are local.** `.env` is gitignored. Never commit it. Never paste credentials into commit messages or PR descriptions.
- **Showboat is not used.** The original TRA-347 scope mentioned Showboat alongside Rodney. In practice, Showboat's `exec`/`verify` model targets executable docs, not screenshot tours — so this tooling uses Rodney for refresh and Playwright MCP (via Claude Code) for authoring, skipping Showboat entirely.
```

- [ ] **Step 2: Build verification**

```bash
pnpm build
```

Expected: build includes `/docs/app-tour/authoring` in the output with no errors.

- [ ] **Step 3: Commit**

```bash
git add docs/app-tour/AUTHORING.md
git commit -m "docs: add app-tour authoring runbook"
```

---

## Task 11: Update `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append an App Tour section**

Open `README.md` and, after the "Serve" section (currently ending at line 40) and before the "Contributing" section, insert:

```md
## App Tour Docs

The `docs/app-tour/` section contains a visual walk-through of every screen in the TrakRF web app, auto-generated from `app.preview.trakrf.id`.

**Refresh screenshots only:**

```bash
bash scripts/refresh-screenshots.sh
```

Requires `.env` with `TRAKRF_PREVIEW_URL` and docs-tour credentials (copy from `.env.example`).

**Full regeneration** (prose + images): see [`docs/app-tour/AUTHORING.md`](docs/app-tour/AUTHORING.md).
```

- [ ] **Step 2: Lint passes**

Run: `pnpm lint`
Expected: no errors. If Prettier flags formatting, run `pnpm lint:fix` and re-stage.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document app-tour regeneration in README"
```

---

## Task 12: Final verification and PR

**Files:** none.

- [ ] **Step 1: Full local verification**

Run these three commands in order; each must succeed:

```bash
pnpm lint
pnpm typecheck
pnpm build
```

- [ ] **Step 2: Push the branch**

```bash
git push -u origin feature/tra-347-app-tour
```

- [ ] **Step 3: Open a PR**

Use `gh pr create`. PR title: `feat: app-tour docs generation (TRA-347)`. PR body should cover:

- What shipped (app-tour section, 9 pages, refresh script, authoring runbook).
- Scope change from the ticket: Showboat dropped in favor of the simpler Rodney-refresh + agent-authoring split. Brief reasoning (Showboat's `verify`/`exec` model doesn't fit screenshot tours).
- Link to `spec/superpowers/specs/2026-04-17-app-tour-generation-design.md` and this plan.
- Test plan: reviewer pulls the branch, runs `pnpm dev`, visits `/docs/app-tour`, clicks a couple of cards.

- [ ] **Step 4: Stop**

Do not merge. CLAUDE.md: "NEVER merge without explicit confirmation."

---

## Self-review checklist (for the writer, not the executor)

Every section of the spec has a matching task:

- Repo layout → Tasks 3, 4, 5, 6, 8
- Per-page template → Task 5 (skeleton) + Task 9 (prose fill-in)
- Site-map → Task 6 + component in Task 3
- Authoring runbook → Task 10
- Refresh script → Task 8 (write) + Task 9 Step 5 (verify)
- Viewports → Tasks 4, 5, 8, 9
- Empty-state / no-device state → Task 9 Step 4 prose guidance + AUTHORING.md "Things to know"
- .env / config → Task 2
- README → Task 11
- Sidebar → Task 7
- Showboat explicitly dropped → AUTHORING.md + PR description

No placeholders, no references to undefined helpers, no "similar to Task N" — each task contains its own complete code.
