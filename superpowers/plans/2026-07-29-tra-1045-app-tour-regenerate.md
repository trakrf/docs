# TRA-1045 App Tour Regenerate — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the customer docs in line with the shipped UI — Inventory renamed to Scan, Home and Barcode tabs removed, Scan tiles relabelled — and regenerate the App Tour from live observation with clean, prod-like screenshots.

**Architecture:** Docs-only changes in `trakrf/docs`, plus a locally-run instance of `trakrf/platform` used purely as a screenshot rig. Structure lands first (pages, sidebar, redirects) so the build stays green; then the capture environment; then prose written from observation; then a terminology sweep; then acceptance verification.

**Tech Stack:** Docusaurus 3.9.2, `@docusaurus/plugin-client-redirects`, pnpm, Playwright MCP, `ble-mcp-test` bridge, PostgreSQL/TimescaleDB via `just`.

## Global Constraints

- **pnpm exclusively.** Never `npm` or `npx`; use `pnpm dlx` in place of `npx`.
- **Never push to main.** All work lands on `docs/tra-1045-app-tour-regenerate` via PR.
- **Do not merge the PR** until TRA-1046 deploys this UI to prod. Opening it is fine and desirable — sync-preview re-merges open PRs, so the work is reviewable on the preview docs site.
- **"Inventory" is reserved vocabulary** for the future Inventory module. It must never describe the scanning surface. Exception: it may describe a *customer's own* third-party systems (e.g. `docs/getting-started/index.md:24`, "integrating TrakRF into existing systems (inventory, ERP, custom dashboards)") — that usage stays.
- **"Barcode"** survives only as a scan mode and as the API `tag_type` value. Never a tab or screen.
- **"Home"** never names a screen.
- **Tile names and order:** Scans → Assets → Found → Missing → Extra. With no reconcile list loaded, only **Scans** and **Assets** render.
- **No Linear ticket references in published docs.** `TRA-NNN` is fine in this plan and in specs; never in `docs/`.
- **All screenshots viewport-only** (never full-browser), captured from local dev, in one consistent theme.
- **No writes to the preview or prod databases.** Seeding targets the local database only.
- Conventional commits: `docs:`, `feat:`, `fix:`, `chore:`.

---

### Task 1: Infra-ops passthrough in the justfile

Gives the docs repo `just psql preview`, `just logs`, `just gcp-auth`, and `just ops <cmd>` by forwarding to the infra justfile, mirroring the TRA-1053 pattern already in `~/platform/justfile`.

**Files:**
- Modify: `justfile`
- Modify: `.env.example`

**Interfaces:**
- Consumes: nothing.
- Produces: `just ops <recipe>` available for later verification steps.

- [ ] **Step 1: Read the reference implementation**

Run: `sed -n '54,100p' ~/platform/justfile`

Note the resolution order: `TRAKRF_INFRA_DIR`, else the main worktree's sibling `infra` directory. The docs repo uses `.claude/worktrees/` exactly like platform, so the main-worktree resolution matters — `../infra` from inside a worktree would resolve wrongly.

- [ ] **Step 2: Add the passthrough to `justfile`**

```just
# ============================================================================
# Infra Ops Passthrough
# ============================================================================
# Cluster, namespace, pod and CNPG knowledge lives in trakrf/infra. These
# recipes only forward to its justfile — they never restate any of it.

# Run an infra ops recipe (`just ops logs preview 1h`); bare `just ops` lists them
ops *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    infra_dir="${TRAKRF_INFRA_DIR:-}"
    if [ -z "$infra_dir" ]; then
        main_dir=$(git worktree list --porcelain 2>/dev/null \
            | awk '/^worktree /{path=$2} /^branch refs\/heads\/main$/{print path; exit}')
        [ -n "$main_dir" ] || main_dir="{{ justfile_directory() }}"
        infra_dir="$(dirname "$main_dir")/infra"
    fi
    if [ ! -f "$infra_dir/justfile" ]; then
        echo "ERROR: no infra checkout at $infra_dir" >&2
        echo "       Set TRAKRF_INFRA_DIR to your trakrf/infra checkout." >&2
        exit 1
    fi
    just --justfile "$infra_dir/justfile" {{ ARGS }}

# Authenticate to GCP and point kubectl at the cluster (no-op if already valid)
gcp-auth *ARGS:
    @just ops gcp-auth {{ ARGS }}

# Interactive psql on a CNPG primary: `just psql preview`
psql *ARGS:
    @just ops psql {{ ARGS }}

# Follow backend logs: `just logs preview 1h`
logs *ARGS:
    @just ops logs {{ ARGS }}
```

- [ ] **Step 3: Document the required variable in `.env.example`**

Append:

