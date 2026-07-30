---
sidebar_position: 3
---

# Webhooks

TrakRF can push an event to an HTTPS endpoint you host whenever an asset moves to a different location — the push alternative to polling [`GET /api/v1/reports/asset-locations`](/api) on a schedule.

One event type ships in v1: `asset.moved`.

Webhooks are registered from the app rather than the API, because registering one is an organization-settings action rather than something an integrator's API key does. There is no public API for webhook management.

## What fires an event

An `asset.moved` event fires when an asset is scanned at a location **different from the one it was last seen at**. That is the whole rule, and it has a consequence worth internalizing before you write a receiver:

**Rescans at the same location send nothing.** A fixed reader that sees a stationary tag hundreds of times an hour produces zero events. This is a movement feed — not a scan feed, and not a heartbeat. Silence means nothing has moved, not that the pipeline is down.

The volume difference is substantial. In a representative fixed-reader deployment, 815 scans produced 8 events.

A scan that carries no location produces no event.

If you need the full scan stream rather than movements, poll [`GET /api/v1/assets/{asset_id}/history`](/api) instead.

## Registering a webhook

Open the **Account menu → Webhooks** (directly below API Keys), or go to **Organization Settings → Manage webhooks →**. The **admin** role is required.

v1 supports **one webhook per organization**.

### The signing secret is shown exactly once

Creating a webhook generates a signing secret and displays it once, on the create confirmation. Secrets carry a `whsec_` prefix:

```
whsec_1f0c1d4e7a2b9c8d3e6f5a0b4c7d2e9f8a1b6c3d0e5f2a7b4c9d6e3f0a5b2c7d
```

There is no way to read it back. Every later view shows a masked form — `whsec_…2c7d` — which is enough to tell two secrets apart and useless for signing.

**There is no secret rotation in v1.** If you lose the secret, the only recovery is to delete the webhook and create a new one, which issues a fresh secret and requires updating your receiver. Copy it into your secrets store before leaving the page.

### Send test event

**Send test event** delivers a synthetic `asset.moved` to your endpoint and reports the HTTP status code it returned. Use it to prove your receiver and your signature verification work before any real asset moves.

The test payload uses obviously-fake identifiers — an `external_key` of `TEST-ASSET`, moving from "Test Origin" to "Test Destination" — so a test fire cannot be mistaken for real movement in your system.

### The enable toggle

The on/off control is the **Deliver events** checkbox on the Webhooks screen. Unchecking it does not take effect until you click **Save webhook** — the change is not live until the save completes. Once saved, turning delivery off stops it without deleting the registration or changing the secret. Events that occur while it is off are dropped, not queued — turning it back on does not replay them.

## The payload

Delivered as `POST` with `Content-Type: application/json`.

```json
{
  "event": "asset.moved",
  "delivery_id": "9f2c8e14-0000-0000-0000-000000000001",
  "occurred_at": "2026-07-27T16:26:26.412Z",
  "data": {
    "asset": {
      "id": 3947115820491,
      "external_key": "FORK-7",
      "name": "Forklift 7"
    },
    "from_location": { "id": 1882094551203, "name": "Receiving" },
    "to_location": { "id": 2740518866937, "name": "Bay 3" }
  }
}
```

| Field                     | Notes                                                                                                                                                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `event`                   | Always `asset.moved` in v1. Match on it anyway — more types will be added, and an unknown value should be ignored rather than treated as an error.                                                                       |
| `delivery_id`             | UUID identifying one detected move. Stable across the retries of a single delivery — use it as your idempotency key.                                                                                                     |
| `occurred_at`             | The scan instant that produced the move, in server time (RFC 3339, UTC). **Order by this**, not by arrival.                                                                                                              |
| `data.asset.id`           | The surrogate `id`, identical to the one the REST API returns for that asset.                                                                                                                                            |
| `data.asset.external_key` | Your natural key for the asset.                                                                                                                                                                                          |
| `data.asset.name`         | The asset's display name at the time of the move.                                                                                                                                                                        |
| `data.from_location`      | The location the asset was last seen at, or `null` when TrakRF has no previous location for it — a first-ever sighting, a previous scan that resolved to no location, or an origin location that has since been deleted. |
| `data.to_location`        | The location it was just scanned at. Never null.                                                                                                                                                                         |

