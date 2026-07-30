# TRA-1045 — App Tour regenerate: Scan rename, Home/Barcode removal, tile relabels

**Date:** 2026-07-29
**Ticket:** TRA-1045 (blocked by TRA-1046, prod release)
**Branch:** `docs/tra-1045-app-tour-regenerate`

## Problem

The nav restructure (TRA-1029), the RFID/Barcode mode toggle (TRA-1031), and the Scan-tile
declutter (TRA-1036) all shipped to preview. The customer docs still describe the old UI.

Verified against preview `v1.2.0-535-g7cbd1a31` on 2026-07-29:

- `#home`, `#inventory`, and `#barcode` all redirect to `#scan`
- The page header reads **Scan**; the sidebar entry is **Scan**
- The RFID / Barcode mode toggle is live in the Scan toolbar
- With no reconcile list loaded, exactly two tiles render: **Scans** ("Live scan results") and
  **Assets** ("Recognized assets")

Two drifts the ticket's grep could not detect, because they are absences rather than strings:

- `docs/app-tour/inventory.md:19` documents a **Sample** button. It no longer exists. The live
  toolbar is Start · Reconcile · Clear · audio · Share · Save.
- The Scan tab has a **location-tag selector** ("No location tag detected" + Select) that no
  page mentions.

## Scope

**In:** full app-tour regenerate from live observation; org-management authoring; terminology
sweep; redirects; screenshot recapture; an infra-ops passthrough in the justfile.

**Out:** Mustering and Kits (explicitly excluded by the operator); Webhooks (TRA-1048); the
OpenAPI reference, which is fetched live at build; the stale `v1.1` language in
`docs/api/resource-identifiers.md:216` and `docs/api/changelog.md:307`.

The `barcode` hits in `docs/api/*` are the `tag_type` enum value (`rfid` / `ble` / `barcode`),
not the removed tab. They stay.

## Page map — `docs/app-tour/`

| Action | Page |
| --- | --- |
| `git mv` | `inventory.md` → `scan.md` |
| delete | `home.md`, `barcode.md` |
| new | `readers.md`, `live-feed.md`, `outputs.md`, `geofence-defaults.md` |
| rewrite from observation | `index.md`, `locate.md`, `assets.md`, `locations.md`, `reports.md`, `settings.md`, `help.md` |
| update | `authoring.md` |

`sidebars.ts` mirrors the app's own nesting: a **Settings** category (linking to `settings`)
containing Readers, Live feed, Outputs, and Geofence defaults, since that is how the app groups
them under Settings in the sidebar.

`src/components/AppTourGrid.tsx` hardcodes all nine tour entries in an `ENTRIES` array. It is
rewritten to match the new page set.

## Redirects

`@docusaurus/plugin-client-redirects` is **not installed** — `docusaurus.config.ts` has a
`presets` block and no `plugins` array at all. Add the dependency and a `plugins` entry:

- `/app-tour/inventory` → `/app-tour/scan`
- `/app-tour/home` → `/app-tour/scan`
- `/app-tour/barcode` → `/app-tour/scan`

This mirrors the hash-route redirects the app itself performs, all three verified in preview.

## Terminology rules

1. **"Inventory" is reserved vocabulary** for the future Inventory module (one of the four
   capabilities: `inventory`, `geofence`, `mustering`, `kitting`). It must not describe scanning
   anywhere, including common-noun uses such as `docs/user-guide/asset-management.md:4`
   ("save an inventory"). Otherwise this rename is re-done when the module ships.
2. **"Barcode"** survives only as a scan mode and as an API `tag_type`. Never a tab.
3. **"Home"** never names a screen.
4. Tiles are documented in shipped order — **Scans → Assets → Found → Missing → Extra** — with
   the two-tile no-reconcile state stated explicitly.

## Screenshots

### Current state is worse than the ticket describes

