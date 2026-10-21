# Transit documentation

The public handbook is the shared source of current behavior for application
users, contributors and agents. Start with [What is Transit?](guides/introduction.md),
[Run Transit locally](guides/quickstart.md) and
[Build your first application](guides/applications.md).

## Guides and reference

The site navigation starts with the interfaces: CLI, SQL, SDKs, HTTP APIs/OpenAPI,
reactive APIs/AsyncAPI, Flight SQL/ADBC and the native protocol. Internals sits
alongside these entry points for architecture, mechanisms and technical evidence. SDKs has its own sidebar with shared caller semantics and language installation pages. Each
interface section groups its usage guides and exact contracts. Core concepts, application state
and operations remain shared references below those entry points.

| Interface | Start here |
| --- | --- |
| CLI | [Configuration](reference/configuration.md), [Commands](reference/cli.md), [console](../apps/transit-cli/docs/console.md), [local server](../apps/transit-cli/docs/server.md), [psql/mysql](../apps/transit-cli/docs/sql.md) |
| SQL | [Statements and support](reference/sql.md), [implemented and planned grammar](reference/sql/grammar-surface.md), [syntax](reference/sql/syntax.md), [types](reference/sql/types.md), [functions and operators](reference/sql/expressions.md), [streaming and effects](reference/sql/streaming.md) |
| SDKs | [Language SDKs](reference/sdks.md), [caller semantics](reference/callers.md) |
| HTTP APIs | [SQL session API](../contracts/SQL_SESSION_V1.md), [Serving OpenAPI](reference/openapi.md), [Board OpenAPI](reference/board-api.md) |
| Reactive APIs | [AsyncAPI](reference/asyncapi.md), [sessions and watches](reference/reactive.md) |
| Analytical clients | [Flight SQL and ADBC](reference/flight.md) |
| Native protocol | [Signed operations](reference/native.md) |

The SQL statement index covers the complete checked grammar, including explicit
Table mutations, offline definitions and administrative forms that remain
grammar-only. The grammar surface inventory also labels planned relational,
graph, foreign-relation and historical-schema operations, separating proposed
syntax from forms whose syntax is undecided. Each statement's page explains its
support boundary before giving examples.

