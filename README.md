# Rey

Home of Transit, an agentic streaming runtime built around a foundational
execution protocol enforced by durable message sequences.

[Transit](docs/TRANSIT.md) is the reusable streaming runtime subsystem: the
kernel, services, clients, storage/runtime adapters, inspection surface, and planned
framework. Each process has a durable PID and an ordered mailbox; its recorded
sequence governs ownership, progress, and effects.
[Station](docs/STATION.md) is the planned OTP-inspired framework for GenServer
behaviors, supervision, and registries. [Board](docs/BOARD.md) is the
inspection UI and API for operators and agents, starting with kernel primitives.
Their artifacts use the `transit-station` and `transit-board` name families.
Trading is one intended application; the primitives are generic.

Rey is a monorepo of Zig libraries and executables, with TypeScript and Vite+
for frontends. Ursula supplies durable storage and transport. Kubernetes
with Agent Substrate is the reference runtime; protocol identities and guarantees
remain independent of those providers.

**Status:** experimental M1 is implemented, including signed ingress, fenced
turns, recovery, bounded effect reconciliation, and opt-in retention. Application
code runs in callers; the node validates the protocol and stores opaque state.
Board provides an embedded inspection UI and OpenAPI service, qualified against
the Kubernetes/Substrate reference. Station, the HTTP connector, and trading applications follow. See the
[roadmap](docs/roadmap/README.md) and [proof coverage and limits](tests/README.md).

## Get started

Install Nix with flakes and `nix-command` enabled, then:

```sh
nix develop
just doctor
just check
just transit-board::install
just launchers::local::up
```

Open the printed Board URL and sign in with the key from the printed file path.
The [launchers](launchers/README.md) run a persistent local stack, a Docker Compose
waypoint, and the Kubernetes/Substrate reference. Use `just launchers::local::down`
or Ctrl-C to stop local services while preserving your data. Local and Compose
`up` stream logs in the foreground; pass `--detach` for background use.
`just launchers` lists the groups.

After editing code, run `just launchers::local::update board` (or `counter`).
Use the same `build`, `update` and `restart` tasks in Compose and reference;
the [development loop](launchers/README.md#incremental-development) explains
candidate builds and same-PID workload upgrades.

Deployment definitions are checked in: [Process Compose](process-compose.yaml),
[Docker Compose](docker-compose.yaml), and the [Transit Helm chart](charts/transit/README.md).

The [examples](examples/README.md) also offer disposable calling-program demos.
`just build` lists the build profiles; `just build::debug` builds executables.
`just ci` runs the local checks and proofs. Frontend dependencies are required by
both the default executable build and CI. Run `just` to browse all tasks.

## Find your way

- [Documentation](docs/README.md): scope, architecture, terminology, and design contracts.
- [Component map](docs/ARCHITECTURE.md#planned-monorepo-decomposition): libraries, apps, and their READMEs.
- [Development](docs/DEVELOPMENT.md): toolchain, commands, tests, and reference deployment.
- [Agent instructions](AGENTS.md): how to change this repository.
