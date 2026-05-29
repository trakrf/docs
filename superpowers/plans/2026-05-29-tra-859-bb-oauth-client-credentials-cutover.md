# TRA-859 — BB harness cutover to OAuth2 client_credentials

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the blackbox (BB) harness + methodology from the dead "API key is a bearer JWT" model to OAuth2 `client_credentials`: the harness hands each contract-track session a durable `{client_id, client_secret}` pair, and the BB agent exchanges it at `POST /api/v1/oauth/token` for a short-lived access token used as `Authorization: Bearer`, re-minting on 401.

**Architecture:** The `just bb_cycle` recipe filters the host `.env.local` down to one org's credentials per session; `scripts/test_bb_cycle.sh` is its self-test. The three markdown wrappers (`BB.md` shared, `BB_PRE_KEY.md` contract track, `BB_MINT_KEY.md` onboarding track) tell the BB agent how to authenticate. All five files reference the old key model and must move to the pair+exchange model. `tests/blackbox/.env.local` is already updated (gitignored, out of scope here).

**Tech Stack:** bash (justfile recipe + bats-free shell self-test), Markdown methodology docs. "Tests" = `bash scripts/test_bb_cycle.sh` (asserts the filtered env) + grep guards for stale tokens.

**Working dir:** worktree `/home/mike/trakrf-docs/.claude/worktrees/tra-859-bb-oauth-cutover` on branch `worktree-tra-859-bb-oauth-cutover`. **pnpm only** if building (no build needed here).

**Contract (ground truth for all tasks):**
- Per-org durable creds: `BBn_CLIENT_ID` (UUID) + `BBn_CLIENT_SECRET` (`trakrf_`+64hex) + `BBn_ORG_ID`.
- Exchange: `POST $API_TEST_APP_URL/api/v1/oauth/token`, header `Content-Type: application/json`, body `{"grant_type":"client_credentials","client_id":"…","client_secret":"…"}` → `{access_token, refresh_token, token_type:"Bearer", expires_in:900}`.
- Use `access_token` as `Authorization: Bearer`; on `401` (expiry, ~15 min) re-exchange. (Form-urlencoded → 415 today; JSON only for now.)

---

## Task 1: `just bb_cycle` recipe + its self-test → pass the credential pair

**Files:**
- Modify: `justfile` (the `bb_cycle` recipe: pre-key validation block ~L112–124, filtered-env write ~L186–190)
- Modify: `scripts/test_bb_cycle.sh` (synthetic env `make_env` ~L27–37; the duplicate inline env ~L286–289; pre-key filter assertions T19 ~L233–256; mint negative-filter assertions ~L274–278; validate assertions T21 ~L287–296)

- [ ] **Step 1: Update the self-test FIRST (TDD) — synthetic envs + assertions expect the pair**

In `scripts/test_bb_cycle.sh`:
- In `make_env` (the `cat > "$env_path" <<'EOF'` block), replace the three `BBn_API_KEY=jwt-bbn-fake` lines with two lines each:
  ```
  BB1_ORG_ID=111
  BB1_CLIENT_ID=client-bb1-fake
  BB1_CLIENT_SECRET=trakrf_bb1fakesecret
  BB2_ORG_ID=222
  BB2_CLIENT_ID=client-bb2-fake
  BB2_CLIENT_SECRET=trakrf_bb2fakesecret
  BB3_ORG_ID=333
  BB3_CLIENT_ID=client-bb3-fake
  BB3_CLIENT_SECRET=trakrf_bb3fakesecret
  ```
- In the T21 inline env (~L286–289, the smaller `cat` that omits BB2 to test the missing-var path), replace `BB1_API_KEY=jwt-bb1-fake` with `BB1_CLIENT_ID=client-bb1-fake` + `BB1_CLIENT_SECRET=trakrf_bb1fakesecret` (keep `BB1_ORG_ID=111`; keep BB2 absent).
- T19 pre-key filter assertions (~L244–256): change the `BB_API_KEY` checks to the new shape. Replace:
  - `grep -q "^BB_API_KEY=jwt-bb2-fake$"` → `grep -q "^BB_CLIENT_ID=client-bb2-fake$"` (rename the assert label too), and ADD a sibling assert `grep -q "^BB_CLIENT_SECRET=trakrf_bb2fakesecret$"`.
  - The "no other orgs' keys" negatives: `! grep -q "^BB1_API_KEY="` / `"^BB3_API_KEY="` → `! grep -q "^BB1_CLIENT_ID="` and `! grep -q "^BB1_CLIENT_SECRET="` (and BB3 likewise). Keep asserting `BB_ORG_ID` matches.
