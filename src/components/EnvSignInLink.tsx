import type { ReactNode } from "react";
import { useDeployEnv } from "@site/src/hooks/useDeployEnv";

type Props = { children: ReactNode };

/** Anchor to the env-appropriate app host. Children are the link text. */
export default function EnvSignInLink({ children }: Props): ReactNode {
  const { appHost } = useDeployEnv();
  return (
    <a href={appHost} target="_blank" rel="noreferrer">
      {children}
    </a>
  );
}
