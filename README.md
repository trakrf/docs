# TrakRF Docs

Documentation site for the [TrakRF](https://trakrf.id) platform, built with [Docusaurus](https://docusaurus.io/).

## Getting Started

### Prerequisites

- Node.js 22+ (see `.nvmrc`)
- pnpm

### Setup

```bash
pnpm install
```

### Development

```bash
pnpm dev
```

This starts a local dev server at `http://localhost:3000`. Most changes are reflected live without restarting.

### Build

```bash
pnpm build
```

Generates static content into the `build/` directory.

The site builds in one of two modes, controlled by `DEPLOY_ENV`:

- `DEPLOY_ENV=production` — emits `https://docs.trakrf.id` / `https://app.trakrf.id` URLs in SSR HTML, sitemap, canonical tags, and the `<EnvBaseURL/>` family of components. The Redoc-rendered `/api` page fetches the spec from `https://app.trakrf.id/api/openapi.yaml` at build time.
- `DEPLOY_ENV=preview` (default for local dev) — emits the `*.preview.trakrf.id` equivalents and fetches the spec from `https://app.preview.trakrf.id/api/openapi.yaml`.

On Cloudflare Pages, set `DEPLOY_ENV=production` on the production environment and `DEPLOY_ENV=preview` on the preview environment. If unset, the build auto-detects from `CF_PAGES_BRANCH` (`main` → production, anything else → preview).

The OpenAPI spec is single-source on the platform; this site never stores a mirrored copy. `/api/openapi.{json,yaml}` 302s to `https://app.{env}.trakrf.id/api/openapi.{json,yaml}` via `functions/_middleware.js`.

### Serve

```bash
pnpm serve
```

Serves the production build locally for testing.

## App Tour Docs

The `docs/app-tour/` section contains a visual walk-through of every screen in the TrakRF web app. Screenshots are captured from platform running **locally** (not preview) so the app renders without the preview environment banner, using an agent with Playwright MCP against a seeded `TrakRF Docs` org.

See [`docs/app-tour/authoring.md`](docs/app-tour/authoring.md) for the full workflow, prerequisites, and fixture setup.

## `/health.json`

The deployed docs site serves `/health.json` (e.g. `https://docs.preview.trakrf.id/health.json`) so
anyone can spot-check which docs build is live. Emitted by `scripts/write-health-json.mjs` at build
time; `static/health.json` is **gitignored** — it's a build artifact.

Platform identity and `spec_refreshed_at` live on the platform's own
`https://app.{env}.trakrf.id/health.json` — there's no longer a mirrored `platform` block here.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) - DevOps To AI LLC dba TrakRF
