# TRA-762 — `bb_cycle` selector arg (mint vs. pre-key tracks)

## Context

The trakrf API black-box methodology now splits into two tracks (see `tests/blackbox/BB.md`, `BB_MINT_KEY.md`, `BB_PRE_KEY.md`):

- **Mint track:** start without an API key, log in to the SPA, mint a key, run the methodology. Exercises onboarding end-to-end. Single-instance.
- **Pre-key track:** start with a pre-minted fixture key pinned to one of three parallelism orgs (`BB1`, `BB2`, `BB3`). Skip the mint flow, run the methodology. Parallelizable across orgs.

The platform-managed fixture keys live in `tests/blackbox/.env.local` as `BB{1,2,3}_API_KEY` / `BB{1,2,3}_ORG_ID`. The user runs parallel pre-key sessions by opening N terminals and invoking the recipe N times, once per org. The justfile recipe must support both tracks from a single entry point and keep the parallel sessions cleanly isolated from each other.

## Signature

`bb_cycle [arg1] [arg2]` — two optional positional args, order-agnostic via sniffing:

| Arg matches    | Meaning                              |
| -------------- | ------------------------------------ |
| `BB[1-3]`      | Selector → pre-key track for that org |
| `[0-9]+`       | Explicit cycle number                |
| (empty/unset)  | Defaults: mint track + auto-num      |

Examples:

```
just bb_cycle              # mint, auto-num
just bb_cycle 33           # mint, cycle 33                (back-compat preserved)
just bb_cycle BB1          # pre-key BB1, auto-num
just bb_cycle BB1 33       # pre-key BB1, cycle 33
just bb_cycle 33 BB1       # same as above (order-agnostic)
```

Invalid forms (rejected with a clear error):

- Two selectors (`bb_cycle BB1 BB2`).
- Two numbers (`bb_cycle 33 34`).
- Unrecognized arg (`bb_cycle foo`, `bb_cycle BB4`, `bb_cycle bb1`).

## Directory naming

- **Mint track:** `$BB_TMP_PREFIX/bb-NN/` (no suffix).
- **Pre-key track:** `$BB_TMP_PREFIX/bb-NN-{selector}/` (suffix is the literal selector, e.g. `BB1`).

Mint and pre-key share the numeric counter. Cycle 33 can hold any combination of `bb-33`, `bb-33-BB1`, `bb-33-BB2`, `bb-33-BB3` — the orchestrator treats them as one logical cycle.

## Auto-num algorithm

When `[num]` is not provided:

1. Scan `$BB_TMP_PREFIX` for directories matching `bb-NN` or `bb-NN-*`. Take the max `NN` seen (ignore the suffix when computing the max). If no `bb-NN*` dir exists, `NN = 1`.
2. Build the target path for this invocation (`bb-NN` for mint, `bb-NN-{selector}` for pre-key).
3. If the target already exists, increment `NN` by 1 and rebuild the path; repeat until the target does not exist.

This makes three parallel `bb_cycle BB{1,2,3}` invocations land on the same `NN` (because each one's specific target doesn't exist yet) while still incrementing cleanly when a track is rerun against an existing cycle.

## Filtered isolated environment

Today the recipe runs `cp -r tests/blackbox/. $target/`, which copies the entire host `.env.local` (login/pass + all three BB-N keys) into the target. Replace this with two steps:

1. **Copy non-env files** from `tests/blackbox/` into `$target/` (BB.md, BB_MINT_KEY.md, BB_PRE_KEY.md, BACKLOG.md, `.envrc`, `check-deploy-lag.sh`, and anything else the directory contains). Exclude `.env.local`.
2. **Write a track-specific `.env.local`** in `$target/`:

### Mint track `.env.local`

```
API_TEST_APP_URL=<from host .env.local>
API_TEST_DOCS_URL=<from host .env.local>
API_TEST_LOGIN=<from host .env.local>
API_TEST_PASS=<from host .env.local>
```

### Pre-key track `.env.local` (selector = `BBn`)

```
API_TEST_APP_URL=<from host .env.local>
API_TEST_DOCS_URL=<from host .env.local>
BB_ORG=BBn
BB_API_KEY=<value of $BBn_API_KEY from host .env.local>
BB_ORG_ID=<value of $BBn_ORG_ID from host .env.local>
```

