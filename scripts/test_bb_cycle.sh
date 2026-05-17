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

# Write a synthetic host .env.local for the recipe to read via BB_SOURCE_ENV.
# Each test creates its own copy so contents are isolated.
make_env() {
  local prefix="$1"
  local env_path="$prefix/.env.local"
  cat > "$env_path" <<'EOF'
API_TEST_APP_URL=https://app.test.example
API_TEST_DOCS_URL=https://docs.test.example
API_TEST_LOGIN=test-admin@example.com
API_TEST_PASS=test-password
BB1_ORG_ID=111
BB1_API_KEY=jwt-bb1-fake
BB2_ORG_ID=222
BB2_API_KEY=jwt-bb2-fake
BB3_ORG_ID=333
BB3_API_KEY=jwt-bb3-fake
EOF
  echo "$env_path"
}

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
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: empty prefix yields 1" "$(extract_n "$prefix" "$out")" "1"
rm -rf "$prefix"

# 2. bb-5 present → cycle 6
prefix=$(make_prefix); mkdir -p "$prefix/bb-5"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: bb-5 yields 6" "$(extract_n "$prefix" "$out")" "6"
rm -rf "$prefix"

# 3. Non-numeric dirs ignored
prefix=$(make_prefix); mkdir -p "$prefix/bb-pw" "$prefix/bb-work"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: non-numeric suffixes ignored" "$(extract_n "$prefix" "$out")" "1"
rm -rf "$prefix"

# 4. Mixed: numeric max wins, non-numeric ignored
prefix=$(make_prefix); mkdir -p "$prefix/bb-3" "$prefix/bb-5" "$prefix/bb-10" "$prefix/bb-pw"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
assert_eq "auto: numeric max wins" "$(extract_n "$prefix" "$out")" "11"
rm -rf "$prefix"

# 5. Explicit arg overrides auto
prefix=$(make_prefix); mkdir -p "$prefix/bb-100"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 7 2>&1)
assert_eq "explicit: arg overrides auto" "$(extract_n "$prefix" "$out")" "7"
rm -rf "$prefix"

# 6. Refuse when target exists
prefix=$(make_prefix); mkdir -p "$prefix/bb-7"
env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 7 >/dev/null 2>&1
rc=$?
set -e
assert_false "refuse: existing target rejected" "$rc"
rm -rf "$prefix"

# 7. Reject non-numeric arg
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle abc >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: non-numeric arg rejected" "$rc"
rm -rf "$prefix"

# 8. Copy includes hidden files (.envrc)
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle >/dev/null 2>&1
[ -f "$prefix/bb-1/.envrc" ] && [ -f "$prefix/bb-1/BB.md" ] && [ -x "$prefix/bb-1/check-deploy-lag.sh" ]
rc=$?
assert_true "copy: hidden files and executable bit preserved" "$rc"
rm -rf "$prefix"

# --- TRA-762: selector arg, suffixed target, auto-num across suffixes ---

# T9. Selector-only: bb_cycle BB2 (no num) → bb-1-BB2/
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
[ -d "$prefix/bb-1-BB2" ] && rc=0 || rc=$?
assert_true "selector: BB2 alone yields bb-1-BB2" "$rc"
rm -rf "$prefix"

# T10. Selector + num (num first): bb_cycle 33 BB1 → bb-33-BB1/
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 33 BB1 2>&1)
[ -d "$prefix/bb-33-BB1" ] && rc=0 || rc=$?
assert_true "selector+num: '33 BB1' yields bb-33-BB1" "$rc"
rm -rf "$prefix"

# T11. Selector + num (selector first): bb_cycle BB1 33 → bb-33-BB1/ (order-agnostic)
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 33 2>&1)
[ -d "$prefix/bb-33-BB1" ] && rc=0 || rc=$?
assert_true "selector+num: 'BB1 33' yields bb-33-BB1 (order-agnostic)" "$rc"
rm -rf "$prefix"

# T12. Auto-num same-cycle reuse: bb-3-BB1 exists → bb_cycle BB2 picks 3
prefix=$(make_prefix); mkdir -p "$prefix/bb-3-BB1"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
[ -d "$prefix/bb-3-BB2" ] && rc=0 || rc=$?
assert_true "auto: bb-3-BB1 present, BB2 picks 3 (not 4)" "$rc"
rm -rf "$prefix"

# T13. Auto-num across-track: bb-3 (mint) + bb-3-BB1 exist → bb_cycle BB2 picks 3
prefix=$(make_prefix); mkdir -p "$prefix/bb-3" "$prefix/bb-3-BB1"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
[ -d "$prefix/bb-3-BB2" ] && rc=0 || rc=$?
assert_true "auto: bb-3 + bb-3-BB1 present, BB2 picks 3" "$rc"
rm -rf "$prefix"

# T14. Auto-num increment when target exists: full cycle 3 → bb_cycle BB1 picks 4
prefix=$(make_prefix); mkdir -p "$prefix/bb-3" "$prefix/bb-3-BB1" "$prefix/bb-3-BB2" "$prefix/bb-3-BB3"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 2>&1)
[ -d "$prefix/bb-4-BB1" ] && rc=0 || rc=$?
assert_true "auto: cycle 3 full, BB1 increments to 4" "$rc"
rm -rf "$prefix"

# T15. Mint auto-num still works when only pre-key dirs exist
prefix=$(make_prefix); mkdir -p "$prefix/bb-3-BB1"
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
[ -d "$prefix/bb-3" ] && rc=0 || rc=$?
assert_true "auto (mint): only bb-3-BB1 present, mint picks bb-3" "$rc"
rm -rf "$prefix"

