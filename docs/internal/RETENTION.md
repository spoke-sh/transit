# Retention and resource lifetimes

Engineering background and historical design. Use [Retention, lifetimes and capacity](../reference/retention.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Choose a retention policy only when your application can tolerate the specified
loss of old data or recovery eligibility. The default is unlimited. This page
separates logical expiry, reconciliation closure and physical cleanup; see
[node operations](../../apps/transit-node/docs/operations.md) for maintenance configuration.

Status: application opt-in and lifetime guarantees are established requirements.
M1 implements a bounded subset: finite execution/settlement, checkpoint/trim,
immutable payload deletion, and finite admission with a physical reserve proof.
[Core](../../packages/zig/transit-core/README.md), [backend](../../packages/zig/transit-backend-ursula/README.md),
and [maintenance](../../apps/transit-node/README.md) own the mechanisms;
[tests](../../tests/README.md) own evidence. [M7](roadmap/M7.md) implements bounded
KV dependencies, resource expiry and keyed checkpoint compaction;
[STATE.md](STATE.md) owns that model. M14–M16 add finite publication/capture lifetime and bounded disposal. General
resource graphs, per-key TTL and distributed compaction remain planned.

## Application contract

Retention is part of a workload's execution contract. Transit must enforce the
lifetime within which a process and its mailbox can safely operate, as well as
the conditions for retiring their data. Station exposes those guarantees to
applications; storage and runtime adapters implement the required operations.

The default is **unlimited**: no automatic expiry or history removal. Applications
opt into finite retention, compaction, or resources owned by a finite workload.
They may declare application defaults and process/stream overrides. Resolve and
record the effective policy and its version when the resource is created or
the message is admitted. A changed default does not silently rewrite existing
contracts. Unsupported policies must be rejected before accepting work.

Unlimited retention is not unlimited capacity. Storage quotas, bounded buffers,
and admission backpressure remain necessary. Reject new work before admission
when its contract cannot be supported; storage pressure does not authorize
silently deleting accepted work.

A resident cache budget is not a retention policy or a maximum logical collection
size. Derived pages may be evicted and read back without deleting durable rows,
waits or results. The legacy fixed catalogs impose real total-cardinality limits;
[M10](roadmap/M10.md) must replace that coupling in the growing-state profile.
Applications must not be forced to select expiry or discard completion evidence
merely to reuse array slots. [State](STATE.md#collection-size-and-working-memory)
separates operation budgets, working sets, quotas and retained data.

A duration such as "30 days" must name its subject and consequence. A cleanup
target allows eligible data to remain while required. A hard logical deadline
ends availability or execution rights at that boundary, even if physical bytes
remain. An application selecting finite mailbox/process lifetime explicitly
accepts terminal expiry if it cannot finish or recover within that contract.

## Distinct but coupled lifetimes

| Dimension | Meaning |
| --- | --- |
| Process lifetime | When the PID may accept new work, followed by any explicitly bounded settlement period before final retirement |
| Mailbox lifetime | How long the logical mailbox and required unprocessed inputs remain valid for the process |
| State resource lifetime | How long an associated resource remains usable; required state constrains process recovery |
| Entry lifetime | A separately declared key/value expiry policy, not inferred from history age; outside the first KV profile |
| Association lifetime | How long a PID uses or requires a resource; association does not imply ownership or permission |
| Settlement window | Bounded permission to finish specifically authorized work after the cutoff for starting new work |
| Reconciliation lifetime | How long a connector may establish an attempt's outcome before its acceptance path closes |
| Suspension limit | The latest permitted resumption boundary, constrained by process and recovery-resource lifetimes |
| History retention | The window of past records available for replay or inspection; may advance while a process remains live |
| Resource ownership | Whether a stream survives independently or is retired with a PID, session, or workload scope |
| Post-termination retention | How long state, transcripts, and diagnostic history remain accessible after execution ends |

Process age is not the age of its oldest retained record. A process can run for
years with a 30-day history window if durable checkpoints and the retained tail
preserve its recovery contract. Conversely, an unprocessed input expiring in
five days can constrain recovery even if the PID itself has no age limit.

Workload-scoped streams can be durable throughout their owner's logical life.
Worker loss, migration, and suspension do not end that ownership. Explicit scope
termination or expiry starts retirement under the recorded policy. Resources
shared outside the scope require separate ownership and dependency rules; do
not cascade deletion through every reference automatically.

## Suspension, activation, and expiry

The kernel must maintain a validated recovery basis: committed process state,
mailbox progress and required pending inputs, ownership/lifecycle facts, pending
outputs/effects, and required deduplication evidence. Its availability constrains
execution. Conceptually, at each lifecycle decision:

```text
resume_before <= earliest applicable deadline of:
    process lifetime
    suspension policy
    required mailbox inputs and recovery resources
```

This is a proposed contract, not a fixed timestamp computed once at spawn.
Processing inputs or publishing a validated checkpoint may remove dependencies.
New admissions or authorized policy changes may introduce earlier limits. Such
changes must be serialized and revalidated; arrivals cannot silently renew a
process lifetime or promise a suspension interval the mailbox cannot support.

Station can authorize suspension only within that bound. Reject a requested
resumption time outside the contract. An unspecified suspension duration on a
finite process must expose its finite deadline; it cannot promise indefinite
recoverability. These are eligibility guarantees, not a promise that capacity
or network availability will let a worker resume before the deadline.

For example, an application selects a hard 30-day lifetime for a required input
admitted on day 0. While that input remains unprocessed, suspension until day 40
must be rejected. If a failure nevertheless keeps the process inactive past day
30, the PID expires. Activation on day 40 fails permanently, even if background
cleanup has not removed the input yet. A 30-day window on already completed
history alone would not impose that same process deadline.

At the application's cutoff for starting new work:

1. Refuse new ordinary admissions, turns, and application-effect dispatch
   authorizations. An earlier mailbox admission alone is not a turn authorization.
2. Enter settlement only for work specifically authorized before the cutoff,
   under recorded finite limits. This may permit its application-state commit;
   it cannot start further work or renew its own authority.
3. Close each settlement when resolved or when its limit is reached. Record the
   disposition of unfinished work, including a closed unknown external outcome.
4. Retire the PID when its settlement rights end. Reject further results and
   activation; a replacement has a new PID and an explicit bootstrap policy.
5. Reconcile runtime shutdown, conditional name cleanup, and eventual storage
   reclamation as separate recoverable operations.

A settling PID is not yet retired. Recovery during that interval can resume
only its existing settlement authority, with fresh ownership fencing, not its
ordinary mailbox workload. A hard mailbox/resource availability deadline cannot
be extended implicitly: validate that the recovery basis survives the entire
promised settlement window, or reject the contract. Explicit termination still
retires the PID immediately; an independently owned connector attempt can remain
open under its own previously accepted reconciliation contract.

Cutoffs cannot depend solely on a timer reaching a suspended mailbox. Authorities
must validate the recorded work/settlement contract even when a background
controller is delayed. If current authority or deadline validity cannot be
established, refuse new authorization. Maintenance can record the terminal facts
after recovery without reopening the expired acceptance path.

An attempt authorized before the cutoff is already potentially in flight, even
if its worker was paused before I/O. Expiry cannot promise that the remote action
will never happen. Reconcile that attempt; do not authorize a replacement solely
because its PID expired. A stricter physical-send deadline needs additional
enforcement, as described in [SECURITY.md](SECURITY.md#effects-and-the-limits-of-revocation).

A temporary storage outage is a retryable availability failure, not proof of
expiry. Unexpected missing history is a recovery failure requiring explicit
handling. A known expired contract is terminal. None permits skipping to the
mailbox tail. Restored snapshots or later recovery of old bytes cannot revive
an expired PID; historical inspection remains separate from live activation.

## Time and policy changes

Define the time origin for each policy: admission time, process creation, a
recorded suspension boundary, scope termination, or an explicit deadline.
Ordinary age retention uses trusted admission time; producer event timestamps
do not determine deletion unless the application selects that interpretation.
An idle-time policy would need its own recorded definition of activity.

The bounded profile specifies authoritative time and clock error bounds;
new runtime topologies must qualify their failover behavior. Record effective
deadlines and expiry decisions for deterministic replay;
replaying a trace does not evaluate it against today's clock. Timer notifications
are scheduling hints, not the sole enforcement mechanism. Clock rollback,
partitions, and stale ownership must not extend an expired lifetime.

The implemented M1 contract uses trusted authorization time and conditional
ordering of acceptance versus closure, keeping the upstream Ursula API unchanged.
See [core deadline enforcement](../../packages/zig/transit-core/docs/authority.md#deadline-enforcement)
for the mechanism, clock assumptions, and physical-write timing limit.

### Bounded connector reconciliation

Connectors own how to establish remote outcomes: interpreting responses, querying
operation identities, cancellation, compensation, and safe retry policy. They
declare a reconciliation window and work budget before dispatch. Transit owns
the generic authorization, correlation, ordering, duplicate rejection, and
irreversible closure guarantees on which those policies rely.

An opted-in finite settlement contract must bound reconciliation duration,
attempts, concurrency, and retained working data. Long or unlimited history
retention does not authorize an endless retry loop. Connector attempts can
outlive the caller only under an explicitly recorded independent owner and
lifetime. Recovery cannot reset their deadlines or counters.

When the window closes, stop authorizing further reconciliation work and reject
new result submissions. Preserve either the established outcome or **closed with
outcome unknown**. Closure is not remote failure, cancellation, or proof that a
paused executor will never send. No automatic retry, caller revival, or reopening
follows a late response. A separate investigation needs new explicit authority
and must not mutate the closed attempt's result.

Release active work and payload pins according to the contract. Retain compact
closure/identity evidence for the supported retry horizon; after its reclamation,
old attempt identities must still be rejected through a durable floor or retired
scope. Payload expiry cannot make an old result eligible again. No promise that
the external system stops or rolls back follows from local closure; applications
requiring that guarantee need a connector with matching remote support.

Policy changes are authorized, versioned transitions. A shorter lifetime must
validate existing admissions and dependencies and record any terminal outcome
under an explicitly accepted change policy. An extension must commit before
expiry and while required data is still guaranteed available. Retention changes
cannot restore reclaimed history or reopen a retired PID.

## Retention, compaction, and tombstones

| Operation | Required semantics |
| --- | --- |
| History trimming | Advance an explicit earliest-readable boundary, preserving the declared recovery basis |
| Checkpoint compaction | Replace a validated execution prefix with durable state and protocol evidence sufficient for supported recovery |
| Keyed compaction | Preserve current values by key under declared ordering/version rules; intermediate updates may leave the retained history |
| Tombstoning | Record logical deletion at a specific position/version; physical reclamation can follow later |
| Garbage collection | Reclaim physical data after its logical disposition and dependencies have been resolved |

Execution journals cannot use arbitrary latest-value-per-key compaction. Their
checkpoint must cover state, sequence positions, pending inputs and outputs,
ownership, effects, and deduplication requirements together. Publish and verify
the checkpoint and referenced payloads before authorizing prefix removal. Once
the old prefix is gone, that checkpoint is essential durable evidence, not a
disposable cache. A sandbox memory snapshot is not a substitute.

Keyed application streams may expose a current-state view that excludes
superseded values immediately after committed updates. A tombstone removes its
key from that view. An explicitly retained historical view can still show older
versions until cleanup. Compaction preserves stable logical positions and
ordering; it does not silently turn an ordinary mailbox into a lossy state view.
Keeping the latest value forever and expiring it after 30 days are distinct
application contracts, even when both use compaction.

For [M7 state resources](STATE.md#lifetimes-and-retention), a live value written
40 days ago survives a 30-day history window through a validated recovery basis.
Required-resource expiry permanently ends the dependent PID's recovery window;
optional-resource expiry is an explicit read outcome. Associations cannot renew
resource lifetime or pin every historical revision. PID-owned and independent
resources have distinct retirement rules, even when they share the same storage.

Retain tombstones until supported consumers and recovery paths cannot resurrect
older values. A consumer beyond the supported horizon must reset from a valid
state snapshot or fail explicitly. State resynchronization is available only
where the application stream contract permits it; it cannot repair a terminally
expired process mailbox by skipping required inputs.

## Horizons, dependencies, and capacity

History replay, current-state recovery, consumer catch-up, duplicate rejection,
and post-termination inspection can have different horizons. Advertise them
explicitly. Reads before the retained boundary return an expiry/trim outcome;
they must not appear to be a complete history beginning at a later record.

Consumer watermarks report progress. Retention pins declare data still needed
by a reader, checkpoint, outbox, exchange manifest, or reconciliation operation.
Pins have explicit owners, scope, and release/deadline policy. Ordinary readers
do not acquire an unlimited right to prevent cleanup. A pin can delay a cleanup
target; it cannot silently extend an opted-in hard lifetime. Incompatible
dependencies must be rejected or have a recorded expiry/failure policy before
work is accepted.

Retain minimal control evidence beyond payload lifetime where necessary: PID
retirement, policy/deletion generations, deduplication boundaries, and unresolved
attempt identities. This separate metadata contract must be disclosed and
bounded or compactable; unlimited per-message tombstones are not a capacity
solution. A forgotten retry receipt must not make an old request eligible as
new work. Reject requests outside the supported retry horizon when their
established outcome can no longer be proven. Retired PIDs are never reused.

[Board](BOARD.md#consistency-freshness-and-retention) is a derived reader. Its
caches cannot extend history availability or silently pin data; inspection must
show retained gaps and reauthorize reads after policy changes.

Snapshots, exchange bodies, and referenced payloads must have compatible
lifetimes. Preserve or explicitly retire dependencies before deleting their
data. Expiring a caller does not prove that an HTTP request was never sent;
reconciliation evidence can outlive both caller and response-body retention.
Likewise, deleting a journal prefix does not erase values copied into snapshots,
archives, backups, or projections. A physical deletion deadline requires an
explicit contract covering those copies.

Measure retained bytes, live backlog, pinned bytes, reclaimable bytes, oldest
eligible data, and reclamation lag. Apply quotas independently of time windows:
even 30 days of input may exceed available capacity. Account for temporary space
and I/O used by checkpointing and compaction, and bound background work so it
does not starve admission or recovery.

Admission must leave reserved capacity for bounded control progress: terminal
outcomes, revocations, expiry, delivery bookkeeping, and maintenance checkpoints.
Filling the same store that must record permission to reclaim it creates a
deadlock. Each supported capacity profile must quantify the reserve and
per-operation amplification, cap pending work and maintenance concurrency, and
test full-store recovery. If the
reserve or authority is unavailable, stop new work safely; quotas alone do not
prove that cleanup can make progress.

The implemented [finite admission profile](../../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity)
bounds control work after admission closes. It preserves terminal/maintenance
progress, not guaranteed application drain: a queued state-backed input needing
a new read view cannot open one from the reserve. Station must expose that
blocked condition without treating capacity pressure as expiry. Its [physical-capacity proof](../../tests/README.md#physical-capacity-profile)
records reserve sizing and measured limits. Enabling an admission ceiling alone
does not provision physical capacity or authorize expiry.

The growing (`transit-v3`) engine now accepts the same opt-in shape —
`admission_ceiling` plus an explicit `control_reserve` — closing admission
accounting for that engine specifically; see
[Growing profile: an explicit control reserve](../../packages/zig/transit-core/docs/authority.md#growing-profile-an-explicit-control-reserve-not-a-derived-one)
for why growing's unbounded catalogs rule out reusing the legacy formula. The
signed `capabilities` query now returns the configured ceiling/reserve so
remaining headroom is directly readable, not just inferable from errors. What
is qualified: a [finite physical-capacity proof](../../tests/README.md#growing-physical-capacity)
with real ENOSPC, retained pages, reserved control progress and disk recovery,
plus node/Station quota refusal and reserve exhaustion across restart. The node
does not allocate physical headroom automatically; capacity beyond that declared
workload still requires its own provisioning and measurements.

The M1 [immutable payload profile](../../packages/zig/transit-backend-ursula/docs/storage.md#immutable-payload-deletion)
implements opted-in whole-stream deletion after permanent owner retirement,
with tombstones in separate control history. General payload dependencies and
distributed compaction remain future work; M7 implements bounded KV checkpoint
compaction within the shared realm.

## Logical storage and background reclamation

Transit owns logical identities, policy versions, retained boundaries, and the
authority to expire or retire work. Station provides application-facing policy,
supervision, and state-view helpers. Trusted retention reconcilers perform
recorded maintenance through storage/runtime adapters. Their queues and indexes
are rebuildable; no second authoritative store decides which history exists.

A logical stream may span physical segments. Adapter contracts must describe
append/read, checkpoint publication, retained-boundary advancement, deletion,
incarnation detection, and observable reclamation capabilities. Reject unsupported
guarantees; do not silently substitute weaker expiry or durability semantics.
Ursula is the first adapter, with concrete mappings in the [backend README](../../packages/zig/transit-backend-ursula/docs/storage.md#retention-adapter).
Its cursors and physical stream names do not define Transit's process identity
or retention policy.

Background maintenance must be fenced and resumable: validate the policy and
dependencies, publish required checkpoints, commit the logical trim/retirement
decision, perform the idempotent adapter operation, and record its outcome.
Serialize new dependency admission against that decision so no reference can
be accepted to data already committed for retirement.
Fence writes before deleting a retired stream or segment. Keep enough control
state outside the deleted payload to reconcile crashes and reject stale access.
Never reuse physical identities so a delayed delete can target a replacement.
Readers use the committed logical boundary even if physical cleanup is delayed.

An adapter's deletion acknowledgement is distinct from proof that every copy
has been physically reclaimed. Report the boundary actually observed. Garbage
collection can run after process expiry without prolonging its execution rights.

M1 proves the lifetime contract, deadline fencing, durable recovery basis, and
basic trim/delete recovery. M7 proves associated-state dependencies, KV compaction,
and resource expiry. M9 exposes those semantics through Station suspension and
supervision. [M17](roadmap/M17.md) qualifies Document causal checkpoints, deletion
evidence and opted-in replica merge/resynchronization horizons. M15 adds connector
dependency handling; M16 applies it to streaming
RPCs. [M19 serving](SERVING.md) separates socket/response deadlines from accepted
operation and receipt lifetimes. [M20 reactive APIs](REACTIVE_API.md) separates
session/watch leases and retained change coverage from snapshot/result retention;
gaps require resynchronization and quota pressure cannot delete accepted evidence.
[M21 reactive interfaces](REACTIVE.md) separately bounds refresh work and view
attachment; closing a view cannot erase retained results or accepted commands.
M22 distinguishes [Flight handles and retained results](ARROW.md#identity-lifetime-and-failure)
from transport timeouts. M31 extends the proofs to distributed consumers and
broader recovery operations. See [roadmap](roadmap/README.md).

## Working catalog reclamation

[M8 catalog retention](../../contracts/CATALOG_V1.md) separates bounded working slots
from permanent logical identities. Applications opt in before execution; only
settled/retired entries with resolved dependencies can leave the working catalog.
Durable allocation frontiers and the retained live set prevent identity reuse
after checkpoint/trim. This preserves non-revival while explicitly allowing old
detailed explanations to disappear under the selected history policy. Default
unlimited retention and quota backpressure remain unchanged.
