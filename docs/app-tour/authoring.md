---
sidebar_position: 99
title: Authoring the App Tour
description: How to regenerate or refresh the App Tour docs section.
---

# Authoring the App Tour

This page explains how the App Tour was generated and how to regenerate or refresh it.

Screenshots are captured from **platform running locally**, not from preview. This is
deliberate, not a convenience choice: `environmentLabel` — the purple "Preview Environment"
banner and the `[PRE]` page-title prefix — comes from `window.__APP_CONFIG__`, which the backend
injects at serve time. Vite's local dev server never injects it, so a local build renders exactly
like production. Preview cannot suppress its banner, so it can never produce a customer-accurate
screenshot; local dev is the only source that can.

## Prerequisites

- A `trakrf/platform` checkout (sibling to this repo works fine — `~/platform` is assumed
  below).
- Docker, for platform's local database and backend.
- `pnpm install` completed in this repo's root.
- Playwright MCP available to the authoring agent — it's the only capture tool used; there is no
  separate deterministic script anymore.
- `.env` present. Start by copying `.env.example`:

  ```bash
  cp .env.example .env
  ```

  Fill in `TRAKRF_DOCS_USER_EMAIL` / `TRAKRF_DOCS_USER_PASSWORD` once you've created the docs
  account (see below). `TRAKRF_LOCAL_URL` defaults to `http://localhost:5173` and shouldn't need
  changing.

- Run the platform commit that matches what's actually in production. Screenshots are supposed
  to document what customers see — capturing against an ahead-of-prod or behind-prod checkout
  will quietly drift the docs from reality.

## Starting the local stack

From `~/platform`:

```bash
just dev                    # database + backend + migrations
just frontend dev-bridge    # frontend on http://localhost:5173, wired to the reader bridge
```

`just dev` brings up the database and backend in Docker and runs migrations. `just frontend
dev-bridge` serves the app on `http://localhost:5173` connected to the RFID reader bridge rather
than the plain dev server.

**Non-interactive shells don't load platform's `.env.local`.** If you're driving these commands
from an agent or script rather than an interactive terminal, platform's `just` recipes will fail
with `PG_URL environment variable not set` because direnv never fired. Prefix each command:

```bash
direnv exec /home/mike/platform just dev
direnv exec /home/mike/platform just frontend dev-bridge
```

### The reader bridge

No extra setup is needed here — the bridge host comes from `BLE_MCP_HOST` in
`~/platform/.env.local`, loaded automatically via platform's `.envrc`. As long as the bridge
server and physical reader are reachable at that host, `just frontend dev-bridge` connects to
them on its own.

### Confirm it's rendering prod-like

Before capturing anything, open `http://localhost:5173` and check two things: no purple
environment banner, and the browser tab reads `TrakRF` with no `[DEV]`/`[PRE]` prefix. This is
the entire reason captures happen locally — if a banner appears, something is injecting
`__APP_CONFIG__` and the capture source is wrong. Stop and diagnose before continuing.

## The fixture: the "TrakRF Docs" org

1. Sign up through the local UI at `http://localhost:5173/#signup`, using an organization name
   of exactly **`TrakRF Docs`** — the seed script matches on that string.
2. Run `scripts/seed-docs-org.sql` against the local database (`just database psql <
   scripts/seed-docs-org.sql`, or the equivalent `docker exec` invocation for your local stack).

The script seeds 8 assets and 5 locations, grants the `geofence` capability so the Outputs and
Geofence defaults pages render real UI instead of a locked upsell page, and creates a second,
empty organization (`TrakRF Docs Empty`) for empty-state captures — the seeded org always has
data, so empty-state screenshots need a separate org.

**Mustering and kitting stay ungranted on purpose.** Those surfaces are out of scope for this
tour, and a locked Mustering tile ("Not enabled for your organization") appearing in the nav is
the accurate, intended state for this org — not a defect to fix.

Five of the seed's registered assets carry sequential bench RFID tags (`10018`–`10022`), matching
a physical reader on the bench. A sixth bench tag, `10023`, is deliberately left unregistered.
Scanning with the bridge-connected reader against this fixture produces a meaningful spread
across all five Scan tiles: **Found** and **Missing** from the registered tags, and **Extra**
from the one that isn't on any asset.

## Capturing

For each screen, at each of two viewports — **1440×900** desktop and **390×844** mobile — take a
viewport-only screenshot with Playwright MCP. **Re-navigate to the page after resizing**, not
just resize in place: several screens size their layout at mount time, so a resize-only capture
can show a desktop layout scaled into a mobile viewport instead of the actual responsive layout.

**Screenshots must be viewport-only, never full-browser.** This is the single most important
rule on this page. Two previously published images captured the full browser chrome, leaking the
author's personal bookmarks bar — email, calendar, job-search bookmarks — into customer-facing
documentation. Always crop to the viewport; never ship a capture that includes the address bar,
tab strip, or bookmarks bar.

**Playwright MCP writes screenshots to its own working directory** — the repository root of the
main checkout, not necessarily the worktree or directory you're working in. Every capture has to
be moved into `static/img/app-tour/` (or `static/img/user-guide/`) explicitly; don't assume the
file landed where you're currently working.

### What can't be recaptured

`static/img/user-guide/pairing-dialog.png` cannot be recaptured through this workflow. The
browser's native Bluetooth pairing dialog is OS/browser chrome that Playwright cannot screenshot,
and the reader bridge bypasses pairing entirely (it connects without ever showing that dialog).
The current image is cropped from an earlier, pre-bridge capture rather than reshot.

### Verify row counts before trusting a capture

In local dev, React's StrictMode double-invokes an effect on the Assets screen that appends to
state instead of replacing it, so the page renders **every row twice** — 16 rows and a
`Total Assets 16` tile against a fixture of 8. Production builds don't do this, so a screenshot
taken this way shows something no customer will ever see.

It is easy to miss, and it contaminated four images the first time this tour was captured,
including the dimmed background behind the create-asset modal. Before capturing any page that
lists data, check the visible count against the fixture: **8 assets, 5 locations**. If the
numbers are doubled, temporarily remove `React.StrictMode` from
`platform/frontend/src/main.tsx`, recapture, and restore it afterwards.

### Locate has a Start button

Locate exposes an on-screen **Start** button once a reader is connected — it is not
trigger-only. Use it to drive a capture rather than assuming a hardware trigger pull is required.

### Which capture path was used

This tour's screenshots were captured using the **physical reader over the bridge**, not
simulated Bluetooth notifications — real EPCs, signal strengths, and read counts, rather than
synthesized ones. Prefer the bridge when a reader is available; fall back to
`navigator.bluetooth.testing.simulateNotification` only if no reader is reachable, and record
which path was used if you regenerate this tour again.

## Things to know

- **Credentials are local.** `.env` is gitignored. Never commit it. Never paste credentials into
  commit messages or PR descriptions.
- **Playwright MCP does not write to a subfolder by default.** See "Capturing" above — always
  verify and move each screenshot after taking it.
