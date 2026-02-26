import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";

const sidebars: SidebarsConfig = {
  userGuideSidebar: [
    "getting-started",
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
  apiSidebar: [
    {
      type: "category",
      label: "API Documentation",
      items: [
        "api/authentication",
        "api/rest-api-reference",
        "api/webhooks",
        "api/rate-limits",
        "api/error-codes",
      ],
    },
  ],
  integrationsSidebar: [
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
