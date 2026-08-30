# Contributing to TrakRF Docs

We love contributions! This guide will help you get started quickly.

## What is this project?

TrakRF Docs is the documentation site for the TrakRF platform, built with [Docusaurus](https://docusaurus.io/). It covers product documentation, API references, guides, and tutorials.

## Before You Start

### Required Tools

- **Node.js 22+** - See `.nvmrc`
- **pnpm** - Package manager (never use npm or yarn)
- **Git** - For version control

### Quick Setup

```bash
# 1. Fork this repo on GitHub

# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/docs.git
cd docs

# 3. Install dependencies
pnpm install

# 4. Start dev server
pnpm dev
```

## Making Changes

### 1. Create a Branch

Branch as `<type>/<slug>`, using a [conventional commit](https://www.conventionalcommits.org)
type — `feat`, `fix`, `docs`, `chore`, `style`, `refactor`, `test`.

```bash
git checkout -b docs/update-getting-started
```

Maintainers working from a tracked issue insert the ticket:
`<type>/<ticket>-<slug>`, e.g. `docs/tra-0000-update-getting-started`. Outside
contributors have no ticket and should use the plain `<type>/<slug>` form.

### 2. Write Your Content

- Documentation lives in `docs/` as Markdown or MDX files
- Use clear, concise language
- Include code examples where helpful
- Add images to `static/img/` and reference them with relative paths

### 3. Verify Your Changes

```bash
# Check the dev server
pnpm dev

# Build to catch any errors
pnpm build
```

### 4. Commit Your Work

```bash
# Use conventional commits
git commit -m "docs: update getting started guide"
git commit -m "feat: add API reference section"
git commit -m "fix: correct broken link in sidebar"
```

## Which Changelog Receives What

TrakRF keeps three separate changelogs for three different audiences. They are not filtered views of each other — putting an entry in the wrong one either buries it or leaks internals to customers. Before writing an entry, pick the audience first:

| Changelog                           | Audience                               | Contains                                                                                                                                              |
| ----------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CHANGELOG.md` in the platform repo | TrakRF engineers                       | Everything: migrations, schema moves, internal refactors, ticket numbers, upgrade steps for operators                                                 |
| `docs/api/changelog.md` (this repo) | Integrators writing against `/api/v1/` | Changes to the public API contract only — request/response shapes, error codes, auth, spec emission. Tracks the API version, not the platform version |
| `docs/release-notes.md` (this repo) | Customers using the app                | What a user can see or do differently. Tracks the platform version                                                                                    |

Rules for the customer-facing release notes:

- **Translate, never copy.** The platform changelog is the source of facts, not the source of prose. Migration numbers, schema detail, and capability-gating mechanics do not belong on a customer page.
- **No internal identifiers.** No ticket numbers, migration numbers, PR links, or table names.
- **Current user vocabulary.** Use the words the app uses today — "Scan", not "Inventory".
- **Not one entry per git tag.** Most releases change nothing a user would notice; saying nothing is the correct output for those. Group by what a user would actually notice.
- **Write so each entry stands alone.** Release announcements are mailed out and many readers only ever see the email, so avoid "as described above" and anything that depends on site navigation.
- **Give every entry a stable anchor** (`{#v1-3-0-scan}`) so an announcement can deep-link to it. Prefix the anchor with the release so it stays unique as releases accumulate.
- **Publish on release, never on merge.** The page must never describe something that is not yet running in production.
- **The page is canonical; the email is a copy.** Never let the email carry content the page lacks.

## Submitting Your Work

1. **Push to your fork:**

   ```bash
   git push origin docs/update-getting-started
   ```

2. **Open a Pull Request:**
   - Go to https://github.com/trakrf/docs
   - Click "New Pull Request"
   - Select your branch
   - Describe what you changed and why

3. **PR Checklist:**
   - [ ] `pnpm build` passes
   - [ ] Content is accurate and well-written
   - [ ] Links are not broken
   - [ ] Commit messages use conventional format

4. **How PRs are merged:**

   PRs are merged with `--merge`, never squashed and never rebased, so that
   individual commit history is preserved.

## Getting Help

- **Questions?** Open a GitHub Discussion
- **Found a bug?** Open an issue with steps to reproduce
- **Have an idea?** Open a discussion before making major changes

## Code of Conduct

Be professional, respectful, and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details.

## Legal

By submitting a pull request, you agree that:

1. You have the right to submit the contribution
2. You grant DevOps To AI LLC dba TrakRF a perpetual, worldwide, non-exclusive,
   no-charge, royalty-free, irrevocable license to use your
   contribution under any terms, including commercial licensing
3. Your contribution will be licensed under MIT for public use
