# Rey

An agentic streaming kernel: a foundational execution protocol enforced by
durable message sequences.

[Transit](docs/TRANSIT.md) is the kernel. Its execution primitive is a process,
identified by a durable PID and owning an ordered, logically unbounded mailbox
over durable streams. Transit governs legal transitions, ownership, progress,
and effects; the recorded sequence is the authority for execution and recovery.
[Station](docs/STATION.md) is the OTP-inspired framework above Transit, providing
GenServer behaviors, supervision, and name registries. Connectors will execute
effects such as HTTP requests and record their responses.

A PID survives worker recovery and migration. Registered names resolve to PIDs;
runtime bindings map those PIDs to deployment resources. Logical termination
or process expiry retires the PID, while eligible recovery preserves it.

Retention defaults to unlimited. Applications can opt into finite process,
mailbox, and history lifetimes or workload-scoped streams. Suspension and
activation respect that contract; expired processes cannot resume. See
[retention and resource lifetimes](docs/RETENTION.md).
Work authorized before a cutoff may settle within an explicitly bounded window.
Connectors own reconciliation policy; Transit enforces closure and rejects late
results. Closing an unknown outcome does not cancel work in the external system.

Authentication establishes caller identity at trusted ingress; Transit enforces
permissions alongside execution ownership. Station and infrastructure providers
compose that boundary. See the [security model](docs/SECURITY.md) and
[adversarial conformance requirements](docs/CONFORMANCE.md).

The kernel is generic. LLM calls, tools, reasoning loops, and trading belong in
layers above it. Trading remains an intended application of the primitives.

Rey is a multi-language monorepo of reusable Zig libraries, Zig executables, and
TypeScript/[Vite+](https://viteplus.dev/) frontends. Transit, Station, connectors,
and runtime adapters have distinct library and executable boundaries, described
in the [decomposition plan](docs/ARCHITECTURE.md#planned-monorepo-decomposition).
[Ursula](https://ursula.tonbo.io/) supplies durable stream storage and transport,
using [ursula-zig](https://github.com/rupurt/ursula-zig) from Zig. Kubernetes with
[Agent Substrate](https://github.com/agent-substrate/substrate) is the reference
deployment architecture; the protocol must remain portable to other runtimes.
The provider packages are `transit-backend-ursula` for storage and transport and
`transit-runtime-substrate` for execution placement and lifecycle integration.

**Status:** Transit has an experimental M1 implementation: signed ingress,
ordered turns and outboxes, fenced ownership, bounded effect reconciliation,
opt-in expiry, checkpoint/trim, and immutable-payload deletion. Application code
runs in Zig callers through [transit-client](docs/CLIENT.md); the node commits and
recovers opaque state without running handlers. Two distinct callers exercise
the same node, and a sample counter runs on the pinned Kubernetes/Substrate
reference with worker-failure recovery and sandbox isolation proofs. A separate finite-capacity profile proves control
progress using reserved disk space. See the [roadmap evidence](docs/ROADMAP.md)
and [implemented profile and limits](contracts/TRANSIT_V2.md). Station, the HTTP
connector, and trading applications are not implemented; this is not a stable public API.

## Development environment

Install Nix with flakes and `nix-command` enabled, then:

```sh
nix develop
just
just doctor
just check
```

The shell provides `just`, Zig **0.17 master** from
[zig-overlay](https://github.com/mitchellh/zig-overlay), the Vite+ `vp` CLI,
Node.js, pnpm, and the Ursula server and `ursulactl` CLI from
[ursula-overlay](https://github.com/rupurt/ursula-overlay). `flake.lock` pins Nix
inputs, including the exact Zig nightly and Ursula overlay revision; the Vite+
release and archive checksums live in `nix/vite-plus.nix`. The shell also includes
`kubectl` and `k9s`, plus `k3s` on Linux, from the pinned nixpkgs input. Linux and
macOS on x86_64 and aarch64 are configured.

Vite+'s CLI and JavaScript toolchain are packaged by Nix, with an internal npm
lockfile under `nix/vite-plus/`. Its first invocation creates local settings in
the ignored `.cache/vite-plus/` directory, uses the Nix-provided Node.js and
package manager, and leaves shell profiles alone. The frontend milestone will
add its own project-local Vite+ dependency and pnpm workspace lockfile.

Run the complete [example applications](examples/README.md) against fresh local
disk-backed infrastructure:

```sh
just example counter
just example byte-log
```

`just build` builds platform executables; `just build-examples` builds the sample
applications. No example binary is required to run the Transit authority.
See [development](docs/DEVELOPMENT.md) for commands, updates, and verification.

## Project plan

Start at the [documentation index](docs/README.md).

| Document | Purpose |
| --- | --- |
| [Glossary](docs/GLOSSARY.md) | Official names and shared protocol, runtime, and packaging terms |
| [Scope](docs/SCOPE.md) | Kernel goals, first outcomes, and application boundaries |
| [Architecture](docs/ARCHITECTURE.md) | Component boundaries and end-to-end data flow |
| [Security](docs/SECURITY.md) | Authentication, authorization, realms, revocation, and trust boundaries |
| [Conformance](docs/CONFORMANCE.md) | Adversarial scenarios, implementation gates, and guarantee limits |
| [Transit — kernel](docs/TRANSIT.md) | Processes, PIDs, lifecycle, sequences, and ownership |
| [Client](docs/CLIENT.md) | Caller programming model, public schema, retry material, and future bindings |
| [Streams](docs/STREAMS.md) | Unbounded mailboxes, persistence, delivery, and retention |
| [Retention](docs/RETENTION.md) | Application contracts, process/mailbox lifetimes, compaction, and reclamation |
| [Station — framework](docs/STATION.md) | GenServer behaviors, supervision, registries, and composition |
| [Connectors](docs/CONNECTORS.md) | HTTP messages, exchange stream groups, interpolation, and replay |
| [Deployment](docs/DEPLOYMENT.md) | Runtime bindings, Kubernetes/Substrate, and portability |
| [Ursula integration](docs/URSULA.md) | Selected stream infrastructure, Zig client boundary, and persistence plan |
| [Roadmap](docs/ROADMAP.md) | Small milestones with observable completion criteria |
| [Agent guidance](AGENTS.md) | Working conventions for this repository |

The foundational docs distinguish implemented M1 profiles from broader target
requirements. Run `just ci` for local protocol/service checks. The Linux/Docker
reference and physical-capacity proofs have additional prerequisites documented
under [development](docs/DEVELOPMENT.md). Technical rationale lives in these docs.
