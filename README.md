# Rey

An agentic streaming kernel: a foundational execution protocol enforced by
durable message sequences.

[Transit](docs/TRANSIT.md) is the kernel. Each process has a durable PID and an
ordered mailbox; its recorded sequence governs ownership, progress, and effects.
[Station](docs/STATION.md) is the planned OTP-inspired framework for GenServer
behaviors, supervision, and registries. [Board](docs/BOARD.md) is the planned
inspection UI and API for operators and agents, starting with kernel primitives.
Trading is one intended application; the primitives are generic.

Rey is a monorepo of Zig libraries and executables, with TypeScript and Vite+
for future frontends. Ursula supplies durable storage and transport. Kubernetes
with Agent Substrate is the reference runtime; protocol identities and guarantees
remain independent of those providers.

**Status:** experimental M1 is implemented, including signed ingress, fenced
turns, recovery, bounded effect reconciliation, and opt-in retention. Application
code runs in callers; the node validates the protocol and stores opaque state.
Board is next; Station, the HTTP connector, and trading applications follow. See the
[roadmap](docs/roadmap/README.md) and [proof coverage and limits](tests/README.md).

## Get started

Install Nix with flakes and `nix-command` enabled, then:

```sh
nix develop
just doctor
just check
just examples::run counter
```

The [examples](examples/README.md) provision fresh local disk-backed infrastructure
and run complete Zig calling programs. `just build` builds platform executables;
`just ci` runs the local test suite. Run `just` to browse tasks.

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/ARCHITECTURE.md#planned-monorepo-decomposition): libraries, apps, and their READMEs.
- [Development](docs/DEVELOPMENT.md): toolchain, commands, tests, and reference deployment.
- [Agent instructions](AGENTS.md): how to change this repository.