- Mint negative-filter assertions (~L274–278): `! grep -q "^BB_API_KEY="` → `! grep -q "^BB_CLIENT_ID="` and `! grep -q "^BB_CLIENT_SECRET="`; `! grep -q "^BB[1-3]_API_KEY="` → `! grep -q "^BB[1-3]_CLIENT_ID="` and `^BB[1-3]_CLIENT_SECRET="`.
- T21 validate assertions (~L294–296): `missing BB2_API_KEY rejected` / `error message names BB2_API_KEY` → `BB2_CLIENT_ID` (the recipe validates client_id first; see Step 3). Update both the assert label and the `grep -q "BB2_..."` on the error text.

- [ ] **Step 2: Run the self-test, expect FAILURE**

Run: `bash scripts/test_bb_cycle.sh`
Expected: FAILs on the pre-key filter + validate assertions (recipe still emits `BB_API_KEY`, not `BB_CLIENT_ID`/`BB_CLIENT_SECRET`). This confirms the test now drives the new behavior.

- [ ] **Step 3: Update the `bb_cycle` recipe to read + emit the pair**

In `justfile`, the pre-key validation block (currently):
```bash
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
```
Replace with:
```bash
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
```
And the filtered-env write block (currently):
```bash
      if [ -n "$selector" ]; then
        echo "BB_ORG=$selector"
        echo "BB_API_KEY=$src_key"
        echo "BB_ORG_ID=$src_id"
      else
```
Replace the pre-key branch with:
```bash
      if [ -n "$selector" ]; then
        echo "BB_ORG=$selector"
        echo "BB_CLIENT_ID=$src_client_id"
        echo "BB_CLIENT_SECRET=$src_client_secret"
        echo "BB_ORG_ID=$src_id"
      else
```

- [ ] **Step 4: Run the self-test, expect PASS**

Run: `bash scripts/test_bb_cycle.sh`
Expected: all assertions pass (final line reports 0 failures).

- [ ] **Step 5: Commit**

```bash
git add justfile scripts/test_bb_cycle.sh
git commit -m "test(bb): hand contract-track sessions client_id/secret pair (TRA-859)"
```

---

## Task 2: `BB_PRE_KEY.md` — contract-track methodology to pair+exchange

**Files:**
- Modify: `tests/blackbox/BB_PRE_KEY.md`

- [ ] **Step 1: Rewrite the credential model**

Make these prose changes (preserve surrounding structure/tone):
- L3: "You have a pre-minted **API key** for one of three parallelism-fixture orgs." → "You have a pre-minted **`{client_id, client_secret}` credential pair** for one of three parallelism-fixture orgs."
- Env-vars list (~L9–14): replace the `BB_API_KEY — the persistent JWT … Pass it as Authorization: Bearer $BB_API_KEY` bullet with:
  - `BB_CLIENT_ID` / `BB_CLIENT_SECRET` — the durable OAuth2 client_credentials for the assigned fixture org. **Not** a bearer token; you exchange them for a short-lived access token (next paragraph).
  - `BB_ORG` / `BB_ORG_ID` — unchanged.
  Then add the exchange instruction:
  > Mint an access token once at session start:
  > ```bash
  > ACCESS_TOKEN=$(curl -s -X POST "$API_TEST_APP_URL/api/v1/oauth/token" \
  >   -H "Content-Type: application/json" \
  >   -d "{\"grant_type\":\"client_credentials\",\"client_id\":\"$BB_CLIENT_ID\",\"client_secret\":\"$BB_CLIENT_SECRET\"}" \
  >   | python3 -c "import json,sys;print(json.load(sys.stdin)['access_token'])")
  > ```
  > Send `Authorization: Bearer $ACCESS_TOKEN` on every API call. The token lives 15 minutes (`expires_in: 900`); if a call returns `401` with `detail: "Invalid or expired token"`, re-run the exchange and retry. (`/oauth/token` requires `Content-Type: application/json` — form-urlencoded returns 415.)
