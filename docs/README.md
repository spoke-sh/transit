# Transit documentation

The public handbook is the shared source of current behavior for application
users, contributors and agents. Start with [What is Transit?](handbook/guides/introduction.md),
[Run Transit locally](handbook/guides/quickstart.md) and
[Build your first application](handbook/guides/applications.md).
The [handbook project](handbook/README.md) keeps the Docusaurus site and its
content together under `docs/handbook/`. The [interface and architecture map](handbook/reference/interfaces.md)
connects public usage, exact contracts and technical accounts.

## Guides and reference

The site navigation starts with the interfaces: CLI, SQL, SDKs, HTTP APIs/OpenAPI,
reactive APIs/AsyncAPI, Flight SQL/ADBC and the native protocol. Internals sits
alongside these entry points for architecture, mechanisms and technical evidence. SDKs has its own sidebar with shared caller semantics and language installation pages. Each
interface section groups its usage guides and exact contracts. Core concepts, application state
and operations remain shared references below those entry points.

| Interface | Start here |
| --- | --- |
| CLI | [Configuration](handbook/reference/configuration.md), [Commands](handbook/reference/cli.md), [console](../apps/transit-cli/docs/console.md), [local server](../apps/transit-cli/docs/server.md), [psql/mysql](../apps/transit-cli/docs/sql.md) |
| SQL | [Statements and support](handbook/reference/sql.md), [implemented and planned grammar](handbook/reference/sql/grammar-surface.md), [syntax](handbook/reference/sql/syntax.md), [types](handbook/reference/sql/types.md), [functions and operators](handbook/reference/sql/expressions.md), [streaming and effects](handbook/reference/sql/streaming.md) |
| SDKs | [Language SDKs](handbook/reference/sdks.md), [caller semantics](handbook/reference/callers.md) |
| SQL connections | [SQL sessions](handbook/reference/sql-sessions.md), [PostgreSQL and MySQL](handbook/reference/database-protocols.md) |
| HTTP APIs | [SQL session API](../contracts/SQL_SESSION_V1.md), [Serving OpenAPI](handbook/reference/openapi.md), [Board OpenAPI](handbook/reference/board-api.md), [schema downloads](handbook/reference/contracts.md) |
| Reactive APIs | [AsyncAPI](handbook/reference/asyncapi.md), [sessions and watches](handbook/reference/reactive.md) |
| Analytical clients | [Flight SQL and ADBC](handbook/reference/flight.md) |
| Native protocol | [Signed operations](handbook/reference/native.md) |

The SQL statement index covers the complete checked grammar, including explicit
Table mutations, offline definitions and administrative forms that remain
grammar-only. The grammar surface inventory also labels planned relational,
graph, foreign-relation and historical-schema operations, separating proposed
syntax from forms whose syntax is undecided. Each statement's page explains its
support boundary before giving examples.

