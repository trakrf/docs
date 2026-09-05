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

## v1.5.0 — September 4, 2026 {#v1-5-0}

Locate is the focus of this release. It could previously show you a signal from a search you had already finished, keep moving after you let go of the trigger, and — in the case that mattered most — look like it had found something when it had found nothing. All of that is fixed. You can also now acquire a Locate target by scanning a barcode, and Settings tells you which reader you are connected to.

### Locate tells you the truth about what it is hearing {#v1-5-0-locate}

Three separate problems could each make a failed search look like a successful one.

A search that ended without hearing the tag used to leave the previous search's reading on the gauge, so an item that was not there could show a strong signal. Readouts now fall to **No signal** rather than holding a number that is no longer being measured.

Changing the target in the middle of a search did not always reach the reader. The reader went on filtering for the tag you started with, so you were shown another item's signal under your new target's name. A target change now reaches the reader before the search runs, and if it cannot, Locate says so instead of searching for the wrong thing.

Releasing the trigger did not stop the search cleanly. The gauge kept moving and the audio kept sounding for a moment after you let go. The audio now stops on release, and the gauge **freezes at the reading you released on** — you pulled the trigger to read that number, so it stays on screen rather than blanking. If the tag was not being heard when you released, the gauge holds **No signal** instead of reviving the last value it heard.

Locate also now finds tags whose identifier is stored in short form. These previously matched at only one tag size, so a tag could be searched for under a value that did not match it.

### Acquire a Locate target by scanning a barcode {#v1-5-0-locate-barcode}

You no longer have to type a 24- or 32-character tag identifier to start a Locate search. Scan the barcode instead.

The workflow this is for is not scanning the tag you are standing next to — it is working from a cut sheet, pick list or work order that carries the barcode of the item you have been sent to find. Scan the paperwork, then go and find the thing.

### Settings shows which reader you are connected to {#v1-5-0-reader-details}

Settings now lists the connected reader's serial number and its three firmware versions. If you contact support about a reader, this is the page to read from — previously there was no way to tell from the app which firmware a reader in the field was running.

### Tags scanned before you sign in are no longer lost {#v1-5-0-scan-before-login}

You can scan tags without signing in, then sign in to see which assets they are. Signing in was clearing those tags before it looked them up, so the list came back empty and the scan was gone. Your scan now survives signing in, and the asset details fill in behind it.

Switching organizations still clears scanned tags, as it always has — those results belong to the organization you were in.

### Accounts set up for you must choose their own password {#v1-5-0-password}

When someone sets up your account in person and gives you a starting password, TrakRF now asks you to choose your own the first time you sign in, and the app waits until you have. Nothing changes for any existing account — you will not be asked to change a password you already chose.

### A more reliable reader connection {#v1-5-0-reader-reliability}

A number of faults that made the reader look broken, unresponsive, or randomly unreliable are fixed. The most visible effect is that the reader recovers from a momentary problem instead of reporting an error it has already recovered from, and a reader that is refusing a command now says so rather than going quiet.

### Smaller changes {#v1-5-0-smaller}

- Location history is recorded to the minute rather than to the second. A move can take up to a minute to appear on reports; in exchange the history is far smaller and faster to read.
- Saving from the Scan tab while a fixed reader is reading the same asset in the same minute no longer fails.

## v1.4.1 — August 13, 2026 {#v1-4-1}

### Change your password from your profile {#v1-4-1-change-password}

You can now change your password from **Account menu → Profile** by entering your current one, without going through the forgotten-password email. This matters if your organization's mail system holds or blocks our messages — until now that email was the only way to change a password you knew.

## v1.4.0 — August 9, 2026 {#v1-4-0}

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
