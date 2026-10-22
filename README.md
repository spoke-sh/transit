# Transit

[![CI](https://github.com/spoke-sh/transit/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/spoke-sh/transit/actions/workflows/ci.yml)

Transit is programmable data infrastructure for applications. It stores and
queries tables, key-value data and collaborative documents, and provides durable
execution for transforming data and coordinating work around it.

Its declarative interfaces describe data and computation; its execution system
preserves accepted changes, progress and outcomes across failures.

Start with the data your application needs, what you want to compute from it,
and the policies governing its use. The [data model](docs/handbook/reference/data-model.md)
connects those decisions to their interfaces and observable outcomes. Durable
processes, messaging and storage supply the mechanisms underneath that model.

## Work with data

| Task | Start here |
| --- | --- |
| Define, query and evolve a dataset | [Local quickstart](docs/handbook/guides/quickstart.md), [Tables](docs/handbook/reference/tables.md) |
| Choose a data representation | [Tables, KV and Documents](docs/handbook/reference/data-model.md#choose-a-data-representation) |
| Compute a result or follow changes | [Query lifetimes](docs/handbook/reference/data-model.md#choose-a-computation-lifetime), [reactive views](docs/handbook/reference/reactive.md) |
| Govern access and lifetime | [Authorization](docs/handbook/reference/security.md), [retention and capacity](docs/handbook/reference/retention.md) |
| Inspect definitions, results and progress | [Lifecycle evidence](docs/handbook/reference/data-model.md#inspect-whether-a-declaration-is-being-fulfilled), [Board](docs/handbook/guides/inspect-board.md) |
| Add application-specific transformations or effects | [Build an application](docs/handbook/guides/applications.md), [connectors](docs/handbook/reference/connectors.md) |

The Table lifecycle is available through configured SQL and typed catalog callers.
KV and Documents use client/service APIs; their SQL declarations compile offline.
Named captured and maintained relational computations use typed Zig owners with
explicit activation and host scheduling. SQL views/subscriptions and a common
declaration lifecycle across all these objects remain future work. The
[capability map](docs/handbook/reference/data-model.md#declarations-and-current-interfaces)
keeps these boundaries explicit.

The organizing question for development is:

> Can someone describe the data, computation and policies they need, then inspect
> whether Transit is fulfilling that declaration?

The [roadmap](docs/roadmap/README.md) turns the remaining gaps into implementation
work. [Choose an interface](docs/handbook/guides/choose-interface.md) for the
operations, types and lifecycle you need today.

## Documentation

Read the [published handbook](https://spoke-sh.github.io/transit/), starting with
[What is Transit?](docs/handbook/guides/introduction.md), the
[data model](docs/handbook/reference/data-model.md) and
[your first dataset](docs/handbook/guides/quickstart.md).

| Reference | Entry point |
| --- | --- |
| Data and policies | [Data model](docs/handbook/reference/data-model.md), [security](docs/handbook/reference/security.md), [retention](docs/handbook/reference/retention.md) |
| Query language | [SQL](docs/handbook/reference/sql.md) |
| Commands and recovery | [Transit CLI](docs/handbook/reference/cli.md) |
| SQL connections | [Server-managed sessions](docs/handbook/reference/sql-sessions.md), [PostgreSQL and MySQL](docs/handbook/reference/database-protocols.md) |
| HTTP APIs | [Serving OpenAPI](docs/handbook/reference/openapi.md), [Board OpenAPI](docs/handbook/reference/board-api.md) |
| Reactive streams | [AsyncAPI](docs/handbook/reference/asyncapi.md) |
| Analytical clients | [Flight SQL and ADBC](docs/handbook/reference/flight.md) |
| Application clients | [Language SDKs](docs/handbook/reference/sdks.md), [native protocol](docs/handbook/reference/native.md) |
| Workload design | [Architectural priorities](docs/handbook/reference/workloads.md), [performance and improvement plan](docs/handbook/reference/performance.md), [declarative benchmarks](docs/handbook/reference/benchmarks.md) |
| System internals | [Architecture, rationale and evidence](docs/handbook/internals/README.md), [scientific standard](docs/handbook/internals/standard.md) |
| Interface coverage | [Usage, contracts and internals map](docs/handbook/reference/interfaces.md), [schema downloads](docs/handbook/reference/contracts.md) |
| Example recipes | [SQL, Python, TypeScript, Rust and Zig](docs/handbook/guides/workload-examples.md) |

The [documentation index](docs/README.md) explains navigation and source ownership;
the [site guide](docs/handbook/README.md) covers local previews.

## Develop the repository

Use the [contributor guide](docs/handbook/guides/contributing.md) for source ownership and
validation responsibilities, the [toolchain setup](nix/README.md) to prepare the
checkout, and the [launcher guide](launchers/README.md) for development lifecycle
commands. To run an installed bundle, follow the [local quickstart](docs/handbook/guides/quickstart.md)
with `transit` on `PATH`.

Copy [transit.yaml.example](transit.yaml.example) to `transit.yaml` for an annotated
local configuration covering services, SQL gateways, accounts, TLS and limits.
Every setting is commented out; uncomment only the keys you want to override,
including their parent sections. The repository ignores `transit.yaml`;
PostgreSQL and MySQL remain disabled until selected.
Follow the [configuration reference](docs/handbook/reference/configuration.md)
and [SQL access guide](apps/transit-cli/docs/sql.md) when enabling them.

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/handbook/reference/components.md): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete applications and public SDK callers.
- [Proof coverage](tests/README.md): checks, failure schedules, and qualification limits.
- [Agent instructions](AGENTS.md): how to change this repository.

For downstream application development, the [local installation guide](apps/transit-cli/docs/applications.md)
covers separately built Zig workers, scoped caller connections and compatible
replacement through a language-neutral bootstrap contract.