```bash
# Path to your trakrf/infra checkout, used by the `just ops` passthrough.
# The sibling-directory fallback assumes ~/infra; set this if yours differs
# (e.g. ~/trakrf-infra). .envrc loads .env.local.
# TRAKRF_INFRA_DIR=/home/you/trakrf-infra
```

- [ ] **Step 4: Set it locally**

Append `TRAKRF_INFRA_DIR=$HOME/trakrf-infra` to `.env.local` (gitignored — never commit it).

- [ ] **Step 5: Verify the passthrough resolves**

Run: `just ops --list | head -20`
Expected: infra's recipe list, including `psql` and `logs`. If it errors with "no infra checkout", `TRAKRF_INFRA_DIR` is unset in the current shell — `direnv reload` or export it.

- [ ] **Step 6: Verify a real forwarded command**

Run: `echo "select 1;" | just psql preview`
Expected: a `1` in the output. A "Unable to use a TTY" warning on stderr is normal and harmless.

- [ ] **Step 7: Commit**

```bash
git add justfile .env.example
git commit -m "chore: forward psql/logs/gcp-auth/ops to the infra justfile"
```

---

### Task 2: Page structure, sidebar, grid, and redirects

Moves and deletes pages, restructures navigation, and installs redirects — all before any prose is written, so the build never goes red for long. New pages land as minimal stubs here and get real content in Tasks 6 and 7.

**Files:**
- Rename: `docs/app-tour/inventory.md` → `docs/app-tour/scan.md`
- Delete: `docs/app-tour/home.md`, `docs/app-tour/barcode.md`
- Create: `docs/app-tour/readers.md`, `docs/app-tour/live-feed.md`, `docs/app-tour/outputs.md`, `docs/app-tour/geofence-defaults.md`
- Modify: `sidebars.ts`, `src/components/AppTourGrid.tsx`, `docusaurus.config.ts`, `package.json`

**Interfaces:**
- Consumes: nothing.
- Produces: doc ids `app-tour/scan`, `app-tour/readers`, `app-tour/live-feed`, `app-tour/outputs`, `app-tour/geofence-defaults`; image paths `/img/app-tour/<id>-desktop.png` and `-mobile.png` that Task 4 must satisfy.

- [ ] **Step 1: Install the redirects plugin**

Run: `pnpm add @docusaurus/plugin-client-redirects@3.9.2`

Version must match the pinned `@docusaurus/core` 3.9.2 exactly.

- [ ] **Step 2: Move and delete pages with git**

```bash
git mv docs/app-tour/inventory.md docs/app-tour/scan.md
git rm docs/app-tour/home.md docs/app-tour/barcode.md
```

Use `git mv` rather than create-plus-delete so the rename is visible in history.

- [ ] **Step 3: Retitle `scan.md`**

Replace the frontmatter and heading. Leave the body prose alone — Task 5 rewrites it from observation.

```markdown
---
sidebar_position: 1
title: Scan
description: Read RFID tags or barcodes and reconcile them against a list.
---

# Scan
```

- [ ] **Step 4: Create the four new stub pages**

Each gets frontmatter, a heading, and screenshot placeholders. `readers.md`:

```markdown
---
sidebar_position: 7
title: Readers
description: Register and manage fixed RFID readers.
---

# Readers

## Desktop

![Readers desktop screenshot](/img/app-tour/readers-desktop.png)

## Mobile

![Readers mobile screenshot](/img/app-tour/readers-mobile.png)

## What this page does

Placeholder — written from live observation in Task 7.
```

Repeat for `live-feed.md` (position 8, title "Live feed", description "Watch tag reads arrive in real time."), `outputs.md` (position 9, title "Outputs", description "Configure output devices triggered by geofence events."), and `geofence-defaults.md` (position 10, title "Geofence defaults", description "Org-wide geofence tuning applied to every portal.").

- [ ] **Step 5: Restructure `sidebars.ts`**

Replace the `appTourSidebar` array. The Settings category mirrors how the app nests these four entries beneath Settings in its own sidebar.

```ts
  appTourSidebar: [
    "app-tour/index",
    "app-tour/scan",
    "app-tour/locate",
    "app-tour/assets",
    "app-tour/locations",
    "app-tour/reports",
    {
      type: "category",
      label: "Settings",
      link: { type: "doc", id: "app-tour/settings" },
      items: [
        "app-tour/readers",
        "app-tour/live-feed",
        "app-tour/outputs",
        "app-tour/geofence-defaults",
      ],
    },
    "app-tour/help",
    "app-tour/authoring",
  ],
```

- [ ] **Step 6: Rewrite the `ENTRIES` array in `src/components/AppTourGrid.tsx`**

