import type { ReactNode } from "react";
import {
  useDeployEnv,
  type DeployEnvLabel,
} from "@site/src/hooks/useDeployEnv";
import styles from "./EnvSwitcher.module.css";

type SwitcherValue = DeployEnvLabel | "auto";

/**
 * Pill control that shows the currently resolved environment and lets the
 * reader override it (persisted via localStorage). Renders the same label the
 * hook resolves so SSR and hydrated output match.
 */
export default function EnvSwitcher(): ReactNode {
  const { envLabel, override, setOverride, clearOverride } = useDeployEnv();
  const value: SwitcherValue = override ?? "auto";

  const onChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const next = e.target.value as SwitcherValue;
    if (next === "auto") clearOverride();
    else setOverride(next);
  };

  return (
    <span className={styles.switcher}>
      <span className={styles.label}>Environment: {envLabel}</span>
      <select
        className={styles.select}
        value={value}
        onChange={onChange}
        aria-label="Switch docs environment"
      >
        <option value="auto">Auto-detect</option>
        <option value="production">Production</option>
        <option value="preview">Preview</option>
      </select>
    </span>
  );
}
