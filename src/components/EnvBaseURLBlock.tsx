import type { ReactNode } from "react";
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

/**
 * Shell code block that exports BASE_URL for the env-matching app host.
 * Replaces the previous two-block "pick one of these" pattern.
 */
export default function EnvBaseURLBlock(): ReactNode {
  const { appHost } = useDeployEnv();
  return (
    <pre>
      <code>{`export BASE_URL=${appHost}`}</code>
    </pre>
  );
}
