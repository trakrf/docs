---
sidebar_position: 4
---

# Rate limits

The TrakRF API applies a per-key rate limit to protect the shared service from runaway integrations. Normal customer traffic is well below the limits; this page is the authoritative answer for integrators who want to pace requests or who hit a `429`.

## How the limit works

Each API key has its own **token bucket** described by two numbers:

- **Burst ceiling — 120.** The most requests you can make in a short spike before a `429`. This is the bucket's capacity, reported live in `X-RateLimit-Limit`.
- **Sustained rate — 60 requests / 60 seconds.** The long-run budget the bucket refills at (~1 token per second), advertised in the `RateLimit-Policy` header as `60;w=60`.

A request costs one token; tokens refill continuously at the sustained rate. When the bucket is empty, further requests get `429` until a token refills. So you can burst up to 120 requests, but holding throughput above 60/minute drains the bucket and throttles you down to the sustained rate.

## Default tier

All keys start with this allowance unless your organization's subscription specifies otherwise:

| Allowance      | Value              | Header                      |
| -------------- | ------------------ | --------------------------- |
| Sustained rate | 60 requests / 60 s | `RateLimit-Policy: 60;w=60` |
| Burst ceiling  | 120 requests       | `X-RateLimit-Limit: 120`    |

Tier-specific allowances keyed to subscription plans are on the roadmap. If your integration needs more throughput than the default tier, [contact support](mailto:support@trakrf.id).

## Response headers

Every API response on the public surface — including 4xx and 5xx errors (`401`, `403`, `404`, `405`, `409`, `415`, `429`, `500`) — carries four rate-limit headers describing your bucket. They are real pacing signals; you can drive client-side throttling off them.

| Header                  | Units                    | Meaning                                                                                                                                                                                                                                      |
| ----------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RateLimit-Policy`      | `quota;w=window-seconds` | The **sustained** rate — `60;w=60` is 60 requests per 60 seconds. This is where the steady-state "60/min" lives. The burst ceiling in `X-RateLimit-Limit` is higher; throughput held above this policy is eventually throttled with a `429`. |
| `X-RateLimit-Limit`     | integer requests         | The **burst ceiling** — the maximum requests in a single burst before a `429` (the bucket's capacity, `120` on the default tier). The lower sustained rate is advertised separately in `RateLimit-Policy`.                                   |
| `X-RateLimit-Remaining` | integer requests         | Requests remaining before a `429`. **Decrements by one on every request**, from `X-RateLimit-Limit` down to `0`, and refills over time toward the ceiling at the sustained rate. Clients **may** pace on this value.                         |
| `X-RateLimit-Reset`     | Unix epoch seconds       | When `X-RateLimit-Remaining` will next equal `X-RateLimit-Limit` — i.e. when the bucket has fully refilled to the ceiling. Equals "now" when you are already at the ceiling.                                                                 |

The headers ride on every response status the public surface emits — including `429` itself — so clients can read them even when the request failed, and budget-tracking dashboards aren't blind on errors.

### What you'll observe

Starting from a full bucket, `X-RateLimit-Remaining` decrements one-for-one and trips `429` when it reaches zero:

```
req 1    → 200   X-RateLimit-Remaining: 119
req 2    → 200   X-RateLimit-Remaining: 118
 …
req 120  → 200   X-RateLimit-Remaining: 0
req 121  → 429   Retry-After: 1
```

`RateLimit-Policy: 60;w=60` rides every one of those responses. After a burst, the bucket refills at ~1 token/second, so sustained throughput settles at 60/minute.

**Pacing guidance:** pace short-term bursts off `X-RateLimit-Remaining` (slow down as it approaches `0`), and size sustained throughput against `RateLimit-Policy` (stay at or below 60/60s so you don't drain the bucket). Honor `429` + `Retry-After` as the backstop.

## When you hit the limit

Throttled requests get a `429` with the standard error envelope:

```json
{
  "error": {
    "type": "rate_limited",
    "title": "Rate limited",
    "status": 429,
    "detail": "Rate limit exceeded; retry after 1 second",
    "instance": "/api/v1/assets",
    "request_id": "01J..."
  }
}
```

…plus the `Retry-After` header:

```
Retry-After: 1
```

`Retry-After` is an integer number of **seconds** to wait before retrying — delta-seconds, floored at `1`, never an HTTP-date. Respect it: retrying earlier costs another token against an empty bucket and can extend the throttle window. The envelope's `request_id` is mirrored in the `X-Request-Id` response header (see [Errors → Filing support tickets](./errors#filing-support-tickets)).

## Recommended client behavior

- **Pace proactively off the headers.** Watch `X-RateLimit-Remaining` for burst budget — slow down as it nears `0` — and keep sustained throughput at or under the `RateLimit-Policy` rate (60/60s on the default tier). Both are real pacing signals now: `Remaining` decrements 1:1, so it moves with every request rather than lagging.
- **Back off on 429.** Wait at least `Retry-After` seconds before retrying; exponential backoff with jitter on repeated 429s is ideal. `Retry-After` is the authoritative backstop even if header-based pacing slips.
- **Don't treat 429 as a server error.** It's a client-side signal — retry policy should differ from retry-on-500. See [Errors](./errors) for the full retry guidance.

## All endpoints participate in the bucket

Every endpoint on the public surface — including `GET /api/v1/orgs/me` and every write under `/api/v1/assets` and `/api/v1/locations` — counts against your bucket and emits the `RateLimit-Policy` and `X-RateLimit-*` headers. There are no carve-outs.

At 60 requests/minute sustained, the budget comfortably covers normal integration traffic, but a few patterns are worth flagging:

- **Liveness/connectivity probes against `GET /api/v1/orgs/me`** — these count, so probe at a frequency your budget tolerates. Once per minute always fits the default tier with room to spare; once every 30 seconds is fine if `/orgs/me` is the only thing the probe hits. Aggressive sub-second probes will drain the bucket and trip throttling.
- **Bulk writes** — every `POST` / `PATCH` / `DELETE` under `/api/v1/assets` and `/api/v1/locations` consumes one token. For ingest workloads above the default tier, [contact support](mailto:support@trakrf.id) about a custom tier rather than spreading writes across multiple keys.

`GET /api/v1/orgs/me` returns the standard `{ "data": ... }` envelope, same as every other endpoint on the public surface. See [Private endpoints → /orgs/me](./private-endpoints#orgs-me) for the full catalog entry.

## Per-key, not per-organization

Limits apply to each API key independently. An organization with three keys has three times the combined throughput. This matches the Stripe/Twilio pattern and is the simplest model; it may tighten if we see abuse.

## Horizontal scaling

Rate limiting is currently implemented in-process on a single backend instance. A horizontally-scaled deployment will move the bucket state to Redis or similar; the `RateLimit-Policy`, `X-RateLimit-*` headers, and `429` semantics remain identical.
