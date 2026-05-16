#!/usr/bin/env bash
# Verify the preview docs deploy has caught up to the published tip.
#
# Why this exists: BB cycles run against the integrator-visible preview
# environment. If `main` was just pushed but Cloudflare Pages is still
# building the new deploy, BB would exercise the previous deploy and any
# fix shipped in the latest commit would appear absent. This check fails
# fast (with a transient exit code) so the wrapper in justfile can retry
# until the deploy catches up.
#
# Pre-mirror-retirement (TRA-743) this script did a three-way diff across
# platform-source, docs-mirror, and app-live spec bodies. With the mirror
# gone the docs origin serves no spec body of its own — `/api/openapi.yaml`
# 302s to the platform. The only docs-side lag question that remains is
# "is the preview docs deploy on the current published commit?", which is
# what this version checks. Platform-side `spec_refreshed_at` lag is
# observable independently at `$API_TEST_APP_URL/health.json` and is not
# part of this preflight.
#
# Exit codes:
#   0  preview docs deploy is current
#   2  required env var missing (API_TEST_DOCS_URL)
#   3  could not fetch /health.json
#   4  preview deploy is behind expected commit (transient — retry)

set -euo pipefail

DOCS="${API_TEST_DOCS_URL:-}"
if [ -z "$DOCS" ]; then
  echo "ERROR: API_TEST_DOCS_URL not set (load tests/blackbox/.env.local)" >&2
  exit 2
fi

# Expected commit: tip of the docs branch that feeds preview. Cloudflare
# Pages publishes `main` to the preview environment, so the expected SHA
# is the remote `origin/main` HEAD.
git fetch --quiet origin main 2>/dev/null || true
expected="$(git rev-parse --short=7 origin/main 2>/dev/null || echo "")"
if [ -z "$expected" ]; then
  echo "ERROR: could not resolve origin/main commit. Is this a checkout of trakrf/docs?" >&2
  exit 2
fi

health_json="$(curl -fsS "$DOCS/health.json" 2>/dev/null)" || {
  echo "FAIL: could not fetch $DOCS/health.json" >&2
  exit 3
}

deployed="$(echo "$health_json" | jq -r '.docs.commit // empty')"
if [ -z "$deployed" ]; then
  echo "FAIL: health.json missing .docs.commit field" >&2
  echo "  body: $health_json" >&2
  exit 3
fi

if [ "$deployed" != "$expected" ]; then
  echo "Preview docs on $deployed; origin/main is $expected. Deploy still catching up." >&2
  exit 4
fi

echo "OK: preview docs on $deployed (matches origin/main)."
