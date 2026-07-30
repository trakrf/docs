# TRA-1048 — Webhooks v1 documentation

Customer-facing documentation for the webhooks shipped in TRA-1043 (platform PR #526).

## Problem

`docs/api/webhooks.md` already exists, and it is wrong in almost every particular. It was
written as a roadmap placeholder ("Planned for v1.x — not available yet") describing a
webhook system TrakRF intended to build. What shipped is narrower and has different
guarantees:

| The existing page claims                               | What shipped                                  |
| ------------------------------------------------------ | --------------------------------------------- |
| Four event types at launch                              | One: `asset.moved`                            |
| At-least-once delivery                                  | **At-most-once**                              |
| Exponential backoff with jitter over ~24 hours          | Two retries (~1s, ~5s, jittered), then dropped |
| A queryable delivery log                                | None in v1                                     |
| Optional per-event filters at registration              | None in v1                                     |
| Payloads carry scan device details                      | Logical data only — no device, EPC, or scan id |

Shipping the site with this page intact would be worse than having no webhooks page at
all: it promises reliability guarantees TrakRF does not provide, and an integrator who
builds against "at-least-once with a 24-hour retry ladder" will silently lose events.

This is therefore a **rewrite in place**, not a new page. Three other pages carry stale
webhook claims, and the webhook CRUD routes are missing from the private-endpoints
catalog.

The webhook surface documents itself nowhere. The CRUD routes are deliberately tagged
`webhooks,internal` with no `public` swagger tag and no `RequireScope` — registering a
webhook is an org-settings action, not something an integrator's API key does — so they
are absent from the generated OpenAPI reference that Redocusaurus renders. Every word of
this is hand-written prose.

## Audience

An integrator writing a receiver. The page is read top-to-bottom once, then used as a
reference while debugging a handler that isn't firing.

## Ground truth

Verified directly against the shipped implementation rather than taken from the ticket
text. Sources: `backend/internal/webhook/{payload,sign,client,sink}.go`,
`backend/internal/assetevent/{event,dispatcher,evaluator}.go`,
`backend/internal/handlers/webhooks/webhooks.go`,
`backend/internal/models/webhook/webhook.go`, `backend/migrations/`.

Three findings refine what the ticket specified:

1. **The signed timestamp is `occurred_at`, not send time.** `client.go` derives
   `X-TrakRF-Timestamp` from `ev.OccurredAt.UTC().Unix()`. It is therefore stable across
   the retries of one delivery, and a receiver's tolerance window is measured against the
   scan instant, not the transmission instant. The ticket's "~5 minute tolerance" advice
   is still right, but the page must say what the timestamp actually is or a receiver
   author will assume send time and set the window too tight.

2. **Ids are obfuscated at the database layer, not in application code.** `assets.id` is
   `BIGINT` populated by the `trakrf.generate_obfuscated_id()` trigger (migration
   `000006`), whose output range is `[0, 2^52)`. The webhook payload selects `id` straight
   from the table, so the wire id **is** the obfuscated surrogate id and does match the id
   the REST API returns. The consequence for the docs: the ticket's example ids (`555`,
   `10`, `20`) are unrealistically small and would lead an integrator to size a 32-bit
   field. Per operator decision, the example uses realistic 52-bit values instead of the
   ticket's verbatim payload.

3. **Signing secrets are `whsec_` + 64 hex characters**, and every response after create
   returns `Mask(secret)` — prefix, ellipsis, last four. The ticket says the secret is
   shown once; the format and the masking are worth stating so a user recognizes the
   masked form as expected rather than as corruption.

Everything else in the ticket verified as written: the envelope shape, all five headers,
the HMAC construction, at-most-once, the `{1s, 5s}` jittered ladder, the 5-second timeout,
refused redirects, and the SSRF guard.

One further detail the code makes clear and the page should carry: the address guard runs
in the dialer's `Control` hook, so it inspects the **resolved IP per connection**.
`ValidateTargetURL` at registration only checks scheme and host. A customer can therefore
register a target that resolves into a blocked range with no error, and see only silent
delivery failures afterward. That asymmetry is exactly the kind of thing that becomes a
support ticket.

Also: when an org's entitlement lapses, skipped events are **dropped, never buffered** —
reinstating a subscription does not replay the gap.

## Design

### `docs/api/webhooks.md` — rewrite

Section order follows the receiver author's path:

1. **What it is.** Delta-only `asset.moved` push delivery; the alternative to polling
   `GET /api/v1/reports/asset-locations`. Available v1.3.
2. **What fires an event.** A pure delta — an event fires only when an asset is scanned at
   a location different from where it was last seen. Rescans at the same location send
   nothing; this is not a heartbeat. Carries the demo-carousel measurement (8 events from
   815 scans) as the concrete illustration, which is the fastest way to correct the
   "webhook = scan feed" misreading.
