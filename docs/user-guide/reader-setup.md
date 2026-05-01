---
sidebar_position: 1
title: Reader Setup
description: Pair a CS108 handheld RFID reader with TrakRF over Web BLE.
---

# Reader Setup

TrakRF pairs with supported RFID readers directly from the browser using Web Bluetooth (Web BLE). No driver install, no companion app — you click **Connect Device**, pick your reader from the OS pairing dialog, and you're scanning.

## Before you start

### Browser support

Web BLE is a Chromium feature. TrakRF works in:

- **Google Chrome** (desktop and Android)
- **Microsoft Edge**
- **Opera**
- **[Bluefy](https://apps.apple.com/us/app/bluefy-web-ble-browser/id1492822055)** (iOS/iPadOS) — free from the App Store. iOS Safari doesn't expose Web BLE, and Chrome/Edge on iOS are Safari under the hood, so Bluefy is the only option on iPhone and iPad.

Desktop Safari and Firefox do **not** support Web BLE and will show a "Supported browsers: Chrome, Edge, Opera" banner in place of the connect button.

### Bluetooth permissions

- **Desktop** — make sure Bluetooth is on in the OS and the browser has permission to access it.
- **Android** — Chrome needs **Location** permission on first pair (Android ties BLE scans to location). Grant it when prompted; you won't be asked again.
- **HTTPS required** — Web BLE only works over HTTPS. The hosted TrakRF app is HTTPS by default, so this only matters if you're running a local build.

### Supported readers

TrakRF currently supports the **CS108** handheld from Convergence Systems (UHF, BLE).

:::note Fixed readers
The Convergence **CS463** fixed reader shares the CS108 API and has a BLE radio, but in practice it's driven over its HTTP API / web UI rather than Web BLE. Fixed-reader workflows are out of scope for this guide.
:::

## Pair your reader

1. Power on the CS108 — hold the power button for ~3 seconds until the **green** power LED lights solid. The Bluetooth indicator starts flashing automatically on power-up, meaning the reader is advertising and ready to be discovered; there's no separate pairing-mode button.

   :::tip First-time battery
   A fresh CS108 battery wants roughly a 4-hour initial charge. The charge LED is **red** while charging and goes out when full. Seat the battery with its metal contacts facing **down**.
   :::

2. In TrakRF, open **Settings** (left nav). You'll land on the **Device Setup** page, which has a **Device Connection** card at the top.

3. Click **Connect Device**.

4. Your browser opens the Web BLE pairing dialog. Pick your reader by name — it advertises as `CS108ReaderXXXXXX`, where `XXXXXX` is the last six hex digits of its MAC — and click **Pair**.

   ![Chrome Web BLE pairing dialog showing a CS108 reader](/img/user-guide/pairing-dialog.png)

5. The page-status chip in the top-right flips from **Disconnected** (red) to **Connected** (green), and the **Device Status** pill in the left sidebar updates to match.

6. The reader is now paired. OS-level pairing happens once per device; from then on, clicking the status button in TrakRF reopens the browser's connect dialog with the reader already listed — just select it and confirm to reconnect. You only need to re-pair through System Settings / Control Panel if you explicitly **forget** the device.

## Adjust basic settings

![Device Setup page with a CS108 connected — green Device Connection card, battery %, and the Signal Power slider](/img/user-guide/settings-connected.png)

Once connected, the **Basic Settings** card on the same page exposes:

- **Signal Power** slider — controls the reader's transmit power in **dBm EIRP**. The CS108 supports roughly **+10.0 to +30.0 dBm** (and up to **+31.5 dBm** in some regions / with certain power supplies), so the practical range is constrained by your regulatory region — FCC, ETSI, etc. The slider is marked **Low / Medium / High** and shows the current value (e.g. `30 dBm`) on the right. Higher power = longer read range, but also more cross-reads from neighbouring shelves. Start at the max and dial back if you're picking up tags you don't want.

  :::note
  The on-screen slider currently runs from 0 to 30 dBm; alignment with the hardware's real floor of +10 dBm is in progress.
  :::

The **Advanced Settings** section (collapsed by default) holds session/query tuning for denser environments. Most users won't need to touch it.

## Troubleshooting

Most pairing and connection issues resolve with the same small set of steps. Try them in order:

1. **Power-cycle the reader.** Hold the power button until the green LED goes out, wait a few seconds, power it back on. The BLE indicator should start flashing again.
2. **Reload the TrakRF tab**, then click the status button to retry the connect. Web BLE sometimes drops silently after sleep/resume — especially on macOS.
3. **Restart the host's Bluetooth stack.** Toggle Bluetooth off and back on in the OS (or use the airplane-mode trick on mobile).
4. **Forget and re-pair.** Open your OS's Bluetooth settings — **System Settings → Bluetooth** on macOS, **Settings → Devices → Bluetooth** on Windows, the Bluetooth panel under Android/iOS settings — find the `CS108ReaderXXXXXX` entry, remove/forget it, then run through the pair flow above from scratch.
5. **Check battery seating and charge.** A low battery can let pairing succeed and then fail mid-scan. Re-seat the pack (metal contacts down) and confirm it's charged — red LED while charging, dark when full.
6. **Try a different browser profile.** Stale site permissions are the usual cause of "it worked yesterday." A fresh profile sidesteps them without touching your main one.

## What's next

- [Asset Management](./asset-management) — register assets and run your first scan.
- [App Tour: Settings](/docs/app-tour/settings) — visual reference for every control on this page.