```tsx
const ENTRIES: TourEntry[] = [
  {
    id: "scan",
    title: "Scan",
    description:
      "Read RFID tags or barcodes and reconcile them against a list.",
  },
  {
    id: "locate",
    title: "Locate",
    description:
      "Find a specific item by walking the area with a handheld reader.",
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
    id: "readers",
    title: "Readers",
    description: "Register and manage fixed RFID readers.",
  },
  {
    id: "live-feed",
    title: "Live feed",
    description: "Watch tag reads arrive in real time.",
  },
  {
    id: "outputs",
    title: "Outputs",
    description: "Configure output devices triggered by geofence events.",
  },
  {
    id: "geofence-defaults",
    title: "Geofence defaults",
    description: "Org-wide geofence tuning applied to every portal.",
  },
  {
    id: "help",
    title: "Help",
    description: "Quick answers to common questions.",
  },
];
```

- [ ] **Step 7: Add the redirects to `docusaurus.config.ts`**

There is no `plugins` array today. Add one as a sibling of `presets`, immediately before it:

```ts
  plugins: [
    [
      "@docusaurus/plugin-client-redirects",
      {
        redirects: [
          { from: "/app-tour/inventory", to: "/app-tour/scan" },
          { from: "/app-tour/home", to: "/app-tour/scan" },
          { from: "/app-tour/barcode", to: "/app-tour/scan" },
        ],
      },
    ],
  ],
```

- [ ] **Step 8: Verify the build fails on the stale images**

Run: `pnpm build`
Expected: FAIL. `onBrokenLinks: "throw"` plus the missing `/img/app-tour/scan-desktop.png` and the four new pages' images will surface. This is the failing test for Task 4.

Record the exact errors — they are the checklist Task 4 must clear.

- [ ] **Step 9: Copy placeholder images so the build can go green**

The real captures land in Task 4. To keep the tree buildable in the meantime, copy an existing image into each new path:

```bash
cd static/img/app-tour
for n in scan readers live-feed outputs geofence-defaults; do
  cp inventory-desktop.png "${n}-desktop.png"
  cp inventory-mobile.png "${n}-mobile.png"
done
git rm home-desktop.png home-mobile.png barcode-desktop.png barcode-mobile.png \
       inventory-desktop.png inventory-mobile.png
```

- [ ] **Step 10: Verify the build passes**

Run: `pnpm build`
Expected: PASS, no broken links.

- [ ] **Step 11: Verify the redirects were emitted**

Run: `ls build/app-tour/inventory/index.html build/app-tour/home/index.html build/app-tour/barcode/index.html`
Expected: all three exist.

Run: `grep -o 'app-tour/scan' build/app-tour/inventory/index.html | head -1`
Expected: `app-tour/scan`. The plugin emits redirects at build time only — they do not exist under `pnpm dev`.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "docs(app-tour): restructure tabs for Scan rename and Home/Barcode removal

Placeholder images stand in until the capture pass replaces them."
```

---

### Task 3: Local capture environment and seed data

Stands up platform locally with the reader bridge, creates the docs org, and seeds realistic data. Nothing here touches the docs repo except the checked-in seed script.

**Files:**
- Create: `scripts/seed-docs-org.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: a local app at `http://localhost:5173` with an org named `TrakRF Docs`, the `geofence` capability granted, a location tree, and named assets — the fixture every screenshot in Task 4 depends on.

- [ ] **Step 1: Start the local stack**

```bash
cd ~/platform
just dev          # database + backend + migrations
```

Expected: "Development environment ready".

- [ ] **Step 2: Start the frontend against the reader bridge**

```bash
cd ~/platform
just frontend dev-bridge
```

Expected: the dev server on `http://localhost:5173`, with the bridge host logged. `BLE_MCP_HOST` is inherited from `~/platform/.env.local` via `.envrc` — do not set it again.

If the bridge is unreachable, the reader is off or `ble-mcp-test` is not running on that host. Screenshots requiring a connected device (Task 4, Steps 8–10) need it; everything else does not.

- [ ] **Step 3: Confirm the app renders prod-like**

Open `http://localhost:5173` and check two things: **no purple environment banner**, and the browser tab reads `TrakRF` with no `[DEV]`/`[PRE]` prefix. This is the whole reason captures happen locally — if a banner appears, the backend is injecting `__APP_CONFIG__` and the capture source is wrong. Stop and diagnose before continuing.

- [ ] **Step 4: Create the account and org through the UI**

Sign up at `http://localhost:5173/#signup`. Use organization name exactly `TrakRF Docs` — the seed script matches on that string. Record the email and password; they go in `.env` in Task 9.

Signing up through the UI (rather than inserting rows) is deliberate: `org_users` membership and org defaults get built by the application.

