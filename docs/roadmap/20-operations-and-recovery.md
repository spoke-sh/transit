# 20. Operations, backup, restore and upgrades

[Roadmap](README.md) · **Status:** Planned

Let an operator declare backup, recovery, capacity and maintenance policy, inspect
its progress, and recover or replace an installation without losing accepted
work or reviving obsolete authority. Deliver executable backup/restore and
upgrade procedures before automatic clustered placement depends on them.

## Prerequisites and scope

Follow [replication and durable failover](19-replication-and-failover.md) over the
[installed storage/runtime](03-live-storage-and-sql-cutover.md). Consume complete
catalog/native-owner recovery roots, retained history and current authority from
[data lifecycle](01-declarative-data-lifecycle.md) and
[storage](02-storage-and-query-performance.md). The first operational profile
uses local or explicitly managed replicated placements; it does not depend on
the later automatic scheduler. [Clustered execution](21-clustered-execution.md)
must subsequently prove these procedures across moving workers and partitions.

The [deployment reference](../handbook/reference/deployment.md),
[versioning policy](../handbook/reference/versioning.md),
[retention](../handbook/reference/retention.md),
[observability](../handbook/reference/observability.md) and
[runtime contract](../../contracts/RUNTIME_SUBSTRATE_V1.md) own the starting
boundaries. Existing restart, maintenance and compatible worker replacement
remain delivered behavior with their current limits. Replication is not a backup:
it may faithfully copy an unwanted accepted change.

Use the [transaction contract](05-transactions-and-atomic-composition.md) when
selecting backup and point-in-time recovery cuts. Include participant state,
durable decisions, receipts and outbox/capture evidence; a timestamp or a set of
partition heads alone cannot prove transaction completeness. Define treatment of
prepared/undecided work and retain the evidence needed to resolve original
attempts. Restoring data never authorizes replay dispatch or resurrects historical
outbox eligibility; activation and reconciliation remain separately governed.

## Delivery sequence

1. **Define operational policies and recoverable operations.** Assign shared
   owners and typed operations for backup, verification, restore preparation,
   activation, maintenance/drain and upgrade. Separate validation, acceptance,
   durable progress and completion; lost replies recover the same operation.
   Define current scoped administrative and read permissions, budgets, cancellation
   and restart behavior before CLI/SQL adapters. Keep Board inspection read-only.
   Select recovery point/time objectives per deployment and measure them rather
   than promising universal targets.
2. **Publish complete, independently verifiable backups.** Define an immutable
   backup manifest binding installation/realm identity, exact contract/build
   definitions, catalog/schema/branch roots, checkpoint cuts, required contiguous
   WAL tails and reachable objects. Include native progress, accepted-operation
   receipts, pending inputs/outputs, retirement, policy and effect evidence, plus
   the necessary configuration and secret/key recovery references. Specify the
   consistent atomic domain or explicit source vector; timestamps alone do not
   establish one cut. Include accepted unflushed writes. Publish completion only
   after verifying all required bytes, using bounded resumable full/incremental
   transfers and explicit destination access, integrity and encryption/key policy.
   Define continuous WAL archival and the verified recovery window for selecting
   a point-in-time cut. Qualify incremental cross-region backup copies with their
   own destination/provider evidence; their completion does not grant live
   failover authority or imply synchronous protection.
3. **Own backup retention and restore verification.** Pin source history during
   capture, track incremental-chain dependencies and validate recovery from the
   destination independently of the source. Backup expiry is explicit opt-in;
   storage pressure does not authorize it. Coordinate deletion with all remaining
   backup, branch and live-reader roots. Separate restore testing into an isolated
   inspection target from authorization to resume live work. Missing segments,
   trimmed tails, incompatible definitions or unavailable keys fail visibly.
4. **Restore through an explicit authority-recovery protocol.** Define the live
   source fence, recovery/trust generations and destination identity before
   activation. An old backup cannot supply current rights, undo retirement or
   authorize the old executor. Preserve post-backup authority safety evidence
   through the selected recovery mechanism; if that evidence or exclusion of the
   old authority cannot be established, refuse live activation. Reconcile pending
   operations and unknown external effects without replay dispatch or invented
   cancellation. Expose the selected cut, any missing interval, recovered work,
   unresolved outcomes and blocked activation. Data-loss choices require explicit
   operator policy; they cannot relabel lost accepted work as never accepted.
