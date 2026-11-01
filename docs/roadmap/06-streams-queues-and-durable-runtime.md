# 6. Declarative streams, queues and durable runtime architecture

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · [Feeds #127](https://github.com/spoke-sh/transit/issues/127) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Decouple the database (`DirectCatalog`, `TablePartition`, `KV`, `Document`,
`transit-query` and `transit-sql`) completely from the `Station` durable actor
runtime, elevate **Streams** (`STREAM`) and **Queues** (`QUEUE`) to first-class
declarative database primitives with dedicated SQL and typed-caller grammar over
`TransitLog` (`TWAL1`) and `.tseg` segments, and re-architect `Station` on top
of those database primitives and [supported transactions](05-transactions-and-atomic-composition.md).

The [completion plan after PR #303](#first-implementation-changes) sequences
the remaining contracts, caller operations, transaction qualification, Station
cutover and performance work from merge `997fbfda9`. Start there for the current
review baseline, dependencies, commit boundaries and acceptance gates. The
[earlier source audit](#source-baseline-and-remaining-gaps) and dated progress
records preserve their original attribution. Delivery-sequence SQL examples
below illustrate proposed scope; use the [SQL reference](../handbook/reference/sql/streaming.md)
for the exact executable declaration and inspection subset.

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
       (sharing the Roaring bitmap foundation introduced for `.tdel` in R1
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
     outbound actor messages and connector effect intents in **one client commit
     round-trip** (participant preparation and physical WAL writes remain separate
     costs unless a qualified common-log path combines them),
     eliminating external `courier` polling and unifying database and runtime
     durability.
   - **Inspectable via standard SQL and Board:** Because `Station` inboxes, dead-
     letter queues, active leases, replay journals and actor state are catalog-
     declared Queues, Streams and Tables, operators and agents inspect queue
     depth, stuck leases, retry history and state through standard SQL and
     [Board](30-board-reimplementation.md) under current `policy_epoch` grants.

## Implementation plan for remaining work

Deliver an application lifecycle in which a caller declares a Stream or Queue,
publishes typed data, observes consumption or leased work, and recovers the same
accepted operation after failure. Then make a Station turn atomically settle its
input, change declared state and publish outbound intents through the database
transaction owner. Keep the milestone **In Progress** until the installed caller,
cutover and performance gates below pass.

### Source baseline and remaining gaps

Source audit: `0e2fba44727ca858bd1e8e4a775b62fbcf1a665d`, 2026-10-31.
This historical assessment updates the original `ba177f4acb52` plan against the checked-in owners,
contracts, tests and qualification ledger. It is a source assessment, not a new
runtime qualification. The dated records below qualify their own revisions;
neither their union nor the presence of a test establishes a pass at this HEAD.
The table records that audit revision, not the current merged implementation.
Subsequent delivery appears in R4–R6 and the
[post-merge completion plan](#first-implementation-changes).

| Area | Delivered basis | Remaining obligation |
| --- | --- | --- |
| Database/SQL independence | [`transit-sql`](../../packages/zig/transit-sql/README.md), `transit-catalog` and `transit-query-direct` reject transitive Station imports. `DatabaseRuntime`, direct tokens, retained cuts and event-driven recovery replace the SQL actor ledger | Preserve those boundaries. `transit-query` still imports Station and Document adapters; database independence does not mean all Query/Station consumers have migrated |
| Declarations and policy | `Catalog.callLog` supports typed preview, admission, execution/recovery, lookup/list, ALTER, RENAME and DROP; immutable schema/routing, native grants and exact DLQ dependencies are implemented | Dedicated SQL DDL and broad caller exposure. ALTER still refuses schema, partition-count, routing/key and ordering changes; do not advertise the proposed examples as supported |
| Stream payloads and progress | [`Catalog.callStream`](../../packages/zig/transit-data-client/README.md) provides idempotent append, fixed-cut reads, explicit assignments/checkpoints, original-operation recovery, release and bounded waits | SQL `PRODUCE`/`CONSUME`/`COMMIT OFFSET`, Arrow batch ingress qualification, transaction participation and the retained Fuze source for `STREAM_SLICE` |
| Stream storage | [`StreamPartition`](../../packages/zig/transit-storage/src/StreamPartition.zig) has WAL tails, `.tseg` sealing, archive/checkpoint/trim, compaction, sparse payload rewriting and opted-in age expiry; local maintenance preserves pins, consumer progress and original receipts | Final integrated fault/resource qualification at one revision; preserve the delivered algorithms rather than rebuilding them |
| Queue payloads and leases | [`Catalog.callQueue`](../../packages/zig/transit-data-client/README.md) supports enqueue, original bounded claims/pages, ACK/NACK/renewal and explicit payload-read release. `QueuePartition` preserves FIFO heads, exact leases and original outcomes across restart | Public bounded claim waits, atomic DLQ transfer, mixed transactions and SQL verbs. Retry exhaustion currently leaves an inspectable nonterminal blocked source |
| Queue scheduling and retention | `.tack`, paged indexes, fenced lease heap, visibility/retry wheel, full-key affinity cache, durable timer runs/merges and automatic local maintenance are implemented. Opted-in terminal-prefix expiry preserves open claims and replay | Integrated saturation, concurrency, clock and wakeup evidence. Terminal eligibility alone never authorizes deletion |
| Shared storage | [`transit-bitmap`](../../packages/zig/transit-bitmap/README.md), `BitmapDirectory`, the `.tdel` migration, `.tack`, pinned tail slabs and retained-graph collection are delivered | Maintain bounded allocation and complete ownership across the new transaction preparations, DLQ destinations and runtime roots |
| Transactions | [M5's local Table profile](05-transactions-and-atomic-composition.md#selected-delivery-profile-and-exclusions) supplies common cuts, private statements/savepoints and durable decisions | [`Participant.requireLocalTable`](../../packages/zig/transit-protocol/src/Transaction.zig) still rejects KV, Document, append and settlement. `DirectTransaction`, `TransactionDirectory` and `TransactionDecisionLog` enforce that restriction; reserved union variants are not executable participants |
| Direct KV | [`KVPartition`](../../packages/zig/transit-storage/src/KVPartition.zig) supplies bounded typed mutations, large values, receipts and retained reads. A distinct native KV authority domain is delivered | Named lifecycle/data callers, node dispatch and transaction participation. [`DirectResource`](../../packages/zig/transit-catalog/src/DirectResource.zig) still requires a writer PID and native initialization |
| Document dependency | M7 has delivered neutral types, logical evaluators, `DocumentPartition`, retained reads/recovery and graph foundations | M7 owns the direct catalog/dispatch and participant/consumer cutover. Integrate its participant with R5; neither its storage owner nor its authority type establishes a public transactional Document API |
| Station and consumers | Existing native one-resource turns, durable calls, names, timers, supervision, private Table/Query helpers and connector outcomes continue to work under their current contracts | Queue-backed inboxes, database state/journal/outbox transactions, service persistence migration and removal of superseded writable engines/ABI actions. Query-host still has a courier role; native delivery waits do not constitute a Queue-based runtime |
| SQL and analytical bridge | M4 statement results and M5 Table transactions are available; `BitemporalAndTvf.evaluateStreamSliceTvf` has component semantics | No executable Stream/Queue SQL or retained catalog-bound `STREAM_SLICE`. Bind real owners and grants without materializing an entire Stream into the component evaluator |
| Write-path performance | Resident owners, publication groups, cross-tree staging, pipelined writes and reused statement metadata are delivered | Account-wide token/partition commit composition, reconstructible bookkeeping, matched latency gates and read-after-write costs remain open under R9/M8 |

The implemented public entry points are typed Zig `callLog`, `callStream` and
`callQueue` over the signed native service. Current bounds include 1-MiB
append/enqueue batches, at most 256 claimed rows, Stream pages of at most 4096
rows/examined offsets and 4 MiB, and Stream waits of at most 1000 ms, all subject
to smaller declaration/deployment limits. See the [Streams reference](../handbook/reference/streams.md)
for exact semantics. Queue scheduling is automatic when local maintenance is
enabled; a public Queue claim-wait action is still absent from
[`DirectQueueClient.Action`](../../packages/zig/transit-catalog/src/DirectQueueClient.zig).

Evidence supporting this assessment has different scopes:

- [Typed declarations](../history/qualification/catalog.md#typed-stream-and-queue-catalog-lifecycle--2026-10-29)
  and [signed Stream operations](../history/qualification/catalog.md#signed-stream-payload-and-consumer-operations--2026-10-30)
  cover current authorization and original-operation recovery. The earlier
  [Stream clean core run](../history/qualification/catalog.md#clean-core-qualification-of-the-stream-maintenance-slice--2026-10-30)
  passed 28 tasks before the subsequent Queue/KV changes.
- [Queue retention](../history/qualification/catalog.md#terminal-queue-payload-retention--2026-10-30)
  covers signed callers, restarts and combined native maintenance under the
  unchanged 32-MiB budget. The later [rebased Queue schedule](../history/qualification/catalog.md#rebased-storage-crash-boundary-and-installed-sdk-attempts--2026-10-30)
  passed 374 public requests and four lost replies. The same source's clean core
  run failed a crash-oracle boundary; the corrected isolated suite passed, but
  the full corrected lane and installed SDK matrix were still incomplete.
- [Direct KV storage](../history/qualification/catalog.md#direct-kv-storage-foundation--2026-10-30)
  covers six keys and a 128-KiB value in one record, growth beyond a one-page
  cache, retained reads and disk reopen. The eight-language authority regression
  exercised Tables with the extended profile, not installed direct KV operations.
- The [expanded Queue model](../history/qualification/verification.md#stream-and-queue-contract-and-bitmap-foundations--2026-10-29)
  exhausts 3,093 states with nine negative controls over three offsets/two keys.
  It assumes atomic accepted transitions and has no Queue-owner replay bridge;
  mixed-participant correspondence, physical faults and scheduling progress
  remain separate gates.

The milestone therefore remains **In Progress**: standalone typed primitives
have substantial executable coverage, while their SQL and transactional runtime
composition are unfinished. Final closure requires new common-revision evidence.

### Delivery profile and milestone boundaries

Start with one catalog, branch one and a fenced local database authority using
disk-backed `LocalWal` and `LocalSegmentStore`. Support multiple logical Stream
and Queue partitions under that authority. Per-partition order is explicit;
neither a returned vector of offsets nor several independent snapshots establishes
a global order or atomic cut. Reuse M5's local decision domain for compositions
that span those partitions. Distributed assignment, replication, remote atomic
commit and provider throughput require the later provider/cluster milestones.

Use typed Zig callers and the shared SQL service as the first executable
surfaces. New cross-language API breadth belongs to M9/M21, but all existing
affected ABI/SDK consumers must migrate in this milestone's hard cutover.
Board receives inspection under current authorization through public reads; its broader
workbench redesign stays in M30. Continuous Fuze dataflows stay in M12; bounded
`CONSUME ... WAIT` and finite `STREAM_SLICE` do not imply continuous SQL.

Direct KV and Table state must support the Station completion workload, including
values above 256 bytes and more than four key changes under explicit byte/work
budgets. Do not raise `STATE_V1` constants or hide a Table behind the old native
turn protocol. M7 owns `DocumentPartition` and its participant. Implement the
Table/KV turn first; expose Document turns only after that owner proves the same
common-decision obligations. This sequencing does not waive M7 or claim that
all Document paths are already independent of Station.

`StreamPartition`, `QueuePartition`, `KVPartition`, `.tack` and the primitive
contracts now exist. Extend their owning packages; do not create parallel
storage engines or another transaction coordinator. A new independent library
boundary requires its own manifest and checks.

### Work packages and dependencies

R2's typed declaration lifecycle now passes its local catalog/native service
gate, with [executed evidence](../history/qualification/catalog.md#typed-stream-and-queue-catalog-lifecycle--2026-10-29).
R0/R1 retain contract/model and integrated maintenance obligations. R3 has a
disk-backed storage owner, signed typed payload/consumer operations and bounded
wait composition, automatic local maintenance and sparse physical payload
rewriting. Full exit qualification remains open.
R4–R6 are partially delivered; R7–R10 remain open. The [first foundation slice](#first-foundation-slice)
delivered the initial parts of R0/R1; the following progress slice adds shared
storage and catalog integration, signed Stream/Queue callers and installed
restart checks. Declaration/inspection SQL is delivered; workload SQL remains outstanding.
Each package can contain several reviewable changes; it closes on its exit
evidence, not on a parser or module landing.
R0–R10 below retain the full acceptance scope. Use the current assessment to
preserve delivered pieces and implement only their outstanding obligations.

The current progress slice delivers:

- R0 declaration/routing/retention contracts, original producer outcomes,
  consumer assignment/progress, finite authenticated reads and trusted-time
  observations. Direct KV and mixed-participant contracts now exist. Expanded
  Stream/mixed model correspondence, durable workload-result semantics and
  replacement runtime contracts remain outstanding.
- R1 paged Roaring directories, the coordinated `.tdel` migration, `.tack`
  envelopes, fenced initialization, bounded pinned tail slabs, immutable log
  archives/checkpoints and retained-graph integration. Queue-specific indexes and bounded durable scheduling are now implemented;
  final integrated resource qualification remains outstanding.
- R2 typed create/alter/rename/drop/lookup/list/pending/recovery, shared names and
  operation identities, native grants and exact-definition DLQ dependencies.
  Historical Queue dependency closure uses exact recorded destinations; atomic
  DLQ transfer still depends on R5.
- R3 atomic single-partition append and producer deduplication, bounded retained
  reads and offset settlement, sealed `.tseg` placement, timestamp filtering,
  archive/checkpoint/trim, control reserve and explicit age-based prefix expiry.
  Paged consumer watermarks protect unread input; old pins and original outcomes
  survive logical expiry. Resumable key compaction publishes sparse read
  visibility while preserving old pins, tombstones and current consumer cuts;
  native collection retains pending candidates through checkpoint and restart.
  A bounded notification component covers register/recheck wake ordering,
  cancellation and deadlines. Signed `stream` dispatch and shared
  `Catalog.callStream` compose original operation identity, current grants,
  owned finite pages, group settlement and closure. Independent signing fixtures
  and native composition tests cover exact recovery and buffered revocation.
  Trusted clock intervals keep append upper bounds, expiry lower proofs and
  persisted floors distinct. Bounded wait composition passes catalog and native
  concurrent host tests for timeout without acceptance, original cut recovery,
  append wakeup, cancellation and revocation after parking. The rebased
  [HTTP and contract checks](../history/qualification/catalog.md#bounded-stream-consume-waits-and-main-integration--2026-10-30)
  pass, including reserved wait admission and original read recovery.
  Automatic local scheduling passes a
  [native disk schedule](../history/qualification/catalog.md#automatic-local-stream-maintenance--2026-10-30)
  covering bounded recovery, executor replacement, finite archive/compaction
  completion, retained reads, clock refusal and opted-in expiry under quota.
  Table and Stream work share a measured allocation budget; disposable validated
  prefix hints avoid repeated historical replay between units. Sparse payload
  rewriting now preserves original ordinals and old placement pins through
  bounded accepted passes, disk restart and empty placements. The updated native
  scheduler completes both partitions within the same memory budget. Native
  collection retains old placement directories and payloads until both read pins
  and replay release them, then preserves current reads after reclamation. The
  installed signed-caller schedule also passes: new reads converge to compacted
  rows while old read pins and original producer outcomes survive SIGKILL and
  restart. The committed Stream slice also passes all 28 tasks in the
  [clean core lane](../history/qualification/catalog.md#clean-core-qualification-of-the-stream-maintenance-slice--2026-10-30).
  Final common-revision qualification with subsequent Queue work remains open.
- R4 private candidate transitions and paged Queue indexes now cover FIFO heads,
  eligibility, exact lease metadata, retries and blocked destinations. Immutable
  claim-selection artifacts preserve original leases and placement cuts. Their
  [disk and format checks](../history/qualification/catalog.md#queue-index-and-original-selection-candidates--2026-10-30)
  pass. The storage Queue owner now accepts enqueue payloads, producer outcomes
  and initial scheduling state in one WAL record; bounded replay reconstructs
  the complete root without object writes. Disk restart, lost replies,
  archive/checkpoint/trim, candidate pressure, revocation and retained-graph
  reclamation pass focused tests. Bounded durable claims now preserve exact
  selections and empty outcomes across expiry and disk recovery, retain original
  payload directories through collection, and refuse capacity or time uncertainty
  before publication. ACK/NACK/renewal and one-deadline expiry now publish full
  successor roots, preserve original settlement outcomes through retirement and
  restart, and keep exhausted FIFO heads nonterminal. Bounded original-claim pages
  now own payload bytes across scratch/tail reuse and report observed current
  lease status under separate authority/time checks, including after collection
  and retirement. Catalog composition now preserves Queue work in the shared
  operation namespace and checks current native grants across policy edits and
  disk reopen. Signed native dispatch, typed caller recovery, independent signing
  fixtures and installed HTTP now pass focused checks, including FIFO head
  selection, three uncertain replies and original payloads after DROP and
  SIGKILL/restart. Shared native maintenance now rotates Tables, Streams and
  Queues under one allocation budget, with one recovering workspace per log
  kind, physical Queue tiering and one-deadline expiry. The
  [native and installed schedules](../history/qualification/catalog.md#automatic-local-queue-maintenance--2026-10-30)
  pass clock-bound expiry, reserved capacity, physical tiering after retirement,
  original outcomes and the combined Table/Stream maintenance regression.
  A bounded exact-lease heap now caches the earliest active deadline prefix and
  invalidates on changed durable lease state; its capacity does not limit the
  active population. Retained graph traversal now follows exact historical DLQ
  definitions from declarations and blocked items, refusing missing or invalid
  destinations. A hierarchical visibility/retry wheel now accelerates a bounded
  earliest eligibility prefix; incomplete advancement or prefix exhaustion
  consults the durable directory and never establishes an empty claim. Lease
  expiry remains owned separately by the fenced heap. Bounded sorted `.tseg`
  timer chunks, pending buffers and paged logical-run directories now have
  storage codecs. Private two-run merging now resumes bounded input progress
  with exact completion evidence and frozen Queue-state filtering. Schedule
  composition adds paged pending chunks, bounded earliest-event reads, size-tiered
  merges and a finite stale-entry sweep. Accepted Queue roots now publish both
  timer kinds, final delta buffers and bounded maintenance progress. Retained
  traversal owns frozen inputs, partial output and Queue-state bases; the
  [disk recovery and collection schedules](../history/qualification/catalog.md#accepted-queue-timer-schedules--2026-10-30)
  preserve original work through lost replies, retirement and physical deletion.
  Native maintenance passes trusted-time expiry, reserved capacity, recovery and
  the unchanged 32-MiB shared budget; the subsequent installed closure schedule
  also passes with accepted timer scheduling enabled.
  A bounded full-key FIFO affinity cache now binds entries to immutable key
  roots, pins generations during concurrent reads and retires exhausted slots.
  Collisions, long keys and saturation fall back to paged lookup. Focused cache,
  owner, disk warm-hit, retained-graph, native and installed regression checks pass. Explicit original-claim payload-read closure now
  records its own recoverable operation without settling or cancelling leases.
  Retained traversal uses closure only from its own accepted cut; older replay
  roots keep their payload dependencies. Focused disk, signed-contract and
  catalog checks pass; the [installed closure schedule](../history/qualification/catalog.md#explicit-queue-claim-payload-read-closure--2026-10-30)
  passes four uncertain replies and repeated node restarts. Terminal payload
  expiry now removes at most one sealed, fully terminal prefix batch under an
  opted-in age policy, preserving open claims and exact original outcomes. Disk
  recovery, unrelated-removal negative controls and native physical collection
  and installed automatic retention pass. The combined native schedule preserves
  open claims while expiring forty terminal batches under reserved capacity and
  the unchanged 32-MiB bound. See the [terminal-retention evidence](../history/qualification/catalog.md#terminal-queue-payload-retention--2026-10-30).
  Explicit atomic DLQ transfer is delivered in the subsequent R5 slice;
  automatic scheduling and combined qualification remain outstanding.

R5 now has a database-owned KV storage foundation over the shared paged engine:
typed values, byte-exact keys, bounded atomic batches, exact receipts and retained
cuts. Disk checks cover large values, more keys than the resident page cache,
lost replies, sealing, archive/trim and restart. A mandatory persisted kind keeps
Table callers and checkpoint recovery from treating KV objects as Tables.
The native profile and all affected callers now require a distinct KV authority
domain; bootstrap, generated contracts and strict SDK decoding share that
profile. The [authority qualification](../history/qualification/catalog.md#direct-kv-authority-and-complete-caller-profiles--2026-10-30)
records the installed Table regression matrix and its pre-rebase source.
Named direct KV now has catalog declaration, signed mutation/read/pin operations,
rename/DROP and shared data-client support. The native writer-backed named KV
path is removed; Documents retain that separate owner. Focused storage, signed
dispatch, bounded-memory and cross-kind dependency checks pass. Installed
current-definition KV recovery passes; clean qualification remains open. Table/KV
transaction components now share private workspaces, current rights and one
decision, with disk replacement and lost-reply tests. Native transactions now
compose Table/KV state, Stream append/offset, Queue enqueue/ACK and explicit
paired Queue terminal transfers. Installed state, mixed and transfer recovery
schedules pass at one definition, including two lost replies and node restarts
per schedule; see [declaration/token and current-definition evidence](../history/qualification/catalog.md#streamqueue-declaration-tokens--2026-10-31)
and [bounded transfer evaluation](../history/qualification/transactions.md#installed-recovery-and-bounded-evaluation).
The complete preparation/decision/finalization fault matrix and automatic DLQ
scheduling remain open. R6's workload SQL/shared caller/finite analytical
surfaces, R0 model correspondence and final integrated
qualification also remain open. Publishing declarations or neutral types does
not complete these gates.

| Package | Outcome | Start gate | Exit evidence |
| --- | --- | --- | --- |
| R0 | Partial: primitive and mixed-participant contracts delivered; workload-result/runtime contracts and model correspondence open | Baseline audit and M5 handoff | Shared types/fixtures, resolved decisions below, finite invariants and refusal cases |
| R1 | Implemented foundations; integrated qualification open | R0 physical ownership and format decisions | `.tdel`/`.tack` container correctness, bounded allocation and disk publication faults |
| R2 | Implemented: catalog declarations, grants and inspectable lifecycles | R0; R1 initialization evidence before publication | [Typed create/alter/drop/inspect/recovery and native policy proof](../history/qualification/catalog.md#typed-stream-and-queue-catalog-lifecycle--2026-10-29) |
| R3 | Partial: signed payload/read/group operations, bounded waits, local maintenance and sparse rewriting; common-revision qualification open | R1 and R2 | Disk reopen, original producer receipts, complete bounded reads and fenced offset progress through public callers |
| R4 | Partial: claims, bounded waits, retries, delays, maintenance, retention and explicit atomic DLQ delivered; automatic DLQ scheduling open | R3 payload storage and R0 lease contract; R5 for DLQ | Durable claim recovery, stale-lease refusal, per-key order, bounded waits/timers and atomic DLQ transfer |
| R5 | Partial: native Table/KV/Stream/Queue mixed recovery and installed explicit DLQ recovery pass; complete fault matrix and clean qualification open | R0 and M5; integrate R3/R4 as available | One decision publishes state, append and settlement with no partial visibility |
| R6 | Partial: declaration SQL, named inspection and paged listings delivered; workload verbs, finite analytical bridge and mixed SQL open | R2–R5 for each exposed operation | Real typed/native SQL/console/wire outcomes and authorization after buffering |
| R7 | Station behaviors and durable services on database primitives | R4/R5 and public typed callers | Atomic turns, durable calls/timers/names/supervision and handler-free recovery |
| R8 | Connector dispatch, consumer migration and courier removal | R7 and qualified waits | Recorded effects with unknown outcomes preserved; all existing affected callers use replacement owners |
| R9 | Database write lifecycle and latency closure | Start after R0; coordinate M3, M8 and #211 | Original-token common envelope, bounded publication and matched installed latency evidence |
| R10 | Installed qualification and current-v1 cutover closure | All applicable R packages | Complete caller/fault/resource matrix, generated-contract migration and common-revision evidence |

The runtime critical path is R0 replacement contracts → R5 mixed-participant
failure qualification → R7 transactional Station → R8 consumer/effect cutover
→ R10. Reuse delivered named KV, log participants and R1–R4's storage and wait
foundations. R4 automatic DLQ scheduling uses the existing paired transfer after
R5's qualification gate. R6 workload SQL first needs shared durable terminal
outcomes and recoverable mutation results; finite analytical reads use retained
sources without waiting for Station. Mixed SQL transactions reuse R5. R9 continues
with M8, and its performance exit remains a milestone completion gate.
M7 can implement Document storage/catalog work independently; its participant
and Station consumer migration meet R5/R7's interface gates rather than requiring
the entire milestones to finish each other first.

### R0 Define contracts and executable invariants

Extend the neutral types in `transit-protocol` before implementing adapters.
Extend the existing [Stream](../../contracts/STREAM_V1.md) and
[Queue](../../contracts/QUEUE_V1.md) contracts for mixed participation and waits;
define the replacement KV/runtime boundaries and update
[data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[direct ownership](../../contracts/DIRECT_TABLE_V1.md),
[storage](../../contracts/TRANSIT_STORAGE_V1.md),
[authorization](../../contracts/AUTHORIZATION_V1.md),
[results](../../contracts/SQL_RESULTS_V1.md) and
[Station](../../contracts/STATION_V1.md) at their affected boundaries. A shared
operation must define its original identity, frozen inputs, policy checks,
acceptance point, inspectable outcome and recovery material.

Resolve these decisions in those owners before freezing persistent formats:

| Contract decision | Required initial rule |
| --- | --- |
| Object and definition identity | Bind catalog/branch/object, immutable schema, partitioning/hash version, key collation and policy references. Rename preserves identity; drop/recreate never rebinds accepted work. Freeze partition count initially; reject online repartitioning until its migration contract exists |
| Offsets and producer identity | Define a partition-local logical offset independently of physical WAL LSN. Bind producer ID/epoch/sequence, payload digest and original result; identical retries recover the same range, changed payloads conflict, and expired dedup evidence cannot admit an old sequence as fresh work |
| Stream reads and group progress | Use an exclusive next-offset checkpoint, with exact conversion for any user syntax. A bounded consume selects an observed upper frontier and returns verified coverage plus continuation. Reading never implicitly commits progress. Group assignment/ownership generations fence offset commits; the initial local assignment protocol must be explicit |
| Filtering, compaction and gaps | Separate scanned coverage from returned rows. Define key compaction's supersession evidence, tombstones, protected consumer/read cuts and explicit unavailable-history responses; no silent seek to the earliest surviving record |
| Claim identity and receipts | A claim is a mutation with its own idempotency identity and exact leased result. Bind receipts to queue, partition, message, claimant, lease generation and expiry. Signature validity supplies neither current rights nor a live lease |
| Lease expiry and retry | Check authoritative time and `_lease_epoch` at the decision boundary, including expiry before reassignment. Refuse when required time/authority cannot be established. Specify renewal/expiry races, attempt increments, capped backoff and original ACK/NACK outcome recovery |
| FIFO and scheduling | For `key_fifo`, the earliest nonterminal item for a canonical key blocks later items for that key, including delay/retry. Different keys remain eligible. Define exact key equality, hash collision handling and the relationship to declared collation |
| Retention and DLQ | Unlimited retention is the default. ACK/DLQ terminal state alone does not authorize physical deletion. Define separately what retains payloads, receipts, replay, snapshots and pending transactions; DLQ routing must preserve payload reachability and original destination |
| State and settlement composition | Define retained KV bases, append reservations, claim/offset guards, savepoint behavior and one decision across all supported participants. Queue claim commits separately before a turn; the turn ACK is a participant. Rollback never implies that the earlier claim did not happen |
| Runtime lifecycle | Preserve stable actor/call identities, authority-derived origins, recorded destinations, permanent retirement, current execution rights and effect-attempt evidence independently of process placement and Queue leases |

Specify finite limits for schemas, encoded requests, append/claim batches,
returned bytes, waiters, active leases, timer work, private transaction state and
maintenance. Distinguish admission quotas from per-operation work limits and
reserve capacity for ACK, revocation, decisions and recovery. Define typed errors
for each refusal and uncertainty state; neither EOF nor timeout is success.

Extend the Queue model for multiple keys/claimants, durable decisions, lease
expiry without reassignment, restart, revocation, DLQ transfer and retention
roots. Add Stream producer/offset and multi-participant schedules. Export
transitions for replay against the eventual Zig owners, with guard-removal
negative controls. Keep modeled safety, conditional progress and disk evidence
separate; a set-based specification proves no timing-wheel complexity claim.

**Exit gate:** shared fixtures cover successful and forbidden transitions,
all decisions above have an owning contract, and unsupported variants reject
before durable admission. No new public route advertises an unimplemented owner.

### R1 Build shared bitmap and partition storage foundations

The shared bitmap, paged directory, `.tdel` migration and `.tack` foundation are
delivered. Preserve the following requirements when adding participant roots
and closing integrated resource/fault qualification.

Keep the Roaring container implementation below both Fuze's `.tdel` reader and
storage's `.tack` owner without adding a Fuze-to-storage dependency cycle.
Use bounded array/bitmap/run containers, canonical encoding, checked cardinality,
intersection/union and per-container iteration. Expose it through an actual
package interface; do not copy container code between the two formats.

Keep `TDel` and all segment readers/writers/fixtures aligned through any new
definition cutover. Preserve `.tack` headers binding the exact queue, segment, offset range,
definition and accepted state frontier. Its state sets must be disjoint, cover
the known payload range according to the contract, and reject corrupt counts,
overlaps, foreign owners and out-of-range offsets. Lease holders/deadlines and
retry metadata need durable records beyond the bitmap itself.

Reuse `TransitLog`, `TransitObjectStore`, `.tseg` codecs and immutable paged
directories for partition manifests, original receipts and checkpoints. Supply
fenced empty-partition initialization records and verified readback so R2 can
publish a declaration before its append/claim execution slice is enabled. Add
bounded reusable tail slabs and explicit borrowed/owned reader lifetimes; pin a
borrowed slice until release and recheck rights before disclosure. Flush, sealed
sidecar publication and checkpoint installation must preserve logical offsets
and original reads. Publish durable dependencies before their accepted root;
recover or collect abandoned staging only through the owning retained graph.

**Exit gate:** independent bitmap fixtures and disk fault schedules cover
partial publication, missing/corrupt sidecars and replay after trim. Growing
segment and receipt directories exceed resident caches. Counting allocators
verify no parent-heap allocations after warmup on the selected container/tail
paths; broader buffer-pool optimization remains M13 work.

### R2 Add declarative catalog and authorization lifecycles

The typed lifecycle has passed its scoped gate. Carry these invariants into
R6's SQL adapters and R10's common-revision qualification.

Extend `DirectCatalog`, its record/store/retention/walk owners, direct intents
and `transit-data-client` with Stream/Queue kinds and typed lifecycle operations.
Reuse stable object and definition identities, original-token binding, bounded
pending discovery, preview, dependency registration and DROP RESTRICT.
Declarations include schema/type/codec/collation, partitioning, retention and
Queue scheduling/DLQ references. Allocate dependent partitions privately and
publish only after their initialization evidence is complete.

Add explicit privileges for metadata inspection, payload reads, append/enqueue,
group progress, claim/settlement and administration within the existing policy
graph. Definition lookup and receipts must filter or deny under current rights;
an old lease, group membership or actor association cannot substitute for them.
Bind a DLQ by object/definition identity and validate its schema and dependency;
renaming the destination cannot retarget accepted retries.

Define ALTER's first supported schema/policy transitions and reject unsupported
changes before acceptance. Preserve old definitions for retained reads and
frozen operations. Logical DROP hides the live name while retaining accepted
operations, outstanding leases and required history under their selected closure
contract. Definition retirement and physical reclamation remain separate.

**Exit gate:** real typed callers create, preview, inspect, alter, rename and
drop through the public owner; replacement recovers the original operation after
lost allocation/publication replies. Denied reads, changed dependencies,
concurrent declarations and catalogs larger than cache are covered.

### R3 Implement streams and consumer progress

The typed storage/service/maintenance profile is delivered. Preserve these
requirements while completing Arrow ingress qualification, R5 participation,
R6 SQL/retained analytical integration and the combined exit evidence.

Implement `StreamPartition` in `transit-storage`, with catalog/service composition
above it. Allocate logical offsets at accepted append, retain schema and producer
identity, and store payloads either in bounded WAL batches or durable `.tseg`
candidates. Single-partition append atomically records its payload reference,
assigned range, producer progress and receipt. Do not impose Table primary-key
uniqueness work or actor frame limits on this path. Initially require each atomic
append batch to target one partition; cross-partition atomic batches require R5.
Define batch atomicity and partial refusal before enabling Arrow batch ingress.

Build one bounded iterator across hot tail and sealed segments with an exact
retained upper cut, exclusive continuation and explicit scanned coverage.
Timestamp pruning must use verified zone maps without assuming event timestamps
are monotonic. A finite `STREAM_SLICE` binds partitions, ranges and definitions
without creating or advancing consumer-group state; Fuze owns relational
execution over that source. Cross-source atomicity requires the common-cut
contract, otherwise report an independent source vector.

Persist group membership/assignment generations and committed next offsets in
paged database-owned state. `CONSUME` may observe beyond the committed checkpoint;
`COMMIT OFFSET` is a separate fenced, monotonic operation bounded by the selected
consumption contract. Lost replies recover its original result. Empty/filtered
pages carry coverage; missing completion cannot justify advancing a checkpoint.
Implement bounded waits with register/recheck notification ordering and explicit
timeout/cancel results, avoiding missed appends during registration.

Add resumable flush, archive/checkpoint, key compaction and opted-in history
expiry. Preserve producer deduplication floors and required group/read/transaction
dependencies independently of payload cleanup. Missing required storage blocks
recovery and never authorizes a watermark jump.

**Exit gate:** typed callers exercise positional and group reads, producer
fencing, exact batch retries, sparse offsets after compaction, timestamp bounds,
empty terminal results and WAL-to-segment transitions across fresh-process
restart. Retained history and current-policy checks hold after buffering and
physical maintenance.

### R4 Implement queue leasing and scheduling

The payload, claim, settlement, timer, affinity and retention owners described
below are implemented. Bounded public claim waits now use those owners through
the signed Queue caller and shared native wait admission. Explicit paired DLQ
transfers now use the common transaction owner and pass installed recovery.
The next functional work is automatic blocked-item scheduling with durable
attempt identities and current source/destination authority; the remaining exit
work includes the full integrated fault and resource evidence.

Implement `QueuePartition` over the R3 payload owner and R1 bitmap foundation.
The Queue owns its internal payload log; reusing storage must not expose a Stream
operation that bypasses Queue authorization or scheduling. Persist enqueue
deduplication, claim identity, acquired state, receipt generation,
deadline, attempts and terminal disposition before acknowledging them. Reopen
must reconstruct the same accepted claims and fence stale owners; volatile heaps
and affinity entries accelerate that durable state but never establish authority.
Claim retries return the original leased selection, even when it has since
expired, with its current status; they cannot silently claim different work.

Implement competing claims and `key_fifo` selection using bounded active-key
state plus paged durable backlog indexes. Full-key comparison resolves hash
collisions. The affinity table's lock-free operations need a defined memory
reclamation/ABA strategy and concurrent tests; do not place every retained key
in RAM. A batched FIFO claim takes at most one active item per key. Saturation
refuses or waits without dropping work or bypassing a blocked key's head.

Use a hierarchical timing wheel for near-term visibility/retry deadlines, a
fenced active-lease heap and durable time-bucketed runs for far-future work.
Specify which owner handles each deadline so wheel and heap cannot make
conflicting transitions. Bound tick advancement, bucket loading, expiry batches
and recovery work; large clock jumps and a backlog larger than memory cannot
force a whole-queue scan in one operation. Authoritative deadlines, not wakeup
delivery, decide expiry. Test backward/unavailable time and restart downtime.

The bounded public claim-wait operation is implemented through `DirectQueue`,
`DirectQueueClient`, `transit-data-client` and native dispatch. It reuses the Stream
register/recheck pattern and checks Queue eligibility: enqueue, a delayed head
becoming visible, retry/expiry, and ACK exposing the next FIFO head can all make
work available. It freezes the original claim before parking and returns timeout
without accepting an empty claim. The current implementation shares 64 active
registrations and four wait admission lanes with Streams, honors declaration
budgets, and bounds each wait to 1000 ms. The next accepted visibility timestamp
supplies an early timer wake; eligibility still requires fresh trusted time.
Original claims, including empty ones, recover without selecting new work.
The [public contract](../../contracts/DIRECT_TABLE_V1.md#queue-payloads-claims-and-settlements)
owns cancellation, timeout and recovery semantics. [Executed wait evidence](../history/qualification/catalog.md#bounded-public-queue-claim-waits--2026-10-31)
covers signatures, clock uncertainty, current policy after parking, cancellation,
timer-driven eligibility and installed lost-reply/restart recovery. The complete
milestone still requires its common-revision qualification gate.

ACK, NACK and renewal revalidate current authority, receipt and live epoch at
publication. Original accepted settlement is still recoverable after later
expiry. Retry exhaustion and NACK/DLQ transfer use one supported local transaction
once R5 is available, or remain unavailable until then; never mark a source
terminal before its destination payload is durably reachable. A denied or full
DLQ produces inspectable blocked progress.

Track per-segment terminal counts under accepted transitions. An O(1) terminal
eligibility check is distinct from bounded dependency traversal and physical
collection. Reclamation additionally requires explicit retention permission and
absence of protected readers, replay, receipts and transaction dependencies.

**Exit gate:** prove duplicate claim recovery, expired-but-unreassigned refusal,
renewal/expiry/commit races, FIFO delay/retry order, unrelated-key progress,
DLQ publication failure and bounded timer recovery on disk. Cancellation after
claim acceptance preserves leases and original recovery evidence.

### R5 Extend the transaction owner and deliver direct KV

Split the remaining implementation into reviewable changes with these gates:

| Change | Owning code and contract work | Required result before dependents proceed |
| --- | --- | --- |
| R5a: neutral participant protocol | `transit-protocol.Transaction`, data-lifecycle/direct contracts and generated fixtures; replace Table-only selection/guard assumptions | Explicit frozen object selection, kind-specific cuts/guards, prepare evidence, append ordering and settlement/terminal-disposition rules. Unsupported owners still reject before admission |
| R5b: named direct KV | `KVPartition`, catalog `DirectResource` replacement for KV, `LocalCatalogRunner`, native dispatch and `transit-data-client` | Declare/initialize/publish, mutate/read/pin/release, rename/drop and recover through signed installed callers without a writer PID. Prove values above 256 bytes, more than four mutations, missing-key conflicts and current rights |
| R5c: durable preparations and decisions | `DirectTransaction`, `TransactionDirectory`, `TransactionDecisionLog`, workspaces/savepoints and participant adapters in `transit-storage` | Table/KV state, Stream/Queue append and Stream offset/Queue ACK consult one decision. Prepared roots, reservations and receipts survive faults, trim and collection; rollback publishes no partial effect |
| R5d: installed composition and DLQ | Public typed transaction calls, Queue maintenance/settlement and retained graph | One accepted decision settles input, changes state and publishes output; DLQ transfer atomically makes the recorded destination reachable and the source terminal |

The R5a implementation replaces object-only directory keys with scoped
object/kind/logical-partition targets, kind-specific guards and owner-grouped
preparations. Its ordered action vocabulary covers append, offset commit, ACK
and terminal transfer, separating expired maintenance from live worker NACK.
The current-v1 definition cutover migrates existing Table consumers. R5b implements named direct KV
under a separate v1 cutover; its installed KV recovery gate passes and clean
qualification is pending.
R5c adds executable Table/KV composition through the existing workspace and
decision owner. Its component checks include private KV reads, current rights,
savepoint identity preservation, commit/abort replacement and retained graph
traversal. Its installed Table/KV proof passes at `4771f5698`: 33 signed requests,
two withheld replies and two node replacements recover the same private statement
and committed decision. Storage components now retain log source pins, stage
paged action directories, privately evaluate Stream/Queue appends and offset/ACK
settlements, accept preparation barriers and resolve their actual common decision.
Decision checks include final lease/retention deadlines; storage traversal follows
prepared payloads and indexes. Catalog transaction selection also accepts explicit
Stream/Queue partition read dependencies, with common-cut retention, current READ
checks, serializable frontier validation and original pin cleanup. Native log
statements now share the Table/KV workspace sequence and savepoints, with compact
permanent operation reservations and exact outcome recovery. The catalog prepares
surviving log actions, verifies the successor graph within the resident budget,
rechecks aggregate deadlines immediately before the decision and resolves the
original decision during cleanup. Initial components cover Table/Stream commit,
Queue ACK plus enqueue, final lease expiry and lost decision recovery on disk.
The current-definition regeneration and workspace checks pass: 206 catalog tests,
28 selected storage tests, 58 fast checks, 19 contract checks and the handbook
build, with a successful native node build. The
[qualification record](../history/qualification/transactions.md#native-mixed-state-and-log-statements--2026-10-31)
keeps these component results separate from clean integrated qualification.
The [installed mixed proof](../history/qualification/transactions.md#installed-mixed-state-output-and-input-settlement--2026-10-31)
also passes: 85 signed requests, two lost replies and two node replacements
recover the original state mutations, appends, Queue ACK and Stream offset.
The remaining preparation/finalization fault matrix and clean integrated
qualification remain open. The subsequent Queue transfer cutover adds explicit
native transfer statements for live NACK and exhausted-item maintenance. A
statement reserves both operation identities and publishes two private action
directories together. The decision validates exact mirrored actions, original
source payload, both Queues' current rights and final time bounds. Sequential
temporary owners preserve the existing resident budget; source archival cannot
replay as a standalone operation. Exhausted items retain their exact destination
and accepted exhaustion time across policy edits. The
[installed explicit-transfer proof](../history/qualification/transactions.md#installed-recovery-and-bounded-evaluation)
passes at its recorded source. Automatic DLQ scheduling and clean integrated
qualification remain open. The
[direct contract](../../contracts/DIRECT_TABLE_V1.md#transactional-stream-and-queue-work)
owns the executable native profile; this does not enable Queue SQL or Station turns.
Shape validation and neutral directory membership are not evidence
of a completed mixed transaction or DLQ transfer.

R5b can progress alongside R5c after R5a fixes their shared interface. For DLQ,
specify both explicit NACK transfer and maintenance transfer of an already
exhausted/expired item. The latter needs a guarded source-state/terminal
transition under current maintenance and destination authority; it must not
manufacture a live worker ACK from an expired receipt. Freeze the original
destination definition and transfer identity, recover that identity after a lost
decision reply, and keep denied/full destinations blocked and nonterminal.

Generalize `Transaction.Begin`, cut directories, guards, prepared records,
private workspaces, savepoints and common-decision readers beyond their current
Table-specific fields. Keep one catalog/branch/local authority and ordered
participant guards. Define explicit object selection for typed mixed transactions;
existing Table-only SQL BEGIN must not silently widen its accepted cut. New
objects cannot join an already accepted transaction without a defined selection
contract. Preserve serializable conflict checks for absent-key and predicate
reads, including queue eligibility and group-progress dependencies where used.

Deliver a database-owned KV partition/read/mutation owner with paged keys,
bounded large values, retained cuts, exact receipts and current policy guards.
Reuse storage indexes and segments without routing writes through a PID or
`STATE_V1`. Migrate named KV lifecycle bindings and direct callers as part of
its cutover. The [M12 managed-computation modules](12-sql-and-dataflows.md#delivered-implementation-evidence--2026-10-30)
now supply bounded lifecycle, cut-alignment and outbox component cases. Use their
watermark/revision/outbox requirements as a consumer of this common decision;
their in-memory transitions do not replace durable participant preparation,
publication guards or restart recovery. M12 P7 depends on this gate before a
sink outbox can publish atomically with its completed revision. The initial conservative conflict frontier can be resource-wide;
it must separate logical changes from flush/checkpoint activity.

For each executable participant implement these obligations:

1. Retain its exact definition, read/conflict basis, payloads and private work
   under paged catalog storage roots and explicit quotas.
2. Prepare durably without public visibility. Append preparation defines reserved
   offsets, aborted reservations and ordering; readers cannot cross an unresolved
   reservation and later miss committed records. Settlement preparation binds
   the original claim epoch or group generation and next offset.
3. Under ordered publication guards, validate all participants and current policy
   and lease deadlines, then append one original commit/abort decision. Expiry
   cannot interleave between validation and the decision. Prepared/uncertain
   work remains owned until that decision is resolved.
4. Make reads, claims, consumer progress and recovery consult the common decision
   before exposing any successor. Finalization is resumable bookkeeping, not a
   second visibility decision. A committed ACK wins over later lease expiry;
   abort leaves the input governed by its existing claim/expiry lifecycle.
5. Release private roots, pins and reservations in bounded steps while preserving
   retry outcomes. Savepoint rollback cannot retract a previously committed
   claim, reuse statement identities or publish append/settlement candidates.

One client COMMIT and one authoritative decision do not mean one physical WAL
write for a multi-partition transaction. Measure preparation and finalization
separately. Any single-log fast path must preserve the same semantics and prove
its actual co-location; do not generalize the one-partition target to every turn.

**Exit gate:** a real caller transaction commits Queue ACK or Stream offset,
Table/KV state and Stream/Queue output together. Inject faults at each preparation,
decision and finalization boundary, revoke each participant's rights, and expire
the lease during commit. Fresh readers observe all or none; recovery observes
the original decision without re-running a handler. Document remains rejected
until M7 supplies the same obligations.

### R6 Expose SQL and shared caller operations

**Delivered declaration/inspection slice:** dedicated CREATE/ALTER/RENAME/DROP
Stream/Queue syntax lowers through the shared Catalog and frozen caller-token
owner. Named SHOW/DESCRIBE and paged SHOW STREAMS/QUEUES use the existing result
lifecycle with current disclosure rights. The [installed SQL evidence](../history/qualification/sql.md#stream-and-queue-declaration-sql--2026-10-31)
covers native, console, PostgreSQL and MySQL callers, original-token recovery
after service replacement, two-batch metadata, empty listings, exact-definition
invalidation and buffered revocation. Workload verbs, retained analytical reads,
mixed transaction SQL and clean dependent lanes remain open.

Deliver four independently testable slices: declaration/inspection SQL over R2;
standalone producer/consumer/lease SQL over R3/R4; finite retained `STREAM_SLICE`
through Fuze; then mixed transaction SQL over R5. The first three do not depend
on completing Station. Claim `WAIT` can lower through R4's public wait contract;
transactional append/settlement syntax waits for R5c/R5d. Each slice updates the
shared grammar, compiler, client, results and actual service callers together.

Extend the checked grammar and corpus, Zig compiler, typed direct client,
`transit-sql.DatabaseRuntime`, shared SQL service and result contracts together.
Implement the dedicated verbs from the delivery sequence only as their owner
passes its gate. Preserve contextual identifiers and prepared parameter typing;
do not classify commands by renderer-local SQL-text heuristics. The proposed
DDL examples also need rejection tests for unsupported schema, partitioning,
compaction and scheduling options.

Use M4's result lifecycle for `PRODUCE`/`ENQUEUE ... RETURNING`, bounded `CONSUME`,
`CLAIM` and metadata. A `CLAIM` result carries accepted mutation identity and
recoverable leased rows; transport retry or refetch cannot execute another claim.
Closing its result releases delivery buffers, not the accepted claim. Lost
production/settlement responses retain original operations. Cancellation racing
with completion cannot manufacture rejection or rollback.

Encode observed per-partition upper cuts, retained lower boundaries, next offsets,
group progress and lag as shared typed evidence. Keep fetched batches separate
from one logical result. A wait timeout may complete an explicitly empty bounded
observation; it does not complete an unbounded stream. Check current grants for
buffered rows, repeated batches, metadata, receipts and terminal counts.

M12 P4 now provides `BitemporalAndTvf.evaluateStreamSliceTvf`, a bounded
in-memory evaluator with offset/time filtering and unchanged-watermark tests.
Reuse that semantic coverage when integrating finite `STREAM_SLICE` with the
existing direct Fuze planner and retained Stream source reader. The evaluator
alone does not bind a catalog object, definition, retained cut or current grant,
and is not yet an executable SQL source. Define the adapter around the existing
Stream owner, preserving bounded pages and payload ownership; do not accumulate
the durable stream into the component's input array. M12 continues to own
continuous dataflows, while this package owns the finite SQL bridge. Carry row/batch limits, source attribution and early-close cleanup through
SQL native sessions, console, PostgreSQL and MySQL adapters. Select explicit
transport/type capabilities; unsupported Arrow/Flight or language combinations
must reject instead of silently narrowing data. SQL consumption and inspection
use the same public operations as typed callers.

**Exit gate:** shared corpus and actual service tests cover each supported verb,
empty/multi-batch results, result-memory limits, scratch-buffer reuse, early close,
revocation after buffering, disconnected claims and exact write recovery.

### R7 Replace Station turn and service persistence

Map behavior definitions and stable actor keys to declared inbox Queues, state
objects, journal Streams and outbox Queues. Register exact dependencies and
current grants explicitly. Idle actors need no permanently resident worker or
per-actor mailbox tree; names, retirement facts and durable accepted identities
still require paged persistence. Application handlers continue outside the node.

The runner claims a `key_fifo` input, acquires its declared transaction basis,
executes a detached handler and submits state changes, journal records, input
ACK and output intents to R5. Preserve private proposal ownership and poisoned
read/error handling. A handler exception or abandoned draft cannot leak writes;
define the durable failed/blocked disposition before automatic retry policy.
On uncertain commit, recover the original transaction before recomputation or
claiming successor work. A new worker must prove its activation and claim fences.

Move call correlations, original reply destinations, waits, durable timers,
registry rebinding and supervisor intent to declared data. Preserve authenticated
reply origins, late-reply closure, conditional stale cleanup, permanent retirement
and suspension/lifetime rules. A name or physical restart cannot revive retired
work or redirect an accepted call. Durable scheduling input must survive restart;
local futures and handler fields remain volatile.

Direct same-domain destination enqueue requires its current permission within
the common decision. If the application records an outbox intent for later
delivery, expose that separate admission boundary and blocked/denied destination
outcome. Never describe two independent commits as atomic inbox-to-inbox delivery.

**Exit gate:** real behaviors mutate Table and KV state beyond the native scalar
ceilings, settle inputs and publish outputs atomically; lost replies, worker
death, lease loss, handler failure, call timeout, registry replacement and
supervision recovery preserve original identities and no partial state.

### R8 Migrate effects and consumers and remove polling delivery

Run connector workers as authorized Queue consumers. A committed intent permits
only the connector's recorded attempt protocol; dispatch still requires current
destination/credential policy. Persist attempt and outcome/unknown/closure
evidence in declared state/journals. Replaying a journal never dispatches.
Queue redelivery cannot by itself authorize repeating a remote call whose outcome
is unknown. Preserve secret references and the current HTTP/gRPC capture and
closure contracts; MCP expansion remains with its later owner.

Replace query-host and delivery polling with bounded Queue waits and durable
notification positions. Register/recheck around sleep, recover once on activation,
and retain a durable discovery obligation if a bounded notification queue fills.
Notifications are wakeup hints; accepted Queue state remains authoritative.
Join waits on shutdown and test enqueue/commit races at registration, cancellation
and replacement. Measure idle requests/CPU and first-work latency.

Complete the inherited removal inventory across `transit-station`, private
Table/Query helpers, `transit-station-bindings.TableBridge`, foreign turn actions,
language SDKs, installed examples, controllers, launchers and Board interpretation.
Move retained query source/result metadata with its reader and authorization
checks; do not merely rename the private Table engine. Preserve the unrelated
catalog `DirectTableBridge`. Bindings continue to call shared Zig semantics.

Provide read-only public inspection of definitions, partition frontiers, group
lag, Queue counts/leases/retries/DLQ, original operations, transaction outcomes
and Station lifecycle. Counts carry their observation cut and exact/estimated
meaning. Board uses those public reads under a read-only grant, without claiming,
ACKing, decoding application values or exposing credentials.

**Exit gate:** run migrated installed example binaries and affected SDK consumers;
exercise connector unknown outcomes and replay with dispatch disabled. Remove
superseded writable engines, routes, ABI actions and courier executables/config
only when their consumers have moved. Ordinary database tests retain zero
Station sends/turns and direct imports remain acyclic.

### R9 Close the database write lifecycle and latency work

Continue [#211](https://github.com/spoke-sh/transit/issues/211) from the delivered
resident owners, foreground completion, bounded object publication groups and
event-driven recovery. M8 now also supplies batched allocation-inventory WAL
appends, one head-directory barrier per group, cross-tree `TreeStore.Batch`
staging and reduced duplicate statement validation/token lookups. Keep M3's installed recovery obligations and M8's
[gateway plan](08-gateway-architecture-and-protocol-ingress.md#work-packages-and-delivery-sequence)
as shared dependencies, with one owner per change.

- **Publication:** reuse the delivered bounded multi-object groups and shared
  candidate index staging. Preserve their dependency inventories, uncertain
  outcomes and disk recovery checks when integrating Stream/Queue writes. Extend
  physical models and disk fault tests before coalescing further barriers. Evaluate
  reconstructible indexes/accounting against accepted WAL evidence; never defer
  the sole copy of an accepted identity or expose an uncommitted descriptor.
- **Combined single-partition commit:** define the account-wide token routing and
  uniqueness fence before combining token binding, mutation and outcome. Concurrent
  use of the same token for another partition or operation kind must conflict or
  return the original winner. Recover the token index from authoritative evidence;
  preserve DDL/configuration/captured-operation identities that cannot join this
  fast path. The current separate Catalog acceptance/settlement boundaries remain
  until this replacement executes under a new definition.
- **Read-after-write:** remove avoidable fresh-cut/control work while preserving
  already-open results and exact uncertain pin acquisition. Use M8's co-hosted
  public owner boundary; no raw storage path in SQL.
- **TRUNCATE:** implement the [existing proposed contract](#proposed-truncate-contract-for-implementation)
  through Table intent, reset/history, authoritative counts, shared result kinds
  and grammar in one cutover. Cover empty Tables, retained predecessors, concurrent
  writes and retry after a later INSERT. Do not make it a Stream/Queue primitive
  or a prerequisite for R3/R4.

Use the existing installed persistent-console driver and independent typed
readback. Preserve the 190 ms then 19 ms INSERT objectives and 10–20 ms warm
SELECT objective with their matched workload and baseline. The newer
[batched-publication and validation measurements](../history/qualification/performance.md#batched-allocation-inventory-cross-tree-index-staging-and-sql-validation-trimming--2026-10-30)
record a 175-ms INSERT median over five samples and 36–40-ms warm SELECT medians,
plus a passing installed SQL gateway run. Subsequent
[pipelined writes and same-command metadata reuse](../history/qualification/performance.md#pipelined-batch-writes-cached-client-token-progress-deduplicated-operationbinding-claims-and-same-turn-sql-coordination--2026-10-30)
at `5c4081e95` record 29-ms warm empty/one-row SELECT medians, but a 925-ms
INSERT median and 599–732-ms post-write SELECT medians on the loaded shared
host. The recorded 193 crash schedules and gateway check pass at that revision;
the timings are not a matched before/after experiment and do not establish a
cause for the write variation. Neither the earlier favorable sample nor a
reduction in internal requests closes the latency gate. The 19-ms write and
10–20-ms warm-read targets, common-revision 190-ms write comparison, account-wide
token/commit composition and reconstructible bookkeeping remain open.
Report cold/fresh/warm reads, changed/unchanged/zero-match writes,
errors, startup and original-operation recovery separately. Attribute foreground
requests, background traffic, staging, syncs and final decisions without adding
instrumented timings into an invented end-to-end sample.

Table latency is the priority for optimization and the numeric performance gate.
Streams, Queues and Station require an initial measured baseline and recorded
resource budgets so later changes have a comparison basis; no absolute latency
or throughput target is selected for those owners yet. Baseline capture remains
required work, rather than an inferred pass from their correctness tests.

Start with these bounded workloads through the installed public callers, on the
local disk profile with unlimited retention. Freeze the exact configuration,
seed, warmup, sample count and correctness oracle with each report:

| Owner | Initial measurement workload | Required independent outcome checks |
| --- | --- | --- |
| Stream | Single-row and 128-row append with 128-byte payloads; finite consumption from a hot tail and after sealing/reopen; empty wait and publication wakeup | Exact payloads and offsets, original duplicate receipts, complete finite coverage and recovered consumer progress |
| Queue | Single-row and 128-row enqueue; claims of one and 16 rows with ACK; uniform 64-key and single-key FIFO workloads; delayed visibility and wait wakeup | Every accepted item accounted for, lease fencing, per-key ordering, no duplicate successful settlement and original outcomes after restart |
| Station | Current installed handler turn with one input, one 128-byte state value and one outbound intent; repeat the same logical workload on the replacement runtime when R7 lands | Atomic input/state/output publication, exact output count, original committed outcome after restart and no replay dispatch |

Use sequential samples first, with setup, warmup, measured operations and recovery
reported separately. Record all samples and report empirical p50; report p95 only
with at least 20 successful samples and p99 only with at least 100. A failed or
uncertain operation fails that measurement run and retains its original recovery
evidence; it must not disappear from the denominator. Sequential completed work
per elapsed second is not saturated throughput. Follow it with explicitly offered
load and worker-count profiles, retaining admitted, refused, completed and unknown
counts as well as generator delay. Keep payload rows/s separate from calls/s and
completed turns/s.

Record latency distributions, allocation attempts/bytes after warmup, peak
resident memory, storage bytes/IOPS and amplification with the source, toolchain,
binary/driver hashes, CPU, filesystem, cache conditions and background load.
Record configured resident/cache/lease/waiter budgets separately from measured
use. Missing counters remain unmeasured, never zero. Do not run timing comparisons
alongside heavy builds or durability proofs. The existing
[offered-load runner](../../tests/performance/load/growing_load.py) reports native
admission and aggregate drain costs; it does not yet measure Station handler-turn
latency. Its results cannot fill that baseline row. The initial baseline report
must identify any missing workload or instrumentation before freezing regression
budgets; this plan itself records no measurements.

After the baseline, extend coverage to contended claims, larger payloads, delayed
backlogs, cold storage, and transactional turns with values above 256 bytes and
more than four keys. Compare the common workload across the runtime cutover and
report newly supported larger turns separately. Do not claim global fastest,
O(1) recovery or one-WAL-write multi-object turns from component timings.

**Exit gate:** matched installed evidence meets the selected targets without
weaker durability, raised deadlines, silent incomplete outcomes or reclassified
failures. Any unmet original gate remains explicitly open in M6 and its owning
tracker; completion requires an explicit scope change rather than a new label.

### R10 Qualify and complete the current-v1 cutover

Plan each incompatible merge as one current-v1 definition replacement. Inventory
native messages, persistent roots, `.tseg`/`.tdel`/`.tack`, manifests, saved
requests, Station journals, ABI/port messages, generated schemas, signing fixtures,
configuration and installed examples. Regenerate from public types and migrate
all affected consumers together. Missing/foreign definitions reject before
execution; never default old artifacts to the current definition or reset them.
Preserve incompatible installations with their matching build; any explicit
offline migration needs its own contract and evidence, without a fallback decoder
or parallel writable runtime in the new build.

The acceptance matrix must include real callers as well as component tests:

| Boundary | Required executable evidence |
| --- | --- |
| Declarations and policy | Create/alter/rename/drop, lost publication reply, dependency races, revoked metadata and payload reads, denied DLQ and fenced replacement |
| Producer and consumer progress | Duplicate/conflicting sequences, racing producers, group reassignment, filtered coverage, compacted/expired gaps, and monotonic original checkpoint recovery |
| Physical data | WAL-only tails, flush/sidecar/checkpoint/trim crossings, corrupt or missing accepted objects, process death and injected disk write/sync errors |
| Queue authority | Duplicate claim selection, forged/foreign receipt, expiry without reassignment, renewal races, expired worker ACK/turn, FIFO delays, unrelated-key progress and blocked DLQ |
| Transactions | Partial preparation, unknown decision, crash after commit before finalization, revocation, savepoints, append reservations and all-or-none state/input/output visibility |
| Results and cancellation | Empty and multi-batch results, owned values across scratch reset, early close, incomplete prefixes, lost mutating result and revocation before terminal disclosure |
| Runtime and effects | Detached handler failure, replacement, durable calls/timers/supervision, retirement, no replay dispatch and retained unknown external outcomes |
| Resources and progress | Durable collections larger than every cache, active-work refusal, far-future timers, clock jumps, control reserve, bounded cleanup and zero missed wakeups under saturation |
| Installed surfaces | Public Zig, shared SQL/console, PostgreSQL/MySQL, all affected existing ABI/SDK examples, Board read-only evidence and launcher restart without courier polling |
| Compatibility | Foreign/missing definitions in peers, files and saved operations; no legacy route or writable private Table engine; no restored identity revival |

Register new Stream/Queue/participant/Station suites in the existing test inventory
as their code lands, with real failing assertions rather than placeholder tasks.
Use the existing `queue-lease-transaction-model`, `local-storage-faults`,
`storage-io-faults`, `sql-transactions`, `station` and `console-latency` tasks as
regression owners. Add concrete model replay and independent oracles for the new
owners. Run affected committed-source clean lanes for contracts/core, formal,
growth, interfaces, runtime experience, bindings, browser and launchers; combined
milestone qualification uses one committed revision and matching binaries.
Local disk is the new primitive baseline. Existing supported Ursula and
Kubernetes/Substrate authority/readiness/recovery profiles must still pass their
applicable migration gates; new distributed Stream/Queue guarantees remain gated
by their provider owners. Process kill is not proof of power-loss durability.

Promote each delivered capability and its exact limits into the data model,
streams, state, Station, SQL grammar inventory, callers, retention, security,
storage and inspection owners. Put mechanisms in the corresponding Internals
topics and component guides. Record commands, revision, configuration, raw
evidence, failures and omissions in qualification history. Close the inherited
checkboxes and link their evidence; change this milestone and the roadmap index
to **Completed** only when R0–R10 and the applicable completion criteria agree.

### First implementation changes

#### Review baseline after PR #303 — 2026-11-01

This is the proposed completion plan from merge `997fbfda9`, whose PR head was
`5ccf1493e`. It supersedes the earlier next-change ordering, while R0–R10
remain the acceptance-scope owners. The dated baseline and qualification
records above retain their original source attribution.

The database-owned KV lifecycle, native Table/KV/Stream/Queue transaction
participants, explicit paired DLQ transfers, and Stream/Queue declaration and
inspection SQL are delivered code. Extend and qualify these owners; do not
reimplement them. Workload SQL, automatic DLQ scheduling and the replacement
Station runtime are still missing.

The [PR-head formal job](https://github.com/spoke-sh/transit/actions/runs/41281486165/job/124774306697)
failed compiling the transaction-workspace replay adapter: it accesses
`head.pending` as the old state-only request instead of the current
`StatementWork` union. The adapter must use the shared statement accessor,
then prove both state and log work. Other clean runs were incomplete when this
plan was prepared; their eventual results must be inspected before claiming
a combined-source pass. Merge status is not qualification.

The unfinished Stream/Queue baseline prototype was excluded from PR #303.
Review its ownership, independent oracle and registration before reusing it.
It supplies neither an executed measurement nor the missing Station-turn baseline.

#### Review decisions and scope

| Decision | Proposed implementation rule |
| --- | --- |
| Initial execution domain | Keep the local disk-backed catalog/branch-one transaction domain and explicit logical partitions. Preserve main's Table-branch behavior. Distributed assignments and remote atomic commit remain with their provider owners. |
| Existing data owners | Reuse `DirectCatalog`, `KVPartition`, `StreamPartition`, `QueuePartition`, and the existing transaction workspace/decision log. Add no Station coordination to database admission, tokens, reads or transactions. |
| Workload operation identity | Freeze exact target definition, canonical request and payload before account/client-token acceptance. Persist actual owner completion, rejection or cancellation evidence; absence of a receipt stays uncertain. |
| Row-returning mutations | Extend the shared result lifecycle with an authorized reference from the original operation to its retained result. Refetching `CLAIM` or `RETURNING` must never execute another mutation or renew a lease. |
| Consumer progress | SQL offset settlement must bind authenticated completed coverage and the original group generation. A numeric requested offset alone cannot manufacture that evidence. |
| Station activation | Prepare replacement modules and consumer changes behind unexposed interfaces, then activate them in one coordinated current-v1 cutover. Do not publish parallel writable runtimes or compatibility decoders. |
| Document participation | M7 owns its catalog/participant implementation. Prove Table/KV turns first; enable Document turns only after the same decision/recovery gate. Record this dependency without creating a second coordinator or waiving inherited Document migration obligations. |
| Performance | Table retains the numeric latency gate. Capture measured Stream, Queue and Station budgets without inventing absolute targets. Measure the current Station workload before removing its runtime. |
| External effects | Atomic outbox publication does not make a remote call atomic. Preserve recorded attempts, unknown outcomes, credential references and connector-specific retry decisions. |

The proposed sequence below describes reviewable delivery batches, not calendar
estimates. Each batch may contain several scoped commits, but protocol changes,
their generated consumers and their acceptance tests must form a coherent
review unit. All acceptance checks below are planned work.

| Batch | R owners | Prerequisite | Reviewable outcome |
| --- | --- | --- | --- |
| 0. Restore qualification | R0/R10 | Merged PR #303 | Correct model adapter and an attributed baseline for the merged implementation |
| 1. Capture initial budgets | R9 | Batch 0 for each measured owner | Table reference run and Stream/Queue/current-Station baseline reports |
| 2. Finish transaction and DLQ gates | R0/R4/R5 | Batch 0 | Qualified mixed decisions and bounded automatic DLQ scheduling |
| 3. Define workload outcomes/results | R0/R6 | Batch 0; reuse Batch 2 decision semantics | Shared durable operation outcomes, result recovery and cancellation rules |
| 4. Deliver workload SQL and finite reads | R3/R6 | Batch 3; Batch 2 for mixed SQL | Stream/Queue verbs, retained `STREAM_SLICE`, mixed SQL transactions |
| 5. Implement transactional Station turns | R0/R7 | Batch 2; Batch 1 current-turn capture | Real handlers compose input, state, journal and output in a standard transaction |
| 6. Migrate Station services | R7 | Batch 5 | Durable calls, timers, names and supervision on declared data |
| 7. Activate consumers and remove old delivery | R8 | Batches 5–6 and affected owner gates | Coordinated SDK/effect/launcher cutover with courier removal |
| 8. Close Table write and latency work | R9 with M3/M8 | Start after Batch 0; measure against Batch 1 | Account-wide token/commit composition, TRUNCATE and matched latency evidence |
| 9. Qualify the milestone | R0–R10 | All applicable preceding gates | One revision with the complete caller, fault, resource and compatibility matrix |

Batches 1, 2, 3 and the design work in 8 can progress independently after their
baseline gates. Station uses typed database callers and does not wait for SQL
syntax. SQL does not wait for Station. The runtime dependency chain is
**0 → 2 → 5 → 6 → 7 → 9**; the SQL chain is **0 → 3 → 4 → 9**.
Batches 1 and 8 also gate 9. Measure benchmarks separately from heavy builds and
fault suites even when their implementation work overlaps.

#### Batch 0 — restore and attribute the regression baseline

**Owners:** the transaction workspace model/replay adapter, existing verification
inventory, catalog/storage checks and installed caller drivers.

1. Correct `tests/verification/models/transaction_workspace_state.zig` to use
   `StatementWork.statement()`. Audit the rest of the replay adapter for old
   state-only assumptions. Preserve every existing invariant and negative control.
2. Add a log-statement replay schedule that actually exercises the new union
   branch, shared statement sequence, pending slot and savepoint behavior.
   A compile-only change does not establish mixed-participant correspondence.
3. Join the outstanding local/CI runs, retain their raw failures and diagnose
   each failure separately. Run focused owner checks before repeating their
   affected clean lanes on committed source.
4. Re-run the installed `kv`, `state-transaction`, `mixed-transaction`,
   `queue-transfer` and `log-token` profiles, plus SQL log declarations,
   against matching node/client/service binaries. Preserve main's branch,
   Document, wire-session and worker-replacement checks.
5. Record revision, definition, binary hashes, commands and omissions in the
   owning qualification records. Reconcile stale current-status prose without
   relabeling older evidence.

**Commit sequence:** `test(models): adapt transaction workspace replay`;
`test(transactions): replay state and log workspace transitions`;
`docs(qualification): record combined-source regression evidence`.

**Exit:** the known formal compilation failure is resolved; required baseline
checks pass or have an explicitly diagnosed outstanding defect that blocks
only dependent work. No failed, skipped or incomplete check counts as a pass.

#### Batch 1 — capture budgets before changing the runtime

**Owners:** existing installed performance drivers, `tests/performance`, shared
public clients, and the performance qualification record.

1. Freeze the Table workload, durability, source/driver binaries, hardware,
   cache conditions and comparison method used for the 190-ms/19-ms write and
   10–20-ms warm-read gates. Report fresh, warm and post-write reads separately.
2. Turn the excluded Stream/Queue prototype into a bounded registered harness.
   Verify the canonical request is saved before dispatch, buffers do not outlive
   their owner, and an independent readback oracle accounts for every accepted
   row, offset, claim and settlement after restart.
3. Capture Stream single-row/128-row appends with 128-byte payloads; finite hot
   tail and sealed/reopened reads; empty waits and publication wakeups.
4. Capture Queue single-row/128-row enqueues, claims of one and 16 rows with ACK,
   competing and FIFO work across 64 keys and one hot key, delayed visibility
   and wait wakeups. Include lease expiry and original-outcome recovery checks.
5. Add a real installed Station handler driver: one input, one 128-byte state
   value and one outbound intent. Preserve the exact logical workload for
   comparison with Batch 5. Native admission/drain throughput is not turn latency.
6. Report successful, refused, failed and unknown counts; all raw samples;
   p50 and sample-supported p95/p99; post-warmup allocation attempts/bytes;
   peak resident memory; storage bytes/IOPS; and configured cache, lease, waiter
   and active-work budgets. Unsupported instrumentation is marked unmeasured.
   Start sequentially, then use explicit offered-load and worker-count profiles.

**Commit sequence:** `test(performance): qualify stream and queue baseline driver`;
`test(performance): measure installed Station handler turns`;
`docs(performance): record baseline workloads and resource budgets`.

**Exit:** reproducible reports exist for all four owners with independent
correctness checks. Use at least 20 successful samples to report p95 and 100 for
p99. A failed or uncertain measured operation fails that run; it cannot disappear
from the denominator. Choose regression thresholds from the measurements and
declared budget policy, not from guessed throughput.

#### Batch 2 — qualify mixed decisions and automate DLQ transfers

**Owners:** `transit-protocol.Transaction`, `DirectTransaction*`, the shared
decision log/workspace, Stream/Queue preparation and retained-root traversal.

1. Extend model correspondence and deterministic/disk fault schedules across
   state preparation, log reservation, each participant barrier, decision
   append, lost decision reply and each finalization/cleanup boundary.
2. Exercise Table+KV mutations, Stream+Queue outputs and Queue ACK/Stream offset
   settlement together. Check savepoint rollback, abort, missing-key conflicts,
   stale definitions, revocation between prepare and decision, final lease
   expiry without reassignment, and duplicate/conflicting operation reuse.
3. Verify accepted preparations, pins, payloads and original receipts survive
   trim/collection and resident-cache eviction. Saturate ordinary work while
   preserving bounded decision, settlement and recovery progress.
4. Add bounded automatic DLQ discovery to the existing Queue maintenance owner.
   Persist the original transfer attempt and exact destination before dispatch;
   recover that attempt before selecting fresh work after replacement.
5. Route automatic transfers through the existing paired transaction statement.
   Recheck current source/destination authority at the common decision.
   Denied, retired, changed or capacity-blocked destinations leave inspectable
   retained work; they do not authorize source archival or fresh retries.
6. Test crash/retry during discovery, admission, preparation, decision and
   cleanup; multiple maintenance workers; policy edits after exhaustion;
   unavailable destinations; and retained source/destination payload reachability.

**Commit sequence:** `test(transactions): qualify mixed participant fault boundaries`;
`feat(queue): recover automatic dead-letter transfer attempts`;
`test(queue): qualify scheduled dead-letter transfer recovery`.

**Exit:** one original decision publishes all state/output/settlement effects;
abort publishes none. Recovery after decision does not rerun a handler. Automatic
DLQ cannot mark a source terminal without the matching destination publication.
The installed proof passes at bounded memory and normal configured deadlines.

#### Batch 3 — define durable workload outcomes and result recovery

**Owners:** Stream/Queue mutation owners, `DirectIntent`/`DirectClientToken`,
`transit-sql-protocol`, `transit-sql-results`, SQL service/client and adapters.
Update [Stream](../../contracts/STREAM_V1.md), [Queue](../../contracts/QUEUE_V1.md),
[direct operations](../../contracts/DIRECT_TABLE_V1.md),
[SQL sessions](../../contracts/SQL_SESSION_V1.md) and
[logical results](../../contracts/SQL_RESULTS_V1.md) before exposing new verbs.

The current Stream/Queue operation lookup returns an optional success receipt;
it does not supply all durable rejection/cancellation outcomes required by SQL
token settlement. SQL's operation-result reopen path currently accepts captured
results, and shared-client settlement returns a command completion. These are
specific implementation prerequisites, not reasons to introduce another result
protocol.

1. Define and implement immutable workload intent references and terminal owner
   evidence. Separate token reservation, owner acceptance, owner outcome and
   authorized disclosure. A changed request cannot reuse an original identity.
2. Persist pre-dispatch cancellation/refusal evidence where the operation
   contract permits it, fencing late admission through every native route.
   After acceptance, cancellation follows the owning operation's semantics;
   it never infers rollback from an absent receipt or a stopped wait.
3. Add a typed original-operation-to-result reference for append/enqueue
   `RETURNING` and original claim rows. Bind object/definition, schema,
   original operation, retained selection, result limits and current rights.
   Result delivery state remains separate from durable mutation completion.
4. Extend service reopen, shared `Executor` settlement, result consumption and
   protocol adapters together. Closing a claim result releases delivery
   resources; it does not ACK, undo, renew or repeat the claim.
5. Define coverage/continuation metadata for finite consumption and a durable,
   authenticated handoff to offset settlement. Specify group ownership,
   expired retained results and unavailable-history refusals.
6. Regenerate neutral schemas, fixtures, ABI/binding resources and consumers
   under a new current-v1 definition wherever semantics are incompatible.

**Commit sequence:** contract/types and independent fixtures; catalog workload
intent/outcome implementation; shared operation-result recovery and consumers.
Keep the breaking definition change and all affected consumers together.

**Exit:** the original result can be recovered after lost mutation replies and
service replacement without reexecution. Test cancellation/admission races,
lease expiry before refetch, revocation after buffering, early close, complete
empty results, multi-batch ownership and missing terminal evidence. No SQL token
is settled from transport success, a missing receipt or a renderer text heuristic.

#### Batch 4 — deliver workload SQL in four reviewable slices

**Owners:** checked grammar/diagnostics, Fuze compiler and source adapters,
`transit-sql`, shared SQL service/client, native/console/PostgreSQL/MySQL callers.

| Slice | Implementation | Required proof |
| --- | --- | --- |
| Stream verbs | Compile/bind `PRODUCE`, positional/group `CONSUME`, bounded `WAIT` and `COMMIT OFFSET` to shared owners. Preserve producer identity, partition routing, parameter types and authenticated progress. | Duplicate/conflicting producers; hot/sealed/reopened reads; filtered coverage and compaction gaps; assignment fencing; original offset recovery; Arrow batch-ingress capability and limits |
| Queue verbs | Compile/bind `ENQUEUE`, `CLAIM ... WITH LEASE`, `ACK`, `NACK` and `EXTEND LEASE`, including delays and bounded waits. Carry exact original receipt/lease identity through typed SQL values. | Disconnected claim recovery; expiry/renewal races; same-key FIFO and unrelated-key progress; empty wait versus accepted claim; no implicit ACK or lease extension on result close/refetch |
| Finite analytical bridge | Bind `STREAM_SLICE` to exact catalog definition, retained offset/time cut and Fuze's bounded source reader; reuse the existing TVF semantic tests. Integrate projections, predicates and finite joins without loading the whole Stream. | No consumer-watermark changes; correct time boundaries and tombstones/gaps; pin protection during compaction; early close; current authorization; stable source attribution across batches |
| Mixed SQL | Lower Stream/Queue append and settlement statements through the existing transaction workspace and controls. Keep claim acquisition separate from the later transactional ACK. Preserve provisional statement attribution and original commit/abort identity. | State+output+settlement all-or-none visibility; savepoint rollback; disconnect/reattach; uncertain COMMIT; stale lease/refused decision; no partial publication on cancellation |

Each slice includes compiler/corpus diagnostics, typed shared client support,
actual installed native/console/PostgreSQL/MySQL execution, public references
and exact unsupported capability checks. Do not expand Flight or language API
claims without qualifying the relevant transport/type combinations.

**Commit boundaries:** one compiler/owner integration plus its caller/fault
proof per slice. Result-protocol work belongs in Batch 3 and is reused here.

**Exit:** each supported verb works through real callers and preserves the
existing result lifecycle, memory limits and authority checks. Parser acceptance
and the in-memory TVF evaluator alone do not satisfy this gate.

#### Batch 5 — implement one real transactional Station behavior

**Owners:** `transit-station`, its shared bindings, declared lifecycle records,
the existing data client and transaction owner. Define the replacement in the
[Station contract](../../contracts/STATION_V1.md) and
[state boundary](../../contracts/STATE_V1.md) before wiring the runner.

1. Define behavior/actor identity, declared inbox/state/journal/outbox references,
   exact dependencies, current grants, activation ownership and retention roots.
   Use paged durable directories; idle actors need no resident worker.
2. Claim an inbox item under `key_fifo`, freeze its transaction basis, run the
   detached handler, and stage Table/KV changes, journal entries, outgoing
   Stream/Queue work and input ACK through the standard transaction API.
3. Bind the proposed turn to both activation ownership and the exact input lease.
   Preserve read/conflict guards and final-time checks. Separate scratch arenas
   from retained proposals; bound active handlers, read sets and output bytes.
4. Persist enough original transaction identity before uncertain submission to
   recover its decision before recomputing or claiming successor work. Private
   drafts, poisoned reads and handler exceptions publish no partial data.
5. Define inspectable failed/blocked dispositions and recovery policy for
   abandoned drafts. Maintain original destinations and permanent retirement.
6. Run the Batch 1 logical turn workload, then a separate workload with values
   above 256 bytes and more than four mutations. Integrate Document state only
   through M7's qualified participant and explicit dependency gate.

**Commit sequence:** replacement runtime contracts and fixtures; declared
actor-state/inbox ownership; transactional runner and recovery; installed
behavior and resource/fault proofs. Keep replacement activation unexposed until
the consumer cutover in Batch 7; preparation commits add no parallel public runtime.

**Exit:** a real handler's input settlement, state and outputs share one decision.
Worker death before/after that decision, lease loss, stale activation, handler
failure, revocation and restart preserve original outcomes and at most one
committed output set. Measure the replacement turn against the saved baseline.

#### Batch 6 — migrate durable Station services

**Owners:** Station calls/replies, registries, timers, supervision, runtime
controllers and their shared ABI records.

| Service | Migration requirement | Acceptance cases |
| --- | --- | --- |
| Calls and replies | Persist correlations, authenticated origins, original reply destinations, waits and closure in declared objects | Caller/worker replacement, late reply, timeout/completion race, cancellation of a local await, duplicate delivery |
| Timers and waits | Record timer identity and scheduled input; use bounded Queue scheduling/waits with a durable recovery obligation | Clock jumps, restart, duplicate wakeup, registration/enqueue race, full notification buffer, joined shutdown |
| Names and lifecycle | Conditional durable binding/rebinding, explicit lookup rights, suspension and permanent retirement | Rebinding cannot redirect accepted calls; stale cleanup cannot remove a new binding; restored state cannot revive retired work |
| Supervision | Durable child intent and outcomes, with providers restricted to physical lifecycle | Lost spawn/stop reply, controller replacement, denied activation, capacity blockage and no child resurrection |

**Commit boundaries:** calls/replies; timers/waits; registry/lifecycle;
supervision/controller adaptation; one installed combined recovery proof.

**Exit:** all existing service guarantees survive worker and controller
replacement using declared data. Local futures, timer heaps, names and provider
observations remain non-authoritative.

#### Batch 7 — migrate effects and consumers, then activate the cutover

**Owners:** connector dispatch, Station bindings/SDKs, private Table/Query helpers,
query-host, controllers, launchers, installed examples and Board public reads.

1. Build an explicit removal inventory naming each superseded writable engine,
   ABI action, executable/configuration entry and its replacement consumer.
   Preserve the unrelated catalog `DirectTableBridge`.
2. Move effect intents/attempts/outcomes to declared Queues/state/journals.
   Recheck destination and credential policy at dispatch. Retain unknown remote
   outcomes and connector-specific closure; replay must never dispatch.
3. Migrate retained query source/result metadata with its original reader,
   interpretation, pins and current authorization. Migrate all affected existing
   language bindings through shared Zig semantics and run actual example binaries.
4. Replace courier and runtime polling with bounded waits plus durable recovery
   discovery. Notifications are hints; saturation cannot lose accepted work.
   Measure idle requests/CPU and first-work latency; join waits on shutdown.
5. Expose definitions, original operations, group lag, Queue leases/retries/DLQ
   and Station outcomes through public read-only inspection. Label count basis
   and exact/estimated meaning. Board must not claim, ACK or decode application
   values.
6. Activate the replacement and remove superseded paths in one current-v1
   integration cutover. Regenerate contracts/ABI/resources/fixtures and update
   installed examples/configuration together. Reject incompatible peers and
   saved artifacts; preserve old installations with their matching build rather
   than introducing a fallback decoder or resetting accepted data.

**Commit boundaries:** effect worker migration; Table/Query consumer migration;
bindings/examples and operator reads; coordinated activation/removal and
installation fixtures. The activation PR contains every required dependent commit.

**Exit:** existing supported consumers work through the replacement owners.
Replay has dispatch disabled, unknown effects remain unknown, old writable
engines/routes/courier entries are gone, and ordinary database operations still
perform zero Station turns. Requalify applicable Ursula and Substrate
authority/readiness/recovery behavior without claiming new distributed guarantees.

#### Batch 8 — close Table commit composition and latency

**Owners:** `DirectCatalog`, account/token binding, `TablePartition`, transaction
publication and M8's co-hosted SQL boundary. Begin the design and measurement
work after Batch 0; do not defer it until the Station cutover.

1. Specify and model the authoritative account-wide token uniqueness/routing
   fence before changing the commit envelope. Concurrent reuse across partitions,
   object kinds, statements and reconnects must conflict or recover one winner.
2. Combine eligible single-partition token identity, mutation and original
   outcome in the authoritative WAL commit. Keep non-joining DDL/configuration
   operations explicit. Reconstruct accelerative token/accounting indexes from
   accepted evidence; never defer the only durable copy of an accepted identity.
3. Reuse bounded publication groups and staging. Remove redundant control,
   validation and fresh-cut work on the co-hosted path without bypassing public
   ownership or invalidating open readers. Prove lost replies and read-pin
   uncertainty before treating the reduced path as qualified.
4. Implement the existing proposed `TRUNCATE` contract through Table intent,
   reset/history, exact counts, grammar and shared command results in one
   coherent change. Test empty Tables, retained predecessors, concurrent writes
   and original retry after a later INSERT.
5. Repeat Batch 1's matched Table workload after each material change. Attribute
   statement work separately from background maintenance; retain all errors and
   cold/fresh/warm/post-write samples. Repeat Stream/Queue/Station baselines after
   integration and publish any regressions.

**Commit sequence:** token-routing model and contract; combined WAL publication
and reconstruction; read-after-write path; TRUNCATE; matched qualification.

**Exit:** prove original account/token identity and one eligible partition commit,
then meet the 19-ms INSERT and 10–20-ms warm SELECT objectives with the matched
190-ms comparison retained. Lower request counts, unmatched timings or weaker
durability cannot close this gate. An unresolved routing/performance constraint
remains visible work rather than being moved to a later milestone.

#### Batch 9 — run one-revision completion qualification

Freeze one committed revision and matching generated definitions/binaries after
all preceding applicable gates. Execute the full [R10 matrix](#r10-qualify-and-complete-the-current-v1-cutover),
including previously supported provider profiles, not just the new happy paths.

- Model/implementation correspondence: Stream producer/progress, multi-key Queue
  leases/DLQ and mixed/runtime decisions, with guard-removal negative controls.
- Physical/resource behavior: tails, sealing, sidecars, checkpoint/trim, corrupt
  or missing accepted objects, injected write/sync faults, larger-than-cache
  collections, allocation bounds, timer/wait saturation and control reserve.
- Installed behavior: typed Zig, native SQL, console, PostgreSQL/MySQL, affected
  SDK/ABI consumers, examples, connectors, Board and launcher replacement.
- Compatibility and authority: missing/foreign definitions, revoked reads after
  buffering, retired actors, expired leases, denied destinations and preserved
  original outcomes.
- Performance: matched Table targets and all required baseline reports, with
  measured budgets and explicitly reported missing counters.

Use existing registered commands while adding each missing proof to its owner:
`just test::transaction-workspace-model`,
`just test::queue-lease-transaction-model`, `just test::catalog`,
`just test::direct-table-service kv`,
`just test::direct-table-service state-transaction`,
`just test::direct-table-service mixed-transaction`,
`just test::direct-table-service queue-transfer`,
`just test::direct-table-service log-token`,
`just test::sql-log-declarations`, `just test::sql-transactions`,
`just test::local-storage-faults`, `just test::storage-io-faults`,
`just test::station` and `just test::console-latency`.
These are starting regression owners, not substitutes for the additional
workload SQL, runtime, fault and measurement coverage specified above.

Run selected committed-source `just ci clean --lane NAME` checks before each
implementation push. For final qualification, run the full inventory selected
by the repository CI tooling, including native build profiles and every affected
core, storage/query, formal, interface, SDK, browser, installation and launcher
lane. Do not silently replace a failed schedule with an easier one.

**Final review artifacts:** a capability/consumer migration inventory; contract
definition and generated-artifact inventory; per-gate source-attributed raw
evidence; Table comparisons and Stream/Queue/Station budget reports; and public
reference/component documentation for every supported behavior and refusal.

**Exit:** no required capability, consumer migration, failure schedule or
performance gate remains open. Update the milestone and roadmap index to
`Completed` together only after the evidence satisfies R0–R10. Documentation
checks on this plan establish no runtime or performance result.

### First foundation slice

The first implementation PR supplies three independently usable foundations,
with [scoped qualification](../history/qualification/verification.md#stream-and-queue-contract-and-bitmap-foundations--2026-10-29):

- `transit-protocol.StreamQueue` and the [Stream](../../contracts/STREAM_V1.md)
  and [Queue](../../contracts/QUEUE_V1.md) contracts define original append and
  settlement identities, logical offsets separate from WAL positions, finite
  filtered coverage, group checkpoint fencing and live-lease checks. Reflected
  schemas and independent full-width fixtures move with those types. Exact
  accepted settlement recovery remains distinct from fresh lease authorization.
- The finite Queue model now covers two keys, authoritative time before
  reassignment, revocation between preparation and decision, derived-cache
  replacement, retained-history protection and DLQ payload reachability, with
  nine negative controls. It assumes atomic accepted state and adds no runtime
  correspondence or physical durability evidence.
- [`transit-bitmap`](../../packages/zig/transit-bitmap/README.md) supplies bounded
  Roaring array/bitmap/run containers, canonical validation, borrowed reads and
  reusable allocation-free mutation scratch. Its standalone manifest and root
  component checks qualify the library independently of a storage owner.

At that first foundation's source revision, R0 remained open for complete declarations, partition/hash/schema policy,
producer/group/claim owner transitions, direct KV and generalized participant
preparation. R1 remained open for the paged container directory, coordinated
`.tdel` cutover, `.tack` envelopes, partition initialization, tail slabs and disk
publication/recovery. That slice left `.tdel` bytes and native execution semantics
unchanged; it did not use the new container codec to reinterpret stored data.
Neither foundation enables Stream/Queue SQL, claims, transaction participants
or a Station migration. Subsequent delivery and current remaining work are
tracked in [work packages and dependencies](#work-packages-and-dependencies).

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
  [SDK coverage](21-service-and-sdk-coverage.md) expose idiomatic `PRODUCE`,
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
- [Storage providers](23-storage-providers-and-concurrency.md),
  [replication](24-replication-and-failover.md) and
  [clustered execution](26-clustered-execution.md) extend partitioned Stream/Queue
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
  committed output intents or external `courier` polling. External attempts retain
  their connector-specific unknown-outcome and retry policy; Queue redelivery
  does not establish exactly-once remote effects.

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
combined single-partition commit. Startup and recovery-triggered pending scans,
separate Catalog acceptance/settlement, cold snapshot replacement and first-publication work still
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
