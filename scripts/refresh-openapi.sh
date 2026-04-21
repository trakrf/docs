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
echo "Review the diff and commit if it looks right:"
echo "  git diff -- $OUT_DIR"
