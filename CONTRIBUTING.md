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

```bash
# Branch naming:
# - feature/add-xyz    (new features)
# - fix/broken-xyz     (bug fixes)
# - docs/update-xyz    (documentation content)

git checkout -b docs/update-getting-started
```

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
