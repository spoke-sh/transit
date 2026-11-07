import { createContext, useContext } from "react";
import Link from "@docusaurus/Link";
import { pages, docId } from "../../catalog";

export const HandbookPageContext = createContext<string | null>(null);
export const useHandbookPage = () => useContext(HandbookPageContext);

export function handbookRoute(id: string): string | null {
  return pages.find((page) => docId(page) === id)?.route ?? null;
}

export function HandbookChapter({ route }: { route: string }) {
  const label = route.startsWith("guides/")
    ? "A field guide"
    : route.startsWith("internals")
      ? "Inside Transit"
      : route.startsWith("sdks/")
        ? "Build in your language"
        : "The working reference";
  return (
    <div className="handbook-chapter" aria-hidden="true">
      <span className="handbook-chapter-mark">
        <i />
        <i />
        <i />
        <i />
        <i />
      </span>
      <span>{label}</span>
    </div>
  );
}

const journeys: Record<string, { label: string; to: string; title: string; detail: string }[]> = {
  "guides/introduction": [
    {
      label: "Build",
      to: "/guides/quickstart",
      title: "Make the first change.",
      detail: "Create a dataset, ask a question, then watch the answer change.",
    },
    {
      label: "Understand",
      to: "/reference/architecture",
      title: "Look beneath the surface.",
      detail: "Follow the boundaries between data, queries, policy and execution.",
    },
  ],
  "guides/quickstart": [
    {
      label: "Explore",
      to: "/reference/data-model",
      title: "Give your application a shape.",
      detail: "Choose its data, computation lifetimes and policies.",
    },
    {
      label: "Build",
      to: "/guides/workload-examples",
      title: "Put the pieces to work.",
      detail: "Follow complete examples across languages and workloads.",
    },
  ],
  "reference/data-model": [
    {
      label: "Build",
      to: "/guides/choose-interface",
      title: "Find your way in.",
      detail: "Match the operation you need to an available interface.",
    },
    {
      label: "Understand",
      to: "/internals/system-model",
      title: "Trace intent to evidence.",
      detail: "Inspect the model behind definitions, versions and outcomes.",
    },
  ],
  "guides/choose-interface": [
    {
      label: "Build",
      to: "/guides/quickstart",
      title: "Start with a working dataset.",
      detail: "Use the local console to define, query and evolve a Table.",
    },
    {
      label: "Explore",
      to: "/reference/sdks",
      title: "Bring your own language.",
      detail: "Find public clients, examples and ownership rules for your application.",
    },
  ],
  "guides/workload-examples": [
    {
      label: "Build",
      to: "/guides/applications",
      title: "Add your application's behavior.",
      detail: "Install a worker and observe its accepted work.",
    },
    {
      label: "Evaluate",
      to: "/reference/verification",
      title: "Examine the evidence.",
      detail: "See which guarantees have been exercised, under which conditions.",
    },
  ],
  "reference/sql": [
    {
      label: "Build",
      to: "/stories/first-dataset",
      title: "Follow a complete example.",
      detail: "See statements alongside the observations they produce.",
    },
    {
      label: "Understand",
      to: "/reference/queries",
      title: "Follow the result's lifetime.",
      detail: "Understand source versions, complete results and recovery.",
    },
  ],
};

export function HandbookNext() {
  const route = useHandbookPage();
  const links = route ? journeys[route] : undefined;
  if (!links) return null;
  return (
    <nav className="handbook-next" aria-label="Continue exploring Transit">
      {links.map((link) => (
        <Link key={link.to} to={link.to}>
          <span className="handbook-label">
            {link.label} <span aria-hidden="true">↗</span>
          </span>
          <strong>{link.title}</strong>
          <span>{link.detail}</span>
        </Link>
      ))}
    </nav>
  );
}
