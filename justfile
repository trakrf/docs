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
    @bash scripts/test_bb_cycle.sh

# Picks the next cycle number (or accepts an explicit one), runs the
# deploy-lag preflight against the preview docs site, then copies
# tests/blackbox/ out to /tmp/bb-NN for isolated execution. Prints a
# copy-paste command to start the session.
#
# Why copy out: the BB cycle is meant to mimic an external integrator's
# experience using only published artifacts. Working out of /tmp keeps
# in-flight dev context in the working tree from leaking into the test
# environment.
#
# Usage:
#   just bb_cycle              # mint track, auto-num
#   just bb_cycle 32           # mint track, explicit cycle number
#   just bb_cycle BB1          # pre-key track for BB1 org, auto-num
#   just bb_cycle BB1 32       # pre-key track for BB1, cycle 32
#   just bb_cycle 32 BB1       # same as above (order-agnostic)
#
# Environment overrides (mostly for tests):
#   BB_SOURCE_ENV        host .env.local to source (default: tests/blackbox/.env.local)
#   BB_SKIP_PREFLIGHT=1  skip the preflight loop (manual testing only)
#   BB_TMP_PREFIX        directory holding bb-NN dirs (default: /tmp)
#   BB_NO_LAUNCH=1       skip the final exec claude (recipe tests only)
#
# Start a fresh blackbox test cycle: preflight, isolate to /tmp/bb-NN, then print the session-start command
bb_cycle arg1="" arg2="":
    #!/usr/bin/env bash
    set -euo pipefail

    prefix="${BB_TMP_PREFIX:-/tmp}"

    # Source the host .env.local (or BB_SOURCE_ENV override for tests).
    # Required for both preflight and the filtered .env.local write step.
    source_env="${BB_SOURCE_ENV:-tests/blackbox/.env.local}"
    if [ -f "$source_env" ]; then
      set -a
      # shellcheck disable=SC1091
      . "$source_env"
      set +a
    fi

    # 1. Sniff args into (selector, n). Each arg may be a selector (BB1/BB2/BB3),
    #    a positive integer (cycle number), or empty. Order-agnostic.
    selector=""
    n=""
    for a in "{{arg1}}" "{{arg2}}"; do
      [ -z "$a" ] && continue
      if [[ "$a" =~ ^BB[1-3]$ ]]; then
        if [ -n "$selector" ]; then
          echo "ERROR: two selectors provided ($selector, $a)" >&2
          exit 1
        fi
        selector="$a"
      elif [[ "$a" =~ ^[0-9]+$ ]]; then
        if [ -n "$n" ]; then
          echo "ERROR: two cycle numbers provided ($n, $a)" >&2
          exit 1
        fi
        n="$a"
      else
        echo "ERROR: unrecognized arg: '$a' (expected BB[1-3] or a positive integer)" >&2
        exit 1
      fi
    done

    # 2. Determine cycle number. If not explicit, scan existing bb-NN[-BBn] dirs
    #    and pick the smallest NN where our specific target doesn't yet exist.
    if [ -z "$n" ]; then
      max=0
      shopt -s nullglob
      for d in "$prefix"/bb-[0-9]*; do
        [ -d "$d" ] || continue
        suffix="${d##*/bb-}"
        if [[ "$suffix" =~ ^([0-9]+)(-BB[1-3])?$ ]]; then
          num="${BASH_REMATCH[1]}"
          if (( num > max )); then
            max=$num
          fi
        fi
      done
      shopt -u nullglob
      candidate=$(( max == 0 ? 1 : max ))
      while :; do
        target_check="$prefix/bb-$candidate"
        [ -n "$selector" ] && target_check="$target_check-$selector"
        [ ! -e "$target_check" ] && break
        candidate=$(( candidate + 1 ))
      done
      n=$candidate
    fi

    # 3. Build target path. Pre-key dirs carry the selector as a suffix.
    target="$prefix/bb-$n"
    [ -n "$selector" ] && target="$target-$selector"

    # 4. Validate source env vars for the chosen track. Doing this before
    #    mkdir means a missing var aborts cleanly without leaving an
    #    orphan target dir that would block a retry.
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

    # 5. Refuse if target exists — prevents clobbering an in-flight cycle
    if [ -e "$target" ]; then
      echo "ERROR: $target already exists. Pick another cycle number or remove it." >&2
      exit 1
    fi

    # 6. Preflight: confirm the preview docs deploy has caught up to
    #    origin/main. Cloudflare Pages builds typically take a couple of
    #    minutes; if we run BB before the new deploy lands the cycle will
    #    test the previous commit.
    if [ "${BB_SKIP_PREFLIGHT:-}" != "1" ]; then
      echo "==> BB cycle $n — running deploy-lag preflight"
      echo

      deadline=$(( $(date +%s) + 300 ))   # ~5 min
      interval=20
      while :; do
        if bash tests/blackbox/check-deploy-lag.sh; then
          break
        fi
        rc=$?
        # Only retry on exit 4 (preview deploy lag — Cloudflare Pages
        # still catching up to the published tip). Other failures (env,
        # unreachable origin) are not transient.
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

    # 7. Isolate: copy tests/blackbox/ into the target, then replace the
    #    copied .env.local with a track-specific filtered file. Each session
    #    sees exactly the env an external integrator would.
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

    # 8. Launch the session directly. The wrapper file matches the chosen
    #    track; the wrapper itself points back at BB.md for the shared
    #    methodology. Claude's own "trust this directory?" prompt is the
    #    backstop if you want to bail before the session starts.
    if [ -n "$selector" ]; then
      wrapper="BB_PRE_KEY.md"
    else
      wrapper="BB_MINT_KEY.md"
    fi
    echo
    echo "==> Launching BB cycle $n in $target (wrapper: $wrapper)"
    direnv allow "$target"
    cd "$target"
    if [ "${BB_NO_LAUNCH:-}" = "1" ]; then
      exit 0
    fi
    exec claude --dangerously-skip-permissions "run blackbox tests per $wrapper"
