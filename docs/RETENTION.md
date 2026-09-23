# Retention and resource lifetimes

Status: application opt-in and lifetime guarantees are established requirements.
Policy fields, record names, deadline mechanics, and reclamation algorithms below
are the target contract. The [experimental v1 profile](../contracts/TRANSIT_V1.md)
implements explicit checkpoint/trim opt-in for quiescent or explicitly cancelled
mailboxes, verified publication, and checkpoint-plus-tail recovery. Finite
time policies, turn settlement permits, reconciliation observation budgets, and
due-maintenance selection are implemented with a trusted clock interface. The
disk proof uses controlled time; the Linux service clock reads the synchronized
kernel's reported error bound. A separate
[`transit-node --maintain` process](../contracts/SERVICE_V1.md) now commits due
expiry/closure and reconciles opted-in checkpoint/trim operations. Physical
capacity reservation now has a bounded single-node proof below. A minimal
immutable-payload catalog also records publication, retirement, and deletion;
the separate maintenance process reconciles whole-stream deletion. General
resource dependencies, finite body lifetimes, and compaction remain later work.

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

M1 must specify authoritative time, clock error bounds, and failover behavior.
Record effective deadlines and expiry decisions for deterministic replay;
replaying a trace does not evaluate it against today's clock. Timer notifications
are scheduling hints, not the sole enforcement mechanism. Clock rollback,
partitions, and stale ownership must not extend an expired lifetime.

### M1 deadline enforcement investigation

The selected contract permits previously authorized work to settle within a
bounded window (option 1). There is no requirement that every physical storage
write finish before the earlier cutoff for starting work. Final settlement
closure is irreversible: it rejects late results, even if the request originally
started on time. A historical receipt can still be read under current permission;
returning that receipt is not accepting a new result.

Keep the upstream Ursula API unchanged. Transit must record the authorized work,
its finite settlement rights, and closure in the same authority ordering. A
worker's prepared proposal or claimed timestamp is not a durable settlement
grant. Closure and result acceptance race through conditional append: once
closure wins, an old prepared result cannot append or reopen the attempt.

