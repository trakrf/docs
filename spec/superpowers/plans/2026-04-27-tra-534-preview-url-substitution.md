# TRA-534 — Build-Time URL Substitution for Preview Docs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make preview docs (`docs.preview.trakrf.id`) emit preview URLs in SSR'd HTML, link metadata, and the Redocusaurus spec download — so scrapers/AI ingesters/view-source copy-pasters get the right host.

**Architecture:**

- Single `DEPLOY_ENV=preview|production` env var read in `docusaurus.config.ts`
- `docusaurus.config.ts` derives `url` from it (fixes canonical/og/sitemap/Redocusaurus download)
- Exposes `customFields.deployEnv` so `useDeployEnv` SSR fallback consults the build env (fixes `<EnvBaseURL/>` SSR emission)
- Auto-fallback: if `DEPLOY_ENV` unset, infer from `CF_PAGES_BRANCH` (`main` → production, else preview); local dev defaults to preview
- Markdown audit limited to _unconditional_ prod-host references; leave deliberate prod+preview comparison docs (authentication.md "Base URL") alone

**Tech Stack:** Docusaurus 3.9, TypeScript, Cloudflare Pages, redocusaurus 2.5

**Out of scope:** rewriting `authentication.md` Base URL section (legit cross-env reference); CHANGELOG historical entries (frozen log); `static/api/openapi.yaml` `servers:` (handled in TRA-517).

---

## File Structure

**Modify:**

- `docusaurus.config.ts` — derive `url` from env, expose `customFields.deployEnv`/`docsHost`/`appHost`
- `src/hooks/useDeployEnv.ts` — `getServerSnapshot` reads `customFields.deployEnv` instead of hardcoded `"production"`; client snapshot prefers build env when no localStorage override and SSR-hydration mismatch is avoided
- `.env.example` — document `DEPLOY_ENV`
- `README.md` — short note on `DEPLOY_ENV` build var (one paragraph)

**Audit-and-fix (unconditional prod-only mentions):**

- `docs/getting-started/api.mdx:18` — `[sign up at app.trakrf.id](https://app.trakrf.id)` → env-aware sign-up link
- `docs/getting-started/ui.md:27` — `[app.trakrf.id](https://app.trakrf.id)` → env-aware (rename to `.mdx`, use `<EnvSignInLink>`)

**Leave alone (deliberate cross-env reference):**

- `docs/api/authentication.md` — every mention is paired with the preview URL; correct as-is
- `docs/api/quickstart.mdx:135`, `pagination-filtering-sorting.md:41`, `postman.mdx:31` — all "production OR preview" comparison lines, correct
- `docs/api/CHANGELOG.md` — historical entries

**No code changes:** `src/components/EnvBaseURL.tsx`, `EnvBaseURLBlock.tsx`, `EnvSignInLink.tsx` — they already use `useDeployEnv`; the SSR fix in the hook flows through automatically.

**CF Pages dashboard (manual, document only):**

- Production environment: set `DEPLOY_ENV=production`
- Preview environment: set `DEPLOY_ENV=preview` (or rely on `CF_PAGES_BRANCH != main` auto-detect)

---

## Task 1: Wire `DEPLOY_ENV` into `docusaurus.config.ts`

**Files:**

- Modify: `docusaurus.config.ts`

- [ ] **Step 1: Add env-resolution helper at top of config**

After the `import` lines, before `const config`:

```ts
type DeployEnv = "production" | "preview";

function resolveDeployEnv(): DeployEnv {
  const explicit = process.env.DEPLOY_ENV;
  if (explicit === "production" || explicit === "preview") return explicit;
  // CF Pages: main branch = production, anything else = preview
  if (process.env.CF_PAGES_BRANCH === "main") return "production";
  if (process.env.CF_PAGES === "1") return "preview";
  // Local dev / unknown: preview is the safer default (won't leak prod URLs)
  return "preview";
}

const deployEnv = resolveDeployEnv();
const docsHost =
  deployEnv === "production"
    ? "https://docs.trakrf.id"
    : "https://docs.preview.trakrf.id";
const appHost =
  deployEnv === "production"
    ? "https://app.trakrf.id"
    : "https://app.preview.trakrf.id";
```

