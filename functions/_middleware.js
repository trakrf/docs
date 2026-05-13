// Cloudflare Pages Functions middleware for canonical OpenAPI spec URL.
//
// Every request hits this middleware first. If the path is one of the
// five legacy/alias forms for the OpenAPI spec, we 301 to the canonical
// /api/openapi.{json,yaml}. Otherwise pass through to static-asset
// serving.
//
// History note: this used to live in static/_redirects, but Cloudflare
// Pages on this project does not appear to honor _redirects entries —
// the original /redocusaurus/trakrf-api.yaml rule (TRA-598) was never
// actually firing, and adding four more entries in TRA-694 produced the
// same silent-no-op behavior. Pages Functions runs in the Workers
// runtime ahead of static-asset serving and is config-independent, so
// the redirects move here.

/** @type {Record<string, string>} */
const REDIRECT_MAP = {
  "/api/v1/openapi.json": "/api/openapi.json",
  "/api/v1/openapi.yaml": "/api/openapi.yaml",
  "/openapi.json": "/api/openapi.json",
  "/openapi.yaml": "/api/openapi.yaml",
  "/redocusaurus/trakrf-api.yaml": "/api/openapi.yaml",
};

/** @type {PagesFunction} */
export const onRequest = async ({ request, next }) => {
  const url = new URL(request.url);
  const target = REDIRECT_MAP[url.pathname];
  if (target) {
    const dest = new URL(target, url.origin);
    return Response.redirect(dest.toString(), 301);
  }
  return next();
};