- L19 unset guard: "If `$BB_API_KEY` or `$BB_ORG` is unset, stop and report" → "If `$BB_CLIENT_ID`, `$BB_CLIENT_SECRET`, or `$BB_ORG` is unset, stop and report".
- L44: "The fixture key on each org is `bb-parallel-permanent`, no expiry, with scopes:" → "The fixture credential on each org is named `bb-parallel-permanent`, with scopes:" (drop "no expiry"; the credential pair is durable, but the access tokens it mints are short-lived).
- L62: "the fixture **key** is intentionally broad" → "the fixture **credential** is intentionally broad" (keep the 403-unreachable point intact).
- L69 orientation step: "Load `$BB_API_KEY`, confirm you can reach `/health.json` and `/api/openapi.yaml`" → "Mint your access token (above), confirm you can reach `/health.json` and `/api/openapi.yaml`".

- [ ] **Step 2: Guard — no stale references**

Run: `grep -nE "BB_API_KEY|persistent JWT|Bearer \\\$BB_API_KEY|no expiry" tests/blackbox/BB_PRE_KEY.md`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add tests/blackbox/BB_PRE_KEY.md
git commit -m "docs(bb): contract track exchanges client_credentials for access token (TRA-859)"
```

---

## Task 3: `BB.md` — shared methodology wording

**Files:**
- Modify: `tests/blackbox/BB.md`

- [ ] **Step 1: Reconcile key→credential/token wording (do not change methodology substance)**

- L5–6 (track summaries): "Start without an API key … mint a key" → "Start without credentials … mint a credential pair"; "Start with a pre-minted **API key** pinned to a … org" → "Start with a pre-minted **credential pair** pinned to a … org".
- L8: "Where the sections below refer to "your API key," the wrapper has already specified its origin." → "Where the sections below refer to "your access token," the wrapper has already specified how you obtained it (minted in the SPA on the mint track; exchanged from a client_credentials pair on the contract track)."
- L39 bullet heading "**No programmatic API key mint.**": keep the claim (minting is SPA-bound, no public programmatic seam) but reword "mint a key" → "mint credentials" within the bullet; leave the Stripe analogy and YAGNI note.
- L281 cleanup: "Delete any API keys or artifacts you create … platform-managed fixture keys (e.g., the persistent `bb-parallel-permanent` keys on the BB1/BB2/BB3 orgs), which are reused across cycles and not yours to revoke." → "Delete any credentials or artifacts you create … platform-managed fixture credentials (the `bb-parallel-permanent` credential on each BB1/BB2/BB3 org), which are reused across cycles and not yours to revoke." (Access tokens you mint expire on their own — nothing to clean up.)
- L116/L117 (401/403 probe list) and L149 (codegen auth-attach): these remain accurate; only change the literal phrase "the API key" → "the access token" where it refers to the value sent on the wire. Leave `X-API-Key` (it's the wrong-scheme example) as-is.

- [ ] **Step 2: Guard**

Run: `grep -nE "your API key|mint a key|bb-parallel-permanent keys|pre-minted API key" tests/blackbox/BB.md`
Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add tests/blackbox/BB.md
git commit -m "docs(bb): shared methodology uses access-token/credential terminology (TRA-859)"
```

---

## Task 4: `BB_MINT_KEY.md` — onboarding track aligns to SPA mint + exchange

**Files:**
- Modify: `tests/blackbox/BB_MINT_KEY.md`

- [ ] **Step 1: Align the onboarding flow to the shipped auth docs**

