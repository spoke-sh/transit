# Station — framework and behaviors

Status: the [Station package](../packages/zig/transit-station/README.md) implements
the bounded M9 profile: GenServer turns, associated state, durable calls, typed
Tables, captured Arrow replies, scoped registries, timed waits, supervision and
versioned Board lenses. [Language adapters](../bindings/README.md) share that
implementation; the [runnable example](../examples/station-ledger/docs/running.md)
composes three workers across the development profiles. The package guides define implemented bounds;
broader behavior below remains architectural direction.
[M9](roadmap/M9.md) builds on [M7 state resources](roadmap/M7.md) and
[M8 runtime readiness](roadmap/M8.md).

## Purpose

Station is Transit's OTP-inspired framework built on [the kernel](TRANSIT.md).
It makes the protocol convenient to compose in Zig and other language clients.
M9 includes bindings for C/C++, Rust, Python, Node.js, Java, .NET, and
Elixir/Erlang, sharing the Zig implementation and versioned contracts.
Producers and consumers can be stateful actors implemented by Transit processes,
using shared behaviors for
mailbox handling, recovery, correlation, and supervision.

[Board](BOARD.md) already provides kernel and resource inspection.
Station supplies versioned descriptors and lenses for its behaviors and
registries, preserving underlying PID/history evidence rather than requiring
Board to infer behavior from names or payload shapes.

The `transit-station` Zig library uses `transit-client` and the public protocol,
without importing the kernel implementation. It exposes behaviors and
composition helpers. Connector libraries and worker executables build on it;
Station itself stays independent of the selected transport and deployment
provider. Its artifacts use the `transit-station*` family, including the planned
`transit-station-http` connector and worker executables. Station remains the
framework's name in prose. See the [monorepo decomposition](ARCHITECTURE.md#planned-monorepo-decomposition).

