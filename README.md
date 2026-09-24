# Transit

An agentic streaming kernel: a foundational execution protocol enforced by
durable message sequences.

Transit gives programs durable processes, ordered mailboxes, and associated state.
Application code runs in callers; the kernel governs what can commit and how work
recovers. [Board](docs/BOARD.md) makes that history inspectable. [Station](docs/STATION.md)
will provide the higher-level interface for behaviors, supervision, and registries.

This monorepo contains Transit's Zig libraries and services, TypeScript/Vite+
frontends, and development tooling. Ursula supplies durable storage; Kubernetes
with Agent Substrate is the reference deployment. **Rey is the intended downstream
trading application**, using the same primitives as other workloads.

**Status:** experimental kernel, Board, launchers, instrumentation, and bounded
KV state are implemented through M7. Station is next. The
[roadmap](docs/roadmap/README.md) records the supported profiles; the
[pre-Station review](docs/reviews/PRE_STATION.md) identifies remaining gaps.

## Get started

For the current resource-backed local stack, use Linux with synchronized time
and Nix with flakes and `nix-command` enabled:

```sh
nix develop
just doctor
just check
just transit-board::install
just launchers::local::up
```

Open the printed Board URL. Everyone who can reach Board can inspect its configured
scope; run it on a private development network. Logs stream in the foreground;
Ctrl-C stops services and preserves data.

The [launcher guide](launchers/README.md) covers host/port settings, updates,
Compose, and the Kubernetes reference. Use [development](docs/DEVELOPMENT.md)
for build profiles and checks, or run `just` to browse tasks.

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/ARCHITECTURE.md#planned-monorepo-decomposition): libraries, apps, and their READMEs.
- [Examples](examples/README.md): complete Zig callers using the public client.
- [Proof coverage](tests/README.md): checks, failure schedules, and qualification limits.
- [Agent instructions](AGENTS.md): how to change this repository.
