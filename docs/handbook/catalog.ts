import { sdkSections } from "./sdk-catalog";
import { internalsSections } from "./internals-catalog";

// Usage documentation and Internals share sources, routes and search.
export type Page = { source: string; route: string; label: string };
export type Section = { label: string; pages: Page[] };
const page = (source: string, route: string, label: string): Page => ({ source, route, label });
const guide = (name: string, label: string): Page =>
  page(`docs/handbook/guides/${name}.md`, `guides/${name}`, label);
const reference = (name: string, label: string): Page =>
  page(`docs/handbook/reference/${name}.md`, `reference/${name}`, label);
export const sections: Section[] = [
  {
    label: "Start here",
    pages: [
      guide("introduction", "What is Transit?"),
      guide("quickstart", "Run Transit locally"),
      guide("choose-interface", "Choose an interface"),
      reference("interfaces", "Interface and architecture map"),
      guide("workload-examples", "Workload examples across languages"),
    ],
  },
  {
    label: "Data model",
    pages: [
      reference("data-model", "Data, computation and policies"),
      reference("tables", "Tables and materialization"),
      reference("state", "Key-value resources and associations"),
      reference("documents", "Documents and text"),
      reference("sql/types", "Data types and cell states"),
    ],
  },
  {
    label: "Queries and derived data",
    pages: [
      reference("queries", "Query execution and recovery"),
      reference("sql/streaming", "Streaming and effects"),
      reference("workloads", "Workloads and architectural priorities"),
    ],
  },
  {
    label: "Policies and lifecycle",
    pages: [
      reference("security", "Identity and permissions"),
      reference("retention", "Retention and capacity"),
    ],
  },
  {
    label: "CLI",
    pages: [
      reference("cli", "Transit CLI"),
      reference("configuration", "Configuration and settings"),
      page(
        "apps/transit-cli/docs/authorization.md",
        "guides/authorization",
        "Administer roles and grants",
      ),
      page("apps/transit-cli/docs/catalog.md", "guides/catalog", "Use Tables and recover writes"),
      page("apps/transit-cli/docs/console.md", "guides/console", "Use the console"),
      page("apps/transit-cli/docs/file-query.md", "guides/file-query", "Query CSV and JSONL files"),
      page("apps/transit-cli/docs/server.md", "guides/server", "Configure a local server"),
      page("apps/transit-cli/docs/sql.md", "guides/local-sql", "Connect with psql and mysql"),
      page(
        "apps/transit-cli/docs/applications.md",
        "guides/install-applications",
        "Install and replace applications",
      ),
      page(
        "apps/transit-cli/docs/unified-query.md",
        "guides/query",
        "Query recovery and source configuration",
      ),
    ],
  },
  {
    label: "SQL",
    pages: [
      reference("sql", "SQL reference"),
      reference("sql/grammar-surface", "Grammar surface: implemented and planned"),
      reference("sql/syntax", "Syntax, names and literals"),
      reference("sql/expressions", "Functions and operators"),
      reference("sql/select", "SELECT"),
      reference("sql/relational", "Table joins and grouped aggregation"),
      reference("sql/parameters", "Typed query parameters"),
      reference("sql/insert", "INSERT"),
      reference("sql/update", "UPDATE"),
      reference("sql/delete", "DELETE"),
      reference("sql/create-connection", "CREATE CONNECTION"),
      reference("sql/create-source", "CREATE SOURCE"),
      reference("sql/create-sink", "CREATE SINK"),
      reference("sql/create-table", "CREATE TABLE"),
      reference("sql/alter-table", "ALTER TABLE"),
      reference("sql/drop-table", "DROP TABLE"),
      reference("sql/create-document", "CREATE DOCUMENT"),
      reference("sql/create-kv", "CREATE KV"),
      reference("sql/authorization", "Role and schema administration"),
      reference("sql/grant", "GRANT"),
      reference("sql/revoke", "REVOKE"),
      reference("sql/show", "SHOW"),
      reference("sql/settings", "Settings and reload"),
      reference("sql/describe", "DESCRIBE"),
      reference("sql/explain", "EXPLAIN"),
      reference("sql/as-of", "FOR SYSTEM_TIME AS OF"),
      reference("sql/application", "Application declarations"),
      reference("database-protocols", "PostgreSQL and MySQL clients"),
      page("contracts/SQL_GATEWAY_V1.md", "reference/database-wire", "Database wire contract"),
      page(
        "packages/zig/transit-fuze/docs/file-sources.md",
        "reference/file-sources",
        "Bounded CSV and JSONL sources",
      ),
      page("packages/zig/transit-fuze/docs/sql.md", "reference/sql-table", "Table SQL v1"),
      page(
        "packages/zig/transit-fuze/docs/unified-sql.md",
        "reference/sql-unified",
        "Unified state SQL",
      ),
      page(
        "packages/zig/transit-query/docs/compatibility.md",
        "reference/query-compatibility",
        "Query compatibility",
      ),
    ],
  },
  {
    label: "HTTP APIs / OpenAPI",
    pages: [
      reference("sql-sessions", "SQL sessions"),
      page("contracts/SQL_SESSION_V1.md", "reference/sql-session", "SQL session wire contract"),
      reference("openapi", "Serving OpenAPI"),
      reference("serving", "Serve an application API"),
      reference("board-api", "Board OpenAPI"),
      page("contracts/SERVING_V1.md", "reference/serving-wire", "Serving wire contract"),
    ],
  },
  {
    label: "Reactive APIs / AsyncAPI",
    pages: [
      reference("asyncapi", "Reactive AsyncAPI"),
      reference("reactive", "Sessions, watches and live views"),
      page("contracts/REACTIVE_V1.md", "reference/reactive-wire", "Reactive wire contract"),
    ],
  },
  {
    label: "Flight SQL and ADBC",
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
    label: "Native protocol",
    pages: [
      reference("native", "Native signed protocol"),
      page("contracts/SERVICE_V1.md", "reference/native-wire", "Native HTTP wire contract"),
      page("contracts/TRANSIT_V1.md", "reference/native-protocol", "Native protocol v1"),
      page("contracts/AUTHORIZATION_V1.md", "reference/authorization-contract", "Authorization v1"),
    ],
  },
  {
    label: "Execution and architecture",
    pages: [
      reference("architecture", "Architecture and scope"),
      reference("versioning", "Versioning and hard cutovers"),
      reference("processes", "Processes and turns"),
      reference("streams", "Streams and delivery"),
      reference("glossary", "Glossary"),
    ],
  },
  {
    label: "Extend Transit",
    pages: [
      guide("applications", "Build your first application"),
      reference("connectors", "Effects, HTTP and gRPC connectors"),
      reference("applications", "Installation, definitions and migration"),
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
  {
    label: "Operate Transit",
    pages: [
      guide("launchers", "Development launchers"),
      reference("deployment", "Deployment and recovery"),
      guide("inspect-board", "Inspect with Board"),
      page("apps/transit-board/docs/configuration.md", "guides/board", "Configure Board"),
      reference("observability", "Logs, metrics and probes"),
      reference("performance", "Performance and improvement plan"),
      reference("benchmarks", "Declarative benchmarks and TPC coverage"),
      page("apps/transit-node/docs/operations.md", "guides/node", "Node operations"),
      reference("storage", "Storage and recovery boundary"),
    ],
  },
  {
    label: "Understand and contribute",
    pages: [
      reference("components", "Component directory"),
      reference("contracts", "Contracts and schema downloads"),
      reference("verification", "Guarantees and verification limits"),
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