5. **Deliver upgrade and migration procedures under one current v1.** Inventory
   matching servers, clients, workers, SDKs, stored formats and generated
   contracts. Preflight compatibility, disk/headroom, recoverable backup and
   unresolved work; drain/fence the selected owners and record resumable progress.
   Qualify compatible replacement separately from incompatible cutover. An
   incompatible definition requires a coordinated stopped cutover and, where
   supported, a separately specified/proved offline converter. Otherwise refuse
   while preserving the original history and matching recovery build. Never add
   mixed incompatible rolling support, fallback decoders, implicit reset or
   re-signing of uncertain work. Define rollback points explicitly: replacing a
   binary cannot undo accepted changes or make old formats readable.
6. **Deliver capacity, maintenance and incident workflows.** Expose backup age
   and verified recovery cut, replica health, storage/retention pressure,
   maintenance/upgrade phase and attributable failures through bounded public
   inspection. Exercise drain/shutdown, repair, credential/key rotation and
   storage/provider outages while reserving control/recovery capacity. Record
   operator runbooks for local, Compose and the selected Kubernetes/Substrate
   profiles; automation uses the same authorized operations and never derives
   execution rights from provider state.

## Boundaries with other milestones

Backups bind [index definitions and generations](09-indexing-and-access-paths.md)
to the selected data cut. Record copied index objects or an explicit rebuild
requirement with complete authoritative inputs; a rebuildable index is not an
excuse to omit constraint definitions or required history. Verify query coverage
and constraint enforcement before restored work becomes eligible. Include index
format/comparator compatibility in upgrade preflight and current-v1 cutover.
Expose rebuild/repair progress and measure temporary capacity, recovery time and
foreground latency under the [performance scorecard](11-data-structures-and-performance.md).
Test interrupted backup, rebuild and upgrade while index publication or retirement
is in progress.

[Branches, merges and restore](15-branches-merges-and-restore.md) owns logical
application-data restore as a new forward successor under current realm policy.
This milestone owns backup media, installation disaster recovery, operational
activation and runtime upgrades. Both preserve the ban on revived grants,
retired processes and historical effects. [Release distribution](31-releases.md)
packages the qualified artifacts and procedures; it does not invent their
upgrade semantics. Broader distributed placement is qualified by its own owner.

## Formal model follow-through

Reassess the [T1/T4/T7 recovery candidates](17-formal-semantics-and-correspondence.md#later-ownership-and-extensions)
against the delivered backup/PITR and upgrade contracts. Extend selected coverage
and retention models to complete backup roots, transaction decisions and
current-authority restore activation; replay corresponding failure histories.
Record assumptions and deferrals explicitly. A logical branch restore proof does
not establish installation recovery or authorize historical effects.

## Completion evidence

Back up a changing installation with Table/KV/Document data, branch history,
accepted unflushed writes, pending work and recorded effects. Destroy an isolated
source fixture and restore using only the declared backup/recovery material.
Exercise full and incremental chains, an intermediate point-in-time cut and the
selected cross-region copy profile; report unavailable intervals explicitly.
Compare exact data, definitions and native outcomes with an independent oracle;
exercise a backup/PITR cut during multi-object commit, undecided participants,
lost commit replies, staged/committed/captured outbox work, incomplete copies,
corrupted/missing chain members, concurrent GC,
retention expiry, lost replies and interrupted restore/upgrade phases.

Prove that a backup predating revocation/retirement/effect completion cannot
activate obsolete rights, revive identities or repeat effects. Test surviving
old writers, stale controllers, unavailable recovery evidence, cancellation and
unknown external outcomes. Use installed compatible upgrades and incompatible
artifact rejection; any offered offline conversion needs its own accepted-work
and rollback proof. Verify bounded memory, resumable progress and control capacity
under disk pressure and slow destinations.

Record achieved recovery point/time, verification/transfer/replay durations,
retained bytes, tested topology and failure limits in the
[proof ledger](../history/qualification/README.md). A successful backup command, replica
failover or SIGKILL restart does not establish disaster recovery. Promote only
executed operational profiles and runnable procedures to their public owners.
