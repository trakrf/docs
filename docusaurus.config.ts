import { themes as prismThemes } from "prism-react-renderer";
import type { Config } from "@docusaurus/types";
import type * as Preset from "@docusaurus/preset-classic";

const config: Config = {
  title: "TrakRF Docs",
  tagline: "RFID Asset Tracking Platform",
  favicon: "img/logo.png",

  future: {
    v4: true,
  },

  url: "https://docs.trakrf.id",
  baseUrl: "/",

  onBrokenLinks: "throw",

  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      {
        docs: {
          sidebarPath: "./sidebars.ts",
          editUrl: "https://github.com/trakrf/docs/edit/main/",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
    [
      "redocusaurus",
      {
        specs: [
          {
            id: "trakrf-api",
            spec: "static/api/openapi.public.yaml",
            route: "/api",
          },
        ],
        theme: {
          primaryColor: "#2e8555",
        },
      },
    ],
  ],

  themeConfig: {
    image: "img/logo.png",
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: "TrakRF Docs",
      logo: {
        alt: "TrakRF Logo",
        src: "img/logo.png",
      },
      items: [
        {
          type: "docSidebar",
          sidebarId: "userGuideSidebar",
          position: "left",
          label: "User Guide",
        },
        {
          type: "docSidebar",
          sidebarId: "appTourSidebar",
          position: "left",
          label: "App Tour",
        },
        {
          type: "docSidebar",
          sidebarId: "apiSidebar",
          position: "left",
          label: "API",
        },
        { to: "/api", label: "API Reference", position: "left" },
        {
          type: "docSidebar",
          sidebarId: "integrationsSidebar",
          position: "left",
          label: "Integrations",
        },
        {
          href: "https://github.com/trakrf/docs",
          label: "GitHub",
          position: "right",
        },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Documentation",
          items: [
            {
              label: "Getting Started",
              to: "/docs/getting-started",
            },
            {
              label: "API Reference",
              to: "/docs/api/authentication",
            },
          ],
        },
        {
          title: "TrakRF",
          items: [
            {
              label: "Platform",
              href: "https://trakrf.id",
            },
            {
              label: "GitHub",
              href: "https://github.com/trakrf",
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} DevOps To AI LLC dba TrakRF. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
