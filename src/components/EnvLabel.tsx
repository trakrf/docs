import type { ReactNode } from "react";
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

/** Inline span rendering just "production" or "preview". */
export default function EnvLabel(): ReactNode {
  const { envLabel } = useDeployEnv();
  return <span>{envLabel}</span>;
}
