# TRA-762 `bb_cycle` Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `just bb_cycle` to support both mint and pre-key tracks from a single entry point, with sniffed positional args (selector `BB[1-3]`, num `[0-9]+`, either order), per-track filtered `.env.local`, and the matching wrapper named in the session-start command.

**Architecture:** Modify the existing bash-shebang recipe in `justfile`. Move host `.env.local` sourcing to the top of the recipe (gated by `BB_SOURCE_ENV` test override). Add an arg-sniffing loop that classifies each positional into `selector` or `n`. Compute the target as `bb-NN[-{selector}]`. Auto-num scans `bb-NN*` ignoring suffixes; walks forward while the specific target dir exists. After copying `tests/blackbox/.`, replace the copied `.env.local` with a freshly written file containing only the vars for the chosen track. Pick `BB_MINT_KEY.md` or `BB_PRE_KEY.md` in the printed `csp` command.

**Tech Stack:** justfile + bash. Tests in `scripts/test_bb_cycle.sh` (assert helpers, synthetic env fixtures via `BB_SOURCE_ENV`).

**Spec:** `docs/superpowers/specs/2026-05-17-tra-762-bb-cycle-selector-design.md`

---

## File Structure

- **Modify:** `tests/blackbox/BB_PRE_KEY.md` — wrapper consumes flat `$BB_API_KEY` / `$BB_ORG_ID` instead of `${BB_ORG}_API_KEY` indirection.
- **Modify:** `justfile` (the `bb_cycle` recipe, lines 33–125) — arg sniffing, suffixed target, auto-num across suffixes, top-of-recipe env sourcing, filtered `.env.local` write, wrapper-aware session-start command.
- **Modify:** `scripts/test_bb_cycle.sh` — refactor existing tests to use a synthetic `BB_SOURCE_ENV` fixture; add new test cases.

No new files.

---

### Task 1: Update BB_PRE_KEY.md to consume flat vars

**Files:**
- Modify: `tests/blackbox/BB_PRE_KEY.md`

- [ ] **Step 1: Edit §Environment**

Replace the §Environment section (everything from the `## Environment` heading through the line that says "Do not attempt to use `API_TEST_LOGIN` / `API_TEST_PASS`...") with:

```markdown
## Environment

`.envrc` + `.env.local` expose:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `BB_ORG` — `BB1`, `BB2`, or `BB3`. The label for the fixture org this session is pinned to. Used for traceability in FINDINGS.md.
- `BB_API_KEY` — the persistent JWT for the assigned fixture org. Pass it as `Authorization: Bearer $BB_API_KEY` on every API call.
- `BB_ORG_ID` — numeric `org_id` for the assigned fixture (for cross-checks).

Record `$BB_ORG` and `$BB_ORG_ID` in the FINDINGS.md context block so triage can correlate runs across parallel sessions.

If `$BB_API_KEY` or `$BB_ORG` is unset, stop and report — the harness did not assign this session a fixture, and guessing is wrong.

There is no SPA login on this track. The fixture key is everything you need; `API_TEST_LOGIN` / `API_TEST_PASS` are not in the env on this track.
```

- [ ] **Step 2: Edit §Mission**

Replace the §Mission line that currently reads:

```
Resolve `$BB_ORG`, load `${BB_ORG}_API_KEY`, confirm you can reach `/health.json` and `/api/openapi.yaml`, then **read [BB.md](./BB.md) top to bottom and execute the shared methodology** against the fixture.
```

with:

```
Load `$BB_API_KEY`, confirm you can reach `/health.json` and `/api/openapi.yaml`, then **read [BB.md](./BB.md) top to bottom and execute the shared methodology** against the fixture.
```

- [ ] **Step 3: Verify no remaining `${BB_ORG}_API_KEY` indirection**

Run: `grep -n '\${BB_ORG}_' tests/blackbox/BB_PRE_KEY.md`
Expected: no output (no matches).

- [ ] **Step 4: Commit**

