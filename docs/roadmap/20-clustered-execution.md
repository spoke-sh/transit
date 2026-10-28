# 20. Clustered execution and storage-disaggregated placement

[Roadmap](README.md) · **Status:** Planned

Extend typed exchanges and manual single-authority handoff into automatic
placement, fenced partition lease transfer and distributed query execution over
the [disaggregated four-tier storage architecture](02-storage-and-query-performance.md).
The [deployment reference](../handbook/reference/deployment.md) and
[runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md) own present behavior.

Placement serves declared data and computation. Because durable state lives in
shared **`TransitLog`** partitions (Ursula, Kafka or Pulsar) and shared
**`TransitObjectStore`** segments (`.tseg`/`.tdel` and Manifests in S3/GCS/R2)
with stateless local NVMe read-through caches on worker nodes, moving a table
partition or Station process group between Kubernetes/Substrate pods requires
no relocation of authoritative data when all required WAL, native checkpoint
and object state already survives in shared storage. This is a selected topology
property, not a guarantee for local-only WAL or disk state. Expose deployment availability separately from
declaration progress and freshness; rescheduling a healthy pod does not
establish that a derived result is current.

Extend the existing [transaction model](05-transactions-and-atomic-composition.md)
and [provider/writer contracts](17-storage-providers-and-concurrency.md) to each
advertised placement. Specify coordinator/participant movement, decision recovery,
visibility and snapshot retention before advertising cross-host transactions.
Moving computation does not widen the atomic domain automatically. Distributed
queries consume the selected complete cut and preserve provisional/terminal
result meaning; neither partition arrival order nor worker completion is commit.

## Delivery sequence

Require [replication and durable failover](18-replication-and-failover.md) and
[operations, backup, restore and upgrades](19-operations-and-recovery.md) for the
selected storage/deployment profile. They establish recoverable durable state,
promotion rules and operational procedures before this milestone automates
worker placement. The [statement-result milestone](04-statement-results-and-consumption.md)
supplies the shared result/batch lifecycle for distributed Fuze consumers.

Consume the provider trust/durability profiles in
[#117](https://github.com/spoke-sh/transit/issues/117) and
[#121](https://github.com/spoke-sh/transit/issues/121), complete durable-owner
inventory in [#126](https://github.com/spoke-sh/transit/issues/126), source roots
in [#125](https://github.com/spoke-sh/transit/issues/125), and retained-history/pin
contract in [#127](https://github.com/spoke-sh/transit/issues/127). This milestone
adds routing/placement and distributed execution, not a replacement permission
or commit authority.

1. **Select topologies and define partitioned authority, routing, placement and provider-conformance contracts:**
   close controller gaps before automatic scheduling. Bind placement decisions
   to **Control/Policy Log** epoch leases `(partition_id, writer_epoch, policy_epoch)`
   with an enforceable revocation/handoff boundary at append, publication and
   disclosure. Use the chosen provider mechanism from #117; a cached epoch,
   signed lease or retained storage credential alone does not fence old pods.
2. **Transfer partition leases and recover workers from checkpoints and retained tails:**
   when a Station group or Table writer moves to a new node, the new node acquires
   the incremented `writer_epoch` lease, loads the latest committed `manifest/v{N}`
   from `TransitObjectStore`, replays only the uncompacted `TransitLog` tail into
   its Tier 0 state, restores native control/process evidence as required, and
   warms its Tier 2 NVMe cache on demand via content-verified
   range reads (`get_range`). Qualify process/grant/mailbox safety before moving
   effects; physical pod readiness never grants execution authority.
3. **Implement locality-aware distributed `Fuze` query execution over `.tseg` segments:**
   assign `.tseg` segment lists across `Fuze` workers using consistent hashing on
   immutable segment keys so workers keep hot `.tseg` column pages pinned in
   their local Tier 2 NVMe cache and Tier 0 RAM buffer pool. Qualify query
   repartitioning independently of lease reassignment, preserving source vectors,
   batch ownership, explicit collations and checked 5-state arithmetic (partial
   aggregation must not silently reassociate errors).
4. **Exercise multi-writer OCC publication, compaction, Document windows, serving, watches and Flight tickets across placement changes:**
   ensure background `.tseg` compaction and multi-writer Manifest CAS commits
   proceed safely alongside worker rescheduling without stalling interactive
   reads or `TransitLog` tailing.
5. **Qualify existing operational procedures across placement changes:**
   exercise the operations milestone's backup cuts, restore activation,
   maintenance/drain and upgrades while partitions move and workers fail.
   Expose partial Board observations with their source/coverage evidence. Reuse
   the replication milestone's promotion and copy guarantees; cross-region
   object copying alone cannot establish live failover or point-in-time recovery.

## Formal model follow-through

Extend the [T3/T5/T7 and A3 candidates](16-formal-semantics-and-correspondence.md#later-ownership-and-extensions)
where the selected placement and execution contracts require them. Check owner
handoff, complete source/transaction coverage and preserved ordering/error
semantics across worker replacement and repartitioning. Connect selected models
to production schedules and finite query oracles, recording profile assumptions
and deferrals. Local concurrency or algebraic proofs do not automatically
establish distributed memory, progress or snapshot guarantees.

## Completion evidence

Extend [index coverage](08-indexing-and-access-paths.md) and the
[local cost/performance model](10-data-structures-and-performance.md) to routed
partitions, transferred build ownership and distributed scans/probes. Qualify
partition/global constraint scopes, complete snapshot coverage and fallback
during movement; summing local readiness flags proves neither global uniqueness
nor one atomic cut. Measure routing, network transfer, data skew, cache locality,
spill and durable runtime scheduling under mixed database/Station load. Compare
scale-up and scale-out with equal resource and failure guarantees, reporting
tail latency and recovery progress alongside aggregate throughput.

Run single-node controls and inject faults at lease acquisition, `TransitLog`
append, `.tseg` staging, conditional Manifest CAS publication, NVMe cache
eviction/corruption, pin release, disclosure, retirement and garbage collection
across Compose and Kubernetes/Substrate (`Ursula + S3 + Substrate`) profiles.
Require `writer_epoch` and `policy_epoch` fencing, current grants, recorded
destinations, exact recovery and reserved control progress.

Compare distributed `Fuze` queries with independent single-node finite oracles
across partitions, worker churn and network faults. Report lease-handoff latency,
NVMe cache hit/warm rates and topology limits separately from correctness. Pod
recovery does not prove host power-loss durability or live disaster recovery.
Repeat qualified backup/restore and upgrade scenarios during lease transfer and
worker churn, preserving their original operation identities and authority fences.
Inject participant/coordinator movement before and after transaction decisions;
prove no partial visibility or lost accepted decision. Recovery alone cannot
authorize a new external attempt; preserve unresolved external outcomes.
Measure checkpoint discovery/loading, replay and cache warming separately;
recovery work is not universally proportional only to the number of WAL frames.
