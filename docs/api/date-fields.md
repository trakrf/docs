---
sidebar_position: 4
---

# Date fields

Every timestamped resource in the TrakRF v1 API uses the same two effective-date fields: `valid_from` and `valid_to`. This page describes their shape on the wire and what the API accepts on input. Audit timestamps (`created_at`, `updated_at`) follow a different convention and are not covered here. Soft-deletion surfaces as `deleted_at` on per-resource list rows (`/assets`, `/locations`) and as `asset_deleted_at` on the cross-resource report row from `/reports/asset-locations` — see [Resource identifiers → Soft-delete visibility on lists](./resource-identifiers#soft-delete-visibility) for the rule and the field-naming asymmetry.

:::note Audit timestamps in one paragraph
`created_at`, `updated_at`, and `deleted_at` are server-managed read-only fields. Outbound they share the wire shape used by everything else on the public API: RFC 3339 in UTC with fixed three-digit millisecond precision (`.NNNZ`). They cannot be set on `POST` or `PATCH` — any value differing from the current state returns `400 validation_error` / `code: read_only`. A verbatim `GET` → `PATCH` echo is accepted: the comparator matches by instant, so any RFC 3339 representation of the same point in time round-trips cleanly even when a generated client re-serializes via its language default (e.g. `+00:00` instead of `Z`, or microsecond fractional precision). See [Pagination, filtering, sorting → Validator behavior on writes](./pagination-filtering-sorting#validator-behavior-on-writes) and [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) for the full accept-if-matches contract.
:::

The history-derived endpoints carry their own per-row timestamp: `event_observed_at` on `GET /api/v1/assets/{asset_id}/history` and `asset_last_seen` on `GET /api/v1/reports/asset-locations`. Both share the outbound RFC 3339-UTC convention documented below for `valid_from`; their semantics and nullability are covered separately under [Scan-event date fields](#scan-event-date-fields).

## The two fields at a glance

| Field        | Always present? | Type on response        | Meaning                                                                    |
| ------------ | --------------- | ----------------------- | -------------------------------------------------------------------------- |
| `valid_from` | Yes             | RFC 3339 UTC            | When the record became effective. Defaults to the creation time on insert. |
| `valid_to`   | Yes             | RFC 3339 UTC, or `null` | When the record expires. **`null` = no expiry.**                           |

The API never returns `0001-01-01T00:00:00Z` zero-time and never returns a `2099-12-31` far-future sentinel. The unset signal for `valid_to` is JSON `null`, not an absent key and not a sentinel value. If a client sees a sentinel, it's a bug — please [report it](mailto:support@trakrf.id).

`valid_from` / `valid_to` drive the **currently-effective** predicate that list endpoints apply by default. See [Effective dating and `is_active`](./resource-identifiers#effective-dating-and-is-active) for the rule and the list-vs-path-param distinction.

## Outbound: always RFC 3339 or `null`

Every `valid_from` on the response is RFC 3339 in UTC. `valid_to` is either RFC 3339 in UTC or JSON `null` — clients can parse the populated value with a single formatter and branch only on null vs. non-null. Two records from the same list endpoint, one with an expiry and one without:

```json
{
  "data": [
    {
      "id": 7,
      "external_key": "LOC-001",
      "name": "Warehouse A",
      "valid_from": "2026-01-15T00:00:00Z",
      "valid_to": "2026-12-31T23:59:59Z"
    },
    {
      "id": 8,
      "external_key": "LOC-002",
      "name": "Warehouse B",
      "valid_from": "2026-02-01T00:00:00Z",
      "valid_to": null
    }
  ]
}
```

Note that the second record's `valid_to` is **`null`, not absent** — the field is always emitted, with the OpenAPI spec marking it `nullable: true` and required. Null-check the value, don't key-check.

## Inbound: RFC 3339, any offset {#inbound-rfc3339-only}

Send `valid_from` / `valid_to` as **RFC 3339** (e.g. `2026-04-24T15:30:00Z`). The OpenAPI spec declares both fields as `format: date-time`, and that is the contract — generated clients and spec validators will reject anything else. Use a date library to format your inputs (`Instant.toString()` in Java, `datetime.isoformat() + "Z"` in Python, `new Date().toISOString()` in JavaScript) rather than constructing the string by hand.

The service accepts any valid RFC 3339 timestamp regardless of offset — both `Z` and a numeric offset like `+05:00` parse. **Non-UTC offsets are silently converted to UTC at write**, so a `valid_from` sent as `2026-04-24T20:30:00+05:00` is stored — and emitted on the next read — as `2026-04-24T15:30:00Z`. The conversion is lossless on the instant: an integrator who sends a non-UTC offset gets the same point in time back, just normalized to `Z`. The one exception is the sentinel rejection rule below: non-UTC offsets that resolve to a rejected instant (e.g. `1970-01-01T05:00:00+05:00`) are still rejected — see [Default-value sentinels](#default-value-sentinels).

If you want your client-side pipeline to surface local-timezone bugs before they reach the server, **normalize to `Z` at the client** rather than relying on the service's silent conversion to mask them. Otherwise either form round-trips correctly to the same instant.

The body validator rejects (with `400 validation_error`) every form the spec doesn't permit — date-only (`2026-05-10`), slash-separated (`2026/05/10`), and empty string are all explicit rejections, not silent coercions to a server-computed default. Format failures return `fields[].message` = `"{field} must be an RFC 3339 timestamp"` (e.g. `"valid_from must be an RFC 3339 timestamp"`). Two otherwise-valid RFC 3339 timestamps are also rejected as default-value sentinels — see [Default-value sentinels](#default-value-sentinels) below. Date-only support is not on the v1 launch surface and may be added in a later v1.x release; today, send a full RFC 3339 timestamp every time. To pick up the server's `valid_from` default on create, **omit the key entirely**; sending an empty string is a 400, not an auto-default trigger.

Sub-microsecond precision is accepted on input but **truncated toward zero** to the microsecond at write. Storage is microsecond; the wire is millisecond. The combined round-trip for `2026-04-24T15:30:00.123456789Z` is: stored as `2026-04-24T15:30:00.123456` in Postgres (the `.789` tail dropped at the µs boundary), emitted on a subsequent read as `2026-04-24T15:30:00.123Z` (the `.456` tail dropped at the ms boundary, per [Wire format](#scan-event-date-fields) on outbound). Truncation toward zero is uniform at both boundaries — `.0000015Z` stores as `.000001`, `.9999999Z` stores as `.999999`; the wire then keeps only the leading three digits. The behavior is deterministic; if you need a specific millisecond on the wire, send no more precision than that.

### Default-value sentinels are rejected {#default-value-sentinels}

Two otherwise-valid RFC 3339 timestamps are rejected as default-value sentinels:

- `0001-01-01T00:00:00Z` — the Go zero time.
- `1970-01-01T00:00:00Z` — the Unix epoch.

Both are programming-language default-value markers that almost always mean an upstream serializer forgot to map "unset" to JSON `null`. Silent acceptance would produce rows that drop out of the [currently-effective predicate](./resource-identifiers#effective-dating-and-is-active) at read time and look like missing assets in reports — a worse surprise than rejecting at write time. The rejection is by exact instant, not a heuristic, so the documented list above is the full list; nearby real values (`1970-01-01T00:00:01Z`, `1969-12-31T23:59:59Z`) are accepted normally. Non-UTC offsets that resolve to the same instant (e.g. `1970-01-01T05:00:00+05:00`) are also rejected — changing the offset isn't a workaround.

Sentinel rejections share `code: invalid_value` with other value-validation failures and have a distinct `message` that echoes the offending value and names JSON `null` as the unset signal:

```json
{
  "error": {
    "type": "validation_error",
    "title": "Validation failed",
    "status": 400,
    "detail": "valid_to must not be a default-value sentinel (1970-01-01T00:00:00Z); use JSON null to leave the field unset",
    "instance": "/api/v1/assets/4287",
    "request_id": "01JXXXXXXXXXXXXXXXXXXXXXXX",
    "fields": [
      {
        "field": "valid_to",
        "code": "invalid_value",
        "message": "valid_to must not be a default-value sentinel (1970-01-01T00:00:00Z); use JSON null to leave the field unset"
      }
    ]
  }
}
```

For programmatic handling, branch on `fields[].code` as usual ([Errors → Validation errors](./errors#validation-errors)); the `message` is human-readable and not a wire contract. To send "unset" for `valid_to`, send JSON `null`; to leave a field unchanged on `PATCH`, omit it.

### `valid_from: null` is rejected on both Create and Update {#valid-from-null-rejected}

Sending `"valid_from": null` returns `400 validation_error` / `code: invalid_value` on both `POST` and `PATCH`. The unset signal is **key omission**, not explicit null: omit the key on `POST` to pick up the server default of now, and omit it on `PATCH` to leave the value unchanged. `valid_to` follows a different pattern — nullable on both create and update, where `null` means "no expiry."

## Example

Create an asset with an explicit `valid_from` and no `valid_to`, then read it back:

```bash
# Create — capture the assigned id from the response
ASSET_ID=$(curl -s -X POST \
     -H "Authorization: Bearer $TRAKRF_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "external_key": "ASSET-0042",
       "name": "Pallet jack",
       "valid_from": "2026-04-24T00:00:00Z"
     }' \
     "$BASE_URL/api/v1/assets" | jq -r '.data.id')

# Read it back by canonical id
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/assets/$ASSET_ID"
```

Response:

```json
{
  "data": {
    "id": 4287,
    "external_key": "ASSET-0042",
    "name": "Pallet jack",
    "valid_from": "2026-04-24T00:00:00Z",
    "valid_to": null
  }
}
```

The response carries `"valid_to": null` because the asset has no expiry. If a later `PATCH` sets `valid_to`, subsequent reads will return it as RFC 3339.

## Scan-event date fields {#scan-event-date-fields}

The two history-derived endpoints expose a per-row scan timestamp under different field names. Both reflect when a reader observed the tag, not when the surrounding asset or location record was created or last edited; they're projections of the underlying scan-event stream ([scan events are a domain concept, not an API resource](./resource-identifiers#scan-event-vocabulary)).

| Field               | Endpoint                                | Always present?                  | Meaning                                                                                                      |
| ------------------- | --------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `event_observed_at` | `GET /api/v1/assets/{asset_id}/history` | Yes — never `null`, never absent | When this scan event was observed for the asset.                                                             |
| `asset_last_seen`   | `GET /api/v1/reports/asset-locations`   | Yes — never `null`, never absent | When the asset's most recent scan was observed. Drives the `-asset_last_seen` default sort on this endpoint. |

Both fields are declared `required` on their respective response schemas (`AssetHistoryItem.event_observed_at`, `AssetLocationItem.asset_last_seen`) and **not** marked `nullable`. `/reports/asset-locations` returns one row per scanned asset, so an asset that has never been scanned does not appear in the response — there is no "scanned but `asset_last_seen: null`" state.

Both names follow the qualifier-prefix pattern shared with `asset_deleted_at` on the same report row — same-primitive cross-endpoint cohesion that preserves the event-row vs asset-most-recent semantic split.

### Wire format: RFC 3339 in UTC, fixed millisecond precision

Both fields are RFC 3339 timestamps in UTC, emitted with **fixed three-digit millisecond fractional precision** — every outbound timestamp on the public API carries `.NNNZ`, never `.NNNNNNZ`, never a bare `Z`. Sample row from `/reports/asset-locations`:

```json
{
  "asset_id": 4287,
  "asset_external_key": "SKU-7421-A",
  "location_id": 42,
  "location_external_key": "DOCK-1",
  "asset_deleted_at": null,
  "asset_last_seen": "2026-04-28T00:33:38.021Z"
}
```

A history-item row:

```json
{
  "event_observed_at": "2026-04-28T00:33:38.021Z",
  "location_id": 42,
  "location_external_key": "DOCK-1",
  "duration_seconds": 1843
}
```

The wire shape is uniform: no trailing-zero trimming, no nanosecond suffix. A regex match like `\.\d{3}Z$` is safe on every outbound timestamp the public API emits. The underlying `timestamp with time zone` column stores microsecond precision; the wire is truncated to millisecond because server-receipt-time on the reader path carries millisecond-scale network jitter, so the bottom three digits would be false precision relative to what reader clients can act on.

Inbound parsing on the `from` / `to` query parameters of `GET /api/v1/assets/{asset_id}/history` accepts any RFC 3339 fractional-second precision (0–9 digits) — a client may copy an emitted `event_observed_at` value verbatim into a filter without parse rejection, and a client whose date library emits nanosecond precision can pass it through unchanged. Use the same date-library helpers covered in [Inbound: RFC 3339 only](#inbound-rfc3339-only).

### `duration_seconds` on asset history rows

`AssetHistoryItem` carries a sibling field next to `event_observed_at` — `duration_seconds: integer | null` — that measures how long the asset stayed at the **previous** location before this row's scan moved it. The semantics:

| Value                | Meaning                                                                                                                             |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `null`               | This is the earliest scan event in the asset's history; there is no previous location to measure dwell against.                     |
| Non-negative integer | Whole seconds elapsed between the previous scan-event timestamp and this row's `event_observed_at`, while at the previous location. |

The field is declared `required` and `nullable: true` on `AssetHistoryItem` — always emitted, `null` only on the earliest row. Codegen-derived clients surface it as a non-optional nullable integer. Null-check the value, don't key-check.

`duration_seconds` is computed against scan-event timestamps at the storage layer; it doesn't surface on `/reports/asset-locations` (that endpoint reports the current snapshot, not a per-event dwell). For per-location dwell across an entire history window, sum `duration_seconds` across the relevant subset of rows on the client side.

### These fields are read-only

`event_observed_at`, `asset_last_seen`, and `duration_seconds` are server-derived from the scan-event stream and have no inbound write path on the public API. There's no `POST /api/v1/asset_scans` or analogous endpoint for partner-side ingestion of scan events in v1; scan ingestion happens out-of-band through the reader integrations. The three fields above are pure projections — null-safe to read, never sent on a write.