Erlang creates processes with PIDs independently of optional registered names;
`gen_server` adds a standard behavior to a process. That separation informs
Transit and Station. Transit's PID survives worker recovery; this is a durable
logical identity, not a claim that an Erlang PID survives process termination.
See the upstream [process documentation](https://www.erlang.org/doc/system/ref_man_processes.html)
and [GenServer documentation](https://www.erlang.org/doc/system/gen_server_concepts.html).

## Languages and bindings

Zig owns the client and framework implementation. A versioned C ABI, generated
declarations/codecs, and thin runtime adapters make those capabilities usable
from the target languages without independently implementing protocol sequencing,
signing, or retry rules. The [client design](CLIENT.md#language-neutral-boundary)
owns that binding boundary, runtime integration, and qualification matrix.

Station adds behavior, request/reply, registry and Table contracts above the
raw Transit client. The same GenServer turn semantics must be available to a
host-language handler: receive authenticated input, compute locally, and return
a proposal. The node never loads that language's runtime or executes its code.
Foreign exceptions, cancellation and garbage collection cannot implicitly commit
or acknowledge a turn. Bindings are part of M9's deliverable, not just a schema
that leaves each language to build its own SDK.

[M11](roadmap/M11.md) adds idiomatic public SDKs above the implemented adapters.
It also adds Ruby as a planned language target over the shared native port;
Ruby is outside the M9-qualified binding matrix.
Handlers use typed inputs and associated KV/Table helpers; a runner owns local
dispatch and drives the shared Zig poll/finish machine. A handler return supplies
a proposal, including any reply, and is not evidence of a committed turn. The
runner resolves uncertain submissions before dispatching another handler and
applies an explicit handler-failure policy without acknowledging work on unwind.

Turn contexts and state helpers are scoped to one private proposal; reject use
after completion and concurrent access that would violate sequencing. Stage
mutations, input progress and outputs under the existing commit boundary.
Handler-object fields are temporary worker memory, not durable process state.
Initialization and recovery use recorded descriptors and associated resources.

Runtime async APIs may await local bridge operations without blocking schedulers.
A cross-process wait must finish its turn with recorded waiting state and resume
through a later authenticated outcome. Arbitrary coroutine stacks are not
recoverable, and holding a turn open cannot extend its read view or lifetime.
Neither an SDK nor a handler runner proves native-code isolation; external
effects still require connectors and deployment-enforced capability boundaries.

The first reference behavior workers remain Zig. Qualifying a language client
does not qualify its VM/native runtime for Substrate sandboxing or resource
isolation; additional worker images need the same deployment proofs as Zig.

## Preconditions for the first framework slice

[M8](roadmap/M8.md) supplies authenticated input origins, an automatic outbox
courier, explicit initialization, scoped lifecycle controls and opt-in catalog
reclamation. [M9](roadmap/M9.md#entry-gates) defines durable lifecycle watches,
timer outcomes, child initialization/restart policies and the example's capacity
budget. The [service guide](../packages/zig/transit-station/docs/services.md)
owns their implemented layout and role separation. These framework protocols use
the public client without test-harness delivery or root credentials in handlers.

A handler has one writable resource per turn. Behavior state and framework
waiting/correlation data that must commit atomically need to share that resource
under a versioned key layout, or use an explicitly asynchronous protocol between
writer PIDs. Multiple logical tables may share one resource and its transaction
boundary; a Table wrapper cannot make separate resources transactional.
After a crash, Station must resolve the previous proposal before deciding to
recompute; SDK-owned in-memory retry bytes are not durable waiting state.

## GenServer

GenServer is a behavior running in a Transit process. It uses that process's
PID, state associations, and ordered durable mailbox; it introduces no second
actor identity. A worker executes one handler turn at a time. Recovery restores
committed associations and eligible resource views, then resumes the mailbox
under a fresh activation. Worker replacement does not create a new logical server.

| Operation | Protocol meaning |
| --- | --- |
| Initialize | Establish resources and named associations under validated lifecycle/commit operations |
| Send/cast | Commit an outgoing message for durable admission to a resolved PID |
| Request/call | Send with correlation and the caller's PID as a durable reply destination |
| Handle | Read explicit resource revisions; consume the next mailbox input and propose mutations/outputs within the supported commit scope |
| Reply | Commit a correlated message to the caller's mailbox |
| Request an effect | Commit an intent for an authorized connector worker |
| Suspend/recover | Validate the process/mailbox lifetime and resumption deadline, preserving the eligible PID while changing activation ownership |
| Terminate/replace | Retire the PID under explicit policy; a replacement is a new process |

The initial host-pumped API and versioned layout are recorded in the
[Station profile](../contracts/STATION_V1.md). The semantic unit is the
kernel turn, with private proposed mutations until commit. Handlers do not have
to return a replacement for all application state. Framework helpers cannot
publish outputs early or move checkpoints independently of that commit.

## State resources and Table helpers

The target framework accesses growing durable collections with bounded reads,
private mutation batches and query batches. M9's complete-resource copies and
shared 32-key capacity are implementation constraints, not a state-lifetime or
application data model. [M10](roadmap/M10.md) qualifies the replacement before
public SDKs; [State](STATE.md#collection-size-and-working-memory) owns the boundary.
Waits and captured results may remain retained without forcing applications to
delete evidence to satisfy a worker buffer size.

[STATE.md](STATE.md) owns resource identity, associations, revisions, commit
visibility, read coverage, and lifetimes. Station uses those public primitives
for handler state, durable waiting/correlation records, registry entries, and
supervisor records. [TABLES.md](TABLES.md) scopes typed tables, Arrow query results,
stream-driven materialization, and transaction limits for M9. Application
serializers, predicates and compute kernels run in callers, outside the node.

A Table identifies a schema and keyspace within an associated resource. The
proposed API offers typed insert/update/upsert/delete, get/scan, and a bounded
query plan. Requests to another writer travel through its PID's mailbox;
local operations contribute to the current handler's proposal. The first query
surface uses versioned structured operations. SQL is planned as a frontend
to that same contract: [M17](roadmap/M17.md) scopes the first bounded read-only
subset, with an explicit grammar and capability matrix.

Tabular results use Apache Arrow: bounded record batches in memory and Arrow IPC
for cross-process exchange. Plan to build on `zarrow` and `zarrow-compute` after
compiler, ownership and interoperability qualification. The Table design separates
an Arrow batch stream from a durable Transit stream: Arrow supplies representation
and compute building blocks; Station supplies ordering, recovery, result framing,
retention and transactional visibility.

[Fuze](FUZE.md) is the shared Zig-native query engine, inspired by DataFusion and
Acero. Station supplies authorized KV/Table/Document source adapters and owns
mutations, merge rules and durable result publication. The Document direction
includes both structured state and collaborative text; its CRDT/storage profile
and unified querying are scoped in [M14](roadmap/M14.md). Fuze queries accepted
state and does not merge speculative edits. [Arrow interchange](ARROW.md) connects the engine to IPC/C
interfaces and later Flight, Flight SQL and ADBC. Query operators stay outside
kernel authority;
network batch streams cannot confer durability or broaden transactions. HTTP is
the first connector and [gRPC](GRPC.md) the second, sharing the
[effect/reconciliation contract](CONNECTORS.md).

M9 starts with current-state materialization and finite snapshot queries.
Updates and deletes change the visible row set before a query evaluates it;
feeding every historical row version to an append-only aggregate is incorrect.
Several tables sharing one resource may mutate in one bounded turn, including
framework correlation records. Separate-resource transactions, continuous query
maintenance and larger storage profiles remain outside M9.

Association, lifetime ownership, writer authority, and access permission remain
distinct. Shared mutation initially goes through the resource's writer PID;
Station must expose that request/reply boundary instead of presenting it as a
local transaction. Resource creation/recovery belongs to the logical process
contract, not a worker-local initialization callback that resets data on restart.

A request/reply helper may present an awaitable API, but waiting must be durable.
Commit the waiting state and request, release the turn, and process the eventual
reply through mailbox order. Do not hold an uncommitted turn open across a remote
call or serialize worker capacity behind an in-memory wait. Define handling of
other messages while waiting as explicit process state.

## Retention-aware lifecycle

Station exposes application-selected retention contracts with unlimited defaults
and explicit process/stream overrides. Validate the effective contract before
creating resources or admitting dependent work. See [RETENTION.md](RETENTION.md)
for process, mailbox, history, and workload-scope lifetimes.

Named associations declare required and optional state dependencies. The M7
profile makes required-resource expiry terminal for the dependent PID; Station
cannot detach or initialize empty state to bypass that outcome. A history
retention window alone does not expire a current table value. Workload-scoped
helpers extend the proven PID/independent resource ownership rules explicitly.

Expose the cutoff for new work separately from final retirement. A settling
process can finish only specifically preauthorized work within a finite window;
supervision cannot turn that permission into ordinary activation or more work.
Connector reconciliation has its own recorded owner, window, and budget. Its
closure is terminal even if the original request later returns a response.

The Station API must return an explicit resumption bound when lifetime is finite.
The [lifecycle contract](../contracts/LIFECYCLE_V1.md) records a generation-fenced
`resume_before_ms` bound and makes late resumption permanently invalid. Station
uses that operation before requesting provider stop; a provider stop alone does
not establish a logical suspension contract. Reject requested suspension beyond
the process's validated recovery window; automatic
sandbox suspension has the same constraint. Worker failure may prevent timely
resumption, so activation must revalidate eligibility. A known expired process
is a permanent lifecycle failure, not a retryable worker outage.

Supervisors observe expiry, stop retrying that PID, and follow the application's
declared replacement or abandonment policy. Creating a replacement is a new
spawn with a new PID; it cannot silently inherit an expired mailbox. Pending
calls and timers receive correlated terminal outcomes where their destinations
remain valid, with evidence retained under their own contracts. A process-owned
temporary stream survives worker replacement and is retired when its logical
owner ends, subject to its recorded dependencies and cleanup policy.

## Registries and addressing

A registry maps `(namespace, name)` to a PID. Processes may remain unnamed;
callers can send directly to a PID. Name lookup, runtime placement, and execution
ownership are separate concerns:

```text
(namespace, name) -> PID -> runtime binding -> current execution location
```

Station supplies registry services and helpers using Transit processes and
durable turns. Register, unregister, and rebind are authorized, recorded
operations. Registry state and lookup caches are recoverable projections of
those operations or validated durable checkpoints, with no separate authoritative
task or naming store. Registry history can be trimmed only while preserving
live bindings, conditional-update revisions, and required retirement evidence.
Use associated state resources for those records; a registry's logical binding
revision is distinct from its resource revision and its writer's activation.

Every namespace declares its authority, visibility, and lifetime. Local and
cluster-wide registration must identify the logical scope in which a name is
unique and how that scope survives worker replacement. Neither means an
unqualified worker-memory map, a Kubernetes namespace, or a Substrate atespace.
M9 defines the minimal scoped registry; M18 proves cluster-wide conflict and
partition behavior.

Serialize changes for each name under one fenced authority. Conditional updates
use registry revisions so competing registrations or stale rebinds cannot both
succeed. When that authority is unavailable, mutations fail closed. The exact
lookup consistency contract remains to be specified; a cached result never
grants ownership or permission to send.

Lookup results used by a handler arrive as recorded inputs; replay does not
consult the current registry. Record the resolved PID and registry revision
with a committed outgoing message. Delivery retries and replies retain that PID
even if its name changes. A lookup racing with termination may therefore yield a
retired destination; report it
explicitly instead of silently resolving again. Cleanup on termination must be
conditional on the old binding, so it cannot remove a replacement's registration.
Accepted work and late effects follow the original process's retirement policy.

Registry lookup and mutation require separate scoped permissions. A resolved
PID does not grant send, inspect, supervision, or runtime-control privileges.
Station requires authenticated caller provenance at the handler boundary.
The public input includes an authority-derived, versioned `origin` identifying
external principals, source-process outputs or recorded effect attempts. Validate
that origin against the expected peer and operation before accepting framework
replies or registry mutations. A sender field inside opaque bytes is insufficient.
Delegation remains explicit rather than inherited from receiving a message.
See [SECURITY.md](SECURITY.md).

## Failure and progress

A failing head message cannot disappear behind a checkpoint. Bound handler CPU,
memory, execution time, and retries. On repeated failure, keep the process visibly
blocked or apply an authorized ordered rejection/termination policy, recording
the input disposition before progress advances. Quarantine is observable retained
work with its own lifetime, not silent acknowledgement. M1 records a handler
failure as a durable block and fences ownership. M8 adds an administrative retry
that names the exact failure and expected generation, preserves the head input,
and requires fresh ownership. Station supplies bounded retry/backoff policy and
an appropriately scoped controller. Repeated ownership requests alone cannot
restart a blocked PID.

Requests, replies, timeout observations, and cancellations retain correlation
and authenticated origin. Client disconnection is not cancellation of accepted
work. Self-calls or cycles of processes awaiting each other can deadlock at the
application level even when turns are released correctly; specify timeout and
failure policy and keep lifecycle control able to fence a stuck process.

## Supervision and time

Supervisors are Station processes whose state records child PIDs, lifecycle intent,
restart policy, and restart history. Runtime adapters carry out committed
lifecycle actions; observed exits and failures return through protocol records.
Recovered supervisors must reconcile existing children before creating new ones.

Define restart scope, limits, backoff, and escalation in framework policy. A
restart policy must distinguish recovering an existing PID from terminating it
and spawning a replacement PID. Rebinding a child name is a separate recorded
operation. Worker loss, handler failure, suspension, expiry, and logical termination
have distinct observations; lifecycle subscriptions must state whether they
observe a process or an activation. No failure permits silently dropping a
child's accepted mailbox backlog or pending effects.

Timers are requested effects. A timer service records a firing observation and
delivers it through mailbox admission. Specify races between timeout, reply, and
cancellation by the resulting process sequence. Replay consumes the recorded
winner rather than consulting the current clock.
Process expiry is additionally enforced at kernel authority boundaries; it
cannot depend on a timer message eventually reaching a suspended mailbox.

## Composition

Worker pools consume committed work with explicit ownership and fencing. The
framework can provide durable request/reply, routing, and retry helpers, while
each connector supplies its external-system semantics. The first example is the
[HTTP connector](CONNECTORS.md).

LLM calls and tool execution can later use the same connector contract. Reasoning
loops, goals, and agent delegation can be library/application patterns above these
behaviors. Trading actors can compose ingestion, risk, execution, and projection
without adding trading concepts to the kernel.

Start with GenServer, a minimal supervisor, and scoped name registration. Broader
behaviors, distributed supervision strategies, and upgrades should grow from
demonstrated use cases and the conformance requirements in the [roadmap](roadmap/README.md).
