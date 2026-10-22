import type { SidebarsConfig } from "@docusaurus/plugin-content-docs";
import { sections, docId, type Section } from "./catalog";

import { sdkSections } from "./sdk-catalog";
import { internalsSections } from "./internals-catalog";

const categories = (entries: Section[]): Extract<SidebarsConfig[string], unknown[]> =>
  entries.map((section) => ({
    type: "category",
    label: section.label,
    collapsed: true,
    items: section.pages.map((entry) => ({ type: "doc", id: docId(entry), label: entry.label })),
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
