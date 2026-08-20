---
sidebar_position: 2
title: Locate
description: Find a specific item by walking the area with a handheld reader.
---

# Locate

## Desktop

![Locate desktop screenshot](/img/app-tour/locate-desktop.png)

## Mobile

![Locate mobile screenshot](/img/app-tour/locate-mobile.png)

## What this page does

Locate is a proximity finder for a single tag. You paste a **Tag EPC Identifier** into the field, then either press the on-screen **Start** button (enabled once a reader is connected) or press and hold the physical trigger — both begin the same search. A semicircular **Signal Strength** gauge, scaled in dBm from -100 to -20 and banded red-to-green, updates in real time as you walk: stronger signal means the tag is closer. A **Statistics** panel tracks Current / Average (1s) / Peak readings, an update rate in Hz, and an overall Status (Idle / Searching); a rolling 10-second signal history appears alongside it whenever the tag is being heard. An **Audio Feedback** toggle, on by default, plays a tone whose pitch rises with signal strength so you don't need to look at the screen while hunting.

The gauge, Current, Average, Peak, and Update Rate all follow the live read stream rather than the search itself — when reads stop, or you retarget to a different EPC, they fall back to **No signal** and 0 Hz rather than holding the last value, so a reading on screen always means the tag is being heard right now. Status still shows **Searching** while a search is running even when nothing is coming back, and the line under the EPC field deliberately keeps the finished search's best reading as `Last search - Peak RSSI`.

## How it fits in the app

Locate complements Scan: a Scan sweep's **Found** and **Missing** tiles tell you which listed items turned up and which didn't, but Locate is how you walk down a single one of them and confirm exactly where it is. Tags are usually copied here from a Scan result row or from an **Assets** record.
