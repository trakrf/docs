#!/usr/bin/env bash
# BB pre-flight: verify the OpenAPI spec is coherent across platform, docs
# mirror, and live API. Run this BEFORE starting the OpenAPI spec contract
# check in BB.md. A FAIL here means BB tests will produce false findings
# rooted in mirror lag, not real spec/service disagreement.
#
# Inputs (env, from .envrc / direnv):
#   API_TEST_APP_URL   — app + API host (e.g. https://app.preview.trakrf.id)
#   API_TEST_DOCS_URL  — docs site host (e.g. https://docs.preview.trakrf.id)
#
# Checks:
#   1. docs/api/platform-meta.json declares a platform commit
#   2. docs/api/openapi.yaml is byte-equivalent to that commit's
#      trakrf/platform:docs/api/openapi.public.yaml
#   3. app/api/openapi.yaml (live, served by the deployed binary) is
#      byte-equivalent to the same platform-repo file
#
# Exit codes:
#   0 — all three checks pass; BB testing is safe to proceed
#   1 — environment / connectivity failure (missing env, bad JSON, host
#       unreachable, github raw lookup failed)
#   2 — docs mirror diverged from its declared commit (refresh-openapi.sh
#       bug; the docs mirror is internally inconsistent)
#   3 — platform deployed code is newer than the docs mirror (the typical
#       race: re-run scripts/refresh-openapi.sh on docs and open a PR
#       before continuing BB)

set -euo pipefail

: "${API_TEST_APP_URL:?API_TEST_APP_URL is required (direnv/.envrc)}"
: "${API_TEST_DOCS_URL:?API_TEST_DOCS_URL is required (direnv/.envrc)}"

APP="${API_TEST_APP_URL%/}"
DOCS="${API_TEST_DOCS_URL%/}"
PLATFORM_REPO="${TRAKRF_PLATFORM_REPO:-trakrf/platform}"

fetch() {
  curl -fsSL --max-time 15 "$1"
}

sha() {
  fetch "$1" | sha256sum | awk '{print $1}'
}

echo "BB spec-sync pre-flight"
echo "  app:  $APP"
echo "  docs: $DOCS"
echo

meta_json=$(fetch "$DOCS/api/platform-meta.json") || {
  echo "FAIL: could not fetch $DOCS/api/platform-meta.json" >&2
  exit 1
}

docs_commit=$(echo "$meta_json" | jq -r '.commit // empty')
docs_refreshed_at=$(echo "$meta_json" | jq -r '.spec_refreshed_at // empty')
docs_source_url=$(echo "$meta_json" | jq -r '.source_url // empty')

if [ -z "$docs_commit" ]; then
  echo "FAIL: platform-meta.json missing .commit field" >&2
  echo "  body: $meta_json" >&2
  exit 1
fi

echo "Docs mirror declares: platform@${docs_commit}"
echo "  refreshed at:   ${docs_refreshed_at}"
echo "  source commit:  ${docs_source_url}"
echo

platform_url="https://raw.githubusercontent.com/${PLATFORM_REPO}/${docs_commit}/docs/api/openapi.public.yaml"

platform_sha=$(sha "$platform_url") || {
  echo "FAIL: could not fetch platform spec at ${platform_url}" >&2
  echo "  (commit may not exist on the platform repo, or may be a force-pushed branch)" >&2
  exit 1
}

docs_sha=$(sha "$DOCS/api/openapi.yaml") || {
  echo "FAIL: could not fetch $DOCS/api/openapi.yaml" >&2
  exit 1
}

app_sha=$(sha "$APP/api/openapi.yaml") || {
  echo "FAIL: could not fetch $APP/api/openapi.yaml" >&2
  exit 1
}

echo "sha256 platform@${docs_commit}: ${platform_sha}"
echo "sha256 docs mirror:            ${docs_sha}"
echo "sha256 app live:               ${app_sha}"
echo

if [ "$docs_sha" != "$platform_sha" ]; then
  echo "FAIL: docs mirror does NOT match its declared platform commit." >&2
  echo "  refresh-openapi.sh is supposed to copy openapi.public.yaml" >&2
  echo "  verbatim from platform@${docs_commit}, but the served file diverges." >&2
  echo "  Investigate scripts/refresh-openapi.sh and the last sync commit." >&2
  exit 2
fi

if [ "$app_sha" != "$platform_sha" ]; then
  echo "FAIL: app live spec does NOT match the docs mirror." >&2
  echo "  Platform has been deployed with a newer (or older) binary than the" >&2
  echo "  spec the docs mirror declares. The typical case is that the docs" >&2
  echo "  mirror is stale: BB will produce false findings against the spec" >&2
  echo "  the docs site serves vs the behavior of the deployed service." >&2
  echo >&2
  echo "  Resolve by running scripts/refresh-openapi.sh in trakrf-docs and" >&2
  echo "  merging the refresh PR before continuing BB. If the docs mirror is" >&2
  echo "  intentionally ahead of platform (rare — e.g., docs-only patch in" >&2
  echo "  flight), confirm with the docs maintainer before proceeding." >&2
  exit 3
fi

echo "OK: docs mirror, app live spec, and platform@${docs_commit} all byte-match."
echo "    BB spec-contract testing can proceed against this state."