# T16. Invalid selectors rejected
for bad in BB4 BB bb1 foo; do
  prefix=$(make_prefix)
  env_file=$(make_env "$prefix")
  set +e
  BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle "$bad" >/dev/null 2>&1
  rc=$?
  set -e
  assert_false "validate: '$bad' rejected" "$rc"
  rm -rf "$prefix"
done

# T17. Two selectors rejected
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 BB2 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: two selectors rejected" "$rc"
rm -rf "$prefix"

# T18. Two numbers rejected
prefix=$(make_prefix)
env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 33 34 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: two numbers rejected" "$rc"
rm -rf "$prefix"

# T19. Pre-key env contents: only URLs + BB_ORG/BB_API_KEY/BB_ORG_ID, no login/pass
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 >/dev/null 2>&1
target_env="$prefix/bb-1-BB2/.env.local"
[ -f "$target_env" ] && rc=0 || rc=$?
assert_true "filter (pre-key): target .env.local exists" "$rc"
grep -q "^API_TEST_APP_URL=https://app.test.example$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): API_TEST_APP_URL present" "$rc"
grep -q "^API_TEST_DOCS_URL=https://docs.test.example$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): API_TEST_DOCS_URL present" "$rc"
grep -q "^BB_ORG=BB2$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_ORG=BB2" "$rc"
grep -q "^BB_API_KEY=jwt-bb2-fake$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_API_KEY matches BB2 source" "$rc"
grep -q "^BB_ORG_ID=222$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_ORG_ID matches BB2 source" "$rc"
! grep -q "^API_TEST_LOGIN=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no API_TEST_LOGIN" "$rc"
! grep -q "^API_TEST_PASS=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no API_TEST_PASS" "$rc"
! grep -q "^BB1_API_KEY=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no other orgs' keys (BB1)" "$rc"
! grep -q "^BB3_API_KEY=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no other orgs' keys (BB3)" "$rc"
rm -rf "$prefix"

# T20. Mint env contents: URLs + LOGIN/PASS, no BB_* vars
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle >/dev/null 2>&1
target_env="$prefix/bb-1/.env.local"
[ -f "$target_env" ] && rc=0 || rc=$?
assert_true "filter (mint): target .env.local exists" "$rc"
grep -q "^API_TEST_APP_URL=https://app.test.example$" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): API_TEST_APP_URL present" "$rc"
grep -q "^API_TEST_DOCS_URL=https://docs.test.example$" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): API_TEST_DOCS_URL present" "$rc"
grep -q "^API_TEST_LOGIN=test-admin@example.com$" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): API_TEST_LOGIN present" "$rc"
grep -q "^API_TEST_PASS=test-password$" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): API_TEST_PASS present" "$rc"
! grep -q "^BB_ORG=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BB_ORG" "$rc"
! grep -q "^BB_API_KEY=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BB_API_KEY" "$rc"
! grep -q "^BB[1-3]_API_KEY=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BBn_API_KEY" "$rc"
rm -rf "$prefix"

# T21. Missing source key for selected org → fail with clear error
prefix=$(make_prefix)
env_path="$prefix/.env.local"
cat > "$env_path" <<'EOF'
API_TEST_APP_URL=https://app.test.example
API_TEST_DOCS_URL=https://docs.test.example
BB1_ORG_ID=111
BB1_API_KEY=jwt-bb1-fake
EOF
set +e
err=$(BB_SOURCE_ENV="$env_path" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 2>&1)
rc=$?
set -e
assert_false "validate (pre-key): missing BB2_API_KEY rejected" "$rc"
echo "$err" | grep -q "BB2_API_KEY" && rc=0 || rc=$?
assert_true "validate (pre-key): error message names BB2_API_KEY" "$rc"
rm -rf "$prefix"

# T22. Missing login/pass for mint track → fail with clear error
prefix=$(make_prefix)
env_path="$prefix/.env.local"
cat > "$env_path" <<'EOF'
API_TEST_APP_URL=https://app.test.example
API_TEST_DOCS_URL=https://docs.test.example
EOF
set +e
err=$(BB_SOURCE_ENV="$env_path" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
rc=$?
set -e
assert_false "validate (mint): missing API_TEST_LOGIN rejected" "$rc"
echo "$err" | grep -q "API_TEST_LOGIN" && rc=0 || rc=$?
assert_true "validate (mint): error message names API_TEST_LOGIN" "$rc"
rm -rf "$prefix"

# T23. Session-start command names BB_MINT_KEY.md on mint track
prefix=$(make_prefix); env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
echo "$out" | grep -q "BB_MINT_KEY.md" && rc=0 || rc=$?
assert_true "session-start (mint): names BB_MINT_KEY.md" "$rc"
echo "$out" | grep -qv "BB_PRE_KEY.md" && rc=0 || rc=$?
assert_true "session-start (mint): does not name BB_PRE_KEY.md" "$rc"
rm -rf "$prefix"

# T24. Session-start command names BB_PRE_KEY.md on pre-key track
prefix=$(make_prefix); env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 2>&1)
echo "$out" | grep -q "BB_PRE_KEY.md" && rc=0 || rc=$?
assert_true "session-start (pre-key): names BB_PRE_KEY.md" "$rc"
echo "$out" | grep -qv "BB_MINT_KEY.md" && rc=0 || rc=$?
assert_true "session-start (pre-key): does not name BB_MINT_KEY.md" "$rc"
rm -rf "$prefix"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
