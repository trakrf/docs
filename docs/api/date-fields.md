---
sidebar_position: 4
---

# Date fields

Every timestamped resource in the TrakRF v1 API uses the same two effective-date fields: `valid_from` and `valid_to`. This page describes their shape on the wire and what the API accepts on input. Audit timestamps (`created_at`, `updated_at`) follow a different convention and are not covered here. Soft-deletion is not surfaced as a general timestamp field on the public API — see [Resource identifiers → soft-delete is not a general field](./resource-identifiers#soft-delete-visibility) for where `asset_deleted_at` does appear and the conditions that surface it.

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
