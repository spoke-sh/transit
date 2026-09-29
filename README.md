# Transit

[![CI](https://github.com/rupurt/rey/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/rupurt/rey/actions/workflows/ci.yml)

An agentic streaming kernel: a foundational execution protocol enforced by
durable message sequences.

Transit gives programs durable processes, ordered mailboxes, and associated state.
Application code runs in callers; the kernel governs what can commit and how work
recovers. [Board](docs/guides/inspect-board.md) makes that history inspectable. [Station](docs/reference/station.md)
provides behaviors, supervision, registries and typed Tables through Zig and
shared language bindings. [Fuze](docs/reference/queries.md) queries declared KV, Table and accepted Document sources
through one versioned plan and nested Arrow result model.

This monorepo contains Transit's Zig libraries and services, TypeScript/Vite+
frontends, and development tooling. Ursula supplies durable storage; Kubernetes
with Agent Substrate is the reference deployment. **Rey is the intended downstream
trading application**, using the same primitives as other workloads.

**Status:** experimental. The implemented profiles cover durable processes and
state, Station SDKs, HTTP/gRPC connectors, KV/Table/Document queries, reactive
APIs, finite Flight SQL and local application installation. Each has explicit
bounds and separately recorded qualification; see the [interface profiles](docs/guides/choose-interface.md).

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

Preview the Docusaurus site with `nix develop`, `just transit-docs::install` and
`just transit-docs::dev`. The [documentation index](docs/README.md) and
[site guide](apps/transit-docs/README.md) explain navigation and source ownership.

## Develop the repository

For the current resource-backed local stack, use Linux with synchronized time
and Nix with flakes and `nix-command` enabled:

```sh
nix develop
just doctor
just transit-board::install
just check
just launchers::local::up
```

Open the printed Board URL. Everyone who can reach Board can inspect its configured
scope; run it on a private development network. Logs stream in the foreground;
Ctrl-C stops services and preserves data.

The [launcher guide](launchers/README.md) covers host/port settings, updates,
Compose, and the Kubernetes reference. Use [development](docs/guides/contributing.md)
for build profiles and checks, or run `just` to browse tasks.
For the multi-process programming example, follow the
[Station ledger guide](examples/station-ledger/docs/running.md).

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/reference/components.md): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete Zig callers using the public client.
- [Proof coverage](tests/README.md): checks, failure schedules, and qualification limits.
- [Agent instructions](AGENTS.md): how to change this repository.

For downstream application development, the [local installation guide](apps/transit-cli/docs/applications.md)
covers separately built Zig workers, scoped caller connections and compatible
replacement through a language-neutral bootstrap contract.
