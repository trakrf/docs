---
sidebar_position: 3
---

# Webhooks

:::info Planned for v1.x — not available yet

Webhook-based push delivery is on the TrakRF roadmap but is **not part of the v1 launch**. This page describes the intended shape so integrators can plan against it and flag "I need this" to us early.

If webhooks are on your integration path, [email support](mailto:support@trakrf.id) or open a conversation with your TrakRF contact — real customer demand is what drives scheduling.

:::

## Why webhooks

Today, integrations using the TrakRF API pull scan and location data on a schedule — typically a cron job hitting `GET /api/v1/scans` every few minutes. That works, but:

- You pay for the request traffic even when nothing has happened.
- The latency between a physical scan and your system seeing it is at best one polling interval.
- You have to track the high-water-mark timestamp yourself to avoid replay.

Webhooks invert the model: TrakRF delivers events to a URL you host the moment they happen.

## Planned event types

When webhooks ship, these are the event types we intend to support at launch:

| Event              | Fires when                                        |
| ------------------ | ------------------------------------------------- |
| `asset.scanned`    | An asset's tag is read by any scan device         |
| `asset.moved`      | An asset transitions from one location to another |
| `location.entered` | An asset enters a specific location               |
| `location.exited`  | An asset leaves a specific location               |

Each event payload will include the full logical context — both forms of the asset and location identifier (`id` + `external_key`), timestamp, scan device details — so your handler doesn't need to make follow-up API calls to hydrate.

## Planned mechanics

- **Registration:** register a target URL per org, with optional per-event filters.
- **Delivery guarantees:** at-least-once. Your handler must be idempotent (TrakRF sends a stable event ID in each payload so you can deduplicate).
- **Retry:** exponential backoff with jitter over ~24 hours. Persistent failures eventually stop retrying; you'll see the failures in the delivery log.
- **Signature verification:** every payload includes an HMAC signature header so you can verify the request originated from TrakRF and wasn't tampered with in flight. A secret is generated per registered webhook.
- **Delivery log:** a queryable history of recent deliveries (status, response code, body) for debugging failed handlers.

## What you can do today

Until webhooks ship, the equivalent patterns on the existing REST API:

- **Poll `GET /api/v1/assets/{id}/history?from=<last-high-water-mark>`** per asset you're tracking, to get scan events for that asset since your last pull.
- **Poll `GET /api/v1/locations/current`** for the current asset-at-location snapshot (cheaper than replaying the full scan stream).

See the [interactive reference](/api) for the available endpoints and [Authentication](./authentication) for how to authenticate the polling calls.

## Status and contact

There's no committed ship date for webhooks yet — the work is gated on customer demand and TrakRF's own readiness for reliable outbound delivery at scale.

To put a real customer need behind this feature, [email support](mailto:support@trakrf.id) with the events you'd want to subscribe to and what your handler would do with them. Concrete use cases accelerate scheduling.
