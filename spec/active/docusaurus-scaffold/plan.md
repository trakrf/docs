# Implementation Plan: Docusaurus Project Scaffolding
Generated: 2026-02-25
Specification: spec.md

## Understanding

Scaffold a Docusaurus site in the existing `trakrf/docs` repo. The repo already has project housekeeping files (LICENSE, CONTRIBUTING, CLAUDE.md, etc.) and CSW initialized. We need to layer Docusaurus on top, set up TrakRF branding (icon from www repo, default Docusaurus theme colors), create the full nav/sidebar structure with placeholder pages, and confirm it builds cleanly as a static site for Cloudflare Pages.

Key decisions from clarifying questions:
- **Adopt Docusaurus/Prettier defaults** (spaces, double quotes, trailing commas, 80 width) — drop our custom `.prettierrc` and `.editorconfig`
- **Logo/favicon from www repo** — `/home/mike/www/public/images/icon.png` (512x512 RFID inlay)
- **Default Docusaurus theme colors** — no custom brand palette exists yet

## Relevant Files

**Source Assets**:
- `/home/mike/www/public/images/icon.png` — RFID inlay icon for logo + favicon

**Files to Remove/Replace**:
- `.prettierrc` — replace with Docusaurus defaults (or remove entirely)
- `.editorconfig` — update to use spaces instead of tabs
- `.prettierignore` — update for Docusaurus paths

**Files to Modify**:
- `.gitignore` — already has Docusaurus entries, verify complete
- `README.md` — already has setup instructions, verify after init
- `CLAUDE.md` — may need minor updates for actual scripts
- `package.json` — Docusaurus will create this; merge with existing if needed

**Files to Create** (via Docusaurus init + manual):
- `docusaurus.config.ts` — site config with TrakRF branding
- `sidebars.ts` — sidebar nav structure
- `src/css/custom.css` — minimal custom styles
- `static/img/logo.png` — copied from www
- `static/img/favicon.ico` — generated from icon.png
- `docs/` — all placeholder pages (see Task 4 for full list)
- `tsconfig.json` — TypeScript config

## Architecture Impact
- **Subsystems affected**: 1 (static site only)
- **New dependencies**: `@docusaurus/core`, `@docusaurus/preset-classic`, `react`, `react-dom`, and their peer deps
- **Breaking changes**: None (greenfield)

## Task Breakdown

### Task 1: Initialize Docusaurus
**Action**: CREATE (via CLI)

Run Docusaurus init with TypeScript template. Since we have existing files in the repo, we'll init into a temp directory and move files over to avoid conflicts with our existing housekeeping files.

**Implementation**:
```bash
# Init Docusaurus in temp dir
cd /tmp && pnpm dlx create-docusaurus@latest trakrf-docs-init classic --typescript

# Copy Docusaurus files into our repo (without overwriting our files)
# Key files: docusaurus.config.ts, sidebars.ts, src/, static/, docs/, tsconfig.json, package.json
```

Merge `package.json` carefully — keep our existing metadata, add Docusaurus deps and scripts.

**Validation**:
- `pnpm install` succeeds
- `pnpm dev` starts without errors

### Task 2: Update Formatting Config
**Action**: MODIFY

Replace our tab-based prettier/editor config with Docusaurus-standard spaces.

**Implementation**:
- Remove `.prettierrc` (use Docusaurus/Prettier defaults, or keep minimal)
- Update `.editorconfig` to use `indent_style = space`, `indent_size = 2`
- Update `.prettierignore` to cover `build/`, `.docusaurus/`, `node_modules/`

**Validation**:
- No formatting config conflicts

### Task 3: Apply TrakRF Branding
**Action**: MODIFY

