# Scope

Status: kernel direction and deployment reference established. Protocol details
and milestones below are designs to implement and validate.

## Purpose

Build Transit, a generic streaming kernel that makes distributed, agentic workloads
understandable through enforced message sequences. A process's durable history
determines what it may do next, how progress commits, and how execution recovers.
The kernel supplies the foundational protocol; durable streams are its transport
and persistent record. Station is the framework above it. See
[Transit](TRANSIT.md), [Station](STATION.md), and the [glossary](GLOSSARY.md).

"Agentic" describes the workloads this should support. Reasoning loops, goals,
agent delegation, model providers, and trading rules are higher-level concerns.
The same primitives must support ordinary stateful distributed programs.

## Established constraints

- One monorepo of reusable Zig libraries and executables; TypeScript and Vite+
  for frontends and frontend tooling. The
  [decomposition plan](ARCHITECTURE.md#planned-monorepo-decomposition) defines
  package responsibilities and dependency direction without creating them yet.
- Ursula supplies durable streams; `ursula-zig` supplies the Zig client.
- Strong protocol enforcement: effects and committed state follow valid durable
  sequences. Worker memory and scheduling caches cannot override that history.
- Authenticate every protocol caller and enforce explicit realm/action/resource
  grants in Transit. Station APIs, provider credentials, and PIDs do not confer
  those rights. Reads, replay, supervision, and retention administration are
  permissioned too. See [SECURITY.md](SECURITY.md).
- Each Transit process owns a durable PID and an ordered, logically unbounded
  mailbox. Eligible worker recovery preserves the PID; termination or expiry retires it.
  Actors and GenServer behaviors build on this primitive.
- Retention defaults to unlimited. Applications opt into finite process/mailbox
  lifetimes, history retention, keyed compaction, and workload-scoped resources.
  Suspension fits the available recovery window; activation after known expiry
  fails permanently. Logical expiry and background physical reclamation are
  separate guarantees. See [RETENTION.md](RETENTION.md).
- Allow specifically authorized work to settle within recorded finite limits
  after the cutoff for starting new work. Connectors own reconciliation and
  external retry/cancellation semantics; Transit supplies irreversible closure,
  fenced acceptance, and late-result rejection. An unresolved attempt can close
  with outcome unknown without pretending the remote operation was cancelled.
- Station, the OTP-inspired framework, supplies behaviors, supervision, and
  scoped name registries above Transit. Registry changes are durable operations;
  rebinding a name cannot redirect accepted work or replies.
- HTTP is the first connector: request/response messages and timing metadata
  travel through exchange stream groups, with explicit variable/secret handling.
- Kubernetes is part of the first executable milestone. Agent Substrate is the
  recommended execution target and reference architecture. Preserve portability
  to other cloud runtimes through durable PID-to-provider runtime bindings.
  Begin with one process per Substrate Actor; activation ownership stays in
  Transit while Substrate handles sandbox placement and lifecycle.
- AX is excluded. Rey owns execution protocol/orchestration authority; adding
  AX's task store and queue would introduce a competing authority.
- Scope and technical rationale live directly in the foundational Markdown docs.

## First outcomes

First, demonstrate a minimal Transit process on Kubernetes with persistent
ordered input, enforced transitions, and recovery after its worker is killed. An earlier worker
must be unable to commit stale work after replacement. The sequence must remain
inspectable and replayable across that failure, retaining the same PID and
mailbox through runtime reconciliation while its contract remains valid. The
first slice also proves opted-in expiry, safe checkpoint/trim boundaries, and
refusal to revive a process whose mailbox recovery lifetime has ended.
Authentication, grant/revocation enforcement, and recovery of the control catalog
are part of that same slice. Its concrete authority, execution-isolation, time,
and capacity mechanisms must pass the [M1 design gates](ROADMAP.md#design-gates-before-expanding-the-slice).

Then add GenServer behavior, supervision, and scoped name registration, and
implement an HTTP connector using those primitives. A caller records a request; a fetch
worker executes an authorized attempt; response data and timing are recorded;
the caller resumes from a correlated mailbox message. Replay uses the transcript.
These outcomes define the [roadmap](ROADMAP.md).

## Boundaries

The initial work proves the kernel, a small framework, and the connector model.
It does not require a trading loop, model integration, or frontend. Cluster
deployment and worker recovery are included; multi-region operation and broad
cloud support follow evidence from the reference deployment.

The unbounded mailbox is a logical programming abstraction over durable storage.
Memory, message size, storage capacity, and admission remain operational limits;
accepted work cannot disappear when those limits are reached. See
[STREAMS.md](STREAMS.md).

Avoid a second stream engine, a new sandbox implementation, an Erlang-compatible
VM, and unmeasured latency/throughput promises. Build the framework incrementally
around working protocol primitives.

The first slice uses one security realm, minimal grants, a fixed workload image,
and trusted synthetic effect execution. Identity federation, arbitrary native
plugins, and a general policy language are later scope. Protocol legality is
distinct from proving arbitrary computation correct, and revocation cannot undo
a possibly in-flight external attempt. [CONFORMANCE.md](CONFORMANCE.md) defines
the adversarial evidence and limits required before extending the foundation.

## Trading as an application

Trading remains an intended consumer of the kernel, framework, and connectors.
Market ingestion, strategy, risk, execution, and projections should compose
these same primitives. A paper-trading milestone will be scoped when the
foundation supports it; no venue, asset class, strategy, or live-trading sequence
is established by the current roadmap.

Preserve application requirements when that work begins: precise monetary
representations, serialized risk and exposure reservations, explicit freshness
and pause semantics, and reconciliation of uncertain external orders. Replaying
trading history must not submit new orders.

## Questions to resolve during implementation

| Question | Evidence needed |
| --- | --- |
| How are admissions, ownership, and turn commits serialized and fenced? | Competing-owner and crash tests on the Ursula mapping |
| How are credentials, realm grants, and revocation bound to each operation? | Impersonation, stale-policy, subscription, and dispatch-race tests |
| Which execution mechanism enforces deterministic handler inputs and resource limits? | Native-code bypass attempts and reproducible re-execution, separate from state recovery |
| How do bootstrap and full-store recovery preserve control authority? | Partial initialization, lost spawn acknowledgement, reserved-capacity and cleanup tests |
| What wire schema and commit representation implement the kernel protocol? | Valid/invalid traces and cross-language fixtures |
| What PID encoding and authority scope preserve durable identity? | Spawn, recovery, migration, and permanent-retirement fixtures |
| How are process/mailbox deadlines and retention guarantees enforced? | Suspension bounds, clock/failover, active expiry, late activation, and full-store tests |
| How are checkpoints, pins, tombstones, and reclamation represented? | Trim/delete crash recovery, dependency checks, lagging-consumer and no-resurrection fixtures |
| How do runtime bindings reconcile Substrate resources and wake from backlog? | Lost-wakeup, duplicate-operation, stale-snapshot, and reference deployment tests |
| What are registry scope lifetimes and lookup consistency guarantees? | Concurrent registration, rebind/termination races, recovery, and cluster partition tests |
| What constitutes an HTTP attempt, its capture boundary, and safe retry? | Connector transcripts and injected network/worker failures |
| Which snapshot and code-version rules preserve replay through upgrades? | Replay and migration fixtures |
| What workload and recovery targets matter? | Measurements from the kernel and connector slices |

Resolve these implementation choices through the kernel and connector milestones.
