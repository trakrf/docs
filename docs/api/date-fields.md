---
sidebar_position: 4
---

# Date fields

Every timestamped resource in the TrakRF v1 API uses the same two effective-date fields: `valid_from` and `valid_to`. This page describes their shape on the wire and what the API accepts on input. Audit timestamps (`created_at`, `updated_at`, `deleted_at`) follow a different convention and are not covered here.

## The two fields at a glance

| Field        | Always present?         | Type on response | Meaning                                                                    |
| ------------ | ----------------------- | ---------------- | -------------------------------------------------------------------------- |
| `valid_from` | Yes                     | RFC3339 UTC      | When the record became effective. Defaults to the creation time on insert. |
| `valid_to`   | No — omitted when unset | RFC3339 UTC      | When the record expires. **Absent key = no expiry.**                       |

The API never returns `0001-01-01T00:00:00Z` zero-time, never returns a `2099-12-31` far-future sentinel, and never returns `"valid_to": null`. If a client sees any of these, it's a bug — see the [Changelog](./CHANGELOG) entry for the normalization cleanup ([TRA-468](https://linear.app/trakrf/issue/TRA-468)).

## Outbound: always RFC3339

Every `valid_from` / `valid_to` on the response is RFC3339 in UTC — clients can parse with a single formatter without branching on shape. Two records from the same list endpoint, one with an expiry and one without:

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
      "valid_from": "2026-02-01T00:00:00Z"
    }
  ]
}
```

Note that the second record has **no `valid_to` key at all** — not `"valid_to": null`, not `"valid_to": ""`. Test for the key's presence, not its value.

## Inbound: RFC3339 only

Send `valid_from` / `valid_to` as **RFC3339 in UTC** (e.g. `2026-04-24T15:30:00Z`). The OpenAPI spec declares both fields as `format: date-time`, and that is the contract — generated clients and spec validators will reject anything else. Use a date library to format your inputs (`Instant.toString()` in Java, `datetime.isoformat() + "Z"` in Python, `new Date().toISOString()` in JavaScript) rather than constructing the string by hand.

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
    "valid_from": "2026-04-24T00:00:00Z"
  }
}
```

The response **omits `valid_to`** because the asset has no expiry. If a later `PUT` sets `valid_to`, subsequent reads will return it as RFC3339.
