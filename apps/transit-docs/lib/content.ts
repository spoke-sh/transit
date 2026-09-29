import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import type { Root } from "mdast";
import { visit } from "unist-util-visit";
import { pages } from "../catalog";
import { readSpecification, renderSpecification, specifications } from "./specs";

export const repository = "https://github.com/rupurt/rey";
export function pageContent(root: string, source: string): string {
  let text = readFileSync(path.join(root, source), "utf8");
  const spec = specifications.find((entry) => entry.page === source);
  if (spec) text += renderSpecification(readSpecification(root, spec.source));
  return text;
}

export function resolveLink(root: string, source: string, url: string, baseUrl: string): string {
  if (/^(?:[a-z][a-z\d+.-]*:|\/|#)/i.test(url)) return url;
  const [file, fragment] = url.split("#", 2);
  let target = path.resolve(root, path.dirname(source), decodeURIComponent(file!));
  if (!existsSync(target)) throw new Error(`${source}: missing link ${url}`);
  if (!target.startsWith(root + path.sep))
    throw new Error(`${source}: link escapes repository: ${url}`);
  if (existsSync(path.join(target, "README.md"))) target = path.join(target, "README.md");
  const relative = path.relative(root, target).split(path.sep).join("/");
  const suffix = fragment ? `#${fragment}` : "";
  const page = pages.find((entry) => entry.source === relative);
  if (page) return `${baseUrl}${page.route}${suffix}`;
  const spec = specifications.find((entry) => entry.source === relative);
  // Downloads are files, not React-router pages. Docusaurus's pathname scheme
  // keeps ordinary navigation and base-path handling for these verified assets.
  if (spec) return `pathname://${baseUrl}specs/${spec.name}${suffix}`;
  return `${repository}/blob/main/${relative}${suffix}`;
}

export function repositoryLinks(options: { root: string; baseUrl: string }) {
  return (tree: Root, file: { path: string }): void => {
    const source = path.relative(options.root, file.path).split(path.sep).join("/");
    visit(tree, ["link", "definition"], (node) => {
      if (node.type === "link" || node.type === "definition")
        node.url = resolveLink(options.root, source, node.url, options.baseUrl);
    });
  };
}
