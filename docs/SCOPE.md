# Scope

Status: kernel direction and deployment reference established. The bounded
[M1 profile](../contracts/TRANSIT_V2.md) is implemented, with evidence in the
[roadmap](roadmap/README.md). [Board M2](roadmap/M2.md) is implemented and qualified
for bounded inspection. The [M7 KV profile](roadmap/M7.md) and
[M8 runtime readiness](roadmap/M8.md) are also implemented and qualified.
[M9](roadmap/M9.md) adds Station and the first bounded Fuze Table profile.
[M10](roadmap/M10.md) qualifies growing state and measured verification budgets;
[M11](roadmap/M11.md) supplies the language SDKs. [M12](roadmap/M12.md) through
[M14](roadmap/M14.md) add SQL, public queries and immutable publication.
[HTTP M15](roadmap/M15.md), [RPC M16](roadmap/M16.md) and
[Documents M17](roadmap/M17.md) are qualified within their declared profiles.
[Unified querying M18](roadmap/M18.md) implements the shared state-query model;
its proof ledger qualifies native source/lifecycle coverage and Table physical recovery.
[Serving M19](roadmap/M19.md) qualifies the initial signed HTTP service, shared
Board listener and separate native/Compose/Substrate recovery profiles. Broader deployment,
transport and application outcomes below remain design direction.

## Purpose

Build Transit, a reusable streaming runtime whose generic kernel makes distributed, agentic workloads
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
  implemented and planned package responsibilities and dependency direction.
- Application code calls the public Transit protocol; the node never runs handlers.
  Transit supports Zig callers. Station M9 adds shared bindings for C/C++,
  Rust, Python, Node.js, Java, .NET and Elixir/Erlang without changing kernel
  execution semantics. Host-language binding glue, examples and conformance tests
  are in scope; the shared client/framework and service implementations remain Zig.
  M11 adds language-native typed APIs, handler runners and installable artifacts,
  and extends the language targets with Ruby;
  generated wire/ABI declarations and shared protocol semantics retain their owners.
- Board is the first operator/agent inspection surface, before Station. Its
  TanStack Router frontend uses Vite+ and is embedded in the Zig `transit-board` API
  executable. OpenAPI supports further clients; read-only views expose kernel
  evidence and optional interpretations of runtime/framework primitives.
  Application value decoding belongs in application interfaces. M7 removed the
  experimental M2 counter lens. See [BOARD.md](BOARD.md).
- Ursula supplies durable streams; `ursula-zig` supplies the Zig client.
- Strong protocol enforcement: effects and committed state follow valid durable
  sequences. Worker memory and scheduling caches cannot override that history.
- Use the implemented durable state resources and recorded process associations
  as Station's starting point. Start with a versioned KV resource; keep mutations, input progress,
  and outputs under one commit decision. Resource lifetime, entry lifetime,
  history retention, association, and access rights remain distinct. The bounded
  M7 profile coexists with inline-state callers; see [STATE.md](STATE.md).
- Authenticate every protocol caller and enforce explicit realm/action/resource
  grants in Transit. Station APIs, provider credentials, and PIDs do not confer
  those rights. Reads, replay, supervision, and retention administration are
  permissioned too. See [SECURITY.md](SECURITY.md).
- Each Transit process owns a durable PID and an ordered, logically unbounded
  mailbox. Eligible worker recovery preserves the PID; termination or expiry retires it.
  Actors and GenServer behaviors build on this primitive.
- Durable state collections and retained framework evidence must grow beyond a
  worker's memory. Bound resident pages, requests and active work independently
  of logical cardinality; enforce explicit deployment quotas before admission.
  Current compiled catalog ceilings are temporary implementation constraints,
  not target semantics. [M10](roadmap/M10.md) qualifies the correction before
  public SDKs; retention is never a workaround for an in-memory array limit.
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
  scoped name registries above the Transit kernel. Registry changes are durable operations;
  rebinding a name cannot redirect accepted work or replies.
- Station Tables add typed state access and Arrow results over durable resources.
  M9 scopes stream-input materialization, finite queries and atomic batches within
  one resource. [TABLES.md](TABLES.md) owns those boundaries.
