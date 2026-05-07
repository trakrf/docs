---
ticket: TRA-590
parent: TRA-583
date: 2026-05-07
status: design
---

# TRA-590 — BB16 W1 — Reframe Authentication docs around SPA-first onboarding

## Goal

Address BB16 W1 by aligning Authentication and Quickstart docs to the actual onboarding model: the SPA is where TrakRF accounts and keys come from, and docs are job #2 after the SPA has handled identity and credential issuance. Hold the "browser-mediated by design" policy decision; close the docs friction that produced the W1 finding (LLM-driven integrators reverse-engineering `POST /orgs/{id}/api-keys` from the SPA bundle and depending on a contract we explicitly disowned).

**No platform or spec changes** — prose only.

## Background

BB16 W1 reported that the documented onboarding flow had no programmatic path. A developer with only HTTP tools is blocked at step 2, finds `POST /api/v1/orgs/{id}/api-keys` in the SPA bundle, sees it documented as "Internal — subject to change without notice," and depends on a contract we said wouldn't be honored.

The decision is to hold "browser-mediated by design" (Stripe analogy holds — the TrakRF SPA is load-bearing for handheld scanning + history reporting, not a thin admin shell), but address the docs friction. Both realistic onboarding scenarios — solo operator-developer, or developer invited into someone else's org — start with "you are already in the SPA, key in hand, before you open the docs site." The synthetic worst case (developer with only HTTP tools who never sees the SPA) is not the realistic one.

## Approach

Four files change. Each edit is small in surface, but the framing shift is the substance.

### 1. `docs/api/quickstart.mdx` — collapse Mint + Verify

**Current:** Six sections — `1. Pick env`, `2. Mint an API key` (long click-by-click), `3. Verify your key works` (already carries the W2 API-key-vs-JWT note from TRA-584), `4. Round-trip`, `5. Postman`, `6. Raw spec`.

**After:** Five sections. `2. Mint` collapses into the existing `3. Verify`, which becomes the new `2. Verify your key works`. The new section opens with a brief "if you don't already have a key, log into the SPA and mint one from the avatar menu (API Keys → New Key); the token is shown once at creation, save it immediately" preamble, links to Authentication for full detail, then proceeds with the existing `/orgs/me` curl + W2 note unchanged. Round-trip's scope-needs note (`assets:read/write`) folds into the new step's preamble or the round-trip intro so it isn't lost. Sections 4–6 renumber to 3–5.

The TL;DR paragraph at the top updates from "mint a JWT from the avatar menu" to a "you've already minted a key" framing. Persona-neutral — no "your administrator," no "if you're invited" branching.

### 2. `docs/getting-started/api.mdx` — same reframe

The parallel API-track quickstart in Getting Started has the same shape (`1. Pick env`, `2. Mint your first API key`, `3. Make your first call`, `4. Interpret`, `5. Next steps`). Same W1 friction applies, so apply the same fix: collapse `2. Mint` into `3. Make your first call`, with a brief mint preamble pointing at Authentication. New numbering: `1. Pick env`, `2. Make your first call`, `3. Interpret`, `4. Next steps`. The "What you'll need" preamble already references signing up at the SPA — tighten phrasing so SPA-first is unambiguous.

### 3. `docs/api/authentication.md` — add "Where keys come from" lead

Insert a new `## Where keys come from` H2 immediately after the page intro, before `## Mint your first API key`. Content:

> ## Where keys come from
>
> TrakRF API keys are minted from the SPA's **avatar menu → API Keys → New Key**. The token is shown once at creation — save it immediately.
>
> This is by design. We don't offer programmatic key minting because possession of an API-creating API would defeat the trust boundary: any compromised key could be used to mint a more-privileged one. The SPA's session-authenticated mint flow keeps key issuance tied to user identity, consistent with how Stripe gates dashboard-only key issuance.
>
> If you have a use case that genuinely requires programmatic provisioning (per-tenant SaaS automation, CI rigs that need ephemeral keys), [contact us](mailto:support@trakrf.id) — we'll consider it for v2 based on demand.

The existing `## Mint your first API key` section stays (the click-by-click is still useful) but gets tightened: drop the now-redundant "v1 does not provide a programmatic key-mint endpoint — browser-mediated by design, consistent with Stripe" lead sentence (covered above). Drop "with an admin account" → "Sign in" (persona-neutral, ticket explicitly calls this out: action not relationship). Drop the trailing "If your integration requires automated key provisioning … contact us" paragraph (now lives in "Where keys come from" as the v2 escape valve).

The `{#mint-your-first-api-key}` anchor is preserved — quickstart, postman, and getting-started link there.

### 4. `docs/api/private-endpoints.md` — drop the api-keys cluster

Remove these table rows from the Endpoint list:

- `/api/v1/orgs/{id}/api-keys` POST, GET (SPA avatar menu)
- `/api/v1/orgs/{id}/api-keys/{key_id}` DELETE
- `/api/v1/orgs/{id}/api-keys/by-jti/{jti}` DELETE

All three rows are part of one tempting "key management surface" cluster. Removing only the POST would leave the rest visible and still discoverable for an LLM-driven scrape. The endpoints stay in the codebase for the SPA's use; they're not referenced from any public docs page.

