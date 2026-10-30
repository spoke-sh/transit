# 6. Declarative streams, queues and durable runtime architecture

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · [Feeds #127](https://github.com/spoke-sh/transit/issues/127) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Decouple the database (`DirectCatalog`, `TablePartition`, `KV`, `Document`,
`transit-query` and `transit-sql`) completely from the `Station` durable actor
runtime, elevate **Streams** (`STREAM`) and **Queues** (`QUEUE`) to first-class
declarative database primitives with dedicated SQL and typed-caller grammar over
`TransitLog` (`TWAL1`) and `.tseg` segments, and re-architect `Station` on top
of those database primitives and [supported transactions](05-transactions-and-atomic-composition.md).

## Prerequisites and architectural rationale

Follow the [declarative data lifecycle](01-declarative-data-lifecycle.md),
[local storage hierarchy](02-storage-and-query-performance.md),
[live storage/SQL cutover](03-live-storage-and-sql-cutover.md),
[statement results](04-statement-results-and-consumption.md) and
[transactions](05-transactions-and-atomic-composition.md). Start from the
[data model](../handbook/reference/data-model.md),
[streams reference](../handbook/reference/streams.md),
[state contract](../../contracts/STATE_V1.md),
[Station reference](../handbook/reference/station.md),
[storage runtime](../handbook/internals/storage-runtime.md) and
[execution model](../handbook/internals/execution-model.md).

