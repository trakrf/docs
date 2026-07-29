---
sidebar_position: 10
title: Geofence defaults
description: Org-wide geofence tuning applied to every portal.
---

# Geofence defaults

## Desktop

![Geofence defaults desktop screenshot](/img/app-tour/geofence-defaults-desktop.png)

## Mobile

![Geofence defaults mobile screenshot](/img/app-tour/geofence-defaults-mobile.png)

## What this page does

Geofence defaults sets four org-wide values that every output falls back to unless it sets its own: an **RSSI threshold** in dBm (minimum signal strength for an output to react — stronger is closer to 0), an **Age-out** in seconds (the re-arm window before an egress output can fire again on the same tag, or how long a presence output waits after the last read before clearing), an **Auto-off** in seconds (how long before an egress device flips itself off on its own; 0 means stay on until manually reset), and a **Mode** (**System default (egress)**, **Egress**, or **Presence**). Leaving a field blank falls back to the system default rather than to zero.

Geofence defaults is enabled per organization. Organizations without it see a locked page in its place, reading that the feature isn't enabled for their organization and directing them to contact `support@trakrf.id` — a padlock next to **Geofence defaults** in the sidebar is expected in that case, not a bug.

## How it fits in the app

These are the fallback values **Outputs** uses when an individual output doesn't set its own RSSI threshold, age-out, auto-off, or mode — tune coverage once here instead of on every device.
