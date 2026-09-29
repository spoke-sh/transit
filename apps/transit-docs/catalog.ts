// Public concepts have one source for users, developers and agents. Internal
// planning/history is deliberately absent from published navigation and search.
export type Page = { source: string; route: string; label: string };
export type Section = { label: string; pages: Page[] };
const page = (source: string, route: string, label: string): Page => ({ source, route, label });
const guide = (name: string, label: string): Page =>
  page(`docs/guides/${name}.md`, `guides/${name}`, label);
const reference = (name: string, label: string): Page =>
  page(`docs/reference/${name}.md`, `reference/${name}`, label);
export const sections: Section[] = [
  {
    label: "Start here",
    pages: [
      guide("introduction", "What is Transit?"),
      guide("quickstart", "Run Transit locally"),
      guide("applications", "Build your first application"),
      guide("choose-interface", "Choose an interface"),
      guide("workload-examples", "Workload examples across languages"),
    ],
  },
  {
    label: "CLI",
    pages: [
      reference("cli", "Transit CLI"),
      page("apps/transit-cli/docs/console.md", "guides/console", "Use the console"),
      page("apps/transit-cli/docs/server.md", "guides/server", "Configure a local server"),
      page(
        "apps/transit-cli/docs/applications.md",
        "guides/install-applications",
        "Install and replace applications",
      ),
      page(
        "apps/transit-cli/docs/unified-query.md",
        "guides/query-v2",
        "Query recovery and source configuration",
      ),
    ],
  },
  {
    label: "SQL",
    pages: [
      reference("sql", "SQL reference"),
      reference("sql/syntax", "Syntax, names and literals"),
      reference("sql/select", "SELECT"),
      reference("sql/create-connection", "CREATE CONNECTION"),
      reference("sql/create-source", "CREATE SOURCE"),
      reference("sql/create-sink", "CREATE SINK"),
      reference("sql/create-table", "CREATE TABLE"),
      reference("sql/create-document", "CREATE DOCUMENT"),
      reference("sql/create-kv", "CREATE KV"),
      reference("sql/grant", "GRANT"),
      reference("sql/revoke", "REVOKE"),
      reference("sql/show", "SHOW"),
      reference("sql/describe", "DESCRIBE"),
      reference("sql/as-of", "FOR SYSTEM_TIME AS OF"),
      reference("sql/application", "Application declarations"),
      reference("queries", "Query execution and recovery"),
      page("packages/zig/transit-fuze/docs/sql.md", "reference/sql-table", "Table SQL v1"),
      page(
        "packages/zig/transit-fuze/docs/unified-sql.md",
        "reference/sql-unified",
        "Unified SQL v2",
      ),
      page(
        "packages/zig/transit-query/docs/compatibility.md",
        "reference/query-compatibility",
        "Query compatibility",
      ),
    ],
  },
  {
    label: "SDKs",
    pages: [
      reference("sdks", "Language SDKs"),
      reference("callers", "Caller and SDK semantics"),
      reference("station", "Behaviors and supervision"),
    ],
  },
  {
    label: "HTTP APIs / OpenAPI",
    pages: [
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
      page("contracts/SERVICE_V2.md", "reference/native-wire", "Native HTTP wire contract"),
      page("contracts/TRANSIT_V3.md", "reference/growing-wire", "Growing protocol v3"),
    ],
  },
  {
    label: "Core concepts",
    pages: [
      reference("architecture", "Architecture and scope"),
      reference("workloads", "Workloads and architectural priorities"),
      reference("processes", "Processes and turns"),
      reference("streams", "Streams and delivery"),
      reference("state", "State and associations"),
      reference("security", "Identity and permissions"),
      reference("retention", "Retention and capacity"),
      reference("glossary", "Glossary"),
    ],
  },
  {
    label: "Build applications",
    pages: [
      reference("tables", "Tables and materialization"),
      reference("documents", "Documents and text"),
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
      page("launchers/README.md", "guides/launchers", "Development launchers"),
      reference("deployment", "Deployment and recovery"),
      guide("inspect-board", "Inspect with Board"),
      page("apps/transit-board/docs/configuration.md", "guides/board", "Configure Board"),
      reference("observability", "Logs, metrics and probes"),
      reference("performance", "Performance and improvement plan"),
      page("apps/transit-node/docs/operations.md", "guides/node", "Node operations"),
      reference("storage", "Storage and recovery boundary"),
    ],
  },
  {
    label: "Understand and contribute",
    pages: [
      reference("components", "Component directory"),
      reference("verification", "Guarantees and verification limits"),
      guide("contributing", "Contributing"),
      page("docs/README.md", "contributing/documentation", "Documentation ownership"),
    ],
  },
];
export const pages = sections.flatMap((section) => section.pages);
export const docId = (entry: Page): string => entry.source.replace(/\.md$/, "");