**Implementation**:
- Copy `icon.png` from www to `static/img/logo.png`
- Generate favicon from icon.png (or use png directly — Docusaurus supports it)
- Update `docusaurus.config.ts`:
  - `title`: "TrakRF Docs"
  - `tagline`: "RFID Asset Tracking Platform"
  - `url`: "https://docs.trakrf.id"
  - `favicon`: "img/favicon.ico" (or "img/logo.png")
  - Navbar logo: point to logo.png
  - Footer: TrakRF branding, links to trakrf.id

**Validation**:
- `pnpm dev` shows TrakRF title and logo
- Favicon renders in browser tab

### Task 4: Create Sidebar Structure and Placeholder Pages
**Action**: CREATE

Create all placeholder docs per TRA-83 content plan.

**Directory structure**:
```
docs/
├── getting-started.md
├── user-guide/
│   ├── reader-setup.md
│   ├── asset-management.md
│   ├── location-tracking.md
│   ├── reports-exports.md
│   └── organization-management.md
├── api/
│   ├── authentication.md
│   ├── rest-api-reference.md
│   ├── webhooks.md
│   ├── rate-limits.md
│   └── error-codes.md
└── integrations/
    ├── mqtt-message-format.md
    └── fixed-reader-setup.md
```

Update `sidebars.ts` with three categories:
1. **User Documentation** — getting started + user-guide/*
2. **API Documentation** — api/*
3. **Integration Guides** — integrations/*

Each placeholder page gets: title, brief description, "Coming soon" note.

**Validation**:
- All sidebar items render
- All links resolve to pages
- No broken links

### Task 5: Clean Up Default Docusaurus Content
**Action**: MODIFY

Remove Docusaurus tutorial/blog boilerplate:
- Delete default `docs/tutorial-*` or `docs/intro.md` pages
- Remove or simplify default `src/pages/index.tsx` (make it a simple landing/redirect to docs)
- Remove default blog if present
- Clean up any placeholder content that doesn't fit

**Validation**:
- No leftover tutorial content
- Landing page is clean

### Task 6: Final Validation and README Update
**Action**: MODIFY

**Implementation**:
- Run full build: `pnpm build`
- Verify output is in `build/` directory
- Verify output is pure static (no SSR runtime)
- Update `README.md` if any scripts or setup steps changed
- Update `CLAUDE.md` if needed

**Validation** (from spec/stack.md):
```bash
pnpm build    # Must complete without errors
pnpm serve    # Must serve the built site
```

All validation criteria from spec:
- [ ] `pnpm dev` starts local server successfully
- [ ] `pnpm build` completes without errors
- [ ] All nav items render and link to placeholder pages
- [ ] TrakRF logo visible on the site
- [ ] Site title shows "TrakRF Docs"
- [ ] No broken links in sidebar navigation
- [ ] Output is static (no SSR runtime needed)

## Risk Assessment
- **Risk**: Docusaurus init conflicts with existing repo files
  **Mitigation**: Init in temp dir and copy files over selectively
- **Risk**: Node 22 compatibility with latest Docusaurus
  **Mitigation**: Docusaurus 3.x supports Node 18+, should be fine
- **Risk**: favicon generation from PNG
  **Mitigation**: Docusaurus can use PNG directly as favicon, no conversion needed

## VALIDATION GATES (MANDATORY)

After EVERY task, run from `spec/stack.md`:
- `pnpm build` — must succeed
- `pnpm dev` — must start cleanly

If any gate fails: Fix immediately, re-run, repeat until pass.

## Plan Quality Assessment

**Complexity Score**: 4/10 (LOW)
**Confidence Score**: 9/10 (HIGH)

**Confidence Factors**:
- Clear requirements from spec and Linear issues
- Standard Docusaurus scaffolding — well-documented framework
- No custom code — just config and placeholder content
- Single subsystem (static site)
- Assets available in www repo

**Estimated one-pass success probability**: 90%

**Reasoning**: This is a standard Docusaurus init with branding and content structure. The only mild risk is merging the init output with our existing repo files, but that's straightforward with the temp-dir approach.
