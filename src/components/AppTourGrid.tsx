import type { ReactNode } from "react";
import Link from "@docusaurus/Link";
import styles from "./AppTourGrid.module.css";

interface TourEntry {
  id: string;
  title: string;
  description: string;
}

const ENTRIES: TourEntry[] = [
  {
    id: "scan",
    title: "Scan",
    description:
      "Read RFID tags or barcodes and reconcile them against a list.",
  },
  {
    id: "locate",
    title: "Locate",
    description:
      "Find a specific item by walking the area with a handheld reader.",
  },
  {
    id: "assets",
    title: "Assets",
    description: "Create, view, and track asset records.",
  },
  {
    id: "locations",
    title: "Locations",
    description: "Create and organize the places where assets live.",
  },
  {
    id: "reports",
    title: "Reports",
    description: "View asset location reports and movement history.",
  },
  {
    id: "settings",
    title: "Settings",
    description: "Configure device and application settings.",
  },
  {
    id: "readers",
    title: "Readers",
    description: "Register and manage fixed RFID readers.",
  },
  {
    id: "live-feed",
    title: "Live feed",
    description: "Watch tag reads arrive in real time.",
  },
  {
    id: "outputs",
    title: "Outputs",
    description: "Configure output devices triggered by geofence events.",
  },
  {
    id: "geofence-defaults",
    title: "Geofence defaults",
    description: "Org-wide geofence tuning applied to every portal.",
  },
  {
    id: "help",
    title: "Help",
    description: "Quick answers to common questions.",
  },
];

export default function AppTourGrid(): ReactNode {
  return (
    <div className={styles.grid}>
      {ENTRIES.map((entry) => (
        <Link
          key={entry.id}
          to={`/docs/app-tour/${entry.id}`}
          className={styles.card}
        >
          <img
            src={`/img/app-tour/${entry.id}-desktop.png`}
            alt={`${entry.title} screenshot`}
            className={styles.thumbnail}
          />
          <div className={styles.body}>
            <h3 className={styles.title}>{entry.title}</h3>
            <p className={styles.description}>{entry.description}</p>
          </div>
        </Link>
      ))}
    </div>
  );
}
