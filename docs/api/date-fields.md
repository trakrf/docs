---
sidebar_position: 4
---

# Date fields

Every timestamped resource in the TrakRF v1 API uses the same two effective-date fields: `valid_from` and `valid_to`. This page describes their shape on the wire and what the API accepts on input. Audit timestamps (`created_at`, `updated_at`) follow a different convention and are not covered here. Soft-deletion is not surfaced as a general timestamp field on the public API — see [Resource identifiers → soft-delete is not a general field](./resource-identifiers#soft-delete-visibility) for where `asset_deleted_at` does appear and the conditions that surface it.

The history-derived endpoints carry their own per-row timestamp: `timestamp` on `GET /api/v1/assets/{asset_id}/history` and `last_seen` on `GET /api/v1/reports/asset-locations`. Both share the outbound RFC3339-UTC convention documented below for `valid_from`; their semantics and nullability are covered separately under [Scan-event date fields](#scan-event-date-fields).

## The two fields at a glance

| Field        | Always present? | Type on response       | Meaning                                                                    |
| ------------ | --------------- | ---------------------- | -------------------------------------------------------------------------- |
| `valid_from` | Yes             | RFC3339 UTC            | When the record became effective. Defaults to the creation time on insert. |
| `valid_to`   | Yes             | RFC3339 UTC, or `null` | When the record expires. **`null` = no expiry.**                           |

The API never returns `0001-01-01T00:00:00Z` zero-time and never returns a `2099-12-31` far-future sentinel. The unset signal for `valid_to` is JSON `null`, not an absent key and not a sentinel value. If a client sees a sentinel, it's a bug — please [report it](mailto:support@trakrf.id).

`valid_from` / `valid_to` drive the **currently-effective** predicate that list endpoints apply by default. See [Effective dating and `is_active`](./resource-identifiers#effective-dating-and-is-active) for the rule and the list-vs-path-param distinction.

## Outbound: always RFC3339 or `null`

Every `valid_from` on the response is RFC3339 in UTC. `valid_to` is either RFC3339 in UTC or JSON `null` — clients can parse the populated value with a single formatter and branch only on null vs. non-null. Two records from the same list endpoint, one with an expiry and one without:

```json
{
  "data": [
    {
      "id": 7,
      "external_key": "LOC-0001",
      "name": "Warehouse A",
      "valid_from": "2026-01-15T00:00:00Z",
      "valid_to": "2026-12-31T23:59:59Z"
    },
    {
      "id": 8,
      "external_key": "LOC-0002",
      "name": "Warehouse B",
      "valid_from": "2026-02-01T00:00:00Z",
      "valid_to": null
    }
  ]
}
```

Note that the second record's `valid_to` is **`null`, not absent** — the field is always emitted, with the OpenAPI spec marking it `nullable: true` and required. Null-check the value, don't key-check.

## Inbound: RFC3339 only

Send `valid_from` / `valid_to` as **RFC3339 in UTC** (e.g. `2026-04-24T15:30:00Z`). The OpenAPI spec declares both fields as `format: date-time`, and that is the contract — generated clients and spec validators will reject anything else. Use a date library to format your inputs (`Instant.toString()` in Java, `datetime.isoformat() + "Z"` in Python, `new Date().toISOString()` in JavaScript) rather than constructing the string by hand.

The body validator rejects (with `400 validation_error`) every form the spec doesn't permit — date-only (`2026-05-10`), slash-separated (`2026/05/10`), empty string, and the Go zero-time `0001-01-01T00:00:00Z` are all explicit rejections, not silent coercions to a server-computed default. To pick up the server's `valid_from` default on create, **omit the key entirely**; sending an empty string is a 400, not an auto-default trigger.

Sub-microsecond precision is accepted on input but truncated at write — `2026-04-24T15:30:00.123456789Z` round-trips as `2026-04-24T15:30:00.123456Z`. Microsecond is the storage precision; nanosecond is a wire-format affordance for clients whose date libraries default there.

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

The response carries `"valid_to": null` because the asset has no expiry. If a later `PUT` sets `valid_to`, subsequent reads will return it as RFC3339.

## Scan-event date fields {#scan-event-date-fields}

The two history-derived endpoints expose a per-row scan timestamp under different field names. Both reflect when a reader observed the tag, not when the surrounding asset or location record was created or last edited; they're projections of the underlying scan-event stream ([scan events are a domain concept, not an API resource](./resource-identifiers#scan-event-vocabulary)).

| Field       | Endpoint                                | Always present?                  | Meaning                                                                                                |
| ----------- | --------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `timestamp` | `GET /api/v1/assets/{asset_id}/history` | Yes — never `null`, never absent | When this scan event was observed for the asset.                                                       |
| `last_seen` | `GET /api/v1/reports/asset-locations`   | Yes — never `null`, never absent | When the asset's most recent scan was observed. Drives the `-last_seen` default sort on this endpoint. |

Both fields are declared `required` on their respective response schemas (`AssetHistoryItem.timestamp`, `AssetLocationItem.last_seen`) and **not** marked `nullable`. `/reports/asset-locations` returns one row per scanned asset, so an asset that has never been scanned does not appear in the response — there is no "scanned but `last_seen: null`" state.

### Wire format: RFC3339 in UTC, sub-second precision

Both fields are RFC3339 timestamps in UTC. They are emitted at sub-second precision — typically microsecond, mirroring the storage column's `timestamp with time zone` type. Sample row from `/reports/asset-locations`:

```json
{
  "asset_id": 4287,
  "asset_external_key": "SKU-7421-A",
  "location_id": 42,
  "location_external_key": "DOCK-1",
  "asset_deleted_at": null,
  "last_seen": "2026-04-28T00:33:38.021257Z"
}
```

A history-item row:

```json
{
  "timestamp": "2026-04-28T00:33:38.021257Z",
  "location_id": 42,
  "location_external_key": "DOCK-1",
  "duration_seconds": 1843
}
```

Sub-microsecond precision is a wire-format affordance — clients whose date libraries default to nanosecond won't see it on outbound (storage truncates to microsecond), but inbound parsing should tolerate any RFC3339 fractional-second precision. Use the same date-library helpers covered in [Inbound: RFC3339 only](#inbound-rfc3339-only).

### These fields are read-only

`timestamp` and `last_seen` are server-derived from the scan-event stream and have no inbound write path on the public API. There's no `POST /api/v1/asset_scans` or analogous endpoint for partner-side ingestion of scan events in v1; scan ingestion happens out-of-band through the reader integrations. The two fields above are pure projections — null-safe to read, never sent on a write.
