// Cloudflare Pages Functions middleware.
//
// Two jobs:
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

  const alias = REWRITE_MAP[url.pathname];
  if (alias) {
    const dest = new URL(alias, url.origin);
    return Response.redirect(dest.toString(), 301);
  }

  const specFormat = SPEC_TARGETS[url.pathname];
  if (specFormat) {
    const appOrigin = resolveAppOrigin(url);
    const dest = `${appOrigin}/api/v1/openapi.${specFormat}`;
    return Response.redirect(dest, 302);
  }

  return next();
};
