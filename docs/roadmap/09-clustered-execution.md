# 9. Clustered execution and storage-disaggregated placement

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
**zero durable data copying**. Expose deployment availability separately from
declaration progress and freshness; rescheduling a healthy pod does not
establish that a derived result is current.

## Delivery sequence

1. **Select topologies and define partitioned authority, routing, placement and provider-conformance contracts:**
   close controller gaps before automatic scheduling. Bind placement decisions
   to **Control/Policy Log** epoch leases `(partition_id, writer_epoch, policy_epoch)`
   so old pods are immediately fenced at both `TransitLog` and `TransitObjectStore`
   when a partition lease moves.
2. **Transfer partition leases and recover workers in $O(\text{WAL tail})$ time:**
   when a Station group or Table writer moves to a new node, the new node acquires
   the incremented `writer_epoch` lease, loads the latest committed `manifest/v{N}`
   from `TransitObjectStore`, replays only the uncompacted `TransitLog` tail into
   its Tier 0 Memtable, and warms its Tier 2 NVMe cache on demand via content-verified
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
5. **Define backup/restore/migration, partial Board observations and operational recovery:**
   leverage immutable `.tseg` segments and manifests for incremental cross-region
   object-store replication and point-in-time recovery.

## Completion evidence

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
