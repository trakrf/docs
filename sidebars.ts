import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  userGuideSidebar: [
    {
      type: "category",
      label: "Getting started",
      link: { type: "doc", id: "getting-started/index" },
      items: ["getting-started/ui", "getting-started/api"],
    },
    {
      type: "category",
      label: "User Guide",
      items: [
        "user-guide/reader-setup",
        "user-guide/asset-management",
        "user-guide/location-tracking",
        "user-guide/reports-exports",
        "user-guide/organization-management",
      ],
    },
  ],
  appTourSidebar: [
    "app-tour/index",
    "app-tour/scan",
    "app-tour/locate",
    "app-tour/assets",
    "app-tour/locations",
    "app-tour/reports",
    {
      type: "category",
      label: "Settings",
      link: { type: "doc", id: "app-tour/settings" },
      items: [
        "app-tour/readers",
        "app-tour/live-reads",
        "app-tour/outputs",
        "app-tour/geofence-defaults",
      ],
    },
    "app-tour/help",
    "app-tour/authoring",
  ],
  apiSidebar: [
    {
      type: "category",
      label: "API Documentation",
      link: { type: "doc", id: "api/README" },
      items: [
        "api/quickstart",
        "api/authentication",
        "api/resource-identifiers",
        "api/data-model",
        "api/id-format",
        "api/date-fields",
        "api/pagination-filtering-sorting",
        "api/errors",
        "api/http-method-coverage",
        "api/rate-limits",
        "api/webhooks",
        "api/design-notes",
        "api/versioning",
        "api/changelog",
        "api/postman",
        "api/private-endpoints",
      ],
    },
  ],
  integrationsSidebar: [
    "integrations/index",
    {
      type: "category",
      label: "Integration Guides",
      items: [
        "integrations/mqtt-message-format",
        "integrations/fixed-reader-setup",
      ],
    },
  ],
};

export default sidebars;
