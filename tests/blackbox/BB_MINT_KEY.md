# trakrf API — black-box evaluation (mint-key track)

You have a TrakRF login at `$API_TEST_APP_URL` (`$API_TEST_LOGIN` / `$API_TEST_PASS`). See if this tool can connect to your systems.

This is the **onboarding track**: you start without an API key, mint one through the SPA, then run the shared methodology in [BB.md](./BB.md). It exercises the human-developer quickstart end-to-end — log-in to first-call. Runs single-instance.

For the parallel **contract track** (skip the mint, use a pre-minted fixture key), see [BB_PRE_KEY.md](./BB_PRE_KEY.md) — but don't switch tracks mid-session. Pick one at start.

## Environment

`.envrc` + `.env.local` expose four vars via direnv:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `API_TEST_LOGIN` — admin account email
- `API_TEST_PASS` — admin account password

**Do not echo `API_TEST_PASS` or pass it as a literal in tool-call arguments.** Reference it through env var expansion or your language's env-reading APIs.

## Tooling notes

When this evaluation runs through a Playwright MCP-driven browser harness, the literal-password rule above and the supported SPA mint flow are jointly unsatisfiable: the `browser_type` tool has no env-variable substitution, so the password has to appear in the call as a literal. A real customer developer typing into a real browser doesn't hit this — it's a tooling artifact, not a TrakRF design issue. A loopback HTTP shim that reads the password server-side and injects it into the page via `<script src=...>` or `fetch(...)` is blocked by Chrome's Private Network Access policy when initiated from the public docs origin; don't re-attempt that path.

Within the Playwright MCP environment, the literal-password constraint may be relaxed for **a single `browser_type` call to the SPA mint/login form's password field**, under these conditions:

- The literal appears in exactly one tool call — the password field of the SPA login/mint form.
- The password is not echoed back into chat output.
- The password is not written to disk — no scratch files, notes, `FINDINGS.md`, or screenshots that capture the field.

The exception does not extend to any other tool call. `curl`, `fetch`, file writes, log statements, and any other surface where the literal could land remain forbidden. This is one named hole in the harness boundary, not a license to spread the literal through the run.

## Mission

Read the docs. Set up an API key. Call the API. Evaluate the experience.

**If onboarding fails before you can authenticate against the API, that is the report.** Document the failure point with verbatim error output and stop. Do not infer findings about endpoints you couldn't reach. A short report that says "I could not get past step 3 of the quickstart, here is exactly what I saw" is more useful than a long report padded with speculation.

Once you have a working API key, **read [BB.md](./BB.md) top to bottom and execute the shared methodology**. Treat your minted key as "your API key" wherever the shared methodology refers to one. The full CRUD lifecycle (including DELETE) is yours to exercise on this track — you control the key's scope at mint time.