| Topic | Public documentation |
| --- | --- |
| Internals | [System models, mechanisms and evidence](handbook/internals/README.md), [scientific standard](handbook/internals/standard.md) |
| Model and components | [Architecture and scope](handbook/reference/architecture.md), [component directory](handbook/reference/components.md), [glossary](handbook/reference/glossary.md) |
| Compatibility policy | [Versioning and hard cutovers](handbook/reference/versioning.md) |
| Workloads and performance | [Workload priorities](handbook/reference/workloads.md), [measured performance and improvement plan](handbook/reference/performance.md), [declarative benchmarks](handbook/reference/benchmarks.md), [examples across languages](handbook/guides/workload-examples.md) |
| Durable execution | [Processes and turns](handbook/reference/processes.md), [streams and delivery](handbook/reference/streams.md), [caller/SDK semantics](handbook/reference/callers.md) |
| Authority and lifetime | [Security](handbook/reference/security.md), [retention and capacity](handbook/reference/retention.md), [storage](handbook/reference/storage.md) |
| Application state | [State resources](handbook/reference/state.md), [Station](handbook/reference/station.md), [Tables](handbook/reference/tables.md), [Documents](handbook/reference/documents.md) |
| Installation and composition | [Application installation, definitions and migration](handbook/reference/applications.md), [language SDKs](handbook/reference/sdks.md) |
| Effects and inbound APIs | [Connectors](handbook/reference/connectors.md), [serving](handbook/reference/serving.md), [reactive sessions and views](handbook/reference/reactive.md) |
| Queries and interchange | [SQL](handbook/reference/sql.md), [query execution](handbook/reference/queries.md), [Arrow](handbook/reference/arrow.md), [Flight SQL/ADBC](handbook/reference/flight.md) |
| Type coverage and schema discovery | [Logical types and frozen CSV/JSONL discovery](handbook/reference/sql/types.md), [measured DuckDB comparisons](handbook/reference/performance.md#schema-on-demand-measurements) |
| Interface specifications | [CLI](handbook/reference/cli.md), [native protocol](handbook/reference/native.md), [serving OpenAPI](handbook/reference/openapi.md), [Board OpenAPI](handbook/reference/board-api.md), [AsyncAPI](handbook/reference/asyncapi.md) |
| Operation and contribution | [Deployment](handbook/reference/deployment.md), [Board](handbook/guides/inspect-board.md), [observability](handbook/reference/observability.md), [verification limits](handbook/reference/verification.md), [contributing](handbook/guides/contributing.md) |

Select a supported profile with the [interface matrix](handbook/guides/choose-interface.md).
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
| `docs/handbook/guides/` | Runnable user and contributor workflows |
| `docs/handbook/reference/` | Current concepts, architecture overview, guarantees, interface semantics, limits and compatibility; explicitly labeled grammar targets, workload priorities and performance improvement plans |
| `sdks/<language>/` READMEs and guides | Consumer language installation and API documentation; the handbook SDK sidebar reads these owners directly |
| Package/app READMEs and `docs/` | Exact component APIs, configuration and substantial integration/recovery guides; linked directly from the handbook |
| [contracts/](../contracts) | Versioned wire/ABI formats, neutral schemas and shared fixtures; generated descriptions keep their implementation owners |
| [examples/](../examples/README.md) | Complete applications and commands that exercise the public APIs |
| [tests/](../tests/README.md) | Executable proof commands, failure schedules, measurements and qualification results |
| [docs/handbook/](handbook/README.md) | Docusaurus navigation, rendering, search, generated API presentation and browser verification |
| [docs/handbook/internals/](handbook/internals/README.md) | Consolidated scientific accounts of system models, mechanisms, invariants, tradeoffs and evidence |
| [docs/roadmap/](roadmap/README.md) | Unfinished delivery scope, sequencing and acceptance criteria |
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
[scientific standard](handbook/internals/standard.md): explicit scope and assumptions,
precise claims, traceable sources, reproducible evidence, alternatives and limits.
New and substantively revised technical accounts follow that standard. Consolidate
overlapping explanations around a clear model or mechanism; link exact contracts,
implementation and evidence instead of creating parallel specifications.

Every Markdown page in `docs/handbook/guides/`, `docs/handbook/reference/` and `docs/handbook/internals/`
belongs in the site catalog and search. Internals has its own top-level navigation
and a compact sidebar. Usage documentation can link there for deeper reasoning,
but remains sufficient to use and operate the documented interface.

Roadmap, Design and History are separate repository sections, linked from their
owners without adding their individual records to the site's reading path or
search. Keep delivery-plan labels and sequencing there. Usage/reference pages,
component guides and wire contracts continue to describe capabilities directly;
scientific accounts may cite dated proof records without inheriting broader claims.
Completed milestones are removed; current semantics and reasoning remain with
their public owners. Test evidence is maintained separately from delivery history.

Repository Markdown must remain readable without Docusaurus. Render generated
OpenAPI/AsyncAPI descriptions from the owning files; do not hand-maintain endpoint
schemas. Preserve explicit implemented/proposed/unsupported distinctions and
source evidence when moving material. Keep dates and outcomes on historical reviews.

## Update and verify

Read the public topic, its component guide and relevant wire contract before
changing behavior. Update all affected user explanations with the code. Use
[contributing](handbook/guides/contributing.md) for the repository workflow and
[verification](handbook/reference/verification.md) to select evidence. The
[site guide](handbook/README.md) owns preview, validation,
hosting, generated references and root/prefixed browser check commands.
