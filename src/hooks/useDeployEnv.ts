import { useSyncExternalStore } from "react";

/**
 * Environment detected from the docs hostname, with localStorage override.
 *
 * Resolution order:
 *   1. localStorage["trakrf-env"] if set to "production" or "preview"
 *   2. Parse window.location.hostname: strip leading "docs.", prepend "app."
 *      (docs.trakrf.id → app.trakrf.id; docs.preview.trakrf.id → app.preview.trakrf.id)
 *   3. SSR / non-matching hostname (e.g. localhost): fall back to production
 *
 * The hook listens on cross-tab storage events and an in-page custom event so
 * every consumer stays in sync when the user flips the EnvSwitcher.
 */
export type DeployEnvLabel = "production" | "preview";

export type DeployEnv = {
  /** Full origin, e.g. "https://app.preview.trakrf.id" */
  appHost: string;
  /** "production" | "preview" */
  envLabel: DeployEnvLabel;
  /** The localStorage override, or null if auto-detecting */
  override: DeployEnvLabel | null;
  /** Persist an override and notify other hook instances */
  setOverride: (env: DeployEnvLabel) => void;
  /** Clear the override, returning to auto-detect */
  clearOverride: () => void;
};

const STORAGE_KEY = "trakrf-env";
const CHANGE_EVENT = "trakrf-env-change";

const PROD_HOST = "https://app.trakrf.id";
const PREVIEW_HOST = "https://app.preview.trakrf.id";

function readOverride(): DeployEnvLabel | null {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (raw === "production" || raw === "preview") return raw;
  return null;
}

function detectFromHostname(): DeployEnvLabel {
  if (typeof window === "undefined") return "production";
  const host = window.location.hostname;
  // docs.preview.trakrf.id → preview; docs.trakrf.id → production.
  // localhost or any non-matching host → production (sensible dev default).
  if (host.startsWith("docs.preview.")) return "preview";
  return "production";
}

function getSnapshot(): DeployEnvLabel {
  return readOverride() ?? detectFromHostname();
}

function getServerSnapshot(): DeployEnvLabel {
  return "production";
}

function subscribe(callback: () => void): () => void {
  const onStorage = (e: StorageEvent) => {
    if (e.key === STORAGE_KEY || e.key === null) callback();
  };
  const onCustom = () => callback();
  window.addEventListener("storage", onStorage);
  window.addEventListener(CHANGE_EVENT, onCustom);
  return () => {
    window.removeEventListener("storage", onStorage);
    window.removeEventListener(CHANGE_EVENT, onCustom);
  };
}

export function useDeployEnv(): DeployEnv {
  const envLabel = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot,
  );

  const appHost = envLabel === "preview" ? PREVIEW_HOST : PROD_HOST;
  const override = readOverride();

  const setOverride = (env: DeployEnvLabel) => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(STORAGE_KEY, env);
    window.dispatchEvent(new Event(CHANGE_EVENT));
  };

  const clearOverride = () => {
    if (typeof window === "undefined") return;
    window.localStorage.removeItem(STORAGE_KEY);
    window.dispatchEvent(new Event(CHANGE_EVENT));
  };

  return { appHost, envLabel, override, setOverride, clearOverride };
}