```bash
git add tests/blackbox/BB_PRE_KEY.md
git commit -m "$(cat <<'EOF'
docs(bb): TRA-762 BB_PRE_KEY.md consumes flat \$BB_API_KEY/\$BB_ORG_ID

The bb_cycle recipe will write a filtered per-track .env.local into the
isolated /tmp target. Each pre-key session sees exactly one fixture key,
exposed flat as \$BB_API_KEY (no \${BB_ORG}_API_KEY indirection). \$BB_ORG
stays as the human-readable label for FINDINGS.md traceability.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Selector arg parsing + suffixed target + auto-num across suffixes

**Files:**
- Modify: `justfile` (recipe `bb_cycle`, lines 33–67)
- Modify: `scripts/test_bb_cycle.sh` (add new tests; existing tests stay unchanged for now)

- [ ] **Step 1: Write the failing tests (selector + target naming + auto-num)**

Add the following block at the end of `scripts/test_bb_cycle.sh`, **before** the final `echo` summary and `[ "$fail" -eq 0 ]` line:

```bash
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
```

- [ ] **Step 2: Run new tests, verify they fail**

Run: `just test`
Expected: tests T9 through T18 fail (the recipe currently rejects `BB2` as a non-numeric arg, and treats two args as an error or ignores the second).

- [ ] **Step 3: Replace the arg-parsing + auto-num + target-build block in `justfile`**

In `justfile`, replace the recipe signature on line 34 — currently:

```just
bb_cycle num="":
```

with:

```just
bb_cycle arg1="" arg2="":
```

Then replace lines 41–61 of the recipe body — currently:

```bash
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
```

with the new block:

```bash
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
```

The "Refuse if target exists" block (currently lines 63–67) stays unchanged and still applies — it now checks the suffixed target for pre-key invocations.

- [ ] **Step 4: Update the comment block above the recipe**

Replace the Usage section in the recipe comments (currently lines 25–28) — currently:

```
# Usage:
#   just bb_cycle        # auto-increment from existing /tmp/bb-NN dirs
#   just bb_cycle 32     # explicit cycle number
```

with:

```
# Usage:
#   just bb_cycle              # mint track, auto-num
#   just bb_cycle 32           # mint track, explicit cycle number
#   just bb_cycle BB1          # pre-key track for BB1 org, auto-num
#   just bb_cycle BB1 32       # pre-key track for BB1, cycle 32
#   just bb_cycle 32 BB1       # same as above (order-agnostic)
```

- [ ] **Step 5: Run tests, verify all pass**

Run: `just test`
Expected: all tests pass, including new T9 through T18. Existing tests T1–T8 also still pass (the new sniffing logic accepts numeric args identically to the old `num=""` form).

- [ ] **Step 6: Commit**

```bash
git add justfile scripts/test_bb_cycle.sh
git commit -m "$(cat <<'EOF'
feat(bb): TRA-762 bb_cycle accepts BB[1-3] selector for pre-key track

bb_cycle now takes two optional positional args, sniffed independently:
BB[1-3] for the pre-key fixture selector, [0-9]+ for the cycle number,
either order. Pre-key dirs land at bb-NN-BBn/, mint dirs stay at bb-NN/.
Auto-num scans bb-NN* across both forms so three parallel bb_cycle BB1/
BB2/BB3 invocations naturally share a cycle number. Invalid selectors,
two-of-same args, and unrecognized args are rejected with clear errors.
Filtered .env.local and wrapper-aware session-start command come in
follow-up commits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Filtered `.env.local` + source-env test harness refactor

**Files:**
- Modify: `justfile` (recipe `bb_cycle`)
- Modify: `scripts/test_bb_cycle.sh` (add `make_env` helper; existing tests adopt it; new env-content tests)

- [ ] **Step 1: Add the `make_env` helper to the test harness**

In `scripts/test_bb_cycle.sh`, add this helper just below `make_prefix()` (after line 14):

```bash
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
```

- [ ] **Step 2: Update every existing test to set `BB_SOURCE_ENV`**

For each `just bb_cycle ...` invocation in `scripts/test_bb_cycle.sh` (both pre-existing T1–T8 and the new T9–T18 from Task 2), prepend `BB_SOURCE_ENV` set to the result of `make_env "$prefix"`.

Pattern — find every line of the form:

```bash
out=$(BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle ... 2>&1)
```

and rewrite to:

```bash
env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle ... 2>&1)
```

Likewise for the `set +e; ... ; set -e` wrapped invocations:

```bash
env_file=$(make_env "$prefix")
set +e
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle ... >/dev/null 2>&1
rc=$?
set -e
```

