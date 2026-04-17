---
sidebar_position: 1
title: Reader Setup
description: Pair a CS108 or CS463 handheld RFID reader with TrakRF over Web BLE.
---

# Reader Setup

TrakRF pairs with supported RFID readers directly from the browser using Web Bluetooth (Web BLE). No driver install, no companion app — you click **Connect Device**, pick your reader from the OS pairing dialog, and you're scanning.

## Before you start

### Browser support

Web BLE is a Chromium feature. TrakRF works in:

- **Google Chrome** (desktop and Android)
- **Microsoft Edge**
- **Opera**

Safari and Firefox do **not** support Web BLE and will show a "Supported browsers: Chrome, Edge, Opera" banner in place of the connect button.

### Bluetooth permissions

- **Desktop** — make sure Bluetooth is on in the OS and the browser has permission to access it.
- **Android** — Chrome needs **Location** permission on first pair (Android ties BLE scans to location). Grant it when prompted; you won't be asked again.
- **HTTPS required** — Web BLE only works over HTTPS. The hosted TrakRF app is HTTPS by default, so this only matters if you're running a local build.

### Supported readers

TrakRF currently supports two handhelds:

- **CS108** — Convergence Systems, UHF, BLE-based.
- **CS463** — Convergence Systems, UHF, BLE-based. (CS463 is the newer/larger-form-factor sibling.)

Both pair through the same flow.

## Pair your reader

1. Power on the reader and make sure it's in Bluetooth pairing mode.

   :::note Hardware-specific steps
   **CS108** — TODO: button / LED sequence to enter pairing mode, plus any battery / charge caveats.

   **CS463** — TODO: same, and call out any differences from the CS108.
   :::

2. In TrakRF, open **Settings** (left nav). You'll land on the **Device Setup** page, which has a **Device Connection** card at the top.

3. Click **Connect Device**.

4. Your browser opens the OS Bluetooth pairing dialog. Pick your reader by name (it typically advertises as `CS108Reader-xxxxxx` or `CS463Reader-xxxxxx`) and click **Pair**.

5. The page-status chip in the top-right flips from **Disconnected** (red) to **Connected** (green), and the **Device Status** pill in the left sidebar updates to match.

6. The reader is now paired to this browser on this device. Chromium remembers the pairing, so you won't have to pick it from the OS dialog again unless you clear site permissions.

## Adjust basic settings

Once connected, the **Basic Settings** card on the same page exposes:

- **Power** slider — a 0–30 dBm value controlling the reader's RF output. Higher power = longer read range but more cross-reads from neighbouring shelves. 30 is the default.

  :::note
  TODO: confirm exact power units and any per-model caps (the CS108 and CS463 may not share the same max).
  :::

The **Advanced Settings** section (collapsed by default) holds session/query tuning for denser environments. Most users won't need to touch it.

## Troubleshooting

:::note
TODO: capture the common failure modes once they're understood — reader won't appear in pairing dialog, reader disconnects mid-scan, trigger does nothing, Android-specific gotchas, etc. A short FAQ-style list is the most useful shape here.
:::

A few quick checks to try first:

- Reload the tab. Web BLE sometimes drops silently after sleep/resume on macOS.
- Re-seat the reader battery. A low battery can let pairing succeed but fail mid-scan.
- Try a different browser profile — stale permissions are the usual cause of "it worked yesterday."

## What's next

- [Asset Management](./asset-management) — register assets and run your first scan.
- [App Tour: Settings](/docs/app-tour/settings) — visual reference for every control on this page.
