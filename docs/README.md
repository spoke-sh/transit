# Transit documentation

For application users, start with [the introduction](guides/introduction.md),
[local quickstart](guides/quickstart.md) and [application walkthrough](guides/applications.md).
[Choose an interface](guides/choose-interface.md) before integrating a client.
The Docusaurus site presents these guides, references and the foundations below
in a task-oriented sidebar. Run `just transit-docs::dev` after the locked
[site setup](../apps/transit-docs/README.md).

## User reference

| Interface | Documentation |
| --- | --- |
| SQL | [Admitted syntax and capability matrix](reference/sql.md) |
| CLI | [Commands, configuration and recovery](reference/cli.md) |
| HTTP | [Serving OpenAPI](reference/openapi.md), [Board OpenAPI](reference/board-api.md) |
| Events | [Reactive AsyncAPI](reference/asyncapi.md), fetch-SSE in serving OpenAPI |
| Arrow clients | [Flight SQL and ADBC](reference/flight.md) |
| Native callers | [Signed protocol](reference/native.md), [language SDKs](reference/sdks.md) |
| Application lifecycle | [Installation and bootstrap](../contracts/APPLICATION_INSTALLATION_V1.md) |

The [roadmap](roadmap/README.md) separates completed profiles from planned work.
Experimental, bounded implementations do not imply every target requirement is
supported. Each foundation links current interfaces before deeper design intent.

## Foundations

| Document | Owns |
| --- | --- |
| [Scope](SCOPE.md) | Goals, application boundaries, and open questions |
| [Architecture](ARCHITECTURE.md) | Layers, dependency direction, and component map |
| [Glossary](GLOSSARY.md) | Official names and shared terminology |
| [Transit](TRANSIT.md) | Processes, PIDs, legal sequences, ownership, and replay |
| [Caller model](CLIENT.md) | Application computation, bindings and implemented language SDK contracts |
| [Public SDK design](SDK.md) | Shared API decisions and implemented [Python](sdk/PYTHON.md), [TypeScript](sdk/TYPESCRIPT.md) and [Rust](sdk/RUST.md) contracts, applications and recovery |
| [Security](SECURITY.md) | Identity, authorization, revocation, and trust boundaries |
| [Streams](STREAMS.md) | Mailboxes, ordering, durable admission, and delivery |
| [State](STATE.md) | Durable resources, process associations, KV/Table boundary, and state lifetimes |
| [Documents](DOCUMENTS.md) | Qualified structured/text model, publication prerequisite, acceptance and unified-query handoff |
| [Tables](TABLES.md) | Station Table operations, Arrow results, materialization and transaction scope |
| [Fuze](FUZE.md) | Zig query engine across KV/Table/Document, source adapters, planning and bounded execution |
| [Query language](QUERY_LANGUAGE.md) | Relational and dataframe surfaces over Fuze's one plan; DDL/DML mapping and the connector/transport namespace idea |
| [Arrow](ARROW.md) | IPC/C interfaces, Flight/Flight SQL and ADBC integration with Fuze |
| [Serving](SERVING.md) | Inbound service/route, identity, admission and response contracts; qualified M19 HTTP profile for applications and Board |
| [Reactive APIs](REACTIVE_API.md) | M20 Table SSE/WebSocket profile, shared sessions/subscriptions, resumable invalidations and generated OpenAPI/AsyncAPI contracts |
| [Reactive interfaces](REACTIVE.md) | Qualified Table live views, exact snapshot refresh and visible freshness; source/placement limits |
| [Reactive applications](REACTIVE_APPLICATIONS.md) | Qualified M23 declaration/publication boundary and selected generated application migration; broader design limits |
| [Retention](RETENTION.md) | Application lifetime contracts, compaction, and reclamation |
| [Board](BOARD.md) | Inspection UI/API, growing atlas, optional Table workspace and observation semantics |
| [Observability](OBSERVABILITY.md) | Board/Transit instrumentation, correlation, signal semantics, and resource limits |
| [Station](STATION.md) | Behaviors, language bindings, SDK runners, Tables, supervision, and registries |
| [Connectors](CONNECTORS.md) | Shared effect/attempt/reconciliation contract, transport/connector/integration tiers and qualified finite HTTP capture |
| [Flow control](FLOW_CONTROL.md) | Application admission credit pattern, and its boundary against transport flow control |
| [gRPC](GRPC.md) | Qualified finite RPC connector: typed calls, streaming authority, transcripts and recovery |
| [Deployment](DEPLOYMENT.md) | Runtime bindings, recovery, isolation, and portability |
| [Ursula](URSULA.md) | Storage-provider choice and authority boundary |
| [Conformance](CONFORMANCE.md) | Adversarial obligations and limits on guarantees |
| [Testing](TESTING.md) | Verification layers, generated/fault/formal checks, scale evidence and CI cost/selection strategy |
| [Roadmap](roadmap/README.md) | Milestones and observable exit criteria |
| [UI/UX design items](design/README.md) | Per-item review sequences, numbered interface proposals, visual studies, outcomes and open questions |