- [Fuze](FUZE.md) is the Zig-native query and compute engine, inspired by Apache
  DataFusion and Acero. It targets one query model across KV, Table and Document,
  while Station owns their distinct mutation and merge semantics. Documents target
  both structured state and collaborative text in [M17](roadmap/M17.md);
  [M18](roadmap/M18.md) adds unified KV/Table/Document queries. [Arrow](ARROW.md) owns interchange and remote access.
  M12 implements the bounded read-only Table SQL compiler. M13 exposes it through
  a separately authorized Board workspace and `transit` query shell; M22 reuses
  it for Flight SQL. Continuous queries and
  separate-resource transactions remain later work. No foreign query engine
  runs behind the interface or inside Transit authority.
- HTTP is the first connector; gRPC is the second. Request/response messages and
  timing travel through durable exchange groups, with explicit credential scope,
  capture, retry and closure. A live RPC stream is not a durable mailbox.
- [Serving](SERVING.md) formalizes the inbound side in [M19](roadmap/M19.md):
  application HTTP APIs and Board share service bindings, identity, admission,
  bounded responses and recovery over public operations. It sits above the kernel
  and complements outbound connectors. Board retains private shared viewer access.
  [Reactive APIs M20](roadmap/M20.md) adds SSE/WebSocket hosting, resumable
  subscriptions and generated OpenAPI/AsyncAPI descriptions.
  [Reactive interfaces M21](roadmap/M21.md) consumes them for live views and
  snapshot refresh; incremental continuous queries and individual sign-in remain
  separately scoped. M22 qualifies Flight over the same serving foundation.
- Kubernetes is part of the first executable milestone. Agent Substrate is the
  recommended execution target and reference architecture. Preserve portability
  to other cloud runtimes through durable PID-to-provider runtime bindings.
  Begin with one process per Substrate Actor; activation ownership stays in
  Transit while Substrate handles sandbox placement and lifecycle.
- AX is excluded. Transit owns execution protocol/orchestration authority; adding
  AX's task store and queue would introduce a competing authority.
