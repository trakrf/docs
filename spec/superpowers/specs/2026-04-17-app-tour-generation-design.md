# App Tour Generation — Design

- **Linear issue:** [TRA-347](https://linear.app/trakrf/issue/TRA-347/set-up-rodney-showboat-tooling-for-screenshot-based-docs-generation)
- **Parent:** TRA-83
- **Blocks:** TRA-329 (NADA minimum documentation content)
- **Date:** 2026-04-17

## Goal

Establish a repeatable, two-track workflow for producing screenshot-based documentation of every screen in the TrakRF web app:

1. **Authoring track (agent-driven, one-shot per pass):** Claude Code tours the live preview app, captures screenshots, and writes first-pass prose for each screen. Output is committed markdown + images that a human can then enhance.
2. **Refresh track (deterministic, human-runnable):** a bash script re-captures the screenshots in-place after a UI change, without touching the prose.

The scope of this spec is the _tooling and structure_ — not the content itself. Actual prose quality and human enhancement live with TRA-329.

## Non-goals

- Playwright-based E2E test authoring (Playwright remains the E2E test framework; this work does not touch it).
- Seeded demo data. First-pass screenshots capture the empty-state / no-device state honestly; seeded captures can be revisited later if TRA-329 requires them.
- Retrofitting existing `docs/user-guide/` pages. Those are 13-line placeholders today; they may link to app-tour images later, but this spec does not modify them.
- Production-deployment automation for the generator. Re-runs are local, human-invoked.

## Inputs and constraints

- **Target URL:** `https://app.preview.trakrf.id`
- **Tab set (9, hash-routed):** `home`, `inventory`, `locate`, `barcode`, `assets`, `locations`, `reports`, `settings`, `help`. Source of truth: `platform/frontend/src/components/TabNavigation.tsx`.
- **Auth model:** no signup restrictions on preview. The authoring pass creates a throwaway docs user via the app's own signup flow and persists the credentials to a gitignored `.env`. Subsequent refresh runs reuse the stored creds.
- **Tools available:** `uvx rodney` (installed), `uvx showboat` (installed — not used in the final design), Playwright MCP (available in the Claude Code environment), `pnpm` (required package manager).
- **Viewports:** capture each tab at both `1440×900` (desktop) and `390×844` (mobile). The mobile shot reflects how handheld-reader screens are actually used.

## Repo layout

```
docs/app-tour/
  index.md                 # site-map, renders <AppTourGrid />
  home.md
  inventory.md
  locate.md
  barcode.md
  assets.md
  locations.md
  reports.md
  settings.md
  help.md
  AUTHORING.md             # runbook for the agent-driven authoring pass
static/img/app-tour/
  home-desktop.png
  home-mobile.png
  ...
  help-desktop.png
  help-mobile.png
src/components/AppTourGrid.tsx   # custom grid used by index.md
scripts/
  refresh-screenshots.sh   # deterministic image-only refresh
.env.example               # TRAKRF_PREVIEW_URL, TRAKRF_DOCS_USER_EMAIL, TRAKRF_DOCS_USER_PASSWORD
.env                       # real creds (already gitignored)
sidebars.ts                # adds an "App Tour" category
README.md                  # adds an "App Tour docs" section
```

One `.md` per tab, paired with two images per tab (desktop + mobile). All app-tour images live under a single `static/img/app-tour/` folder so refresh is a flat operation.

## Per-page markdown template

Every `docs/app-tour/<tab>.md` follows the same shape so `AppTourGrid` can treat them uniformly.

```md
---
sidebar_position: <n> # 1..9 matching nav order
title: <Tab Label>
description: <one-line summary, ~120 chars — reused as site-map bullet>
---

# <Tab Label>

## Desktop

![<tab> desktop screenshot](/img/app-tour/<tab>-desktop.png)

## Mobile

![<tab> mobile screenshot](/img/app-tour/<tab>-mobile.png)

## What this page does

<2–4 sentences written by the agent from observing the page>

## How it fits in the app

<1–2 sentences connecting this tab to adjacent tabs or to a typical workflow>

:::note
This page was generated as a first-pass tour. Human enhancement welcome.
:::
```

Rules:

- `description` doubles as the site-map bullet — one source of truth.
- Desktop shot precedes mobile, then prose. Prose is single-voice; it does not need separate sections per viewport.
- The `:::note` banner is a visual marker for reviewers and can be stripped later as pages get rewritten by humans.

## Site-map (`docs/app-tour/index.md`)

```md
---
sidebar_position: 0
title: App Tour
---

# App Tour

A visual walk-through of every screen in the TrakRF web app.

import AppTourGrid from '@site/src/components/AppTourGrid';

<AppTourGrid />
```

### `AppTourGrid` component

- Location: `src/components/AppTourGrid.tsx`.
- Consumes a hardcoded array of 9 entries, each `{ id, title, description, thumbnailSrc, href }`. The array lives in the same file; no dynamic docs-plugin introspection in v1 (simpler, fewer moving parts).
- Renders a CSS-grid of cards, each showing the desktop thumbnail (mobile aspect ratio would make the grid uneven), title, description, linked to `/docs/app-tour/<id>`.
- ~40 LOC; no new dependencies. Styles via CSS modules or Docusaurus' built-in Infima classes.

The entries are kept in sync with per-page frontmatter manually. The authoring pass is responsible for updating the array when it writes the `.md` files. Drift-detection is out of scope for v1 — if it becomes a problem, a later pass can replace the hardcoded array with a build-time read of docs metadata.

## Authoring runbook (`docs/app-tour/AUTHORING.md`)

A markdown file that is both human-readable and Claude-runnable. It contains:

1. **Prerequisites**
   - `pnpm install` completed in the repo root.
   - `uvx` available (for the refresh script only).
   - Chromium available (Playwright MCP requirement for the agent pass; `rodney start` requirement for the refresh script).
   - `.env` present with `TRAKRF_PREVIEW_URL`, `TRAKRF_DOCS_USER_EMAIL`, `TRAKRF_DOCS_USER_PASSWORD`. If email/password are blank, the authoring pass performs signup and writes them back.

2. **Signup flow (first-time only)**
   - Navigate to `TRAKRF_PREVIEW_URL`.
   - Click through to signup. Create an account with a generated email (`docs-<timestamp>@example.com`) and a random password; persist both to `.env`.
   - Complete any post-signup steps required to reach the main app (org creation prompt, etc.). Capture these post-auth screens as part of the tour if they appear as tabs; otherwise dismiss.

3. **Per-tab capture loop** — for each of the 9 tabs in order:
   - Navigate to `<TRAKRF_PREVIEW_URL>/#<tab>`.
   - Wait for the page to stabilize (network idle + any obvious in-page load indicators clear).
   - Capture desktop screenshot at 1440×900 → `static/img/app-tour/<tab>-desktop.png`.
   - Resize viewport to 390×844, re-navigate if the app's responsive layout requires a remount, capture → `static/img/app-tour/<tab>-mobile.png`.
   - Observe the UI: visible controls, empty-state copy, any banners or device-status indicators. Note tooltips from nav items as supplementary description input.
   - Write `docs/app-tour/<tab>.md` using the per-page template, filling in `sidebar_position`, `title`, `description`, "What this page does" (2–4 sentences), and "How it fits in the app" (1–2 sentences). Descriptions should be concrete and grounded in what was actually on screen, not assumed functionality.

4. **Site-map sync**
   - After all 9 pages are written, update the `AppTourGrid` entries array in `src/components/AppTourGrid.tsx` so each entry matches the frontmatter of the corresponding `.md`.
   - Verify `docs/app-tour/index.md` renders without errors via `pnpm dev`.

5. **Re-run modes**
   - **Full regenerate:** delete `docs/app-tour/*.md` (except `AUTHORING.md`) and `static/img/app-tour/*.png`, then run the authoring pass again.
   - **Screenshots only:** `bash scripts/refresh-screenshots.sh`. Prose untouched.

## Refresh script (`scripts/refresh-screenshots.sh`)

Pure bash, targeting the 9 tabs × 2 viewports = 18 captures. Behavior:

1. `set -euo pipefail`; fail loudly on any step.
2. `source .env`; fail with a helpful message if missing.
3. Start Rodney headless: `uvx rodney start`.
4. Navigate to the login URL, fill credentials via `rodney input` / `rodney click`, wait for the dashboard to appear.
5. For each tab in a fixed bash array:
   - `uvx rodney open "${TRAKRF_PREVIEW_URL}/#${tab}"`
   - `uvx rodney waitstable`
   - `uvx rodney screenshot -w 1440 -h 900 "static/img/app-tour/${tab}-desktop.png"`
   - `uvx rodney screenshot -w 390 -h 844 "static/img/app-tour/${tab}-mobile.png"`
6. `uvx rodney stop` in a trap so the browser cleans up on error.

Approximately 40–60 lines. Idempotent — running twice overwrites the PNGs.

Caveat: if Rodney's `screenshot -w -h` sets viewport size only at capture time rather than mounting the page at that size, the mobile shot may be a scaled-down desktop layout rather than the app's responsive mobile view. If that turns out to be the case, the script instead uses Rodney's JS bridge to set `window.innerWidth/innerHeight` + reload, or falls back to Playwright's `--emulate` for the mobile pass. Exact mechanism is an implementation detail resolved during build; the spec commits only to "both viewports are captured, both reflect the app's responsive layout."

## State captured

First-pass honesty: the docs user is fresh and owns no data, and no handheld RFID reader is connected to the browser. Consequences:

- `Assets`, `Locations`, `Reports`: empty-state UI — "No assets yet" messages, empty tables. This is informative ("this is where your assets will appear") and matches the first-time user experience.
- `Inventory`, `Locate`, `Barcode`: device-disconnected state — probably a "connect a reader" prompt. Prose acknowledges this and notes that real-device screenshots can supersede these in a later pass.
- `Home`, `Settings`, `Help`: fully populated regardless.

Seeded captures are explicitly out of scope. If TRA-329 determines empty-state screenshots undersell the product, a follow-up issue can add a seeding step to the runbook.

## Configuration

`.env.example`:

```
TRAKRF_PREVIEW_URL=https://app.preview.trakrf.id
TRAKRF_DOCS_USER_EMAIL=
TRAKRF_DOCS_USER_PASSWORD=
```

`.env` is already covered by the existing `.gitignore`; no changes required there.

## README changes

Add a short "App Tour docs" section to `README.md` pointing at `docs/app-tour/AUTHORING.md` for regeneration and `scripts/refresh-screenshots.sh` for screenshot-only refreshes. Half a page, no more.

## Sidebar changes

`sidebars.ts` gains an "App Tour" category containing `app-tour/index` followed by the 9 tab pages in nav order. Existing categories untouched.

## Done when

- `docs/app-tour/` contains `index.md`, `AUTHORING.md`, and all 9 per-tab markdown files, each with a desktop + mobile screenshot and filled-in prose.
- `static/img/app-tour/` contains 18 PNGs.
- `src/components/AppTourGrid.tsx` renders the site-map grid with thumbnails, titles, descriptions, and links to the 9 pages.
- `scripts/refresh-screenshots.sh` exists and successfully refreshes all 18 screenshots against `app.preview.trakrf.id` using credentials from `.env`.
- `pnpm dev` renders the App Tour section without errors; navigation, links, and image loads all work.
- `pnpm build` succeeds.
- `README.md` documents the authoring and refresh workflows.
- `.env.example` exists and `.env` is gitignored.
- Showboat is **not** used in the final implementation; the ticket's "use both tools" language is superseded by the simpler agent-driven-authoring + rodney-refresh approach and is noted as a scope change in the PR description.

## Open questions deferred to implementation

- Exact Rodney command sequence for setting a mobile-responsive viewport (verified during build, see Refresh script caveat).
- Whether Docusaurus' default image handling needs any config tweaks for the per-page + thumbnail usage in `AppTourGrid`.
- Whether the signup flow on preview has any interstitial steps (e.g., email verification) that would block the one-shot authoring pass. If it does, the runbook adds a human-in-the-loop pause note and the spec doesn't change.