The public `authentication.md` now teaches: SPA **New Key** returns a `{client_id, client_secret}` (secret shown once) → exchange at `/oauth/token` → use the access token as Bearer. Update this wrapper to match:
- L5 / "Mission" (L34) / L38: "mint **a key**" / "Set up an **API key**" / "Treat your minted **key** as "your API key"" → mint **credentials** (`client_id` + `client_secret`, secret shown once), then **exchange them at `POST /api/v1/oauth/token` (`grant_type=client_credentials`) for a short-lived access token**, and treat that **access token** as "your access token" wherever BB.md refers to one. Keep the "onboarding fails before you can authenticate = that is the report" framing.
- Keep the SPA login/password handling section and the Playwright literal-password exception **unchanged** — they are about logging into the SPA to reach the mint UI, which still applies.
- Preserve the "you control the scope at mint time / full CRUD incl DELETE is yours" point (still true — scopes are chosen on the credential at mint).

- [ ] **Step 2: Guard**

Run: `grep -nE "mint a key|Set up an API key|your minted key" tests/blackbox/BB_MINT_KEY.md`
Expected: no matches (phrasing moved to credentials/access-token).

- [ ] **Step 3: Commit**

```bash
git add tests/blackbox/BB_MINT_KEY.md
git commit -m "docs(bb): onboarding track mints credentials then exchanges for token (TRA-859)"
```

---

## Task 5: Final verification

- [ ] **Step 1: Self-test passes**

Run: `bash scripts/test_bb_cycle.sh`
Expected: 0 failures.

- [ ] **Step 2: Repo-wide stale-reference guard (excluding the plan/spec + .env.local)**

Run:
```bash
grep -rnE "BB_API_KEY|BBn_API_KEY|bb-parallel-permanent keys|persistent JWT|use (it|the key) as .*Bearer" \
  justfile scripts/test_bb_cycle.sh tests/blackbox/BB.md tests/blackbox/BB_PRE_KEY.md tests/blackbox/BB_MINT_KEY.md
```
Expected: no matches (the recipe + docs no longer reference the dead model). `BB_CLIENT_ID`/`BB_CLIENT_SECRET` are the new names.

- [ ] **Step 3: Dry-run the documented contract-track exchange against preview**

Using the real cached creds from the MAIN checkout (`/home/mike/trakrf-docs/tests/blackbox/.env.local`, not the worktree), confirm the exact command block in `BB_PRE_KEY.md` works:
```bash
set -a; . /home/mike/trakrf-docs/tests/blackbox/.env.local; set +a
BB_CLIENT_ID=$BB1_CLIENT_ID BB_CLIENT_SECRET=$BB1_CLIENT_SECRET bash -c '
  AT=$(curl -s -X POST "$API_TEST_APP_URL/api/v1/oauth/token" -H "Content-Type: application/json" \
    -d "{\"grant_type\":\"client_credentials\",\"client_id\":\"$BB_CLIENT_ID\",\"client_secret\":\"$BB_CLIENT_SECRET\"}" \
    | python3 -c "import json,sys;print(json.load(sys.stdin)[\"access_token\"])")
  curl -s -o /dev/null -w "orgs/me: %{http_code}\n" -H "Authorization: Bearer $AT" "$API_TEST_APP_URL/api/v1/orgs/me"'
```
Expected: `orgs/me: 200`. (Confirms the methodology's literal commands are correct, not just the prose.)

- [ ] **Step 4: Finish the branch**

Use superpowers:finishing-a-development-branch → push + PR to `main`, title referencing TRA-859. Do NOT merge without explicit user confirmation.

---

## Self-review

- **Spec coverage:** recipe+test (Task 1), BB_PRE_KEY contract track (Task 2), BB.md shared (Task 3), BB_MINT_KEY onboarding (Task 4), verification incl live dry-run (Task 5). All four files from the inventory + the recipe are covered.
- **Placeholders:** none — every edit gives concrete old→new strings and the exchange command is literal.
- **Naming consistency:** `BB_CLIENT_ID` / `BB_CLIENT_SECRET` / `BB_ORG_ID` / `BB_ORG` used identically in the recipe (Task 1 Step 3), the self-test (Task 1 Step 1), and the contract-track doc (Task 2). Recipe validates `CLIENT_ID` first, so the T21 "missing → names BB2_CLIENT_ID" assertion matches.
- **Out of scope (correctly):** `.env.local` (already updated, gitignored); the `check-deploy-lag.sh` staleness-alarm improvement (separate concern); form-urlencoded support (platform-side).