- [ ] **Step 2: Replace hardcoded `url` and add `customFields`**

Change:

```ts
url: "https://docs.trakrf.id",
baseUrl: "/",
```

to:

```ts
url: docsHost,
baseUrl: "/",

customFields: {
  deployEnv,
  docsHost,
  appHost,
},
```

- [ ] **Step 3: Verify build picks up env**

```bash
DEPLOY_ENV=preview pnpm build 2>&1 | tail -20
```

Expected: build succeeds.

```bash
grep -c "docs.preview.trakrf.id" build/sitemap.xml
```

Expected: ≥ 1 (sitemap now uses preview URL).

```bash
grep -c "https://docs.trakrf.id" build/sitemap.xml
```

Expected: 0 (no production-host leaks in sitemap).

- [ ] **Step 4: Commit**

```bash
git add docusaurus.config.ts
git commit -m "feat(config): derive site url from DEPLOY_ENV for preview/production builds"
```

---

## Task 2: Fix SSR fallback in `useDeployEnv`

**Files:**

- Modify: `src/hooks/useDeployEnv.ts`

- [ ] **Step 1: Read build env from `customFields` for SSR snapshot**

Add an import at the top:

```ts
import siteConfig from "@generated/docusaurus.config";
```

Replace the file's hardcoded `PROD_HOST` / `PREVIEW_HOST` constants with values pulled from `customFields`, and update `getServerSnapshot` and `detectFromHostname` to use the build env as the default. Final state of the relevant section:

```ts
const STORAGE_KEY = "trakrf-env";
const CHANGE_EVENT = "trakrf-env-change";

const customFields = (siteConfig.customFields ?? {}) as {
  deployEnv?: DeployEnvLabel;
  docsHost?: string;
  appHost?: string;
};

const BUILD_DEPLOY_ENV: DeployEnvLabel =
  customFields.deployEnv === "production" ? "production" : "preview";

const PROD_HOST = "https://app.trakrf.id";
const PREVIEW_HOST = "https://app.preview.trakrf.id";

function readOverride(): DeployEnvLabel | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (raw === "production" || raw === "preview") return raw;
  return null;
}

function detectFromHostname(): DeployEnvLabel {
  if (typeof window === "undefined") return BUILD_DEPLOY_ENV;
  const host = window.location.hostname;
  if (host.startsWith("docs.preview.")) return "preview";
  if (host === "docs.trakrf.id") return "production";
  // localhost / unknown: trust the build env so dev matches prod-like SSR
  return BUILD_DEPLOY_ENV;
}

function getSnapshot(): DeployEnvLabel {
  return readOverride() ?? detectFromHostname();
}

function getServerSnapshot(): DeployEnvLabel {
  return BUILD_DEPLOY_ENV;
}
```

Note: `PROD_HOST` and `PREVIEW_HOST` are kept as-is since they are the _targets_ the hook resolves to — they need both values in the bundle so the EnvSwitcher can flip at runtime. The bug was only the SSR _default_, which is now fixed.

- [ ] **Step 2: Build preview and verify SSR'd quickstart no longer shows prod app host**

```bash
DEPLOY_ENV=preview pnpm build 2>&1 | tail -5
```

Expected: success.

```bash
grep -c "app.trakrf.id" build/docs/api/quickstart/index.html
```

Expected: 0 (was 4 per BB11 finding).

```bash
grep -c "app.preview.trakrf.id" build/docs/api/quickstart/index.html
```

Expected: ≥ 4 (the 4 SSR slots now resolve to preview).

- [ ] **Step 3: Sanity-check production build still emits production URLs**

```bash
DEPLOY_ENV=production pnpm build 2>&1 | tail -5 && grep -c "app.trakrf.id" build/docs/api/quickstart/index.html
```

Expected: ≥ 4. And:

```bash
grep -c "app.preview.trakrf.id" build/docs/api/quickstart/index.html
```

Expected: 0.

- [ ] **Step 4: Commit**