The [implemented profile](../contracts/TRANSIT_V1.md#authority-time-and-bounded-settlement)
uses trusted validation time at the expected journal tail as the authorization
boundary. Its recorded uncertainty must fit the realm's configured bound.
Persistence may finish later; an intervening closure or policy operation fences
the candidate and forces fresh validation. A result first validated after its
window is rejected even if a closure controller is delayed. Clock rollback below
the durable high-water mark fails closed. This is an explicit authorization-time
contract, not a guarantee that all physical writes stop at the UTC cutoff.

The executable proof uses controlled time. A deployment still needs a trustworthy
synchronized source and periodic maintenance; ordinary host wall-clock readings
do not establish a UTC error bound. Reject finite contracts without the required
realm opt-in and time source. Replay applies recorded time evidence.

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
deadlock. M1 must quantify the reserve and per-operation amplification, cap
pending work and maintenance concurrency, and test full-store recovery. If the
reserve or authority is unavailable, stop new work safely; quotas alone do not
prove that cleanup can make progress.

### M1 bounded capacity profile

Genesis may explicitly set `admission_ceiling` between 2 and 65,536 journal
positions. The default is unset. Once reached, Transit rejects new admissions,
spawns, grants, activations, running-provider intents, and effect dispatches.
It can finish already admitted scalar inputs, settle existing outputs/attempts,
revoke grants, retire processes, stop provider resources, and checkpoint once.
Turns cannot introduce new outputs/effects into this reserve. Reads remain
available. Repeated revocations, repeated unknown provider observations, repeated
stop intents, and further checkpoint intents cannot consume unlimited records.

This is an explicit finite allocation for the experimental realm, not a retention
deadline. It never expires a PID, cancels input, or authorizes deletion by itself.
An accepted input whose completion requires a new effect remains pending; only
explicit termination or its original opted-in expiry can cancel it. Trim and
restart do not reopen admission. Online expansion/rearming is not implemented;
do not enable this profile expecting a self-resizing production store.

For ceiling `N`, the conservative post-ceiling bound is
`2*(N+256+128) + 128*17 + 64*6 + 16 + 16*3 + 1` accepted records: at most a permit and
turn per old/newly delivered input, finite attempt observations/closures, bounded
provider completion/stop and retirement, revocations, payload publication/
retirement/deletion, and one checkpoint.
Typed journal entries are capped at 4 KiB and checkpoints at 1 MiB.
Pending preauthorized payload creation can additionally write at most sixteen
64 KiB bodies (1 MiB total); those bytes need their own reserved headroom.
Transport failures and backend housekeeping are not accepted protocol records; physical
provisioning must additionally cover their amplification and temporary files.

`just test-capacity` proves the `N=256` profile against the pinned official
Ursula image on an owned 2 GiB ext4 filesystem, with a physically allocated
1 GiB reserve file. It fills only that filesystem, observes real `ENOSPC` and
Ursula's disk-pressure write rejection, and releases only the reserve. The filler
stays in place while Transit revokes a grant, expires an opted-in PID, closes an
unknown attempt, drains the unlimited PID's accepted backlog, and checkpoints
and trims. SIGKILL/restart preserves retirement, closure, and closed admissions.

The fixture uses 251 post-ceiling records. A passing run grew WAL allocation by
167,936 bytes during control recovery; current measurements are emitted by the
recipe. The conservative current bound
is 3,905 records (15,994,880 bytes plus a checkpoint). The 1 GiB physical reserve is
a tested envelope for this configuration/schedule, not a universal filesystem
or Ursula write-amplification guarantee. The fixture asserts control growth
stays below 128 MiB and free space remains above the 32 MiB resume threshold.
Keep one maintenance writer and bounded authority concurrency; unbounded crash
loops, unrelated disk writers, disk loss, other topologies and larger allocations
need separate qualification. An absent/exhausted reserve fails closed and needs
operator capacity recovery; it does not create expiry permission.

Completed maintenance now verifies the existing checkpoint/floor before writing.
After restart the adapter uses only GET/HEAD for that already completed intent;
it does not repeatedly publish or trim. Ursula can still change its internal WAL
during reads/recovery, so raw WAL equality is not a valid no-mutation assertion.
The fixture records adapter HTTP methods and stores measurements in the ignored
`.cache/capacity-evidence.json`.

### M1 immutable payload deletion

The initial resource catalog supports sixteen lifetime payload identities, each
at most 64 KiB, owned by an unlimited-lifetime PID. They are immutable standalone
bytes; no mailbox/state/effect field can depend on them in this scalar profile.
Finite owner/body lifetimes are rejected as unsupported rather than inferred.
General reference admission, large body streams and connector replay dependencies
need their own later contract.

A declaration records owner PID, publisher principal, length, SHA-256, and
`allow_delete` (false by default). Its journal position is its logical identity;
neither logical nor derived physical names are reused. A trusted publisher makes
one atomic Ursula create with the complete body and `closed=true`, verifies the
closed stream and hash, then records readiness. Creation and publication are
trusted control operations, not application handler capabilities. The publisher
must be serialized and issue no duplicate PUT: a lost receipt or restarted
publisher may only verify the original attempt. A missing stream stays uncertain;
it is not recreated. An unresolved creation remains pinned, with bounded catalog
and payload capacity; maintenance does not poll or discard it indefinitely.

Once the owner is permanently retired, an opted-in, positively published payload
can enter `retiring`. That durable record removes logical availability before
physical deletion. Background maintenance checks current grants, verifies the
stream is closed, issues DELETE, confirms 404, and records `deleted`. A crash
after DELETE leaves `retiring` in the control journal/checkpoint; a subsequent
404 completes that same intent. Storage errors are not deletion evidence.
Creating/default-retention payloads are not eligible, and late publication or a
new dependency cannot reopen a retired identity. Physical erasure of old WAL,
snapshots, backups or external copies is not claimed by a DELETE acknowledgement.

`just test-storage` kills/restarts disk Ursula after publication and after DELETE
but before recording its outcome, including checkpoint/trim of the control
history. `just test-service` proves automatic background retirement/deletion and
that default-retention bytes remain readable by the trusted storage verifier.

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
Ursula is the first adapter, with concrete mappings in [URSULA.md](URSULA.md#retention-adapter).
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
basic trim/delete recovery. M2 makes those semantics explicit in suspension and
supervision. Later milestones add connector dependency handling and broader
compaction/retention operations; see [ROADMAP.md](ROADMAP.md).
