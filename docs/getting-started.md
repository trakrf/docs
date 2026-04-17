---
sidebar_position: 1
---

# Getting Started

Welcome to TrakRF — the RFID asset tracking platform built for handheld readers and the browser.

This page takes you from "I just signed up" to "I've saved my first scan" in about 15 minutes, assuming you have a supported RFID reader in hand. Each step links to a deeper page if you want more detail.

## What you'll need

- A supported handheld reader: **CS108** or **CS463**.
- A Chromium-based browser (Chrome, Edge, or Opera) on the device that'll talk to the reader. Safari and Firefox don't support the Bluetooth APIs TrakRF uses.
- A few RFID tags attached to things you want to track — even a handful of stick-on labels on nearby objects is enough to follow along.

:::note Browser support
TrakRF is a web app. There's no install — you just open it in a browser — but that browser must be Chromium-based. More detail in [Reader Setup](./user-guide/reader-setup#browser-support).
:::

## 1. Create your account

1. Go to [app.trakrf.id](https://app.trakrf.id) and click **Sign up** (or navigate directly to `/#signup`).
2. Fill in your name, email, password, and an **Organization** name. The organization is the top-level container for your assets, locations, and teammates — use your company name or a project name.
3. Verify your email when prompted and sign in.

You'll land on the **Home** dashboard — a device-status summary, links to **Inventory / Locate / Barcode**, and a "Watch Demo" card.

## 2. Pair your reader

Detailed in [Reader Setup](./user-guide/reader-setup). The short version:

1. Power on your CS108 or CS463 and put it in pairing mode.
2. In TrakRF, go to **Settings** in the left nav.
3. Click **Connect Device** and pick your reader from the browser's Bluetooth dialog.
4. Watch the **Device Status** pill flip from **Disconnected** to **Connected**.

Chromium remembers the pairing, so subsequent sessions on the same browser profile won't need to re-pair.

## 3. Set up your first location and asset

Before your first scan means anything, give TrakRF a place to put things and at least one thing to find.

1. **Locations** → create a root location (e.g. "Main Warehouse"). See [Asset Management: step 1](./user-guide/asset-management#1-create-a-location).
2. **Assets** → click **Create Asset**, give it a name, pick the location, and paste the EPC (tag number) of one of your RFID tags under **RFID Tags**. See [Asset Management: step 2](./user-guide/asset-management#2-register-an-asset).

:::tip Don't know your tag EPCs?
Skip ahead to step 4 and scan first — unregistered tags show up under **Not Listed**. You can copy the EPC from there into a new asset record afterwards.
:::

## 4. Run your first scan

1. Open **Inventory** (left nav). Confirm the device-status chip reads **Connected**.
2. Press and hold the handheld's trigger. Tags in range stream into the **Scanned** list in real time.
3. Release the trigger when you've covered your area.
4. Click **Save** in the top toolbar to commit the session.

Full detail: [Asset Management: step 3](./user-guide/asset-management#3-run-a-scan-session).

## 5. See what you captured

Open **Reports** to see your saved scan rolled up into **Locations History** and **Asset History**. Filter by time (**Today**, **Last 7 days**, **Stale**) to answer "what did we actually see, and when?"

More: [Asset Management: step 5](./user-guide/asset-management#5-review-in-reports).

## Where to go next

- [Reader Setup](./user-guide/reader-setup) — deeper reader pairing and troubleshooting.
- [Asset Management](./user-guide/asset-management) — the full scan-to-report walkthrough.
- [App Tour](/docs/app-tour) — one page per screen in the app, with screenshots.