```bash
git add src/hooks/useDeployEnv.ts
git commit -m "fix(hook): useDeployEnv SSR snapshot reads build env from customFields"
```

---

## Task 3: Fix unconditional prod-host references in markdown

**Files:**

- Modify: `docs/getting-started/api.mdx`
- Rename + modify: `docs/getting-started/ui.md` → `docs/getting-started/ui.mdx`

- [ ] **Step 1: Replace prod-only sign-up link in `api.mdx`**

In `docs/getting-started/api.mdx`, add an import near the top of the file (after frontmatter, before first heading):

```mdx
import EnvSignInLink from "@site/src/components/EnvSignInLink";
```

Change line 18 from:

```
- A TrakRF account. If you were given preview credentials, you already have one — skip to step 1. Otherwise [sign up at app.trakrf.id](https://app.trakrf.id).
```

to:

```
- A TrakRF account. If you were given preview credentials, you already have one — skip to step 1. Otherwise <EnvSignInLink>sign up</EnvSignInLink>.
```

- [ ] **Step 2: Rename `ui.md` → `ui.mdx` and replace prod-only link**

```bash
git mv docs/getting-started/ui.md docs/getting-started/ui.mdx
```

Add at top of file (after frontmatter, before first heading):

```mdx
import EnvSignInLink from "@site/src/components/EnvSignInLink";
```

Change line 27 from:

```
1. Go to [app.trakrf.id](https://app.trakrf.id) and click **Sign up** (or navigate directly to `/#signup`).
```

to:

```
1. Go to <EnvSignInLink>the TrakRF app</EnvSignInLink> and click **Sign up** (or navigate directly to `/#signup`).
```

- [ ] **Step 3: Build preview and verify**

```bash
DEPLOY_ENV=preview pnpm build 2>&1 | tail -5
```

Expected: success (no broken-link errors — Docusaurus has `onBrokenLinks: "throw"`).

```bash
grep -c "app.preview.trakrf.id" build/docs/getting-started/api/index.html build/docs/getting-started/ui/index.html
```

Expected: ≥ 1 in each.

- [ ] **Step 4: Commit**

```bash
git add docs/getting-started/api.mdx docs/getting-started/ui.mdx
git commit -m "docs(getting-started): use env-aware sign-up link instead of hardcoded prod"
```

---

## Task 4: Verification pass — strict scan + document for PR

**Files:** none modified — produces verification commands for the PR description.

- [ ] **Step 1: Build a preview bundle**

```bash
DEPLOY_ENV=preview pnpm build
```

- [ ] **Step 2: Run the scrape-and-grep pass**

```bash
# Hostname leak scan: list any HTML/XML/JSON file in the build that
# mentions a production hostname, with line context
grep -rn -E "https?://(docs|app)\.trakrf\.id" build \
  --include="*.html" --include="*.xml" --include="*.json" \
  --include="*.yaml" --include="*.yml"
```

Expected output: only matches inside files derived from `docs/api/authentication.md`, `quickstart.mdx`, `pagination-filtering-sorting.md`, `postman.mdx`, and `CHANGELOG.md` (the deliberate cross-env reference docs and historical changelog).

Specifically expected to be ABSENT:

- Any match in `build/sitemap.xml`
- Any match in `build/index.html`
- Any match in `build/api/index.html` (Redocusaurus API Reference page)
- Any match in `build/docs/getting-started/api/index.html`
- Any match in `build/docs/getting-started/ui/index.html`
- Any prod-host mention of `redocusaurus/trakrf-api.yaml` or the OpenAPI download link

- [ ] **Step 3: Targeted check — Redocusaurus spec download link is preview**

```bash
grep -E "trakrf-api\.yaml|openapi\.(yaml|json)" build/api/index.html | head
```

Expected: any absolute URL there points to `docs.preview.trakrf.id`, not `docs.trakrf.id`.

- [ ] **Step 4: Targeted check — API Reference page absolute links**

```bash
# BB11 finding: 11 absolute links pointing at docs.trakrf.id
grep -oE 'https://docs\.trakrf\.id[^"'\'']*' build/api/index.html | wc -l
```

Expected: 0.

```bash
grep -oE 'https://docs\.preview\.trakrf\.id[^"'\'']*' build/api/index.html | wc -l
```

Expected: ≥ 11 (the same 11 links, now correctly preview).

- [ ] **Step 5: Capture the verification block for the PR description**

Save the following snippet for the PR body (it documents the eval-reusable verification):

```bash
# Build-and-scan verification (TRA-534)
DEPLOY_ENV=preview pnpm build

