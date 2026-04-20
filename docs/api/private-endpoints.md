---
sidebar_position: 6
---

# Private endpoints (classification pending)

:::caution Not part of the public API
The endpoints listed on this page are used by the first-party TrakRF web app but are **not currently published in the OpenAPI spec** at [`/api`](/api). Their classification — public API, internal-only, or something in between — is a pending platform decision.

Third-party integrations should not depend on these endpoints. If you need functionality not available via the documented public API, [email support](mailto:support@trakrf.id) so we can prioritize exposing the right primitives.
:::

## Endpoint list

| Endpoint | Method(s) | Used by | Status | Classification |
|---|---|---|---|---|
| `/api/v1/auth/login` | POST | SPA login form | Undocumented | Pending |
| `/api/v1/auth/signup` | POST | SPA signup form | Undocumented | Pending |
| `/api/v1/auth/forgot-password` | POST | SPA password recovery | Undocumented | Pending |
| `/api/v1/auth/reset-password` | POST | SPA password recovery | Undocumented | Pending |
| `/api/v1/auth/accept-invite` | POST | SPA invite acceptance | Undocumented | Pending |
| `/api/v1/users/me` | GET | SPA user context | Undocumented | Pending |
| `/api/v1/users/me/current-org` | GET | SPA org context | Undocumented | Pending |
| `/api/v1/orgs` | GET | SPA org picker | Undocumented | Pending |
| `/api/v1/orgs/{id}` | GET | SPA org detail | Undocumented | Pending |
| `/api/v1/orgs/{id}/api-keys` | GET, POST, DELETE | Settings → API Keys UI | Undocumented | Pending |
| `/api/v1/orgs/me` | GET | API-key health check | Undocumented | Pending — see response-shape note below |

## Response-shape note: `/orgs/me` {#orgs-me}

The `GET /api/v1/orgs/me` endpoint is currently excluded from rate limiting (see [Rate limits → Exclusions](./rate-limits#exclusions)) and is commonly used as an API-key liveness probe. It has a **different response shape** from the rest of the v1 API:

```json
{
  "id": 123,
  "name": "Example Org"
}
```

Unlike other endpoints — which wrap payloads in a `{ "data": ... }` envelope — this one returns a bare object. If it migrates to the standard envelope, clients keyed on the bare-object shape will break.

If you're using `/orgs/me` as a health check, prefer to also verify the standard envelope on a "real" endpoint (e.g. `GET /api/v1/assets?limit=1`) so your checks aren't tied to the current shape.

## Classification decisions to come

Each row in the table will be classified over time into one of:

- **Public** — added to the OpenAPI spec and appearing in the [`/api`](/api) reference. Integrators can rely on it.
- **Internal** — marked private (e.g. via an `X-Internal: true` middleware header); third parties must not depend on it.
- **Public-with-caveats** — documented publicly with explicit version/stability caveats.

This page tracks the state until those decisions land.
