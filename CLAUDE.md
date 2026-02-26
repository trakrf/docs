# CLAUDE.md

This file provides guidance to Claude when working with code in this repository.

## Project Overview

Standalone **Docusaurus documentation site** for trakrf (`trakrf/docs`). Content-focused — no application logic, no backend, no monorepo. Just docs and configuration.

## Package Manager

**pnpm EXCLUSIVELY** — never use `npm` or `npx`.
- `npx` → `pnpm dlx`
- `npm run` → `pnpm`

## Common Commands

```bash
pnpm dev          # Local dev server
pnpm build        # Production build
pnpm serve        # Serve production build locally
pnpm typecheck    # Type checking
pnpm lint         # Linting
```

## Git Workflow

**NEVER PUSH DIRECTLY TO MAIN BRANCH**
1. ALL changes go through a Pull Request — no exceptions
2. Always create a feature/fix branch: `feature/add-xyz`, `fix/broken-xyz`, `docs/update-xyz`
3. NEVER squash merge — preserve individual commit history
4. NEVER merge without explicit confirmation
5. Use conventional commits: `feat:`, `fix:`, `docs:`, `chore:`
6. Prefer incremental commits over amending

## Style & Conventions

- **TypeScript** for any config or custom components
- **ES Modules only** — no CommonJS
- **Prettier** for formatting
- **Conventional Commits** for git messages
- Keep files under 500 lines

## AI Behavior Rules

- Ask questions when requirements are unclear
- Never delete code without explicit instruction
- Verify builds pass before claiming completion
- Report actual status — no false optimism
- Use only verified packages — no hallucinated imports
