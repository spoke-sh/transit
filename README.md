# Transit

[![CI](https://github.com/spoke-sh/transit/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/spoke-sh/transit/actions/workflows/ci.yml)

**Transit is a declarative, versioned multi-model database, vectorized/incremental query engine (`Fuze`), and durable execution runtime (`Station`) written in Zig.**

You declare **data** (Tables, Key-Value maps, collaborative Documents, Streams, Queues, Property Graphs, and 2D/3D Spatial models), **computations** (point-in-time SQL queries, recoverable captured jobs, maintained incremental views, and stateful dataflows), and **policies** (scoped `policy_epoch` authorization, security-barrier Row-Level Security, unlimited-by-default retention, and resource budgets). Transit's runtime **activates** that data across a four-tier storage hierarchy (`TransitLog` write-ahead delta logs and immutable `.tseg` columnar segments), executes queries with five-state cell provenance (`value`, `null`, `missing`, `type_error`, `conflict`), and coordinates stateful processes (`Station`) and recorded external connector effects.

![Transit](docs/handbook/static/img/architecture/transit-machine.jpg)

Start with the data your application needs, what you want to compute from it, and the policies governing its use. The [published handbook](https://spoke-sh.github.io/transit/) connects those declarations to their public interfaces and observable outcomes, and [Internals](docs/handbook/internals/README.md) formalizes the underlying storage, query, state, and execution models.

## Documentation and Handbook

Read the [published handbook](https://spoke-sh.github.io/transit/), organized into seven pillars:

| Pillar | Primary entry points |
| --- | --- |
| **1. Overview & Quickstart** | [What is Transit?](docs/handbook/guides/introduction.md), [Architecture and scope](docs/handbook/reference/architecture.md), [Run Transit locally](docs/handbook/guides/quickstart.md), [Choose an interface](docs/handbook/guides/choose-interface.md), [Workload examples](docs/handbook/guides/workload-examples.md) |
| **2. Data Model & Type System** | [Data, computation and policies](docs/handbook/reference/data-model.md), [Tables](docs/handbook/reference/tables.md), [Documents](docs/handbook/reference/documents.md), [KV resources](docs/handbook/reference/state.md), [Streams](docs/handbook/reference/streams.md), [Data types and cell states](docs/handbook/reference/sql/types.md), [Storage boundary](docs/handbook/reference/storage.md) |
| **3. Query Engine (`Fuze`) & SQL** | [Query execution and recovery](docs/handbook/reference/queries.md), [SQL reference](docs/handbook/reference/sql.md), [Grammar surface](docs/handbook/reference/sql/grammar-surface.md), [Table joins and aggregation](docs/handbook/reference/sql/relational.md), [Transactions and savepoints](docs/handbook/reference/sql/transactions.md), [`FOR SYSTEM_TIME AS OF`](docs/handbook/reference/sql/as-of.md) |
| **4. Durable Execution (`Station`) & Apps** | [Processes and turns](docs/handbook/reference/processes.md), [Build your first application](docs/handbook/guides/applications.md), [Effects, HTTP and gRPC connectors](docs/handbook/reference/connectors.md), [Application installation and migration](docs/handbook/reference/applications.md) |
| **5. Client Protocols, CLI & Gateways** | [Transit CLI](docs/handbook/reference/cli.md), [SQL sessions](docs/handbook/reference/sql-sessions.md), [PostgreSQL and MySQL wire gateways](docs/handbook/reference/database-protocols.md), [Flight SQL and ADBC](docs/handbook/reference/flight.md), [Serving OpenAPI](docs/handbook/reference/openapi.md), [Reactive AsyncAPI](docs/handbook/reference/asyncapi.md), [Language SDKs](docs/handbook/reference/sdks.md), [Native protocol](docs/handbook/reference/native.md) |
| **6. Security, Governance & Operations** | [Identity and permissions](docs/handbook/reference/security.md), [Retention and capacity](docs/handbook/reference/retention.md), [Inspect with Board](docs/handbook/guides/inspect-board.md), [Configuration](docs/handbook/reference/configuration.md), [Deployment and recovery](docs/handbook/reference/deployment.md), [Packages and containers](docs/handbook/reference/distribution.md), [Observability](docs/handbook/reference/observability.md), [Benchmarks](docs/handbook/reference/benchmarks.md) |
| **7. Internals, Verification & Contracts** | [System Internals](docs/handbook/internals/README.md), [Scientific standard](docs/handbook/internals/standard.md), [Guarantees and verification limits](docs/handbook/reference/verification.md), [Interface and contract map](docs/handbook/reference/interfaces.md), [Schema downloads](docs/handbook/reference/contracts.md) |

The [documentation index](docs/README.md) explains navigation and source ownership; the [site guide](docs/handbook/README.md) covers local previews.

## Develop the Repository

Use the [contributor guide](docs/handbook/guides/contributing.md) for source ownership and validation responsibilities, the [toolchain setup](nix/README.md) to prepare the checkout, and the [launcher guide](launchers/README.md) for development lifecycle commands. To run an installed bundle, follow the [local quickstart](docs/handbook/guides/quickstart.md) with `transit` on `PATH`.

Copy [transit.yaml.example](transit.yaml.example) to `transit.yaml` for an annotated local configuration covering services, SQL gateways, accounts, TLS, and limits. Every setting is commented out; uncomment only the keys you want to override, including their parent sections. The repository ignores `transit.yaml`; PostgreSQL and MySQL remain disabled until selected. Follow the [configuration reference](docs/handbook/reference/configuration.md) and [SQL access guide](apps/transit-cli/docs/sql.md) when enabling them.

## Find Your Way

- [Component map](docs/handbook/reference/components.md): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete applications and public SDK callers.
- [Proof coverage](tests/README.md) and [qualification ledger](docs/history/qualification/README.md): executable checks, failure schedules, and verification limits.
- [Roadmap](docs/roadmap/README.md): milestone sequence, architectural reviews, and acceptance gates.
- [Agent instructions](AGENTS.md): engineering rules for working on this repository.

For downstream application development, the [local installation guide](apps/transit-cli/docs/applications.md) covers separately built Zig workers, scoped caller connections, and compatible replacement through a language-neutral bootstrap contract.
