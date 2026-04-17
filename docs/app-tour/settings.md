---
sidebar_position: 8
title: Settings
description: Configure device and application settings.
---

# Settings

## Desktop

![Settings desktop screenshot](/img/app-tour/settings-desktop.png)

## Mobile

![Settings mobile screenshot](/img/app-tour/settings-mobile.png)

## What this page does

Settings is titled "Device Setup" because its primary job is pairing a handheld reader. The top **Device Connection** card shows the device status (a red "Disconnected" on a fresh setup with no paired reader) and a **Connect Device** button that initiates Web Bluetooth pairing. Below that, **Basic Settings** exposes a **Signal Power** slider from Low through Medium to High (shown in dBm — e.g. 30 dBm), and an **Advanced Settings** collapsible panel holds the rest of the RFID protocol knobs.

## How it fits in the app

Settings is the only tab that directly changes how the handheld reader behaves — signal power affects read range and battery life, and advanced settings cover session, query, and antenna tuning. The scanning tabs (Inventory, Locate, Barcode) all inherit whatever is configured here, so changes made on this page ripple everywhere.

:::note
This page was generated as a first-pass tour. Human enhancement welcome.
:::
