# Architecture

Engineering background and historical design. Use [Architecture and scope](../handbook/reference/architecture.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.
New and substantively revised architecture accounts follow the
[scientific standard](../handbook/internals/standard.md); the historical material here retains its
recorded scope and evidence.

Use this map to place your component in the stack and find its public package.
Start with [the user overview](../handbook/guides/introduction.md) for the application model;
this page explains ownership and dependency direction.

Status: experimental M1 kernel, client, storage adapter, and reference runtime
implemented and verified. Board supplies the qualified M2 inspection UI/API.
The implemented stack now includes growing state, Station, language SDKs,
HTTP/gRPC connectors, Documents, unified queries, serving/reactive APIs, Flight
and local application installation, each with its own qualified profile. Use
the [roadmap](../roadmap/README.md) for scope and the [test guide](../../tests/README.md) for proved behavior and limits.

## Execution model

This monorepo develops Transit, the reusable streaming runtime: its
generic agentic kernel, supporting services, clients, storage/runtime adapters,
Board inspection surface, Station framework and Fuze query engine.
`transit-core` implements the deterministic kernel; the runtime's deployment is packaged in
[charts/transit](../../charts/transit/README.md). Station is the OTP-inspired framework
above the kernel. Transit's execution primitive is a process with a durable PID
and an ordered, logically unbounded mailbox. Its
sequence determines valid execution, including lifecycle, input handling,
progress, and authorized effects. Actors are implemented by processes; GenServer
is a Station behavior running in one. Workers are replaceable executors.

The PID survives eligible suspension, worker replacement, and migration;
termination or opted-in process expiry retires it. Each activation has a fresh
ownership generation. A registered name resolves to a PID, while a runtime binding maps it to a
scoped provider resource. Neither naming nor placement grants execution rights.

Transit defines the protocol. Ursula carries and persists its messages via
`ursula-zig`. Station makes that protocol convenient to program; connectors
perform external work; applications compose these facilities. LLM reasoning and
trading rules do not enter the kernel's vocabulary.

The cutoff for starting work and the end of settlement are distinct. Previously
authorized work can finish within recorded finite limits. Connectors choose how
to establish external outcomes; Transit enforces acceptance rights and permanent
closure. A late result cannot reopen a closed attempt, and closing an unknown
outcome makes no claim about what the external system did.

Use the [glossary](GLOSSARY.md) for official names and shared terminology.

## Layers and ownership

| Layer | Owns | Design |
| --- | --- | --- |
| Identity adapters and protocol ingress | Credential verification, authenticated request provenance, and mapping external identities to principals | [SECURITY.md](SECURITY.md) |
| Transit — kernel | Processes/PIDs, lifecycle, legal sequences, ordered commits, realm/grant checks, ownership and effect authority; resource/association contracts | [TRANSIT.md](TRANSIT.md), [STATE.md](STATE.md), [SECURITY.md](SECURITY.md) |
| Durable transport | Persistent history, continuation positions, mailbox storage and delivery | [STREAMS.md](STREAMS.md), [URSULA.md](URSULA.md) |
| Station — framework | GenServer behaviors, Table/association helpers, scoped name registries, request/reply, supervision, timers, worker-pool patterns | [STATION.md](STATION.md) |
| Fuze — query and compute | Shared source/plan/operator model; versioned KV/Table/Document adapters and bounded nested Arrow results | [FUZE.md](FUZE.md) |
| Serving — inbound interfaces (M19 profile) | Published service bindings, authenticated request context, admission, bounded responses and recovery; HTTP first for application APIs and Board | [SERVING.md](SERVING.md) |
| Reactive APIs (M20 Table profile) | SSE/WebSocket hosting, shared session/watch and resume contracts, generated OpenAPI/AsyncAPI descriptions | [REACTIVE_API.md](REACTIVE_API.md) |
| Reactive interfaces (M21) | Shared live-view owner, exact finite refresh and visible freshness over the reactive API | [REACTIVE.md](REACTIVE.md) |
| Query interchange and protocol adapters | IPC/C interfaces; finite Flight/Flight SQL over the same query/serving components, with pinned ADBC clients | [ARROW.md](ARROW.md) |
| Connectors | Authorized external attempts, request/response capture, bounded reconciliation, outcome and retry/cancellation policy | [CONNECTORS.md](CONNECTORS.md) |
| Runtime adapter | Durable PID-to-provider bindings and reconciliation of lifecycle intents with provider resources/observations | [DEPLOYMENT.md](DEPLOYMENT.md) |
| Retention reconciliation | Enforce Transit-authorized policies and retained boundaries; coordinate checkpoints, dependency checks, and adapter reclamation | [RETENTION.md](RETENTION.md) |
| Board — inspection | Authorized operator/agent API, embedded frontend, evidence-linked views, and optional framework lenses | [BOARD.md](BOARD.md) |
| Applications | Workload policy, agent composition, trading, and application-specific views | [SCOPE.md](SCOPE.md) |

Zig implements the Transit kernel, Station framework, Fuze engine, connectors,
runtime adapters and application backends. TypeScript/Vite+ supplies frontend code and tooling.
Shared contracts use language-neutral schemas and fixtures. Ursula and Agent
Substrate are external infrastructure with their own implementation languages.
Station M9 adds host-language SDK adapters and examples over the shared Zig
client/framework. M11 adds language-native public SDKs over
those bindings. That binding glue does not change the service language or move
application handlers into Transit authority; [CLIENT.md](CLIENT.md#language-neutral-boundary)
owns the generated ABI and target-language plan.

## Implemented topology and planned composition

The running profile exposes all application reads and writes through the public
node. The separate maintenance process is trusted infrastructure with storage
access. Clients and provider controllers do not read the journal directly.

```mermaid
flowchart LR
    Caller[Zig or language binding caller] -->|Signed reads and proposals| Node[transit-node]
    Board[transit-board] -->|Signed inspection| Node
    Delivery[transit-delivery] -->|Scoped status and delivery operations| Node
    Controller[transit-runtime-controller] -->|Signed lifecycle operations| Node
    Framework[transit-station-controller] -->|Scoped observations or lifecycle operations| Node
    Node -->|Validated history and conditional append| Store[(Ursula realm journal)]
    Maintenance[transit-node --maintain] -->|Validated maintenance and recovery| Store
    Controller -->|Reconcile physical lifecycle| Runtime[Agent Substrate on Kubernetes]
    Runtime -.->|Hosts reference caller| Caller
```

Current authority operations serialize across the entire realm, including
processes, grants, and state resources. This supplies the initial atomicity domain;
replicating the HTTP service does not create independent write shards. Mailbox
semantics promise per-process order, not a portable global order between PIDs.

The explicit v3 profile decouples durable cardinality from resident memory:
resource data, retained work and control catalogs use paged access and bounded
working sets. One conditional root publication retains the authority decision.
The default v2 profile still uses fixed arrays and complete resource snapshots;
those are compatibility ceilings, not cache settings. M10
tracks qualification before public SDKs stabilize;
[State](STATE.md#collection-size-and-working-memory) defines the boundary.
No launcher or foreign binding switches profiles implicitly.

Massive-scale deployment also requires an explicit authority-partition and routing
design, including grant/revocation and cross-partition delivery semantics. Measure
the single-realm serialization bottleneck in M10; M35 qualifies
broader clustered execution. Additional node replicas do not by themselves create
independent write capacity or a cross-partition transaction guarantee.

Station runs in callers and connectors will submit observations through the
same public boundary. The [delivery courier](../../apps/transit-delivery/README.md)
automatically advances committed outboxes with scoped rights; history holds its
progress and retry identity. Station timer/child observers submit authenticated
mailbox observations; separately scoped lifecycle controllers apply recorded
restart intent. They never acquire provider authority implicitly.

Every ingress establishes authenticated provenance before the kernel accepts
an operation. Credential providers stay behind adapters; Transit validates
principal/realm grants alongside ownership and lifecycle. Station helpers and
provider RBAC cannot replace these checks. Read APIs, projections, transcripts,
and administrative operations need their own scoped permissions. Revocation
and replay semantics are defined in [SECURITY.md](SECURITY.md).

## Source of truth

Validated durable history is authoritative for process creation/termination,
mailbox admission, ownership changes, completed turns, pending outputs/effects,
state-resource mutations, and runtime bindings. Station registry operations use
that same authority through ordinary process turns.
State indexes, name lookup caches, ready queues, and UI views are derived; their
loss must not erase accepted work or invent completed work.

Applications opt into finite retention and resource lifetime; unlimited is the
default. Transit owns those contracts independently of Ursula. A logical stream
may span physical segments, and the storage adapter maps checkpoints, trimming,
and deletion onto verified provider capabilities. Suspension must fit the
process/mailbox recovery window; known expiry permanently ends activation
eligibility. Storage GC can happen later without extending that lifetime.

Once history is reclaimed, a validated durable checkpoint and retained tail
become the authoritative recovery basis. Preserve live state, pending work,
ownership, and required control evidence; only derived indexes and runtime
caches remain disposable. [RETENTION.md](RETENTION.md) defines the guarantees
and distinguishes lifetime, history windows, quotas, and physical reclamation.

A committed turn links its input, state transition, outgoing messages, and
effect intents. Only committed outputs become eligible for dispatch. Delivery
across processes is recoverable and deduplicated; an append to one process's
stream does not establish a transaction over another process's stream. Committed
destinations remain bound to PIDs across name rebinding and placement changes.

Kubernetes and Substrate retain operational state for infrastructure and sandbox
management. Transit's runtime adapter reconciles that state with recorded execution
intent. Substrate owns physical worker assignment; a running pod or restored
sandbox is not proof of current process ownership. The first reference mapping
is one Transit process per Substrate Actor, across many activations. The
[deployment design](DEPLOYMENT.md) defines that boundary, provider reconciliation,
and why AX is excluded.

## Caller and enforcement boundary

Application code runs in clients. It receives state and input, computes a
proposal, and submits it through the public protocol. Core validates identity,
current grants, ownership, ordering, revision, and lifetime. It commits opaque
application state without running or verifying the handler's computation.
[CLIENT.md](CLIENT.md) defines that programming model; [SECURITY.md](SECURITY.md)
and [CONFORMANCE.md](CONFORMANCE.md) define trust and bypass obligations.

M7 evolves inline application state into versioned resources
accessed through recorded process associations. Core enforces identity,
revision, commit, grants, and lifetime; application values stay opaque. The
client supplies bounded KV access, core rebuilds its bounded materialized catalog
from backend journals/checkpoints,
and Station builds behavior/Table APIs above them. [STATE.md](STATE.md) owns
the design and proof gates; it introduces no separate authoritative database
or automatic cross-resource transaction.

Runtime isolation and restricted credentials must prevent direct effects and
raw journal writes. A well-behaved SDK alone cannot enforce this boundary.
Trusted connectors execute recorded attempts. Replay restores recorded state
and outcomes without reissuing effects; recovery of unfinished work requires
current ownership and explicit attempt policy.

## Planned monorepo decomposition

Library boundaries describe code responsibilities, not processes or pods.
Executables compose libraries with configuration, credentials, and OS lifecycle.
The root build orchestrates packages; each library declares its own dependencies
and checks. See [development](DEVELOPMENT.md#package-workflow).

### Implemented libraries

| Package / module | Owns | Direct package dependencies |
| --- | --- | --- |
| [transit-http-server](../../packages/zig/transit-http-server/README.md) / `transit_http_server` | Bounded HTTP/1.1 and WebSocket framing, concurrent socket ownership, control reserve and joined deadlines; consumed by Board and serving | None |
| [transit-station-app](../../packages/zig/transit-station-app/README.md) / `transit_station_app` | M23 neutral definitions, shared compiler, signed conditional publication, bounded host contract and upload continuation | transit-serving |
| [transit-serving](../../packages/zig/transit-serving/README.md) / `transit_serving` | M19 admission/current reads; M20 session controls, Table watch coverage and generated reactive contracts; native/Compose/Substrate qualification | transit-station, transit-query |
| [transit-query-client](../../packages/ts/transit-query-client/README.md) | Reflected finite-query host types, bounded browser transport, semantic cell validation and complete-result reads shared by Board and applications | transit-query schema, transit-reactive-client caller coordination, AJV |
| [transit-application](../../packages/ts/transit-application/README.md) | M23 generated validators, pure visual edits, scoped signing and exact pending/reviewed-plan recovery | transit-station-app reflected contract, AJV |
| [transit-serving-http](../../packages/zig/transit-serving-http/README.md) / `transit_serving_http` | Reusable signed HTTP/SSE/WebSocket dispatch, local challenges and joined streaming tasks extracted for M21 | transit-serving, transit-http-server |
| [transit-exchange](../../packages/zig/transit-exchange/README.md) / `transit_exchange` | M15 qualified segment capture, frozen intent coverage and explicit cleanup | transit-station |
| [transit-station-document](../../packages/zig/transit-station-document/README.md) / `transit_station_document` | M17 structured merge, collaborative text and qualified paged accepted-state publication | transit-station |
| [transit-station-http](../../packages/zig/transit-station-http/README.md) / `transit_station_http` | M15 qualified finite HTTP request construction, strict framing and durable capture | transit-exchange, transit-tls |
| [transit-tls](../../packages/zig/transit-tls/README.md) / `transit_tls` | Compiler-pinned TLS client with bounded certificate-path verification | Pinned zig-libs certificate-validation snapshot |
| [transit-station-grpc](../../packages/zig/transit-station-grpc/README.md) / `transit_station_grpc` | M16 qualified durable finite RPC adapter | transit-exchange, transit-grpc |
| [transit-flight](../../packages/zig/transit-flight/README.md) / `transit_flight` | Qualified finite Table Flight gateway, pinned wire, bounded IPC and standard metadata codecs | transit-grpc, transit-query, transit-serving |
| [transit-station-flight](../../packages/zig/transit-station-flight/README.md) / `transit_station_flight` | Recorded outbound Flight requests and bounded typed replay, with native TLS peer qualification | transit-flight, transit-station-grpc |
| [transit-grpc](../../packages/zig/transit-grpc/README.md) / `transit_grpc` | Finite HTTP/2 RPC transport and protobuf codecs; no dispatch authority | transit-tls, pinned zig-libs HTTP/2/protobuf/gRPC client snapshot |
| [transit-observability](../../packages/zig/transit-observability/README.md) / `transit_observability` | Transit diagnostic vocabulary and optional instrumentation | transit-protocol, telemetry |
| [telemetry](../../packages/zig/telemetry/README.md) / `telemetry` | Bounded diagnostic sinks, local metrics and trace context | None |
| [transit-protocol](../../packages/zig/transit-protocol/README.md) / `transit_protocol` | Public types, signatures, opaque values, schema, shared fixtures | None |
| [transit-core](../../packages/zig/transit-core/README.md) / `transit_core` | Protocol state, validation, conditional authority, recovery | transit-protocol |
| [transit-client](../../packages/zig/transit-client/README.md) / `transit_client` | Signed HTTP calls, activation sessions, retry material | transit-protocol, transit-observability |
| [transit-backend-ursula](../../packages/zig/transit-backend-ursula/README.md) / `transit_backend_ursula` | Storage/transport, checkpoint, trim, deletion | transit-core, transit-observability, upstream ursula-zig |
| [transit-board-api](../../packages/zig/transit-board-api/README.md) / `transit_board_api` | Board response types, OpenAPI generation and evidence projections | transit-protocol, transit-station (framework metadata), transit-query, transit-exchange, transit-station-http/grpc/document (allowlisted metadata) |
| [transit-board-client](../../packages/ts/transit-board-client/README.md) (TypeScript) | Generated Board models/runtime validators and bounded browser transport | AJV runtime helper |
| [transit-runtime-substrate](../../packages/zig/transit-runtime-substrate/README.md) / `transit_runtime_substrate` | Provider identity, template validation, sandbox lifecycle operations | transit-observability; invokes pinned external CLI |
| [transit-station](../../packages/zig/transit-station/README.md) / `transit_station` | GenServer, durable calls, scoped names, supervision, Tables and captured queries | transit-client, transit-fuze |
| [transit-station-bindings](../../packages/zig/transit-station-bindings/README.md) / `station_abi` | Shared native SDK handles, detached turn actions, C exports and generated host schemas; composes above the framework | transit-station, transit-client ABI, transit-station-http |
| [transit-query](../../packages/zig/transit-query/README.md) / `transit_query` | Signed public Table queries, admission behaviors, verified typed pages and v2 KV/Table/Document adapters | transit-station, transit-station-document |
| [transit-fuze](../../packages/zig/transit-fuze/README.md) / `transit_fuze` | Source/plan contracts, Table SQL compilation and bounded Zig-native Arrow execution | pinned zarrow, zarrow-compute |

The [binding packages](../../bindings/README.md) expose the shared Zig client and
Station through a generated C ABI and owned native-port adapters. Each target
owns runtime scheduling and resource cleanup; protocol and framework semantics
remain in Zig. Fuze has no Station, Ursula or Substrate dependency. It embeds
neither DataFusion nor Acero.

The dependency graph stays acyclic. Core must remain testable without providers
or Station; applications use the public client. `transit-backend-*` names storage
and transport integrations; `transit-runtime-*` names execution placement and
lifecycle integrations. Additional implementations must prove the required
ordering, fencing, recovery, and retention guarantees. Broader interfaces should
follow a second concrete implementation, not a speculative plugin system.

### Implemented executables and examples

| Entry point | Role |
| --- | --- |
| [transit-station-document-worker](../../apps/transit-station-document-worker/README.md) | M17 authenticated Document writer and bounded maintenance; local/Compose/reference recovery qualified |
| [transit-station-grpc-worker](../../apps/transit-station-grpc-worker/README.md) | M16 qualified finite RPC preparation/dispatch/capture worker |
| [transit-station-http-worker](../../apps/transit-station-http-worker/README.md) | M15 qualified finite HTTP preparation/dispatch/capture worker |
| [transit-node](../../apps/transit-node/README.md) | Hosts core with Ursula, signed ingress, trusted time; separate maintenance mode |
| [transit-delivery](../../apps/transit-delivery/README.md) | Public-client courier for ordered committed outboxes; no storage or handler authority |
| [transit-runtime-controller](../../apps/transit-runtime-controller/README.md) | Composes public client and Substrate adapter to reconcile one PID |
| [transit-station-controller](../../apps/transit-station-controller/README.md) | Observes Station timers/children or applies separately scoped lifecycle intent |
| [transit-station-host](../../apps/transit-station-host/README.md) | Bounded native port for host languages; delegates to the shared ABIs |
| [transit-client-host](../../apps/transit-client-host/README.md) | Standalone raw client port; canonical recovery and metadata without Station |
| [transit-query-host](../../apps/transit-query-host/README.md) | Runnable growing v1/v2 source/requester workers and scoped courier |
| [transit-cli](../../apps/transit-cli/README.md) (`transit`) | Local server/application lifecycle, explicit-submit console and signed v1 Table/v2 unified SQL shells |
| [transit-docs](../handbook/README.md) | Static Docusaurus handbook over owned Markdown and generated interface descriptions; no runtime authority or credentials |
| [transit-board](../../apps/transit-board/README.md) | Inspection API plus optional separate v1 Table or v2 unified query capability with embedded [TanStack Router frontend](../../apps/transit-board-web/README.md); public client and transit-board-api composition |
| [kubectl-transit](../../apps/kubectl-transit/README.md) | Kubernetes installation/workload inspection, service logs and origin-aware Board access |
| [transit-admin](../../apps/transit-admin/README.md) | Signs/submits commands and reads scoped views |
| [example-counter](../../examples/counter/README.md) | Complete caller, also the reference deployment workload |
| [example-byte-log](../../examples/byte-log/README.md) | Independent caller against the same generic authority |
| [example-station-ledger](../../examples/station-ledger/README.md) | Three Station processes with Tables, calls, registry, supervision and Arrow replies |
| [example-state-query](../../examples/state-query/README.md) | Finite SQL caller with private original-intent recovery and bounded owned pages |
| [example-station-document](../../examples/station-document/README.md) | Independent structured/text editors over the public Document call/read APIs |

Transit artifacts use the `transit-` prefix, including the `transit-board*`
inspection family, `transit-station*` framework and `transit-fuze*` engine
families. These names denote subsystem membership; core and the public execution
client do not depend on Board, Station or Fuze. Examples are applications, not required infrastructure.
Tests launch their actual binaries; fault injection
and protocol assertions belong under [tests/](../../tests/README.md).

### Planned components

- M19 formalizes serving with HTTP application APIs and Board
  as its first consumers. The implemented neutral `transit-http-server` owns HTTP
  mechanics; implemented `transit-serving` composes public Transit/Station admission and
  response contracts. Board keeps its projections and private access profile.
  Create packages only with real implementations, manifests and consumers;
  core must not depend on these higher layers. M20 adds
  qualified SSE/WebSocket bindings, an int64 Table snapshot/watch adapter and
  generated API descriptions over shared durable session controls. M21 consumes
  that API for bounded refresh and live views. Neither creates another event store.
- Add typed public APIs, handler runners and installable artifacts to the existing
  language packages in M11. Python, TypeScript, Rust, Ruby, C/C++,
  Java and .NET have public handler/recovery/data proofs; remaining targets and public mixed
  language pairs are still open. Ruby uses the shared native port.
  Generated/raw bindings remain a
  separate interface over the shared Zig client/framework; the
  [caller design](CLIENT.md#idiomatic-language-sdks) owns that boundary.
- Extend `kubectl-transit` with authorized logical inspection and, later, operator
  controls as scoped in the full plugin plan.
- M17 adds Document changes/CRDTs over M14 publication;
  M18 adds KV/Document query adapters and wider source contracts. Add further entity adapters only
  with their implementation and qualification; no standalone engine service is required.
- M15 introduces only the shared exchange/capture/reference library needed by
  HTTP, above Station. M16 qualifies reuse for gRPC. Keep generally reusable
  publication/read primitives below the adapters; Station Documents cannot
  import a higher-layer exchange or transport package. Add real packages with
  manifests when their implementation and consumers exist.
- `packages/zig/transit-station-http`, module `transit_station_http`: exchange contracts, capture,
  caller helpers, and trusted dispatch over Station/Transit.
- `packages/zig/transit-station-grpc`, module `transit_station_grpc`: typed call
  contracts/helpers and capture/reconciliation for authorized external RPCs.
  Keep reusable Zig HTTP/2/protobuf transport separate from dispatch authority.
- `packages/zig/transit-flight` and `apps/transit-flight-gateway`: Flight/
  Flight SQL as an Arrow serving adapter, reusing M19's identity/admission/
  response seams over Station/public client, with no direct storage access.
  `packages/zig/transit-station-flight` constructs outbound recorded RPCs and
  interprets their captured Arrow responses through `transit-station-grpc`.
  Existing ADBC clients connect through Flight SQL; [ARROW.md](ARROW.md) owns
  this M22 profile and its independently qualified inbound gRPC behavior.
- `apps/transit-station-worker`, `apps/transit-station-http-worker` and
  `apps/transit-station-grpc-worker`: compose behaviors or connector execution
  with explicitly supplied runtime capabilities.
- M23 implements [declarative reactive applications](REACTIVE_APPLICATIONS.md),
  using Board as the first consumer. Shared Zig definition/publication/migration
  owners remain above the public client and Station; TypeScript renderers consume
  generated, runtime-validated types and M20/M21 clients. SQL lowers to owning
  operations or Fuze plans, never a UI authority database. Create shared packages
  only when Board and the downstream example exercise them.
- M24 formalizes the Zig `transit` entry point around `server`
  and `console`. The server composes a supervisor/gateway and the locally placed
  service neighborhood; OS lifecycle does not replace durable ownership or
  Station supervision. The console reuses public clients, Fuze and M23's shared
  grammar/catalog assistance. [Deployment](DEPLOYMENT.md#transit-cli-applications-and-planned-publication)
  owns the local-placement boundary; [Query language](QUERY_LANGUAGE.md#terminal-console)
  owns the terminal semantic boundary.
- M25 adds application installation above the native client.
  The [public declaration/bootstrap contract](../../contracts/APPLICATION_INSTALLATION_V1.md)
  identifies roles and resources without granting authority. The CLI composes
  exact native provisioning and physical lifecycle; independently built workers
  import public packages. Compatible worker revision, ownership generation,
  data epoch and published interface revision remain separate. Native key rotation
  preserves permission epochs, so restarting a process cannot renew revoked reads.
- M33 publishes the declared Transit artifact matrix from a
  tagged commit through GitHub Releases/Packages, Nix, an install script,
  Homebrew, OCI images and Helm. Existing component build/package owners remain
  authoritative; release orchestration binds their outputs to one verified
  manifest and platform/compatibility matrix.
- Application libraries and entry points: compose these primitives without
  adding application policy to core. Further TypeScript/Vite+ frontends and
  shared libraries follow concrete consumers.

Keep request/transcript construction separate from effect dispatch. Importing a
library must not acquire credentials or start work. Workload-specific images can
compile behavior selection; dynamic plugins are not implied. Add directories
when implementation starts. Do not duplicate public protocol definitions or
create a generic utility package without a concrete owner.

M7's resource contracts, validation, client operations, storage/index mechanisms,
and inspection extend those existing owners. A separate state package
or executable needs a concrete dependency or runtime boundary; this plan does
not create empty packages or require a new state service. The implemented M7
profile uses those boundaries; numerical limits and wire details live in the
[state contract](../../contracts/STATE_V1.md).

## Observation and repository ownership

[Launchers](../../launchers/README.md) compose existing executables for native local
development, Docker Compose, and reference qualification. Their configuration,
OS process management, and provisioning are development tooling, not new kernel
or framework layers. Local/Compose ownership is recorded through the public
client; only the Substrate reference supplies the implemented provider binding.

Board starts with kernel identities and lifecycle evidence, then gains optional
Station/connector lenses as those layers land. It reads through the public client;
required discovery/history surfaces belong to Transit, not a Board backdoor into
storage. UI and agent consumers share a versioned OpenAPI contract. Views remain
derived, permissioned, bounded, and explicit about freshness and missing history.
See [BOARD.md](BOARD.md) and M2 for the design and proof gates.

[Service observability](OBSERVABILITY.md) is implemented across Board,
Transit services, clients, adapters and callers. Owners define their signals;
executables configure bounded sinks and correlation. Core stays deterministic,
and telemetry remains lossy operational evidence with no execution authority.
M4 owns its qualification evidence.
Collectors and remote export are later scope.
Measure latency, throughput, recovery time, and resident memory before choosing
scaling or latency targets. The [pre-Station review](reviews/PRE_STATION.md) maps
current limits and missing framework prerequisites to the next milestone.

`packages/zig/` owns libraries; `apps/` owns platform/application entry points;
`examples/` owns complete sample callers. Exact versioned specifications live in
`contracts/`. Tests, deployment, Nix, and task recipes each own their operational
README. [The documentation index](../README.md#where-documentation-lives) explains
where to put design, implementation details, and validation evidence.
