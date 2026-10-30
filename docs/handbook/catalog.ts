import { sdkSections } from "./sdk-catalog";
import { internalsSections } from "./internals-catalog";

// Usage documentation and Internals share sources, routes and search.
export type Page = { source: string; route: string; label: string };
export type PageGroup = { label: string; pages: Page[] };
export type Section = { label: string; pages: Page[]; groups?: PageGroup[] };
const page = (source: string, route: string, label: string): Page => ({ source, route, label });
const guide = (name: string, label: string): Page =>
  page(`docs/handbook/guides/${name}.md`, `guides/${name}`, label);
const reference = (name: string, label: string): Page =>
  page(`docs/handbook/reference/${name}.md`, `reference/${name}`, label);
const groupedSection = (label: string, groups: PageGroup[]): Section => ({
  label,
  groups,
  pages: groups.flatMap((group) => group.pages),
});

export const sections: Section[] = [
  {
    label: "Overview and quickstart",
    pages: [
      guide("introduction", "What is Transit?"),
      reference("architecture", "Architecture and scope"),
      reference("collaborative-decisions", "From data to decisions with people and agents"),
      guide("quickstart", "Run Transit locally"),
      guide("choose-interface", "Choose an interface"),
      reference("interfaces", "Interface and architecture map"),
      guide("workload-examples", "Workload examples across languages"),
      reference("glossary", "Glossary"),
    ],
  },
  {
    label: "Data model and type system",
    pages: [
      reference("data-model", "Data, computation and policies"),
      reference("tables", "Tables and materialization"),
      reference("documents", "Documents and text"),
      reference("state", "Key-value resources and associations"),
      reference("streams", "Streams and delivery"),
      reference("sql/types", "Data types and cell states"),
      page(
        "packages/zig/transit-fuze/docs/file-sources.md",
        "reference/file-sources",
        "Bounded CSV and JSONL sources",
      ),
      reference("storage", "Storage and recovery boundary"),
    ],
  },
  groupedSection("Query engine (Fuze) and SQL", [
    {
      label: "Query execution and lifecycles",
      pages: [
        reference("queries", "Query execution and recovery"),
        reference("workloads", "Workloads and architectural priorities"),
        reference("sql/streaming", "Streaming and effects"),
        page(
          "packages/zig/transit-query/docs/compatibility.md",
          "reference/query-compatibility",
          "Query compatibility",
        ),
      ],
    },
    {
      label: "SQL language and foundations",
      pages: [
        reference("sql", "SQL reference"),
        reference("sql/grammar-surface", "Grammar surface: implemented and planned"),
        reference("sql/syntax", "Syntax, names and literals"),
        reference("sql/expressions", "Functions and operators"),
        reference("sql/parameters", "Typed query parameters"),
        page("packages/zig/transit-fuze/docs/sql.md", "reference/sql-table", "Table SQL v1"),
        page(
          "packages/zig/transit-fuze/docs/unified-sql.md",
          "reference/sql-unified",
          "Unified state SQL",
        ),
      ],
    },
    {
      label: "Queries, joins and time travel",
      pages: [
        reference("sql/select", "SELECT"),
        reference("sql/relational", "Table joins and grouped aggregation"),
        reference("sql/as-of", "FOR SYSTEM_TIME AS OF"),
      ],
    },
    {
      label: "Mutations and transactions (DML)",
      pages: [
        reference("sql/transactions", "Table transactions and savepoints"),
        reference("sql/insert", "INSERT"),
        reference("sql/update", "UPDATE"),
        reference("sql/delete", "DELETE"),
      ],
    },
    {
      label: "Data and resource declarations (DDL)",
      pages: [
        reference("sql/create-table", "CREATE TABLE"),
        reference("sql/alter-table", "ALTER TABLE"),
        reference("sql/drop-table", "DROP TABLE"),
        reference("sql/create-document", "CREATE DOCUMENT"),
        reference("sql/create-kv", "CREATE KV"),
        reference("sql/create-connection", "CREATE CONNECTION"),
        reference("sql/create-source", "CREATE SOURCE"),
        reference("sql/create-sink", "CREATE SINK"),
        reference("sql/application", "Application declarations"),
      ],
    },
    {
      label: "Introspection and session settings",
      pages: [
        reference("sql/show", "SHOW"),
        reference("sql/describe", "DESCRIBE"),
        reference("sql/explain", "EXPLAIN"),
        reference("sql/settings", "Settings and reload"),
      ],
    },
  ]),
  {
    label: "Durable execution (Station) and apps",
    pages: [
      reference("processes", "Processes and turns"),
      guide("applications", "Build your first application"),
      reference("connectors", "Effects, HTTP and gRPC connectors"),
      reference("applications", "Installation, definitions and migration"),
      page(
        "apps/transit-cli/docs/applications.md",
        "guides/install-applications",
        "Install and replace applications",
      ),
      page(
        "examples/work-items/docs/local.md",
        "guides/work-items",
        "Work-item commands and migration",
      ),
      page(
        "contracts/APPLICATION_INSTALLATION_V1.md",
        "reference/application-installation",
        "Installation and bootstrap contract",
      ),
    ],
  },
  groupedSection("Client protocols, CLI and gateways", [
    {
      label: "CLI and interactive console",
      pages: [
        reference("cli", "Transit CLI"),
        page("apps/transit-cli/docs/console.md", "guides/console", "Use the console"),
        page("apps/transit-cli/docs/sql.md", "guides/local-sql", "Connect with psql and mysql"),
      ],
    },
    {
      label: "SQL sessions and wire gateways",
      pages: [
        reference("sql-sessions", "SQL sessions"),
        page("contracts/SQL_SESSION_V1.md", "reference/sql-session", "SQL session wire contract"),
        reference("database-protocols", "PostgreSQL and MySQL clients"),
        page("contracts/SQL_GATEWAY_V1.md", "reference/database-wire", "Database wire contract"),
      ],
    },
    {
      label: "Arrow, Flight SQL and ADBC",
      pages: [
        reference("flight", "Flight SQL and ADBC"),
        reference("arrow", "Arrow interchange"),
        page(
          "packages/zig/transit-flight/docs/compatibility.md",
          "reference/flight-compatibility",
          "Flight compatibility",
        ),
        page(
          "apps/transit-flight-gateway/docs/configuration.md",
          "guides/flight-gateway",
          "Configure a Flight gateway",
        ),
        page("contracts/FLIGHT_V1.md", "reference/flight-wire", "Flight wire contract"),
      ],
    },
    {
      label: "HTTP Serving (OpenAPI) and Reactive (AsyncAPI)",
      pages: [
        reference("openapi", "Serving OpenAPI"),
        reference("serving", "Serve an application API"),
        page("contracts/SERVING_V1.md", "reference/serving-wire", "Serving wire contract"),
        reference("asyncapi", "Reactive AsyncAPI"),
        reference("reactive", "Sessions, watches and live views"),
        page("contracts/REACTIVE_V1.md", "reference/reactive-wire", "Reactive wire contract"),
      ],
    },
    {
      label: "Native signed protocol",
      pages: [
        reference("native", "Native signed protocol"),
        page("contracts/SERVICE_V1.md", "reference/native-wire", "Native HTTP wire contract"),
        page("contracts/TRANSIT_V1.md", "reference/native-protocol", "Native protocol v1"),
      ],
    },
  ]),
  groupedSection("Security, governance and operations", [
    {
      label: "Identity, grants and retention",
      pages: [
        reference("security", "Identity and permissions"),
        reference("sql/authorization", "Role and schema administration"),
        reference("sql/grant", "GRANT"),
        reference("sql/revoke", "REVOKE"),
        page(
          "contracts/AUTHORIZATION_V1.md",
          "reference/authorization-contract",
          "Authorization v1",
        ),
        reference("retention", "Retention and capacity"),
      ],
    },
    {
      label: "Board workbench and observability",
      pages: [
        guide("inspect-board", "Inspect with Board"),
        page("apps/transit-board/docs/configuration.md", "guides/board", "Configure Board"),
        reference("board-api", "Board OpenAPI"),
        reference("observability", "Logs, metrics and probes"),
      ],
    },
    {
      label: "Deployment, configuration and benchmarks",
      pages: [
        reference("configuration", "Configuration and settings"),
        page("apps/transit-cli/docs/server.md", "guides/server", "Configure a local server"),
        guide("launchers", "Development launchers"),
        reference("deployment", "Deployment and recovery"),
        reference("distribution", "Release packages and installation"),
        page("apps/transit-node/docs/operations.md", "guides/node", "Node operations"),
        reference("performance", "Performance and improvement plan"),
        reference("benchmarks", "Declarative benchmarks and TPC coverage"),
      ],
    },
  ]),
  {
    label: "Verification, contracts and contributing",
    pages: [
      reference("verification", "Guarantees and verification limits"),
      reference("contracts", "Contracts and schema downloads"),
      reference("versioning", "Versioning and hard cutovers"),
      reference("components", "Component directory"),
      guide("contributing", "Contributing"),
      page("docs/README.md", "contributing/documentation", "Documentation ownership"),
    ],
  },
];
export const sdkPages = sdkSections.flatMap((section) => section.pages);
export const handbookPages = [...sections.flatMap((section) => section.pages), ...sdkPages];
export const internalsPages = internalsSections.flatMap((section) => section.pages);
export const pages = [...handbookPages, ...internalsPages];
export const docId = (entry: Page): string => entry.source.replace(/\.md$/, "");
