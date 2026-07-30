# TRA-1048 Webhooks v1 Documentation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inaccurate "Planned for v1.x" webhooks page with hand-written documentation of the webhooks that actually shipped, and purge stale "planned" webhook language from the rest of the docs.

**Architecture:** One rewritten page (`docs/api/webhooks.md`) carries the whole feature — payload, headers, signature verification, delivery semantics, endpoint requirements, and the in-app registration walkthrough. The walkthrough lives on the API page rather than in the app tour because `docs/api/authentication.md` already sets that precedent for API-key minting. Four other pages get stale claims corrected, one nav entry moves, one changelog entry is added. Screenshots follow in a separate commit so the prose can merge the instant the platform deploy lands.

**Tech Stack:** Docusaurus 3, Markdown/MDX, pnpm, Prettier.

## Global Constraints

- **pnpm exclusively.** Never `npm` or `npx`. `npx` → `pnpm dlx`.
- **No documented field or behavior that is not in the shipped code.** Where the ticket text and the platform code disagree, the code wins.
- **No Linear ticket references** (`TRA-NNN`) in any published prose under `docs/`.
- **Nothing from Phase 2 documented as "coming soon" with specifics** — no event-type names, payload shapes, or dates for unshipped work.
- **`onBrokenLinks: "throw"`** in `docusaurus.config.ts` — a broken internal link fails the build. `pnpm build` is the link test.
- **Prettier formats embedded code blocks in Markdown.** Do not hand-align JSON or table columns; write it plainly and let `pnpm lint:fix` normalize. Always run `pnpm lint:fix` before committing.
- **Do not merge.** This branch is held open deliberately until the production platform deploy. Push and open the PR; never merge.
- Conventional commits; never squash; branch is `docs/tra-1048-webhooks-v1`.

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `docs/api/webhooks.md` | The entire webhooks feature, for an integrator writing a receiver | Rewrite (full replace) |
| `docs/api/README.mdx` | API section index; one-line link descriptions | Modify line 39 |
| `docs/api/resource-identifiers.md` | Scan-event vocabulary; forward reference to webhooks | Modify line 709 |
| `docs/api/versioning.md` | Open/closed enum policy; uses a scope name as an example | Modify line 66 |
| `docs/api/private-endpoints.md` | Catalog of session-auth internal routes | Add 6 table rows |
| `docs/api/changelog.md` | Integrator-facing change record | Add one `###` entry |
| `sidebars.ts` | API sidebar ordering | Move one array element |

---

### Task 1: Rewrite the webhooks page

The substance of the work. Everything else is cleanup.

**Files:**
- Modify: `docs/api/webhooks.md` (full replace of lines 1–59)
- Test: `pnpm build` (link checking), `pnpm lint`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the heading anchors `#what-fires-an-event`, `#registering-a-webhook`, `#the-payload`, `#headers`, `#verifying-the-signature`, `#delivery-semantics`, `#endpoint-requirements`, `#reconciling-missed-events`, and `#events-went-quiet`. Task 2 and Task 3 link to `./webhooks` only (no anchors), so no cross-task anchor dependency exists — but do not rename these headings without updating this plan.

**Frontmatter note:** Preserve the existing frontmatter block (`sidebar_position: 3`) verbatim. `sidebars.ts` lists `apiSidebar` items explicitly, so `sidebar_position` is inert for this page; changing it is churn with no rendered effect. Task 3 handles the real reorder.

- [ ] **Step 1: Replace the file contents**

Write `docs/api/webhooks.md` with exactly this content:

````markdown
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

The volume difference is substantial. On the TrakRF demo carousel, 815 scans produced 8 events.

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

Turning a webhook off stops delivery without deleting the registration or changing the secret. Events that occur while it is off are dropped, not queued — turning it back on does not replay them.

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

