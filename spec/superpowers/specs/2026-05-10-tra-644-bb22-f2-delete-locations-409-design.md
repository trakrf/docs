---
ticket: TRA-644
title: BB22 F2 — DELETE /locations 409 conflict on descendants or placed assets
status: design
date: 2026-05-10
---

# Goal

Update trakrf-docs prose to reflect platform PR [#289](https://github.com/trakrf/platform/pull/289) (merged 2026-05-10). `DELETE /api/v1/locations/{id}` previously returned `204` even when the location had active descendant locations (silently breaking the FK-pair invariant `parent_id != null AND parent_external_key == null`) and even when assets were placed directly at it (same shape of broken FK pair on `location_id` / `location_external_key`). After the platform change the handler runs a pre-check and returns `409 conflict` in either case, with distinct `detail` strings so integrators can branch correctly.

The acceptance bar from the parent ticket: the docs describe the rejection rules — descendants must be reassigned or removed, placed assets must be moved or removed, bulk cascade is not supported in v1.

# Scope

## `resource-identifiers.md` — new H2 `## Locations: delete semantics`

Insert a new top-level section between `## Location tree endpoints` and `## Asset external_key is optional`. Section covers:

1. **The shape.** `DELETE /api/v1/locations/{location_id}` returns `204` only when the location is a true leaf — no active descendant locations and no active placed assets. Otherwise the server rejects with `409 conflict` and the standard error envelope.
2. **The two rejection cases, with distinct `detail` strings.** One pre-check per call, descendants checked first.
   - "location has descendant locations; reassign or remove them before deleting (cascade is not supported)"
   - "location has assets placed at it; move or remove them before deleting (cascade is not supported)"
   - Distinct strings let integrators branch on which constraint failed without parsing free-form text fragments.
3. **Active means `deleted_at IS NULL`.** Soft-deleted descendants and soft-deleted placed assets do not block the delete. This matches the soft-delete model documented earlier on the page — soft-deleted rows are not addressable, and they don't tether their parent either.
4. **Why the rejection.** Preserves the FK-pair invariant the page documents elsewhere (`parent_id` and `parent_external_key` on locations; `location_id` and `location_external_key` on assets are both populated when the relationship exists, both `null` when unset, never one without the other). Silently allowing the delete would leave descendants pointing at a deleted parent — `parent_id` populated, `parent_external_key` null, `tree_path` retaining the stale parent segment — undefined under the docs.
5. **No bulk cascade in v1.** A `?cascade=true` query parameter is not supported. The narrow contract is intentional; the explicit-strip / move pattern the SPA uses keeps the responsibility on the caller. A separate endpoint may be added if customer demand surfaces.
6. **Discovery.** Pre-check before delete using existing read endpoints — `GET /api/v1/locations/{location_id}/descendants` for the descendant set, `GET /api/v1/locations/current?location_id={id}` (or `GET /api/v1/assets?location_id={id}`) for placed assets. Cross-link the descendants endpoint to the existing `## Location tree endpoints` section.
7. **One envelope example.** Show the 409 response shape (`error.type = "conflict"`, `error.title = "Conflict"`, `error.status = 409`, `detail` matching one of the two strings above) so partners can pattern-match. Use the existing error-envelope style on `errors.md` rather than inventing a new shape.

## `errors.md` — adjacent fixes

Two small edits to keep the page consistent with the new behavior:

1. **L67, conflict catalog row.** Today's text reads "Unique-constraint violation (typically a duplicate `external_key` on assets/locations or a duplicate `(tag_type, value)` on tags)." The 409 cause space is now broader. Reword to cover both classes: unique-constraint violations on natural keys (existing), and referential-integrity violations on `DELETE /api/v1/locations/{location_id}` (new) — link to the new delete-semantics section.
2. **L281, retry-safety bullet for DELETE assets/locations.** Today: "idempotent in the 'ends up gone' sense. A second delete returns `404 not_found` (not `204`) so you can detect state drift; both outcomes are fine to treat as 'deleted.'" Add a one-sentence aside that on locations the first call may return `409 conflict` if descendants or placed assets exist, and that retry of a 409 without first reconciling will keep returning 409 — the retry contract only covers the path-shape `404` case.

# Out of scope

- The OpenAPI spec mirror has already been refreshed on this branch (`scripts/refresh-openapi.sh` against `trakrf/platform@main` resolved to commit `74b15ab`; the new `409` response on `DELETE /locations/{location_id}` is in `static/api/openapi.{json,yaml}` and the regenerated Postman collection). No further spec edits.
- BB23 verification of the live behavior is the parent ticket's responsibility, not this PR. Per `feedback_docs_behind_preview`, the docs PR ships against preview; full BB23 audit happens later.
- A `?cascade=true` query parameter is a separate ticket if customer demand surfaces (per the parent ticket's out-of-scope clause).
- Asset deletion semantics — assets are leaf entities, no children, no dependents. Confirmed in the platform PR's audit. No analog page edit needed.
- Subresource link deletes (`DELETE /assets/{id}/tags/{tag_id}`, `DELETE /locations/{id}/tags/{tag_id}`) — pure association deletes with no cascade. Already documented as fully idempotent on `errors.md` L282.

# Audit-adjacent check

Verified before editing:

- `docs/api/quickstart.mdx` — round-trip example deletes a freshly-created leaf asset; not affected.
- `docs/api/authentication.md` L69 — scope table mentions `DELETE /locations/{location_id}` under `locations:write`. The scope is unchanged. No edit.
- `docs/api/pagination-filtering-sorting.md` — validator-behavior section covers PUT body fields. No DELETE-related prose to update.
- `docs/api/webhooks.md`, `docs/api/private-endpoints.md`, `docs/api/versioning.md`, `docs/api/date-fields.md`, `docs/api/rate-limits.md` — checked; no claims about DELETE locations behavior to update.
- `docs/api/errors.md` L281 already references DELETE locations idempotency and is the right home for the retry-safety nuance (case 2 above).

The conflict-catalog row on `errors.md` is the only adjacent staleness in the wider docs surface. No other named-finding fixes required.
