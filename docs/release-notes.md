---
title: Release notes
description: What changed in the TrakRF app, newest first.
---

# Release notes

What changed in the TrakRF app, newest first. Every entry describes something you can see or do differently as a user of the app.

Two related logs cover different ground:

- The [API changelog](./api/changelog) tracks the public `/api/v1/` contract for integrators writing code against TrakRF. It follows the API's own version, which moves independently of the app version on this page.
- The release notes here follow the platform version reported by the app itself.

Most releases change nothing you would notice, and those are not listed. A release appears on this page when it changes something in front of you.

## v1.4.0 — August 7, 2026 {#v1-4-0}

The Assets screen was showing you only part of your data, and a saved scan took up to two minutes to appear on Reports. Both are fixed. Locate now works with 128-bit tags, and you can edit your own name and email.

### The Assets screen shows every asset {#v1-4-0-assets}

The Assets screen only ever loaded the first 25 assets. The list, the result count above it, and the summary tiles were all built from that first 25 — as was every export, so a CSV, XLSX, or PDF download from a 400-asset organization contained 25 rows and gave no sign anything was missing. All of it now reads your full asset set.

Separately, assets could linger after they were no longer yours to see. Switching organizations, or deleting an asset in another browser session, left the old rows on screen for up to an hour, sometimes as apparent duplicates of an asset you did still have. The screen now rebuilds from each load rather than accumulating across them.

If you exported asset data from TrakRF before this release, re-export it — the earlier file was almost certainly incomplete.

### A saved scan appears on Reports immediately {#v1-4-0-report-freshness}

Saving from the Scan tab and going straight to the asset locations report used to show those assets at their _previous_ location — often hours or days old — for up to two minutes before catching up. The save itself was always recorded correctly and completely; only the report lagged behind it. The report now includes the most recent scans as it loads, and reopening it after a save refetches rather than reusing a cached view, so what you just saved is there when you arrive.

### Locate works with 128-bit tags {#v1-4-0-locate}

Locate could not reliably find tags with 128-bit EPCs. It matched only the first 96 bits, so every tag off the same reel looked identical to it and it homed in on whichever one it happened to hear; tags whose EPC began with a zero were searched for under the wrong value entirely. Locate now matches the full EPC.

Locate also no longer reports "No signal" while reads are arriving. The first **Start** click after opening Locate could fail silently and leave the signal gauge empty even though the reader was working.

### Edit your own name and email {#v1-4-0-profile}

You can now change your own display name and email address from **Account menu → Profile**, without asking an administrator. Changing your email notifies the old address as well as the new one, so an unexpected change doesn't go unnoticed.

### Clearer guidance when a reader won't connect {#v1-4-0-bluetooth}

TrakRF now tells you _why_ a reader can't be connected rather than failing generically. A missing Bluetooth adapter, a browser without Web Bluetooth support, and a browser that supports it but has it switched off each say so specifically and tell you what to do next. On an iPhone or iPad, where Apple allows only its own browser engine and so no Safari-based browser can reach Bluetooth, TrakRF points you to Bluefy and can reopen the current page there.

On Windows, a CS108 that hasn't yet been paired in Windows itself appears in the browser's device chooser as "Unknown or unsupported device" followed by a string of numbers, rather than by name. Those numbers are the reader's Bluetooth address, printed on the label on the back of the antenna as **BT Mac Addr**, so you can check the device is yours before selecting it. Adding the reader in **Settings → Bluetooth & devices** first makes it list by name instead. Help now explains this before you run into it — see [Reader Setup](./user-guide/reader-setup#windows-first-connect).

### Smaller changes {#v1-4-0-smaller}

- Readers, Live Reads, Outputs, and Kits show a title in the header; those screens previously opened with a blank one. Live Reads no longer calls a scan an "inventory."
- Account and permission handling has been tightened internally. No action is needed on your part, and nothing you do changes.

## v1.3.0 — July 30, 2026 {#v1-3-0}

The first substantial update since TrakRF moved to production in May. Scanning was reworked, the asset locations report gained dwell time, webhooks arrived, and several problems that made scanning and reporting unreliable are fixed.

### Inventory is now Scan {#v1-3-0-scan}

The Inventory tab is renamed **Scan**, and the separate Home and Barcode tabs are gone. Barcode is now a mode toggle inside Scan, sitting next to RFID, so you switch between reading a single barcode and sweeping every tag in range without leaving the page. Your status filter is remembered between visits.

Existing bookmarks and links to Home, Inventory, or Barcode still work — they land on Scan.

The summary tiles below the results list are labelled **Scans**, **Assets**, **Found**, **Missing**, and **Extra**. Scans and Assets are always shown. Found, Missing, and Extra appear once you run **Reconcile** against an uploaded CSV of the tags or assets you expected to find, and show which expected items turned up, which did not, and which scanned tags were not on your list at all.

### Save records exactly what the view shows {#v1-3-0-save}

Saving a scan now persists precisely the rows in front of you — the same list, under the same filter. Items that appear only as reconciliation results, because they were expected but never actually read, are deliberately excluded from the saved scan. What you see is what gets stored.

### Dwell time on the asset locations report {#v1-3-0-dwell}

The asset locations report now shows how long each asset has been where it is. Dwell is measured across the time the asset was actually observed at that location rather than as the age of a single sighting, so it reflects an ongoing stay. It makes assets that have sat in staging, shipping, or a repair bay longer than they should stand out without cross-checking timestamps by hand.

### Webhooks tell you when an asset moves {#v1-3-0-webhooks}

You can now register an HTTPS endpoint of your own and have TrakRF call it whenever an asset is scanned at a location different from where it was last seen. Set one up from the **Account menu → Webhooks**; each organization can have one.

Deliveries are signed, so your receiving system can verify a call genuinely came from TrakRF. Because the notification fires on movement, rescanning an asset where it already is sends nothing. Setup instructions and the exact payload are in [Webhooks](./api/webhooks).

### Scanning and reporting are more reliable {#v1-3-0-reliability}

- The asset locations report no longer intermittently fails to load.
- Scan and Locate no longer break after a new version of the app is released. Previously a tab left open across a release could fail to open part of the app until you reloaded it.
- Geofence alarms no longer re-fire for tags that were already inside the zone when the geofence engine restarts.

### New surfaces that your organization can enable {#v1-3-0-capabilities}

Kits, Outputs, and Geofence defaults ship in this release but start switched off for every organization. If you see one of these as a locked tile, it marks a feature arriving rather than one taken away — contact TrakRF to have it enabled for your organization.
