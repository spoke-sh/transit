# 5. Transactions, consistent snapshots and atomic composition

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · **Status:** In Progress

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

At the implementation-plan base `87a10e4f2` (fetched `origin/main` on
2026-10-28), the [SQL reference](../handbook/reference/sql.md) and
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

## Implementation plan — 2026-10-28

This plan is based on committed `origin/main` at `87a10e4f2`, including the
database-runtime cutover and storage resource follow-up. It does not incorporate
uncommitted work from another checkout. All transaction work packages below are
**tracked below**; existing component and installed evidence qualifies only its recorded
profile. Keep the milestone `Planned` until implementation starts, then update
this header and the roadmap index together.

### Work package status

| Package | Outcome | Status |
| --- | --- | --- |
| P0 | Neutral identities, fixed local scope, participant/decision commitments and fixtures | In progress: protocol types, validation, finite models and a production common-cut counterexample/control; remaining runtime correspondence stays open |
| P1 | Database admission, original-token binding, transaction quotas and caller boundary | In progress: original-token begin admission, coordination partition reservation, limits, signed caller fixture and component private-statement admission; aggregate account reservations; host integration and transaction settlement remain open |
| P2 | Paged common-cut acquisition, pin recovery and private workspaces | In progress: paged common-cut acquisition, original-pin recovery, catalog-owned private statement/root recovery and cumulative staging charges; aggregate account reservations; host/caller integration and deployment-wide scheduling remain open |
| P3 | Participant preparation, whole-Table OCC, common decision and atomic visibility | In progress: fenced decision journal with exact preparation membership; Table preparation and visibility integration remain open |
| P4 | Restart/failure settlement, retained roots, cleanup and maintenance | In progress: private statement/root recovery and retained-graph coverage; commit/abort recovery and cleanup remain open |
| P5 | Provisional statement results, SQL session controls and shared client | Planned |
| P6 | Typed Zig, console and PostgreSQL/MySQL adapters and inspection | Planned |
| P7 | Savepoints, cursor invalidation and resource/failure schedules | Planned |
| P8 | Table outbox/checkpoints and explicit participant extension handoff | Planned |
| P9 | Installed caller, anomaly, recovery and resource qualification | Planned |

