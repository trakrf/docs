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
