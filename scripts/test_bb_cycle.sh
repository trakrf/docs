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

# --- TRA-762: selector arg, suffixed target, auto-num across suffixes ---

# T9. Selector-only: bb_cycle BB2 (no num) → bb-1-BB2/
prefix=$(make_prefix)
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
[ -d "$prefix/bb-1-BB2" ]
assert_true "selector: BB2 alone yields bb-1-BB2" "$?"
rm -rf "$prefix"

# T10. Selector + num (num first): bb_cycle 33 BB1 → bb-33-BB1/
prefix=$(make_prefix)
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 33 BB1 2>&1)
[ -d "$prefix/bb-33-BB1" ]
assert_true "selector+num: '33 BB1' yields bb-33-BB1" "$?"
rm -rf "$prefix"

# T11. Selector + num (selector first): bb_cycle BB1 33 → bb-33-BB1/ (order-agnostic)
prefix=$(make_prefix)
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 33 2>&1)
[ -d "$prefix/bb-33-BB1" ]
assert_true "selector+num: 'BB1 33' yields bb-33-BB1 (order-agnostic)" "$?"
rm -rf "$prefix"

# T12. Auto-num same-cycle reuse: bb-3-BB1 exists → bb_cycle BB2 picks 3
prefix=$(make_prefix); mkdir -p "$prefix/bb-3-BB1"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
[ -d "$prefix/bb-3-BB2" ]
assert_true "auto: bb-3-BB1 present, BB2 picks 3 (not 4)" "$?"
rm -rf "$prefix"

# T13. Auto-num across-track: bb-3 (mint) + bb-3-BB1 exist → bb_cycle BB2 picks 3
prefix=$(make_prefix); mkdir -p "$prefix/bb-3" "$prefix/bb-3-BB1"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
[ -d "$prefix/bb-3-BB2" ]
assert_true "auto: bb-3 + bb-3-BB1 present, BB2 picks 3" "$?"
rm -rf "$prefix"

# T14. Auto-num increment when target exists: full cycle 3 → bb_cycle BB1 picks 4
prefix=$(make_prefix); mkdir -p "$prefix/bb-3" "$prefix/bb-3-BB1" "$prefix/bb-3-BB2" "$prefix/bb-3-BB3"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 2>&1)
[ -d "$prefix/bb-4-BB1" ]
assert_true "auto: cycle 3 full, BB1 increments to 4" "$?"
rm -rf "$prefix"

# T15. Mint auto-num still works when only pre-key dirs exist
prefix=$(make_prefix); mkdir -p "$prefix/bb-3-BB1"
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
[ -d "$prefix/bb-3" ]
assert_true "auto (mint): only bb-3-BB1 present, mint picks bb-3" "$?"
rm -rf "$prefix"

# T16. Invalid selectors rejected
for bad in BB4 BB bb1 foo; do
  prefix=$(make_prefix)
  set +e
  BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle "$bad" >/dev/null 2>&1
  rc=$?
  set -e
  assert_false "validate: '$bad' rejected" "$rc"
  rm -rf "$prefix"
done

# T17. Two selectors rejected
prefix=$(make_prefix)
set +e
BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 BB2 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: two selectors rejected" "$rc"
rm -rf "$prefix"

# T18. Two numbers rejected
prefix=$(make_prefix)
set +e
BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 33 34 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: two numbers rejected" "$rc"
rm -rf "$prefix"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
