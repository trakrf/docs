# Feature: Docusaurus Project Scaffolding

## Origin

Linear [TRA-328](https://linear.app/trakrf/issue/TRA-328) — child of [TRA-83](https://linear.app/trakrf/issue/TRA-83) (stand up docs portal at docs.trakrf.id).

## Outcome

A working Docusaurus site in `trakrf/docs` that builds cleanly, has TrakRF branding, and has the nav/sidebar structure in place with placeholder pages ready for content.

## User Story

As a TrakRF developer or technical writer
I want a scaffolded documentation site with navigation structure
So that I can start writing content immediately without setup friction

## Context

**Repo**: `trakrf/docs` — standalone, not a monorepo
**Hosting**: Cloudflare Pages at `docs.trakrf.id` (infra handled separately in TRA-327)
**Framework**: Docusaurus (React-based, MDX, versioning, static generation)
**Package manager**: pnpm exclusively
**Node**: 22 (per .nvmrc)

The repo already has project housekeeping (LICENSE, CONTRIBUTING, etc.) and CSW initialized. This spec covers the actual Docusaurus scaffolding.

## Requirements

### 1. Docusaurus Init

- Initialize Docusaurus with TypeScript
- pnpm as package manager
- Verify `pnpm dev`, `pnpm build`, `pnpm serve` all work
- ES modules only

### 2. TrakRF Branding

- Logo and favicon (source from trakrf.id or www repo assets)
- Brand colors in custom CSS
- Site title: "TrakRF Docs"
- Tagline appropriate for RFID asset tracking platform

### 3. Navigation / Sidebar Structure

Per TRA-83 content plan:

**User Documentation**

- Getting Started / Quickstart
- Reader Setup (Web BLE pairing)
- Asset Management
- Location Tracking
- Reports & Exports
- Organization / Team Management

**API Documentation** (placeholder)

- Authentication
- REST API Reference
- Webhooks
- Rate Limits
- Error Codes

**Integration Guides** (placeholder)

- MQTT Message Format
- Fixed Reader Setup (future)

### 4. Placeholder Pages

- Each nav item should have a placeholder `.md` or `.mdx` page
- Enough content to show the structure is real (title, brief description, "coming soon" note)

### 5. Build & Deploy Readiness

- `pnpm build` produces clean output in `build/`
- Static output compatible with Cloudflare Pages
- No SSR dependencies — pure static site generation

## Out of Scope

- Actual documentation content (that's follow-up work)
- Cloudflare/DNS infra (TRA-327)
- Search integration (Algolia — later)
- API doc auto-generation from OpenAPI (later)
- Versioning setup (later)

## Validation Criteria

- [ ] `pnpm dev` starts local server successfully
- [ ] `pnpm build` completes without errors
- [ ] All nav items render and link to placeholder pages
- [ ] TrakRF logo/colors visible on the site
- [ ] Site title shows "TrakRF Docs"
- [ ] No broken links in sidebar navigation
- [ ] Output is static (no SSR runtime needed)

## References

- [Docusaurus docs](https://docusaurus.io/docs)
- [TRA-83](https://linear.app/trakrf/issue/TRA-83) — parent issue with content plan
- [TRA-327](https://linear.app/trakrf/issue/TRA-327) — Cloudflare infra (separate)
- Reference sites: docs.stripe.com, supabase.com/docs, docs.thingsboard.io
