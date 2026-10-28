# 5. Transactions, consistent snapshots and atomic composition

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · **Status:** Planned

Let an application read a consistent basis, compose changes to supported data
objects, and inspect one durable commit or abort decision through SQL and typed
clients. Cover ordinary applications, Station composition and retained reads
with explicit atomic boundaries. A completed statement, a committed transaction,
delivered results and completed external work are different observations.

## Prerequisites and current scope

Follow [statement results](04-statement-results-and-consumption.md), the
[local runtime cutover](03-live-storage-and-sql-cutover.md) and
[storage foundation](02-storage-and-query-performance.md). Resolve atomic-domain,
isolation and snapshot contracts with [data lifecycle](01-declarative-data-lifecycle.md)
and #125/#111 before dependent persistent formats; the delivery position does
not defer those decisions. Pull forward **Step 1 of
[declarative streams, queues and durable runtime](06-streams-queues-and-durable-runtime.md)**
(`transit-sql` $\perp$ `Station` decoupling) before implementing this milestone's
transaction coordinator so `BEGIN`/`COMMIT`/`ROLLBACK` and autocommit SQL statements
build directly on `DirectCatalog`, `TablePartition` and `TransitLog` (`TWAL1`)
rather than layering over `Station` [`AccountRuntime.zig`](https://github.com/spoke-sh/transit/blob/fbbaeae12/packages/zig/transit-sql/src/AccountRuntime.zig)
or [`Ledger.zig`](https://github.com/spoke-sh/transit/blob/fbbaeae12/packages/zig/transit-sql/src/Ledger.zig). Coordinate
stream/queue outbox, consumer-checkpoint and durable-runtime turn composition
with [Milestone 6](06-streams-queues-and-durable-runtime.md) and client contracts
with the [early programming foundation](07-client-foundation-and-language-apis.md).

At source `7f9343cc`, the [SQL reference](../handbook/reference/sql.md) and
[session contract](../../contracts/SQL_SESSION_V1.md) do not offer interactive
`BEGIN`/`COMMIT`/`ROLLBACK` sessions. The
[native state contract](../../contracts/STATE_V1.md#read-bases-and-atomic-turns)
commits input progress, mutations to at most one KV resource and outputs together;
selected read views can be revision-guarded. Independent source snapshots do not
establish a catalog-wide atomic cut. Existing accepted-operation recovery remains
the foundation; this plan claims no new executable transaction syntax or API.

The reviewed transaction discussion informs this plan, with these corrections:
branches contain committed history rather than being open transactions;
investigations can retain a basis independently of a transaction session;
uncertainty describes knowledge of a decision, not an additional atomicity tier.
MVCC, OCC, catalog roots and immutable segments are candidate mechanisms, not
proof of serializability or universal nonblocking execution. The local transcript
has SHA-256 `b0f5d210a851e260d39fa7b114e7920a82060c9f96f3653662c52d2752f18b74`;
the plan is self-contained and does not require that file.

## Database runtime handoff — 2026-10-28

The SQL database dependency on Station has been removed by the
[database runtime cutover](06-streams-queues-and-durable-runtime.md#sql-database-runtime-cutover--2026-10-28).
The transaction agent can begin the selected local Table profile against these
owners without introducing an account actor:

1. Extend the typed database contract first. `DirectClientToken` owns original
   client identity and a paged operation directory; its acceptance LSN is a
   Catalog receipt, **not** the Table commit LSN. Preserve both when defining
   transaction/statement identities and uncertain commit settlement.
2. Build participant preparation, common-decision visibility and original commit
   recovery in `DirectCatalog`, `TablePartition` and `TransitLog`. The existing
   `TablePartition.commit` / `commit_saved` path provides single-partition
   autocommit with one data WAL append. Catalog acceptance/settlement remain
   separate today; joining their semantics is explicit transaction work.
3. Preserve current authorization and Catalog activation fencing. A gateway's
   activation revision protects its database requests through the Catalog access
   lock. Transaction participant leases and policy ordering must be enforced by
   their owning database operations, not only by session-side checks.
4. Replace independent read vectors with the selected common transaction cut.
   `ReadCache` owns 64 persistent cache slots per route and bounded resident
   borrows; a warm read reuses an exact Table cut. Those pins do not establish
   atomic multi-Table visibility. Define transaction retention and pin lifetime
   separately and preserve lost-acquisition recovery/current disclosure checks.
5. Keep session/result composition in `transit-sql-service`, finite SQL execution
   and recovery in `transit-sql`, and direct query execution in
   `transit-query-direct`. Their public statement-result protocol remains the
   consumer boundary. No interactive transaction syntax is implemented by this
   decoupling change.

Reserve the transaction envelope's state-mutation, log-append and guarded
consumer-settlement participant categories now. First-class Stream/Queue storage
and Station's transactional turn migration are still Milestone 6 work; do not
pretend the existing actor turn or external captured-query lane is a transaction
participant. Existing accepted Station work keeps its current recovery owner.

Start verification with the Catalog quota/fence tests, the disk-backed
single-partition autocommit test, native SQL lost-reply proof and installed
SQL/source recovery schedules in the [qualification record](../history/qualification/sql.md#database-owned-sql-runtime--2026-10-28).
Retain the current-v1 hard-cutover and generated-contract checks for every
incompatible transaction format change. The remaining end-to-end control-path
costs are measured separately from the single data commit; do not repeat old
actor-turn latency as a measurement of this implementation.

## Experience and ownership

| Experience | Required outcome and boundary |
| --- | --- |
| Single statement or typed batch | One accepted operation and atomic publication within its declared domain; autocommit is the same commit model with an implicit transaction lifetime |
| Interactive SQL or programmatic transaction | Multiple statements and supported Table/KV/Document mutations share a consistent basis, read their own writes and commit or abort together within one qualified domain |
| Read-only transaction | Data and interpretation bind to one supported consistent cut, including committed unflushed WAL state, with bounded work and explicit pin lifetime |
| Station turn and durable consumer | Preserve the native turn boundary; declare whether data, input/checkpoint progress and staged outputs can participate in one supported commit or are separately recoverable operations |
| Transactional outbox | Data changes and durable message/connector intents publish atomically; delivery, execution and external outcomes complete separately |
| Branches, reviewed publication and investigations | Reuse snapshot/conditional-publication primitives with their own history, retention, policy and lifetime contracts |
| Replicated or distributed deployment | Preserve the same decision, isolation and visibility semantics under the later qualified failure and placement profiles |

## Delivery sequence

The [selected foundation profile](01-declarative-data-lifecycle.md#selected-transaction-session-extension)
fixes the initial local Table domain, consistent-cut acquisition, conservative
whole-object optimistic validation, participant preparation/common-decision
visibility, provisional statements, savepoints and Table outbox boundary. Its
native KV/Document and cross-owner exclusions do not remove the broader
composition outcomes above. Add those owners only through explicit participant
contracts and their failure histories. The selected profile is planned, not
executable syntax or implemented transaction support.

1. **Select the atomic domain and isolation contract.** Define database/catalog,
   branch, object, partition and writer identities and their relationships.
   Specify the first supported multi-object Table/KV/Document combination and
   its coordinator/participant placement. Reject unsupported combinations before
   accepting work; sharing a realm, connection or name does not join commits.
   Target serializable read/write transactions and consistent read-only snapshots
   within that domain. Resolve the implementation and cost before freezing the
   contract; do not silently substitute snapshot isolation. Any weaker isolation
   requires explicit anomaly rules and caller selection. Specify whether real-time
   ordering is provided separately from serializability. Validate read/write and
   predicate dependencies, absent keys, uniqueness, keyless row identities,
   collation-sensitive ranges, Document causal rules and schema changes.
   The foundation selects whole-object optimistic validation under ordered
   participant guards for the first local Table profile. Because whole-Table
   read conflict detection aborts concurrent read-write transactions touching
   disjoint keys on the same Table, [indexing and access paths](09-indexing-and-access-paths.md)
   and [concurrent-writer qualification](18-storage-providers-and-concurrency.md)
   explicitly own the progression to fine-grained key-range and predicate-level
   Serializable Snapshot Isolation (SSI / index-range conflict tracking) over the
   same transaction session and recovery contract; neither can weaken the
   declared anomaly rules without explicit caller selection and qualification.
2. **Define transaction identity, session state and statement outcomes.** Specify
   begin, execute, inspect, commit, rollback and savepoint operations before their
   SQL/SDK adapters. Bind a transaction and commit attempt to exact objects,
   definitions, original request identity and frozen content. Separate temporary
   connection/session attachment from durable decision and recovery ownership.
   Define duplicate statements, sequencing, autocommit controls, nested-scope
   rejection or savepoint behavior, deadlines, session loss and prepared-plan
   invalidation. A statement's rows or matched/changed counts describe its work
   within the transaction; terminal statement evidence cannot imply durable commit.
   Specify result/cursor behavior at savepoint rollback, commit and abort, including
   already disclosed provisional results. DDL and constraints need an explicit
   transactional profile or explicit rejection; do not add implicit commits.
3. **Implement bounded private workspaces and consistent reads.** Pin exact
   catalog/definition and data cuts, including committed WAL tails, and overlay
   private changes for read-your-writes. Bound resident memory, active work,
   workspace bytes, conflict metadata and retained pins through explicit quotas
   and transaction policy. Spill where qualified without exposing uncommitted
   objects. Savepoints restore data and staged intents while preserving the
   read/conflict dependencies needed for the isolation guarantee. Specify which
   resources are released immediately or reclaimed later; neither savepoints nor
   rollback promise zero I/O. Define lease expiry, cleanup after caller loss,
   orphan collection and backpressure without deleting accepted history. Recheck
   current access on reads, buffered disclosure and commit; an old snapshot never
   preserves old privileges.
4. **Establish atomic publication, participant primitives and decision recovery.**
   Specify the linearization point, participant preparation/durability, visible
   commit cut, contiguous history and original outcome receipts. Structure the
   transaction commit envelope around **three native participant primitives** from
   the outset:
   1. **State mutations and conflict guards** (`TABLE`, `KV` and `DOCUMENT` writes
      plus read/predicate/version guards),
   2. **Log appends** (`STREAM` `PRODUCE INTO` and `QUEUE` `ENQUEUE INTO` records,
      including `visible_at` and `dedup_key`), and
   3. **Consumer and lease settlements** (`QUEUE` `ACK` guarded by `_lease_epoch`
      and `STREAM` `COMMIT OFFSET`).
   No participant's staged data, appended records or lease settlements become
   visible before the common decision. A single coordination-log
   record is insufficient without participant/object availability and recovery
   rules; avoid a global realm CAS for every unrelated write. Recover interrupted
   decisions, fence former coordinators/writers and preserve policy ordering.
   Commit timeout, lost reply or local cancellation cannot establish abort.
   Return unresolved outcomes with original recovery material and bounded
   settlement; resolve the original attempt without replaying SQL as fresh work.
   A confirmed pre-commit abort prevents publication but may leave bounded
   deferred cleanup. Define commit/abort races explicitly. Retention of decisions
   and recovery material must match the promised recovery lifetime.
5. **Compose messages, effects and consumer progress through explicit scopes.**
   Stage authorized Station messages and connector intents with transaction data
   where the selected domain supports that outbox. Durable commit makes them
   eligible for delivery even if the caller never receives its commit reply.
   Dispatch requires the effect owner's current authorization and policy;
   commit does not establish remote success or exactly-once execution. Use
   [connector](../handbook/reference/connectors.md) intent/attempt/capture and
   uncertainty rules, secret references and network-free replay. Branches and
   restored history must not silently activate old intents. Preserve native
   one-KV-resource turns until cutover: direct writes inside a handler remain
   independent unless an explicitly extended owning contract qualifies composition.
   Define when a durable consumer's checkpoint and mutations share this domain;
   otherwise expose separately recoverable steps. Because Step 4's commit envelope
   natively unifies state mutations/guards, `STREAM`/`QUEUE` log appends and
   `_lease_epoch`-guarded `QUEUE` `ACK` / `STREAM` `COMMIT OFFSET` settlements,
   **a `Station` actor or workflow turn in [Milestone 6](06-streams-queues-and-durable-runtime.md)
   requires zero bespoke turn-commit protocol**: it executes as a standard
   transaction combining `(3) ACK inbox queue lease under _lease_epoch` +
   `(1) mutate Table/KV/Document state` + `(2) PRODUCE/ENQUEUE outbound messages
   and connector effect intents`. Do not automatically rerun application
   callbacks containing arbitrary I/O after a conflict or uncertain commit.
6. **Deliver shared callers and the current-v1 cutover.** Put execution and
   decision recovery in the owning service and reusable submission/settlement in
   shared clients. Migrate native messages, PostgreSQL/MySQL transaction adapters,
   existing SQL/SDK consumers, schemas and fixtures together where affected.
   Preserve foreign/missing-definition rejection and original accepted work.
   Review ordinary and advanced recovery examples across SQL and idiomatic
   language APIs without freezing speculative method names. Publish qualified
   semantics and limits in the SQL, query, state, caller and connector owners;
   record the mechanism in existing Internals topics when implemented.

## Later owners and execution gates

Define index-maintenance, constraint and DDL interactions with the
[historical catalog](08-standards-and-catalogs.md) and
[indexing owner](09-indexing-and-access-paths.md) before dependent formats.
Every constraint advertised here must already be enforceable in the supported
domain, expanding from primary-key and `NOT NULL` checks to declarative row-level
`CHECK` constraints and cross-table `FOREIGN KEY` referential integrity as those
catalog and index slices land. The later indexing delivery adds secondary
structures, online builds, index-backed `FOREIGN KEY` validation and fine-grained
key-range/predicate conflict tracking (moving concurrent read-write transactions
from conservative whole-Table read conflicts to key/range serializability);
it cannot defer transaction correctness. Index-backed reads and private writes
must preserve absent-key/range conflict tracking, referential integrity, uniqueness
and savepoint/abort behavior. Distinguish constraint enforcement readiness from
query eligibility; an asynchronously populated structure cannot authorize duplicate
or referentially invalid commits. Choose isolation mechanisms on their own evidence,
not because a tree offers optimistic traversal. Include indexed/unindexed and
parent/child foreign-key histories in later qualification.

[Historical catalogs](08-standards-and-catalogs.md) retain exact interpretation;
[dataflows](10-sql-and-dataflows.md) consume complete transaction changes without
publishing half a multi-object update. General `MERGE`/upsert and prepared-plan
features stay with SQL composition; this milestone owns their transaction
interactions. [Foreign relations](14-multi-model-and-foreign-relations.md) owns
typed `COPY`/import/export and its adapters. Foreign observations are not
automatically transactional participants, and exporting bytes cannot be undone
by local rollback.

[Branches](15-branches-merges-and-restore.md) own multi-commit histories, merge
validation and forward restore. [Investigations](23-published-resources-and-investigations.md)
own retained multi-call bases, including honestly independent source vectors.
Neither requires keeping an interactive transaction open for hours or days.

The first qualified deployment is an explicitly bounded atomic domain over the
local foundations. [Provider/concurrent-writer qualification](18-storage-providers-and-concurrency.md),
[replication](19-replication-and-failover.md), [operations](20-operations-and-recovery.md)
and [clustered execution](21-clustered-execution.md) extend and requalify decision
durability, fencing and placement. Design all experiences together without
claiming arbitrary distributed atomicity before those profiles execute.

## Completion evidence

Use independent histories and business-invariant oracles through actual SQL and
typed callers. Require the following for every advertised domain/isolation profile:

- Atomic multi-object updates, read-your-writes, consistent data/schema cuts and
  read-only snapshots spanning WAL-only commits, flush, compaction and restart.
- Write skew, phantoms, absent-key races, uniqueness/keyless identity, concurrent
  DDL, Document conflicts and collation-sensitive predicate schedules. Check
  forbidden histories, not just eventual matching row counts.
- Savepoint rollback after spill, staged-intent rollback, cursor lifecycle,
  oversized work, slow readers, expiry, cleanup and bounded conflict tracking.
- Failure during participant preparation, before/after the durable decision and
  during publication; lost commit replies, duplicate exact recovery, conflicting
  identity reuse and cancellation racing with commit. No partial visibility or
  manufactured abort after acceptance.
- Revocation before commit and after buffered reads, stale coordinators/writers,
  inaccessible recovery evidence and explicit unresolved outcomes.
- Outbox recovery when commit succeeded but its reply was lost; no dispatch from
  aborted work, no dispatch during replay, and preserved unknown external outcomes.
  Prove the selected checkpoint/data composition and reject unsupported scopes.

Record scope, mechanism, disk/failure assumptions, executed histories, resident
bounds and measured contention/latency in the [proof ledger](../history/qualification/README.md).
Component checks and this plan establish no new runtime guarantee.
