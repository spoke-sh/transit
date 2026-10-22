# Transit

[![CI](https://github.com/spoke-sh/transit/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/spoke-sh/transit/actions/workflows/ci.yml)

Transit provides durable processes, messaging and state for applications.

Use the [CLI](docs/handbook/reference/cli.md) to run Transit and install applications,
[SQL](docs/handbook/reference/sql.md) to query KV, Table and Document data, and
[language SDKs](docs/handbook/reference/sdks.md) to build workers and callers.
Integrate through [HTTP](docs/handbook/reference/openapi.md) and
[reactive APIs](docs/handbook/reference/asyncapi.md), connect analytical tools with
[Flight SQL and ADBC](docs/handbook/reference/flight.md), and inspect the system in
[Board](docs/handbook/guides/inspect-board.md).
The [database gateway](apps/transit-sql-gateway/README.md) provides PostgreSQL and
MySQL autocommit access to authorized Table catalogs. Follow the
[local connection guide](apps/transit-cli/docs/sql.md) to enable either protocol.

The [interface guide](docs/handbook/guides/choose-interface.md) describes supported
operations, types and compatibility rules for each entry point.

## Documentation

Start with [What is Transit?](docs/handbook/guides/introduction.md),
[Run Transit locally](docs/handbook/guides/quickstart.md), or
[Build your first application](docs/handbook/guides/applications.md).

| Reference | Entry point |
| --- | --- |
| Query language | [SQL](docs/handbook/reference/sql.md) |
| Commands and recovery | [Transit CLI](docs/handbook/reference/cli.md) |
| HTTP APIs | [Serving OpenAPI](docs/handbook/reference/openapi.md), [Board OpenAPI](docs/handbook/reference/board-api.md) |
| Reactive streams | [AsyncAPI](docs/handbook/reference/asyncapi.md) |
| Analytical clients | [Flight SQL and ADBC](docs/handbook/reference/flight.md) |
| Application clients | [Language SDKs](docs/handbook/reference/sdks.md), [native protocol](docs/handbook/reference/native.md) |
| Workload design | [Architectural priorities](docs/handbook/reference/workloads.md), [performance and improvement plan](docs/handbook/reference/performance.md), [declarative benchmarks](docs/handbook/reference/benchmarks.md) |
| System internals | [Architecture, rationale and evidence](docs/handbook/internals/README.md), [scientific standard](docs/handbook/internals/standard.md) |
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
