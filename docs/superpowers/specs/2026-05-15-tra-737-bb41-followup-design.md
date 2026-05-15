# TRA-737 — BB41 docs follow-up

## Source

`FINDINGS.md` attached to [TRA-737](https://linear.app/trakrf/issue/TRA-737/api-v1-bb41-test-findings). BB41 black-box run against preview at `docs.commit=cf42657` / `platform.commit=8420660` (2026-05-15).

## Disposition summary

| # | Subject | Finding disposition | Action this PR |
| --- | --- | --- | --- |
| F1 | `openapi-fetch` (TS) doesn't auto-detect `application/merge-patch+json`; every PATCH 415s on first try | hygiene; defer | **Ship a discoverability fix** — add a tip in quickstart §3 pointing TS readers to the existing §5.1 middleware |
| F2 | Pydantic `datamodel-codegen` drops `nullable: true` | confirms `BACKLOG.md` "OpenAPI 3.1 migration" + `design-notes.md` "Nullable fields…" | none — verified |
| F3 | Pydantic emits `TagType`/`TagType2`/`TagType4` per-variant enums | confirms `design-notes.md` "Tag schema uses three single-value enums…" | none — verified |
| F4 | HEAD supported on every GET; spec deliberately omits it | confirms `design-notes.md` "HEAD method not declared…" | none — verified |
| F5 | `descendant_count_affected: 0` on asset rename | confirms `design-notes.md` "`descendant_count_affected` on `RenameAssetResponse`…" (shipped in TRA-736 F5, `cf42657`) | none — verified |
| F6 | `metadata` PATCH replaces wholesale | confirms `resource-identifiers.md#metadata-opaque` | none — verified |
| F7 | `id` is int64 on wire, int32 runtime | confirms `id-format.md` + `BACKLOG.md` "Bigint storage migration" | none — verified |

## F1 — what the gap actually is

The substantive fix shipped in TRA-718 (`833446d`) / TRA-716 (`e2d6de8`): `docs/api/quickstart.mdx` §5.1 "TypeScript with `openapi-fetch`" documents the 415 trap and provides a copyable middleware (`mergePatchMiddleware`) plus a `createTrakrfClient` wrapper. The platform-side reference file at `trakrf/platform:docs/codegen/typescript/merge-patch.ts` is in place.

The BB41 tester ran cleanly against §3's curl walkthrough first, then translated those calls to `openapi-fetch` in a smoke script before reaching §5. The 415 hit in their §10 codegen test reflects that ordering: §5.1 exists, but isn't surfaced where a TS reader is most likely to write their first PATCH.

The finding text already names the fix: *"a short note in the quickstart's 'Step 3 — Update'"*.

## Change

Add a single `:::tip` admonition in `docs/api/quickstart.mdx` §3, immediately after the curl create/read/update/delete block, cross-linking to the existing `#openapi-fetch` anchor in §5. Wording follows TrakRF's existing prose style — concise, names the failure mode, links to the canonical fix.

```mdx
:::tip TypeScript with `openapi-fetch`?
`openapi-fetch` is schema-agnostic at runtime — it won't read `application/merge-patch+json` from the spec, and every `PATCH` returns `415 unsupported_media_type` unless you override `Content-Type` per call or register a middleware. See [§5 — TypeScript with `openapi-fetch`](#openapi-fetch) below for the drop-in middleware that handles every `PATCH` site automatically.
:::
```

Plus a one-bullet BB41 entry in `docs/api/changelog.md` recording the cross-reference (pre-launch docs-only; no wire change).

## Out of scope

- Platform changes — none needed; F1 is purely a docs discoverability nit and F2–F7 are confirmations of existing design notes.
- Reflowing the existing §5.1 prose — already concise and complete.
- Adding TS-specific notes to `docs/getting-started/api.mdx` — that page stops at "verify your key works" and explicitly hands off to the API Quickstart for PATCH/update content (line 66).
- Touching `design-notes.md`, `id-format.md`, `resource-identifiers.md`, `BACKLOG.md` — all F2–F7 references are accurate, current, and load-bearing as-is.

## Verification

- `pnpm build` (Docusaurus build catches MDX/link errors).
- Manual: serve the build, confirm the §3 tip renders, and confirm the `#openapi-fetch` anchor resolves to §5.1.
