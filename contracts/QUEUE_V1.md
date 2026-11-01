# Queue lease and settlement bindings v1

## Implemented boundary

[`transit-protocol.StreamQueue`](../packages/zig/transit-protocol/src/StreamQueue.zig)
defines neutral Queue append, lease, settlement and original-receipt bindings.
Its pure validators do not create a Queue, claim a message, authenticate a receipt
or commit state. The signed [Queue action](DIRECT_TABLE_V1.md#queue-payloads-claims-and-settlements)
composes standalone enqueue, claim, original payload reads and settlements.
SQL `CREATE QUEUE`, `ENQUEUE`, `CLAIM`, `ACK`, `NACK` and `EXTEND LEASE` remain
unavailable. Native [transactional log work](DIRECT_TABLE_V1.md#transactional-stream-and-queue-work)
composes enqueue, fenced ACK and paired dead-letter transfer with Table/KV state.

The [typed catalog lifecycle](DIRECT_TABLE_V1.md#stream-and-queue-lifecycle)
publishes Queue declarations separately from payload execution. It verifies
partition initialization, native ownership, compatible DLQ schemas and exact
destination definitions, and publishes retained dependency edges atomically.

The internal `transit-storage.QueuePartition` accepts enqueue payloads and their
initial FIFO/eligibility/`.tack` state in the same WAL record as producer
deduplication and the original receipt. It shares physical sealing, archives,
checkpoints and bounded recovery with the Stream owner. Replay reconstructs the
complete Queue candidate without object writes. Bounded claims now publish their
original selection, acquired bits, epochs, attempts and deadlines together.
Original empty and nonempty outcomes survive restart and expiry; new selection
requires a new operation. Capacity exhaustion refuses instead of publishing a
false empty result. ACK, NACK, renewal and bounded expiry also publish complete
successor roots with current authorization and conservative deadline checks.
Bounded original-claim reads return owned payload rows and separately observed
lease status. The catalog adapter `DirectQueue.apply` binds those
operations to current native Queue grants and the shared operation namespace.
Claim receipt inspection and payload pages require read and acquire privileges;
settlement requires settle privileges. It rechecks authority after buffering,
preserves original outcomes through compatible ALTER/DROP, and reports bounded
incomplete recovery before accepting fresh work. The native signed service and
typed client expose this standalone composition. The local maintenance executor
seals and archives Queue payloads and expires at most one accepted lease per
unit. Expiry requires the trusted lower time bound to reach the current deadline,
also after retirement; it preserves payloads and original receipts. Visibility
and lease schedules use bounded deltas and paged time-bucketed runs. Separate
physical maintenance publishes resumable merges and stale-event sweeps without
changing logical lease state or requiring a clock. Its frozen inputs and Queue
basis remain retained until accepted progress releases them; recovery rederives
each complete successor. The [storage contract](TRANSIT_STORAGE_V1.md#private-scheduling-source-composition)
defines these bounds and publication rules. Explicit dead-letter transfers use
the same native transaction decision; automatic blocked-item transfer scheduling
remains unimplemented.

The shared [Stream contract](STREAM_V1.md) owns partition and append attribution.
The [data lifecycle schema](data-lifecycle-v1.schema.json) and
[fixture](../packages/zig/transit-protocol/src/fixtures/stream-queue-v1.json)
are generated/checked through the existing public contract workflow.

## Lease identity and time

The declaration's Queue policy selects `unordered` or `key_fifo`. FIFO requires
a stable key column; with multiple partitions that column also supplies routing,
so equal canonical keys share a partition. Default and maximum lease durations
are positive, the default does not exceed the maximum, and maximum attempts is
nonzero. Deadline calculation rejects unsigned overflow and requested durations
outside the maximum.

Retry backoff records initial/maximum milliseconds and a positive multiplier.
Attempt one uses the initial delay; later delays multiply with saturation and
clamp at the maximum. Calculation work is bounded by integer width even for a
full-width attempt count. Zero initial delay and multiplier one are explicit
constant-delay policies. Exhaustion does not itself discard a message.

An optional DLQ binds an exact destination definition in the same catalog and
branch and cannot point back to its source object. Catalog publication must
also check destination kind/schema, dependencies and current permissions.
Pure configuration validation does not establish any of those facts.

`Lease` binds the current definition through its target, the exact Queue
interpretation/partition, original claim operation, logical message offset,
nonzero lease epoch, nonzero attempt count and absolute expiry in milliseconds.
The maximum unsigned offset is excluded because a record must have a
representable exclusive successor. A claim's operation and target share a scope.
Batch claims may share one operation but have different offsets/epochs.

The structure is the semantic body to be authenticated by an eventual owner;
it is not a bearer credential. A runtime must verify the signed receipt, recorded
claim, object kind, current claimant rights and worker/lifecycle fences.
Current Queue state, not a payload's claimed identity, establishes the holder.

`requireLive` requires exact equality with the owner's current lease, including
the original claim, interpretation, offset, epoch, attempt and expiry. A mismatch
is `QueueLeaseFenced`. Missing authoritative time is `QueueTimeUnavailable`.
Time at or beyond expiry is `QueueLeaseExpired`, even when cleanup has not run
and no worker has acquired a newer epoch. Renewal publishes a new exact receipt;
the old expiry-bearing receipt cannot authorize a later settlement.

The owner must supply trusted time and serialize its validation with publication.
An in-memory timer, local caller clock or delayed wakeup is insufficient.
Clock rollback and restart require the owner's persisted time/fencing contract;
these validators do not establish that contract from an arbitrary integer.

`LogClock` records the last accepted authoritative time floor. The owner
obtains trusted time under the decision guard and persists its nondecreasing
floor with lease-affecting outcomes. A missing clock returns
`LogTimeUnavailable`; a value below the persisted floor returns
`LogTimeRegression`. Neither restart nor delayed timer processing resets the
floor. Supplying an integer to this pure check does not establish a trusted
clock source.

The storage candidate transitions use `LogTime.Sample`'s trusted closed UTC
interval. Claim visibility requires the lower bound to reach `visible_ms`;
claim expiry is the upper bound plus the checked lease duration. Settlement
requires the entire interval to precede expiry. An interval spanning expiry
returns `QueueTimeUnavailable`, allowing neither settlement nor reassignment;
expiry processing requires its lower bound to reach the accepted deadline.
The storage publication owner repeats these checks under its guard and
preserves the accepted upper clock floor. Pure transition checks alone provide
no trusted clock or durable acceptance.

NACK backoff starts at its observed upper bound and honors a later requested
visibility time. Backoff after lease expiry starts at the accepted deadline;
restart downtime or delayed cleanup does not start that delay again. Exhaustion
keeps the source available but blocked, with its FIFO successor still blocked.
A configured DLQ records its exact destination definition with the blocked
reason, not the source's terminal state. Later policy edits cannot redirect it.
The common transaction must establish destination durability before transfer.
Stored items and public lease observations require nullable `blocked_after_ms`:
it is present exactly when blocked, and records the accepted NACK upper bound or
expiry deadline. Missing fields never default to the current clock. Exhausted
transfer binds this value, current epoch and attempt; the decision's trusted
lower time bound must reach it. Source terminalization and the destination append
are published only through a verified paired transaction decision. Recovery
preserves that decision without requiring a clock or dispatching effects.

## Claim selection and original results

The public signed Queue `wait` action schedules the same claim for at most
1000 milliseconds. It uses current eligibility, FIFO, capacity and trusted-time
checks and returns the original receipt if that claim was already accepted.
While no item is eligible it publishes no empty claim. Timeout returns an
observed cut; it is neither a retention pin nor proof that a concurrent attempt
was rejected. Publication notifications and the next delayed visibility deadline
trigger fresh authorized checks. See the [direct action contract](DIRECT_TABLE_V1.md#queue-payloads-claims-and-settlements)
for admission, cancellation and recovery semantics.

`Claim` freezes the exact target, original operation, positive maximum row count
and positive lease duration. The owner applies declaration limits and current
rights at publication. `ClaimReceipt` records the original claim, accepted WAL
position, observed authoritative time, checked expiry, returned row count and
immutable content reference for the exact leased selection. Every selected
lease must bind that claim, target and expiry; epochs and attempts come from
the accepted per-message state. Selection cannot exceed the requested maximum.
Expiry equals observed time plus requested duration without overflow.

An empty accepted claim has zero rows and no selection content. Its original
retry remains empty even if messages become available later. A changed maximum,
duration or target under the same operation conflicts. A new selection requires
a new operation identity. A nonempty receipt retains its selection and payload
dependencies across disconnect and restart. Receipt disclosure needs current
rights, and later execution still needs the current live lease. These neutral
receipt types perform neither selection nor durable acceptance.

### Original payload traversal and observed lease status

`transit-protocol.QueueRead.Cursor` binds an exact original `ClaimReceipt` and
the next ordinal in that selection. The ordinal is not a message offset. The
owner resolves the original accepted operation and compares the entire receipt;
supplied content references cannot select other work. An ordinal may address
any position through the original row count. This cursor is a read selector,
not an authenticated consumption proof, lease or grant. Traversal neither claims
new work nor settles a message.

The storage `readClaimPage` operation applies current read budgets and returns
owned row bytes with original producer operation/ordinal attribution. It fills
bounded pages across original append batches, stops before exceeding the encoded
row-byte budget, and marks the returned cursor complete exactly at the original
selection's row count. A row that cannot fit an empty page refuses without
advancing the cursor. A complete cursor means this selector has reached the end;
it does not prove that an arbitrary caller read earlier ordinals. Current read
rights are checked again after buffering, including original empty selections
and repeated terminal pages. Retrying a page preserves its original payload
selection, while its separately reported status observation can advance.

`QueueRead.Basis` records the current partition cut and optional trusted closed
UTC bounds. The immutable original selection separately retains its original
payload placement cut. Do not describe changing lease observations across pages
as one atomic status snapshot. `LeaseObservation` carries the original lease,
current available/acquired/acked/archived state, epoch, attempt, optional deadline
and blocked reason, without revealing another holder's claim identity.

Liveness is `live` only when the original lease still matches and the entire
trusted interval precedes expiry. It is `expired` when the lower bound reaches
that matching lease's deadline, and `unavailable` when time is missing,
regressing or spans expiry. It is `fenced` after renewal, reassignment or leaving
the acquired state. An acquired bitmap state can therefore coexist with an
expired observation before bounded cleanup runs. Clock uncertainty does not
prevent recovery of original payloads, and an observation supplies no authority
for a later settlement: that operation must revalidate the live lease and current
rights at publication.

### Stored nonempty claim selection

The internal `QueueSelection` candidate artifact begins with `QCLAIM01`, the
32-byte shared definition, a big-endian u32 metadata length and a big-endian u32
row count. Canonical structured metadata follows, then three big-endian u64s per
row: logical offset, lease epoch and attempt. Offsets are strictly increasing;
the common target, original claim and expiry come from metadata. A changed
selection cannot reuse an original receipt's content digest.

Metadata retains its required definition, exact declaration, original claim,
trusted time interval, expiry, accepted position and the preceding payload
placement cut, including its mandatory retained lower and next-offset boundaries.
Every selected offset lies within those original boundaries. The acceptance position is exactly one log record after that
cut. Metadata is bounded to 16 KiB and a selection to 4,096 rows, additionally
restricted by the declaration and owner budgets. Missing or foreign
definitions, noncanonical metadata, duplicate offsets, trailing bytes and
truncation reject. An empty claim has no selection artifact; its receipt remains
the original empty result. The storage owner verifies the exact selection during
claim publication and replay. The artifact alone supplies no publication,
retention or current-authority guarantee.

## Explicit original payload-read closure

`QueueRead.Release` freezes a new operation by the original claimant and the
entire accepted `ClaimReceipt`. The signed Queue `release` mutation resolves
that exact original claim and requires current read and acquire privileges.
Its `ReleaseReceipt` records acceptance in the same partition after the claim.
Retrying the saved release recovers the same outcome; changing its claim under
that operation conflicts. A different release operation for an already closed
claim returns `QueueReadReleased`. Empty accepted claims can close too.

Acceptance permanently closes payload-page traversal for that claim, including
repeated terminal pages. It preserves the original claim receipt, selection and
lease identities. It neither ACKs, NACKs, renews nor cancels a lease, and it needs
no trusted clock. A still-live lease can subsequently settle through its usual
authorized operation. Closure remains available after compatible ALTER or DROP.
Closing a transient client result or disconnecting does not issue this mutation.

The Queue WAL accepts closure evidence and its paged claim index together.
Retained traversal may omit the selection's payload-placement roots only when
that same retained cut contains the accepted release. Older replay roots retain
their own dependencies; current Queue data and any other open selection retain
theirs independently. Closure alone authorizes no payload expiry or deletion.
Terminal cleanup additionally needs declared retention and the owning logical
expiry and physical collection gates.

## Terminal payload retention

Retention remains unlimited unless `max_age_ms` is explicitly declared. The
storage owner and local native maintenance can expire at most one whole sealed
append batch at the current retained prefix per unit. Its accepted append must
have a trusted time; the current trusted lower bound must reach that append's
upper bound plus the declared age. An unsealed, untimed, not-yet-due or
nonterminal batch stops that prefix. Later terminal batches remain retained until
the prefix reaches them. Delay, lease expiry, retry exhaustion, blocked DLQ work,
DROP and quota pressure never substitute for terminal state or retention policy.

The `.tack` directory lookup resolves the exact batch's accepted state vector.
Its four cardinalities provide a constant-time terminal check after the bounded
paged lookup; every item must be ACKed or durably archived. This profile currently
publishes ACK terminalization and transactionally archived DLQ sources.
The owner revalidates policy, time, original append and terminal state, removes
only that batch's current placement entries, and records the new retained lower
boundary. Queue replay reconstructs both successor directories exactly, refusing
unrelated removal without writing objects. Metadata, producer fences, original
claim/settlement receipts and logical offsets remain unchanged.

Lease expiry and terminal payload retention occupy separate bounded maintenance
classes. Retention uses reserved control capacity and remains available after
DROP under its frozen opted-in declaration. A Queue observation's `retained_from`
reports the current payload prefix; an open original claim can still read offsets
below it from its frozen placement roots, with current lease status and rights.
Physical collection requires explicit claim-read closure and closure of every
other retained dependency, including replay checkpoints. Neither expiry nor a
release by itself proves that payload bytes can be deleted.

## Settlement and original outcomes

`Settlement` freezes a distinct original operation by the claiming principal,
the exact lease and one action: `ack`, `nack` with a requested visibility time,
or `extend` with a strictly later expiry. The runtime must also enforce its
maximum lease duration, retry/backoff policy and scheduling limits. A NACK
visibility time in the past can mean immediately eligible; it cannot erase
FIFO or policy obligations.

For fresh publication, `requireLive` checks the supplied live lease and time.
`requireSame` compares the entire operation, receipt and action. Changing a
retry delay or renewal deadline under the same operation is a conflict.
Stopping a client wait or closing a result buffer does not settle a claim.

`SettlementReceipt` records the exact settlement and a nonempty accepted WAL
position. `requireSettlement` recovers that original binding without applying
today's lease-expiry check. An ACK accepted before expiry remains accepted after
expiry, reassignment or revocation; its disclosure still requires current
authorization and verified accepted evidence. A timeout or missing receipt
establishes neither rejection nor acceptance.

## Required execution and storage boundaries

The integrated Queue service must provide these guarantees before exposing claims:

- Durable enqueue deduplication and exact claim-result recovery. Retrying a
  disconnected claim cannot lease a different selection under the same identity.
- Disjoint per-offset `Available`, `Acquired`, `Acked` and `Archived/DLQ` states,
  plus separately durable lease/deadline/attempt metadata. A bitmap alone does
  not encode a lease or authorize its owner.
- `key_fifo` ordering by the declared canonical key: the earliest nonterminal
  offset blocks later offsets for that key, including its delay/retry interval.
  Other keys remain eligible. Hash collisions never establish key equality.
- Bounded active-lease/affinity caches and deadline work over a paged durable
  backlog. Recovery and clock jumps cannot load every retained item into RAM.
- Current authorization and live lease validation at a common transaction
  decision that publishes input ACK, state mutations and outbound intents
  together. A prepared draft has no public effect. An expired lease cannot commit
  while waiting for reassignment; a previously committed decision survives expiry.
- Durable DLQ destination/payload reachability before source terminalization.
  Denial, missing storage or destination capacity produces blocked progress.
- Unlimited default retention. A fully terminal segment may be eligible for
  cleanup only after policy and every retained reader/replay/transaction
  dependency permit it. Terminal counts alone authorize no deletion.

Database acceptance does not promise exactly-once remote effects. Connector
redelivery must preserve recorded attempts, unknown outcomes and current dispatch
policy; replay never dispatches an effect.

## Verification scope

The [finite Queue model](../tests/verification/models/README.md#finite-queuepartition-lease-and-turn-commit-model)
checks selected state, time, policy, decision and retention invariants, including
negative controls. It assumes atomic accepted state and does not implement a
Queue partition, timing wheel, persisted receipt authentication or storage
recovery. Pure Zig contract checks independently exercise exact identity,
time-at-expiry, unavailable time and original-receipt recovery. Implementation
correspondence and physical fault proofs remain separate execution gates.
