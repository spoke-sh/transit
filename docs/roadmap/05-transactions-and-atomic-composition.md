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
not defer those decisions. Coordinate client contracts with the
[early programming foundation](06-client-foundation-and-language-apis.md).

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
   participant guards for the first local Table profile. SSI and finer-grained
   locking remain alternatives for later profiles; neither can weaken the
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
4. **Establish atomic publication and decision recovery.** Specify the
   linearization point, participant preparation/durability, visible commit cut,
   contiguous history and original outcome receipts. No participant's staged
   data becomes visible before the common decision. A single coordination-log
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
   one-KV-resource turns: direct writes inside a handler remain independent unless
   an explicitly extended owning contract qualifies composition. Define when a
   durable consumer's checkpoint and mutations share this domain; otherwise
   expose separately recoverable steps. Do not automatically rerun application
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
[indexing owner](08-indexing-and-access-paths.md) before dependent formats.
Every constraint advertised here must already be enforceable in the supported
domain. The later indexing delivery adds secondary structures and online builds;
it cannot defer transaction correctness. Index-backed reads and private writes
must preserve absent-key/range conflict tracking, uniqueness and savepoint/abort
behavior. Distinguish constraint enforcement readiness from query eligibility;
an asynchronously populated structure cannot authorize duplicate commits.
Choose isolation mechanisms on their own evidence, not because a tree offers
optimistic traversal. Include indexed/unindexed histories in later qualification.

[Historical catalogs](07-standards-and-catalogs.md) retain exact interpretation;
[dataflows](09-sql-and-dataflows.md) consume complete transaction changes without
publishing half a multi-object update. General `MERGE`/upsert and prepared-plan
features stay with SQL composition; this milestone owns their transaction
interactions. [Foreign relations](11-multi-model-and-foreign-relations.md) owns
typed `COPY`/import/export and its adapters. Foreign observations are not
automatically transactional participants, and exporting bytes cannot be undone
by local rollback.

[Branches](12-branches-merges-and-restore.md) own multi-commit histories, merge
validation and forward restore. [Investigations](20-published-resources-and-investigations.md)
own retained multi-call bases, including honestly independent source vectors.
Neither requires keeping an interactive transaction open for hours or days.

The first qualified deployment is an explicitly bounded atomic domain over the
local foundations. [Provider/concurrent-writer qualification](15-storage-providers-and-concurrency.md),
[replication](16-replication-and-failover.md), [operations](17-operations-and-recovery.md)
and [clustered execution](18-clustered-execution.md) extend and requalify decision
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
bounds and measured contention/latency in the [proof ledger](../../tests/README.md).
Component checks and this plan establish no new runtime guarantee.