3. **Registering a webhook.** Account menu → **Webhooks**, or Organization Settings →
   **Manage webhooks →**. Admin required. One per organization. The signing secret is
   displayed exactly once on create, with no read-back and no rotation — losing it means
   delete and re-create. **Send test event** fires a synthetic `asset.moved` using
   obviously-fake identifiers (`TEST-ASSET`, "Test Origin" → "Test Destination") and
   reports the status code returned. The enable toggle stops delivery without deleting the
   registration. Screenshots land here.
4. **The payload.** The envelope, then a field-reference table. `from_location` is present
   and explicitly `null` — never omitted — for a genuine first-ever sighting. No
   `sequence` field. Logical data only.
5. **Headers.** Five-row table.
6. **Verifying the signature.** The construction (`HMAC-SHA256` over
   `timestamp + "." + rawBody`, hex, `sha256=` prefix); the raw-body-not-reparsed warning
   as a prominent callout; Node and Python snippets; why both use a constant-time compare;
   the tolerance window plus the `occurred_at` nuance from Ground truth.
7. **Delivery semantics.** At-most-once; two jittered retries then dropped, no DLQ and no
   replay; ordering not guaranteed, order by `occurred_at`; duplicates possible on the
   retry path, use `delivery_id` for idempotency; anything but 2xx burns a retry; 5-second
   timeout so acknowledge fast and work asynchronously; no event when the new scan has no
   location.
8. **Endpoint requirements.** https only, publicly reachable; refused address ranges, with
   the per-connection-at-delivery-time framing from Ground truth; redirects not followed,
   a 302 is a failed delivery.
9. **Reconciling missed events.** Replaces the old "What you can do today" section.
   Reframed from interim workaround to standing requirement: under at-most-once, periodic
   reconciliation against `GET /api/v1/reports/asset-locations` is part of a correct
   integration, not a stopgap.
10. **Events went quiet.** Troubleshooting checklist, leading with lapsed subscription and
    the enable toggle — an integrator whose events stop needs billing on the list of
    causes, not just their own infrastructure.
11. **Not in v1.** One short paragraph. No shapes, no dates — the Phase 2 designs are not
    settled and naming specifics would create expectations.

### Collateral

- `docs/api/README.mdx` — the Webhooks link description still reads "status of outbound
  delivery and the interim polling pattern". Rewrite for a shipped feature.
- `docs/api/resource-identifiers.md` — "When webhooks ship, events **will** fire…" moves
  to present tense.
- `docs/api/private-endpoints.md` — add the six `/api/v1/webhooks*` routes to the endpoint
  list. They are session-authenticated internal routes, which is precisely what that page
  catalogs, and their absence is a gap now that the feature is live.
- `docs/api/versioning.md` — uses `webhooks:write` as a hypothetical example of a future
  scope. Misleading now that webhook CRUD has shipped with no scope at all. Swap the
  example for a different plausible one.
- `sidebars.ts` — move `api/webhooks` from the meta/tools tail (currently between
  `changelog` and `postman`) to immediately after `rate-limits`, closing the functional
  reference section. It is a capability now, not a status page.
- `docs/api/changelog.md` — add an entry. The page scopes itself to changes under
  `/api/v1/` and webhook CRUD is internal, but outbound delivery is a new integrator-facing
  contract, which is what the changelog exists to record.

### Screenshots

Three captures against preview, in a follow-up commit on the same PR so the prose is ready
to merge the moment TRA-1046 lands: the Webhooks screen empty state, the reveal-once secret
banner, and a test-fire result. Captured from a throwaway webhook — never a real secret.

## Constraints

- No documented field or behavior that is not in the shipped code. Where the ticket and the
  code disagree, the code wins.
- Nothing from TRA-398 Phase 2 documented as "coming soon" with specifics.
- No Linear ticket references in the published prose.
- Docs build clean, no broken internal links.

## Out of scope

TRA-398 Phase 2 in its entirety: N subscriptions, per-event filters, additional event types,
the full retry ladder, DLQ, per-delivery logs, secret rotation, IP allowlisting. Email/SMS
notification (TRA-1044) is a different feature with different delivery guarantees.

## Acceptance

- A webhooks page exists under the API section, reachable from the docs nav.
- Payload, all five headers, and both verification snippets are present and correct against
  the shipped implementation.
- At-most-once, no-ordering-guarantee, and lapsed-subscription behavior are each stated
  explicitly rather than implied.
- The raw-body-not-reparsed warning is present.
- No stale "planned" webhook language survives anywhere in `docs/`.
- `pnpm build` succeeds with no broken internal links.

## Release coupling

Webhooks exist on preview only; production is on v1.2. This work must not reach
`docs.trakrf.id` before the TRA-1046 production deploy. The PR is held open deliberately and
merged, alongside the TRA-1045 PR, immediately after that deploy.
