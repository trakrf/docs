import type { ReactNode } from "react";
import platformMeta from "@site/static/api/platform-meta.json";

type PlatformMeta = {
  commit: string;
  source_url: string;
  spec_refreshed_at: string;
};

function formatTimestamp(iso: string): string {
  // 2026-05-13T13:24:08Z → 2026-05-13 13:24 UTC
  const trimmed = iso.replace(/:\d{2}Z$/, " UTC").replace("T", " ");
  return trimmed;
}

/**
 * Inline badge naming the platform commit the published OpenAPI spec was
 * mirrored from. Reads static/api/platform-meta.json at build time
 * (written by scripts/refresh-openapi.sh) so the rendered value is
 * deterministic per docs build, not refreshed on page load.
 *
 * Surface chosen for TRA-695: any BB session, integrator, or reviewer
 * who suspects a spec/service mismatch can attribute it to a platform
 * commit in seconds rather than reconstructing the timeline from logs.
 */
export default function SpecMirrorBadge(): ReactNode {
  const { commit, source_url, spec_refreshed_at } =
    platformMeta as PlatformMeta;
  return (
    <span>
      Spec mirrored from{" "}
      <a href={source_url}>
        <code>trakrf/platform@{commit}</code>
      </a>{" "}
      at <code>{formatTimestamp(spec_refreshed_at)}</code>.
    </span>
  );
}