Required source vars are read from the host `.env.local` (already loaded earlier in the recipe for the deploy-lag preflight). If any required source var is missing or empty, the recipe must abort with a clear error naming the missing var.

Rationale: each session sees exactly the surface a customer-developer counterpart would see — no admin credentials in a pre-key session, no other orgs' keys in a BB1 session, no fixture keys in a mint session.

## Wrapper update — BB_PRE_KEY.md

Because the filtered pre-key `.env.local` exposes flat `$BB_API_KEY` and `$BB_ORG_ID`, update `tests/blackbox/BB_PRE_KEY.md`:

- Replace the `${BB_ORG}_API_KEY` indirection wording in §Environment with direct references to `$BB_API_KEY` and `$BB_ORG_ID`.
- Keep `$BB_ORG` listed — it's still set, still useful as the human-readable label in FINDINGS.md context.
- Drop the language enumerating the three keys; the wrapper's perspective is per-session and only sees one key.

The shared methodology (`BB.md`) doesn't need to change.

## Session-start command

The final line printed by the recipe selects the wrapper based on track:

- Mint: `cd $target && direnv allow && csp 'run blackbox tests per BB_MINT_KEY.md'`
- Pre-key: `cd $target && direnv allow && csp 'run blackbox tests per BB_PRE_KEY.md'`

## Tests

Extend `scripts/test_bb_cycle.sh` with cases covering the new behavior. Existing cases (auto-num progression, refuse-if-exists, hidden-file copy) stay; the new cases use a synthetic host `.env.local` placed inside `$BB_TMP_PREFIX` (or an env-override mechanism) so the test doesn't depend on the real one.

New cases:

1. **Selector-only:** `just bb_cycle BB2` → target is `bb-1-BB2/`. Target's `.env.local` contains `BB_ORG=BB2`, `BB_API_KEY=<BB2 value>`, `BB_ORG_ID=<BB2 value>`, and the two URL vars. Does NOT contain `API_TEST_LOGIN`, `API_TEST_PASS`, or the other orgs' keys.
2. **Selector + num, num first:** `just bb_cycle 33 BB1` → `bb-33-BB1/`.
3. **Selector + num, selector first:** `just bb_cycle BB1 33` → `bb-33-BB1/` (same outcome as case 2).
4. **Auto-num same-cycle reuse:** with `bb-3-BB1/` already present, `just bb_cycle BB2` → `bb-3-BB2/` (NN=3, not 4).
5. **Auto-num across-track:** with `bb-3/` (mint) and `bb-3-BB1/` (pre-key) both present, `just bb_cycle BB2` → `bb-3-BB2/`.
6. **Auto-num increment when target exists:** with `bb-3/`, `bb-3-BB1/`, `bb-3-BB2/`, `bb-3-BB3/` all present, `just bb_cycle BB1` → `bb-4-BB1/`.
7. **Mint track auto-num unchanged:** with `bb-3-BB1/` present (no `bb-3/`), `just bb_cycle` → `bb-3/`.
8. **Mint track env shape:** `just bb_cycle` writes `.env.local` with `API_TEST_LOGIN` / `API_TEST_PASS` and the URL vars; no `BB_*` vars.
9. **Invalid selectors rejected:** `bb_cycle BB4`, `bb_cycle BB`, `bb_cycle bb1`, `bb_cycle foo` all exit non-zero with a message naming the offending arg.
10. **Two selectors rejected:** `bb_cycle BB1 BB2` exits non-zero.
11. **Two numbers rejected:** `bb_cycle 33 34` exits non-zero.
12. **Missing source key rejected:** synthetic host `.env.local` omits `BB2_API_KEY`; `just bb_cycle BB2` exits non-zero with a message naming `BB2_API_KEY`.

## Out of scope

- Parallel-session orchestration. The user manually opens N terminals.
- FINDINGS.md aggregation across parallel runs. Each session writes its own FINDINGS.md to its target dir; aggregation is a downstream/triage concern.
- DELETE coverage on the pre-key track. Fixture key scope omits `*:delete`; this is documented in BB_PRE_KEY.md and the spec covers it via the §Mission note, not by recipe behavior.
- New tracks beyond mint and pre-key. If a future fixture model needs different env, this spec doesn't pre-allocate for it.
