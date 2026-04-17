#!/usr/bin/env bash
# Refresh all app-tour screenshots by driving Rodney against the preview app.
# Prose in docs/app-tour/*.md is untouched. See docs/app-tour/AUTHORING.md for the full workflow.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in credentials (or run the authoring pass first)." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

: "${TRAKRF_PREVIEW_URL:?TRAKRF_PREVIEW_URL missing from .env}"
: "${TRAKRF_DOCS_USER_EMAIL:?TRAKRF_DOCS_USER_EMAIL missing from .env}"
: "${TRAKRF_DOCS_USER_PASSWORD:?TRAKRF_DOCS_USER_PASSWORD missing from .env}"

TABS=(home inventory locate barcode assets locations reports settings help)
OUT_DIR="static/img/app-tour"
mkdir -p "$OUT_DIR"

cleanup() {
  uvx rodney stop >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo ">> starting rodney (headless)"
uvx rodney start

echo ">> logging in"
uvx rodney open "$TRAKRF_PREVIEW_URL"
uvx rodney waitload
uvx rodney wait "input[type=email], input[name=email]"
uvx rodney input "input[type=email], input[name=email]" "$TRAKRF_DOCS_USER_EMAIL"
uvx rodney input "input[type=password], input[name=password]" "$TRAKRF_DOCS_USER_PASSWORD"
uvx rodney click "button[type=submit]"
uvx rodney wait "nav, [data-testid=menu-item-home]"

for tab in "${TABS[@]}"; do
  echo ">> capturing $tab"
  uvx rodney open "${TRAKRF_PREVIEW_URL}/#${tab}"
  uvx rodney waitstable
  uvx rodney screenshot -w 1440 -h 900 "${OUT_DIR}/${tab}-desktop.png"
  uvx rodney screenshot -w 390 -h 844 "${OUT_DIR}/${tab}-mobile.png"
done

echo ">> done. 18 screenshots refreshed in ${OUT_DIR}/"
