---
sidebar_position: 2
---

# REST API Reference

The complete, always-current reference for every endpoint in the TrakRF public API lives at [**`/api`**](/api). That page is rendered directly from the OpenAPI 3.0 spec that ships with each release — endpoint list, request/response shapes, parameters, and error codes are always in sync with the running service.

## What's in the reference

- Every endpoint under `/api/v1/` with its request shape, response shape, query parameters, and error catalog
- The API-key security scheme (Bearer JWT) with per-operation scope requirements
- Try-it-out widgets for exploration once you have an API key

## Raw spec and tooling

The machine-readable spec is downloadable in either format:

- [`/api/openapi.json`](/api/openapi.json) — JSON
- [`/api/openapi.yaml`](/api/openapi.yaml) — YAML

Feed the JSON spec to an OpenAPI code generator (openapi-generator-cli, NSwag, etc.) to scaffold a typed client in your language of choice.

## Postman

A ready-to-import Postman collection is available. See [Postman collection](./postman) for the download link and import steps.

## Related guides

- [Authentication](./authentication) — API keys, headers, scopes, worked examples
- [Rate limits](./rate-limits) — request budgets and `Retry-After` semantics
- [Error codes](./error-codes) — RFC 7807 envelope, validation errors, retry guidance