Measured diagnostics in [Milestone 3 P5](03-live-storage-and-sql-cutover.md#implementation-plan--2026-10-27)
establish two structural bottlenecks in the pre-cutover architecture:

1. **Durable runtime concerns leaked into the database:** `transit-sql` routed
   ordinary SQL DML admission, idempotency token binding and outcome recovery
   through an account operation ledger ([`AccountRuntime.zig`](https://github.com/spoke-sh/transit/blob/fbbaeae12/packages/zig/transit-sql/src/AccountRuntime.zig),
   [`Ledger.zig`](https://github.com/spoke-sh/transit/blob/fbbaeae12/packages/zig/transit-sql/src/Ledger.zig) and
   [`Coordinator.zig`](https://github.com/spoke-sh/transit/blob/fbbaeae12/packages/zig/transit-sql/src/Coordinator.zig))
   implemented as a `Station` `GenServer` actor over a native KV state resource.
   Because [`STATE_V1`](../../contracts/STATE_V1.md) restricts each turn to four
   256-byte hex-encoded KV mutations, one instrumented 1-row `INSERT` observed 16
   native actor turns and 1,307 total fixture requests, including background
   work. That request count is not an isolated statement cost or a universal
   lower bound. The accepted data ultimately belongs to
   [`TablePartition`](../../packages/zig/transit-storage/src/TablePartition.zig),
   while `SELECT` persisted durable [`ReadPins`](https://github.com/spoke-sh/transit/blob/fbbaeae12/packages/zig/transit-sql/src/ReadPins.zig)
   and re-ran Table/catalog recovery on every request. In a distributed
   deployment where network hops carry millisecond latency, multi-turn actor
   mediation on the database path is untenable.
2. **The durable runtime (`Station`) was built without first-class `STREAM` and `QUEUE` database primitives:**
   Because the [data model](../handbook/reference/data-model.md) previously
   declared only `TABLE`, `KV` and `DOCUMENT` objects, `Station` actors had to
   rely on low-level PID sequence journals and copy-on-write `TPG1` B-tree pages
   inside [`growing.zig`](../../packages/zig/transit-core/src/growing.zig) (capped
   at 1–32 byte keys, 0–256 byte values, 4 mutations per turn and 8 records per
   page) plus external polling loops (`courier` in
   [`transit-query-host`](../../apps/transit-query-host/main.zig)) to move
   messages between outboxes and mailboxes.

This milestone resolves both problems in order: first, sever every dependency of
the database and SQL gateway on `Station`; second, introduce first-class
declarative `STREAM` and `QUEUE` catalog primitives with dedicated grammar and a
literature-backed `TransitLog`/`.tseg` storage and execution engine; third,
rebuild `Station` actors, workflows, supervision and connector effect queues as
consumers and producers over declared `QUEUE`s, `STREAM`s, `TABLE`/`KV`/`DOCUMENT`
state and [Milestone 5 atomic transactions](05-transactions-and-atomic-composition.md).

## Experience and workload boundaries

| Primitive / Plane | Primary workload | Declarative SQL & caller verbs | Storage & execution authority |
| --- | --- | --- | --- |
| `TABLE` / `KV` / `DOCUMENT` (Direct Data Plane) | Mutable versioned state, relational queries, point lookups and causal documents | `CREATE TABLE`, `INSERT INTO`, `UPDATE`, `DELETE FROM`, `SELECT ... FROM` | `DirectCatalog`, `TablePartition`, `TransitLog` (`TWAL1`), `.tseg` segments and `.tdel` vectors with zero `Station` involvement |
| `STREAM` (Direct Data Plane) | High-throughput append-only ordered event logs, pub/sub fan-out, CDC and replayable histories | `CREATE STREAM`, `PRODUCE INTO`, `CONSUME ... FROM`, `COMMIT OFFSET` (plus read-only `STREAM_SLICE(...)` for relational `SELECT` joins) | `StreamPartition`: partitioned `TransitLog` (`TWAL1`) tail + immutable `.tseg` segments in `TransitObjectStore` + consumer-group watermark log |
| `QUEUE` (Direct Data Plane) | Point-to-point competing consumers, delayed tasks, retries/DLQ and key-ordered (`key_fifo`) work leasing | `CREATE QUEUE`, `ENQUEUE INTO`, `CLAIM ... FROM ... WITH LEASE`, `ACK`, `NACK`, `EXTEND LEASE` | `QueuePartition`: `StreamPartition` payloads + `.tack` Roaring-bitmap ack vectors + fenced in-memory `_lease_epoch` heap + `key_fifo` affinity table + hierarchical timer wheel |
| `Station` (Process & Effect Plane) | Stateful virtual actors, durable workflows, supervision trees and governed external connector effects | Behavior handlers, typed `client.service` RPC and transactional turns | Layered over declared `QUEUE` (inbox with `key_fifo` lease), `TABLE`/`KV`/`DOCUMENT` (state), `STREAM`/`QUEUE` (journal & outbox) and Milestone 5 transactions |

## Delivery sequence

1. **Decouple the database and SQL service from `Station` (`transit-sql` $\perp$ `Station` — pulled forward to close [Milestone 3 P5](03-live-storage-and-sql-cutover.md#implementation-plan--2026-10-27) before [Milestone 5](05-transactions-and-atomic-composition.md) coordinator implementation).**
   Remove `Station` `GenServer`, `AccountRuntime`, `Ledger` and `Coordinator` from
   `transit-sql`, `transit-sql-gateway` and `transit-query-host`. Move client
   operation idempotency (`(AccountId, ClientToken) -> OperationId, CommitLSN, OutcomeReceipt`),
   active lease fencing (`policy_epoch`) and snapshot cut pins directly into the
   database's own partition and transaction coordinator (`DirectCatalog`,
   `TablePartition` and [Milestone 5 transaction logs](05-transactions-and-atomic-composition.md)).
   Execute this decoupling as the immediate bridge closing [Milestone 3 P5](03-live-storage-and-sql-cutover.md)
   so [Milestone 5](05-transactions-and-atomic-composition.md) (`BEGIN`/`COMMIT`/`ROLLBACK`)
   is never built on top of `AccountRuntime` or `Ledger`:
   - A single-partition autocommit SQL `INSERT`, `UPDATE` or `DELETE` must commit
     in **one round-trip** from the SQL gateway to the partition owner's
     `TransitLog` (`TWAL1`), without chunking SQL text into 128-byte KV parts or
     invoking actor turns.
   - A SQL `SELECT` must acquire its consistent snapshot cut (`manifest/v{N}`,
     `lsn_cut`) in the query/transaction read header against hot resident catalog
     and partition state bound to the partition's fenced lease epoch, eliminating
     per-query disk-flushed `ReadPins` and cold manifest replay when the epoch is
     unchanged.
   - Preserve exact original-operation recovery, lost-reply settlement, current
     authorization checks on disclosure and bounded batch streaming from
     [Milestone 4](04-statement-results-and-consumption.md).

2. **Define the declarative `STREAM` grammar and execution contract.**
   Add `STREAM` as a first-class catalog object kind sharing `CatalogId`,
   `DefinitionId`, typed column schemas ($\tau$), physical codecs ($\epsilon$),
   collations ($\kappa$), retention policies and `policy_epoch` grants. Keep
   stream append and consumption grammar explicitly distinct from relational
   table `INSERT` and `SELECT` so stream-specific partitioning, offset cursors,
   watermarks and tailing semantics never collide with relational snapshot rules:
   - **Declaration (`CREATE STREAM` / `ALTER STREAM` / `DROP STREAM`):**
     ```sql
     CREATE STREAM events (
       event_id UUID NOT NULL,
       tenant_id STRING COLLATE utf8_binary NOT NULL,
       payload JSON,
       event_ts TIMESTAMP NOT NULL
     ) PARTITION BY HASH (tenant_id) PARTITIONS 16
     WITH (
       retention = '7d',
       compaction = 'none' | 'key',
       timestamp_column = 'event_ts'
     );
     ```
   - **Production (`PRODUCE INTO`):**
     ```sql
     PRODUCE INTO events (event_id, tenant_id, payload, event_ts)
     VALUES (?, ?, ?, ?)
     RETURNING _partition, _offset, _timestamp;
     ```
     `PRODUCE INTO` appends immutable records to the target stream partition's
     `TransitLog` (`TWAL1`) without primary-key uniqueness scans or row-level MVCC
     conflict checks, supporting producer idempotency sequences (`PRODUCER ID`,
     `SEQUENCE`) and high-throughput Arrow IPC batch appends.
   - **Consumption (`CONSUME ... FROM` and `COMMIT OFFSET`):**
     ```sql
     CONSUME _partition, _offset, _timestamp, event_id, payload
     FROM events
     WHERE _partition = 0 AND _offset >= 1000
     LIMIT 500 WAIT '250ms';

     CONSUME event_id, payload
     FROM events
     GROUP 'billing_workers'
     LIMIT 256 WAIT '500ms';

     COMMIT OFFSET ON STREAM events GROUP 'billing_workers'
     PARTITION 0 OFFSET 1255;
     ```
     `CONSUME` returns a typed [Milestone 4 `ResultSet`](04-statement-results-and-consumption.md)
     whose terminal completion metadata carries the observed partition
     high-watermark offset, next continuation offset and consumer watermark lag.
     Filter and projection predicates push down into vectorized `Fuze` batch
     readers over both hot `TWAL1` tail buffers and historical `.tseg` segments.
   - **Explicit read-only bridge for relational queries over historical stream segments (`STREAM_SLICE`):**
     While `PRODUCE INTO` and `CONSUME ... FROM` own operational stream append
     and stateful cursor/watermark progression, analytical `SELECT` queries that
     join or aggregate historical `.tseg` stream data with relational Tables
     (such as bitemporal `AS OF JOIN` backtesting in [Milestone 12](12-sql-and-dataflows.md))
     use an explicit, side-effect-free table-valued function bridge
     (`SELECT * FROM STREAM_SLICE(events, OFFSET ? TO ?)` or
     `STREAM_SLICE(events, TIMESTAMP ? TO ?)`), keeping stateful stream
     consumption (`CONSUME`) and side-effect-free relational queries over a
     pinned cut (`SELECT`) strictly separated.

3. **Define the declarative `QUEUE` grammar and lease lifecycle contract.**
   Add `QUEUE` as a first-class catalog object kind for point-to-point competing
   consumers, scheduled/delayed work and key-ordered (`key_fifo`) execution:
   - **Declaration (`CREATE QUEUE` / `ALTER QUEUE` / `DROP QUEUE`):**
     ```sql
     CREATE QUEUE tasks (
       task_id UUID NOT NULL,
       entity_key STRING COLLATE utf8_binary NOT NULL,
       attempt INT32 NOT NULL DEFAULT 0,
       payload JSON NOT NULL
     ) PARTITION BY HASH (entity_key) PARTITIONS 16
     WITH (
       mode = 'competing' | 'key_fifo',
       lease_duration = '30s',
       max_attempts = 5,
       backoff = 'exponential(1s, 60s)',
       dead_letter_queue = 'tasks_dlq'
     );
     ```
   - **Enqueueing (`ENQUEUE INTO`):**
     ```sql
     ENQUEUE INTO tasks (task_id, entity_key, payload)
     VALUES (?, ?, ?)
     WITH (dedup_key = 'order-42-charge', visible_at = TIMESTAMP '2026-10-28T00:00:00Z')
     RETURNING _partition, _offset, _message_id;
     ```
   - **Leased claiming and settlement (`CLAIM ... FROM`, `ACK`, `NACK`, `EXTEND LEASE`):**
     ```sql
     CLAIM _message_id, _receipt_handle, _lease_epoch, _attempt, task_id, entity_key, payload
     FROM tasks
     WHERE entity_key = 'order-42'
     LIMIT 16 WITH LEASE '30s' WAIT '250ms';

     ACK ON QUEUE tasks RECEIPT ?;
     NACK ON QUEUE tasks RECEIPT ? WITH (delay = '5s', reason = 'upstream_timeout');
     EXTEND LEASE ON QUEUE tasks RECEIPT ? BY '30s';
     ```
     Every claimed message carries a cryptographic/fenced `_receipt_handle` and
     monotonic `_lease_epoch`. An `ACK`, `NACK` or transactional commit from a
     worker whose lease has expired and been reassigned rejects with a typed
     stale-lease error (`QueueLeaseExpired`) before any side effect can commit.

4. **Implement the `TransitLog` + `.tseg` storage and execution engine for Streams and Queues.**
   Ground physical storage and execution in proven log-structured and streaming
   systems literature ([Apache Kafka](https://kafka.apache.org/) /
   [KIP-932 Share Groups](https://cwiki.apache.org/confluence/display/KAFKA/KIP-932%3A+Queues+for+Kafka),
   [Apache Pulsar](https://pulsar.apache.org/) `Key_Shared` subscriptions,
   [Apache RocketMQ](https://rocketmq.apache.org/),
   [WarpStream](https://www.warpstream.com/) object-tiered logs and
   [Varghese & Lauck's Hashed Hierarchical Timing Wheels, SOSP 1987](https://dl.acm.org/doi/10.1145/41457.37504)):
   - **Shared physical partition architecture (`TablePartition`, `StreamPartition` and `QueuePartition`):**
     Share the segment writer, LeanStore/Umbra buffer slabs, `NvmeCache` and
     Roaring-bitmap machinery across all three partition types in `transit-storage`:
     - **`TablePartition`:** `TWAL1` + `.tseg` + `.tdel` (Roaring bitmap of deleted
       row IDs) + primary-key index.
     - **`StreamPartition`:** `TWAL1` + `.tseg` indexed by monotonic `_offset` and
       `_timestamp` zone maps. Active tail pages stay resident in the LeanStore/Umbra
       RAM buffer pool so live `CONSUME` readers stream zero-copy slices directly
       from memory while catch-up consumers and `STREAM_SLICE(...)` scans read
       sealed `.tseg` segments in `TransitObjectStore` without disturbing tail
       writers.
     - **`QueuePartition`:** Composes `StreamPartition`'s `TWAL1` + `.tseg`
       append-only payload storage with a **`.tack` Roaring-bitmap state vector**
       (reusing the exact `.tdel` Roaring bitmap implementation in `transit-storage`
       to track per-offset `Available`, `Acquired`, `Acked` and `Archived/DLQ`
       states as compact `TWAL1` delta frames and sealed sidecars). Instead of
       mutating and vacuuming B-tree heap pages on every queue claim or
       acknowledgement, payloads are written once and never rewritten; when all
       offsets in a sealed `.tseg` queue segment are marked `Acked` in `.tack`
       and retention allows, the entire segment is reclaimed in $O(1)$ without
       per-row deletes.
   - **Lock-free `key_fifo` key-affinity table:** For `mode = 'key_fifo'` queues,
     each `QueuePartition` tracks active leases by `entity_key` hash alongside an
     in-memory fenced `_lease_epoch` min-heap ordered by `lease_expiry_ns`. While
     a message for `entity_key = K` is `Acquired`, later offsets for `K` wait in
     strict FIFO order while messages for other keys on the same partition remain
     immediately claimable by concurrent workers.
   - **Hierarchical Timing Wheel for `visible_at`, lease expiry and retry backoff:**
     Manage delayed messages (`visible_at`), retry backoff deadlines and active
     lease expirations through an in-memory Hashed Hierarchical Timing Wheel
     backed by time-bucketed `.tseg` runs on disk, achieving $O(1)$ timer
     insertion/cancellation and bounded tick advancement without full-queue index
     scans.

5. **Re-architect `Station` (the durable runtime) on top of Queues, Streams, Tables/KV and Transactions.**
   Following the virtual-actor and durable-execution literature
   ([Restate](https://restate.dev/), [Temporal](https://temporal.io/),
   [DBOS](https://www.dbos.dev/) and [Orleans Virtual Actors](https://www.microsoft.com/en-us/research/project/orleans-virtual-actors/)),
   replace the bespoke `STATE_V1` 256-byte/4-mutation B-tree turn kernel and
   external `courier` polling loop with a declarative execution layer over the
   database:
   - **Actor and workflow inboxes are declared `QUEUE`s (`mode = 'key_fifo'`):**
     A `Station` behavior's inbox is a partitioned `key_fifo` Queue keyed by
     `(behavior_id, actor_key)`. Workers issue batched `CLAIM` requests; the
     Queue's `key_fifo` lease (`_lease_epoch`) provides single-writer fenced
     execution per actor instance without pre-allocating a persistent kernel PID
     or B-tree root per idle actor.
   - **Actor state lives in standard `TABLE`, `KV` or `DOCUMENT` objects:**
     Handlers read and mutate rich relational tables, KV namespaces or JSON
     documents under their turn transaction, removing the legacy 256-byte value
     and 4-mutation per-turn ceilings.
   - **Deterministic replay journals and effect outboxes are declared `STREAM`s and `QUEUE`s:**
     Suspension points, durable timers (scheduled via Queue `visible_at`) and
     recorded HTTP/gRPC/MCP connector intents enqueue into declared Streams and
     Queues.
   - **A `Station` turn is a single [Milestone 5 database transaction](05-transactions-and-atomic-composition.md) with zero bespoke turn-commit protocol:**
     Because [Milestone 5's](05-transactions-and-atomic-composition.md) transaction
     commit envelope natively unifies `(1) TABLE/KV/DOCUMENT state mutations and
     conflict guards`, `(2) STREAM PRODUCE / QUEUE ENQUEUE log appends`, and
     `(3) _lease_epoch-guarded QUEUE ACK / STREAM COMMIT OFFSET settlements`,
     completing a handler turn requires no separate actor commit protocol—it
     executes one standard database commit that validates the inbox Queue's
     `_lease_epoch` and `policy_epoch`, `ACK`s the consumed inbox message,
     commits `TABLE`/`KV`/`DOCUMENT` state mutations, and `PRODUCE`s/`ENQUEUE`s
     outbound actor messages and connector effect intents in **one round-trip**,
     eliminating external `courier` polling and unifying database and runtime
     durability.
   - **Inspectable via standard SQL and Board:** Because `Station` inboxes, dead-
     letter queues, active leases, replay journals and actor state are catalog-
     declared Queues, Streams and Tables, operators and agents inspect queue
     depth, stuck leases, retry history and state through standard SQL and
     [Board](29-board-reimplementation.md) under current `policy_epoch` grants.

## Database dependency separation — 2026-10-27

The first implementation slice separates the existing database execution code
from application runtime dependencies:

- `transit-catalog` directly imports the public client/protocol, Fuze and storage.
  Native page types and shared Document publication bounds no longer require
  importing Station. The unused catalog actor fixture is removed.
- `transit-query-direct` owns finite Table preparation/execution, relational
  compilation/execution, bounded compute workers and relational spill. SQL
  statements and sessions import it directly; captured-query integration calls
  that same implementation. There is no second query engine or source decoder.
- Both package build graphs reject transitive Station imports. Existing source
  checks and consumers move with their implementation owners.

At that source this established a package boundary, not completion of Step 1.
SQL admission, account-token binding and recovery still used
`AccountRuntime`/`Ledger`, and `ReadPins` still journaled durable acquisitions.
The next slices below replace those owners. No latency claim follows from moving
modules alone. Streams, Queues and the Station transaction replacement remain
planned.

## Database-owned client-token bindings — 2026-10-27

The next Step 1 slice adds `DirectClientToken`: an authenticated principal/account/
token and request fingerprint bind to one complete immutable Table intent in the
direct catalog WAL. Its paged index survives replacement, rejects conflicting
fingerprints, returns the original winner of racing preparations and rechecks
current rights. The deployment quota is independent of resident pages and never
expires identities at capacity. The shared definition changes with the mandatory
stored directory/count. See the
[direct token contract](../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings).

That slice supplied original-intent selection and lookup for typed Table DDL/DML
callers. It did **not** migrate SQL's `AccountRuntime`, `Ledger`, recovery
scheduler or `ReadPins`, provide account-wide pending enumeration, or combine
token acceptance with a single-partition row commit. Namespace, conditional
name, configuration and captured-operation bindings still needed their selected
database ownership contract before the SQL runtime could switch as a whole.
Database-owned snapshot leases and matched latency evidence were outstanding.
The runtime cutover below supersedes that intermediate status.

## SQL database runtime cutover — 2026-10-28

The account runtime cutover replaces SQL's `AccountRuntime`, `Ledger`,
`Coordinator`, private KV upload records and local `ReadPins` journal. The current
v1 definition is `transit.native.v1.database-sql-runtime.2026-10-28`; incompatible
stored roots, saved requests and configurations reject before execution.

| Boundary | Implemented owner |
| --- | --- |
| Complete frozen intents and opaque recovery bodies | `DirectIntent` and content-addressed `DirectRecord` in `transit-catalog` |
| Account/client-token identity, bounded pending discovery and retained quotas | Catalog token, operation, pending and account-usage trees; immutable acceptance receipt plus compare-and-set progress |
| Replacement fencing | Catalog activation revision checked under shared access for the entire database request; replacement requires exclusive access |
| SQL DDL/DML recovery and cancellation | `transit-sql.DatabaseRuntime` observes the original domain operation independently of sessions |
| Single-partition autocommit | `commit_saved` executes mutation and outcome in one Table WAL append, including unchanged updates; retry observes the same original operation |
| Read cuts and cleanup | Bounded `ReadCache` borrows a warm exact Table cut, with Catalog recovery slots for cold acquisition, eviction and replacement |
| SQL sessions, configuration and explicitly captured sources | `transit-sql-service` composes the independent database package with those optional owners |
| Installed enrollment | One scoped Table identity, stable account and increasing Catalog activation generation; no SQL actor creation or ownership grants |

`transit-sql`, `transit-query-direct` and `transit-catalog` reject transitive
Station dependencies in their package builds. Captured Query/Station source
adapters remain above this boundary and retain their existing execution contracts;
they do not mediate database admission, finite Table queries or commit recovery.
The native SQL proxy proof verifies zero Station sends/turns for database work.
See the [qualification record](../history/qualification/sql.md#database-owned-sql-runtime--2026-10-28)
for executed schedules and limits.

The architecture prerequisite for Milestone 5 is now database-owned. Start that
work from the [transaction handoff](05-transactions-and-atomic-composition.md#database-runtime-handoff--2026-10-28).
Do not infer a catalog-wide transaction from these components: Catalog token
acceptance and settlement remain separate from the partition data commit.
`commit_saved` is one commit request and one data WAL append; total statement
execution still includes validation, staging, Catalog acceptance and observation
requests. Cold read-cache acquisition still persists a pin. The stronger Step 1
latency target requires measuring and reducing those remaining control costs;
this implementation does not claim a one-HTTP-request SQL statement.

The matched four-row wire comparison passes exact values/counts and observes
lower p50 in all 12 mutation cases and 19 of 20 read cases; MySQL literal point
lookup increases by 23%. Default installation/restart schedules also retain
native bootstrap timeouts reproduced in the unchanged baseline. The linked
qualification record keeps those failures and the broader latency/installation
gates open. Milestone 5 can use the database owners described in the handoff.

Streams, Queues, consumer settlement participants and the Station rebuild below
remain planned. Completing database independence does not close the full milestone.

## Table transaction participant handoff — 2026-10-28

Milestone 5 supplies a local Table coordinator, paged common-cut/private workspace
owners, whole-Table OCC, durable savepoints and one original commit/abort decision.
The shared `Transaction.Participant` contract reserves state mutations/guards,
log appends and consumer settlements. Only Table state participants execute in
this profile; native KV/Document, Stream/Queue appends and lease/offset settlements
must reject before acceptance. A reserved variant is not an executable participant.

The [Table checkpoint/outbox example](../../examples/table-outbox/README.md)
composes three ordinary Tables. It does not migrate native inbox progress,
Station turns or connector dispatch. This milestone must provide each additional
KV/Stream/Queue participant's retained basis, current-policy guard, preparation/durability proof,
common-decision visibility, original outcome and bounded cleanup implementation.
The [Document owner](07-document-storage-and-station-decoupling.md) supplies those
same obligations for `DocumentPartition` before Document state can join a turn.
QUEUE ACK must bind the original `_lease_epoch`; Stream/Queue appends must retain
accepted payload availability before decision. Reuse the decision envelope and
original-token owner instead of adding a Station-specific commit protocol.

Qualification must combine inbox settlement, state changes and outbound intents
under one decision, including revocation/fencing, lost replies, partial preparation,
restart and no replay dispatch. The earlier native one-KV turn remains its own
contract until that migration and hard cutover execute. Table transaction evidence
does not establish cross-model or distributed composition.

## Inherited Station cutover obligations

The [milestone 3 boundary and caller inventory](03-live-storage-and-sql-cutover.md#p1--complete-live-ownership-reopen-and-payload-recovery)
records the 2026-10-28 source audit at `05fda5b01` and identifies the still-active
private Station Table engine, `Query` capture,
`TableBridge`/foreign turn actions, SDK examples and consumers, and inspection
metadata. Their removal belongs with this replacement, after the transaction
foundation can preserve or explicitly replace native input/state/output
atomicity. Ordinary catalog Tables already use the direct owner. Do not route
them back through the private engine or remove the catalog's separate
`DirectTableBridge` because it has a similar name.

- [ ] Migrate private `TableCreation`/`TableWrite`/`TableStatement` and retained
  `TableReader`/query consumers to declared data and the selected transaction
  domain. State whether each input acknowledgment, mutation and output intent
  shares one decision. Two independently recoverable commits cannot silently
  replace one native turn.
- [ ] Move stored Table/query metadata, public bindings, language APIs,
  examples, Board interpretation and their recovery/authorization checks
  together under one current-v1 cutover. Remove superseded storage/SDK surfaces;
  do not retain a parallel writable engine or rename it as a generic KV helper.
- [ ] Carry the original SQL latency failures and saved-operation settlement
  evidence into matched before/after measurements of database-owned idempotency
  and snapshot cuts in Step 1, now pulled forward into milestone 3 P5. Request totals including
  background work must remain distinguishable from statement-attributable work.
  Preserve the distinction between [an accepted INSERT recovered by its original
  receipt and an incomplete SQL upload durably abandoned through original-identity
  cancellation](../history/qualification/storage.md#original-sql-diagnostic-outcome-recovery--2026-10-27).
  Neither settlement converts its original submission deadline into a passing
  latency sample.
- [ ] Replace query-host/courier polling through Queue waits and transactional
  outboxes, retaining disconnect/cancellation, wakeup-race, current-policy,
  fencing and shutdown checks. Measure idle requests/CPU and first-work latency;
  eliminating a polling loop in source is not evidence of correct wakeups.

Milestone 3 continues to own direct storage maintenance, read lifetimes,
original-operation recovery, installed inspection and its final qualification,
and now includes Step 1's SQL/database decoupling bridge. The private Station
Table/Query migration and Queue-based runtime replacement remain here.
These inherited tasks neither complete that milestone nor claim the replacement
runtime is implemented.

## Later owners and execution gates

- [Logical document storage, `.tseg` trees and Station decoupling](07-document-storage-and-station-decoupling.md)
  severs the remaining `STATION_DOCUMENT_V1`/`SIX1` actor-turn dependency so
  `DOCUMENT` joins `TABLE`, `STREAM` and `QUEUE` in `transit-storage`
  (`DocumentPartition`) before client foundation extraction.
- [Shared client foundation](09-client-foundation-and-language-apis.md) and
  [SDK coverage](20-service-and-sdk-coverage.md) expose idiomatic `PRODUCE`,
  `CONSUME`, `ENQUEUE`, `CLAIM`/`ACK`/`NACK`, `Document` and re-architected
  `Station` worker APIs across target languages without re-introducing a
  `Station` dependency into ordinary data clients.
- [Managed computations and WAL-activated dataflows](12-sql-and-dataflows.md)
  connect declarative `STREAM`s and Table `CHANGES(...)` CDC feeds directly to
  continuous `Fuze` pipelines and materialized views, advancing consumer-group
  watermarks atomically with materialized output commits.
- [Data structures and runtime performance](13-data-structures-and-performance.md)
  enforces zero steady-state heap allocations after warmup, LeanStore/Umbra
  buffer residency and per-morsel resource metering across Stream/Queue tail
  readers, Roaring-bitmap ack vectors and `Station` turn commits.
- [Storage providers](22-storage-providers-and-concurrency.md),
  [replication](23-replication-and-failover.md) and
  [clustered execution](25-clustered-execution.md) extend partitioned Stream/Queue
  leases, timer wheels and fenced `Station` worker placement across distributed
  nodes.

## Completion evidence

Require executable proof through real SQL and typed callers in the
[proof ledger](../history/qualification/README.md):

- **Database decoupling and single-round-trip latency:** Verify that `transit-sql`
  and `transit-sql-gateway` execute DDL, autocommit DML (`INSERT`/`UPDATE`/`DELETE`)
  and `SELECT` with zero imports or runtime calls to `Station` (`AccountRuntime`,
  `Ledger`, `GenServer`), reducing local 1-row `INSERT` coordination from 16
  native turns to 1 partition commit and `SELECT` to 1 snapshot-cut batch read
  while preserving exact duplicate-token idempotency and lost-reply recovery.
- **Stream correctness and watermark recovery:** Exercise `CREATE STREAM`,
  `PRODUCE INTO` (single, batch and idempotent-producer sequences), positional and
  consumer-group `CONSUME ... FROM` across `TWAL1`-only tails, `.tseg` flush
  boundaries, compaction and process restart, and verify `COMMIT OFFSET`
  monotonicity and lag reporting.
- **Queue lease fencing, `key_fifo` ordering and timer wheels:** Exercise
  `CREATE QUEUE`, `ENQUEUE INTO` (immediate, deduplicated and `visible_at`
  delayed), competing and `key_fifo` `CLAIM ... FROM ... WITH LEASE`, `EXTEND LEASE`,
  `ACK` and `NACK` with exponential backoff and DLQ routing. Prove that expired
  leases fence late worker `ACK`s/commits (`QueueLeaseExpired`), that `key_fifo`
  strictly serializes claims per `entity_key` without blocking other keys on the
  same partition, and that sealed `.tseg` queue segments reclaim cleanly once all
  offsets are acknowledged.
- **Transactional `Station` turns over Queues, Streams and Tables:** Prove that a
  `Station` handler claims a `key_fifo` inbox Queue message, mutates a declared
  `TABLE`/`KV` state resource (> 256 bytes and > 4 keys) and enqueues outbound
  messages/connector intents in one atomic transaction commit; verify that crash
  or lease loss before commit rolls back state and outbox intents together and
  redelivers the inbox message under a higher `_lease_epoch` without duplicate
  side effects or external `courier` polling.

## Durable write lifecycle and interactive latency

[Implementation tracker #211](https://github.com/spoke-sh/transit/issues/211)
orders contract/model work, concrete replay, exact console measurement, resident
owners, bounded publication batches, combined single-partition commitment and
read-after-write qualification. Preserve the separate Catalog acceptance and
Table completion boundaries until a common transaction envelope actually replaces
them. The [finite models](../../tests/verification/models/README.md#finite-sql-write-lifecycle-models)
include both paths without treating the candidate as implemented.

The resident-owner/direct-completion implementation delivers part of W4: bounded
catalog and Table workspaces, suffix validation on changed history, exact proof
verification reuse, principal projections tied to the complete native head, and
foreground INSERT/UPDATE/DELETE completion through the original accepted intent.
Successful foreground writes return authoritative counts without client polling;
Catalog pending accounting still settles separately. Current authorization,
activation fencing, recovery and control capacity remain independent gates.
Repeated immutable publication can reuse an acknowledged object within the same
exclusive owner epoch; first-publication durability barriers remain required.

The installed persistent-console comparison observes warm SELECT medians of
90.5–92.5 ms versus 216.5–250.5 ms in its controls, and INSERT medians of
338–362 ms versus 501–2,055 ms. Write variation, slow post-DELETE reads and a
separate installed-startup timeout prevent a general latency guarantee. The
[qualification account](../history/qualification/performance.md#resident-owners-foreground-completion-and-snapshot-acquisition)
preserves all samples and failures. Snapshot preparation now reconciles a raced
pin only after proving the original acquisition absent and unable to succeed;
accepted or uncertain cuts never change identity.

W3/W7 qualification remains open alongside W5/W6 publication batching and a
combined single-partition commit. Background pending scans, separate Catalog
acceptance/settlement, cold snapshot replacement and first-publication work still
cost time. The 190 ms then 19 ms INSERT targets and 10–20 ms warm SELECT target
are not met by these samples. No runtime TRUNCATE support is added.

### Proposed TRUNCATE contract for implementation

TRUNCATE remains unsupported by the current SQL execution contract. Its modeled
operation fixes the following implementation direction before grammar/runtime
work and the required current-v1 cutover:

- Publish an empty successor of the existing Table. Preserve object, definition,
  schema, grants and original operation receipts; never implement it as DROP and
  CREATE or immediate object deletion.
- Bind the exact definition and data basis before acceptance. A concurrent data
  change causes the original frozen attempt to reject; retry does not rebind or
  reselect. The command requires the current Table mutation/delete authority,
  with execution fencing and separate current inspection rights for its outcome.
- Derive matched/changed counts from the authoritative predecessor's live-row
  count. Both counts equal the number removed. Empty TRUNCATE reports zero counts
  while advancing the logical data frontier, making the ordering with concurrent
  writers observable without inventing a row change.
- Preserve retained snapshots and logical history with an explicit reset event
  and predecessor coverage. Logical removal grants no physical expiry permission.
  A later INSERT followed by retry of the old TRUNCATE returns the original
  receipt and leaves the new row intact.
- Do not reset operation-derived row identities. SQL sequence reset, CASCADE,
  trigger dispatch and dependent-object rewriting are outside the initial
  profile; reject requested unsupported options. Do not introduce sequence or
  constraint features simply to implement this operation. Future constraints
  must define their own admission checks before Tables using them qualify.
- Start with the existing one-Table atomic domain. Multi-Table transaction
  composition depends on Milestone 5's common decision/visibility contract;
  TRUNCATE must not add a separate coordinator.

The model covers empty successors, frontier ordering, retained history and
original retry identity. It does not deliver parser support, native action tags,
stored reset/history records, shared result command kinds or runtime execution.
Those require one coordinated v1 contract/consumer migration and concrete disk,
console and caller qualification. The 10×/100× INSERT targets remain measurement
gates, not consequences of a model check.
