// Cloudflare Pages Functions middleware.
//
// Four jobs:
//
// 1. Spec asset redirects. /api/openapi.{json,yaml} 302 to the platform's
//    canonical spec URL on app.{env}.trakrf.id. Single source of truth lives
//    on the platform; docs.trakrf.id never serves a mirrored spec body. The
//    target host is derived from the docs hostname so previews stay on
//    preview and prod stays on prod.
//
// 2. Legacy/alias 301s. Older callers hit five variant paths for the spec
//    (see REWRITE_MAP below). All collapse to /api/openapi.{json,yaml},
//    which then redirects out via job (1).
//
// 3. Explicit 410 Gone for retired mirror artifacts. `platform-meta.json`
//    and the bundled Postman collection were deleted in TRA-743 but
//    Cloudflare's edge cache may keep serving the last-deploy 200 for the
//    TTL window. Returning an authoritative 410 with `Cache-Control:
//    no-store` displaces the stale entry on next request and prevents any
//    BB cycle from treating the stale body as ground truth.
//
// 4. Docs-page sibling redirects. Spec-emitted URLs of the form
//    /api/<page> mirror their canonical Docusaurus location at
//    /docs/api/<page>; see DOCS_PAGE_REDIRECTS. A reader who follows
//    /api/openapi.yaml at the docs origin (and gets the 302 above)
//    rationally expects sibling /api/<page> paths to resolve similarly.
//
// History note: redirects used to live in static/_redirects, but Cloudflare
// Pages on this project does not appear to honor _redirects entries — the
// original /redocusaurus/trakrf-api.yaml rule (TRA-598) was never actually
// firing, and adding four more entries in TRA-694 produced the same silent-
// no-op behavior. Pages Functions runs in the Workers runtime ahead of
// static-asset serving and is config-independent, so the redirects live
// here instead.

/** @type {Record<string, "json" | "yaml">} */
const SPEC_TARGETS = {
  "/api/openapi.json": "json",
  "/api/openapi.yaml": "yaml",
};

/** @type {Record<string, string>} */
const REWRITE_MAP = {
  "/api/v1/openapi.json": "/api/openapi.json",
  "/api/v1/openapi.yaml": "/api/openapi.yaml",
  "/openapi.json": "/api/openapi.json",
  "/openapi.yaml": "/api/openapi.yaml",
  "/redocusaurus/trakrf-api.yaml": "/api/openapi.yaml",
};

/** Retired mirror artifacts — return 410 Gone with no-store to displace
 *  any stale CF-edge-cached 200 responses from the pre-TRA-743 deploy. */
const RETIRED_PATHS = new Set([
  "/api/platform-meta.json",
  "/api/trakrf-api.postman_collection.json",
]);

/** Same-origin 302 redirects for /api/<page> → /docs/api/<page>.
 *  The spec's info.description names canonical Docusaurus locations under
 *  /docs/api/; these redirects catch readers who trim the prefix by analogy
 *  with the /api/openapi.{json,yaml} aliases above. */
/** @type {Record<string, string>} */
const DOCS_PAGE_REDIRECTS = {
  "/api/http-method-coverage": "/docs/api/http-method-coverage",
};

/** @param {URL} url */
function resolveAppOrigin(url) {
  const host = url.hostname;
  if (host === "docs.trakrf.id") return "https://app.trakrf.id";
  if (host === "docs.preview.trakrf.id") return "https://app.preview.trakrf.id";
  // Local dev / preview deploys on *.pages.dev / unknown hostnames: default
  // to preview so dev builds don't accidentally hit prod platform.
  return "https://app.preview.trakrf.id";
}

/** @type {PagesFunction} */
export const onRequest = async ({ request, next }) => {
  const url = new URL(request.url);

  if (RETIRED_PATHS.has(url.pathname)) {
    return new Response(
      `Gone. This artifact was retired in TRA-743 (single-source OpenAPI ` +
        `spec on platform). See https://docs.trakrf.id/docs/api/postman for ` +
        `URL-import guidance.\n`,
      {
        status: 410,
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": "no-store",
        },
      },
    );
  }

  const alias = REWRITE_MAP[url.pathname];
  if (alias) {
    const dest = new URL(alias, url.origin);
    return Response.redirect(dest.toString(), 301);
  }

  const specFormat = SPEC_TARGETS[url.pathname];
  if (specFormat) {
    const appOrigin = resolveAppOrigin(url);
    // Target the platform's canonical path (`/api/openapi.*`); the
    // `/api/v1/openapi.*` form on platform is itself a 301 to the canonical,
    // so naming the intermediate hop would add an extra redirect to every
    // client.
    const dest = `${appOrigin}/api/openapi.${specFormat}`;
    return Response.redirect(dest, 302);
  }

  const docsPage = DOCS_PAGE_REDIRECTS[url.pathname];
  if (docsPage) {
    const dest = new URL(docsPage, url.origin);
    return Response.redirect(dest.toString(), 302);
  }

  return next();
};