Three things about the shape:

- **`from_location` is present and explicitly `null`** whenever there is no known origin. The key is never omitted, so a receiver can read it unconditionally — but do not treat `null` as "new asset", since a deleted origin location and a previous scan with no location both produce it too.
- **Ids are large.** The surrogate `id` is an opaque integer well beyond what a 32-bit field holds, and within the 2⁵³−1 ceiling the spec declares, so store it in a 64-bit integer type — a 32-bit field will overflow. Treat it as opaque: don't parse it, order by it, or infer a count or creation time from it. Join your own systems on `external_key`. See [ID format](./id-format) and [Resource identifiers](./resource-identifiers#numeric-id-is-a-surrogate-key).
- **The payload is logical data only.** No scan point, no antenna, no EPC, no scan-event id — the physical layer stays internal. If you need physical provenance, it isn't here and won't be.

There is **no `sequence` field**, deliberately. See [Delivery semantics](#delivery-semantics).

## Headers

| Header               | Value                                                                               |
| -------------------- | ----------------------------------------------------------------------------------- |
| `X-TrakRF-Event`     | `asset.moved`                                                                       |
| `X-TrakRF-Delivery`  | UUID, stable across the retries of one delivery. Matches `delivery_id` in the body. |
| `X-TrakRF-Timestamp` | Unix seconds — the signed timestamp.                                                |
| `X-TrakRF-Signature` | `sha256=<hex>`                                                                      |
| `User-Agent`         | `TrakRF-Webhooks/1`                                                                 |

## Verifying the signature

Every delivery is signed with the webhook's secret. Verify it on every request — an unverified endpoint will accept anything anyone posts to it.

The signature is **HMAC-SHA256 over `timestamp + "." + rawBody`**, hex-encoded and prefixed `sha256=`, where `timestamp` is the `X-TrakRF-Timestamp` header value.

:::warning Sign the raw body, not a re-serialized parse

You must compute the HMAC over the **exact bytes** of the request body. Parsing the JSON and re-encoding it changes whitespace and key order, which changes the hash, and verification will fail for every delivery.

Most frameworks discard the raw body once they have parsed it. Capture it first — Express needs `express.raw()` or a `verify` hook on the JSON parser; Flask needs `request.get_data()`; Rails needs `request.raw_post`. This is by a wide margin the most common webhook integration mistake.

:::

### Node

```js
const crypto = require("crypto");

function verify(rawBody, headers, secret) {
  const ts = headers["x-trakrf-timestamp"];
  const expected =
    "sha256=" +
    crypto
      .createHmac("sha256", secret)
      .update(ts + "." + rawBody)
      .digest("hex");
  const got = headers["x-trakrf-signature"];
  if (!got) return false;
  return (
    got.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(got), Buffer.from(expected))
  );
}
```

### Python

```python
import hashlib, hmac

def verify(raw_body: bytes, headers, secret: str) -> bool:
    ts = headers["X-TrakRF-Timestamp"]
    expected = "sha256=" + hmac.new(
        secret.encode(), ts.encode() + b"." + raw_body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(headers["X-TrakRF-Signature"], expected)
```

Both compare in constant time — `crypto.timingSafeEqual` and `hmac.compare_digest`. A plain `==` returns as soon as it finds a differing byte, and the timing of those failures leaks how much of a guessed signature was correct, which is enough to reconstruct a valid one over many attempts. Note that `timingSafeEqual` throws on length mismatch, hence the length check before it.

### Check the timestamp too

The timestamp is inside the signed material so that a captured delivery cannot be replayed indefinitely. Reject a delivery whose `X-TrakRF-Timestamp` falls outside a tolerance window — five minutes is a reasonable default — in addition to checking the signature.

**The signed timestamp is `occurred_at`, not the moment of transmission.** It is the scan instant, and it does not change when a delivery is retried. Your tolerance window is therefore measured from the physical scan, and it has to accommodate the pipeline latency between the scan and the delivery attempt, not just network time. Don't set it so tight that a normally-delayed event fails.

## Delivery semantics

Document these honestly in your own runbook, because they constrain what you can build.

**At-most-once.** A failed delivery is retried after roughly one second and roughly five seconds — both jittered — and then dropped. There is no dead-letter queue and no replay in v1. **You will eventually miss an event.** Design the receiver so a missed movement is recoverable, and see [Reconciling missed events](#reconciling-missed-events).

**Order is not guaranteed.** Concurrent scans can deliver out of order. Order by `occurred_at`, never by arrival. There is deliberately no `sequence` field — a counter would imply an ordering guarantee TrakRF does not provide.

**Duplicates are possible.** If your endpoint processes a request but responds too slowly, the delivery is retried and you will see the same event twice. Deduplicate on `delivery_id`, which is stable across the retries of one delivery.

**Expect a 2xx.** Any other status counts as a failure and burns a retry. A 3xx is a failure too — see below.

**The timeout is 5 seconds**, covering the whole request. Acknowledge immediately and do your real work asynchronously; a slow handler converts into duplicate deliveries and then into dropped events.

**Delivery stops when a subscription lapses.** Webhook delivery is an outbound request, so nothing in your integration will report an authorization failure — the events simply stop. Skipped events are dropped, not buffered: reinstating the subscription resumes new deliveries but does not replay the gap.

## Endpoint requirements

- **HTTPS only.** A plain `http` target is rejected — it would expose both the payload and the signature.
- **Publicly reachable.** Targets that resolve into private address space are refused: loopback, RFC 1918, link-local (including the cloud metadata address), unique-local IPv6, and CGNAT.
- **Redirects are not followed.** A 302 is a failed delivery, not a hop. Register the final URL.

The address check runs against the **resolved IP on every connection**, not against the URL at registration time. Registration validates only the scheme and host, so a URL pointing at an internal host registers cleanly and then fails on every delivery. If you are testing against something on your own network, that is the symptom you will see — the fix is a publicly reachable endpoint or a tunnel, not a support ticket.

## Reconciling missed events

At-most-once delivery makes periodic reconciliation part of a correct integration rather than a fallback. Poll [`GET /api/v1/reports/asset-locations`](/api) on a slow schedule — hourly is usually enough — and correct any asset whose location disagrees with what your webhook-derived state believes.

This costs little: the report is a current-state snapshot rather than a replay of the scan stream, and it is the same endpoint you would have polled continuously without webhooks. Webhooks reduce the polling interval from seconds to hours; they do not eliminate the need to poll.

See [Authentication](./authentication) for how to authenticate that call.

## Events went quiet

In rough order of likelihood:

1. **Nothing moved.** Delivery is delta-only. Confirm against [`GET /api/v1/reports/asset-locations`](/api) that assets have actually changed location.
2. **The webhook is disabled.** Check the **Deliver events** checkbox on the Webhooks screen.
3. **The subscription lapsed.** Delivery stops for an organization that is no longer entitled, and nothing in your integration surfaces it. Check billing.
4. **Your endpoint started failing.** Use **Send test event** — it reports the status code your endpoint returned. Anything but a 2xx, including a redirect, is a failed delivery.
5. **The scans carry no location.** Reads that resolve to no location produce no event.

## Not in v1

Multiple subscriptions per organization, per-event filters, additional event types, a longer retry ladder, a dead-letter queue, per-delivery logs, secret rotation, and IP allowlisting are all recognized gaps rather than settled designs. If one of them blocks your integration, [email support](mailto:support@trakrf.id) — real customer demand is what drives scheduling.