Important: the `make_env` call must come **after** any `mkdir -p "$prefix/bb-..."` setup so the prefix dir exists.

- [ ] **Step 3: Add new env-content tests**

Append to `scripts/test_bb_cycle.sh`, **before** the final `echo` summary:

```bash
# T19. Pre-key env contents: only URLs + BB_ORG/BB_API_KEY/BB_ORG_ID, no login/pass
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB2 >/dev/null 2>&1
target_env="$prefix/bb-1-BB2/.env.local"
[ -f "$target_env" ]
assert_true "filter (pre-key): target .env.local exists" "$?"
grep -q "^BB_ORG=BB2$" "$target_env"
assert_true "filter (pre-key): BB_ORG=BB2" "$?"
grep -q "^BB_API_KEY=jwt-bb2-fake$" "$target_env"
assert_true "filter (pre-key): BB_API_KEY matches BB2 source" "$?"
grep -q "^BB_ORG_ID=222$" "$target_env"
assert_true "filter (pre-key): BB_ORG_ID matches BB2 source" "$?"
! grep -q "^API_TEST_LOGIN=" "$target_env"
assert_true "filter (pre-key): no API_TEST_LOGIN" "$?"
! grep -q "^API_TEST_PASS=" "$target_env"
assert_true "filter (pre-key): no API_TEST_PASS" "$?"
! grep -q "^BB1_API_KEY=" "$target_env"
assert_true "filter (pre-key): no other orgs' keys (BB1)" "$?"
! grep -q "^BB3_API_KEY=" "$target_env"
assert_true "filter (pre-key): no other orgs' keys (BB3)" "$?"
rm -rf "$prefix"

# T20. Mint env contents: URLs + LOGIN/PASS, no BB_* vars
prefix=$(make_prefix); env_file=$(make_env "$prefix")
BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle >/dev/null 2>&1
target_env="$prefix/bb-1/.env.local"
[ -f "$target_env" ]
assert_true "filter (mint): target .env.local exists" "$?"
grep -q "^API_TEST_LOGIN=test-admin@example.com$" "$target_env"
assert_true "filter (mint): API_TEST_LOGIN present" "$?"
grep -q "^API_TEST_PASS=test-password$" "$target_env"
assert_true "filter (mint): API_TEST_PASS present" "$?"
! grep -q "^BB_ORG=" "$target_env"
assert_true "filter (mint): no BB_ORG" "$?"
! grep -q "^BB_API_KEY=" "$target_env"
assert_true "filter (mint): no BB_API_KEY" "$?"
! grep -q "^BB[1-3]_API_KEY=" "$target_env"
assert_true "filter (mint): no BBn_API_KEY" "$?"
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
echo "$err" | grep -q "BB2_API_KEY"
assert_true "validate (pre-key): error message names BB2_API_KEY" "$?"
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
echo "$err" | grep -q "API_TEST_LOGIN"
assert_true "validate (mint): error message names API_TEST_LOGIN" "$?"
rm -rf "$prefix"
```

- [ ] **Step 4: Run the new tests, verify they fail**

Run: `just test`
Expected: T19–T22 fail (recipe doesn't yet write a filtered `.env.local`; T21/T22 don't yet validate source vars).

- [ ] **Step 5: Move host `.env.local` sourcing to the top of the recipe**

In `justfile`, after the existing `prefix="${BB_TMP_PREFIX:-/tmp}"` line, add this block:

```bash
    # Source the host .env.local (or BB_SOURCE_ENV override for tests).
    # Required for both preflight and the filtered .env.local write step.
    source_env="${BB_SOURCE_ENV:-tests/blackbox/.env.local}"
    if [ -f "$source_env" ]; then
      set -a
      # shellcheck disable=SC1091
      . "$source_env"
      set +a
    fi
```

Then delete the redundant in-preflight sourcing block (currently lines 80–85 of the original file, which read):

```bash
      # Load API_TEST_* from tests/blackbox/.env.local. Required by the
      # preflight script. .env.local is gitignored and holds the preview
      # URLs and test credentials.
      if [ -f tests/blackbox/.env.local ]; then
        set -a
        # shellcheck disable=SC1091
        . tests/blackbox/.env.local
        set +a
      fi
```

- [ ] **Step 6: Replace the copy step with copy + filtered-env write**

Currently the recipe's copy step (around line 117) reads:

