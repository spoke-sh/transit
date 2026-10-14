# Transit

[![CI](https://github.com/rupurt/rey/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/rupurt/rey/actions/workflows/ci.yml)

Transit provides durable processes, messaging and state for applications.

Use the [CLI](docs/reference/cli.md) to run Transit and install applications,
[SQL](docs/reference/sql.md) to query KV, Table and Document data, and
[language SDKs](docs/reference/sdks.md) to build workers and callers.
Integrate through [HTTP](docs/reference/openapi.md) and
[reactive APIs](docs/reference/asyncapi.md), connect analytical tools with
[Flight SQL and ADBC](docs/reference/flight.md), and inspect the system in
[Board](docs/guides/inspect-board.md).
The [database gateway](apps/transit-sql-gateway/README.md) provides PostgreSQL and
MySQL autocommit access to authorized Table catalogs.

The [interface guide](docs/guides/choose-interface.md) describes supported
operations, types and compatibility rules for each entry point.

## Documentation

Start with [What is Transit?](docs/guides/introduction.md),
[Run Transit locally](docs/guides/quickstart.md), or
[Build your first application](docs/guides/applications.md).

| Reference | Entry point |
| --- | --- |
| Query language | [SQL](docs/reference/sql.md) |
| Commands and recovery | [Transit CLI](docs/reference/cli.md) |
| HTTP APIs | [Serving OpenAPI](docs/reference/openapi.md), [Board OpenAPI](docs/reference/board-api.md) |
| Reactive streams | [AsyncAPI](docs/reference/asyncapi.md) |
| Analytical clients | [Flight SQL and ADBC](docs/reference/flight.md) |
| Application clients | [Language SDKs](docs/reference/sdks.md), [native protocol](docs/reference/native.md) |
| Workload design | [Architectural priorities](docs/reference/workloads.md), [performance and improvement plan](docs/reference/performance.md), [declarative benchmarks](docs/reference/benchmarks.md) |
| System internals | [Architecture, rationale and evidence](docs/internals/README.md), [scientific standard](docs/internals/standard.md) |
| Example recipes | [SQL, Python, TypeScript, Rust and Zig](docs/guides/workload-examples.md) |

The [documentation index](docs/README.md) explains navigation and source ownership;
the [site guide](apps/transit-docs/README.md) covers local previews.

## Develop the repository

Use the [contributor guide](docs/guides/contributing.md) for source ownership and
validation responsibilities, the [toolchain setup](nix/README.md) to prepare the
checkout, and the [launcher guide](launchers/README.md) for development lifecycle
commands. To run an installed bundle, follow the [local quickstart](docs/guides/quickstart.md)
with `transit` on `PATH`.

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/reference/components.md): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete applications and public SDK callers.
- [Proof coverage](tests/README.md): checks, failure schedules, and qualification limits.
- [Agent instructions](AGENTS.md): how to change this repository.

For downstream application development, the [local installation guide](apps/transit-cli/docs/applications.md)
covers separately built Zig workers, scoped caller connections and compatible
replacement through a language-neutral bootstrap contract.