- Scope and cross-component rationale live in foundational Markdown docs;
  implementation details live with their owning components.

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
and capacity mechanisms must pass the [M1 design gates](roadmap/M1.md#design-gates-before-expanding-the-slice).

Next, build Board to discover and explain the running kernel through public,
authorized read APIs. Operators and agents should follow mailbox input, turns,
outputs, effects, ownership, and retention with visible freshness and gaps.
The static frontend and API ship in one executable; M2 adds no control actions.

The completed [M4 observability milestone](roadmap/M4.md) instruments
Board, Transit services and their dependencies before Station so operators can
diagnose the running system. Logs, metrics and trace context remain derived
signals; collector/export infrastructure is later scope.

[M7 state resources and associations](roadmap/M7.md) provide fenced KV mutation,
bounded recoverable reads, dependency lifetimes, and generic Board inspection.
[M8 runtime readiness](roadmap/M8.md) adds authenticated input origins, automatic
outbox delivery, opt-in working catalog reclamation and scoped lifecycle controls.
The bounded [Station M9](roadmap/M9.md) profile adds GenServer behavior,
supervision, scoped name registration, language bindings and Arrow Tables,
respecting those contracts. [M10](roadmap/M10.md) establishes comprehensive
verification, growing state and measured scale boundaries. [M11](roadmap/M11.md)
makes those capabilities natural
to use through typed language SDKs, with explicit lifetime and recovery behavior.
[M14](roadmap/M14.md) qualifies bounded immutable publication.
[HTTP M15](roadmap/M15.md) consumes it for shared exchange capture: a caller
records an intent, a fetch worker executes an authorized attempt, and the caller
resumes from a correlated durable outcome. Replay reads captures without I/O.
[gRPC M16](roadmap/M16.md) reuses that common lifecycle for bounded streaming
calls. These first connectors precede [Documents M17](roadmap/M17.md) and
[unified queries M18](roadmap/M18.md), which reuse the storage/read foundations
without depending on live network protocols. [Serving M19](roadmap/M19.md)
first composes HTTP application APIs and Board.
[Reactive APIs M20](roadmap/M20.md) supplies the session, event and protocol
contracts that [reactive interfaces M21](roadmap/M21.md) consumes for live views.
[Arrow interoperability M22](roadmap/M22.md) reuses serving for Flight SQL/ADBC.
[M23](roadmap/M23.md) implements the [Board design explorations](design/README.md)
as a monochrome reactive UI and a shared SQL/visual application grammar, with
explicit publication and recoverable application migrations.
[Transit CLI M24](roadmap/M24.md) formalizes `transit server` as a local
supervisor/gateway and `transit console` as a psql-like SQL/slash-command shell
with shared grammar/catalog typeahead. [Local applications M25](roadmap/M25.md)
adds language-neutral installation/bootstrap and compatible worker replacement,
qualified first with a separately compiled Zig consumer. [Publication M26](roadmap/M26.md) makes
tagged Transit artifacts installable through Nix, a shell installer, Homebrew,
Docker/OCI and Helm, with GitHub release publication and an explicit SDK/library
inventory. M25 is in progress; publication remains planned. [M27](roadmap/M27.md) extends their authority
and recovery proofs across cluster topologies. Station,
connectors and query services add authorized Board metadata as their primitives land.
These outcomes define the [roadmap](roadmap/README.md).

## Boundaries

The foundation proves the kernel, Board, a small framework, and the connector
model. Board introduces the first frontend; a trading loop or model integration
is not required. Cluster
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
these same primitives. Rey's intended workload includes broad instrument history
through L2/L3, internet context and collaboration, algorithmic/high-frequency
execution, and strategy research/optimization with learned agents and models.
The [workload model](workloads/REY.md) derives capacity scenarios and their
implications for M10 without selecting venues, initial coverage, latency SLOs or
a live-trading sequence. Trading milestones will be scoped when the foundation
supports them; a paper-trading endpoint is not the foundation's objective.

Preserve application requirements when that work begins: precise monetary
representations, serialized risk and exposure reservations, explicit freshness
and pause semantics, and reconciliation of uncertain external orders. Replaying
trading history must not submit new orders.

## Questions for expanding the implementation

The bounded M1 choices have [recorded evidence](../tests/README.md). These
questions remain review obligations as profiles expand; later framework and
connector questions are still open.

| Question | Evidence needed |
| --- | --- |
| How are admissions, ownership, and turn commits serialized and fenced? | Competing-owner and crash tests on the Ursula mapping |
| How are credentials, realm grants, and revocation bound to each operation? | Impersonation, stale-policy, subscription, and dispatch-race tests |
| Which execution mechanism enforces workload I/O and resource limits? | Native-code bypass attempts; recorded-state recovery must not claim deterministic re-execution |
| How do bootstrap and full-store recovery preserve control authority? | Partial initialization, lost spawn acknowledgement, reserved-capacity and cleanup tests |
| What wire schema and commit representation implement the kernel protocol? | Valid/invalid traces and cross-language fixtures |
| What PID encoding and authority scope preserve durable identity? | Spawn, recovery, migration, and permanent-retirement fixtures |
| How are process/mailbox deadlines and retention guarantees enforced? | Suspension bounds, clock/failover, active expiry, late activation, and full-store tests |
| How are checkpoints, pins, tombstones, and reclamation represented? | Trim/delete crash recovery, dependency checks, lagging-consumer and no-resurrection fixtures |
| How do runtime bindings reconcile Substrate resources and wake from backlog? | Lost-wakeup, duplicate-operation, stale-snapshot, and reference deployment tests |
| What are registry scope lifetimes and lookup consistency guarantees? | Concurrent registration, rebind/termination races, recovery, and cluster partition tests |
| What constitutes an HTTP attempt, its capture boundary, and safe retry? | Connector transcripts and injected network/worker failures |
| Which snapshot and code-version rules preserve replay through upgrades? | Replay and migration fixtures |
| How do associated resources commit and expire with process work? | Atomic visibility, revisioned reads, dependency/retirement races, and compaction proofs in [M7](roadmap/M7.md) |
| How can inspection expose enough evidence without leaking data or inventing certainty? | Authorized discovery/history, revocation/trim races, bounded reads, and Board API/UI agreement |
| What workload and recovery targets matter? | Measurements from the kernel and connector slices |

Resolve new choices through the corresponding kernel, framework, and connector milestones.
