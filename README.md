# Transit

[![CI](https://github.com/rupurt/rey/actions/workflows/ci.yml/badge.svg?branch=main&event=push)](https://github.com/rupurt/rey/actions/workflows/ci.yml)

An agentic streaming kernel: a foundational execution protocol enforced by
durable message sequences.

Transit gives programs durable processes, ordered mailboxes, and associated state.
Application code runs in callers; the kernel governs what can commit and how work
recovers. [Board](docs/BOARD.md) makes that history inspectable. [Station](docs/STATION.md)
provides behaviors, supervision, registries and typed Tables through Zig and
shared language bindings. [Fuze](docs/FUZE.md) queries declared KV, Table and accepted Document sources
through one versioned plan and nested Arrow result model.

This monorepo contains Transit's Zig libraries and services, TypeScript/Vite+
frontends, and development tooling. Ursula supplies durable storage; Kubernetes
with Agent Substrate is the reference deployment. **Rey is the intended downstream
trading application**, using the same primitives as other workloads.

**Status:** experimental kernel, Board, launchers, instrumentation, and bounded
KV state are implemented through M8. Station (M9) adds a bounded programming
profile with durable calls, Tables, Arrow queries and language clients. The
[verification and scale foundations milestone](docs/roadmap/M10.md) qualifies an
explicit growing profile and measured CI budgets.
[Idiomatic language SDKs](docs/roadmap/M11.md) add qualified raw/Station APIs,
installed examples and public interoperability across all target languages on Linux x86_64.
[M12](docs/roadmap/M12.md) adds a qualified Table SQL compiler over Fuze's existing
plan, with independent parser/result checks and scoped Lean rewrite proofs.
[M13](docs/roadmap/M13.md) adds a signed Table query shell, runnable query hosts
and Board's growing atlas/workspace with a separate query capability.
[M14](docs/roadmap/M14.md) adds bounded immutable publication;
[M15](docs/roadmap/M15.md) and [M16](docs/roadmap/M16.md) qualify the first finite
HTTP and RPC connectors over shared capture and explicit outcome policies.
[M17](docs/roadmap/M17.md) adds structured Documents and collaborative text.
[M18](docs/roadmap/M18.md) extends querying across those state sources, with all
ten SDKs, explicit SQL ingress and bounded current-authority result readers.
[M19](docs/roadmap/M19.md) qualifies shared HTTP serving, durable application
admission, concurrent Board reads and recovery across native, Compose and Substrate placements.
[M20–M21](docs/REACTIVE.md) add resumable Table invalidations and verified reactive
views; [M22](docs/roadmap/M22.md) qualifies finite Flight SQL/ADBC access.
[M23](docs/roadmap/M23.md) implements declarative Board/application publication
and migration, and [M24](docs/roadmap/M24.md) adds a local server and SQL terminal
with shared authorized completion. Their selected profiles pass focused and
clean-checkout qualification.
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

For downstream application development, the [local installation guide](apps/transit-cli/docs/applications.md)
covers separately built Zig workers, scoped caller connections and compatible
replacement through a language-neutral bootstrap contract.
