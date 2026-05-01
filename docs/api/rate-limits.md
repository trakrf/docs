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

Every API response — successful or throttled — includes three headers describing the current state of your bucket:

| Header                  | Units              | Meaning                                                                                                                    |
| ----------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `X-RateLimit-Limit`     | integer requests   | Your steady-state budget per 60-second window (e.g. `60`).                                                                 |
| `X-RateLimit-Remaining` | integer requests   | Requests you can make before throttling, bounded by `Limit`. Stays at `Limit` while you're inside the burst safety margin. |
| `X-RateLimit-Reset`     | Unix epoch seconds | Wall-clock time at which `Remaining` will next equal `Limit`. Equal to "now" when you already have full quota.             |

You can watch `X-RateLimit-Remaining` to pace requests preemptively rather than waiting to hit `429`. A well-behaved client pattern is:

```python
if remaining < some_threshold:
    time.sleep(max(0, reset - now))
```

The `max(0, …)` is important: when you're not throttled, `reset - now` is zero and the sleep is a no-op.

**Burst safety margin.** Under the hood, the bucket holds up to 2× `Limit` tokens so short spikes don't throttle well-paced clients. That extra headroom is deliberately hidden from the headers — `Remaining` never exceeds `Limit` — so clients pace against the steady-state rate they were sold, not against burst capacity.

## When you hit the limit

Throttled requests get a `429` with the standard error envelope:

```json
{
  "error": {
    "type": "rate_limited",
    "title": "Rate limit exceeded",
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

- **Back off on 429.** Wait at least `Retry-After` seconds before retrying. Exponential backoff with jitter on repeated 429s is ideal.
- **Read `X-RateLimit-Remaining` proactively.** If it's approaching zero and your workload can wait, pause briefly rather than letting the server enforce the pause.
- **Don't treat 429 as a server error.** It's a client-side signal — retry policy should differ from retry-on-500. See [Errors](./errors) for the full retry guidance.

## Exclusions

The following endpoints do **not** emit `X-RateLimit-*` headers and are not counted against the bucket:

- `GET /api/v1/orgs/me` — used as a connectivity/health check; excluded so that liveness probes never trip the limit.
- **All write endpoints** — every `POST`/`PUT`/`DELETE` under `/api/v1/assets` and `/api/v1/locations`. Writes are audited rather than rate-limited; if you need backpressure on ingest, apply it client-side.

**Response-shape note:** `GET /api/v1/orgs/me` returns the standard `{ "data": ... }` envelope, same as every other endpoint on the public surface. See [Private endpoints → /orgs/me](./private-endpoints#orgs-me) for the full catalog entry.

All other endpoints (the public read surface) participate in the bucket.

## Per-key, not per-organization

Limits apply to each API key independently. An organization with three keys has three times the combined throughput. This matches the Stripe/Twilio pattern and is the simplest model; it may tighten if we see abuse.

## Horizontal scaling

Rate limiting is currently implemented in-process on a single backend instance. A horizontally-scaled deployment will move the bucket state to Redis or similar; the `X-RateLimit-*` headers and `429` semantics remain identical.
