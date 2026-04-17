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
    id: "home",
    title: "Home",
    description: "Main dashboard with quick access to all features.",
  },
  {
    id: "inventory",
    title: "Inventory",
    description: "View scanned items and check what's missing from a list.",
  },
  {
    id: "locate",
    title: "Locate",
    description:
      "Find a specific item by walking the area with a handheld reader.",
  },
  {
    id: "barcode",
    title: "Barcode",
    description: "Use a phone camera to scan regular barcodes.",
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
