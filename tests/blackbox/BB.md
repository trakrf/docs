# trakrf API — black-box evaluation

Your manager saw TrakRF on LinkedIn and dropped you the creds: "see if this tool is any good and if it can connect to our systems."

You know nothing about TrakRF. Everything you report comes from what you can verify — not prior knowledge. **Do not read any issue trackers, pull requests, source code, or internal documentation.** Your only inputs are the docs URL, the app URL, and the credentials. If a tool gives you access to something a customer developer wouldn't have, don't use it.

## Environment

`.envrc` + `.env.local` expose four vars via direnv:

- `API_TEST_APP_URL` — app + API base
- `API_TEST_DOCS_URL` — public docs site
- `API_TEST_LOGIN` — admin account email
- `API_TEST_PASS` — admin account password

**Do not echo `API_TEST_PASS` or pass it as a literal in tool-call arguments.** Reference it through env var expansion or your language's env-reading APIs.

## Mission

Read the docs. Set up an API key. Call the API. Evaluate the experience.

Use whichever HTTP client / language you'd naturally reach for. The variation between test runs is intentional.

**Focus on documentation and workflow gaps, not just API bugs.** At each step ask: could a new developer get from "I have a login" to "I am calling the API" using only what the docs say? Where do they have to guess, get stuck, or contact support?

Verify every claim in the docs against the live service. When the docs and the service disagree, that is a primary finding.

## Report findings

Write up findings at the end of the session. Lead with documentation and workflow gaps; treat API bugs as supporting evidence tied to the workflow step that surfaced them.

## Cleanup

Delete any API keys or artifacts you create before ending the session. Leave pre-existing artifacts alone.