- [ ] **Step 5: Confirm the local psql invocation**

```bash
cd ~/platform
just database psql   # or: docker compose exec -T postgres psql -U postgres -d trakrf
```

Verify the org exists:

```sql
select id, name from trakrf.organizations where name = 'TrakRF Docs';
```

Expected: exactly one row. If empty, signup did not complete.

- [ ] **Step 6: Write `scripts/seed-docs-org.sql`**

Resolves the org by name inside a `DO` block, so no psql variables are needed and the script is re-runnable.

```sql
-- Seeds the TrakRF Docs org used for documentation screenshots.
-- Idempotent: safe to re-run. Targets a LOCAL database only.
-- Usage: just database psql < scripts/seed-docs-org.sql
\set ON_ERROR_STOP on

DO $$
DECLARE
    v_org       BIGINT;
    v_receiving BIGINT;
    v_warehouse BIGINT;
    v_bay3      BIGINT;
    v_office    BIGINT;
    v_lab       BIGINT;
BEGIN
    SELECT id INTO v_org
      FROM trakrf.organizations
     WHERE name = 'TrakRF Docs' AND deleted_at IS NULL;

    IF v_org IS NULL THEN
        RAISE EXCEPTION 'Org "TrakRF Docs" not found — sign up through the UI first';
    END IF;

    -- Geofence unlocks the Outputs and Geofence defaults pages. Without it they
    -- render as locked upsell pages. Mustering and kitting stay ungranted on
    -- purpose: those surfaces are out of scope and must not appear unlocked.
    INSERT INTO trakrf.org_capabilities (org_id, capability, granted_at)
    VALUES (v_org, 'geofence', now())
    ON CONFLICT DO NOTHING;

    IF EXISTS (SELECT 1 FROM trakrf.assets
                WHERE org_id = v_org AND external_key = 'ASSET-CAMERA'
                  AND deleted_at IS NULL) THEN
        RAISE NOTICE 'Seed data already present — skipping';
        RETURN;
    END IF;

    SELECT location_id INTO v_receiving FROM trakrf.create_location_with_tags(
        v_org, 'LOC-RECEIVING', 'Receiving', 'Inbound dock',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    SELECT location_id INTO v_warehouse FROM trakrf.create_location_with_tags(
        v_org, 'LOC-WAREHOUSE-A', 'Warehouse A', 'Main storage',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    SELECT location_id INTO v_bay3 FROM trakrf.create_location_with_tags(
        v_org, 'LOC-BAY-3', 'Bay 3', 'Warehouse A, bay 3',
        v_warehouse, now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1A101"}]'::jsonb);

    SELECT location_id INTO v_office FROM trakrf.create_location_with_tags(
        v_org, 'LOC-OFFICE', 'Office', 'Front office',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    SELECT location_id INTO v_lab FROM trakrf.create_location_with_tags(
        v_org, 'LOC-LAB', 'Lab', 'Test bench',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-CAMERA', 'Camera',
        'Canon EOS R6 body', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B201"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-LAPTOP', 'Laptop',
        'ThinkPad X1 Carbon', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B202"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-TABLET', 'Tablet',
        'iPad Pro 11-inch', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B203"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-PROJECTOR', 'Projector',
        'Epson conference room projector', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B204"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-TOOLBOX', 'Toolbox',
        'Field service toolkit', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B205"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-PALLET-JACK', 'Pallet Jack',
        'Electric pallet jack', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B206"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-MICROSCOPE', 'Microscope',
        'Lab inspection microscope', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B207"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-LABEL-PRINTER', 'Label Printer',
        'Zebra ZT411 tag printer', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B208"}]'::jsonb);

    RAISE NOTICE 'Seeded org % with 5 locations and 8 assets', v_org;
END $$;
```

The EPC values are placeholders for display. Step 8 replaces the ones you intend to physically scan with EPCs from real tags.

- [ ] **Step 7: Run the seed**

```bash
cd ~/platform && just database psql < ~/trakrf-docs/.claude/worktrees/tra-1045-app-tour-regenerate/scripts/seed-docs-org.sql
```

Expected: `NOTICE: Seeded org <id> with 5 locations and 8 assets`.

- [ ] **Step 8: Align tag values with the physical tags**

Read the EPCs your bench tags actually broadcast — scan them in the app, or check `~/platform/frontend/tests/e2e/test-utils/constants.ts` for the known test-tag definitions. Update the matching `value` fields in the seed script and re-run after deleting the seeded assets, so scanned reads resolve to named assets instead of showing as unknown EPCs.

This is what makes the Found/Missing/Extra tiles meaningful: reads that match a registered asset land in Found, registered assets not seen land in Missing, and unregistered EPCs land in Extra.

