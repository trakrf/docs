import type { ReactNode } from "react";
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

/** Inline span rendering the env-appropriate app host, e.g. https://app.preview.trakrf.id */
export default function EnvBaseURL(): ReactNode {
  const { appHost } = useDeployEnv();
  return <code>{appHost}</code>;
}
