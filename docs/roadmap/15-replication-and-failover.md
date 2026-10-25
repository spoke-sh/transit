# 15. Replication and durable failover

[Roadmap](README.md) · **Status:** Planned

Let an installation declare a replication and failure-tolerance policy for its
data and control history, then inspect durable copies, committed positions,
replica lag and whether a replacement can safely serve work. Preserve accepted
changes and their original outcomes across the failures named by that policy.
Replication establishes storage/authority continuity before automatic compute
placement and distributed queries.

## Prerequisites and scope

Consume [local storage](02-storage-and-query-performance.md),
[provider/concurrent-writer qualification](14-storage-providers-and-concurrency.md),
the [installed runtime cutover](03-live-storage-and-sql-cutover.md), catalog roots
and the complete native durable-owner inventory. The prerequisites include
[#117](https://github.com/spoke-sh/transit/issues/117) for enforceable writer and
policy fencing, [#121](https://github.com/spoke-sh/transit/issues/121) for provider
durability profiles, [#125](https://github.com/spoke-sh/transit/issues/125) for
snapshot roots, [#126](https://github.com/spoke-sh/transit/issues/126) for native
owners and [#127](https://github.com/spoke-sh/transit/issues/127) for retained
history/pins. Provider correctness and local durability remain earlier
obligations; this milestone qualifies their replicated composition and failover.

Start from [storage](../handbook/reference/storage.md),
[deployment](../handbook/reference/deployment.md),
[retention](../handbook/reference/retention.md) and the
[storage contract](../../contracts/TRANSIT_STORAGE_V1.md). Neither shared object
storage nor a replicated provider by itself establishes complete Transit
recovery. Cover catalog/control policy, native process progress, receipts,
KV/Documents/Tables, effect evidence and required captured/stream payloads,
including accepted unflushed WAL state and directly published bulk objects.

Replicate the [transaction owner's](05-transactions-and-atomic-composition.md)
participant preparation, durable decision, visibility cut, receipts and committed
outbox eligibility as one recoverable history. Promotion must not expose a subset
of committed participants, invent an abort or redispatch a captured effect.
Follower reads need an explicit isolation/freshness contract; replication alone
does not make independent snapshots atomic or establish real-time ordering.

## Delivery sequence

1. **Define replication policy and the failure model.** Select and document the
   first executable topology, failure domains, membership, trusted components,
   acknowledgement point and tolerated failures before choosing its mechanism.
   Distinguish a synchronously protected commit from asynchronous remote copying;
   report their different availability and potential data-loss boundaries. State
   which guarantees the provider supplies and which Transit must enforce. Do not
   assume Ursula, Kafka/Pulsar or object-store providers are interchangeable, or
   require a second consensus engine where a qualified provider owns that role.
2. **Specify one replicated commit and recovery boundary.** Bind durable log
   positions, policy/ownership epochs, catalog/checkpoint roots and all required
   immutable objects. A replica cannot become eligible from an advanced log
   watermark if referenced objects or control evidence are missing. Define
   quorum/commit rules for the selected profile, ambiguous acknowledgements,
   promotion eligibility and recovery of the original accepted operation.
   Replication cannot introduce an independent writable manifest authority.
3. **Implement bounded bootstrap, catch-up and repair.** Transfer a verified
   checkpoint plus its pinned contiguous tail and reachable objects; validate
   identities, definitions and digests before installation. Coordinate snapshot
   creation, compaction, retention and replica removal so required history cannot
   disappear mid-transfer. Bound memory, I/O, concurrency and retry work; expose
   stalled progress and explicit rebootstrap when history is unavailable. Quota
   pressure cannot silently discard accepted state or retention obligations.
4. **Qualify membership change and authority failover.** Record configuration
   transitions durably, fence former writers and removed replicas at append,
   conditional publication and disclosure, and reject stale policy. Prove
   controlled failover before automatic scheduling; replacement readiness comes
   from verified committed history and current authority, never pod health.
   A minority or disconnected former owner cannot continue protected writes.
   Rejoining nodes recover the committed history without resurrecting divergent
   proposals. Define read consistency explicitly; follower reads need their own
   current-authorization and source-basis proof or remain unsupported.
5. **Expose policy and observed replication state through public owners.** Define
   typed configure/inspect/membership/failover operations with current scoped
   authorization before adding syntax. Report selected policy, configuration and
   epoch, committed/durable/applied positions, object coverage, lag, blockers and
   promotion readiness separately. Board consumes read-only public inspection;
   provider credentials and metrics cannot authorize a promotion.
6. **Qualify the selected real deployment profiles.** Use disk-backed providers
   and real network/storage faults in Compose and Kubernetes/Substrate as
   applicable. Carry the exact contract into [operations](16-operations-and-recovery.md)
   and [clustered execution](17-clustered-execution.md). Automatic worker/query
   placement, disaster restore to an older cut and cross-region live failover are
   separate profiles; asynchronous copying alone qualifies none of them.

## Completion evidence

Include [index definitions, coverage and build state](08-indexing-and-access-paths.md)
in the recovery inventory. Decide which physical generations replicate and which
are rebuilt from retained authoritative data. Promotion must preserve constraint
enforcement and use an index only after proving coverage; a rebuilt acceleration
index may remain unavailable while a qualified scan serves reads. Test failover
during backfill, catch-up, readiness publication and unique-key conflicts.
Extend the [performance scorecard](10-data-structures-and-performance.md) with
replicated commit latency, bounded rebuild/catch-up and control progress under
index maintenance load.

Run public SQL and typed callers through leader/writer loss, lost replies,
network partitions, quorum loss, delayed/stale replicas, membership changes,
missing/corrupt objects, concurrent compaction and catch-up interrupted by restart.
For each selected profile, verify every acknowledged operation survives its
declared failure envelope, uncertain operations resolve under their original
identities, and uncommitted proposals never become visible. An unavailable quorum
is an explicit refusal/uncertainty condition, not permission to weaken durability.

Verify policy revocation, permanent retirement, native input/state/output
atomicity, recorded effect outcomes and no dispatch during recovery. Include
failure before flush, during multi-object transaction preparation/decision,
after commit with a lost reply and immediately after bulk publication, and retained state
larger than RAM/cache. Check state and source bases against independent oracles.
Measure commit latency, lag, failover, catch-up throughput and reserved control
progress separately. Record topology, provider configuration and actual fault
coverage in the [proof ledger](../../tests/README.md); process kills alone do not
prove host/disk loss, zone failure or power-loss durability.
