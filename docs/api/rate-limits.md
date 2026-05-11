---
sidebar_position: 4
---

# Rate limits

The TrakRF API applies a per-key rate limit to protect the shared service from runaway integrations. Normal customer traffic is well below the limits; this page exists so integrators have the authoritative answer when they hit a `429`.

## How the limit works

Each API key has its own **token bucket**:

- **Refill rate** — the steady-state request budget.
- **Bucket capacity** — the burst allowance. Requests can spike up to this before the steady-state budget takes over.

Tokens replenish continuously at the refill rate. A request costs one token. When the bucket is empty, further requests receive `429 Rate Limit Exceeded` until tokens replenish.

## Default tier

All keys start with this allowance unless your organization's subscription specifies otherwise:

| Limit        | Value                |
| ------------ | -------------------- |
| Steady-state | 60 requests / minute |
| Burst        | 120 requests         |

Tier-specific allowances keyed to subscription plans are on the roadmap. If your integration needs more throughput than the default tier, [contact support](mailto:support@trakrf.id).

## Response headers

Every API response on the public surface — including 4xx and 5xx errors (`401`, `403`, `404`, `409`, `415`, `429`, `500`) — includes three headers describing the current state of your bucket:

| Header                  | Units              | Meaning                                                                                                                                                                                                           |
| ----------------------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `X-RateLimit-Limit`     | integer requests   | Your steady-state budget per 60-second window (e.g. `60`).                                                                                                                                                        |
| `X-RateLimit-Remaining` | integer requests   | Steady-state budget remaining, bounded by `Limit`. Decrements only after the burst margin is consumed — a value of `Limit` does not mean a full request budget, it means you are still inside the burst headroom. |
| `X-RateLimit-Reset`     | Unix epoch seconds | Wall-clock time at which `Remaining` will next equal `Limit`. Equal to "now" when you already have full quota.                                                                                                    |

The headers ride on every response status the public surface emits, so clients can read them even when the request itself failed — error responses are not a blind spot for budget-tracking dashboards or observability metrics.

**Don't pace on `X-RateLimit-Remaining`.** It looks like a preemptive-pacing input but it isn't one. The bucket holds 2× `Limit` tokens (the burst margin), and `Remaining` is reported as `min(bucket, Limit)` so the header never exceeds the steady-state cap a customer was sold. The practical consequence: `Remaining` stays at `Limit` while the bucket is anywhere inside the burst margin, and only starts decrementing once the bucket has drained below the steady-state line. By the time the header moves, the burst margin is already gone and the next bad spike trips `429`. A client that watches `Remaining < threshold` to back off is using a signal that can't fire until throttling is imminent. Pace on `429` + `Retry-After` instead — that's the integrator-correct contract on this surface.

## When you hit the limit

Throttled requests get a `429` with the standard error envelope:

```json
{
  "error": {
    "type": "rate_limited",
    "title": "Rate limited",
    "status": 429,
    "detail": "Retry after 30 seconds",
    "instance": "/api/v1/assets",
    "request_id": "01J..."
  }
}
```

…plus the `Retry-After` header:

```
Retry-After: 30
```

The `Retry-After` value is an integer number of **seconds** to wait before the next request will succeed (assuming no other throttled requests in the meantime). Respect it — retrying immediately will cost another token and may extend the throttle window.

## Recommended client behavior

- **Back off on 429.** Wait at least `Retry-After` seconds before retrying. Exponential backoff with jitter on repeated 429s is ideal. This is the primary pacing signal on the public surface — see the warning above on why preemptive pacing against `X-RateLimit-Remaining` does not work.
- **Treat the `X-RateLimit-*` headers as observability, not pacing.** Surface them in dashboards and request-budget metrics if useful, but don't drive client-side throttling decisions off `Remaining` or `Reset` — drive throttling off `429` + `Retry-After`.
- **Don't treat 429 as a server error.** It's a client-side signal — retry policy should differ from retry-on-500. See [Errors](./errors) for the full retry guidance.

## All endpoints participate in the bucket

Every endpoint on the public surface — including `GET /api/v1/orgs/me` and every write under `/api/v1/assets` and `/api/v1/locations` — counts against your bucket and emits `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers. There are no carve-outs.

At 60 requests/minute the steady-state budget comfortably covers normal integration traffic, but a few patterns are worth flagging:

- **Liveness/connectivity probes against `GET /api/v1/orgs/me`** — these count, so probe at a frequency your budget tolerates. Once per minute is the simplest pattern that always fits inside the default tier with room to spare; once every 30 seconds is fine if `/orgs/me` is the only thing the probe hits. Aggressive sub-second probes will trip throttling.
- **Bulk writes** — every `POST` / `PATCH` / `DELETE` under `/api/v1/assets` and `/api/v1/locations` consumes one token. For ingest workloads above the default tier, [contact support](mailto:support@trakrf.id) about a custom tier rather than spreading writes across multiple keys.

`GET /api/v1/orgs/me` returns the standard `{ "data": ... }` envelope, same as every other endpoint on the public surface. See [Private endpoints → /orgs/me](./private-endpoints#orgs-me) for the full catalog entry.

## Per-key, not per-organization

Limits apply to each API key independently. An organization with three keys has three times the combined throughput. This matches the Stripe/Twilio pattern and is the simplest model; it may tighten if we see abuse.

## Horizontal scaling

Rate limiting is currently implemented in-process on a single backend instance. A horizontally-scaled deployment will move the bucket state to Redis or similar; the `X-RateLimit-*` headers and `429` semantics remain identical.
