import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";
import { sections, docId, type Section } from "./catalog";

import { internalsSections } from "./internals-catalog";

const categories = (entries: Section[]): SidebarsConfig[string] =>
  entries.map((section) => ({
    type: "category",
    label: section.label,
    collapsed: true,
    items: section.pages.map((entry) => ({ type: "doc", id: docId(entry), label: entry.label })),
  }));

const sidebars: SidebarsConfig = {
  handbook: categories(sections),
  internals: categories(internalsSections),
};
export default sidebars;
