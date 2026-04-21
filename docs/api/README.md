---
sidebar_position: 0
title: API docs
---

# TrakRF API

The TrakRF public REST API lets integrators read and write the same assets, locations, and scan events the first-party web app uses — via API-key authentication and predictable JSON.

This page is the map. The pages linked below are the territory.

## Where to start

- New to the API? **[Quickstart](./quickstart)** — mint a key, make your first call, round-trip a resource. ~10 minutes.
- Already know the shape? **[Interactive reference](/api)** — every endpoint, rendered from the OpenAPI spec that ships with each release.
- Generating a client? The raw spec is at [`/api/openapi.json`](/api/openapi.json) / [`.yaml`](/api/openapi.yaml), and a [Postman collection](./postman) is available too.

## Concept guides

- **[Authentication](./authentication)** — API keys, Bearer headers, scopes, key lifecycle
- **[Resource identifiers](./resource-identifiers)** — why you key on `identifier`, not `surrogate_id`
- **[Pagination, filtering, sorting](./pagination-filtering-sorting)** — conventions that apply to every list endpoint
- **[Errors](./errors)** — RFC 7807 envelope, error catalog, retry guidance
- **[Rate limits](./rate-limits)** — per-key token bucket, `X-RateLimit-*` headers, `Retry-After`
- **[Versioning](./versioning)** — v1 stability commitment, deprecation policy, open vs closed enums
- **[Changelog](./CHANGELOG)** — release-by-release record of added / deprecated / removed
- **[Webhooks](./webhooks)** — status of outbound delivery and the interim polling pattern
- **[Postman collection](./postman)** — ready-to-import collection
- **[Private endpoints](./private-endpoints)** — session-cookie-only endpoints used by the first-party web app (not part of the public API surface)

## License

This documentation site (`trakrf/docs`) is licensed under the MIT License. The source of these prose pages is in the [trakrf/docs GitHub repo](https://github.com/trakrf/docs) — file improvements or corrections there.

The TrakRF platform implementation lives in a separate repository under the Business Source License 1.1. Self-hosting platform operators should consult the platform repo's own `docs/api/` for operator-specific guidance (deployment, admin bootstrap, per-instance configuration); the API surface described here is the same in both cases.