```bash
    # 4. Isolate: copy tests/blackbox/ (including hidden .envrc + .env.local)
    #    into the target dir. trailing /. makes cp include dotfiles.
    echo "==> Isolating to $target"
    mkdir -p "$target"
    cp -r tests/blackbox/. "$target/"
```

Replace with:

```bash
    # 4. Isolate: copy tests/blackbox/ into the target, then replace the
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
        src_key_var="${selector}_API_KEY"
        src_id_var="${selector}_ORG_ID"
        src_key="${!src_key_var:-}"
        src_id="${!src_id_var:-}"
        if [ -z "$src_key" ]; then
          echo "ERROR: $src_key_var is empty or unset in $source_env" >&2
          exit 1
        fi
        if [ -z "$src_id" ]; then
          echo "ERROR: $src_id_var is empty or unset in $source_env" >&2
          exit 1
        fi
        echo "BB_ORG=$selector"
        echo "BB_API_KEY=$src_key"
        echo "BB_ORG_ID=$src_id"
      else
        if [ -z "${API_TEST_LOGIN:-}" ]; then
          echo "ERROR: API_TEST_LOGIN is empty or unset in $source_env" >&2
          exit 1
        fi
        if [ -z "${API_TEST_PASS:-}" ]; then
          echo "ERROR: API_TEST_PASS is empty or unset in $source_env" >&2
          exit 1
        fi
        echo "API_TEST_LOGIN=$API_TEST_LOGIN"
        echo "API_TEST_PASS=$API_TEST_PASS"
      fi
    } > "$target/.env.local"
```

Note on the redirection: the validation error `echo "ERROR: …" >&2; exit 1` lines inside the `{ ... }` block must NOT redirect to `$target/.env.local`. Because they're inside the `{ … } > "$target/.env.local"` group, their stdout would be redirected; but `>&2` sends to stderr (which is not redirected) and `exit 1` exits the recipe. This works correctly — verified by T21/T22.

- [ ] **Step 7: Run all tests, verify all pass**

Run: `just test`
Expected: all tests pass — existing T1–T8 (now using `BB_SOURCE_ENV`), T9–T18 from Task 2, and new T19–T22.

- [ ] **Step 8: Sanity-check a real invocation locally**

Run from the worktree root:

```bash
BB_TMP_PREFIX=/tmp/bb-test-real BB_SKIP_PREFLIGHT=1 just bb_cycle BB1
cat /tmp/bb-test-real/bb-1-BB1/.env.local
rm -rf /tmp/bb-test-real
```

Expected: the printed `.env.local` contains the real `BB1_API_KEY` value from the user's host `tests/blackbox/.env.local`, plus `BB_ORG=BB1`, `BB_ORG_ID=<numeric>`, and the two URL vars. No `API_TEST_LOGIN`, `API_TEST_PASS`, `BB2_*`, or `BB3_*` lines.

- [ ] **Step 9: Commit**

```bash
git add justfile scripts/test_bb_cycle.sh
git commit -m "$(cat <<'EOF'
feat(bb): TRA-762 filtered .env.local per track + source-env validation

Recipe now sources the host .env.local at the top (overridable via
BB_SOURCE_ENV for tests) and writes a track-specific .env.local into the
isolated target instead of copying the host file. Mint targets get
API_TEST_LOGIN/PASS + URLs; pre-key targets get flat BB_ORG/BB_API_KEY/
BB_ORG_ID + URLs for the selected fixture only. Missing source vars
(BBn_API_KEY for the chosen selector, or LOGIN/PASS for mint) abort with
a clear error naming the missing var. Test harness gains a make_env
helper and all tests now point at a synthetic env via BB_SOURCE_ENV.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Session-start command picks wrapper

**Files:**
- Modify: `justfile` (recipe `bb_cycle`, final echo block)
- Modify: `scripts/test_bb_cycle.sh` (add wrapper-name assertions)

- [ ] **Step 1: Write failing tests**

Append to `scripts/test_bb_cycle.sh`, before the final `echo` summary:

```bash
# T23. Session-start command names BB_MINT_KEY.md on mint track
prefix=$(make_prefix); env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle 2>&1)
echo "$out" | grep -q "BB_MINT_KEY.md"
assert_true "session-start (mint): names BB_MINT_KEY.md" "$?"
echo "$out" | grep -qv "BB_PRE_KEY.md"
assert_true "session-start (mint): does not name BB_PRE_KEY.md" "$?"
rm -rf "$prefix"

