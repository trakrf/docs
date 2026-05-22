---
sidebar_position: 4
---

# Data model: master sync and scan data

The TrakRF public API surfaces two categories of data and treats them differently on writes. Knowing which category a field falls into tells you whether you can `POST` / `PATCH` it from your side or whether the API is read-only on it.

- **Master data** is **read-write.** The API both accepts it on write and returns it on read. Your system of record is upstream; you sync into TrakRF.
- **Scan / operational data** is **read-only.** The API returns it for consumption. Collection happens through ingestion paths that are deliberately separate from the public API — fixed-reader MQTT and handheld UI submission.

If you tried to `POST` or `PATCH` `location_id` on an asset and got `400 read_only`, this page is the explanation. The short answer: asset location is scan-derived, not partner-set. The longer answer follows.

## Master data (read-write)

Master data is the set of resources the API both serves on read and accepts on write. These resources represent partner-side facts — what assets exist, where the locations are organized, which tag is on which asset — and you keep them in sync from a system of record on your side (ERP, WMS, facilities management, tag printer, asset-management software).

| Resource                  | Typical upstream system                                                                        | Write surface                                                                                                                                              |
| ------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Assets                    | ERP, asset-management software                                                                 | `POST /api/v1/assets`, `PATCH /api/v1/assets/{asset_id}`, `POST /api/v1/assets/{asset_id}/rename`, `DELETE /api/v1/assets/{asset_id}`                      |
| Locations                 | Facilities management, WMS, layout tool (hierarchical via `parent_id` / `parent_external_key`) | `POST /api/v1/locations`, `PATCH /api/v1/locations/{location_id}`, `POST /api/v1/locations/{location_id}/rename`, `DELETE /api/v1/locations/{location_id}` |
| Tag-asset associations    | Tag printer firmware, ERP-managed tag inventory (print-and-apply workflows)                    | `POST /api/v1/assets/{asset_id}/tags`, `DELETE /api/v1/assets/{asset_id}/tags/{tag_id}`                                                                    |
| Tag-location associations | Facilities tag printer, fixed-installation BLE/RFID layout                                     | `POST /api/v1/locations/{location_id}/tags`, `DELETE /api/v1/locations/{location_id}/tags/{tag_id}`                                                        |

The rename endpoints are master-data operations. `external_key` is immutable through `PATCH` (sending a different value returns `400 validation_error` / `code: invalid_context` — the field is settable, just not via this verb); the `/rename` endpoint is the canonical mutation path. See [Resource identifiers → Renaming an `external_key`](./resource-identifiers#renaming-an-external_key) for the rationale.

Tag-asset associations stay on the public API because the integration use case is real — partners running print-and-apply lines or ERP-synced tag inventories drive these writes from their side. The tag CRUD surface is part of the master-data category and behaves like the others (POST to attach, DELETE to detach; the parent resource's read shape includes the current tag set).

## Scan / operational data (read-only)

Scan / operational data is the set of resources the API exposes for **consumption only.** Collection happens through ingestion paths that are deliberately separate from the public API:

- **Fixed-reader MQTT pipeline.** Readers in the field publish scan events to MQTT topics the platform subscribes to. The MQTT contract is not a public-API surface; integrator-facing access is through the consumption endpoints below.
- **Handheld UI submission.** The operator workflow submits scans through the TrakRF web and mobile apps. The submission path is internal to the first-party UI; it is not on the public API.

The separation is intentional. Scan data carries provenance — which reader observed the tag, at what time, under what auth — that the public-API write path cannot reproduce without re-implementing the ingestion contract. Keeping ingestion off the public API is what makes the read views trustworthy: every row served by the endpoints below traces back to a scan event with verifiable origin, not a partner-side guess about where an asset is.

Consumption endpoints for scan data:

| Endpoint                                | Shape                                                    | Scope           |
| --------------------------------------- | -------------------------------------------------------- | --------------- |
| `GET /api/v1/assets/{asset_id}/history` | Per-asset scan history; time-series rows                 | `tracking:read` |
| `GET /api/v1/reports/asset-locations`   | Bulk current-location lookup across assets               | `tracking:read` |

Both endpoints are projections of the scan-event stream — that's why the scope name reflects data lineage rather than the URL shape. See [Authentication → Scopes](./authentication#scopes) for the full mapping.

Current location is **not** a field on the asset resource. `GET /api/v1/assets` and `GET /api/v1/assets/{asset_id}` return master data only — name, `external_key`, `is_active`, effective dates, tags. To read where an asset is, use the two scan-data endpoints above.

### What you cannot do

- **`POST /api/v1/assets` with `location_id` or `location_external_key` in the body** returns `400 read_only`. The fields are absent from `CreateAssetWithTagsRequest`. Create the asset; record scans to populate location.
- **`PATCH /api/v1/assets/{asset_id}` with `location_id` or `location_external_key` in the body** returns `400 read_only`. The fields are absent from `UpdateAssetRequest` — and from the asset response shape — so there is nothing to round-trip; `PATCH` rejects them on presence, exactly as `POST` does.
- **There is no public endpoint to record a scan event from a partner side.** Ingestion is reader-pipeline-only by design.

## Consumption pattern guidance

The most common integrator pattern is "I have a list of asset external keys from my system of record and I want their current locations." The canonical batch-lookup form is the asset-locations report:

```bash
curl -H "Authorization: Bearer $TRAKRF_API_KEY" \
     "$BASE_URL/api/v1/reports/asset-locations?asset_external_key=SKU-7421-A&asset_external_key=BACK-STORAGE-2"
```

The response is one row per scanned asset, with `asset_external_key`, `location_id`, `location_external_key`, and `asset_last_seen` for each. Pass repeated `asset_external_key` parameters for the assets you care about; the server returns rows in `-asset_last_seen` order by default. The `asset_external_key` query parameter (and its surrogate sibling `asset_id`) is the [repeatable filter](./pagination-filtering-sorting#filtering) that makes this batch-lookup expressible in one request rather than N — see [Pagination, filtering, sorting](./pagination-filtering-sorting) for the cursor and sort surface and the full filter param list on this endpoint.

If you only have surrogate ids in hand (you cached them from a previous create or list), use `asset_id` instead — both filter forms are supported, and the resolution rules match every other paired-key surface on the API (the two are [mutually exclusive in a single request](./pagination-filtering-sorting#paired-by-id-and-by-natural-key-filters-are-mutually-exclusive); the asset and location filter pairs are independent and intersect when combined). For a single asset, filter the report down to it — `GET /api/v1/reports/asset-locations?asset_id=4287` — or read the latest row of `GET /api/v1/assets/{asset_id}/history`; the asset resource itself carries no location field.

For per-asset history rather than current-state — "where has this asset been over the last seven days" — use `GET /api/v1/assets/{asset_id}/history?from=...&to=...`. The endpoint is the projection of the same scan-event stream with a different shape (time-series rows rather than current-state pairs). See [Pagination, filtering, sorting → Time range (history)](./pagination-filtering-sorting#time-range-history) for the `from`/`to` semantics.

## See also

- [Resource identifiers](./resource-identifiers) — how to address master-data rows by `id` or `external_key`.
- [Resource identifiers → Read shape vs. write shape](./resource-identifiers#read-shape-vs-write-shape) — the per-field write-surface table, including the `read_only` rejection contract for scan-derived fields on the asset write surface.
- [Authentication → Scopes](./authentication#scopes) — `assets:write` / `locations:write` for master-data mutations, `tracking:read` for scan-data consumption.
- [Errors → `read_only`](./errors#error-type-catalog) — the validation-error envelope returned when a write targets a read-only field.
