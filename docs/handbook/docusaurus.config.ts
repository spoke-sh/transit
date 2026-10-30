import { copyFileSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import type { Config } from "@docusaurus/types";
import type { Options, ThemeConfig } from "@docusaurus/preset-classic";
import { pages } from "./catalog";
import { pageContent, repository, repositoryLinks } from "./lib/content";
import { specifications } from "./lib/specs";
import { downloads } from "./lib/downloads";

const root = path.resolve(__dirname, "../..");
const url = process.env.TRANSIT_DOCS_URL ?? "https://spoke-sh.github.io";
const baseUrl = process.env.TRANSIT_DOCS_BASE_URL ?? "/transit/";
const revision = process.env.TRANSIT_DOCS_REVISION ?? "main";
if (revision !== "main" && !/^[0-9a-f]{40}$/.test(revision))
  throw new Error("TRANSIT_DOCS_REVISION must be main or a full Git commit");
if (!/^\/(?:[A-Za-z0-9_-]+\/)*$/.test(baseUrl))
  throw new Error("TRANSIT_DOCS_BASE_URL must start and end with / and contain path segments only");
const generated = path.join(__dirname, ".generated/static");
mkdirSync(path.join(generated, "specs"), { recursive: true });
for (const spec of downloads)
  copyFileSync(path.join(root, spec.source), path.join(generated, "specs", spec.name));
writeFileSync(
  path.join(generated, "robots.txt"),
  `User-agent: *\nAllow: /\nSitemap: ${new URL(`${baseUrl}sitemap.xml`, url).href}\n`,
);
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
  tagline:
    "Declarative multi-model database, vectorized/incremental query engine (Fuze), and durable execution runtime (Station).",
  url,
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
          custom_edit_url: `${repository}/${revision === "main" ? "edit" : "blob"}/${revision}/${source}`,
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
          beforeDefaultRemarkPlugins: [[repositoryLinks, { root, baseUrl, revision }]],
        },
        blog: false,
        theme: { customCss: "./src/css/custom.css" },
      } satisfies Options,
    ],
  ],
  themeConfig: {
    image: "img/refraction-social.jpg",
    metadata: [
      { property: "og:image:width", content: "1200" },
      { property: "og:image:height", content: "630" },
      {
        property: "og:image:alt",
        content:
          "A measured score becomes waves, branching upward into graphite terrain and downward into translucent planes, joined by a vermilion thread.",
      },
      {
        name: "twitter:image:alt",
        content:
          "A measured score becomes waves, branching upward into graphite terrain and downward into translucent planes, joined by a vermilion thread.",
      },
    ],
    navbar: {
      title: "TRANSIT",
      logo: { alt: "", src: "img/transit.svg", width: 28, height: 28 },
      items: [
        { to: "/guides/introduction", label: "Documentation", position: "left" },
        { to: "/reference/data-model", label: "Data model", position: "left" },
        { to: "/reference/cli", label: "CLI", position: "left" },
        { to: "/reference/sql", label: "SQL", position: "left" },
        { to: "/reference/sdks", label: "SDKs", position: "left" },
        { to: "/internals", label: "Internals", position: "left" },
        { to: "/search", label: "Search", position: "right" },
        { href: repository, label: "GitHub", position: "right" },
      ],
    },
    footer: { style: "light", copyright: "Transit · Programmable data infrastructure." },
    colorMode: { respectPrefersColorScheme: true },
    tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
    prism: { additionalLanguages: ["bash", "json", "sql", "python", "rust", "go", "toml", "zig"] },
  } satisfies ThemeConfig,
};
export default config;
