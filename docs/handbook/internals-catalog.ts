import type { Page, Section } from "./catalog";

const account = (name: string, label: string): Page => ({
  source: `docs/handbook/internals/${name}.md`,
  route: name === "README" ? "internals" : `internals/${name}`,
  label,
});

// Publish consolidated explanations. Roadmap, Design and History retain their
// own repository indexes and source links outside this reading path and search.
export const internalsSections: Section[] = [
  {
    label: "Read and write Internals",
    pages: [
      account("README", "Internals"),
      account("standard", "Scientific standard for Internals"),
      account("template", "Technical account template"),
    ],
  },
  {
    label: "System and execution",
    pages: [
      account("system-model", "System model and authority boundaries"),
      account("execution-model", "Execution, authorization and recovery"),
      account("state-model", "State, publication and lifetime"),
    ],
  },
  {
    label: "Programming and interfaces",
    pages: [
      account("client-framework", "Clients, SDKs and Station"),
      account("query-engine", "Query planning, snapshots and results"),
      account("effect-lifecycle", "External effects and uncertain outcomes"),
      account("service-interfaces", "Serving, reactive views and Board"),
    ],
  },
  {
    label: "Runtime and evidence",
    pages: [
      account("storage-runtime", "Storage, placement and observation"),
      account("verification-method", "Verification and the limits of evidence"),
    ],
  },
];
