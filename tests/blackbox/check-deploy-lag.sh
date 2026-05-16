#!/usr/bin/env bash
# Verify the preview docs deploy has caught up to the published tip.
#
# Why this exists: BB cycles run against the integrator-visible preview
# environment. If `preview` was just pushed but Cloudflare Pages is still
# building the new deploy, BB would exercise the previous deploy and any
# fix shipped in the latest commit would appear absent. This check fails
# fast (with a transient exit code) so the wrapper in justfile can retry
# until the deploy catches up.
#
# Pre-mirror-retirement (TRA-743) this script's predecessor did a three-way
# diff across platform-source, docs-mirror, and app-live spec bodies. With
# the mirror gone the docs origin serves no spec body of its own —
# `/api/openapi.yaml` 302s to the platform. The only docs-side lag question
# that remains is "is the preview docs deploy on the current `preview`
# branch tip?", which is what this script checks. Platform-side
# `spec_refreshed_at` lag is observable independently at
# `$API_TEST_APP_URL/health.json` and is not part of this preflight.
#
# Why query GitHub API for the branch tip (rather than local `git
# rev-parse origin/preview`): the script gets copied into `/tmp/bb-N/`
# alongside the rest of `tests/blackbox/` for the BB session itself, where
# there is no git context. Querying the public GitHub API works regardless
# of caller location, and `trakrf/docs` is a public repo so no auth needed.
#
# Why `preview` not `main`: Cloudflare Pages deploys `docs.preview.trakrf.id`
# from the `preview` branch (force-pushed by .github/workflows/sync-preview.yml
# = main + all open non-draft PRs). `main` is the merge target;
# `docs.trakrf.id` (production) tracks it. For preview lag, the right ref
# is `preview`.
#
# Exit codes:
#   0  preview docs deploy is current
#   2  required env var missing (API_TEST_DOCS_URL)
#   3  could not fetch /health.json or GitHub API
#   4  preview deploy is behind expected commit (transient — retry)

set -euo pipefail

DOCS="${API_TEST_DOCS_URL:-}"
if [ -z "$DOCS" ]; then
  echo "ERROR: API_TEST_DOCS_URL not set (load tests/blackbox/.env.local)" >&2
  exit 2
fi
DOCS="${DOCS%/}"

DOCS_REPO="${TRAKRF_DOCS_REPO:-trakrf/docs}"
DOCS_BRANCH="${TRAKRF_DOCS_BRANCH:-preview}"

fetch() {
  curl -fsSL --max-time 15 "$1"
}

# Branch tip: full SHA from the GitHub public API.
preview_tip="$(fetch "https://api.github.com/repos/${DOCS_REPO}/branches/${DOCS_BRANCH}" 2>/dev/null \
  | jq -r '.commit.sha // empty' 2>/dev/null)" || preview_tip=""

if [ -z "$preview_tip" ]; then
  echo "WARN: could not query GitHub API for ${DOCS_REPO}@${DOCS_BRANCH} tip;" >&2
  echo "      skipping preview-deploy-lag check (rate limit or network)." >&2
  exit 0
fi

# Deployed commit: short SHA from the docs site's own /health.json.
health_json="$(fetch "$DOCS/health.json")" || {
  echo "FAIL: could not fetch $DOCS/health.json" >&2
  exit 3
}

deployed="$(echo "$health_json" | jq -r '.docs.commit // empty')"
if [ -z "$deployed" ]; then
  echo "FAIL: health.json missing .docs.commit field" >&2
  echo "  body: $health_json" >&2
  exit 3
fi

# health.json carries the short (7-char) SHA; GitHub API returns the full
# SHA. Compare as prefix.
case "$preview_tip" in
  "$deployed"*)
    echo "OK: preview docs on ${deployed} (matches ${DOCS_BRANCH}@${preview_tip:0:7})."
    ;;
  *)
    echo "Preview deploy still catching up:" >&2
    echo "  ${DOCS_BRANCH} branch tip:    ${preview_tip}" >&2
    echo "  deployed docs.commit: ${deployed}" >&2
    exit 4
    ;;
esac