Other Internal rows stay (`/auth/login`, `/auth/signup`, `/auth/forgot-password`, `/auth/reset-password`, `/auth/accept-invite`, `/users/me`, `/users/me/current-org`, `/orgs`, `/orgs/{id}`). Those don't represent a forge-your-own-credentials trap in the same way — they're SPA mechanics with no tempting public alternative.

The `## Programmatic access` section above the table is already on-message ("supported credential is an API key issued via the in-app avatar menu → API Keys flow") and stays unchanged. The `## Response shape: /orgs/me` section stays. The `## Classification policy` section stays.

## Verified state (pre-edit)

```
$ grep -n "Mint an API key\|Mint your first API key\|mint-an-api-key\|mint-your-first-api-key" docs/
docs/api/postman.mdx:32:    [Authentication → Mint your first API key](./authentication#mint-your-first-api-key)
docs/api/quickstart.mdx:30:## 2. Mint an API key
docs/api/quickstart.mdx:34:    [Authentication → Mint your first API key](./authentication#mint-your-first-api-key)
docs/api/quickstart.mdx:44:    [Authentication → Mint your first API key](./authentication#mint-your-first-api-key)
docs/getting-started/api.mdx:34:## 2. Mint your first API key
docs/getting-started/api.mdx:38:    ([details](../api/authentication#mint-your-first-api-key))
docs/getting-started/api.mdx:47:    [Authentication → Mint your first API key](../api/authentication#mint-your-first-api-key)
docs/api/authentication.md:9:## Mint your first API key {#mint-your-first-api-key}

# Inbound anchor #mint-your-first-api-key is referenced from postman, quickstart (3x), getting-started/api (2x).
# Anchor MUST be preserved across this work.

$ awk 'NR==32' docs/api/private-endpoints.md
| /api/v1/orgs/{id}/api-keys | POST, GET | SPA avatar menu → API Keys | Internal | Internal |
$ awk 'NR==33' docs/api/private-endpoints.md
| /api/v1/orgs/{id}/api-keys/{key_id} | DELETE | SPA avatar menu → API Keys | Internal | Internal |
$ awk 'NR==34' docs/api/private-endpoints.md
| /api/v1/orgs/{id}/api-keys/by-jti/{jti} | DELETE | SPA avatar menu → API Keys | Internal | Internal |
```

## Acceptance mapping (from ticket)

- [x] Quickstart step 1 starts from "you have a key" or "if you don't, here's where" — not "go contact someone." → quickstart.mdx + getting-started/api.mdx new step preamble.
- [x] Quickstart step 1 mentions API-key-vs-session-JWT (folds in W2). → preserved from TRA-584 work, carried into the renumbered section.
- [x] Authentication page leads with "Where keys come from" framing browser-mediated minting as deliberate policy. → new section above existing "Mint your first API key."
- [x] Authentication page mentions v2 / programmatic-provisioning escape valve. → trailing paragraph of new section.
- [x] Phrasing describes actions, not relationships. → "Sign in" replaces "Sign in with an admin account" in Authentication; quickstart preamble omits relationship terms.
- [x] `private-endpoints.md` no longer references `POST /api/v1/orgs/{id}/api-keys` as Internal. → all 3 api-keys rows removed.
- [x] Single docs PR; coordinated with TRA-584. → TRA-584 is already merged; this builds on its `/orgs/me` API-key note rather than re-doing it.

## Out of scope

- Reversing "browser-mediated by design." Held.
- Adding `POST /api/v1/orgs/{id}/api-keys` to the public spec.
- Restructuring the Authentication page beyond the new lead section + tightening the existing Mint section's redundant lead/trailing paragraph.
- Screenshots / annotated SPA walkthrough.
- Documenting the org invite flow.
- BB.md prompt reshape (TRA-591).

## Files

| File                            | Change                                                                                                                                                                                                                                                   |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/api/quickstart.mdx`       | Collapse `## 2. Mint` into `## 3. Verify`, becoming the new `## 2. Verify your key works`. Renumber 4–6 → 3–5. Update TL;DR paragraph. Persona-neutral phrasing.                                                                                         |
| `docs/getting-started/api.mdx`  | Collapse `## 2. Mint` into `## 3. Make your first call`, becoming the new `## 2. Make your first call`. Renumber 4–5 → 3–4. Tighten the "What you'll need" preamble.                                                                                     |
| `docs/api/authentication.md`    | Insert `## Where keys come from` after the page intro, before `## Mint your first API key`. Tighten existing `## Mint…` (drop redundant lead sentence + trailing v2 paragraph + persona-neutral phrasing). Preserve `{#mint-your-first-api-key}` anchor. |
| `docs/api/private-endpoints.md` | Remove all 3 api-keys table rows (POST/GET, DELETE by key_id, DELETE by jti). No other changes.                                                                                                                                                          |

## Verification plan

- `pnpm build` succeeds.
- `pnpm lint` clean (prettier).
- Manually verify on local dev server:
  - `/docs/api/authentication` renders the new "Where keys come from" section as the first H2 after the intro; existing scopes/lifecycle/base-URL sections unchanged.
  - `/docs/api/quickstart` renders 5 numbered sections with no broken anchors.
  - `/docs/getting-started/api` renders 4 numbered sections.
  - `/docs/api/private-endpoints` table no longer lists api-keys rows; remaining Internal rows still render.
  - All inbound `#mint-your-first-api-key` links resolve.
