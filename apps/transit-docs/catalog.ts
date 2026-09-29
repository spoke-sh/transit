// Each page has one repository owner. Routes and navigation are presentation only.
export type Page = { source: string; route: string; label: string };
export type Section = { label: string; pages: Page[] };
const page = (source: string, route: string, label: string): Page => ({ source, route, label });
const foundation = (name: string, label: string): Page =>
  page(`docs/internal/${name}.md`, `concepts/${name.toLowerCase().replaceAll("_", "-")}`, label);
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
    ],
  },
  {
    label: "Core concepts",
    pages: [
      foundation("TRANSIT", "Processes and turns"),
      foundation("STREAMS", "Streams and delivery"),
      foundation("STATE", "State and associations"),
      foundation("SECURITY", "Identity and permissions"),
      foundation("RETENTION", "Retention and lifetimes"),
      foundation("FLOW_CONTROL", "Flow control"),
      foundation("GLOSSARY", "Glossary"),
    ],
  },
  {
    label: "Build applications",
    pages: [
      foundation("CLIENT", "Caller model"),
      reference("sdks", "Language SDKs"),
      foundation("SDK", "Shared SDK contracts"),
      foundation("STATION", "Behaviors and supervision"),
      foundation("TABLES", "Tables"),
      foundation("DOCUMENTS", "Documents"),
      foundation("CONNECTORS", "Effects and HTTP connectors"),
      foundation("GRPC", "gRPC connectors"),
      foundation("SERVING", "Serve an application API"),
      foundation("REACTIVE_API", "Sessions and subscriptions"),
      foundation("REACTIVE", "Live views and freshness"),
      foundation("REACTIVE_APPLICATIONS", "Declarative applications"),
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
    ],
  },
  {
    label: "Query data",
    pages: [
      reference("sql", "SQL reference"),
      foundation("FUZE", "Query execution"),
      page("packages/zig/transit-fuze/docs/sql.md", "reference/sql-table", "Table SQL v1"),
      page(
        "packages/zig/transit-fuze/docs/unified-sql.md",
        "reference/sql-unified",
        "Unified SQL v2",
      ),
      page("apps/transit-cli/docs/console.md", "guides/console", "Use the console"),
      page(
        "apps/transit-cli/docs/unified-query.md",
        "guides/query-v2",
        "Query recovery and source configuration",
      ),
      page(
        "packages/zig/transit-query/docs/compatibility.md",
        "reference/query-compatibility",
        "Query compatibility",
      ),
      foundation("ARROW", "Arrow interchange"),
      reference("flight", "Flight SQL and ADBC"),
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
    ],
  },
  {
    label: "Interface reference",
    pages: [
      reference("cli", "Transit CLI"),
      reference("native", "Native signed protocol"),
      reference("openapi", "Serving OpenAPI"),
      reference("board-api", "Board OpenAPI"),
      reference("asyncapi", "Reactive AsyncAPI"),
      page(
        "contracts/APPLICATION_INSTALLATION_V1.md",
        "reference/application-installation",
        "Installation and bootstrap contract",
      ),
      page("contracts/SERVING_V1.md", "reference/serving-wire", "Serving wire contract"),
      page("contracts/REACTIVE_V1.md", "reference/reactive-wire", "Reactive wire contract"),
      page("contracts/FLIGHT_V1.md", "reference/flight-wire", "Flight wire contract"),
      page("contracts/SERVICE_V2.md", "reference/native-wire", "Native HTTP wire contract"),
      page("contracts/TRANSIT_V3.md", "reference/growing-wire", "Growing protocol v3"),
    ],
  },
  {
    label: "Operate Transit",
    pages: [
      page("apps/transit-cli/docs/server.md", "guides/server", "Configure a local server"),
      page("launchers/README.md", "guides/launchers", "Development launchers"),
      foundation("DEPLOYMENT", "Deployment and recovery"),
      foundation("BOARD", "Inspect with Board"),
      page("apps/transit-board/docs/configuration.md", "guides/board", "Configure Board"),
      foundation("OBSERVABILITY", "Logs, metrics and probes"),
      page("apps/transit-node/docs/operations.md", "guides/node", "Node operations"),
      foundation("URSULA", "Storage boundary"),
    ],
  },
  {
    label: "Architecture and contribution",
    pages: [
      foundation("SCOPE", "Scope and limits"),
      foundation("ARCHITECTURE", "Architecture and components"),
      foundation("QUERY_LANGUAGE", "Declarative language design"),
      page("docs/internal/DEVELOPMENT.md", "contributing/development", "Development"),
      page("docs/internal/TESTING.md", "contributing/testing", "Testing strategy"),
      page("docs/internal/CONFORMANCE.md", "contributing/conformance", "Conformance requirements"),
      page("docs/README.md", "contributing/documentation", "Documentation ownership"),
      page("docs/internal/roadmap/README.md", "contributing/roadmap", "Roadmap"),
    ],
  },
];
export const pages = sections.flatMap((section) => section.pages);
export const docId = (entry: Page): string => entry.source.replace(/\.md$/, "");
