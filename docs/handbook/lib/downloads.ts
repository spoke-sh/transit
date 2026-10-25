import { specifications } from "./specs";

// Downloads retain their repository owners. Only OpenAPI/AsyncAPI entries are
// rendered as API tables; native message schemas have their own encoding rules.
export const downloads = [
  ...specifications,
  ...[
    "transit-v1.schema.json",
    "sql-session-v1.schema.json",
    "direct-table-v1.schema.json",
    "configuration-v1.schema.json",
    "configuration-settings-v1.json",
    "diagnostic-v1.schema.json",
    "application-installation-v1.schema.json",
    "data-lifecycle-v1.schema.json",
    "index-lifecycle-v1.schema.json",
  ].map((name) => ({
    source: `contracts/${name}`,
    name,
    page: "docs/handbook/reference/contracts.md",
  })),
];
