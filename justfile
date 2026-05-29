# trakrf-docs justfile
#
# Common discoverable operations. Recipes use bash shebangs so they run as a
# single script (not line-by-line), and `set -euo pipefail` is on by default
# in each.

# Show available recipes
default:
    @just --list

# Run justfile recipe tests
test:
    @bash scripts/test_bb.sh

# Picks the cycle.round[.session] target directly, runs the deploy-lag
# preflight against the preview docs site, then copies tests/blackbox/
# out to /tmp/bb-{cycle.round[.session]} for isolated execution and
# launches Claude with the wrapper that matches the chosen track.
#
# Naming scheme (cycle.round.session): see tests/blackbox/BB.md
# - cycle: era/phase (cycle 2 = post-TRA-564 closure)
# - round: batch of parallel sessions within a cycle
# - session: parallel org index in {1,2,3}, pre-key only (mint has no session)
#
# Session N maps to fixture org BB{N}: session 1 = BB1, session 2 = BB2,
# session 3 = BB3. The BB{n} name stays in env var names (BB1_CLIENT_ID
# etc) and methodology — those are the fixtures' durable identifiers.
#
# Usage:
#   just bb 2.3        # mint track, cycle 2 round 3
#   just bb 2.3.1      # pre-key BB1 fixture (session 1), cycle 2 round 3
#   just bb 2.3.2      # pre-key BB2 fixture (session 2), cycle 2 round 3
#   just bb 2.3.3      # pre-key BB3 fixture (session 3), cycle 2 round 3
#
# Environment overrides (mostly for tests):
#   BB_SOURCE_ENV        host .env.local to source (default: tests/blackbox/.env.local)
#   BB_SKIP_PREFLIGHT=1  skip the preflight loop (manual testing only)
#   BB_TMP_PREFIX        directory holding bb-* dirs (default: /tmp)
#   BB_NO_LAUNCH=1       skip the final exec claude (recipe tests only)
#
# Start a fresh blackbox test cycle: validate, preflight, isolate, launch
bb cr:
    #!/usr/bin/env bash
    set -euo pipefail

    prefix="${BB_TMP_PREFIX:-/tmp}"

    source_env="${BB_SOURCE_ENV:-tests/blackbox/.env.local}"
    if [ -f "$source_env" ]; then
      set -a
      # shellcheck disable=SC1091
      . "$source_env"
      set +a
    fi

    # 1. Parse cycle.round[.session]. Segment count determines track.
    cr="{{cr}}"
    if [[ "$cr" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
      cycle="${BASH_REMATCH[1]}"
      round="${BASH_REMATCH[2]}"
      session=""
      selector=""
    elif [[ "$cr" =~ ^([0-9]+)\.([0-9]+)\.([1-3])$ ]]; then
      cycle="${BASH_REMATCH[1]}"
      round="${BASH_REMATCH[2]}"
      session="${BASH_REMATCH[3]}"
      selector="BB${session}"
    else
      echo "ERROR: expected cycle.round (mint) or cycle.round.session with session in {1,2,3} (pre-key), got: $cr" >&2
      echo "       Examples:  just bb 2.3   |   just bb 2.3.1" >&2
      exit 1
    fi

    target="$prefix/bb-${cr}"

    # 2. Validate source env vars for the chosen track. Doing this
    #    before mkdir means a missing var aborts cleanly without
    #    leaving an orphan target dir.
    if [ -n "$selector" ]; then
      src_client_id_var="${selector}_CLIENT_ID"
      src_client_secret_var="${selector}_CLIENT_SECRET"
      src_id_var="${selector}_ORG_ID"
      src_client_id="${!src_client_id_var:-}"
      src_client_secret="${!src_client_secret_var:-}"
      src_id="${!src_id_var:-}"
      if [ -z "$src_client_id" ]; then
        echo "ERROR: $src_client_id_var is empty or unset in $source_env" >&2
        exit 1
      fi
      if [ -z "$src_client_secret" ]; then
        echo "ERROR: $src_client_secret_var is empty or unset in $source_env" >&2
        exit 1
      fi
      if [ -z "$src_id" ]; then
        echo "ERROR: $src_id_var is empty or unset in $source_env" >&2
        exit 1
      fi
    else
      if [ -z "${API_TEST_LOGIN:-}" ]; then
        echo "ERROR: API_TEST_LOGIN is empty or unset in $source_env" >&2
        exit 1
      fi
      if [ -z "${API_TEST_PASS:-}" ]; then
        echo "ERROR: API_TEST_PASS is empty or unset in $source_env" >&2
        exit 1
      fi
    fi

    # 3. Refuse if target exists
    if [ -e "$target" ]; then
      echo "ERROR: $target already exists. Pick another cycle.round[.session] or remove it." >&2
      exit 1
    fi

    # 4. Preflight
    if [ "${BB_SKIP_PREFLIGHT:-}" != "1" ]; then
      echo "==> BB ${cr} — running deploy-lag preflight"
      echo

      deadline=$(( $(date +%s) + 300 ))
      interval=20
      while :; do
        if bash tests/blackbox/check-deploy-lag.sh; then
          break
        fi
        rc=$?
        if [ "$rc" -ne 4 ]; then
          echo "ERROR: preflight failed with exit code $rc (non-transient). Resolve and retry." >&2
          exit "$rc"
        fi
        now=$(date +%s)
        if [ "$now" -ge "$deadline" ]; then
          echo "ERROR: preflight still failing after 5 min timeout. Investigate Cloudflare Pages deploy queue before retrying." >&2
          exit 1
        fi
        echo "Preview deploy still catching up; retrying in ${interval}s…" >&2
        sleep "$interval"
      done

      echo
    fi

    # 5. Isolate + write filtered .env.local
    echo "==> Isolating to $target"
    mkdir -p "$target"
    cp -r tests/blackbox/. "$target/"
    rm -f "$target/.env.local"

    {
      echo "API_TEST_APP_URL=${API_TEST_APP_URL:-}"
      echo "API_TEST_DOCS_URL=${API_TEST_DOCS_URL:-}"
      if [ -n "$selector" ]; then
        echo "BB_ORG=$selector"
        echo "BB_CLIENT_ID=$src_client_id"
        echo "BB_CLIENT_SECRET=$src_client_secret"
        echo "BB_ORG_ID=$src_id"
      else
        echo "API_TEST_LOGIN=$API_TEST_LOGIN"
        echo "API_TEST_PASS=$API_TEST_PASS"
      fi
    } > "$target/.env.local"

    # 6. Launch
    if [ -n "$selector" ]; then
      wrapper="BB_PRE_KEY.md"
    else
      wrapper="BB_MINT_KEY.md"
    fi
    echo
    echo "==> Launching BB ${cr} in $target (wrapper: $wrapper)"
    direnv allow "$target"
    cd "$target"
    if [ "${BB_NO_LAUNCH:-}" = "1" ]; then
      exit 0
    fi
    exec claude --dangerously-skip-permissions "run blackbox tests per $wrapper"
