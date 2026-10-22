# 7. Clustered execution

[Roadmap](README.md)

Extend typed exchanges and manual single-authority handoff into automatic placement
and distributed execution. The [deployment reference](../reference/deployment.md)
and [runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md) own present behavior.

## Delivery sequence

1. Select a topology and define authority, routing, placement and provider-conformance
   contracts. Close growing controller gaps before automatic scheduling;
   distributed authority is a separate boundary.
2. Transfer ownership and recover providers through durable history. Qualify
   process/grant/mailbox safety before moving effects; physical readiness never
   grants execution authority.
3. Qualify query repartitioning independently of reassignment. Preserve source
   vectors, batch ownership and checked arithmetic; partial aggregation must not
   silently reassociate errors.
4. Exercise publication, collection, reconciliation, Document windows, serving,
   watches and query tickets across movement and partitions.
5. Define backup/restore/migration, partial Board observations and operational
   recovery. Extend provider portability through shared interfaces.

## Completion evidence

Run one-authority controls and inject faults at prepare, admission, staging,
publication, pin release, disclosure, retirement and collection. Require fencing,
current grants, recorded destinations, exact recovery and reserved control progress.

Compare queries with independent finite oracles across partitions/workers/faults.
Report topology limits and latency separately from correctness. Pod recovery does
not prove host power-loss durability or live disaster recovery.