| Topic | Public documentation |
| --- | --- |
| Internals | [System models, mechanisms and evidence](internals/README.md), [scientific standard](internals/standard.md) |
| Model and components | [Architecture and scope](reference/architecture.md), [component directory](reference/components.md), [glossary](reference/glossary.md) |
| Compatibility policy | [Versioning and hard cutovers](reference/versioning.md) |
| Workloads and performance | [Workload priorities](reference/workloads.md), [measured performance and improvement plan](reference/performance.md), [declarative benchmarks](reference/benchmarks.md), [examples across languages](guides/workload-examples.md) |
| Durable execution | [Processes and turns](reference/processes.md), [streams and delivery](reference/streams.md), [caller/SDK semantics](reference/callers.md) |
| Authority and lifetime | [Security](reference/security.md), [retention and capacity](reference/retention.md), [storage](reference/storage.md) |
| Application state | [State resources](reference/state.md), [Station](reference/station.md), [Tables](reference/tables.md), [Documents](reference/documents.md) |
| Installation and composition | [Application installation, definitions and migration](reference/applications.md), [language SDKs](reference/sdks.md) |
| Effects and inbound APIs | [Connectors](reference/connectors.md), [serving](reference/serving.md), [reactive sessions and views](reference/reactive.md) |
| Queries and interchange | [SQL](reference/sql.md), [query execution](reference/queries.md), [Arrow](reference/arrow.md), [Flight SQL/ADBC](reference/flight.md) |
| Type coverage and schema discovery | [Logical types and frozen CSV/JSONL discovery](reference/sql/types.md), [measured DuckDB comparisons](reference/performance.md#schema-on-demand-measurements) |
| Interface specifications | [CLI](reference/cli.md), [native protocol](reference/native.md), [serving OpenAPI](reference/openapi.md), [Board OpenAPI](reference/board-api.md), [AsyncAPI](reference/asyncapi.md) |
| Operation and contribution | [Deployment](reference/deployment.md), [Board](guides/inspect-board.md), [observability](reference/observability.md), [verification limits](reference/verification.md), [contributing](guides/contributing.md) |

Select a supported profile with the [interface matrix](guides/choose-interface.md).
Unsupported behavior, uncertainty, recovery rules and compatibility limits belong
beside the feature users rely on. Describe the capabilities in the documented
source revision, using interface versions and explicit supported/unsupported
profiles. Public architectural priorities and performance improvement plans live
beside their evidence, explicitly distinguished from implemented interfaces and
without promised dates or speedups. Keep delivery-plan labels and scheduling in
the separate planning and historical records. Usage guides, component guides and
wire contracts describe capabilities without delivery-plan labels. A reader
can understand the interface contract without reconstructing an engineering history.

Public command examples invoke `transit` from `PATH`. State the required installed
bundle and matching dependencies beside the workflow. Keep repository environment
setup and task-runner commands in the source tooling guides, outside
the site catalog and search. Link to those owners for setup and proof execution.

Write interfaces in the present tense: what they do, how to use them, supported
types and platforms, version compatibility and failure behavior. Avoid maturity
labels and blanket readiness caveats. Put concrete limits beside the operation
they affect; keep test execution details in the proof ledger. Clear wording must
preserve the actual support boundary.

## Where documentation lives

| Location | Ownership |
| --- | --- |
| `docs/guides/` | Runnable user and contributor workflows |
| `docs/reference/` | Current concepts, architecture overview, guarantees, interface semantics, limits and compatibility; explicitly labeled grammar targets, workload priorities and performance improvement plans |
| `sdks/<language>/` READMEs and guides | Consumer language installation and API documentation; the handbook SDK sidebar reads these owners directly |
| Package/app READMEs and `docs/` | Exact component APIs, configuration and substantial integration/recovery guides; linked directly from the handbook |
| [contracts/](../contracts) | Versioned wire/ABI formats, neutral schemas and shared fixtures; generated descriptions keep their implementation owners |
| [examples/](../examples/README.md) | Complete applications and commands that exercise the public APIs |
| [tests/](../tests/README.md) | Executable proof commands, failure schedules, measurements and qualification results |
| [apps/transit-docs/](../apps/transit-docs/README.md) | Docusaurus navigation, rendering, search, generated API presentation and browser verification |
| [docs/internals/](internals/README.md) | Consolidated scientific accounts of system models, mechanisms, invariants, tradeoffs and evidence |
| [docs/roadmap/](roadmap/README.md) | Delivery scope, sequencing, acceptance criteria and milestone status |
| [docs/design/](design/README.md) | UI/UX proposals, visual studies and recorded review outcomes |
| [docs/history/](history/README.md) | Earlier topic accounts, language sketches, workload assumptions and qualification reviews; preserved as source material |
| [docs/decisions/](decisions/README.md) | Reserved decision guidance and template; no separate ADR process |
| [AGENTS.md](../AGENTS.md) | Contributor/agent workflow and implementation rules; starts from the public handbook |

Keep one current explanation of a behavior. Guides and reference teach users how
to build with and operate Transit, including the assumptions, supported cases,
limits and failure semantics needed for those tasks. Internals explains the
mechanisms and reasoning in greater depth for readers evaluating or changing the
system. Link between these owners instead of duplicating contracts.

Internals and architecture explanations must meet the
[scientific standard](internals/standard.md): explicit scope and assumptions,
precise claims, traceable sources, reproducible evidence, alternatives and limits.
New and substantively revised technical accounts follow that standard. Consolidate
overlapping explanations around a clear model or mechanism; link exact contracts,
implementation and evidence instead of creating parallel specifications.

Every Markdown page in `docs/guides/`, `docs/reference/` and `docs/internals/`
belongs in the site catalog and search. Internals has its own top-level navigation
and a compact sidebar. Usage documentation can link there for deeper reasoning,
but remains sufficient to use and operate the documented interface.

Roadmap, Design and History are separate repository sections, linked from their
owners without adding their individual records to the site's reading path or
search. Keep delivery-plan labels and sequencing there. Usage/reference pages,
component guides and wire contracts continue to describe capabilities directly;
scientific accounts may cite dated proof records without inheriting broader claims.
Historical outcomes and proposal status remain intact in their owning records.

Repository Markdown must remain readable without Docusaurus. Render generated
OpenAPI/AsyncAPI descriptions from the owning files; do not hand-maintain endpoint
schemas. Preserve explicit implemented/proposed/unsupported distinctions and
source evidence when moving material. Keep dates and outcomes on historical reviews.

## Update and verify

Read the public topic, its component guide and relevant wire contract before
changing behavior. Update all affected user explanations with the code. Use
[contributing](guides/contributing.md) for the repository workflow and
[verification](reference/verification.md) to select evidence. The
[site guide](../apps/transit-docs/README.md) owns preview, validation,
hosting, generated references and root/prefixed browser check commands.