# T24. Session-start command names BB_PRE_KEY.md on pre-key track
prefix=$(make_prefix); env_file=$(make_env "$prefix")
out=$(BB_SOURCE_ENV="$env_file" BB_TMP_PREFIX="$prefix" BB_SKIP_PREFLIGHT=1 just bb_cycle BB1 2>&1)
echo "$out" | grep -q "BB_PRE_KEY.md"
assert_true "session-start (pre-key): names BB_PRE_KEY.md" "$?"
echo "$out" | grep -qv "BB_MINT_KEY.md"
assert_true "session-start (pre-key): does not name BB_MINT_KEY.md" "$?"
rm -rf "$prefix"
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `just test`
Expected: T23/T24 fail — the recipe currently emits `BB.md` regardless of track.

- [ ] **Step 3: Parameterize the wrapper name in the session-start echo**

In `justfile`, replace the final echo block (currently lines 119–124, which read):

```bash
    # 5. Session-start command for copy-paste
    echo
    echo "==> Ready. Start the session with:"
    echo
    echo "    cd $target && direnv allow && csp 'run blackbox tests per BB.md'"
    echo
```

with:

```bash
    # 5. Session-start command for copy-paste. The wrapper file matches the
    #    chosen track; the wrapper itself points back at BB.md for the
    #    shared methodology.
    if [ -n "$selector" ]; then
      wrapper="BB_PRE_KEY.md"
    else
      wrapper="BB_MINT_KEY.md"
    fi
    echo
    echo "==> Ready. Start the session with:"
    echo
    echo "    cd $target && direnv allow && csp 'run blackbox tests per $wrapper'"
    echo
```

- [ ] **Step 4: Run all tests, verify all pass**

Run: `just test`
Expected: every test passes — T1–T8 (existing, updated for `BB_SOURCE_ENV`), T9–T18 (Task 2), T19–T22 (Task 3), T23–T24 (this task).

- [ ] **Step 5: Spot-check the printed command**

Run:

```bash
BB_TMP_PREFIX=/tmp/bb-spot-check BB_SKIP_PREFLIGHT=1 just bb_cycle
BB_TMP_PREFIX=/tmp/bb-spot-check BB_SKIP_PREFLIGHT=1 just bb_cycle BB1
rm -rf /tmp/bb-spot-check
```

Expected: first command prints `csp 'run blackbox tests per BB_MINT_KEY.md'`; second prints `csp 'run blackbox tests per BB_PRE_KEY.md'`.

- [ ] **Step 6: Commit**

```bash
git add justfile scripts/test_bb_cycle.sh
git commit -m "$(cat <<'EOF'
feat(bb): TRA-762 bb_cycle prints wrapper matching the chosen track

Session-start command now names BB_MINT_KEY.md (mint, default) or
BB_PRE_KEY.md (pre-key selector). Each wrapper sets up its track-specific
preamble and points back at BB.md for the shared methodology.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Verification

After all four tasks land:

1. `just test` passes cleanly (all 24+ tests).
2. `just bb_cycle BB1` from the repo root creates `/tmp/bb-NN-BB1/` with a filtered `.env.local` containing `BB_ORG=BB1`, `BB_API_KEY=<real BB1 JWT>`, `BB_ORG_ID=<real BB1 org_id>`, and the URL vars only; prints a `csp` command referencing `BB_PRE_KEY.md`.
3. `just bb_cycle` (no args) from the repo root creates `/tmp/bb-NN/` with a filtered `.env.local` containing `API_TEST_LOGIN`/`API_TEST_PASS`/URLs only; prints a `csp` command referencing `BB_MINT_KEY.md`.
4. Three concurrent `just bb_cycle BB1` / `BB2` / `BB3` invocations (from three terminals) all pick the same cycle number and land in distinct dirs.

## Out of scope

This plan does not:
- Aggregate `FINDINGS.md` across parallel sessions.
- Run the BB methodology itself (that's `csp 'run blackbox tests per <wrapper>'`, downstream of the recipe).
- Manage fixture data (scans, seed cleanup, etc.).
- Extend the recipe with additional tracks beyond mint and pre-key.
