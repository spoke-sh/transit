import { copyFileSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import type { Config } from "@docusaurus/types";
import type { Options, ThemeConfig } from "@docusaurus/preset-classic";
import { pages } from "./catalog";
import { pageContent, repository, repositoryLinks } from "./lib/content";
import { specifications } from "./lib/specs";

const root = path.resolve(__dirname, "../..");
const baseUrl = process.env.TRANSIT_DOCS_BASE_URL ?? "/";
if (!/^\/(?:[A-Za-z0-9_-]+\/)*$/.test(baseUrl))
  throw new Error("TRANSIT_DOCS_BASE_URL must start and end with / and contain path segments only");
const generated = path.join(__dirname, ".generated/static");
mkdirSync(path.join(generated, "specs"), { recursive: true });
for (const spec of specifications)
  copyFileSync(path.join(root, spec.source), path.join(generated, "specs", spec.name));
writeFileSync(
  path.join(generated, "search-index.json"),
  JSON.stringify(
    pages.map((page) => ({
      title: page.label,
      route: page.route,
      text: pageContent(root, page.source)
        .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
        .replace(/[#*`|]/g, "")
        .replace(/\s+/g, " "),
    })),
  ),
);

const config: Config = {
  title: "Transit",
  tagline: "Build on durable state.",
  url: process.env.TRANSIT_DOCS_URL ?? "http://localhost:3000",
  baseUrl,
  favicon: "img/transit.svg",
  trailingSlash: false,
  onBrokenLinks: "throw",
  onBrokenAnchors: "throw",
  staticDirectories: ["static", generated],
  markdown: {
    format: "md",
    mermaid: true,
    hooks: { onBrokenMarkdownLinks: "throw", onBrokenMarkdownImages: "throw" },
    parseFrontMatter: async (params) => {
      const parsed = await params.defaultParseFrontMatter(params);
      const source = path.relative(root, params.filePath).split(path.sep).join("/");
      const page = pages.find((entry) => entry.source === source);
      if (page)
        Object.assign(parsed.frontMatter, {
          slug: `/${page.route}`,
          title: page.label,
          custom_edit_url: `${repository}/edit/main/${source}`,
        });
      return parsed;
    },
    preprocessor: ({ filePath, fileContent }) => {
      const source = path.relative(root, filePath).split(path.sep).join("/");
      return specifications.some((entry) => entry.page === source)
        ? pageContent(root, source)
        : fileContent;
    },
  },
  themes: ["@docusaurus/theme-mermaid"],
  presets: [
    [
      "classic",
      {
        docs: {
          path: root,
          include: pages.map((page) => page.source),
          exclude: [],
          routeBasePath: "/",
          sidebarPath: "./sidebars.ts",
          beforeDefaultRemarkPlugins: [[repositoryLinks, { root, baseUrl }]],
        },
        blog: false,
        theme: { customCss: "./src/css/custom.css" },
      } satisfies Options,
    ],
  ],
  themeConfig: {
    image: "img/transit.svg",
    navbar: {
      title: "TRANSIT",
      logo: { alt: "", src: "img/transit.svg", width: 28, height: 28 },
      items: [
        { to: "/guides/introduction", label: "Documentation", position: "left" },
        { to: "/reference/cli", label: "CLI", position: "left" },
        { to: "/reference/sql", label: "SQL", position: "left" },
        { to: "/reference/sdks", label: "SDKs", position: "left" },
        { to: "/internals", label: "Internals", position: "left" },
        { to: "/search", label: "Search", position: "right" },
        { href: repository, label: "GitHub", position: "right" },
      ],
    },
    footer: { style: "light", copyright: "Transit · Durable processes and state." },
    colorMode: { respectPrefersColorScheme: true },
    tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
    prism: { additionalLanguages: ["bash", "json", "sql", "python", "rust", "toml", "zig"] },
  } satisfies ThemeConfig,
};
export default config;
