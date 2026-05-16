#!/usr/bin/env bash
# Exercises the `just bb_cycle` recipe: cycle-number selection, refuse-if-exists
# guard, and hidden-file copy. Uses BB_TMP_PREFIX to redirect /tmp/bb-NN into an
# isolated tempdir and BB_SKIP_PREFLIGHT=1 to bypass the external HTTP checks.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pass=0
fail=0

make_prefix() { mktemp -d -t bb-recipe-test.XXXXXX; }

# Pull the "/<prefix>/bb-<N>" path out of the session-start line the recipe prints.
extract_n() {
  local prefix="$1" output="$2"
  echo "$output" | grep -oE "$prefix/bb-[0-9]+" | head -n1 | sed -E "s|.*/bb-||"
}

assert_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name: got '$got', want '$want'"
    fail=$((fail + 1))
  fi
}

assert_true() {
  local name="$1" rc="$2"
  if [ "$rc" -eq 0 ]; then
    echo "ok   $name"
    pass=$((pass + 1))
  else
    echo "FAIL $name (rc=$rc)"
    fail=$((fail + 1))
  fi
}

assert_false() {
  local name="$1" rc="$2"
  if [ "$rc" -ne 0 ]; then
    echo "ok   $name (expected failure, rc=$rc)"
    pass=$((pass + 1))
  else
    echo "FAIL $name: expected non-zero exit"
    fail=$((fail + 1))
  fi
}

# 1. Empty prefix → cycle 1
prefix=$(make_prefix)
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: empty prefix yields 1" "$(extract_n "$prefix" "$out")" "1"
rm -rf "$prefix"

# 2. bb-5 present → cycle 6
prefix=$(make_prefix); mkdir -p "$prefix/bb-5"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: bb-5 yields 6" "$(extract_n "$prefix" "$out")" "6"
rm -rf "$prefix"

# 3. Non-numeric dirs ignored
prefix=$(make_prefix); mkdir -p "$prefix/bb-pw" "$prefix/bb-work"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: non-numeric suffixes ignored" "$(extract_n "$prefix" "$out")" "1"
rm -rf "$prefix"

# 4. Mixed: numeric max wins, non-numeric ignored
prefix=$(make_prefix); mkdir -p "$prefix/bb-3" "$prefix/bb-5" "$prefix/bb-10" "$prefix/bb-pw"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: numeric max wins" "$(extract_n "$prefix" "$out")" "11"
rm -rf "$prefix"

# 5. Explicit arg overrides auto
prefix=$(make_prefix); mkdir -p "$prefix/bb-100"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 7 2>&1)
assert_eq "explicit: arg overrides auto" "$(extract_n "$prefix" "$out")" "7"
rm -rf "$prefix"

# 6. Refuse when target exists
prefix=$(make_prefix); mkdir -p "$prefix/bb-7"
set +e
BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 7 >/dev/null 2>&1
rc=$?
set -e
assert_false "refuse: existing target rejected" "$rc"
rm -rf "$prefix"

# 7. Reject non-numeric arg
prefix=$(make_prefix)
set +e
BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle abc >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: non-numeric arg rejected" "$rc"
rm -rf "$prefix"

# 8. Copy includes hidden files (.envrc)
prefix=$(make_prefix)
BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle >/dev/null 2>&1
[ -f "$prefix/bb-1/.envrc" ] && [ -f "$prefix/bb-1/BB.md" ] && [ -x "$prefix/bb-1/check-deploy-lag.sh" ]
rc=$?
assert_true "copy: hidden files and executable bit preserved" "$rc"
rm -rf "$prefix"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
