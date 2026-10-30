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
    label: "Architecture and foundations",
    pages: [
      account("README", "Internals"),
      account("system-model", "System model and authority boundaries"),
      account("standard", "Scientific standard for Internals"),
      account("template", "Technical account template"),
    ],
  },
  {
    label: "Storage, state and query engine (Direct Data Plane)",
    pages: [
      account("storage-runtime", "Storage, placement and observation"),
      account("state-model", "State, publication and lifetime"),
      account("query-engine", "Query planning, snapshots and results"),
    ],
  },
  {
    label: "Durable execution, gateways and verification",
    pages: [
      account("execution-model", "Execution, authorization and recovery"),
      account("effect-lifecycle", "External effects and uncertain outcomes"),
      account("service-interfaces", "SQL sessions, serving and operator interfaces"),
      account("client-framework", "Clients, SDKs and Station"),
      account("verification-method", "Verification and the limits of evidence"),
    ],
  },
];
