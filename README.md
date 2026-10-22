# Transit

[![CI](https://github.com/spoke-sh/transit/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/spoke-sh/transit/actions/workflows/ci.yml)

Transit is programmable, versioned data infrastructure for applications. You
declare **data** (Tables, Key-Value maps, collaborative Documents, and external
datasets), **computations** (point-in-time queries, live subscriptions,
maintained derived views, and stateful dataflows), and **policies** (scoped
authorization, retention, capacity, and placement). Transit's runtime **activates**
that data through authorized publication, query execution and durable processes
(`Station`); connectors coordinate recorded external effects. The installed
runtime persists native history and immutable state through Ursula. Native
write-ahead logs, hybrid OLTP/OLAP segments and automatic incremental activation
are the target storage and computation architecture; their component libraries
do not yet replace the installed data path.

Start with the data your application needs, what you want to compute from it,
and the policies governing its use. The [data model](docs/handbook/reference/data-model.md)
connects those declarations to their public interfaces and observable outcomes,
and [Internals](docs/handbook/internals/README.md) formalizes the underlying
system, storage, query, state, and execution models.

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

- [Component map](docs/handbook/reference/components.md): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete applications and public SDK callers.
- [Proof coverage](tests/README.md): checks, failure schedules, and qualification limits.
- [Agent instructions](AGENTS.md): how to change this repository.

For downstream application development, the [local installation guide](apps/transit-cli/docs/applications.md)
covers separately built Zig workers, scoped caller connections and compatible
replacement through a language-neutral bootstrap contract.
