---
ticket: TRA-590
parent: TRA-583
date: 2026-05-07
spec: ../specs/2026-05-07-tra-590-bb16-w1-spa-first-auth-design.md
status: plan
---

# TRA-590 — BB16 W1 SPA-first auth docs reframe — implementation plan

Branch: `miks2u/tra-590-bb16-w1-reframe-authentication-docs-around-spa-first` in worktree at `.claude/worktrees/tra-590-spa-first-auth-docs/`.

## Step 1 — design doc commit

- File: `spec/superpowers/specs/2026-05-07-tra-590-bb16-w1-spa-first-auth-design.md` (already committed: `e9b949a`)

## Step 2 — plan doc commit

- File: `spec/superpowers/plans/2026-05-07-tra-590-bb16-w1-spa-first-auth.md` (this file)
- Commit: `docs(plan): TRA-590 BB16 W1 SPA-first auth reframe plan`

## Step 3 — `docs/api/authentication.md` — add "Where keys come from" lead

Insert a new H2 `## Where keys come from` after the page intro (line 7), before the existing `## Mint your first API key {#mint-your-first-api-key}`. Three short paragraphs: where keys come from (avatar menu), why no programmatic mint (trust boundary + Stripe analogy), v2 escape valve (contact us for genuine programmatic-provisioning use cases).

Tighten the existing `## Mint your first API key` section:

- Drop the lead sentence "API keys are minted through the TrakRF web app. v1 does not provide a programmatic key-mint endpoint — the flow is browser-mediated by design, consistent with how Stripe gates dashboard-only key issuance." (the new section above covers it).
- Replace step 1's "Sign in with an admin account" with persona-neutral "Sign in" wording.
- Drop the trailing paragraph "If your integration requires automated key provisioning … no roadmap commitment to a programmatic mint endpoint; webhooks, OAuth, and client credentials are out of scope for v1." (the v2 escape valve now lives in "Where keys come from").

Preserve the `{#mint-your-first-api-key}` anchor — it's referenced from quickstart, postman, and getting-started.

- Verify: `grep -rn '#mint-your-first-api-key' docs/` still resolves to a real anchor.
- Verify: `pnpm build` — no broken anchors.
- Commit: `docs(auth): add "Where keys come from" lead with SPA-first framing (TRA-590 W1)`

## Step 4 — `docs/api/quickstart.mdx` — collapse Mint + Verify

Delete current `## 2. Mint an API key` (lines ~30–44). Rewrite current `## 3. Verify your key works` as new `## 2. Verify your key works`, opening with a brief mint preamble:

> If you don't already have an API key, log into the SPA at `<EnvBaseURL />` and mint one from the **avatar menu → API Keys → New Key**. The token is shown once at creation — copy it immediately. Full detail: [Authentication → Mint your first API key](./authentication#mint-your-first-api-key).

The existing `/orgs/me` curl block + W2 API-key-vs-session-JWT note + 401 troubleshooting all stay (preserves TRA-584 W2 work).

The TL;DR paragraph at the top (line 16) updates: drop "mint a JWT from the avatar menu, send it as Authorization: Bearer <jwt>" prescription; replace with "you've already minted a key in the SPA — send it as Authorization: Bearer, hit `$BASE_URL/api/v1/...`, and the rest of this page walks the round-trip."

Renumber `## 4. Round-trip` → `## 3. Round-trip`, `## 5. Postman` → `## 4. Alternative: Postman`, `## 6. Raw spec` → `## 5. Raw spec for codegen`. Fold the round-trip scope-needs note ("you'll need `assets:read` and `assets:write`") into either the new step 2 preamble or the round-trip section intro so it isn't lost.

- Verify: `pnpm build` — no broken section anchors.
- Verify: render the page locally and walk through each numbered step.
- Commit: `docs(quickstart): collapse mint+verify, lead with "you have a key" (TRA-590 W1)`

## Step 5 — `docs/getting-started/api.mdx` — same reframe

Delete current `## 2. Mint your first API key` (lines ~34–47). Rewrite current `## 3. Make your first call` as new `## 2. Make your first call` with the same brief mint preamble pointing to Authentication.

Tighten the "What you'll need" preamble — the bullet currently reads "A TrakRF account. If you were given preview credentials, you already have one — skip to step 1. Otherwise sign up at the … app." Make the SPA-first flow explicit: "A TrakRF account and an API key. Sign in (or sign up) at the … app, then mint a key from the avatar menu (API Keys → New Key)."

Renumber `## 4. Interpret the response` → `## 3. Interpret the response`, `## 5. Next steps` → `## 4. Next steps`.

Persona-neutral phrasing throughout — no "your administrator," no "if you were invited."

- Verify: `pnpm build` — no broken anchors.
- Commit: `docs(getting-started): SPA-first reframe of API track (TRA-590 W1)`

## Step 6 — `docs/api/private-endpoints.md` — drop api-keys cluster

Remove three table rows from the Endpoint list:

```
| /api/v1/orgs/{id}/api-keys             | POST, GET | SPA avatar menu → API Keys | Internal | Internal |
| /api/v1/orgs/{id}/api-keys/{key_id}    | DELETE    | SPA avatar menu → API Keys | Internal | Internal |
| /api/v1/orgs/{id}/api-keys/by-jti/{jti}| DELETE    | SPA avatar menu → API Keys | Internal | Internal |
```

No other changes to the file. The `## Programmatic access` lead, the `## Response shape: /orgs/me` section, and the `## Classification policy` section all stay unchanged.

- Verify: `git grep '/orgs/{id}/api-keys' docs/` returns no public-doc hits.
- Verify: `pnpm build`.
- Commit: `docs(private-endpoints): drop api-keys cluster from public-docs surface (TRA-590 W1)`

## Step 7 — Final verification + PR

- `pnpm build` — production build clean.
- `pnpm lint` — prettier clean. If touched files need format pass, commit as `style: prettier on TRA-590 touched files`.
- Manual local-server walk: `/docs/api/authentication`, `/docs/api/quickstart`, `/docs/getting-started/api`, `/docs/api/private-endpoints`. Click every inbound `#mint-your-first-api-key` link from postman, quickstart, getting-started, confirm they resolve.
- Push branch, open PR against `main`. PR description references TRA-590 and the BB16 W1 finding.