For hands-on work, use [development](DEVELOPMENT.md) and the
[component READMEs](ARCHITECTURE.md#planned-monorepo-decomposition).
The downstream [Rey workload model](workloads/REY.md) records application demand
scenarios, capacity arithmetic and their implications for qualification.

## Where documentation lives

| Location | Content |
| --- | --- |
| Root [README](../README.md) | Orientation, status, and a short runnable start |
| `docs/` foundations | Scope, cross-component concepts/design, invariants, tradeoffs and explicit implementation status |
| `docs/guides/`, `docs/reference/` | User journeys, cross-interface references and links to the authoritative component/wire owners |
| [apps/transit-docs/](../apps/transit-docs/README.md) | Docusaurus configuration, navigation, generated API rendering, styling and site verification; consumes source Markdown directly |
| [docs/roadmap/](roadmap/README.md) | Milestone index and individual scope, design decisions, qualification criteria and status files |
| [docs/design/](design/README.md) | UI/UX reviews; one directory, linear D-numbered review sequence and summary table per item |
| Package/app READMEs | Purpose, public entry points, dependencies, quick start, limits, and links to deeper guides |
| Package/app `docs/` | Substantial component configuration, caller workflows, storage mappings, and operational details |
| [Pre-Station review](reviews/PRE_STATION.md), [post-M9 review](reviews/PRE_M10.md) | Dated comparisons of documented guarantees, implementation, evidence, and upcoming gates |
| [contracts/](../contracts) | Exact versioned wire/provider specifications and generated schema |
| [examples/](../examples/README.md) | Complete calling programs and how to run them |
| [launchers/](../launchers/README.md) | Running and inspecting persistent development environments; lifecycle and trust limits |
| [tests/](../tests/README.md) | Proof commands, failure schedules, results, and qualification limits |
| [deploy/reference/](../deploy/reference/README.md) | Reference setup, prerequisites, and teardown |
| [charts/transit/](../charts/transit/README.md) | Transit Helm resources, values, bootstrap and deployment limits |
| [nix/](../nix/README.md), [tasks/](../tasks/README.md) | Toolchain maintenance and command reference |
| [AGENTS.md](../AGENTS.md) | Working instructions and required reading |

Document a fact where it is owned and link to it from the broader design.
The site catalog must include every top-level foundational page. Add a task-first
entry when a new interface becomes usable, with runnable commands and exact
profile limits. Keep configuration detail in its component guide and include that
guide directly in the site where useful. OpenAPI/AsyncAPI pages render the owning
generated specifications; never maintain another handwritten endpoint schema.
Repository Markdown must remain readable without the site. Published navigation
maps included Markdown links to site routes and other repository links to source. Keep
technical choices and rationale alongside that topic. Preserve failure findings
and validation limits when moving details; avoid duplicate specifications.
Future components stay in the design docs until they have real implementation.
Review findings reference their code/contract owners and distinguish missing
capabilities from defects. They do not replace current contracts or milestone plans.

## Design review workflow

Use the [UI/UX design-item index](design/README.md) for interface proposals that
need visual or interaction review. System architecture belongs in its owning
topic documents, with scope, decisions and qualification in the roadmap milestones.
Each UI/UX item has its own directory and linear review sequence.
Each numbered document owns its question, proposal, figures, outcome, open
questions and evidence limits. Follow the
[structure and status rules](design/README.md#review-document-structure) and
start from the shared [template](design/TEMPLATE.md). Keep one review summary
table in each item's README, stable D IDs within the item and previous/next
links. Place substantial new iterations in that item's next numbered review
rather than named follow-up files. Qualify references across items with the
item name, such as **board-atlas D2**.

Review acceptance records a design choice. Product boundaries stay in their
owning foundational documents, and implementation scope and proof stay in the
roadmap and test guide.

## Planning a change

1. Define its use case and limits in scope, then identify the architecture owner.
2. Update that owner's design and adversarial requirements before claiming a guarantee.
3. Tie implementation to a roadmap milestone with observable exit criteria.
   Insert newly scoped work into the [linear sequence](roadmap/README.md#maintaining-the-sequence)
   and renumber upcoming milestones and their references.
4. Update component usage and proof evidence with the code. Mark proposals and
   unsupported cases explicitly; update the glossary when terminology changes.

Keep [decision guidance](decisions/README.md) and its template for future use;
we are not maintaining separate decision records at this stage.