| Field | Notes |
| --- | --- |
| `event` | Always `asset.moved` in v1. Match on it anyway — more types will be added, and an unknown value should be ignored rather than treated as an error. |
| `delivery_id` | UUID identifying one detected move. Stable across the retries of a single delivery — use it as your idempotency key. |
| `occurred_at` | The scan instant that produced the move, in server time (RFC 3339, UTC). **Order by this**, not by arrival. |
| `data.asset.id` | The surrogate `id`, identical to the one the REST API returns for that asset. |
| `data.asset.external_key` | Your natural key for the asset. |
| `data.from_location` | The location the asset was last seen at, or `null` for a genuine first-ever sighting. |
| `data.to_location` | The location it was just scanned at. Never null. |

Three things about the shape:

- **`from_location` is present and explicitly `null`** on a first sighting. The key is never omitted, so a receiver can read it unconditionally.
- **Ids are large.** The surrogate `id` is an opaque integer up to 2⁵², so store it in a 64-bit integer type — a 32-bit field will overflow. Treat it as opaque: don't parse it, order by it, or infer a count or creation time from it. Join your own systems on `external_key`. See [ID format](./id-format) and [Resource identifiers](./resource-identifiers#numeric-id-is-a-surrogate-key).
- **The payload is logical data only.** No scan point, no antenna, no EPC, no scan-event id — the physical layer stays internal. If you need physical provenance, it isn't here and won't be.

