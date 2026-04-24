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
    "app-tour/home",
    "app-tour/inventory",
    "app-tour/locate",
    "app-tour/barcode",
    "app-tour/assets",
    "app-tour/locations",
    "app-tour/reports",
    "app-tour/settings",
    "app-tour/help",
    "app-tour/AUTHORING",
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
        "api/date-fields",
        "api/pagination-filtering-sorting",
        "api/errors",
        "api/rate-limits",
        "api/versioning",
        "api/CHANGELOG",
        "api/webhooks",
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
