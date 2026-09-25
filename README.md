# Transit

[![CI](https://github.com/rupurt/rey/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/rupurt/rey/actions/workflows/ci.yml)

An agentic streaming kernel: a foundational execution protocol enforced by
durable message sequences.

Transit gives programs durable processes, ordered mailboxes, and associated state.
Application code runs in callers; the kernel governs what can commit and how work
recovers. [Board](docs/BOARD.md) makes that history inspectable. [Station](docs/STATION.md)
provides behaviors, supervision, registries and typed Tables through Zig and
shared language bindings. [Fuze](docs/FUZE.md) queries those Tables and returns
Arrow results; KV and Document querying comes next.

This monorepo contains Transit's Zig libraries and services, TypeScript/Vite+
frontends, and development tooling. Ursula supplies durable storage; Kubernetes
with Agent Substrate is the reference deployment. **Rey is the intended downstream
trading application**, using the same primitives as other workloads.

**Status:** experimental kernel, Board, launchers, instrumentation, and bounded
KV state are implemented through M8. Station (M9) adds a bounded programming
profile with durable calls, Tables, Arrow queries and language clients. The
next milestone establishes [verification and scale foundations](docs/roadmap/M10.md),
followed by [idiomatic language SDKs](docs/roadmap/M11.md).
The [roadmap](docs/roadmap/README.md) records supported profiles and qualification limits.

## Get started

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
Compose, and the Kubernetes reference. Use [development](docs/DEVELOPMENT.md)
for build profiles and checks, or run `just` to browse tasks.
For the multi-process programming example, follow the
[Station ledger guide](examples/station-ledger/docs/running.md).

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/ARCHITECTURE.md#planned-monorepo-decomposition): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete Zig callers using the public client.
- [Proof coverage](tests/README.md): checks, failure schedules, and qualification limits.
- [Agent instructions](AGENTS.md): how to change this repository.