There is **no `sequence` field**, deliberately. See [Delivery semantics](#delivery-semantics).

## Headers

| Header | Value |
| --- | --- |
| `X-TrakRF-Event` | `asset.moved` |
| `X-TrakRF-Delivery` | UUID, stable across the retries of one delivery. Matches `delivery_id` in the body. |
| `X-TrakRF-Timestamp` | Unix seconds — the signed timestamp. |
| `X-TrakRF-Signature` | `sha256=<hex>` |
| `User-Agent` | `TrakRF-Webhooks/1` |

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
2. **The webhook is disabled.** Check the enable toggle on the Webhooks screen.
3. **The subscription lapsed.** Delivery stops for an organization that is no longer entitled, and nothing in your integration surfaces it. Check billing.
4. **Your endpoint started failing.** Use **Send test event** — it reports the status code your endpoint returned. Anything but a 2xx, including a redirect, is a failed delivery.
5. **The scans carry no location.** Reads that resolve to no location produce no event.

## Not in v1

Multiple subscriptions per organization, per-event filters, additional event types, a longer retry ladder, a dead-letter queue, per-delivery logs, secret rotation, and IP allowlisting are all recognized gaps rather than settled designs. If one of them blocks your integration, [email support](mailto:support@trakrf.id) — real customer demand is what drives scheduling.
````

- [ ] **Step 2: Format and verify no stale language survives**

```bash
pnpm lint:fix
grep -in "at-least-once\|asset.scanned\|location.entered\|location.exited\|delivery log\|not available yet\|Planned for" docs/api/webhooks.md
```

Expected: the `grep` prints **nothing** (exit status 1). Every hit is stale roadmap language that must not survive the rewrite.

- [ ] **Step 3: Verify the build and link checking pass**

```bash
pnpm build
```

Expected: build succeeds. `onBrokenLinks: "throw"` means any broken internal link — `./id-format`, `./resource-identifiers#numeric-id-is-a-surrogate-key`, `./authentication`, `/api` — fails here. If `./resource-identifiers#numeric-id-is-a-surrogate-key` errors, confirm the anchor with `grep -n "numeric-id-is-a-surrogate-key" docs/api/resource-identifiers.md` and correct the link rather than removing it.

- [ ] **Step 4: Commit**

```bash
git add docs/api/webhooks.md
git commit -m "docs(api): document webhooks v1 as shipped

The page described a roadmap feature with four event types,
at-least-once delivery, a 24-hour retry ladder, and a delivery log.
What shipped is delta-only asset.moved, at-most-once, two jittered
retries, and no log. Rewritten against the implementation.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Correct stale webhook claims on the other API pages

Three pages describe webhooks as unshipped; one omits the routes entirely. A reviewer could reasonably accept Task 1 and reject this, so it commits separately.

**Files:**
- Modify: `docs/api/README.mdx:39`
- Modify: `docs/api/resource-identifiers.md:709`
- Modify: `docs/api/versioning.md:66`
- Modify: `docs/api/private-endpoints.md` (endpoint list table, after line 33)
- Test: `pnpm build`, `pnpm lint`

**Interfaces:**
- Consumes: the rewritten `docs/api/webhooks.md` from Task 1. Links target `./webhooks` with no anchor.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Update the API index link description**

In `docs/api/README.mdx`, replace line 39:

```markdown
- **[Webhooks](./webhooks)** — status of outbound delivery and the interim polling pattern
```

with:

```markdown
- **[Webhooks](./webhooks)** — outbound `asset.moved` delivery, signature verification, and delivery guarantees
```

- [ ] **Step 2: Move the resource-identifiers reference to present tense**

In `docs/api/resource-identifiers.md`, replace line 709:

```markdown
When [webhooks](./webhooks) ship, events will fire on scan events but the payloads address **assets and locations**, not scan events directly — there's no scan-event id to subscribe to or look up. An ingestor planning a scan-driven workflow should think in terms of asset history and current location, not in terms of a scan-event resource.
```

with:

```markdown
[Webhooks](./webhooks) follow the same rule: an `asset.moved` event is triggered by a scan, but its payload addresses **assets and locations**, not scan events directly — there's no scan-event id to subscribe to or look up. An ingestor planning a scan-driven workflow should think in terms of asset history and current location, not in terms of a scan-event resource.
```

- [ ] **Step 3: Replace the misleading scope example in versioning**

`versioning.md` offers `webhooks:write` as a hypothetical future scope. Webhook management shipped with no scope at all — it is session-authenticated and admin-gated — so the example now implies a public surface that does not exist.

In `docs/api/versioning.md` line 66, replace this fragment:

```markdown
TrakRF may introduce new scopes (e.g. `reports:read`, `webhooks:write`) in any v1 release
```

with:

```markdown
TrakRF may introduce new scopes (e.g. `reports:read`, `alarms:write`) in any v1 release
```

Leave the rest of line 66 untouched.

- [ ] **Step 4: Add the webhook routes to the private-endpoints catalog**

In `docs/api/private-endpoints.md`, insert these six rows into the endpoint list table immediately after the `/api/v1/assets/bulk` row (line 32) and before the `/api/v1/orgs/me` row (line 33). Do not hand-align the columns; Prettier reflows the table.

```markdown
| `/api/v1/webhooks`                    | GET, POST      | SPA webhook registration (admin)             | Internal | Internal |
| `/api/v1/webhooks/{webhook_id}`       | GET, PATCH, DELETE | SPA webhook management (admin)           | Internal | Internal |
| `/api/v1/webhooks/{webhook_id}/test`  | POST           | SPA **Send test event** (admin)              | Internal | Internal |
```

Then add this paragraph immediately after the table (before the `## Response shape: /orgs/me` heading on line 35):

```markdown
Webhook management is internal by design rather than by omission: registering a delivery endpoint is an organization-settings action performed by an admin in the browser, not something an integrator's API key does. The delivery side — the payload TrakRF posts to your endpoint, and how to verify it — is fully documented in [Webhooks](./webhooks).
```

- [ ] **Step 5: Format, then verify no "planned webhooks" language survives anywhere**

```bash
pnpm lint:fix
grep -rin "when webhooks ship\|webhooks:write\|interim polling" docs/
```

Expected: the `grep` prints **nothing**.

- [ ] **Step 6: Verify the build passes**

```bash
pnpm build
```

Expected: build succeeds, no broken links.

- [ ] **Step 7: Commit**

```bash
git add docs/api/README.mdx docs/api/resource-identifiers.md docs/api/versioning.md docs/api/private-endpoints.md
git commit -m "docs(api): retire pre-ship webhook language across the API pages

Present-tense the resource-identifiers forward reference, rewrite the
index link description, drop webhooks:write as a hypothetical scope
example now that webhook CRUD shipped without one, and add the six
session-auth webhook routes to the private-endpoints catalog.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Move the nav entry and record the change

Webhooks sits in the meta/tools tail of the sidebar because it was a status page. It is a capability now and belongs with the functional reference.

**Files:**
- Modify: `sidebars.ts:55`
- Modify: `docs/api/changelog.md` (insert after line 12)
- Test: `pnpm build`, `pnpm typecheck`, `pnpm lint`

**Interfaces:**
- Consumes: `docs/api/webhooks.md` from Task 1 — the doc id `api/webhooks` must still resolve.
- Produces: nothing.

- [ ] **Step 1: Move `api/webhooks` in the API sidebar**

In `sidebars.ts`, the `apiSidebar` items array currently reads:

```ts
        "api/rate-limits",
        "api/design-notes",
        "api/versioning",
        "api/changelog",
        "api/webhooks",
        "api/postman",
        "api/private-endpoints",
```

Change it to place `api/webhooks` directly after `api/rate-limits`, closing the functional-reference run before the meta pages:

```ts
        "api/rate-limits",
        "api/webhooks",
        "api/design-notes",
        "api/versioning",
        "api/changelog",
        "api/postman",
        "api/private-endpoints",
```

- [ ] **Step 2: Add the changelog entry**

Entries in `docs/api/changelog.md` sit under `## v1.0 — Launch (TBD)` newest-first. Insert this as the new top entry — after the section's intro paragraph (line 12) and immediately before the existing `### \`id\` is globally unique and opaque…` heading on line 14:

```markdown
### Webhooks: outbound `asset.moved` delivery {#webhooks-asset-moved}

TrakRF can now push an event to an HTTPS endpoint you host when an asset is scanned at a location different from the one it was last seen at. One event type (`asset.moved`), one webhook per organization, registered from the app's **Account menu → Webhooks** rather than through the API — webhook management is an admin browser action and has no public API surface. This is additive; nothing about the existing polling endpoints changes.

- **Delivery is at-most-once and delta-only.** A failed delivery is retried at roughly one and five seconds, jittered, then dropped — no dead-letter queue and no replay. Rescans at an unchanged location emit nothing at all, so this is a movement feed rather than a scan feed. Receivers must tolerate a missed event and reconcile periodically against `GET /api/v1/reports/asset-locations`.
- **Ordering is not guaranteed and there is no `sequence` field.** Concurrent scans can deliver out of order; order by `occurred_at`. Duplicates are possible on the retry path — deduplicate on `delivery_id`.
- **Every delivery is signed.** `X-TrakRF-Signature` carries an HMAC-SHA256 over `timestamp + "." + rawBody`, hex-encoded, with the signed timestamp in `X-TrakRF-Timestamp` so a captured delivery cannot be replayed indefinitely. The signature must be computed over the raw request bytes, not a re-serialized parse. See [Webhooks](./webhooks).
```

- [ ] **Step 3: Format and verify the build, types, and nav**

```bash
pnpm lint:fix
pnpm typecheck
pnpm build
```

Expected: all three succeed. `typecheck` catches a malformed `sidebars.ts`; `build` catches a doc id that no longer resolves.

- [ ] **Step 4: Confirm the sidebar renders in the new order**

```bash
grep -A9 '"api/rate-limits"' sidebars.ts
```

Expected: `"api/webhooks"` appears on the line immediately after `"api/rate-limits"`, and appears exactly once in the file.

- [ ] **Step 5: Commit**

```bash
git add sidebars.ts docs/api/changelog.md
git commit -m "docs(api): promote webhooks into the reference nav, log the change

Webhooks sat between changelog and postman because it was a roadmap
status page. It is a shipped capability now, so it moves up to close
the functional reference run after rate-limits.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Screenshots (follow-up commit — do not block the PR on this)

Deferred deliberately. Tasks 1–3 must be mergeable the moment the platform production deploy lands; these captures need a working preview session and can arrive afterward on the same PR.

**Files:**
- Create: `static/img/webhooks-empty-state.png`
- Create: `static/img/webhooks-secret-reveal.png`
- Create: `static/img/webhooks-test-result.png`
- Modify: `docs/api/webhooks.md` (embed the three images)
- Test: `pnpm build`

**Interfaces:**
- Consumes: the `## Registering a webhook`, `### The signing secret is shown exactly once`, and `### Send test event` sections from Task 1.
- Produces: nothing.

**Prerequisite:** confirm with the operator that a preview SPA session is available for an admin-role org before starting. Do not attempt credential recovery unprompted.

- [ ] **Step 1: Confirm the existing screenshot convention**

```bash
ls static/img/ | head -30
grep -rn "static/img\|!\[" docs/app-tour/assets.md | head -10
```

Match whatever path form and alt-text style the app-tour pages already use. Do not invent a new convention.

- [ ] **Step 2: Capture the three screenshots against preview**

Use the Playwright MCP browser at a 1680x900 desktop viewport, matching the app-tour captures.

1. **Empty state** — Account menu → Webhooks with no webhook registered.
2. **Secret reveal** — the create confirmation showing the reveal-once secret banner.
3. **Test-fire result** — the status-code result after **Send test event**.

**Create a throwaway webhook for this and delete it afterward.** Never capture a real signing secret. If the reveal-once banner shows a live secret in the frame, redact it before saving the file — the whole point of the capture is the banner, not the value.

- [ ] **Step 3: Embed the images**

Add each image directly beneath the section it illustrates in `docs/api/webhooks.md` — empty state under `## Registering a webhook`, secret banner under `### The signing secret is shown exactly once`, test result under `### Send test event`. Write descriptive alt text stating what the screen shows, not "screenshot of webhooks".

- [ ] **Step 4: Verify the build resolves the image paths**

```bash
pnpm lint:fix
pnpm build
```

Expected: build succeeds with no missing-asset warnings.

- [ ] **Step 5: Confirm no live secret was committed**

```bash
git diff --cached --stat
grep -rn "whsec_" docs/ | grep -v "whsec_1f0c1d4e\|whsec_…"
```

Expected: the `grep` prints nothing. The only `whsec_` strings in the docs are the illustrative example and the masked form from Task 1.

- [ ] **Step 6: Commit**

```bash
git add static/img/webhooks-*.png docs/api/webhooks.md
git commit -m "docs(api): add webhooks UI screenshots

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Finishing

After Task 3, push and open the PR. **Do not merge.**

```bash
git push -u origin docs/tra-1048-webhooks-v1
gh pr create --title "docs: document webhooks v1 as shipped" --body "$(cat <<'EOF'
Replaces the "Planned for v1.x — not available yet" webhooks page with
documentation of the feature that actually shipped, and clears stale
"planned webhooks" language from the rest of the API section.

The old page was actively misleading: it promised four event types,
at-least-once delivery, a 24-hour exponential-backoff retry ladder, and
a queryable delivery log. What shipped is one event type, at-most-once
delivery, two jittered retries, and no log. An integrator building
against the old page would silently lose events.

Content verified against the platform implementation rather than the
ticket text.

## HOLD — do not merge before the production platform deploy

Webhooks exist on preview only; production is on v1.2. Merging publishes
to docs.trakrf.id, which would document a feature production users do
not have. Merge alongside #206 immediately after the deploy lands.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Screenshots (Task 4) land on this branch afterward, and do not gate the merge.

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: the page rewrite and all eleven of its sections → Task 1; the five collateral items → Tasks 2 and 3 (README, resource-identifiers, versioning, private-endpoints in Task 2; sidebars and changelog in Task 3); screenshots → Task 4; release coupling → Finishing. The three Ground-truth refinements are each carried into Task 1's prose — the `occurred_at` timestamp nuance in "Check the timestamp too", the 52-bit id magnitude in "The payload", and the `whsec_` format plus masking in "The signing secret is shown exactly once". The per-connection SSRF framing is in "Endpoint requirements" and the drop-never-buffer behavior is in "Delivery semantics".

**Placeholder scan.** No TBD/TODO, no "similar to Task N", no "add error handling". Every prose change quotes the exact before-and-after text; the page rewrite carries its full final content.

**Consistency.** Heading anchors referenced in Task 1's cross-links (`#delivery-semantics`, `#reconciling-missed-events`) match headings defined in the same task. The `whsec_1f0c1d4e…` example secret in Task 1 is the same string Task 4's leak check whitelists. Delivery guarantees are stated identically in Task 1 and the Task 3 changelog entry (at-most-once, ~1s/~5s jittered, no DLQ, no replay, order by `occurred_at`, dedupe on `delivery_id`).