- [ ] **Step 9: Verify the seed landed and capabilities are right**

```sql
select (select count(*) from trakrf.assets a
         where a.org_id = o.id and a.deleted_at is null)    as assets,
       (select count(*) from trakrf.locations l
         where l.org_id = o.id and l.deleted_at is null)    as locations,
       (select string_agg(capability, ',') from trakrf.org_capabilities c
         where c.org_id = o.id)                             as caps
  from trakrf.organizations o
 where o.name = 'TrakRF Docs';
```

Expected: `assets = 8`, `locations = 5`, `caps = geofence`. If `caps` contains `mustering` or `kitting`, remove them — those surfaces must render locked.

- [ ] **Step 10: Confirm the gated pages unlocked**

Reload the app. In the sidebar, **Outputs** and **Geofence defaults** must no longer carry "Not enabled for your organization", while **Mustering** still does.

- [ ] **Step 11: Commit**

```bash
git add scripts/seed-docs-org.sql
git commit -m "feat(scripts): add local seed for documentation screenshots"
```

---

### Task 4: Capture screenshots

Captures every image from local dev via Playwright MCP. Screenshots land in the repo root by default and must be moved.

**Files:**
- Create/replace: `static/img/app-tour/{scan,locate,assets,locations,reports,settings,readers,live-feed,outputs,geofence-defaults,help}-{desktop,mobile}.png`
- Replace: `static/img/user-guide/*.png` (every image showing the app)

**Interfaces:**
- Consumes: the seeded local app from Task 3; the image paths declared in Task 2.
- Produces: real screenshots at every path Task 2's pages reference.

- [ ] **Step 1: Log in and confirm the capture persona**

Log into `http://localhost:5173` as the Task 3 account. Open the account menu and confirm it lists exactly one organization and has **no "All Organizations" item**. If that item appears, the account is a superadmin and must not be used — superadmin surfaces must never reach customer documentation.

- [ ] **Step 2: Set the desktop viewport**

Resize the browser to 1440×900.

- [ ] **Step 3: Capture each desktop page**

For each of `scan, locate, assets, locations, reports, settings, readers, live-feed, outputs, geofence-defaults, help`: navigate to the page, wait 1–2 seconds for it to settle, then screenshot.

The app's own hash routes are not identical to the doc ids. Confirm each from the sidebar rather than guessing — `Readers` is `#scan-devices` and `Geofence defaults` is `#org-geofence-defaults`, not `#readers` / `#geofence-defaults`.

Move each capture into place:

```bash
mv page-*.png static/img/app-tour/<id>-desktop.png
```

- [ ] **Step 4: Capture each mobile page**

Resize to 390×844 and **re-navigate** before each capture — the app's layout depends on viewport size at mount, so resizing alone yields a scaled desktop view. Save as `<id>-mobile.png`.

- [ ] **Step 5: Verify no image leaks browser chrome**

Open two or three captures and confirm they show only the app viewport — no address bar, no bookmarks bar, no OS chrome. The image being replaced, `inventory-scanning.png`, leaked a personal bookmarks bar into published docs; do not reintroduce that.

- [ ] **Step 6: Verify the tile states**

In `scan-desktop.png`, with no reconcile list loaded, exactly two tiles must be visible: **Scans** and **Assets**. If five appear, a list is loaded — clear it and recapture.

- [ ] **Step 7: Recapture the user-guide images**

Replace every `static/img/user-guide/*.png` that shows the app, matching each one's existing purpose (see the alt text in `docs/user-guide/asset-management.md` and `reader-setup.md`): empty and populated Locations, empty and populated Assets, the create-asset modal, the reports page, and device setup.

Rename the two scanning images to match the new tab name:

```bash
git mv static/img/user-guide/inventory-connected-idle.png static/img/user-guide/scan-connected-idle.png
git mv static/img/user-guide/inventory-scanning.png static/img/user-guide/scan-scanning.png
```

Update the references at `docs/user-guide/asset-management.md:66` and `:78`.

- [ ] **Step 8: Connect the reader**

Click **Connect Device** and pair through the bridge. Confirm the device-status chip reads **Connected**. If the bridge is down, skip Steps 8–10 and note in the PR which images still need a hardware pass.

- [ ] **Step 9: Capture the connected-idle state**

With the reader connected and the Scanned list empty, capture the Scan page as `static/img/user-guide/scan-connected-idle.png`.

- [ ] **Step 10: Capture the mid-scan and reconcile states**

Load the asset list via **Reconcile**, run a scan against the bench tags, and capture:
- `static/img/user-guide/scan-scanning.png` — populated Scanned list with per-row signal and count
- `static/img/app-tour/scan-desktop.png` is the *empty* state and must not be overwritten here

