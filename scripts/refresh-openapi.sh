#!/usr/bin/env bash
# Refresh static/api/openapi.{json,yaml} and the Postman collection from
# the customer-facing filtered spec committed in trakrf/platform.
#
# This is the SOLE writer of static/api/openapi.* and the Postman collection.
# A previous push-flow (platform's publish-api-docs.yml) was retired in
# TRA-445 — see spec/superpowers/specs/2026-04-26-tra-445-pull-only-spec-sync-design.md.
#
# Source of truth: trakrf/platform repo, file docs/api/openapi.public.{json,yaml}
# at $TRAKRF_PLATFORM_REF (default: main). Set TRAKRF_PLATFORM_REF to a branch,
# tag, or commit SHA to pull from a different point.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PLATFORM_REPO="${TRAKRF_PLATFORM_REPO:-trakrf/platform}"
PLATFORM_REF="${TRAKRF_PLATFORM_REF:-main}"
SPEC_BASE="https://raw.githubusercontent.com/${PLATFORM_REPO}/${PLATFORM_REF}/docs/api"
OUT_DIR="static/api"

echo "Fetching OpenAPI spec from ${PLATFORM_REPO}@${PLATFORM_REF}..."

curl -fsSL "${SPEC_BASE}/openapi.public.json" -o "${OUT_DIR}/openapi.json"
curl -fsSL "${SPEC_BASE}/openapi.public.yaml" -o "${OUT_DIR}/openapi.yaml"

echo "Wrote:"
wc -l "${OUT_DIR}/openapi.json" "${OUT_DIR}/openapi.yaml"

echo
echo "Paths in fetched spec:"
if command -v jq >/dev/null 2>&1; then
  jq -r '.paths | keys[]' "${OUT_DIR}/openapi.json"
else
  echo "  (install jq for path summary)"
fi

echo
echo "Regenerating Postman collection..."
pnpm dlx openapi-to-postmanv2 \
  -s "${OUT_DIR}/openapi.json" \
  -o "${OUT_DIR}/trakrf-api.postman_collection.json" \
  -p -O folderStrategy=Paths

echo
echo "Resolving ${PLATFORM_REF} to a commit SHA via git ls-remote..."
# git ls-remote prints "<sha>\t<ref>" lines and exits 0 with empty output for
# an unknown ref. If empty, treat $PLATFORM_REF as itself a SHA and use it.
RESOLVED=$(git ls-remote "https://github.com/${PLATFORM_REPO}.git" "${PLATFORM_REF}" | awk '{print $1}' | head -n1)
if [ -z "${RESOLVED}" ]; then
  RESOLVED="${PLATFORM_REF}"
fi
SHORT_SHA="${RESOLVED:0:7}"

spec_refreshed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n \
  --arg commit "${SHORT_SHA}" \
  --arg source_url "https://github.com/${PLATFORM_REPO}/commit/${RESOLVED}" \
  --arg spec_refreshed_at "${spec_refreshed_at}" \
  '{commit: $commit, source_url: $source_url, spec_refreshed_at: $spec_refreshed_at}' \
  > "${OUT_DIR}/platform-meta.json"

echo "Wrote ${OUT_DIR}/platform-meta.json (${PLATFORM_REPO}@${SHORT_SHA})"

echo
echo "Review the diff and commit if it looks right:"
echo "  git diff -- ${OUT_DIR}"
