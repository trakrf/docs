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

### Serve

```bash
pnpm serve
```

Serves the production build locally for testing.

## App Tour Docs

The `docs/app-tour/` section contains a visual walk-through of every screen in the TrakRF web app, generated from `app.preview.trakrf.id`.

**Refresh screenshots only:**

```bash
bash scripts/refresh-screenshots.sh
```

Requires `.env` with `TRAKRF_PREVIEW_URL` and docs-tour credentials (copy from `.env.example`).

**Full regeneration** (prose + images): see [`docs/app-tour/AUTHORING.md`](docs/app-tour/AUTHORING.md).

## `/health.json`

The deployed docs site serves `/health.json` (e.g. `https://docs.preview.trakrf.id/health.json`) so
anyone can spot-check which build is live.

- `docs.{commit, build_time}` — emitted by `scripts/write-health-json.mjs` at build time. The file
  `static/health.json` is **gitignored** — it's a build artifact.
- `platform.{commit, tag, build_time, spec_refreshed_at}` — committed snapshot at
  `static/api/platform-meta.json`, written by `scripts/refresh-openapi.sh` whenever the OpenAPI spec
  is refreshed. It pins the bundled spec to a specific platform build.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) - DevOps To AI LLC dba TrakRF