Confirm all five tiles now render in the order **Scans → Assets → Found → Missing → Extra**. If the Location column reads `-` for scanned assets, the `asset_scan_latest` continuous aggregate has not refreshed — assets carry no `location_id` column, so location is derived from scan history:

```sql
CALL refresh_continuous_aggregate('trakrf.asset_scan_latest', NULL, NULL);
```

- [ ] **Step 11: Verify the build**

Run: `pnpm build`
Expected: PASS with no broken links.

- [ ] **Step 12: Commit images separately from prose**

```bash
git add static/img
git commit -m "feat: recapture app-tour and user-guide screenshots

Captured from local dev: no environment banner, viewport-only, seeded
data with real asset names."
```

---

### Task 5: Rewrite `scan.md` from observation

**Files:**
- Modify: `docs/app-tour/scan.md`

**Interfaces:**
- Consumes: `scan-desktop.png` / `scan-mobile.png` from Task 4.
- Produces: the tile vocabulary every other page must match.

- [ ] **Step 1: Observe the page**

With the app open on the Scan tab, list what is actually present: the RFID/Barcode mode toggle, the toolbar buttons, the location-tag selector, the tile row, and the empty-state copy. Do not copy the old prose forward — it documents a **Sample** button that no longer exists.

- [ ] **Step 2: Write "What this page does"**

Two to four sentences naming concrete controls. It must state the toolbar accurately (Start, Reconcile, Clear, the audio toggle, Share, Save — and **no Sample**), name the RFID/Barcode toggle as a mode switch rather than a separate tab, mention the location-tag selector, and give the tiles as **Scans → Assets → Found → Missing → Extra** with the note that only Scans and Assets render until a reconcile list is loaded.

- [ ] **Step 3: Write "How it fits in the app"**

One or two sentences connecting Scan to Locate and Assets. Must not use the word "Inventory" to describe scanning.

- [ ] **Step 4: Remove the first-pass note**

Delete the `:::note This page was generated as a first-pass tour. Human enhancement welcome. :::` block — this page is no longer a first pass.

- [ ] **Step 5: Verify the forbidden strings are gone**

Run: `grep -nE 'Inventory|Barcode tab|Sample|Not Listed|Total Scanned|Saveable' docs/app-tour/scan.md`
Expected: no output. A `Barcode` match is acceptable only where it names the scan mode.

- [ ] **Step 6: Commit**

```bash
git add docs/app-tour/scan.md
git commit -m "docs(app-tour): rewrite the Scan page from the shipped UI"
```

---

### Task 6: Rewrite the remaining existing tour pages

**Files:**
- Modify: `docs/app-tour/index.md`, `locate.md`, `assets.md`, `locations.md`, `reports.md`, `settings.md`, `help.md`

**Interfaces:**
- Consumes: tile vocabulary from Task 5; images from Task 4.
- Produces: cross-references the terminology sweep in Task 9 will assert against.

- [ ] **Step 1: Rewrite each page from observation**

For each, refresh both sections against the live screen and remove the first-pass `:::note` block. Every cross-reference to the old tabs must go: `assets.md`, `locate.md`, `locations.md`, `reports.md`, and `settings.md` each currently reference Inventory, Home, or Barcode.

- [ ] **Step 2: Handle `help.md:23` carefully**

The line maps docs sections to in-app Help questions: "Its questions mirror the scanning tabs (Inventory = My Items, Locate = Find Item)".

Open the Help tab and read the actual accordion labels. If the in-app copy still says "Inventory", that string lives in the **platform** repo — do not paper over it here. Describe what the in-app Help actually shows and file a platform ticket for the stale copy. Note the ticket number in the PR description.

- [ ] **Step 3: Verify no page describes a removed tab**

Run: `grep -rnE '\b(Home|Inventory)\b' docs/app-tour/`
Expected: no output.

Run: `grep -rn 'Barcode' docs/app-tour/`
Expected: only matches naming the scan mode.

- [ ] **Step 4: Commit**

```bash
git add docs/app-tour
git commit -m "docs(app-tour): refresh tour pages against the shipped UI"
```

---

### Task 7: Author the four new tour pages

**Files:**
- Modify: `docs/app-tour/readers.md`, `live-feed.md`, `outputs.md`, `geofence-defaults.md`

**Interfaces:**
- Consumes: the `geofence` grant from Task 3 (without it, two of these pages render as locked upsell pages and cannot be documented).
- Produces: nothing downstream.

- [ ] **Step 1: Confirm the pages render unlocked**

All four must show real UI, not "This feature isn't enabled for your organization." If Outputs or Geofence defaults still show the upsell, the grant from Task 3 did not apply — fix that before writing.

