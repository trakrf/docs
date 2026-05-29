#!/usr/bin/env bash
# Exercises the `just bb` recipe: cycle.round[.session] parsing, track
# selection by segment count, refuse-if-exists guard, env filtering, and
# hidden-file copy. Uses BB_TMP_PREFIX to redirect /tmp/bb-* into an isolated
# tempdir, BB_SKIP_PREFLIGHT=1 to bypass the external HTTP checks, and
# BB_NO_LAUNCH=1 to skip the final `exec claude ...` so the recipe returns
# normally for assertions.

set -euo pipefail

export BB_NO_LAUNCH=1

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
BB1_CLIENT_ID=client-bb1-fake
BB1_CLIENT_SECRET=trakrf_bb1fakesecret
BB2_ORG_ID=222
BB2_CLIENT_ID=client-bb2-fake
BB2_CLIENT_SECRET=trakrf_bb2fakesecret
BB3_ORG_ID=333
BB3_CLIENT_ID=client-bb3-fake
BB3_CLIENT_SECRET=trakrf_bb3fakesecret
EOF
  echo "$env_path"
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

# --- Track selection by segment count ---

# Mint: explicit cycle.round → bb-2.3
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3 >/dev/null 2>&1
[ -d "$prefix/bb-2.3" ] && rc=0 || rc=$?
assert_true "mint: 2.3 creates bb-2.3" "$rc"
rm -rf "$prefix"

# Pre-key: explicit cycle.round.session → bb-2.3.1 (session 1 = BB1)
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3.1 >/dev/null 2>&1
[ -d "$prefix/bb-2.3.1" ] && rc=0 || rc=$?
assert_true "pre-key: 2.3.1 creates bb-2.3.1" "$rc"
rm -rf "$prefix"

# Pre-key: session 2 → bb-2.3.2 (BB2)
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3.2 >/dev/null 2>&1
[ -d "$prefix/bb-2.3.2" ] && rc=0 || rc=$?
assert_true "pre-key: 2.3.2 creates bb-2.3.2" "$rc"
rm -rf "$prefix"

# Pre-key: session 3 → bb-2.3.3 (BB3)
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3.3 >/dev/null 2>&1
[ -d "$prefix/bb-2.3.3" ] && rc=0 || rc=$?
assert_true "pre-key: 2.3.3 creates bb-2.3.3" "$rc"
rm -rf "$prefix"

# --- Argument validation ---

# Reject session out of {1,2,3}: session 4
prefix=$(make_prefix); env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3.4 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: session 4 rejected" "$rc"
rm -rf "$prefix"

# Reject session out of {1,2,3}: session 0
prefix=$(make_prefix); env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3.0 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: session 0 rejected" "$rc"
rm -rf "$prefix"

# Reject malformed: single int (no round segment)
prefix=$(make_prefix); env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 5 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: single int rejected" "$rc"
rm -rf "$prefix"

# Reject malformed: four segments
prefix=$(make_prefix); env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.3.1.1 >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: four segments rejected" "$rc"
rm -rf "$prefix"

# Reject malformed: non-numeric
prefix=$(make_prefix); env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb foo >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: non-numeric rejected" "$rc"
rm -rf "$prefix"

# Missing positional arg: just itself rejects (recipe takes one mandatory arg)
prefix=$(make_prefix); env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb >/dev/null 2>&1
rc=$?
set -e
assert_false "validate: missing arg rejected" "$rc"
rm -rf "$prefix"

# --- Refuse-if-exists guard ---

# Refuse when target exists
prefix=$(make_prefix); mkdir -p "$prefix/bb-2.7"
env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.7 >/dev/null 2>&1
rc=$?
set -e
assert_false "refuse: existing target rejected" "$rc"
rm -rf "$prefix"

# --- Copy semantics ---

# Copy includes hidden files (.envrc) and preserves the executable bit
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1 >/dev/null 2>&1
[ -f "$prefix/bb-2.1/.envrc" ] && [ -f "$prefix/bb-2.1/BB.md" ] && [ -x "$prefix/bb-2.1/check-deploy-lag.sh" ]
rc=$?
assert_true "copy: hidden files and executable bit preserved" "$rc"
rm -rf "$prefix"

# --- Pre-key env filtering (session 2 = BB2) ---