- `static/img/user-guide/inventory-scanning.png` is a **full-browser capture including the
  author's personal bookmarks bar** — Gmail, Google Calendar, "Your AI credentials…",
  Jobs/gigs, BizDev, and a profile avatar are all legible. This is published customer
  documentation. It is a privacy defect independent of the UI drift.
- `static/img/user-guide/assets-populated.png` is viewport-only (no leak) but shows placeholder
  asset names — `sss`, `rr`, `qq`, `pp`, `oo`, `nn`, `mm`, `ll`, `kk`, `jj`.
- The set is visually inconsistent: `inventory-scanning.png` is dark theme,
  `assets-populated.png` is light.
- **Every** published app image carries a purple "Preview Environment" band and a `[PRE]` page
  title. No customer's app looks like that.

Therefore recapture covers **every user-guide image showing the app**, not only the two the
ticket names. All captures are viewport-only via Playwright MCP (never full-browser), in a
single consistent theme.

### Capture source: platform local dev

All images are captured against **platform running locally**, not preview. Three properties make
this strictly better than capturing from preview:

1. **Prod-like chrome.** `environmentLabel` comes from `window.__APP_CONFIG__`, injected by the
   backend at serve time (TRA-853). Vite dev has no injection, so the label defaults to `''` and
   `isNonProd('')` is false — no purple banner, page title stays `TrakRF`. Preview cannot
   suppress its banner.
2. **Automated scanner access.** `ble-mcp-test` is already a frontend dev dependency with two
   usable modes. A **bridge server** fronts a real CS108 — one is running on `knuckles.local`,
   verified reachable on WS 8080 and HTTP 8081 — selected via `BLE_MCP_HOST` plus
   `VITE_BLE_BRIDGE_ENABLED=true` (see `frontend/tests/config/ble-bridge.config.ts` and
   `vite.config.ts`). Failing that, the `@ui-only` path needs no hardware at all:
   `navigator.bluetooth.testing.simulateNotification` via
   `frontend/tests/e2e/helpers/trigger-utils.ts`, plus `connectToDevice()` /
   `waitForConnectionStatus()` in `helpers/connection.ts`.

   Prefer the bridge with real hardware — genuine EPCs, signal strengths, and read counts beat
   synthesized ones in customer documentation. Fall back to simulation if the reader is
   unavailable, and say which was used in `authoring.md`.
3. **No writes to shared preview.** Seeding targets the local database, so BB tests are
   untouched, no superadmin action is needed, and the "preview re-roll wipes the seeded org"
   risk disappears.

The cost is a heavier prerequisite: a platform checkout plus Docker (`just dev` brings up the
database and backend and runs migrations). `authoring.md` documents this, including the
requirement to run the commit that ships in TRA-1046 so the docs match what users get.

Launch is `just frontend dev-bridge` (→ `VITE_BLE_BRIDGE_ENABLED=true node scripts/dev-bridge.js`),
which connects the app to the physical reader through the bridge. This needs no additional
setup: `scripts/dev-bridge.js:34` resolves `BLE_MCP_HOST || BLE_MCP_WS_HOST || 'localhost'`, and
`BLE_MCP_HOST` is already set in `~/platform/.env.local` (loaded by `.envrc` via
`dotenv_if_exists`, so every recipe in the platform tree inherits it). The
`public/web-ble-mock.bundle.js` symlink into `node_modules` is likewise already in place.

Bridge settings live at the platform root, not in `frontend/.env.local` — the latter does not
exist. Alongside the host, the root file sets `BLE_MCP_WS_PORT`, `BLE_MCP_HTTP_PORT`,
`BLE_MCP_HTTP_TOKEN`, and `BLE_DEVICE_NAME=CS108`.

The sidebar renders a version string, which will differ in local dev. Confirm what it shows and,
if it reads as a dev artifact, note it rather than pretending otherwise.

### Seeded org

Seeded into the **local** database via SQL, using the schema's own helpers rather than raw
INSERTs:

- `trakrf.create_asset_with_tags(p_org_id, p_external_key, p_name, p_description, p_valid_from,
  p_valid_to, p_is_active, p_metadata, p_tags)`
- `trakrf.create_location_with_tags(...)` — same shape plus `p_parent_location_id`

Ids need no manual minting: `generate_obfuscated_id()` is a BEFORE-INSERT trigger.

Asset names are plausible trackable equipment — Camera, Laptop, Tablet, Projector, Toolbox,
Pallet Jack — across a small location tree (Receiving / Warehouse A / Bay 3 / Office / Lab).
This replaces both the empty docs-tour org and the BB-contaminated Organized Chaos, which holds
rows such as `BB54-PY-CODEGEN-2` and `BB-1778367224-BB-ok`.

The account is created by signing up through the local UI, so `org_users` membership and org
defaults are built by the app rather than hand-assembled.

The capability grant is a single row:

```sql
insert into trakrf.org_capabilities (org_id, capability, granted_at)
values (:org_id, 'geofence', now());
```

Without it the org starts at zero grants (TRA-1024, no backfill) and Outputs and Geofence
defaults render as locked upsell pages, making them undocumentable. Grant only `geofence` —
leaving `mustering` and `kitting` ungranted keeps those surfaces out of the captures, matching
the agreed scope.

The seed is checked in as `scripts/seed-docs-org.sql` so the whole environment is reproducible.

### Known artifacts in captures

A locked **Mustering** tile ("Not enabled for your organization") appears in every
nav-inclusive screenshot. This is accurate — it is what a real ungranted org sees — and is left
as-is rather than engineered away.

### Reconcile state

The seeded asset list plus simulated tag reads make the **five-tile** reconcile state reachable
(Scans → Assets → Found → Missing → Extra). Without a loaded list and a connected reader, only
the two-tile state can be captured.

## Org management

`docs/user-guide/organization-management.md` is currently a 13-line "Coming Soon" stub. It is
authored from live observation as +t2, covering the account-menu surface: Organization Settings,
Members, API Keys, and Create Organization.

**Webhooks is excluded** — it belongs to TRA-1048.

Note that TRA-891 settled that the users and org-admin *API* surfaces are internal-only. That
constrains the API docs, not this UI walkthrough, but the prose must not imply a public API for
membership management.

## Infra-ops passthrough

Copy the TRA-1053 delegation pattern from `~/platform/justfile` into the docs repo: `psql`,
`logs`, `gcp-auth`, and a general `ops <cmd>`, each forwarding to the infra justfile via
`just --justfile "$infra_dir/justfile"`. The pattern deliberately does not restate cluster,
namespace, or CNPG knowledge, and does not mirror infra's recipe names.

The sibling-directory fallback (`$(dirname main_worktree)/infra`) does **not** resolve on this
machine — the checkout is `~/trakrf-infra`, not `~/infra`. So `TRAKRF_INFRA_DIR` must be set in
`.env.local`, and documented in `.env.example`. Platform already depends on this.

Related, out of scope, worth filing: `PG_URL_PREVIEW` in `~/platform/.env.local` is stale. It
points at Timescale Cloud, which refuses connections; preview is CNPG on GKE now.

## Verification

- `pnpm build` clean, no broken internal links
- No `Inventory`, `Barcode`, or `Home` as a tab or screen name under `docs/`
- No `Not Listed`, `Total Scanned`, or `Saveable` anywhere
- Tile docs match shipped order and the two-tile no-reconcile state
- All three redirects resolve
- No browser chrome or personal data in any published image
- Screenshots show plausible equipment names, not placeholder strings

## Sequencing and risk

The PR **opens but does not merge** until TRA-1046 deploys this UI to prod, so docs never
describe a UI users lack. Because sync-preview re-merges open PRs, the work is reviewable on the
preview docs site throughout the hold.

Preview re-rolls will wipe the seeded org; `scripts/seed-docs-org.sql` plus a note in
`authoring.md` is the mitigation.