- [ ] **Step 2: Write each page**

Replace the placeholder "What this page does" with 2–4 sentences of live observation, then add a "How it fits in the app" section, matching the structure of the existing tour pages.

For `geofence-defaults.md`, the app's own nav tooltip describes the surface as org-wide geofence tuning — RSSI, age-out, auto-off, and mode — applied to every portal unless an output overrides it. Verify each of those controls exists on the page before describing it.

- [ ] **Step 3: Note the capability gate on the gated pages**

Outputs and Geofence defaults are capability-gated. Each page must state plainly that the feature is enabled per organization and that orgs without it see a locked page directing them to support — a reader whose sidebar shows a padlock needs to know that is expected, not broken.

Do not name Mustering or Kits anywhere; both are out of scope.

- [ ] **Step 4: Verify the build**

Run: `pnpm build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add docs/app-tour
git commit -m "docs(app-tour): document Readers, Live feed, Outputs, and Geofence defaults"
```

---

### Task 8: Author the organization-management page

**Files:**
- Modify: `docs/user-guide/organization-management.md`

**Interfaces:**
- Consumes: the local app and account from Task 3.
- Produces: nothing downstream.

- [ ] **Step 1: Observe the account-menu surface**

Open the account menu and walk each item: Organization Settings, Members, API Keys, and Create Organization.

- [ ] **Step 2: Replace the placeholder**

The page is currently a 13-line "Coming Soon" stub. Replace it entirely with sections covering those four surfaces, written from observation, keeping the existing `sidebar_position: 5`.

- [ ] **Step 3: Exclude Webhooks**

The account menu also contains **Webhooks**. Leave it undocumented — it belongs to the separate webhooks docs ticket. Do not mention it, and do not leave a "coming soon" stub in its place.

- [ ] **Step 4: Keep the API framing correct**

The users and org-admin *API* surfaces are internal-only. This page documents the UI. Do not imply a public API exists for managing members or organizations, and do not link to API reference pages for these operations.

- [ ] **Step 5: Verify the placeholder is gone**

Run: `grep -n 'Coming Soon' docs/user-guide/organization-management.md`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add docs/user-guide/organization-management.md
git commit -m "docs(user-guide): document organization management"
```

---

### Task 9: Terminology sweep and authoring workflow

**Files:**
- Modify: `docs/user-guide/asset-management.md`, `docs/getting-started/ui.mdx`, `docs/app-tour/authoring.md`, `scripts/refresh-screenshots.sh`, `.env.example`

**Interfaces:**
- Consumes: the tile vocabulary from Task 5.
- Produces: a repo that satisfies Task 10's acceptance greps.

- [ ] **Step 1: Fix `docs/user-guide/asset-management.md`**

Five distinct edits:
- `:4` — the description reads "save an inventory". Reword; this is the common-noun collision the reserve rule targets.
- `:9` — "running a scan session on the **Inventory** screen" → the **Scan** screen.
- `:57` — "show the raw EPC under 'Not Listed'" → under **Extra**.
- `:64` — "Open **Inventory** from the left nav" → **Scan**.
- `:75-77` — the three tile definitions change: **Not Listed** → **Extra** ("tags seen that weren't on the list"), **Total Scanned** → **Scans** ("unique EPCs seen this session"), **Saveable** → **Assets** ("of those, how many match a registered asset").

Also fix `:110` and `:114`, which use "Inventory" and "an inventory scan" to mean scanning.

- [ ] **Step 2: Fix `docs/getting-started/ui.mdx`**

- `:34` — "You'll land on the **Home** dashboard — a device-status summary, links to **Inventory / Locate / Barcode**, and a 'Watch Demo' card." The Home dashboard no longer exists; signing in lands on **Scan**. Rewrite against the live app.
- `:55` — "unregistered tags show up under **Not Listed**" → under **Extra**.
- `:60` — "Open **Inventory** (left nav)" → **Scan**.

- [ ] **Step 3: Leave `docs/getting-started/index.md:24` alone**

It reads "integrating TrakRF into existing systems (inventory, ERP, custom dashboards)" — the customer's own systems, not a TrakRF surface. This usage is explicitly permitted.

- [ ] **Step 4: Update `scripts/refresh-screenshots.sh`**

The `TABS` array on line 24 lists the old tabs. Replace with the current set, and update the login/capture flow to match the new capture story — the script drives Rodney against `app.preview.trakrf.id`, which is no longer where screenshots come from.

Either repoint it at `http://localhost:5173` with the local account, or delete it and let `authoring.md` describe the local flow. If you delete it, remove its mention from `authoring.md` too. Do not leave a script that silently captures from the wrong environment.

