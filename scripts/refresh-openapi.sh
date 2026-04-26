#!/usr/bin/env bash
# Refresh static/api/openapi.{json,yaml} from the live platform spec.
# Run whenever the platform ships endpoint changes so the docs site's
# interactive reference at /api stays in sync.
#
# Source of truth: https://app.preview.trakrf.id/api/v1/openapi.{json,yaml}
# (Preview always tracks the latest platform build. Production is a subset
# of preview by the time this lands, so preview is the right source.)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SPEC_HOST="${TRAKRF_SPEC_HOST:-https://app.preview.trakrf.id}"
OUT_DIR="static/api"

echo "Fetching OpenAPI spec from $SPEC_HOST..."

curl -fsSL "$SPEC_HOST/api/v1/openapi.json" -o "$OUT_DIR/openapi.json"
curl -fsSL "$SPEC_HOST/api/v1/openapi.yaml" -o "$OUT_DIR/openapi.yaml"

echo "Wrote:"
wc -l "$OUT_DIR/openapi.json" "$OUT_DIR/openapi.yaml"

echo
echo "Paths in fetched spec:"
if command -v jq >/dev/null 2>&1; then
  jq -r '.paths | keys[]' "$OUT_DIR/openapi.json"
else
  echo "  (install jq for path summary)"
fi

echo
echo "Snapshotting platform build metadata from $SPEC_HOST/health..."
# Best-effort: do not abort the spec refresh on /health failure.
# The spec is the load-bearing artifact; the snapshot is a nice-to-have.
# Existing platform-meta.json is left intact on any failure path.
if health_json=$(curl -fsSL "$SPEC_HOST/health" 2>/dev/null); then
  # `// ""` defaults null/missing fields to empty string so we never
  # write the literal string "null" into platform-meta.json.
  if commit=$(echo "$health_json" | jq -re '.commit // ""') \
     && build_time=$(echo "$health_json" | jq -re '.build_time // ""') \
     && [ -n "$commit" ] && [ -n "$build_time" ]; then
    tag=$(echo "$health_json" | jq -r '.tag // ""')
    spec_refreshed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    jq -n \
      --arg commit "$commit" \
      --arg tag "$tag" \
      --arg build_time "$build_time" \
      --arg spec_refreshed_at "$spec_refreshed_at" \
      '{commit: $commit, tag: $tag, build_time: $build_time, spec_refreshed_at: $spec_refreshed_at}' \
      > "$OUT_DIR/platform-meta.json"
    echo "Wrote $OUT_DIR/platform-meta.json (platform@$commit)"
  else
    echo "WARN: /health returned malformed or empty JSON, leaving existing platform-meta.json intact" >&2
  fi
else
  echo "WARN: /health unreachable, leaving existing platform-meta.json intact" >&2
fi

echo
echo "Review the diff and commit if it looks right:"
echo "  git diff -- $OUT_DIR"