The neutral types validate descriptor shape only. They establish no transaction
service, acquired consistent cut, serializable execution or durable decision.
The [Table transaction model](../../tests/verification/models/README.md#finite-local-table-transaction-model)
checks selected finite programs for common-cut acquisition, whole-Table OCC,
savepoint dependencies, private reads and atomic visibility. Its algorithm-level
evidence does not discharge production replay or installed qualification in P3/P4/P9.
The storage directory and decision-journal components have separate disk/recovery
checks and an explicit [integration contract](../../packages/zig/transit-storage/docs/transaction-decisions.md).
Their verification callbacks are not yet connected to Table owners. Catalog
begin admission now reserves a coordination partition through the original-token
owner and retains its selected directory pages. The catalog component acquires a
paged common cut under an embedding host's publication fence and retains its
source directory; its original-pin and policy-epoch checks do not yet establish
an installed transaction service. Its
[component qualification](../history/qualification/verification.md#catalog-owned-common-cuts-and-mutation-buffers--2026-10-28)
records the executed recovery, authorization, retention-graph and memory checks
and their limits. Catalog-owned private statement admission and outcome publication now preserve
original identities, private roots and their retained data across lost replies.
Host integration, durable savepoints, deployment-wide capacity, Table predecessor
barriers, common-decision visibility, decision retention and public callers remain
required before an installed transaction profile is claimed.

### Incoming handoffs and start gates

| Owner and status at this base | Available input | Required action and gate for this milestone |
| --- | --- | --- |
| [M1](01-declarative-data-lifecycle.md), Completed | Stable identities, exact definitions, frozen operations, WAL-inclusive cuts and the selected local transaction algorithm | Carry the selected profile into executable contracts and neutral fixtures in P0. Descriptor validation is not consistent-cut acquisition or a transaction proof. |
| [M2](02-storage-and-query-performance.md), Completed | Local WAL/object durability, paged Table history, immutable data and retained roots | Extend the actual acceptance, recovery and retained-graph owners in P2–P4; do not infer that existing single-Table durability already covers a common decision. |
| [M3](03-live-storage-and-sql-cutover.md#implementation-plan--2026-10-27), In Progress | Installed direct Tables, lazy schema projection, WAL reads, automatic maintenance, database-owned SQL and single-executable packaging | Implementation can start from these merged owners. Preserve P1 native-resource/caller boundaries and P4 maintenance/retention checks. Coordinate P5 read/wait costs and P6 inspection; require affected installed recovery and resource gates at M5 P9. M3 P4–P6 and P8 remain independently open. |
| [M4](04-statement-results-and-consumption.md#delivered-integration-boundary), Completed | `transit-sql-results`, `Executor`, bounded `ResultSet`, typed counts and immutable observation evidence | Extend the shared model with provisional transaction attribution and decision evidence in P0/P5. Keep completion, delivery and closure separate. Do not rebuild submission/fetch/recovery in each adapter. |
| [M6 Step 1](06-streams-queues-and-durable-runtime.md#sql-database-runtime-cutover--2026-10-28), In Progress | `DirectClientToken`, `DatabaseRuntime`, activation fencing, `ReadCache`, `commit_saved`, and build checks excluding Station from database packages | The architectural prerequisite is delivered. Preserve the one-data-append fast path and measure complete control-path cost; its remaining performance/installation gates are not prerequisites for drafting P0, nor are they automatically passed by this plan. |
| [M11 / #194](11-data-structures-and-performance.md#implementation-plan-for-issue-194), In Progress | Admitted result/client/service reserves and `transit-memory` / `transit-io` owners | Budget transaction work separately from result and recovery capacity; coordinate source/storage allocation work with F–J. Rebase its older `AccountRuntime` references onto `DatabaseRuntime`; they are not an instruction to restore actors. |
| [M16](16-service-and-sdk-coverage.md), In Progress; [M7](07-client-foundation-and-language-apis.md), Planned | Existing console, wire adapters and SDKs; agreed future shared-client direction | M5 delivers typed Zig and native SQL transaction callers plus the existing PostgreSQL/MySQL mappings. Review language ownership now; broad new language/Flight transaction coverage remains with M7/M16. |
| [M17 T4](17-formal-semantics-and-correspondence.md#t4-transaction-decisions-isolation-and-atomic-outbox-publication), In Progress | Model/checker infrastructure and an explicit transaction candidate | Select the local OCC/decision model and production correspondence during P0, replay its counterexamples in P3/P4, and retain its bounded assumptions. Later SSI and distributed proofs do not substitute for the local gate. |

The storage follow-up at this base deliberately **does not adopt** the reusable
128 MiB private maintenance reserve: installed RSS increased without a clear
latency/CPU benefit. Consume the retained slab initialization and request-lifetime
fixes, and the [measured tradeoff](03-live-storage-and-sql-cutover.md#p4--schedule-archival-checkpoints-compaction-and-collection).
Do not copy a large reserve into every transaction to satisfy an allocation
counter. Count admitted capacity, resident pages, OS memory, foreground latency
and background work together.

### Selected delivery profile and exclusions

The [foundation decision](01-declarative-data-lifecycle.md#selected-transaction-session-extension)
is the starting algorithm, not an open-ended mechanism search:

- One catalog, its existing branch-one profile, and one fenced local database
  authority; multiple Tables may participate. No new branch lifecycle or remote
  coordinator is required. Data and schema identities remain distinct from
  names, SQL sessions, account activations and storage epochs.
- Serializable read/write transactions use a retained common cut and conservative
  whole-Table logical-version validation. Validate every read and written Table,
  including absent-key/predicate/constraint reads. Physical flush, compaction,
  pin bookkeeping and recovery must not create false logical conflicts. There
  is no snapshot-isolation fallback. Do not advertise strict serializability or
  real-time ordering without separately proving it.
- Read-only transactions use the same common-cut acquisition and pin ownership;
  they need no write preparation and may finish on their retained cut despite
  later data commits. Current grants still govern every disclosure.
- Typed begin can select an explicit Table set; ordinary interactive SQL begin
  selects the authorized catalog Table set under one stable name/definition
  basis. A later statement cannot silently extend that cut. Reject an omitted,
  newly created or newly accessible object before executing the statement.
  Record the exact scope so a filtered catalog cut is never described as covering
  inaccessible Tables. Catalog-wide acquisition must page even when the directory
  exceeds every resident cache.
- DML, supported finite Table reads, existing primary-key/NOT NULL constraints,
  savepoints, typed Table outbox records and same-domain Table consumer checkpoints
  form the first executable scope. DDL, GRANT/configuration changes, captured
  jobs, native KV/Document sources, native input acknowledgments and arbitrary
  external calls cannot join it. No statement implicitly commits to accommodate
  an excluded operation. Metadata results retain their proper catalog/settings
  evidence rather than inventing data rows or data-snapshot authority.
- Native KV/Document participation and the Stream/Queue/Station composition
  remain explicit extension obligations. P0 fixes the three participant
  categories; P8 provides the common interface and handoff to M6. An extension
  does not execute merely because its variant is present in a fixture.

The local Table delivery gate is useful before M6 is complete. It is not proof
of the broader multi-model or Station outcomes in [Experience and ownership](#experience-and-ownership).
Track those outcomes individually at P8/P9; do not close them through a blanket
“transactions implemented” status or make M6 wait for its own completed migration
before it can consume the qualified Table coordinator.

### Implementation owners and contract changes

Names in this table identify existing owners; proposed transaction modules and
operations acquire exact names and manifests in P0. Reuse the dependency direction
and package interfaces, without imports from sibling source directories.

| Boundary | Existing implementation to extend | Contract and review responsibility |
| --- | --- | --- |
| Neutral identities, source basis and receipts | `transit-protocol` data lifecycle types | [Data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md): transaction/begin/statement/attempt identities, consistency scope, participant directory commitment, decision evidence and incompatible-definition rejection |
| Catalog admission, names, authorization and recovery directory | [Direct catalog](../../packages/zig/transit-catalog/docs/direct-catalog.md), `DirectClientToken`, `DirectCatalogStore`, `DirectStorageGraph` | [Direct requests](../../contracts/DIRECT_TABLE_V1.md) and [catalog](../../contracts/CATALOG_V1.md): original token binding, paged transaction/pin/cleanup indexes, fenced decision ownership and complete retained roots |
| Durable participant state and commit visibility | [Storage](../../packages/zig/transit-storage/README.md), `TablePartition`, `TransitLog`, object and recovery owners | [Storage](../../contracts/TRANSIT_STORAGE_V1.md): private preparation, predecessor barriers, immutable objects, one common decision, logical history, replay and checkpoint/trim rules |
| Private evaluation and read-your-writes | [Direct query](../../packages/zig/transit-query-direct/README.md), Fuze and Table mutation builders | Existing query/DML types plus a bounded transaction overlay; no raw provider credentials in query execution and no duplicate evaluator |
| Database scheduling and session attachment | [DatabaseRuntime](../../packages/zig/transit-sql/docs/runtime.md), `Statement`, `ReadCache`, `transit-sql-service.Session` | Durable recovery lives below temporary sessions. Transaction control uses public database operations; session handles/leases are not commit authority. |
| Logical outcomes and caller ownership | [Results](../../packages/zig/transit-sql-results/README.md), [shared client](../../packages/zig/transit-sql-client/README.md), typed direct client | [SQL results](../../contracts/SQL_RESULTS_V1.md) and [SQL sessions](../../contracts/SQL_SESSION_V1.md): provisional evidence, exact decision settlement, cursor closure and bounded ownership |
| Grammar and adapters | SQL parser/compiler, console, `transit-postgres`, `transit-mysql`, public Zig SDK | [Grammar](../../contracts/sql/README.md), [gateway contract](../../contracts/SQL_GATEWAY_V1.md), [caller boundary](../handbook/reference/callers.md): shared control semantics, accurate capability/error mappings and generated resources |
| Local hosting, maintenance and inspection | `apps/transit-node`, local backend, SQL gateway, existing public read surfaces | [Storage](../handbook/reference/storage.md), [retention](../handbook/reference/retention.md), [security](../handbook/reference/security.md): prepare/decision retention, bounded recovery, current-policy checks and read-only inspection |

Catalog acceptance LSN, each participant's prepare/data LSN, the common decision
position and SQL statement completion are different evidence. Preserve them as
typed, scoped fields; never compare positions from different logs as one scalar
clock. Reuse the current Catalog token directory rather than creating a second
session deduplication authority. Common-decision records may use a dedicated
database coordination partition, selected in P0; unrelated single-partition
autocommit must not acquire a new global durable root dependency.

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