- [ ] **Step 5: Rewrite `docs/app-tour/authoring.md`**

It documents a workflow that no longer applies. It must now cover: the platform checkout and Docker prerequisites, `just dev` and `just frontend dev-bridge`, the bridge host coming from `~/platform/.env.local`, signing up to create the `TrakRF Docs` org, running `scripts/seed-docs-org.sql`, the `geofence` grant and why Mustering stays locked, capturing viewport-only at both viewports, and the requirement to run the platform commit that matches production.

Record which capture path was used — the reader bridge or simulated notifications.

Keep the two existing warnings that still apply: Playwright MCP writes screenshots to the working directory, and credentials stay local and uncommitted.

- [ ] **Step 6: Update `.env.example`**

The docs-tour preview credentials no longer drive screenshots. Replace them with the local-capture variables, keeping `TRAKRF_INFRA_DIR` from Task 1, and mirror the change into `.env`.

- [ ] **Step 7: Verify the sweep**

Run: `grep -rnE 'Not Listed|Total Scanned|Saveable' docs/`
Expected: no output.

Run: `grep -rniE '\binventory\b' docs/ --include='*.md' --include='*.mdx' | grep -v 'docs/api/'`
Expected: only `docs/getting-started/index.md:24`.

- [ ] **Step 8: Commit**

```bash
git add docs scripts .env.example
git commit -m "docs: retire Inventory/Barcode/Home vocabulary and rewrite the authoring flow"
```

---

### Task 10: Acceptance verification and PR

**Files:** none modified unless a check fails.

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Clean build**

```bash
pnpm clear && pnpm build
```

Expected: PASS, no broken-link errors. `onBrokenLinks: "throw"` means any dangling reference fails the build.

- [ ] **Step 2: Run every acceptance grep**

```bash
grep -rnE 'Not Listed|Total Scanned|Saveable' docs/ ; echo "tiles: $?"
grep -rnE '\b(Home|Inventory)\b' docs/app-tour/ ; echo "tabs: $?"
grep -rn 'TRA-[0-9]' docs/ ; echo "ticket refs: $?"
```

Expected: each prints `1` (grep found nothing). Any `0` means a violation remains.

- [ ] **Step 3: Verify redirects**

```bash
for p in inventory home barcode; do
  test -f "build/app-tour/$p/index.html" && grep -q 'app-tour/scan' "build/app-tour/$p/index.html" \
    && echo "$p OK" || echo "$p FAILED"
done
```

Expected: three `OK` lines.

- [ ] **Step 4: Verify no image leaks personal data**

Open every changed file under `static/img/` and confirm none shows browser chrome, bookmarks, an email address other than the docs account, or a superadmin menu.

- [ ] **Step 5: Serve and eyeball**

```bash
pnpm serve
```

Walk the App Tour sidebar top to bottom. Confirm the Settings category expands to the four sub-pages, every image loads, and no page describes a control that is not in its screenshot.

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin docs/tra-1045-app-tour-regenerate
gh pr create --title "docs: propagate Scan rename, Home/Barcode removal, and tile relabels" --body "$(cat <<'EOF'
Regenerates the App Tour against the shipped UI.

## Do not merge yet

Blocked on the prod release. Docs must not describe a UI users don't have.
Preview serves open PRs, so this is reviewable on the preview docs site now.

## Beyond the original scope

- The `Sample` button was documented but no longer exists
- The Scan tab's location-tag selector was undocumented
- `inventory-scanning.png` published a personal bookmarks bar
- Every app image carried a purple "Preview Environment" banner

Screenshots now come from local dev: no banner, viewport-only, seeded data
with real asset names. Nothing was written to the preview database.

## Excluded

Mustering, Kits, and Webhooks.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 7: Do not merge**

Leave the PR open until the prod release lands. Confirm in the PR that the branch is not set to auto-merge.

---

## Self-Review

**Spec coverage:** page map (Task 2), redirects (Task 2), terminology rules (Tasks 5, 6, 9), screenshots and capture source (Tasks 3, 4), seeded org and grant (Task 3), org management (Task 8), infra passthrough (Task 1), verification (Task 10), sequencing (Task 10 Step 7). The spec's note about the local version string is folded into Task 4's observation steps.

**Known gaps, deliberately left to execution:** the app's hash routes for the four new pages are confirmed only for Readers (`#scan-devices`) and Geofence defaults (`#org-geofence-defaults`); Task 4 Step 3 instructs reading the rest from the sidebar rather than guessing. Prose is written from live observation, so the plan specifies what each page must state rather than supplying final copy.

**Out of scope, file separately:** `PG_URL_PREVIEW` in `~/platform/.env.local` still points at Timescale Cloud and refuses connections since preview moved to CNPG on GKE.
