import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";
import { sections, docId, type Page, type Section } from "./catalog";

import { sdkSections } from "./sdk-catalog";
import { internalsSections } from "./internals-catalog";

const docItems = (entries: Page[]) =>
  entries.map((entry) => ({ type: "doc" as const, id: docId(entry), label: entry.label }));

const categories = (entries: Section[]): Extract<SidebarsConfig[string], unknown[]> =>
  entries.map((section) => ({
    type: "category",
    label: section.label,
    collapsed: true,
    items: section.groups
      ? section.groups.map((group) => ({
          type: "category" as const,
          label: group.label,
          collapsed: false,
          items: docItems(group.pages),
        }))
      : docItems(section.pages),
  }));

const sidebars: SidebarsConfig = {
  handbook: [...categories(sections), { type: "link", label: "SDKs", href: "/reference/sdks" }],
  sdks: [
    ...categories(sdkSections),
    { type: "link", label: "Handbook", href: "/guides/introduction" },
  ],
  internals: categories(internalsSections),
};
export default sidebars;
