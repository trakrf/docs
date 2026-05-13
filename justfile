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
# spec-sync preflight against the live preview deploys, then copies
# tests/blackbox/ out to /tmp/bb-NN for isolated execution. Prints a
# copy-paste command to start the session.
#
# Why copy out: the BB cycle is meant to mimic an external integrator's
# experience using only published artifacts. Working out of /tmp keeps
# in-flight dev context in the working tree from leaking into the test
# environment.
#
# Usage:
#   just bb_cycle        # auto-increment from existing /tmp/bb-NN dirs
#   just bb_cycle 32     # explicit cycle number
#
# Environment overrides (mostly for tests):
#   BB_TMP_PREFIX        directory holding bb-NN dirs (default: /tmp)
#   BB_SKIP_PREFLIGHT=1  skip the preflight loop (manual testing only)
#
# Start a fresh blackbox test cycle: preflight, isolate to /tmp/bb-NN, then print the session-start command
bb_cycle num="":
    #!/usr/bin/env bash
    set -euo pipefail

    prefix="${BB_TMP_PREFIX:-/tmp}"

    # 1. Determine cycle number
    if [ -n "{{num}}" ]; then
      n="{{num}}"
      if ! [[ "$n" =~ ^[0-9]+$ ]]; then
        echo "ERROR: cycle number must be a positive integer, got: $n" >&2
        exit 1
      fi
    else
      max=0
      shopt -s nullglob
      for d in "$prefix"/bb-[0-9]*; do
        [ -d "$d" ] || continue
        suffix="${d##*/bb-}"
        if [[ "$suffix" =~ ^[0-9]+$ ]] && (( suffix > max )); then
          max=$suffix
        fi
      done
      shopt -u nullglob
      n=$(( max + 1 ))
    fi

    target="$prefix/bb-$n"

    # 2. Refuse if target exists — prevents clobbering an in-flight cycle
    if [ -e "$target" ]; then
      echo "ERROR: $target already exists. Pick another cycle number or remove it." >&2
      exit 1
    fi

    # 3. Preflight against the preview environment.
    #    Runs from the working tree (not the isolation dir) so it can fail
    #    fast before any filesystem state is created.
    if [ "${BB_SKIP_PREFLIGHT:-}" != "1" ]; then
      echo "==> BB cycle $n — running spec-sync preflight"
      echo

      # Load API_TEST_* from tests/blackbox/.env.local. Required by the
      # preflight script. .env.local is gitignored and holds the preview
      # URLs and test credentials.
      if [ -f tests/blackbox/.env.local ]; then
        set -a
        # shellcheck disable=SC1091
        . tests/blackbox/.env.local
        set +a
      fi

      deadline=$(( $(date +%s) + 300 ))   # ~5 min
      interval=20
      while :; do
        if bash tests/blackbox/check-spec-sync.sh; then
          break
        fi
        rc=$?
        # Only retry on exit 4 (preview deploy lag — Cloudflare Pages
        # still catching up to the preview branch tip). Other failures
        # (env, mirror divergence, real spec drift) are not transient.
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

    # 4. Isolate: copy tests/blackbox/ (including hidden .envrc + .env.local)
    #    into the target dir. trailing /. makes cp include dotfiles.
    echo "==> Isolating to $target"
    mkdir -p "$target"
    cp -r tests/blackbox/. "$target/"

    # 5. Session-start command for copy-paste
    echo
    echo "==> Ready. Start the session with:"
    echo
    echo "    cd $target && direnv allow && csp 'run blackbox tests per BB.md'"
    echo
