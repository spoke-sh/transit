# Queue lease and settlement bindings v1

## Implemented boundary

[`transit-protocol.StreamQueue`](../packages/zig/transit-protocol/src/StreamQueue.zig)
defines neutral Queue append, lease, settlement and original-receipt bindings.
Its pure validators do not create a Queue, claim a message, authenticate a receipt
or commit state. No installed `CREATE QUEUE`, `ENQUEUE`, `CLAIM`, `ACK`, `NACK`
or `EXTEND LEASE` operation is enabled by these types. Queue transaction
participants continue to reject before acceptance.

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

The future Queue owner must provide these guarantees before enabling claims:

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
