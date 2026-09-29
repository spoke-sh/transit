import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";
import { sections, docId } from "./catalog";

const sidebars: SidebarsConfig = {
  handbook: sections.map((section) => ({
    type: "category",
    label: section.label,
    collapsed: true,
    items: section.pages.map((entry) => ({ type: "doc", id: docId(entry), label: entry.label })),
  })),
};
export default sidebars;
