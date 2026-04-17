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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) - DevOps To AI LLC dba TrakRF