# Only URLs + BB_ORG/BB_CLIENT_ID/BB_CLIENT_SECRET/BB_ORG_ID, no login/pass, no other orgs
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1.2 >/dev/null 2>&1
target_env="$prefix/bb-2.1.2/.env.local"
[ -f "$target_env" ] && rc=0 || rc=$?
assert_true "filter (pre-key): target .env.local exists" "$rc"
grep -q "^API_TEST_APP_URL=https://app.test.example$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): API_TEST_APP_URL present" "$rc"
grep -q "^API_TEST_DOCS_URL=https://docs.test.example$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): API_TEST_DOCS_URL present" "$rc"
grep -q "^BB_ORG=BB2$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_ORG=BB2" "$rc"
grep -q "^BB_CLIENT_ID=client-bb2-fake$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_CLIENT_ID matches BB2 source" "$rc"
grep -q "^BB_CLIENT_SECRET=trakrf_bb2fakesecret$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_CLIENT_SECRET matches BB2 source" "$rc"
grep -q "^BB_ORG_ID=222$" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): BB_ORG_ID matches BB2 source" "$rc"
! grep -q "^API_TEST_LOGIN=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no API_TEST_LOGIN" "$rc"
! grep -q "^API_TEST_PASS=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no API_TEST_PASS" "$rc"
! grep -q "^BB1_CLIENT_ID=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no other orgs' keys (BB1 client_id)" "$rc"
! grep -q "^BB1_CLIENT_SECRET=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no other orgs' keys (BB1 client_secret)" "$rc"
! grep -q "^BB3_CLIENT_ID=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no other orgs' keys (BB3 client_id)" "$rc"
! grep -q "^BB3_CLIENT_SECRET=" "$target_env" && rc=0 || rc=$?
assert_true "filter (pre-key): no other orgs' keys (BB3 client_secret)" "$rc"
rm -rf "$prefix"

# --- Mint env filtering ---

# URLs + LOGIN/PASS, no BB_* vars
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1 >/dev/null 2>&1
target_env="$prefix/bb-2.1/.env.local"
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
! grep -q "^BB_CLIENT_ID=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BB_CLIENT_ID" "$rc"
! grep -q "^BB_CLIENT_SECRET=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BB_CLIENT_SECRET" "$rc"
! grep -q "^BB[1-3]_CLIENT_ID=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BBn_CLIENT_ID" "$rc"
! grep -q "^BB[1-3]_CLIENT_SECRET=" "$target_env" && rc=0 || rc=$?
assert_true "filter (mint): no BBn_CLIENT_SECRET" "$rc"
rm -rf "$prefix"

# --- Per-track source-env validation ---

# Missing source key for selected org (session 2 = BB2) → fail naming BB2_CLIENT_ID
prefix=$(make_prefix)
env_path="$prefix/.env.local"
cat > "$env_path" <<'EOF'
API_TEST_APP_URL=https://app.test.example
API_TEST_DOCS_URL=https://docs.test.example
BB1_ORG_ID=111
BB1_CLIENT_ID=client-bb1-fake
BB1_CLIENT_SECRET=trakrf_bb1fakesecret
EOF
set +e
err=$(BB_SOURCE_ENV="$env_path" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1.2 2>&1)
rc=$?
set -e
assert_false "validate (pre-key): missing BB2_CLIENT_ID rejected" "$rc"
echo "$err" | grep -q "BB2_CLIENT_ID" && rc=0 || rc=$?
assert_true "validate (pre-key): error message names BB2_CLIENT_ID" "$rc"
rm -rf "$prefix"

# Missing login/pass for mint track → fail naming API_TEST_LOGIN
prefix=$(make_prefix)
env_path="$prefix/.env.local"
cat > "$env_path" <<'EOF'
API_TEST_APP_URL=https://app.test.example
API_TEST_DOCS_URL=https://docs.test.example
EOF
set +e
err=$(BB_SOURCE_ENV="$env_path" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1 2>&1)
rc=$?
set -e
assert_false "validate (mint): missing API_TEST_LOGIN rejected" "$rc"
echo "$err" | grep -q "API_TEST_LOGIN" && rc=0 || rc=$?
assert_true "validate (mint): error message names API_TEST_LOGIN" "$rc"
rm -rf "$prefix"

# --- Wrapper selection in the session-start command ---

# Session-start names BB_MINT_KEY.md on mint track
prefix=$(make_prefix); env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1 2>&1)
echo "$out" | grep -q "BB_MINT_KEY.md" && rc=0 || rc=$?
assert_true "session-start (mint): names BB_MINT_KEY.md" "$rc"
echo "$out" | grep -qv "BB_PRE_KEY.md" && rc=0 || rc=$?
assert_true "session-start (mint): does not name BB_PRE_KEY.md" "$rc"
rm -rf "$prefix"

# Session-start names BB_PRE_KEY.md on pre-key track
prefix=$(make_prefix); env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb 2.1.1 2>&1)
echo "$out" | grep -q "BB_PRE_KEY.md" && rc=0 || rc=$?
assert_true "session-start (pre-key): names BB_PRE_KEY.md" "$rc"
echo "$out" | grep -qv "BB_MINT_KEY.md" && rc=0 || rc=$?
assert_true "session-start (pre-key): does not name BB_MINT_KEY.md" "$rc"
rm -rf "$prefix"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
