# Transit — kernel protocol

Engineering background and historical design. Use [Processes, turns and recovery](../reference/processes.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Use this model to understand what a worker may commit and how it recovers.
The [native protocol reference](../reference/native.md) owns wire entry points;
[the application guide](../guides/applications.md) shows a caller in practice.

Status: foundational requirements established; record names and mechanisms below
are the target protocol outline. An experimental signed-request/ownership/replay
slice is implemented; its supported surface and limits are specified in
[the v2 profile](../../contracts/TRANSIT_V2.md), with evidence in the
[test guide](../../tests/README.md). M7 adds the [bounded associated KV profile](../../contracts/STATE_V1.md). General
payloads and broader kernel lifecycle mechanisms remain design direction.
Station behaviors and selected application migrations are implemented above the
kernel; [growing v3](../../contracts/TRANSIT_V3.md) adds the separate paged profile.

## Boundary

Transit names the reusable streaming runtime subsystem. This document owns its
agentic kernel protocol: it defines which message sequences
constitute valid execution. Durable streams transport and persist those
sequences. A record is authoritative only when it satisfies protocol validation
and commit rules; storing arbitrary bytes does not authorize an action.

The kernel knows processes, messages, turns, ownership, capabilities, and effects.
The implemented [state profile](STATE.md) adds durable resource identities,
associations, revisions, and lifetime dependencies; application value semantics
remain outside the kernel.
It does not know prompts, reasoning loops, goals, agent delegation strategies,
HTTP semantics, or trading policy. Those compose the protocol through
[Station, the framework](STATION.md), and [connectors](CONNECTORS.md).

The [transit-core library](../../packages/zig/transit-core/README.md) implements
validation, transitions, and recovery over shared public protocol types. It stays
independent of Ursula, Kubernetes, and Station. Adapters and executables supply
persistence, hosting, and configuration; see the
[monorepo decomposition](ARCHITECTURE.md#planned-monorepo-decomposition).

## Processes and identity

A **process** is Transit's logical execution primitive: an identity, ordered
mailbox, committed control state and application-state associations, execution
sequence, and lifecycle. M1 stores application state inline; [M7](roadmap/M7.md)
adds durable resource associations. A **PID** identifies
that process independently of its worker, OS process, pod, or sandbox. An actor
is a programming-model participant implemented by a process; a Station GenServer
is a behavior running in one. Raw processes and other behaviors can use Transit
without Station.

PIDs are opaque and unique within an explicit Transit identity authority. A
portable reference must identify that scope as well as the process. M1 uses
`(realm, accepted spawn position)`, with both coordinates in the exact integer
range documented by the wire profile. Retired PIDs are never reused.
An optional registered name is an alias to a PID, not its identity.

Each process owns one logical ordered mailbox and execution sequence. Concurrent
senders are ordered at durable admission. Process sequence positions are
protocol identities distinct from Ursula's opaque continuation tokens.
Cross-process messages carry causation and correlation; they do not establish
a global total order.

An **activation** is a period of execution on a worker under a validated ownership
grant. Each new activation receives a monotonically advancing generation for
that PID. An **activation reference**, conceptually `(PID, ownership_generation)`,
identifies that incarnation. Knowing a PID or activation reference grants no
permission; commit and dispatch authorization boundaries must validate current
authority.

A turn identifies its PID, generation, admitted input, code version, and prior
committed state. Outgoing messages and effect intents have stable identities
that survive retries. A [runtime binding](DEPLOYMENT.md#runtime-bindings) relates
the PID to its deployment resource. Its revision is separate from the ownership
generation and cannot authorize execution.

Principals and grants are separate from PIDs and ownership. Trusted ingress
binds authenticated sender provenance; the kernel enforces realm and action
permissions at admission, commit, delivery, and effect authorization. Station
does not supply the security boundary. See [SECURITY.md](SECURITY.md).

## Lifecycle

| Event | Identity and recovery meaning |
| --- | --- |
| Spawn | Create a new PID, mailbox, initial state, and lifecycle history under authorized control |
| Activate or recover | Validate lifetime and recovery eligibility, then execute the existing process under a fresh ownership generation |
| Suspend | Fence execution and preserve the PID, state, mailbox, and pending work within the accepted resumption deadline |
| Worker loss or migration | Reconcile runtime placement and recover the same process under fresh ownership |
| Compatible code upgrade | Record the workload change while fenced and suspended; preserve PID, state and pending work, then require fresh activation |
| Handler failure | Record the failure; policy decides whether to retry/recover or request logical termination |
| Stop starting work | Refuse fresh work; preserve only specifically authorized, finitely bounded settlement rights |
| Settle | Finish that authorized work under current ownership and grants, without granting further work or extending its window |
| Terminate | Irrevocably retire the PID and fence its activations; apply an explicit policy to accepted input, pending outputs, and effects |
| Expire | Permanently retire the PID when its opted-in process/mailbox recovery lifetime ends; fence execution and record pending-work disposition |

Runtime failure is not logical termination. A replacement spawned after
termination has a new PID, even if a name is later rebound to it. Termination
cannot silently drop accepted work, redirect it to the replacement, or undo an
external attempt already dispatched. Its retirement and reconciliation policy
must be recorded. Lifecycle observations identify whether they concern a PID
or a particular activation; a lost worker must not masquerade as process death.
After termination, reject new application admissions and turns while permitting
authorized cleanup and recording of outstanding effect evidence only while its
independent reconciliation contract remains open. Closure rejects new results.

The implemented [same-PID upgrade](../../contracts/TRANSIT_V2.md) keeps the declared
application/state contract unchanged. It performs no state conversion, renews no
lifetime, and cannot revive a failed or retired process. Compatibility of edited
application code remains the caller/deployer's responsibility.

Applications opt into finite retention and process lifetime; the default is
unlimited. Suspension cannot promise recovery beyond the mailbox and other
required resources' availability. Activation after a known expiry fails
permanently, even if the bytes or a sandbox snapshot still exist. A 30-day
history window alone does not make every PID expire at age 30 days: a verified
checkpoint and retained tail may support a longer-lived process. The complete
contract lives in [RETENTION.md](RETENTION.md).

These durable PID semantics deliberately differ from equating recovery with
spawning a new Erlang process. The inspiration is the separation of process,
identity, and behavior, not Erlang VM compatibility.

## Naming and addressing

Transit addresses messages to PIDs. Station supplies optional scoped
[name registries](STATION.md#registries-and-addressing) as services using ordinary
Transit processes and committed turns. A process can exist without a name.

Name resolution must produce a recorded destination PID before an outgoing
message becomes eligible for delivery. Preserve the resolved PID and registry
revision across retries; mailbox admission records the PID explicitly. Rebinding
a name cannot retarget committed outputs, accepted messages, or late replies.
If the resolved process terminates, report that outcome against the original
PID. A new send to a replacement requires a new authorized decision.

## Proposed protocol vocabulary

These semantic families describe the target vocabulary, not published API names.
Use the linked versioned contracts for the implemented M1–M7 operations.

| Family | Required meaning |
| --- | --- |
| Process lifecycle | Spawn, suspend, resume, terminate, expire, and record failure with explicit PID and deadline semantics |
| Ownership | Grant/revoke an activation generation through the process's serialized authority |
| Runtime lifecycle | Record binding revisions, provider-operation intents, and correlated observations without transferring execution authority to the provider |
| Message admission | Durably accept a stable message identity into the target PID's mailbox order |
| Turn commit | Bind the next input to committed state, outgoing messages, and effect intents |
| Effect attempt | Authorize a particular attempt of a committed effect and identify its executor |
| Effect observation | Record correlated data, completion, failure, or an unknown outcome |
| Settlement and closure | Bind preauthorized work to finite settlement rights; irrevocably close acceptance with a known or unknown outcome |
| Recovery checkpoint | Identify a validated history prefix, state representation, and code/schema versions |
| Retention lifecycle | Record policy versions, recovery deadlines, checkpoint coverage, trim/retirement decisions, and maintenance outcomes |
| Authorization control | Record principal/resource bindings, grants, policy revisions, revocations, and operation decisions without persisting credentials |

Lifecycle authority can fence a failed worker without waiting for its handler.
Application cancellation and other user messages retain their declared mailbox
ordering. The protocol must distinguish those two forms of control explicitly.

## Authoritative operations

An authoritative operation must order identity, payload, expected prior state,
current policy, and its resulting receipt together. A timeout after acceptance
leaves an uncertain acknowledgement; retry the same identity and recover the
recorded result. The [core implementation](../../packages/zig/transit-core/README.md#authority-and-recovery)
uses one conditional realm journal for M1; its exact wire representation belongs
to the [v2 profile](../../contracts/TRANSIT_V2.md).

Spawn is idempotent too: one authorized spawn identity produces one PID and
initial state. A controller or supervisor recovering a lost reply must not
create another child. User-supplied IDs alone grant no authority; identity scope
and payload validation follow [SECURITY.md](SECURITY.md) and [STREAMS.md](STREAMS.md).

Per-process acceptance is serialized and fenced. Policy/revocation changes and
retention dependency admission must have defined ordering against affected
operations as well. Listing records from separate streams does not create a
transaction between them. M1 proves conditional realm append; any replacement
coordination mechanism needs its own authority-crash and competing-writer proofs; transport deduplication
and Kubernetes leases do not establish it. The first authority topology may be
simple, but must recover exclusively from validated durable control state.

## A turn

The supported inline-state model is:

```text
(state, admitted_message) -> (next_state, outgoing_messages, effect_intents)
```

1. Recover the process's last committed state and validate current ownership.
2. Select its next unprocessed mailbox message in admitted order.
3. Run the handler against explicit inputs. Proposed state and outputs are private.
4. Validate and durably commit the turn against its prior state and generation.
5. Make the committed outputs eligible for delivery or effect dispatch.

A crash before commit may cause recomputation. A crash after commit must recover
the same state and pending outputs. Acknowledging admission, committing a turn,
and completing an effect are separate observable events.

The proposed commit unit records the input, state change or durable state
reference, outputs, and effect intents together in the process's history.
Referenced data must already be durable with compatible retention. Large payloads
can be staged before a manifest commit makes them authoritative. Local indexes
and execution caches remain disposable. A protocol checkpoint that replaces a
reclaimed prefix must itself be durable and validated; it becomes part of the
authoritative recovery basis with the retained tail.

The [implemented turn format](../../contracts/TRANSIT_V2.md) makes opaque state and
outputs atomically visible in one journal record. Pending cross-process delivery
uses durable outboxes with stable identities and deduplicated admission; this
provides no general multi-stream transaction. See [STREAMS.md](STREAMS.md).

[M7](roadmap/M7.md) introduces associated resource views and mutation proposals
under that same turn boundary. A process can locate its state through named,
versioned associations instead of replacing all application data per message.
The kernel validates the resources and commit preconditions without interpreting
their values. [STATE.md](STATE.md#turn-and-commit-boundary) owns atomic visibility,
read/replay coverage, and lifetime rules; storing an arbitrary resource ID in
today's opaque state does not implement those guarantees.

## Enforcement

- Validate sender authority, record schema, process lifecycle/state, input
  position, prior commit, ownership generation, and lifetime eligibility before
  a transition can commit. The cutoff for new work leaves only recorded bounded
  settlement rights. Enforce those rights and final closure at acceptance and
  recovery even when background notification is delayed.
- Reject stale owners, competing commits, illegal transitions, and mismatched
  effect results. Within the supported retry horizon, an accepted identity
  returns its established outcome; conflicting content is rejected. Outside
  that horizon, reject an unprovable old retry instead of admitting it as new work.
- Process-produced messages and external effects require committed intents.
  Connector attempts also require the correct capability and current dispatch
  authority. External ingress follows its own authenticated admission contract.
- Workloads cannot directly append authoritative records, alter committed state,
  access arbitrary destinations, or obtain connector secrets. Isolate workload
  execution from the trusted admission/commit and effect-dispatch boundaries.
- Clock, randomness, external observations, and relevant configuration enter
  reproducible handlers as recorded inputs. Application code runs in callers;
  language choice does not change the protocol or require code in the node.

A client API alone cannot enforce these requirements on arbitrary native code.
The [caller proof](../../tests/README.md#independent-caller-evidence) and reference
isolation checks qualify a reviewed native workload, not arbitrary code.
Transport credentials, network policy, and sandboxing support protocol checks;
none independently proves legal execution. Trusted kernel/storage administrators
remain outside the workload isolation boundary.

Protocol validation establishes which authenticated process may propose the
next legal transition. It does not independently prove arbitrary handler
computation correct or deterministic. The selected handler executor must enforce
the claimed input/I/O and resource limits; application tests establish domain
correctness. Distinguish recovery by applying recorded committed state from
re-executing code to reproduce that state. A malicious worker with a valid grant
must not be described as unable to lie solely because its envelope validates.
See [the trust model](SECURITY.md#trusted-computing-base-and-provider-boundaries).

The [caller model](CLIENT.md) defines the implemented opaque-state boundary,
including state revisions and failure reports that leave input pending.

## Ownership and failure

At most one generation may commit for a process at a time. Recording a higher
number after two workers already committed is insufficient: admission, ownership
changes, and commits need a serialized, fenced authority. A pod lease or timeout
alone does not establish that property.

The Ursula mapping and authority recovery protocol have bounded M1 proofs.
Broader topologies must extend competing-authority, partitioned-worker, and
stale-snapshot tests. On resume, revalidate ownership and history before any
new commit or dispatch authorization. Enforce this outside the restored workload
as well: a resume hook alone cannot fence code running with stale memory or
credentials. Unavailability of authority blocks progress safely.

Revocation cannot retract an external request already sent. Preserve the attempt
and reconcile its outcome; never turn uncertainty into an invented success or
failure. Late observations can be recorded as evidence without granting a stale
worker authority to advance process state. Connector policy defines bounded
reconciliation; Transit rejects results after closure. A settling process can
commit only its previously authorized work, not start a fresh turn or chain of
effects. Delivering a connector result and authorizing a caller turn are distinct:
applying that result after the work cutoff needs an explicit bounded settlement
continuation, preserving mailbox order. Final retirement forbids either path.
The durable dispatch authorization marks an attempt as potentially in flight,
including a worker paused before sending. Fencing prevents new authorizations;
it cannot prove that such an attempt never reaches the external system. This
boundary is specified in [SECURITY.md](SECURITY.md#effects-and-the-limits-of-revocation).

## Replay and versions

Replay consumes committed history and recorded effect outcomes without executing
external work. Recovery resumes unfinished live work under fresh validated
authority and an unexpired lifetime contract. Keep these modes distinct in APIs
and tests. Full historical replay is limited to the declared replay horizon;
checkpoint recovery does not promise every earlier intermediate state.

Checkpoints identify the PID, process sequence, input position, code/schema
version, state content, and retained dependencies. Reconstruct from history only
when enough history remains; a missing required checkpoint is a recovery error,
not permission to start empty. Process/mailbox expiry is a terminal lifecycle outcome;
temporary storage unavailability is retryable. Version changes require an
explicit migration or replay policy; a new binary must not silently reinterpret
an existing process's sequence.

M1 rejects unsupported workload/schema changes. Later migration must quiesce
or fence old activations, preserve pending message/effect identities, and commit
the new version and compatible state under explicit authority. If old code or
required history is unavailable, stop visibly; neither loading a new image nor
recomputing old effects is a migration strategy.

## Runtime readiness controls

[M8 lifecycle controls](../../contracts/LIFECYCLE_V1.md) implement generic initialization
barriers, scoped blocked-input retry, and bounded suspension/resumption. They keep
process retirement, ownership generations and provider activation distinct.
Station builds behavior initialization, subscriptions and restart policy on these
operations; none of those framework policies executes in the node.
