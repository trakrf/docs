---
sidebar_position: 2
title: Asset Management
description: Register assets, scan them, save an inventory, and review history.
---

# Asset Management

This walkthrough covers the end-to-end asset flow: creating a location, registering an asset with an RFID tag, running a scan session on the **Inventory** screen, saving the results, and reviewing them in **Reports**.

If you haven't paired a handheld reader yet, finish [Reader Setup](./reader-setup) first — steps 3–4 below require a connected reader.

## 1. Create a location

Locations are where assets live (a room, a shelf, a truck). TrakRF supports a hierarchical tree, so you can nest "Warehouse A → Aisle 3 → Shelf B" if you want — but for your first pass, one root location is enough.

1. Open **Locations** from the left nav.
2. If this is a fresh organization you'll see "No locations found. Create a root location to get started."

   ![Empty Locations page — empty tree, prompt to create a root location, and floating + button](/img/user-guide/locations-page.png)

3. Click the floating **+** button (bottom-right) to open the create dialog.
4. Enter a name — keep it short and human-readable ("Main Warehouse" works fine).
5. Save.

The new location shows up in the tree on the left; the right pane becomes a detail view for whichever location you select. With a few locations registered, the page looks like this:

![Populated Locations page — tree with multiple root nodes and active/inactive counts](/img/user-guide/locations-populated.png)

## 2. Register an asset

Assets are the records TrakRF checks scans against. Each asset has at least one RFID tag number (EPC), plus optional metadata — name, description, home location, active window.

1. Open **Assets** from the left nav. On a fresh org you'll see a "No assets yet" empty state with a **Create Asset** button.

   ![Empty Assets page — No assets yet, Create Asset CTA, and footer cards](/img/user-guide/assets-page.png)

2. Click **Create Asset** (in the empty-state card) or the floating **+** button.
3. Fill in the **Create New Asset** modal:

   ![Create New Asset modal — Asset ID, Name, Description, Location, Active, Valid From/To, RFID Tags](/img/user-guide/create-asset-modal.png)
   - **Asset ID** — leave blank to auto-generate as `ASSET-XXXX`, or type your own (e.g. a part number).
   - **Name** — required. This is what you'll see in scan results and reports.
   - **Description** — optional free text.
   - **Location** — pick the one you created in step 1. Leave as "No location assigned" if you want it to appear under the **Unassigned** filter.
   - **Active** — checked by default. Uncheck to hide the asset from live scan comparisons without deleting it.
   - **Valid From / Valid To** — defaults to today / blank. Use these if the asset is only in circulation for a known window.
   - **RFID Tags** — click **Add Tag** and paste or type the tag's EPC (hex string). You can attach more than one tag to the same asset.

4. Click **Create Asset**.

The asset now appears in the list. The footer cards (**Total Assets**, **Active**, **Inactive**) update immediately. After a few assets, the list looks like this:

![Populated Assets list — table with Asset ID, Name, Location, Tags, Status, Actions columns and a Share action](/img/user-guide/assets-populated.png)

:::tip Bulk-import via scan
If you have a pile of already-tagged items and no spreadsheet of EPCs, it's often faster to scan them first (step 3) and then use **Assets** to attach names to the tags you captured. The scanner doesn't require an asset record to read a tag — it'll just show the raw EPC under "Not Listed" until you register it.
:::

## 3. Run a scan session

With an asset registered and a reader paired (see [Reader Setup](./reader-setup)), you're ready to scan.

1. Open **Inventory** from the left nav.

   ![Inventory page ready to scan — device connected (89%), empty Scanned list, full toolbar, empty footer stats](/img/user-guide/inventory-connected-idle.png)

2. Confirm the device-status chip in the top-right reads **Connected**, not **Disconnected**.
   - On a supported browser with no paired reader, the banner reads "Connect your device to start scanning" and the **Connect Device** button is live.
   - On an unsupported browser (no Web BLE), the banner lists the supported browsers instead and **Connect Device** is disabled — see [Reader Setup: browser support](./reader-setup#browser-support).
3. (Optional) Click **Select** under "No location tag detected" to tell TrakRF which location this scan represents. Scanning a location tag with the reader does the same thing automatically.
4. Press and hold the handheld's trigger. Tags in range stream into the **Scanned** list in real time. The footer cards update live:
   - **Found** — tags that match an expected list (only populated if you've uploaded a CSV of expected tags).
   - **Missing** — tags on the expected list that haven't been seen yet.
   - **Not Listed** — tags seen that don't match anything expected.
   - **Total Scanned** — unique EPCs seen this session.
   - **Saveable** — of those, how many match a registered asset.
     ![Inventory mid-scan — 12 tags captured at Bay 7 Shelf 1 via location tag, per-row signal and count](/img/user-guide/inventory-scanning.png)

5. Release the trigger when you've covered the area. The list stays on screen; you can resume by pressing the trigger again.
6. Use the top toolbar as needed:
   - **Start** — software-trigger equivalent of holding the hardware trigger; handy for bench testing or when you want hands-free scanning.
   - **Sample** — shorter burst; useful for spot checks.
   - **Reconcile** — marks the current scan as a reconciliation against an expected list.
   - **Clear** — wipes the in-progress list without saving.
   - **Off / On** — audio feedback toggle.

## 4. Save the session

Once the scan looks right, click **Save** in the top toolbar. This commits the session to history and attaches it to the selected location. The **Share** button next to **Save** generates a link you can send to a teammate — useful for handing off a cycle count or flagging discrepancies.

Saving is what promotes a scan from "live on my screen" to "part of the audit trail." Reports and asset history only reflect saved sessions.

## 5. Review in Reports

1. Open **Reports** from the left nav.

   ![Reports page with two assets in Locations History at Bay 7 Shelf 1, both seen today](/img/user-guide/reports-populated.png)

2. The top stat cards show **Total Assets Tracked**, **Assets Seen Today**, and **Stale Assets (> 7 days)** — a quick-read summary of your catalog's recency.
3. Switch between **Locations History** (which locations saw which assets) and **Asset History** (per-asset timeline).
4. Filter by:
   - Asset name (search box)
   - Location (dropdown)
   - Time window — **All Time**, **Live (\< 15min)**, **Today**, **Last 7 days**, **Stale (\> 7 days)**.
5. Click **Share** to hand a filtered view to a teammate.

## Find a specific tag

Inventory answers "what's here?" **Locate** answers "where is this one?" Paste or type the EPC of the tag you're hunting for (or jump over from an asset's row action) and TrakRF turns the reader into a metal detector: a signal-strength gauge, peak/average stats, and an audio-feedback option whose pitch **and** beep rate both climb as you close the distance.

![Locate screen searching for EPC 10019 — signal-strength gauge reading -31 dBm, stats panel, audio feedback on](/img/user-guide/locate-searching.png)

Use it for single-item retrieval after an inventory scan has flagged something as missing or misplaced.

## What's next

- [Location Tracking](./location-tracking) — deeper coverage of the location tree and location-tag workflows.
- [Reports & Exports](./reports-exports) — pulling scan data out of TrakRF.
- [App Tour](/docs/app-tour) — screen-by-screen reference for every page touched above.

:::note Work in progress
This walkthrough describes the happy path for a single-location, single-reader setup. Multi-location workflows, CSV-driven reconciliation, and bulk tag commissioning are covered in [Location Tracking](./location-tracking) and [Reports & Exports](./reports-exports) — flesh those out as needed.
:::
