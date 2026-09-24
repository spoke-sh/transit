# Station — framework and behaviors

Status: an OTP-inspired layer above the kernel is established direction. The
behavior API and lifecycle policies below are proposed, with no implementation.

## Purpose

Station is Transit's OTP-inspired framework built on [the kernel](TRANSIT.md).
It makes the protocol convenient to compose in Zig. Producers and consumers can
be stateful actors implemented by Transit processes, using shared behaviors for
mailbox handling, recovery, correlation, and supervision.

[Board](BOARD.md) precedes Station and already plans kernel-level inspection.
Station will supply versioned descriptors and lenses for its behaviors and
registries, preserving underlying PID/history evidence rather than requiring
Board to infer behavior from names or payload shapes.

The planned `transit-station` Zig library uses `transit-client` and the public protocol,
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

## GenServer

GenServer is a behavior running in a Transit process. It uses that process's
PID, versioned state, and ordered durable mailbox; it introduces no second actor
identity. A worker executes one handler turn at a time. Recovery restores
committed state and resumes the mailbox under a fresh activation; worker
replacement does not create a new logical server.

| Operation | Protocol meaning |
| --- | --- |
| Initialize | Establish initial state under a process lifecycle transition |
| Send/cast | Commit an outgoing message for durable admission to a resolved PID |
| Request/call | Send with correlation and the caller's PID as a durable reply destination |
| Handle | Consume the next mailbox input and propose state/output changes |
| Reply | Commit a correlated message to the caller's mailbox |
| Request an effect | Commit an intent for an authorized connector worker |
| Suspend/recover | Validate the process/mailbox lifetime and resumption deadline, preserving the eligible PID while changing activation ownership |
| Terminate/replace | Retire the PID under explicit policy; a replacement is a new process |

Callback names and Zig signatures remain open. The semantic unit is the
kernel turn, with private proposed state until commit. Framework helpers cannot
publish outputs early or move checkpoints independently of that commit.

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

Expose the cutoff for new work separately from final retirement. A settling
process can finish only specifically preauthorized work within a finite window;
supervision cannot turn that permission into ordinary activation or more work.
Connector reconciliation has its own recorded owner, window, and budget. Its
closure is terminal even if the original request later returns a response.

Suspension returns an explicit resumption bound when lifetime is finite. Reject
requested suspension beyond the process's validated recovery window; automatic
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

Every namespace declares its authority, visibility, and lifetime. Local and
cluster-wide registration must identify the logical scope in which a name is
unique and how that scope survives worker replacement. Neither means an
unqualified worker-memory map, a Kubernetes namespace, or a Substrate atespace.
M3 defines the minimal scoped registry; M5 proves cluster-wide conflict and
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
Recorded caller provenance is available to application handlers, but delegation
is explicit rather than inherited from receiving a message. See [SECURITY.md](SECURITY.md).

## Failure and progress

A failing head message cannot disappear behind a checkpoint. Bound handler CPU,
memory, execution time, and retries. On repeated failure, keep the process visibly
blocked or apply an authorized ordered rejection/termination policy, recording
the input disposition before progress advances. Quarantine is observable retained
work with its own lifetime, not silent acknowledgement. M1 needs the minimal
failure policy; Station supplies reusable supervision helpers in M3.

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
