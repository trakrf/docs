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

| Header                  | Meaning                                                             |
| ----------------------- | ------------------------------------------------------------------- |
| `X-RateLimit-Limit`     | Your steady-state limit (e.g. `60`)                                 |
| `X-RateLimit-Remaining` | Tokens left in the bucket at the moment this response was generated |
| `X-RateLimit-Reset`     | Unix timestamp when the bucket will be fully refilled               |

You can watch `X-RateLimit-Remaining` to pace requests preemptively rather than waiting to hit `429`.

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

The `Retry-After` value is the number of seconds to wait before the next request will succeed (assuming no other throttled requests in the meantime). Respect it — retrying immediately will cost another token and may extend the throttle window.

## Recommended client behavior

- **Back off on 429.** Wait at least `Retry-After` seconds before retrying. Exponential backoff with jitter on repeated 429s is ideal.
- **Read `X-RateLimit-Remaining` proactively.** If it's approaching zero and your workload can wait, pause briefly rather than letting the server enforce the pause.
- **Don't treat 429 as a server error.** It's a client-side signal — retry policy should differ from retry-on-500. See [Errors](./errors) for the full retry guidance.

## Exclusions

One endpoint bypasses rate limiting entirely:

- `GET /api/v1/orgs/me` — returns the organization your key belongs to, used as a connectivity/health check by most clients. Excluded so that liveness probes never trip the limit.

**Response-shape note:** `GET /api/v1/orgs/me` returns a bare `{ "id": ..., "name": ... }` object — not the `{ "data": ... }` envelope used by the rest of the v1 API. Clients using this as a liveness probe should be aware the shape may change if the endpoint migrates to the standard envelope. Consider also verifying a "real" enveloped endpoint (e.g. `GET /api/v1/assets?limit=1`) in your health check if you want to detect envelope drift early. See [Private endpoints → /orgs/me](./private-endpoints#orgs-me) for the full catalog entry.

All other endpoints participate in the bucket.

## Per-key, not per-organization

Limits apply to each API key independently. An organization with three keys has three times the combined throughput. This matches the Stripe/Twilio pattern and is the simplest model; it may tighten if we see abuse.

## Horizontal scaling

Rate limiting is currently implemented in-process on a single backend instance. A horizontally-scaled deployment will move the bucket state to Redis or similar; the `X-RateLimit-*` headers and `429` semantics remain identical.
