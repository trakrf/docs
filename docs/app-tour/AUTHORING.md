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
2. If credentials are blank: navigate to `${TRAKRF_PREVIEW_URL}/#signup` (the "Sign up" link on the login page doesn't consistently route via a click — go to the URL directly). Create an account with a generated email (`docs-tour-<YYYYMMDD>@example.com`), an organization name like "TrakRF Docs Tour", and a random password. Persist email + password into `.env`.
3. For each of the 9 tabs, in nav order — `home, inventory, locate, barcode, assets, locations, reports, settings, help`:
   - Resize the browser to 1440×900.
   - Navigate to `${TRAKRF_PREVIEW_URL}/#<tab>`.
   - Wait 1–2 seconds for the page to stabilize.
   - Take a screenshot into `static/img/app-tour/<tab>-desktop.png`.
   - Resize to 390×844, navigate again to force responsive remount, wait, screenshot into `<tab>-mobile.png`.
   - Observe the page. Write 2–4 sentences into the "What this page does" section of `docs/app-tour/<tab>.md`. List concrete controls, empty-state copy, and any visible device-status indicators.
   - Write 1–2 sentences into the "How it fits in the app" section connecting this tab to adjacent tabs or a workflow.
4. Run `pnpm build` to verify. Then `pnpm dev` and eyeball the site-map + a few detail pages.
5. Commit images and prose separately for a clean history.

## Things to know

- **Playwright MCP saves screenshots to the working directory, not a subfolder.** Each `browser_take_screenshot` drops the PNG in the repo root; move it into `static/img/app-tour/` with the correct name after each capture.
- **Signup URL.** Clicking the "Sign up" link from the login form does not consistently route on `app.preview.trakrf.id` — navigate directly to `/#signup` instead.
- **Empty-state honesty.** A fresh docs user owns no assets/locations/reports, so those tabs show "no data yet" UIs. A browser without a connected RFID reader shows "connect a device" states on Inventory / Locate / Barcode / Settings. Both are informative and match the new-user experience. If you want populated screenshots later, seed the account before the capture.
- **Mobile viewport caveat.** Rodney's `screenshot -w -h` resizes the viewport before each capture; if the app's layout depends on viewport size at mount time, the mobile shot may be a scaled desktop. If that happens, the fix is in `scripts/refresh-screenshots.sh`: either re-navigate after resize (the agent authoring recipe already does this) or drive viewport emulation via Rodney's JS bridge. Playwright MCP, used for the authoring pass, handles this correctly already.
- **Credentials are local.** `.env` is gitignored. Never commit it. Never paste credentials into commit messages or PR descriptions.
- **Showboat is not used.** The original TRA-347 scope mentioned Showboat alongside Rodney. In practice, Showboat's `exec`/`verify` model targets executable docs, not screenshot tours — so this tooling uses Rodney for refresh and Playwright MCP (via Claude Code) for authoring, skipping Showboat entirely.
