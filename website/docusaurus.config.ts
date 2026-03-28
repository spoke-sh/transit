import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const siteUrl = process.env.DOCS_SITE_URL ?? 'https://transit.spoke.sh';
const baseUrl = process.env.DOCS_BASE_URL ?? '/';
const repoUrl = 'https://github.com/spoke-sh/transit';

const config: Config = {
  title: 'Transit',
  tagline: 'Lineage-aware event streaming for embedded runtimes and networked rails',
  favicon: 'img/favicon.svg',
  future: {
    v4: true,
  },
  url: siteUrl,
  baseUrl,
  organizationName: 'spoke-sh',
  projectName: 'transit',
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },
  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: 'docs',
          editUrl: `${repoUrl}/tree/main/website/`,
          showLastUpdateAuthor: false,
          showLastUpdateTime: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],
  themeConfig: {
    image: 'img/transit-social-card.svg',
    colorMode: {
      defaultMode: 'light',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'Transit',
      logo: {
        alt: 'Transit logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          to: '/docs/intro',
          label: 'Docs',
          position: 'left',
        },
        {
          to: '/docs/start-here/embedded-library-first-run',
          label: 'Start Here',
          position: 'left',
        },
        {
          to: '/docs/reference/foundational-docs',
          label: 'Reference',
          position: 'left',
        },
        {
          href: repoUrl,
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Get Oriented',
          items: [
            {
              label: 'Intro',
              to: '/docs/intro',
            },
            {
              label: 'Choose Your Track',
              to: '/docs/start-here/choose-your-track',
            },
            {
              label: 'Library First Run',
              to: '/docs/start-here/embedded-library-first-run',
            },
          ],
        },
        {
          title: 'Concepts',
          items: [
            {
              label: 'Core Model',
              to: '/docs/concepts/core-model',
            },
            {
              label: 'Durability Modes',
              to: '/docs/concepts/durability-modes',
            },
          ],
        },
        {
          title: 'Project',
          items: [
            {
              label: 'GitHub',
              href: repoUrl,
            },
            {
              label: 'Architecture',
              to: '/docs/reference/contracts/architecture',
            },
            {
              label: 'Constitution',
              to: '/docs/reference/contracts/constitution',
            },
            {
              label: 'Foundational Docs',
              to: '/docs/reference/foundational-docs',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Transit contributors.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
