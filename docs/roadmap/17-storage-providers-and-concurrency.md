# 17. Storage providers and concurrent-writer qualification

[Roadmap](README.md) · [Storage tracker #109](https://github.com/spoke-sh/transit/issues/109) · **Status:** Planned

Extend the qualified local storage system to real distributed providers and
concurrent writers. An installation selects a provider, durability and writer
profile, then inspects accepted changes, conflicts and recovery under its
declared failure assumptions. Provider configuration alone establishes none of
those guarantees.

## Prerequisites and transferred scope

Consume [local storage](02-storage-and-query-performance.md), the
[installed runtime](03-live-storage-and-sql-cutover.md),
[transactions](05-transactions-and-atomic-composition.md) and the intervening
historical/branch caller profiles used by acceptance. Contract work for provider
trust, fencing and acknowledgement starts with the foundation gates; it does
not wait for every adapter or branch implementation.

This milestone explicitly receives the unfinished distributed-provider and
concurrent-writer delivery from milestones 2 and 3. Preserve
[#117](https://github.com/spoke-sh/transit/issues/117) (partition authority,
fencing and OCC), [#121](https://github.com/spoke-sh/transit/issues/121) (real
providers/cache), and the corresponding runtime and
[#124](https://github.com/spoke-sh/transit/issues/124) proof obligations. The
original [storage assessment](02-storage-and-query-performance.md#reopened-assessment--2026-10-22)
and delivered component evidence remain attributable. Local immutable creation,
cross-process conditional publication, bounded reads and restart safety remain
milestone 2 obligations; this split cannot excuse an unsafe local implementation.

## Delivery sequence

1. **Freeze enforceable provider and writer profiles.** Specify accepted commit
   points, durable-copy locations, process/host/disk loss, network partitions and
   log/object-store outages. A remote object store cannot recover acknowledged
   writes held only in a lost local WAL. Define scoped provider credentials,
   current authorization and ordering of revocation, append, publication and
   disclosure. A signed lease or cached epoch alone cannot fence a disconnected
   writer. Reuse #125/#111's commit authority; no independent manifest acceptance.
2. **Deliver real reference storage, envelope encryption at rest and bounded disk caching.**
   Implement and qualify `UrsulaWal` on disk-backed Ursula and real `S3ObjectStore`
   conditions, immutable writes and range reads. Keep credential handling inside
   the backend. Deliver authenticated **encryption at rest and envelope encryption
   (KMS / BYOK)** across `TransitLog` (`TWAL1`) segments, immutable `.tseg`/`.tdel`
   objects and local NVMe cache/spill files, binding Data Encryption Keys (DEKs)
   to realm, tenant or subject-group Key Encryption Keys (KEKs) so key rotation
   and cryptographic erasure (crypto-shredding in
   [Control & Policy Plane](21-control-and-policy-plane.md)) operate cleanly
   over immutable object storage. Replace in-memory signing loopbacks and
   heap-only caches with content-verified disposable NVMe range caching and
   bounded disk spill. Exercise interrupted transfers, missing/corrupt bytes,
   revoked/rotated KMS keys, cache loss and cold restart independently of
   authoritative state. Qualify Compose and Kubernetes/Substrate deployment
   wiring; automatic placement remains later scope.
3. **Qualify each additional planned provider.** Retain Kafka/Pulsar log adapters
   and GCS/R2/Azure object-store profiles as explicit delivery obligations. State
   producer/lease fencing, conditions, integrity, retention and acknowledgement
   per provider and supported combination. Publish a matrix of qualified,
   unsupported and pending combinations; an S3 API name establishes no general
   equivalence. Each promised profile needs real evidence or an explicit later
   scope revision, never silent removal.
4. **Integrate partitioned authority, concurrent publication and fine-grained distributed serializability.**
   Separate control/policy authority from independent data/process partitions,
   enforce epoch-fenced writer leases at actual storage publication, and integrate
   OCC with the selected transaction isolation contract. Extend the fine-grained
   key-range and predicate-level Serializable Snapshot Isolation (SSI / index-range
   conflict detection) from [Milestone 8](08-indexing-and-access-paths.md) across
   concurrent partition writers and multi-partition transactions so concurrent
   read-write transactions touching disjoint keys or ranges on shared Tables do
   not suffer whole-Table aborts. Reuse staged immutable segments for admissible
   disjoint writes while validating read/predicate, `FOREIGN KEY`/`CHECK`,
   schema, key and uniqueness conflicts as required. Measure rebase work; CAS
   alone proves neither serializability nor lock-freedom. Preserve local and
   native turn guarantees and expose unsupported cross-domain commits explicitly.
5. **Qualify installed callers and deployment recovery.** Run SQL, typed SDKs,
   historical reads, branches, native process/KV/Document owners and logical
   consumers through the same acceptance protocol. Integrate maintenance,
   compaction, retained pins and current-policy enforcement. Report selected
   provider/root, accepted/flushed positions, conflicts, lag and blockers through
   public inspection. Reproduce matched local/provider performance controls
   using #76/#124 without confusing a provider's replication with complete
   Transit failover.

## Formal model follow-through

Extend the [formalization milestone's T1/T7 candidates](16-formal-semantics-and-correspondence.md#later-ownership-and-extensions)
after selecting each provider's durability and fencing contract. Model actual
log/object publication and current-policy enforcement, delayed stale-writer
requests and recovery with missing objects. Establish the provider assumptions
required by reused local proofs and connect selected models to production
fault schedules. Record explicit scope decisions for deferred candidates;
finite model success does not qualify a provider's physical durability.

## Completion evidence and later owners

Qualify [index maintenance and coverage](08-indexing-and-access-paths.md) through
the same provider acceptance boundary: concurrent builds, same/different primary
keys colliding on a secondary unique key, stale build owners and partial index
object publication. Define uniqueness scope across partitions explicitly; local
indexes alone cannot enforce global uniqueness. Repeat the
[performance scorecard](10-data-structures-and-performance.md) with real provider
range-read latency, cold caches, write amplification, contention and rebuild
interference under matched durability/isolation settings.

Require independent concurrent processes and real disk/network faults, not
multiple handles to one in-memory helper. Exercise stale writers after revocation
or handoff, competing same/disjoint keys and predicates, lost replies, partial
object publication, policy changes, WAL/object outages and restart before flush.
Verify exact original receipts, transaction visibility, complete logical history,
branch/snapshot reachability and native input/state/output/effect evidence.
Retained datasets, manifests, caches and consumer history must exceed resident
budgets; report memory, I/O, amplification, rebase work and latency separately.

[Replication](18-replication-and-failover.md) follows this owner and qualifies
complete Transit history/object coverage and safe promotion.
[Operations](19-operations-and-recovery.md) qualifies backups and upgrades;
[clustered execution](20-clustered-execution.md) qualifies automatic placement
and distributed queries. None substitutes for provider correctness here.
Record exact provider revisions, topology, supported combinations and executed
faults in the [proof ledger](../history/qualification/README.md) and public storage/deployment
owners; this planning split establishes no new deployment support.
