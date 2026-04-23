---
sidebar_position: 6
---

# Private endpoints

:::caution Internal endpoints
The endpoints marked **Internal** in the table below are used by the first-party TrakRF web app and are **not published** in the OpenAPI spec at [`/api`](/api). Third-party integrations must not depend on them — they can change without notice.

If you need functionality not available via the documented public API, [email support](mailto:support@trakrf.id) so we can prioritize exposing the right primitives.
:::

## Endpoint list

| Endpoint                       | Method(s) | Used by               | Status                      | Classification |
| ------------------------------ | --------- | --------------------- | --------------------------- | -------------- |
| `/api/v1/auth/login`           | POST      | SPA login form        | Internal                    | Internal       |
| `/api/v1/auth/signup`          | POST      | SPA signup form       | Internal                    | Internal       |
| `/api/v1/auth/forgot-password` | POST      | SPA password recovery | Internal                    | Internal       |
| `/api/v1/auth/reset-password`  | POST      | SPA password recovery | Internal                    | Internal       |
| `/api/v1/auth/accept-invite`   | POST      | SPA invite acceptance | Internal                    | Internal       |
| `/api/v1/users/me`             | GET       | SPA user context      | Internal                    | Internal       |
| `/api/v1/users/me/current-org` | POST      | SPA org switcher      | Internal                    | Internal       |
| `/api/v1/orgs`                 | GET       | SPA org picker        | Internal                    | Internal       |
| `/api/v1/orgs/{id}`            | GET       | SPA org detail        | Internal                    | Internal       |
| `/api/v1/orgs/me`              | GET       | API-key health check  | Public (see [`/api`](/api)) | Public         |

## Response shape: `/orgs/me` {#orgs-me}

`GET /api/v1/orgs/me` is excluded from rate limiting (see [Rate limits → Exclusions](./rate-limits#exclusions)) and is commonly used as an API-key liveness probe. It uses the same `{"data": ...}` envelope as every other endpoint on the public surface:

```json
{
  "data": {
    "id": 123,
    "name": "Example Org"
  }
}
```

If you're using `/orgs/me` as a health check, consider also probing a "real" endpoint (e.g. `GET /api/v1/assets?limit=1`) so your checks exercise the database path, not just the token verification path.

## Classification policy {#policy}

Every row above is one of:

- **Public** — published in [`/api`](/api). Contract stability covered by the OpenAPI spec and the [versioning policy](./versioning).
- **Internal** — listed here, not in [`/api`](/api). Subject to change without notice.

Public-with-caveats is not a separate classification. When a public endpoint has a stability nuance, it's expressed inline in the [`/api`](/api) reference (e.g. via `x-stability` or deprecation annotations on that endpoint).

If you believe a row belongs in a different bucket — especially if there's a concrete integration use case for an Internal endpoint — [email support](mailto:support@trakrf.id) and we'll review.