# 1. No prod-host leaks in sitemap or index
grep -E "https?://(docs|app)\.trakrf\.id" build/sitemap.xml || echo "OK: no leaks"
grep -E "https?://(docs|app)\.trakrf\.id" build/index.html || echo "OK: no leaks"

# 2. API Reference page: 11 BB11 links flipped to preview
grep -c "docs.trakrf.id" build/api/index.html       # expect 0
grep -c "docs.preview.trakrf.id" build/api/index.html  # expect ≥ 11

# 3. SSR'd quickstart shows preview app host
grep -c "app.trakrf.id" build/docs/api/quickstart/index.html         # expect 0
grep -c "app.preview.trakrf.id" build/docs/api/quickstart/index.html  # expect ≥ 4
```

- [ ] **Step 6: No commit — verification only.**

---

## Task 5: Document `DEPLOY_ENV` for the build pipeline

**Files:**

- Modify: `.env.example`
- Modify: `README.md`

- [ ] **Step 1: Add `DEPLOY_ENV` to `.env.example`**

Append:

```
# Build target: "production" or "preview". Drives docusaurus url + customFields.
# Auto-detected from CF_PAGES_BRANCH on Cloudflare Pages (main → production).
# Local dev defaults to "preview" so prod URLs are not emitted by accident.
DEPLOY_ENV=preview
```

- [ ] **Step 2: Add a short README note**

In `README.md`, find the build section and add a paragraph:

```markdown
### Build environments

The site builds in one of two modes, controlled by `DEPLOY_ENV`:

- `DEPLOY_ENV=production` — emits `https://docs.trakrf.id` / `https://app.trakrf.id` URLs in SSR, sitemap, canonical tags, and the OpenAPI download link.
- `DEPLOY_ENV=preview` (default) — emits the `*.preview.trakrf.id` equivalents.

On Cloudflare Pages, set `DEPLOY_ENV=production` on the production environment and leave it unset (or `=preview`) on preview environments. Auto-detection from `CF_PAGES_BRANCH` covers the unset case.
```

- [ ] **Step 3: Commit**

```bash
git add .env.example README.md
git commit -m "docs(build): document DEPLOY_ENV var for preview/production builds"
```

---

## Task 6: CF Pages dashboard configuration (manual, out-of-band)

This is not a code change. After the PR merges, in the Cloudflare Pages dashboard:

1. Production environment → Variables → add `DEPLOY_ENV=production`
2. Preview environment → Variables → add `DEPLOY_ENV=preview` (defensive — auto-detect would also work)
3. Trigger a fresh preview build and re-run the verification commands from Task 4 against the deployed URL:

```bash
curl -s https://docs.preview.trakrf.id/api/ | grep -c "docs.trakrf.id"
# expect 0
curl -s https://docs.preview.trakrf.id/docs/api/quickstart/ | grep -c "app.trakrf.id"
# expect 0
```

Document this verification in the Linear ticket once confirmed.

---

## Self-Review Notes

- **Spec coverage:** AC1 (build-time substitution) → Tasks 1+2; AC1 confirms (preview URLs in API quickstart / API Reference / spec download) → Task 4 explicit checks; AC2 (curl+grep verification documented for PR) → Task 4 step 5.
- **Out-of-scope respected:** `servers:` ordering deferred to TRA-517; `/auth/login` doc deferred separately.
- **No placeholders.** Every code block is the actual diff to apply.
- **Type consistency:** `DeployEnv` (config-side) and `DeployEnvLabel` (hook-side) are intentionally distinct names; `customFields.deployEnv` is the bridge string. Both narrow to the same `"production" | "preview"` literal union.
