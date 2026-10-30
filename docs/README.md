# Transit documentation

Read the [published handbook](https://spoke-sh.github.io/transit/), starting with
[What is Transit?](handbook/guides/introduction.md),
[Architecture and system planes](handbook/reference/architecture.md), the
[data model](handbook/reference/data-model.md) and
[your first dataset](handbook/guides/quickstart.md).

## Handbook structure

The handbook organizes Transit's database, `Fuze` query engine and `Station`
durable runtime into seven pillars:

1. **Overview and quickstart:** [What is Transit?](handbook/guides/introduction.md),
   [Architecture and system planes](handbook/reference/architecture.md),
   [Run Transit locally](handbook/guides/quickstart.md),
   [Choose an interface](handbook/guides/choose-interface.md) and
   [workload examples](handbook/guides/workload-examples.md).
2. **Data model and type system:** [Data, computation and policies](handbook/reference/data-model.md),
   [Tables](handbook/reference/tables.md), [Documents](handbook/reference/documents.md),
   [KV resources](handbook/reference/state.md), [Streams](handbook/reference/streams.md),
   [Data types, encodings and 5-state cells](handbook/reference/sql/types.md) and
   [Storage boundary](handbook/reference/storage.md).
3. **Query engine (`Fuze`) and SQL:** [Query execution and recovery](handbook/reference/queries.md),
   [SQL reference](handbook/reference/sql.md), [grammar surface](handbook/reference/sql/grammar-surface.md),
   joins, transactions, `FOR SYSTEM_TIME AS OF`, DDL and introspection.
4. **Durable execution (`Station`) and apps:** [Processes and turns](handbook/reference/processes.md),
   [Build your first application](handbook/guides/applications.md),
   [Connectors](handbook/reference/connectors.md) and
   [application installation](handbook/reference/applications.md).
5. **Client protocols, CLI and gateways:** [Transit CLI](handbook/reference/cli.md),
   [SQL sessions](handbook/reference/sql-sessions.md),
   [PostgreSQL and MySQL](handbook/reference/database-protocols.md),
   [Flight SQL and ADBC](handbook/reference/flight.md),
   [OpenAPI](handbook/reference/openapi.md), [AsyncAPI](handbook/reference/asyncapi.md)
   and [Native signed protocol](handbook/reference/native.md).
6. **Security, governance and operations:** [Identity and permissions](handbook/reference/security.md),
   [Retention](handbook/reference/retention.md), [Board](handbook/guides/inspect-board.md),
   [Deployment](handbook/reference/deployment.md), [Observability](handbook/reference/observability.md),
   [Performance](handbook/reference/performance.md) and [Benchmarks](handbook/reference/benchmarks.md).
7. **Verification, contracts and contributing:** [Guarantees and verification limits](handbook/reference/verification.md),
   [Contracts](handbook/reference/contracts.md), [Versioning](handbook/reference/versioning.md),
   [Components](handbook/reference/components.md) and [Contributing](handbook/guides/contributing.md).

Use [Internals](handbook/internals/README.md) for the computer-science models,
storage and query mechanisms, formal invariants and empirical evidence behind
those interfaces.

## Where documentation lives

| Section | Contents |
| --- | --- |
| [Guides](handbook/guides/) | Tutorials and workflows for using and operating Transit |
| [Reference](handbook/reference/interfaces.md) | Concepts, interfaces, configuration, limits and compatibility |
| [Internals](handbook/internals/README.md) | System models, three-plane architecture, `.tseg` storage, `Fuze` query engine, invariants and evidence |
| [SDKs](handbook/reference/sdks.md) | Language installation and API guides owned by `sdks/<language>/` |
| [Components](handbook/reference/components.md) | Package/app READMEs and component integration guides |
| [Contracts](../contracts/) | Exact wire formats, schemas, ABIs and shared fixtures |
| [Examples](../examples/README.md) | Complete applications and public API callers |
| [Tests](../tests/README.md) | Test ownership, commands, fixtures and verification navigation |
| [Qualification history](history/qualification/README.md) | Source-attributed experiments, outcomes and linked raw evidence |
| [Roadmap](roadmap/README.md) | Delivery scope, dependencies, acceptance criteria and status |
| [Design](design/README.md) | UI/UX proposals, visual studies and review outcomes |
| [History](history/README.md) | Earlier technical accounts and qualification records |
| [Handbook project](handbook/README.md) | Site tooling, previews, navigation and publication |

## Update and verify

Follow the [shared documentation instructions](AGENTS.md) and the scoped
[Handbook](handbook/AGENTS.md), [Design](design/AGENTS.md) or
[Roadmap](roadmap/AGENTS.md) instructions for the section you change.
The [site guide](handbook/README.md#validation-and-hosting) explains documentation
checks; the [contributor guide](handbook/guides/contributing.md) covers repository work.
