# CLAUDE.md

@AGENTS.md

Docusaurus documentation site (`trakrf/docs`) — content and config only.
Branches, commits and merges: [CONTRIBUTING.md](CONTRIBUTING.md). Tooling:
`.claude/csw.json`.

- **pnpm exclusively** — `pnpm dlx` not `npx`, `pnpm` not `npm run`
- `pnpm dev` · `build` · `serve` · `typecheck` · `lint` (prettier, gates `validate`)
- TypeScript and ES modules for config and components
- **Specs and plans go to `superpowers/` at the root, never under `docs/`** —
  Docusaurus globs `docs/`, so a stray file renders locally but never in CI
- Merging to `main` publishes to customers immediately; unreleased behaviour
  waits as a draft PR. Preview builds against the preview API and is separate
- The OpenAPI spec is fetched from the live API at build, not checked in — spec
  changes originate in `trakrf/platform`
