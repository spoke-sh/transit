# 6. Declarative streams, queues and durable runtime architecture

[Roadmap](README.md) · [Foundation #125](https://github.com/spoke-sh/transit/issues/125) · [Feeds #127](https://github.com/spoke-sh/transit/issues/127) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Decouple the database (`DirectCatalog`, `TablePartition`, `KV`, `Document`,
`transit-query` and `transit-sql`) completely from the `Station` durable actor
runtime, elevate **Streams** (`STREAM`) and **Queues** (`QUEUE`) to first-class
declarative database primitives with dedicated SQL and typed-caller grammar over
`TransitLog` (`TWAL1`) and `.tseg` segments, and re-architect `Station` on top
of those database primitives and [supported transactions](05-transactions-and-atomic-composition.md).

The [current completion plan](#first-implementation-changes), refreshed on
2026-11-05 from `origin/main` at `c4dd89c22`, sequences the remaining contracts,
caller operations, transaction qualification, Station cutover and performance
work. Start there for the source assessment, milestone handoffs, review boundaries
and acceptance gates. The shared SQL wait contract and unfiltered Queue WAIT
(4b.2) and bounded SQL Stream WAIT (4a.2) are implemented in the follow-ups
below. The [Stream WAIT slice plan](#next-slice-sql-stream-wait-4a2--2026-11-05)
records its source basis at merged PR #386; grouped Stream consumption and offset settlement (4a.1),
NACK and original renewal results remain regression inputs.
The [earlier source audit](#source-baseline-and-remaining-gaps) and dated progress
records preserve their original attribution. Delivery-sequence SQL examples
below illustrate proposed scope; use the [SQL reference](../handbook/reference/sql/streaming.md)
for the current executable declarations, workload operations and inspection forms.

## Explicit SQL Stream groups and offset settlement — 2026-11-03

This implementation delivers Batch 3's grouped progress handoff
and **4a.1** over the existing native assignment, read and settlement owners.
`CONSUME ... GROUP` binds an explicit binary native assignment and starts at its
checkpoint; predicates filter output without skipping input progress. Grouped
completion retains the authenticated initial/final boundaries, including partial
LIMITs and empty results. `COMMIT OFFSET ON STREAM ... RECEIPT` submits that
progress through the existing original-token lifecycle. Fresh stale assignments,
checkpoint conflicts, released reads and forged cursor MACs receive recorded
native refusals; recovery retains the original accepted identity.

The [public SQL profile](../handbook/reference/sql/streaming.md#consume-and-settle-an-assigned-group)
and [Stream contract](../../contracts/STREAM_V1.md#sql-assignment-and-progress-descriptors)
own executable syntax and limits. PostgreSQL, MySQL and the console accept the
same binary descriptors, while the native SQL result API supplies authenticated
completion metadata. SQL does not create or rebalance assignments, infer progress
from row counts, release a read pin on result close, or silently commit progress.
The current-v1 definition changes to
`037c68077dfd548bbd03c09ee4ae0ccf1f3b7a58d1e496a877ae61b55599fcdf`;
generated consumers and independent fixtures move with it.

The 2026-11-04 rebase onto `origin/main` at `b94462388` preserves M7's
retained Document collection cuts, M8's co-hosted SQL lane coordination, M12's
catalog-owned progress and original staging/closure, and Board's bounded workbook
relations. The combined definition covers Stream descriptors, Document collection
coverage, the mandatory nullable candidate slot and `CPR1` progress envelope,
and `SOR1` original ownership.
Later Station work can reuse these reservation/readiness, attachment, closure and
collection contracts where applicable. The original source assessment below and
earlier qualification results retain their recorded revisions; they do not
qualify this rebased source. Continuous Stream activation, SQL WAIT and
transactional Station remain separate work.

The [qualification record](../history/qualification/query.md#sql-stream-groups-and-authenticated-offsets--2026-11-03)
attributes the completed checks and earlier failed attempts to their tested
revisions and distinguishes this slice from the remaining milestone gates.

This section supersedes the older dated next-step descriptions for 4a.1 below.
M6 remains **In Progress**. Stream/Queue waits, payload acquisition predicates,
finite `STREAM_SLICE`, mixed SQL, transactional Station, the M7 handoff and the
remaining maintenance, resource, performance and common-revision qualification
gates retain their existing owners and acceptance criteria.

## Original renewal results and SQL admission — 2026-11-02

The implementation following the `edeb8618c` completion plan supplies Batch
4b.1's original-renewal result contract. A native `renewal` selection binds the
accepted settlement and delivers one exact updated lease descriptor. SQL
`EXTEND LEASE` freezes a descriptor-only projection and returns one binary
`_receipt_handle` row through M4's result lifecycle, M8's database admission and
M9's shared caller. ACK/NACK retain command completion. This uses the current-v1
cutover definition
`fa88766ac95f2c156474b0c97eb9eaafcccc8c13a70009e574d09397d7ba3c72`;
all generated schemas, bindings and independent fixtures move together.
The [SQL reference](../handbook/reference/sql/streaming.md#renew-a-queue-lease)
and [result contract](../../contracts/SQL_RESULTS_V1.md#original-workload-evidence)
own the executable semantics.

The [renewal qualification record](../history/qualification/query.md#sql-queue-renewal-original-results--2026-11-02)
attributes the completed SQL/SDK checks and earlier failures to their tested
revisions. Those checks predate integration with the latest Board computation
changes; the PR tracks validation of the combined branch separately.

Batch 0's preserved fixture now has a matching-binary, read-only recovery
[observation](../history/qualification/storage.md#preserved-queue-fixture-read-only-recovery--2026-11-02)
for the original enqueue, claim and payload, obtained from a private copy with
maintenance disabled. The original fixture is unchanged. The maintenance-timeout
cause and original terminal-retention gate remain open; this observation does
not replace the failed maintenance profile with a pass.

M6 remains **In Progress**. This implements the first feature review unit in the
completion plan, not all of Batches 0–9. Group assignment/offset SQL, waits and
claim predicates, retained `STREAM_SLICE`, mixed SQL transactions, Station
services/effects, the M7 Document handoff, remaining baseline profiles and
common-revision resource/fault/provider qualification retain their gates.

The next planned feature review unit is **4a.1**: explicit Stream assignment
and group binding, followed by authenticated progress handoff and `COMMIT OFFSET`.
Batch 3's result/coverage contract comes first; native assignment generations and
owner-issued read evidence remain authoritative. Queue WAIT (4b.2) is an
independent subsequent unit. Batch 0's maintenance investigation and Batch 1's
baseline work remain separate completion gates.

## Queue settlement SQL follow-up — 2026-11-02

This review unit starts from merged `origin/main` at `ffbf2e9b12dc` (PR #333).
It implements the NACK portion of Batches 3/4b through the existing workload
intent, Catalog token and native Queue settlement owners. The SQL binder freezes
the original binary lease and an optional absolute UTC visibility timestamp;
the native owner retains retry backoff, FIFO, attempt limits and current lease
and permission checks. Command completion reuses M4's typed result model.
PostgreSQL emits `NACK`; MySQL and the console use their existing shared command
completion. Current behavior belongs to the
[SQL reference](../handbook/reference/sql/streaming.md#return-queue-work-for-retry)
and [Queue contract](../../contracts/QUEUE_V1.md#opaque-lease-descriptor-codec).

The current shared definition remains
`c3cbdfe99cdb08a8a21cc2429783fd746b1311b096d9ca8371058e1abb037b64`,
introduced on main with M12's owned staging. NACK's native request, outcome and
saved-work encodings already exist; this additive SQL admission does not replace
those definitions or reinterpret accepted work. M8's database runtime owns
admission/recovery, and M9's SQL caller retains the original token. The operation
is outside M5's attached SQL transaction profile; it does not implement a Station
turn, M7 Document participation or M12 continuous activation.

The [executed NACK qualification](../history/qualification/query.md#sql-queue-nack-settlement-and-recovery--2026-11-02)
records all eight clean SQL tasks and all 28 clean core tasks, the original
response-failure investigation, and the independently reproduced signing-fixture
correction. Its source identities and limits remain separate from the broader
M6 qualification gates.

M6 remains **In Progress**. This supersedes the earlier checkpoint's statement
that all NACK SQL is absent, without closing all of Batch 3 or 4b. Renewal still
needs returned-handle semantics; predicates, waits, group progress/offset SQL,
finite `STREAM_SLICE`, mixed SQL, Station services/effects and common-revision
resource/fault/provider qualification retain their gates below. This NACK profile
uses absolute visibility rather than relative-delay or reason operands. Broader
NACK metadata needs an explicit native contract before admission. Batch 1's
remaining baseline profiles and Batch 8's commit/latency work are also open.

## Progress checkpoint — 2026-11-01

The current source assessment starts at `origin/main` commit `0c64c4b03`,
including M6 progress #321, M7 logical storage #319, M8 ingress #315,
M10 catalog/column semantics #320 and M12 retained revisions #324. The combined
current-v1 definition is
`afac2bd84560136ca90c0683afdffb8f71d5f96568b05dd3de773ce3c5339b2a`.
SQL workloads and managed computations retain separate operation identities;
older saved artifacts cannot acquire either interpretation implicitly. Earlier
rebase and cutover evidence retains its own source and definition attribution.

The implemented owners provide original-operation recovery and bounded result delivery for
SQL append, positional Stream consumption, routed Queue claims and receipt-based
ACK. Native work also covers authenticated Stream progress intervals, mixed
state/log transactions and protected automatic Queue terminal transfers. Queue
candidate persistence now stages only the reachable new index and bitmap objects,
including frozen timer-merge roots and FIFO-key child directories. It preserves
accepted roots, time checks, lease durations and resident quotas.

M6 remains **In Progress**. The later
[installed claim/ACK fixture closure](../history/qualification/query.md#installed-sql-queue-claim-and-ack-fixture-closure--2026-11-01)
passes against frozen current-main binaries; common-revision qualification remains
open for the complete milestone. The subsequent
[clean branch run](../history/qualification/query.md#m6-clean-sql-session-attempt--2026-11-01)
passes the installed claim/ACK profile with runtime and fixtures both at
`f590f1bd0`, retaining the original lease, wait and batch bounds. That source
also passes the full selected core and SQL-interface lanes and the existing
transaction-workspace model/replay gate; the
[integration record](../history/qualification/storage.md#m6-recovery-integration-fixture-repairs--2026-11-01)
preserves earlier failures, interrupted checks and the exact scope of each pass.
The subsequent [clean storage/query lane](../history/qualification/storage.md#m6-clean-storagequery-continuation--2026-11-02)
passes all 33 tasks at `655067be1` and again at `8c0657436`, including repaired
native and Table fixtures, mixed transactions, Queue transfers and catalog
growth/restart verification. That account also records the later fixture-only
convergence and its separate focused outcomes.
The selected large unordered Queue profile now
[passes its workload and cold-recovery gate](../history/qualification/performance.md#queue-profile-4-recovery-gate-closure--2026-11-01)
with unchanged budgets; unfinished profiles do not supply complete baselines. Earlier installed passes retain
their own source attribution. The remaining work includes executable SQL renewal
and NACK, acquisition predicates, consumer groups/WAIT/offset settlement,
`STREAM_SLICE` integration, real transactional Station handlers and effects,
Table commit-path/performance gates, and final resource/fault/provider qualification.
Table retains the numeric performance gate; Stream, Queue and Station turns need
measured baseline budgets before later target refinement.
The [integration evidence](../history/qualification/query.md#m6-progress-integration--2026-11-01)
records the executed checks and their source-specific limits.

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

R0–R10 retain their original acceptance scope. The dated progress records in
this section describe delivery as it landed; use the
[current source assessment](#current-source-assessment) and
[current batch order](#delivery-order-and-review-boundaries) for remaining work.

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
Mixed disk append-fault schedules and the protected automatic DLQ owner now
pass focused [catalog, storage and native worker checks](../history/qualification/transactions.md#protected-automatic-dlq-transaction-owner--2026-11-01).
The [installed automatic-worker schedule](../history/qualification/transactions.md#installed-automatic-dlq-recovery--2026-11-01)
also passes original transfer recovery across process replacement. Integrated
resource schedules and common-revision clean lanes remain open. R6's workload SQL/shared caller/finite analytical
surfaces, R0 model correspondence and final integrated
qualification also remain open. Publishing declarations or neutral types does
not complete these gates.

| Package | Outcome | Start gate | Exit evidence |
| --- | --- | --- | --- |
| R0 | Partial: primitive and mixed-participant contracts delivered; workload-result/runtime contracts and model correspondence open | Baseline audit and M5 handoff | Shared types/fixtures, resolved decisions below, finite invariants and refusal cases |
| R1 | Implemented foundations; integrated qualification open | R0 physical ownership and format decisions | `.tdel`/`.tack` container correctness, bounded allocation and disk publication faults |
| R2 | Implemented: catalog declarations, grants and inspectable lifecycles | R0; R1 initialization evidence before publication | [Typed create/alter/drop/inspect/recovery and native policy proof](../history/qualification/catalog.md#typed-stream-and-queue-catalog-lifecycle--2026-10-29) |
| R3 | Partial: signed payload/read/group operations, bounded waits, local maintenance and sparse rewriting; common-revision qualification open | R1 and R2 | Disk reopen, original producer receipts, complete bounded reads and fenced offset progress through public callers |
| R4 | Partial: claims, bounded waits, retries, delays, maintenance, retention and automatic atomic DLQ owner delivered; installed automatic-worker recovery passes; integrated qualification open | R3 payload storage and R0 lease contract; R5 for DLQ | Durable claim recovery, stale-lease refusal, per-key order, bounded waits/timers and atomic DLQ transfer |
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
Automatic blocked-item scheduling now uses protected original transaction
identities and a separately configured database signer. Catalog fault schedules
and native policy/collection/worker replacement checks pass, as does installed
automatic-worker recovery across SIGKILL/restarts. Remaining exit work includes
integrated fault/resource evidence on one revision.

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

#### Next slice: SQL Stream WAIT (4a.2) — 2026-11-05

**Status: Implemented; [qualification remains partial](../history/qualification/sql.md#bounded-sql-stream-waits--2026-11-05). Plan source basis:** `origin/main` at
`d8b756f08116ac50c53b72886dca239abb74cbb3`, including merged
[PR #386](https://github.com/spoke-sh/transit/pull/386). That change delivers
shared SQL wait recovery and unfiltered Queue WAIT (4b.2). This plan selects one
subsequent implementation PR, with logical commits below. It supersedes only the
next-slice ordering and Queue-wait gaps in the earlier source assessment; Batches
0–9 retain their remaining gates. This source review executes no runtime proof.

**Application outcome:** a caller waits briefly for a declared Stream's offset
frontier, receives one finite retained read when ready, or inspects a pending
original operation after timeout. Explicit resume preserves the same request.
Grouped consumption retains authenticated progress for a separate `COMMIT OFFSET`.
Reading, waiting, closing delivery and inspecting status never commit progress.

The implemented forms reuse the existing grammar:

```sql
CONSUME value, _offset FROM events WHERE _offset >= $1 LIMIT 128 WAIT '1s';
CONSUME value, _offset FROM events GROUP $1 LIMIT $2 WAIT $3;
```

The source revision above refused these forms. The slice now binds and dispatches
the saved native Stream wait through shared SQL recovery. Current semantics live
in the [SQL reference](../handbook/reference/sql/streaming.md#wait-for-a-stream-frontier).
The group parameter is the existing binary `StreamHandle.Group`, the limit is
an unsigned row count, and the wait parameter is a duration string. SQL still
selects exactly one partition. Follow the current
[SQL consumption profile](../handbook/reference/sql/streaming.md#consume-and-settle-an-assigned-group),
[native wait contract](../../contracts/DIRECT_TABLE_V1.md#stream-payload-and-consumer-progress)
and [SQL wait recovery contract](../../contracts/SQL_SESSION_V1.md#queue-wait-attempts)
when extending admission.

##### Source findings and implementation owners

| Boundary | Delivered owner | Change needed for this slice |
| --- | --- | --- |
| Grammar and owned operands | [`LogConsumeSql`](../../packages/zig/transit-fuze/src/LogConsumeSql.zig) already parses GROUP, predicates, LIMIT and WAIT, including parameters | Preserve existing syntax and owned literals; add native-range diagnostics and executable capability fixtures |
| Catalog binding | [`DirectLogPreparedConsume.freeze`](../../packages/zig/transit-catalog/src/DirectLogPreparedConsume.zig) freezes a positional start or explicit group checkpoint, with native `until = null` | Remove WAIT refusal only after saved-work semantics are implemented; retain routing, predicates and logical LIMIT |
| Saved intent | [`DirectWorkloadIntent`](../../packages/zig/transit-catalog/src/DirectWorkloadIntent.zig) persists mandatory nullable `wait_ms`; validation and `Reference.operation` currently dispatch only waited Queue claims | Admit waited Stream consume bodies, validate the exact native request and dispatch Stream wait from the saved reference |
| Shared observations | [`Workload.Wait`](../../packages/zig/transit-sql-results/src/Workload.zig) and [`Operation.validate`](../../packages/zig/transit-sql-protocol/src/root.zig) restrict waiting to Queue claim bindings/commands | Admit precisely Stream consume and Queue claim, with matching command, binding and nonterminal row-result shape |
| SQL execution/recovery | [`WorkloadOperations`](../../packages/zig/transit-sql/src/WorkloadOperations.zig) has receipt-first passive, initial and explicit paths; dispatch and timeout validation are Queue-specific | Add the Stream branch using `DirectStreamResponse`; keep first-admission and resume scheduling in the existing `DatabaseRuntime` |
| Native parking and authority | [`DirectStream`](../../packages/zig/transit-catalog/src/DirectStream.zig), [`DirectStreamResponse`](../../packages/zig/transit-catalog/src/DirectStreamResponse.zig) and node `LocalLogWaits` already implement bounded frontier waits | Reuse them; extend their real-owner tests where SQL introduces a new composition or exposes a missing race |
| Delivery and callers | `DirectWorkloadResult`, `WorkloadRead`, shared-client `Pending`/`Executor.resumeWorkload` and the wire adapters already preserve original results | Prove Stream wait observations, finite cuts and grouped completion through these owners; add no new result or recovery protocol |

##### Contract choices to freeze before admission

1. **Separate SQL policy from native work identity.** Freeze a positive duration
   of 1–1000 whole milliseconds in the canonical SQL intent and token
   fingerprint. The native accepted identity remains the exact underlying
   consume request; its wait duration is a transient scheduling bound. Null
   policy continues to mean ordinary consumption. Missing fields, other workload
   kinds, changed frozen inputs and foreign definitions refuse. A resume can
   obtain a new bounded deadline, never a new source, checkpoint or operation.
2. **Keep readiness independent of output selection.** SQL retains native
   `until = null`: readiness is `from < next`, where positional `from` is the
   existing conservative lower bound and grouped `from` is the saved checkpoint.
   Upper `_offset` comparisons remain row predicates. Payload filters and LIMIT,
   including LIMIT 0, do not bypass the wait or require matching rows before
   acceptance. A ready read may therefore produce zero rows. Native explicit
   `until <= next` behavior remains a regression case; this slice introduces no
   SQL upper-frontier operand or timestamp syntax and does not reinterpret a
   WHERE upper bound as one. Preserve rejection of contradictory routing bounds.
3. **Retain exactly one accepted cut.** The native owner selects the finite
   upper cut at acceptance. Later appends never extend it, and resume/reopening
   never recapture it. Group descriptors retain principal, generation, partition
   and expected checkpoint; every native attempt checks current assignment and
   rights. Fresh expired history, stale groups and changed definitions follow
   their existing refusal rules, without refreshing the saved request.
4. **Keep timeout, uncertainty and acceptance distinct.** An actual native
   timeout yields a ready/pending SQL operation with no receipt, terminal rows,
   counts or coverage. Only that attempt's response may carry its observed cut;
   passive status carries null `timed_out`. Validate the timeout through
   `DirectStreamResponse` against the complete request, including its unready
   frontier and retained boundary. Timeout is neither a retained pin nor proof
   that a concurrent attempt cannot accept. An original receipt or durable
   closure takes precedence over waiting, including an accepted empty read.
5. **Reuse explicit recovery and cancellation.** Only the first winning SQL
   admission or an explicit original-work resume may dispatch one wait attempt.
   Same-token execute, status and service recovery cannot consume plainly or
   start another wait. Preserve lost-reply uncertainty and the original identity
   when subsequent observation is denied. A local stopped wait is separate from
   durable cancellation; cancellation races use the existing consume closure
   owner. Resume uses the data lane; observation and cancellation retain control
   capacity. Bound shutdown/join and preserve SQL activation fencing.
6. **Reuse delivery, progress and transport semantics.** Successful results use
   the existing consume selection and bounded result lifecycle. Grouped terminal
   metadata authenticates traversal, including filtered and partial-LIMIT cases;
   row counts cannot authorize offset settlement. Local result close neither
   commits offsets nor releases the native pin. Pending PostgreSQL/MySQL outcomes
   retain the existing 57014 and 1317/70100 mapping and original operation ID;
   the console returns nonzero with typed recovery JSON. All four callers obtain
   rows on success; group progress remains exposed through the native result API.
7. **Make one coherent current-v1 change.** Extending accepted saved-work and
   wait-observation semantics requires a replacement shared definition. Update
   the Stream, direct workload, SQL session/result contracts, reflected schemas,
   independent fixtures, SDK validator resources and signing digests together.
   Preserve missing/foreign-definition refusal. Do not default old persisted
   policy, reinterpret old accepted work or add a second compatibility profile.

##### Implementation and logical commit sequence

| Commit unit | Concrete work | Review gate |
| --- | --- | --- |
| 1. `feat(sql): define original Stream wait observations` | Extend shared wait/operation validation and contract fixtures for Stream consume; specify readiness, timeout, cancellation and original-result evidence. Coordinate the current-v1 definition and generated consumer cutover | Independent valid/invalid observations distinguish Stream consume from append/offset and Queue claim from settlement; mismatched command/binding/target, terminal-plus-wait and foreign definitions reject |
| 2. `feat(catalog): bind bounded Stream waits to saved consumption` | Extend `Saved.validate` and `Reference.operation`; freeze `wait_ms` through `createWaited` in `DirectLogPreparedConsume`. Preserve the existing projection, partition and group binding; no pin or admission during preparation | Parameter buffers and prepared objects can be destroyed; restore reproduces the same identity/projection/duration. Allocation failures, invalid durations, ambiguous routing and changed canonical inputs refuse safely |
| 3. `feat(sql): execute and resume original Stream waits` | Dispatch and validate Stream wait in `WorkloadOperations`; reuse `DatabaseRuntime`'s first-binding winner, passive recovery and explicit resume. Carry the observation through SQL service, shared client, wire and console adapters | A timeout stays pending through status, same-token execution and replacement; only explicit resume can accept later arrivals. Lost replies, recovering owners, current denial and cancellation preserve original identity |
| 4. `test(sql): qualify waited Stream cuts and group progress` | Extend installed log/wait schedules and owning native concurrency checks; exercise real typed, native SQL, PostgreSQL, MySQL and console paths. Keep Queue WAIT and ordinary consume/offset regressions | Acceptance matrix below passes with unchanged deadlines, budgets and exact operation/receipt assertions; controlled race tests establish both allowed outcomes |
| 5. `docs(sql): publish Stream wait behavior and evidence` | Update the public Stream/SQL references, Catalog/SQL/client guides, capability inventory and relevant Internals explanation. Record executed revision-specific proof and update this milestone's slice status | Public owners explain current behavior without a roadmap; proof records distinguish component, installed, caller and unexecuted scenarios |

These are commits within one review unit, not permission to expose partially
supported syntax between dependent PRs. Implementation may combine inseparable
contract/generated changes, but the final tree must reject unsupported work
before admission. Keep native Stream/Queue storage and database ownership intact.

##### Acceptance matrix

| Case | Required observation | Starting owner |
| --- | --- | --- |
| Binding and bounds | Literal/parameter 1 ms and 1000 ms accepted; zero, null, malformed and 1001 ms refused. Owned parameters, full-width offsets, multi-partition ambiguity, explicit groups, LIMIT 0 and AND/OR/NOT retain their existing semantics | `LogConsumeSql`, `DirectLogPreparedConsume`, saved-intent and shared protocol tests |
| Ready versus empty output | Existing data accepts immediately; filtered/all-hidden input and LIMIT 0 can complete empty after readiness. An upper-offset predicate does not delay until that upper offset. Partial LIMIT preserves authenticated progress | Catalog owner, `WorkloadRead`, installed consume/group schedules |
| Timeout and late publication | No read receipt or pin is accepted by the timed-out attempt. Later append plus repeated passive observation/same-token execute still leaves SQL pending. Explicit resume retains original identities and selects one finite cut | `tests/interfaces/sql_sessions/waits.py`, original token/result checks |
| Arrival at the deadline | Registration-before-check and final authorized recheck allow either original acceptance or timeout followed by explicit resume; deterministic controls exercise both, not just whichever branch an uncontrolled race reaches | `apps/transit-node/local_log_wait_test.zig`, Catalog wait tests, installed waits |
| Recovery and response loss | Drop initial admission, timeout, accepted execute/resume and fetch replies separately; replace SQL service/node and inspect the same saved work. Denied observation preserves known identity and clears stale timeout evidence; no automatic retry or recapture | SQL fault proxy, shared-client peer tests and installed original-result recovery |
| Groups and offsets | Reassignment, changed checkpoint or revoked acquire rights while parked fence work. Waited empty/filtered/multi-batch/partial results produce authentic progress; separate COMMIT OFFSET succeeds or returns the original recorded refusal. Forged and released descriptors still fail | Existing group/offset installed schedules, Stream response/result validators |
| Accepted-cut lifetime | Append after acceptance, result reopen, compatible catalog edits, compaction gaps and restart preserve original receipt/cut and available payload. Released or unavailable history fails explicitly; no silent fresh read | Disk Catalog/native Stream tests and installed results |
| Current rights and cancellation | Denial before admission, while parked and after buffering prevents disclosure. Durable cancellation versus acceptance resolves one original outcome; session loss/shutdown joins local waits without promising rollback | Native wait schedules, service/client cancellation and after-buffer controls |
| Capacity and ownership | Four native wait lanes, 64 aggregate Stream/Queue registrations and smaller declaration limits remain bounded. Saturation preserves unrelated control progress; completion/cancellation releases registrations. SQL parking holds no data lock | `LocalLogWaits`, native host/service and SQL concurrency checks |
| Caller carriage and regressions | Native SQL/shared client, PostgreSQL, MySQL and console preserve pending identity and successful finite rows. Ordinary consume, group settlement, Queue WAIT, ACK/NACK and exact renewed-handle results continue to pass | Full installed `sessions-log`, SQL package/wire suites |

The native wait owner's existing explicit-upper-frontier, timestamp-filter and
producer-retry controls remain regressions; they do not expand SQL syntax or
qualify new Arrow/Flight ingress. Preserve separate native page, examined-offset,
SQL result-page and display budgets. Use bounded scratch and retained output
lifetimes; never collect a whole Stream to decide readiness or column widths.

##### Validation and completion

During implementation use the affected package tests in `transit-fuze`,
`transit-catalog`, `transit-sql-results`, `transit-sql-protocol`, `transit-sql`,
`transit-sql-service` and `transit-sql-client`, then real owning disk/service
tests (`just test catalog`, `just test local-catalog`, `just test service`).
The existing focused installed command is:

```sh
nix develop .#sql-wire --command zig build test-sql-wire-gateway -Doptimize=ReleaseSafe -- sessions-wait
```

Extend that selector to run both Queue and Stream schedules; retain their
inclusion in `just test sql-log-declarations` (`sessions-log`). A focused pass
cannot substitute for the full log/group/offset regressions. Run
`just check contracts`, `just test sql-wire-contracts` and
`just test sql-wire-types` inside their owning pinned shells. Before the
implementation PR, run the root fast gate and both handbook install/check
commands, the pinned `ci-experience` console-latency gate followed by
`server-sql-types`, and affected committed-HEAD clean `core`, `storage-query`,
`interfaces-sql` and `installation-ui` lanes. The definition cutover also requires
the dependent SDK/browser contract checks selected from the final generated diff
and [suite inventory](../../tests/runner/suite.json). Keep timed latency runs
separate from heavy builds and retain failed original attempts. Record commands,
revision/definition, binaries, outcomes and omissions; no skipped check or pass
from an earlier revision qualifies the final implementation.

Update [SQL streaming](../handbook/reference/sql/streaming.md),
[Streams](../handbook/reference/streams.md), the owning package guides and
[service internals](../handbook/internals/service-interfaces.md) with executable
behavior when it lands. Reconcile stale blanket WAIT refusals in component
guides while retaining the actual Queue predicate and Stream-source limits.
Put executed results in [SQL qualification](../history/qualification/sql.md#bounded-sql-stream-waits--2026-11-05).
This planning change needs documentation checks only and establishes no runtime
or latency result.

**Slice exit:** waited consumption preserves one original operation; each accepted
read retains one finite cut and, when grouped, authenticated progress across the
matrix above, through supported callers under current rights. Mark 4a.2 delivered only
with its implementation and source-attributed evidence. M6 remains In Progress:
Queue predicates, `STREAM_SLICE`, mixed SQL, automatic group assignment,
transactional Station, the Document handoff and Batches 0/1/2/8/9 remain separate.
Continuous consumption/activation and new producer or Arrow ingress profiles are
not added by this slice.

#### Completion plan at current main — 2026-11-05

**Source basis:** fetched `origin/main` at
`c4dd89c2224ab53fd9139f2f89c328e8ca0b3f25`. Since the November 3 plan at
`63f6369d5`, main includes M6 explicit Stream groups/offsets #367, M7 retained
Document collection cuts #370, M12 owned progress/original staging and closure
#361/#365, M8 local SQL lane coordination #362, console/scenario gates #366/#369,
SQL scalar parity #374, original wire-write conflict recovery #381, relational
ordering/grouping and forward Dataflow revisions #383, and filesystem publication
#384. The nightly published-image campaign #379 supplies a separate measurement
workflow. Earlier database separation, native mixed decisions, automatic DLQ,
renewal, retained reads and shared-client foundations remain available.
The mandatory shared definition in `transit-protocol.Growth` is
`4a79430a0f740284cda72df8341f0af87a87a63a599d7a81c62a934778875e1a`.
This plan uses merged source only. Other
worktrees, proposed APIs and earlier component passes are not prerequisites
that can be treated as delivered or qualified at this revision.

This refresh updates the November 3 plan at `63f6369d5` in place and retains
its R0–R10 owners and Batch 0–9 acceptance scope. It replaces that plan's
next-change ordering, the November 2 ordering at `edeb8618c` and the ordering
after PR #303, while preserving that
[review's attribution](#review-baseline-after-pr-303--2026-11-01), the earlier
source audit and each dated implementation/evidence record. The linked accounts
record executed checks at their own revisions; this planning change adds no
runtime qualification. M6 stays **In Progress**.

**Completion journey:** declare a Stream and Queue; publish and recover typed
work; consume a finite retained interval or acquire an exact lease; atomically
settle that input with declared state and outbound intents; replace the service
or worker; inspect the same outcomes under current rights. SQL and typed clients
use the same owners. Station adds behavior and effect policy above that database
lifecycle, without becoming the database's admission or recovery authority.

#### Current source assessment

Read the [public SQL profile](../handbook/reference/sql/streaming.md),
[Stream/Queue operations](../handbook/reference/streams.md) and exact
[direct operation contract](../../contracts/DIRECT_TABLE_V1.md) alongside source.
Some earlier broad summaries still describe workload SQL, automatic DLQ and
native mixed transactions as absent. The assessment below supersedes those
remaining-work descriptions; reconcile their public owners with the next
relevant implementation change rather than treating old prose as a new feature
requirement. SQL result tags or compiler helpers alone do not prove admission.

| Boundary | Existing implementation to preserve | Remaining implementation or evidence |
| --- | --- | --- |
| Database independence | `DatabaseRuntime`, direct tokens/read cuts and transitive Station import gates in Catalog, SQL, direct Query and data-client packages | Preserve through runtime migration; complete account-token/partition commit composition and installed Table latency gates |
| Storage and declarations | `StreamPartition`, `QueuePartition`, direct KV, `.tseg`, `.tack`, shared Roaring directories, retained graphs and signed declaration/inspection SQL | Common-revision disk, corruption, growth, retention and resource qualification; no replacement partition engine |
| Stream operations | Producer deduplication, retained finite reads, explicit group generations, authenticated interval settlement, native waits and maintenance; SQL group descriptors and original offset settlement | SQL WAIT, finite retained `STREAM_SLICE`, Arrow/batch ingress qualification and full integrated evidence; assignment and read release remain native, with no automatic rebalance service |
| Queue operations | Exact claims/pages, ACK/NACK/renewal, bounded native waits, durable scheduling, FIFO affinity, terminal retention and explicit read release | Predicate-aware native acquisition and SQL waits; integrated concurrency, time and resource evidence |
| Mixed decisions and DLQ | `DirectTransaction`, private state/log workspaces and `TransactionDecisionLog` compose Table/KV, Stream/Queue appends and offset/ACK settlements. Protected automatic transfers use that same owner; the #333 clean storage/query lane includes these installed schedules | Extend the remaining preparation/decision/finalization fault and correspondence matrix, especially collection and reserved control under pressure; an installed mixed pass is not a Station-handler proof |
| Owned records and progress | M12's `DirectTransactionRecord` retains ready `TXR1` candidates; `DirectClientToken` owns `CPR1` progress and `SOR1` original reservation/readiness/attachment/closure. `ManagedTable` packs bounded multi-row `DFP1` pages | Reuse the appropriate ownership family for runtime candidates and work. Closed owned originals can be collected under their contract; published declarations/revisions and generic unowned `DirectRecord` objects do not thereby become collectible |
| Workload identity/results | [`DirectWorkloadIntent`](../../packages/zig/transit-catalog/src/DirectWorkloadIntent.zig), [`DirectWorkloadResult`](../../packages/zig/transit-catalog/src/DirectWorkloadResult.zig), [`WorkloadOperations`](../../packages/zig/transit-sql/src/WorkloadOperations.zig) and [`WorkloadRead`](../../packages/zig/transit-sql/src/WorkloadRead.zig) retain outcomes, closures and original bounded results | Extend these owners for the missing verbs and wait/progress handoff; do not implement another outcome/result protocol |
| Executable workload SQL | Single-partition PRODUCE/ENQUEUE with RETURNING, positional/explicitly grouped CONSUME, authenticated COMMIT OFFSET, partition-routed CLAIM, binary-receipt ACK/NACK and EXTEND LEASE returning the original renewed handle | Finish waits, payload acquisition predicates, finite TVF and mixed SQL. Preserve authenticated coverage separately from row counts, descriptor-only renewal results and ACK/NACK command completion. NACK reasons/relative delays need a separate contract |
| Admission and retained reads | `DatabaseRuntime.submitPrepared`/SQL `Registry` now track possible acceptance at the actual token boundary; current Table capture binds an explicit interpretation and preserves the first accepted cut | Apply exact uncertainty to new workload verbs. The latest generic pending projection deliberately excludes workload intents; it is not a ready WAIT/result adapter. Table capture changes do not authorize recapturing accepted Stream reads |
| Collection and historical obligations | #355 adds signed/typed disk schedules for original historical acquisitions and closures; #359 batches collection mark work and reuses existing Catalog views | Requalify log/runtime roots under the changed collectors. Neither Table-only collection evidence nor the repair commit establishes the cause of the retained Queue maintenance failure |
| Document integration | M7 stores retained collection membership and bounded head pages with exact raw-part/topology roots | Direct public lifecycle, protected Document staging and mixed participation remain M7 gates; collection cuts alone cannot admit Document turns |
| Finite relational execution | #383 adds typed GROUP BY/HAVING/ORDER BY/LIMIT and forward retained Dataflow revisions | Reuse supported operators and result ownership when adding the Stream source. A Table relational pass or standalone array TVF is not an executable `STREAM_SLICE` adapter |
| Publication and installed paths | #384 publishes named immutable files and recoverable directory assemblies without rename flags; #381 recovers admitted wire writes after foreground owner conflicts | Preserve durability, exact identity and publication fault regressions; the filesystem change does not qualify EFS or explain earlier maintenance/setup timeouts |
| Station | Native GenServer, durable calls/timers/names/supervision, private Table/Query helpers and recorded effects retain their existing semantics | Real database-transaction handlers, durable service migration and coherent consumer/effect/delivery cutover |
| Performance tools | Registered `log-runtime-baseline` and `station-turn-baseline` drivers with independent oracles | Preserve the passing profile 4 recovery gate, complete all baseline profiles and broaden coverage; compare the new runtime with the existing measured Station workload |
| Formal adapter | `transaction_workspace_state.zig` now uses `StatementWork` variants and `statement()` | The old compilation repair is no longer a new task. Establish concrete Stream/Queue/mixed/runtime correspondence and run the integrated formal gate |

The source checks that fix the next implementation boundary are
[`DirectLogPreparedConsume.freeze`](../../packages/zig/transit-catalog/src/DirectLogPreparedConsume.zig)
(GROUP binds an explicit assignment; WAIT still refuses),
[`DirectLogPreparedClaim`](../../packages/zig/transit-catalog/src/DirectLogPreparedClaim.zig)
(routing-only selection; WAIT/payload predicates refuse),
[`DirectLogPreparedSettlement`](../../packages/zig/transit-catalog/src/DirectLogPreparedSettlement.zig)
(renewal now freezes its result projection), and
[`TransactionWork`](../../packages/zig/transit-sql/src/TransactionWork.zig)
(attached mutations still require Table DML).
[`DirectLogPreparedOffset`](../../packages/zig/transit-catalog/src/DirectLogPreparedOffset.zig)
and `Statement` now supply offset admission; `WorkloadRead` retains the original
authenticated coverage. Conversely, `WorkloadOperations.advance` still observes
then executes ordinary original work: merely admitting WAIT in a binder would
allow recovery to consume/claim without waiting. Its recovery semantics must
change with the wait contract. `BitemporalAndTvf` remains an array-backed helper;
the production relational path has no retained Stream source.
`Transaction.Participant.requireLocalState` and Catalog selection still reject
Documents. These are source observations, not newly executed tests.

Current bounds remain distinct: native append/enqueue admits at most 1 MiB;
claims select at most 256 rows; native Stream pages allow up to 4096 rows/examined
offsets and 4 MiB; original workload-result delivery has its own 128-row/1-MiB
page ceiling; saved workload JSON has a 4-MiB bound including encoding overhead.
Smaller declaration/deployment limits apply. These are separate operation,
scan and delivery budgets, not reasons to raise actor frame constants or collect
whole histories in memory.

Preserve the following evidence and remaining blockers separately:

| Evidence | Consequence for the next changes |
| --- | --- |
| [Installed claim/ACK closure](../history/qualification/query.md#installed-sql-queue-claim-and-ack-fixture-closure--2026-11-01), then [clean SQL at `f590f1bd0`](../history/qualification/query.md#m6-clean-sql-session-attempt--2026-11-01) | Keep the 65-row, multi-batch original-result and exact-receipt proof as a regression. Do not repeat the fixture repair or claim it explains the earlier `ClockUnavailable` failure |
| [Clean storage/query integration](../history/qualification/storage.md#m6-clean-storagequery-continuation--2026-11-02): 33 tasks pass at `655067be1` and `8c0657436` | The initial recovery integration is delivered, including mixed work, automatic transfers and growth/restart. Broader faults/resources and one final revision remain gates |
| [Preserved Queue fixture](../history/qualification/storage.md#preserved-queue-fixture-read-only-recovery--2026-11-02) at `e8f5cf5c6`: matching binaries recover original enqueue/claim/payload from a private copy with maintenance disabled | Original records are observed, so do not repeat that investigation as missing work. `MaintenanceTimeout`/`WalRecoveryRequired`/`AuthorityUnavailable`, terminal ACK and retention completion under the failing configuration remain unresolved; #359 is a candidate to investigate, not a demonstrated explanation |
| [NACK qualification](../history/qualification/query.md#sql-queue-nack-settlement-and-recovery--2026-11-02), [renewal and post-merge checks](../history/qualification/query.md#post-merge-validation-and-fault-proxy-cleanup--2026-11-02) | Renewal is delivered. The recorded combined tree passed SQL, storage, core and installation lanes; the workflow's SDK disk failure and separately reported repairs retain their own attribution. Preserve exact renewed handles, no repeated mutation and current disclosure checks; these runs do not qualify today's combined definition |
| The renewal follow-up retains two local `direct-workload-result` preparation timeouts at the unchanged 180-second deadline, before result-recovery assertions; one saved cancellation lacks a captured reply | Track setup latency and original cancellation uncertainty separately from the older Queue maintenance case. Joined proxy cleanup fixed interpreter teardown, not setup latency. A hosted pass does not explain either local timeout |
| [Profile 4 recovery closure](../history/qualification/performance.md#queue-profile-4-recovery-gate-closure--2026-11-01) under the original budgets | Do not reopen the fixed large unordered Queue replay implementation without a new failure. Finish the six-profile log campaign and its missing group/wait/maintenance/concurrency coverage |
| [Station baseline](../history/qualification/performance.md#installed-station-handler-baseline--2026-11-01): 20 turns plus restart at `6c4e10116`, p50 440.153 ms / p95 607.804 ms | Preserve its actual handler/input/state/output oracle and repeat a matching control before replacement. It measures the old native runtime, not transactional Station or zero server allocations |
| [Transaction-owned candidate evidence](../history/qualification/query.md#transaction-owned-managed-result-candidates--2026-11-02) and [original staging/closure](../history/qualification/query.md#owned-original-staging-and-closure--2026-11-03) | Preserve registration/creation/collection races, retained revisions and delivered closure of owned originals. Generic work records retain their own lifetime; the full mixed/runtime crash matrix and managed performance remain open |
| [Historical collection schedules](../history/qualification/catalog.md#native-historical-obligations-through-disk-collection--2026-11-03), ordered Document/fork evidence and [owned predicate qualification](../history/qualification/query.md#owned-predicate-preparation-and-codec-reuse--2026-11-02) | Reuse their independent oracles and exact source records. Graceful disk reopen, Table filtering and Document component passes do not establish Queue fault recovery, predicate acquisition or Station composition |
| [F0 diagnostic scorecard](../history/qualification/performance.md#managed-staging-and-sdk-diagnostic-baselines--2026-11-02) precedes current capture and multi-row staging | Preserve failed managed successors and original SDK/console observations; remeasure at the new definition. Old per-row publication counts and timing are controls to update, not current-main results or M6 budgets |
| [Grouped SQL qualification and M8/M12 integration](../history/qualification/query.md#sql-stream-groups-and-authenticated-offsets--2026-11-03) | 4a.1 is delivered, including four SQL callers and negative coverage controls. Keep the recorded MySQL BEGIN uncertainty, workload-token/result setup failures and interrupted growth attempt distinct from subsequent core/SDK/individual SQL passes; they do not form one passing integrated lane |
| [M7 collection/closure integration](../history/qualification/storage.md#integration-with-original-operation-staging-closure--2026-11-04) at `501d5532be3b` | Core 28/28, SDK conformance 7/7 and storage-query 33/33 passed, including both workload setup deadlines. These are later source-specific passes, not explanations of earlier timeouts or qualification of today's definition |
| [Installed scenarios](../history/qualification/performance.md#installed-scenario-qualification--2026-11-04) and [scalar interface parity](../history/qualification/sql.md#scalar-parity-across-sql-interfaces--2026-11-04) | Preserve verified values/recovery and the existing console budget gate. Scenario observations are not a paired speedup, and passing smoke ceilings does not meet M6's Table targets or supply complete Stream/Queue/Station baselines |

**Immediate order:** preserve 4a.1, 4b.1 and the Queue WAIT implementation
(4b.2) and **Stream WAIT (4a.2)** below as regression inputs. The latter uses
the shared wait identity/result/recovery contract, extending its Queue-only
validation deliberately and reusing group coverage rather than redefining it. Batch 0 investigates the original
maintenance failure and distinct setup/BEGIN uncertainties, using the later
passing revisions as controls. Batch 1 freezes current-definition baselines;
Batch 2 extends mixed-decision/retained-root correspondence. These are separate
work tracks; benchmarks run without concurrent heavy builds or fault suites.

Finite `STREAM_SLICE` (4c) can proceed after its own source/closure contract;
mixed SQL (4d) requires Batch 2 and its statement contract. Station's first real
handler (Batch 5) requires Batch 2's decision/authority gates and the actor guard
contract, independently of SQL syntax. Do not rebuild delivered groups, storage,
DLQ, renewal, record closure, current Table capture or managed page batching.
M6 stays In Progress until the remaining R0–R10 gates pass.

#### Recent milestones and upcoming handoffs

| Owner | Input available to M6 | Required handoff and scope boundary |
| --- | --- | --- |
| [M1–M3](03-live-storage-and-sql-cutover.md), storage/lifecycle | Stable identities, direct catalog, retained cuts, local maintenance and installed recovery owners; M3 remains In Progress | Register every new preparation/runtime/result root in the existing graph. M3 keeps its installed storage gates; M6 R9 shares its write-path work |
| [M4](04-statement-results-and-consumption.md), Completed | Logical statement outcomes, bounded ResultSet delivery, completion evidence and original-attempt settlement | Reuse command/row distinctions and current disclosure checks, including empty and repeated batches. Workload completion is separate from result delivery |
| [M5](05-transactions-and-atomic-composition.md), Completed for local Tables | Common cuts, private statements/savepoints and original commit/abort decisions | Extend the delivered M6 mixed owner and qualify its extra participants; M5 completion is not mixed/Document/distributed proof |
| [M7](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work), In Progress; #354/#370 merged | Causal maps, ordered/versioned trees, BP/raw parts, verified MIME candidates and retained collection membership/head pages in `DocumentPartition` | Public C4 lifecycle and protected staging remain; C5 must integrate partition-aware cuts, workspaces and preparation with M6 R5. C7 joins R7/R8's consumer cutover. Table/KV Station work proceeds first; retained membership alone cannot admit Document transactions or close the old runtime |
| [M8](08-gateway-architecture-and-protocol-ingress.md#next-performance-implementation-after-milestones--2026-11-02), In Progress; #347/#356/#359 merged | Co-hosted/event-driven SQL, owner-attribution counters, explicit current Table pin capture, acceptance-boundary tracking and fresh session-recovery repairs | Reuse F0/R1/M3/C4/D5/S6/E7/Q8 owners and measure the changed path. Do not repeat current-pin capture or one-row managed-page work as pending implementation. Workload pending evidence still needs its own contract; WAIT must park through native notifications with bounded service capacity. Deadlines, core-bounded scheduling and coarse remote placement remain M8 gates |
| [M9](09-client-foundation-and-language-apis.md#remaining-implementation-plan--2026-11-01), In Progress | Independent data client, bounded Context/admission, SQL recovery store, direct KV recovery and generated installed Node validators from #330 | Supply exact log/result/transaction semantics and saved-attempt adapters through that Context/store. Reuse generated validation in affected packages; faster imports do not qualify Stream/Queue APIs. M9 owns managed handles/data bindings; M21 owns broader coverage. M6 still migrates every affected existing consumer |
| [M10](10-standards-and-catalogs.md), In Progress; #355 merged | Current column/type/collation and retained catalog semantics; independent signed/typed historical acquisition/closure schedules through disk collection | Bind exact interpretation and canonical key semantics during log preparation. Extend root/closure cases to claims, Stream reads and transaction work; the existing Table fixture does not prove those owners. No private Stream snapshot namespace or implied runtime support from schema acceptance |
| [M11](11-indexing-and-access-paths.md), Planned | Neutral index identity/coverage contracts; executable secondary-index lifecycle remains future work | Queue predicates must be correct under bounded native scans now. Future access paths can accelerate selection only with exact coverage and canonical key semantics; keep existing transaction guards until narrower conflict validation is qualified |
| [M12](12-sql-and-dataflows.md#next-implementation-slice-owned-staging-and-finite-qualification), In Progress; #361/#365/#383 merged | Transaction-owned candidates, catalog-owned progress, protected original attachment/closure, bounded multi-row results and forward retained revisions with finite grouping/ordering | Reuse the distinct TXR1/CPR1/SOR1 owners and their collection rules. Do not rebuild delivered original closure or treat arbitrary work records as collectible. M6 supplies finite Stream sources and atomic progress/output decisions; continuous activation, complete-commit feed coverage, incremental execution and sink composition remain M12 work |
| [M13](13-data-structures-and-performance.md), [M14](14-vectorized-strings-and-search.md), [M15](15-data-centric-compilation-and-specialization.md); #348/#357 merged | Resource meters, compact Batch strings, shared encoded traversal and execution-owned `PreparedPredicate` literal/schema/collation binding reused within filtered Table requests | Reuse these package interfaces for selection and `STREAM_SLICE`; preserve owned literal lifetimes, charged scratch, ordered failures and post-compute authorization. A Table predicate cache is not an acquisition index or Queue authority. M11 indexes, broader M13 metering and M15 compilation can optimize only after M6 finite semantics and budgets pass |
| [M16](16-document-profiles-and-gateway-exchange-lifecycle.md), In Progress; #349/#354 merged | Bounded JSON/XML/MIME construction, verification and ordered-storage candidate composition | Coordinate raw-part/candidate lifetime with M7 C3/C4/C5 and M6 mixed decisions. Exchange representation and gateway capture stay with M16; preserve current effect intent/attempt/unknown outcomes during Station migration. A verified MIME candidate is not an installed connector exchange |
| [M20](20-branches-merges-and-restore.md), In Progress; #353 merged | Immutable single-Table forks have independent pins and survive source-branch retirement | Keep branch identity and retained dependencies in read/collection tests. A Table fork grants no Stream/Queue branch or cross-branch transaction capability; preserve `Transaction.Domain`'s local branch-one refusal until its owner deliberately extends it |
| [M21](21-service-and-sdk-coverage.md), [M22](22-formal-semantics-and-correspondence.md), [M23–M26](23-storage-providers-and-concurrency.md) | Existing SDK, verification and provider contracts | Hand off qualified operations, invariants and resource reports. Wider SDK breadth, distributed assignment/replication/atomic commit and placement are later work; preserve existing Ursula/Substrate safety profiles now |
| [M30](30-board-reimplementation.md#local-connections-and-document-persistence-plan--2026-11-02), [M34](34-programming-model.md) | Board operations/reactivity and automatic managed local data access (#326/#332/#335); application composition consumers | Supply authorized definition/progress/outcome reads through existing observation owners, with freshness and incomplete evidence. Keep inspection read-only. Planned workbook saves use separate public Document writes after M7/M9 gates; neither saving nor observation claims/settles Queue work. Application goals/delegation/policy remain outside the kernel |
| [M17/M18/M40 workload consumers](README.md#terrestrial-and-orbital-logistics--issue-358), Planned extensions | #358 adds delayed telemetry, time-windowed logistics and long-lived planning work to the roadmap | Preserve schema-bound event time, finite coverage, exact original claims and explicit delay/expiry policy. Spatial interpolation, route/mission policy and physical effects remain with those owners/applications, not Queue scheduling or kernel authority; these future workloads do not gate the first M6 handler |
| [M44](44-qualification-and-benchmarks.md), [M45](45-releases.md); #350/#352 merged | Matching-definition installed artifacts and portable/static release-fixture repairs | Keep runtime, shared libraries, SDKs and proof helpers from the selected revision. Artifact preparation fixes supply no runtime pass. Broader release/platform/provider evidence remains separate from focused M6 gates |

These are interface gates rather than whole-milestone dependencies. In particular,
M7 can implement its participant against the existing mixed owner; M9 can expose
qualified typed operations; M12 can use qualified native decisions; none needs
the entire Station migration to finish first. Conversely, M30's draft-saving
profile needs M7's public Document lifecycle, not all M6 workload SQL. The M7 C5
participant and C7 consumer gates still block complete removal of the old
Document-backed Station paths; do not turn that narrower Board prerequisite into
an excuse for a second Document authority.

#### Contract decisions before dependent implementation

Retain R0's identity, authority and retention invariants. Resolve the following
remaining decisions in the owning [Stream](../../contracts/STREAM_V1.md),
[Queue](../../contracts/QUEUE_V1.md), [SQL result](../../contracts/SQL_RESULTS_V1.md),
[SQL session](../../contracts/SQL_SESSION_V1.md),
[Station](../../contracts/STATION_V1.md) and
[state](../../contracts/STATE_V1.md) contracts before exposing each slice.

| Decision | Selected direction and acceptance obligation |
| --- | --- |
| Execution domain | Local disk-backed catalog, branch one for log work, explicit logical partitions and the existing common decision domain. Preserve separately supported immutable Table branches; reject unsupported cross-branch/distributed composition |
| Timed work | Validate the trusted interval and current lease under the publication guard; retain accepted clock floors. Fix work on the critical path rather than extending leases/deadlines or weakening time checks to make a proof pass |
| Admission uncertainty | Preserve #359's distinction between preparation failure and possibly accepted token binding. Workload status must carry original typed evidence; do not reuse the non-workload pending projection to manufacture success, absence or a new token |
| SQL WAIT | Persist the original consume/claim and SQL wait policy before dispatch; distinguish immutable native identity from each bounded wait attempt. Choose explicit same-token resume after timeout/service loss; background recovery observes original receipts or executes an explicitly requested cancellation, never starts an ordinary non-waiting consume/claim. A timeout is a nonterminal observation, not an empty result, success receipt or durable rejection; specify its shared result/status carriage before syntax admission |
| Group progress (delivered) | Preserve SGH1 assignment/checkpoint binding and SPH1 authenticated interval handoff through the original read. Extend waits/mixed SQL around these exact owners. Never accept a bare caller-chosen offset or returned row count as traversal evidence |
| Filtered acquisition | Bind a deterministic typed predicate before native selection. A failing FIFO head still blocks its key; a later matching item cannot leapfrog it. Search limits yield explicit incomplete/refused work, not a false empty selection. Post-claim display filtering cannot hide acquired messages |
| Lease renewal (delivered) | Preserve one typed row containing the renewed binary `_receipt_handle`, bound to the original accepted settlement through M4's result/evidence types. Reopening returns the same handle, even if no longer live; old handles cannot authorize fresh settlement after the lease changes. Wait work requires no renewal redesign |
| Transactional consumption | Acquisition is a separately accepted claim; the later transaction composes ACK, state and outputs. Abort leaves that acquisition subject to explicit settlement/expiry. Offset settlement similarly requires authentic read coverage; no handler-local counter substitutes |
| Station identity and authority | Retain stable actor/call identity, authority-derived origin, original destinations, activation generation and permanent retirement. Queue lease authority and execution ownership are independent guards checked at decision |
| Runtime rollout | Develop private replacement modules, then activate and remove superseded public paths in one coordinated current-v1 cutover. No v2, fallback decoder, parallel writable runtime or automatic history reset |
| Candidate ownership | Select M12's transaction candidate, replaceable progress or protected original owner according to the record's lifetime; preserve registration/readiness/attachment/closure and retained traversal. Specify additional runtime families before collection; abort, retirement, read close and terminal Queue bits are distinct from deletion authority |
| Effects and retention | Atomic intent publication does not make remote execution atomic. Preserve unknown outcomes, recorded attempts, secret references and connector retry policy. Unlimited retention stays default; terminal bits alone authorize no deletion |

For any incompatible wire, stored framework or ABI change, replace the mandatory
shared definition and regenerate all affected schemas, independent fixtures and
binding resources together. Use the definition from the integrated source; the
hash in an older checkpoint is historical evidence. Do not default a missing
persisted field to today's interpretation. Keep release VERSION independent.

#### Delivery order and review boundaries

The batch numbers retain the earlier plan's R-owner mapping. Each batch can span
several scoped commits; contracts, implementation, affected consumers and their
acceptance evidence form the review unit. These are delivery gates, not calendar
estimates.

| Batch | Owners | Start gate | Reviewable exit |
| --- | --- | --- | --- |
| 0 | R0/R1/R3/R4/R6/R10 | Original Queue records observed; later setup passes coexist with earlier failed/uncertain cases | Distinct maintenance, setup and BEGIN cases resolved with controlled regressions and original identities; unexplained failures or uncertain outcomes keep this exit open |
| 1 | R9 | Existing drivers; current-definition controls; Batch 0 for blocked profiles | All six log profiles plus required extended scenarios and preserved Station comparison, with measured budgets |
| 2 | R0/R4/R5 | Existing mixed/DLQ owners | Complete common-decision faults, correspondence and integrated automatic transfer proof |
| 3 | R0/R6 | Existing workload results/closures, delivered group coverage and ACK/NACK/renewal, latest admission tracking | Wait contract/recovery first, then predicate and mixed-statement semantics with shared caller composition |
| 4a–4d | R3/R4/R6 | Batch 3 per verb; Batch 2 for mixed SQL; 4a.1 and 4b.1 delivered | Queue WAIT (4b.2) and Stream WAIT (4a.2) implemented; native predicates (4b.3), finite TVF (4c), mixed SQL (4d) as separate units; groups/offsets and renewal remain regression gates |
| 5 | R0/R7 | Batch 2, replacement contracts, saved Station baseline | One real handler commits inbox ACK, Table/KV state, journal and output together |
| 6 | R7 | Batch 5 | Durable calls, names, timers and supervision migrated |
| 7 | R8 | Batches 5–6, owner gates for affected consumers | Effects/SDKs/query consumers migrated; replacement activated and old delivery removed |
| 8 | R9 with M3/M8 | Begin contracts/attribution now; Batch 1 comparisons | Account-wide token/partition commit, TRUNCATE and matched Table latency evidence |
| 9 | R0–R10 | All preceding applicable exits | Common-revision caller/fault/resource/provider qualification and documented completion |

The runtime path is **2 → 5 → 6 → 7 → 9**. The SQL path is
**3 → 4a/4b/4c → 9**, with **2 + 3 → 4d → 9** for mixed SQL.
Batches 0, 1 and 8 also gate completion. Delivered group/offset work supplies
Stream progress evidence; predicate support is not a prerequisite for unfiltered waits.
Finite TVF work uses existing retained readers and can proceed once its own
contract is fixed. Station uses typed callers and does not
wait for SQL syntax; SQL does not wait for Station. Baseline diagnosis, contract
work and participant work can progress independently, but measurements run
without concurrent heavy builds/fault suites. Do not activate a dependent path
while its authority or recovery gate remains failed.

#### Batch 0 — diagnose the remaining maintenance and recovery failure

**Owners:** native maintenance/activation and WAL recovery, `QueuePartition`,
Queue index/bitmap readers, and the existing installed Table/Queue and SQL drivers.
The reachable-candidate, verified-cache and profile 4 replay improvements and
the initial clean-lane fixture repairs have landed. This batch does not repeat
their implementation.

Keep three distinct case families: the preserved Queue maintenance/
terminal-retention failure, workload-token/result setup timeouts, and the
integrated SQL gateway's uncertain MySQL BEGIN. Later M7 collection/closure
qualification passes both unchanged setup deadlines. Use that source as a
control; it neither diagnoses the earlier timeouts nor settles the original
BEGIN. The local setup cancellation with no captured reply also stays uncertain.
The matching-binary read-only observation and joined proxy teardown are already
recorded. #359 changes collector batching, resident mark pages, Catalog view
reuse and SQL acceptance reporting; inspect those changes as hypotheses against
controlled cases. Apply the same discipline to #362's lane coordination, #381's
foreground conflict recovery and #384's publication changes: none of their merges
establishes a cause for these particular failures.

1. Reproduce the recorded cases with matching source/definition/binary/configuration
   manifests. Preserve original requests and receipts. Inspect old failed work
   only with its compatible build; a new installation is a separate regression
   run, not settlement of the old operation. Start with the `e8f5cf5c6`
   installation recorded in the storage/query ledger: reuse the observed original
   enqueue/claim/payload and establish the still-missing terminal/maintenance
   evidence through public reads, without fabricating an ACK or replaying SQL
   with a new token. For each result-setup timeout, locate the last saved operation
   and its actual receipt; the uncaptured cancellation reply remains uncertain.
2. Attribute native `tail` recovery, maintenance request/lock wait, actual durable
   progress, authority time, cancellation/join and control-reserve availability.
   Reproduce isolated operation and controlled competing maintenance separately.
   Retain `WalRecoveryRequired` as a real readiness boundary. Do not treat a
   recovered cache, a timeout or background-worker liveness as completion.
3. If a defect reproduces, add an independent failing oracle and fix its owner;
   otherwise retain the original failure as unexplained and keep its closure
   gate open. Preserve fixed deadlines, lease durations, trusted-clock bounds,
   cache budgets and first-publication barriers. Never convert maintenance load
   into permission to skip accepted history or increase resident cardinality.
4. Re-run the exact 65-row claim, original result reopen, binary receipt and ACK
   with normal limits, including service/node replacement. The claim result must
   cross bounded batches without reselection or implicit renewal; an accepted
   empty result must remain empty after later enqueue.
5. Re-run the large Queue workload's first original-operation lookup after restart
   under its 30-second logical budget. Preserve the passing profile 4 regression
   and the already-repaired mixed workspace replay adapter. Run
   `just test::direct-table-service queues` independently of heavy qualification;
   add an explicit pressure schedule to test the contention hypothesis rather
   than relying on accidental concurrent builds.
6. Separate setup from result recovery in `direct-workload-result` attribution,
   retaining the original setup cardinality and 180-second deadline. Run the
   unchanged installed result schedule with matched current artifacts and ordinary
   maintenance. A setup pass must reach all original result/revocation assertions;
   a setup timeout supplies no result-recovery pass. Include #359's admission
   boundary cases without weakening unknown-outcome handling for workload tokens.
7. Preserve `direct-workload-token`'s 257 distinct cancellations per partition
   and unchanged 180-second preparation deadline. Compare its failed and passed
   sources/configurations without reducing the cold-recovery threshold. For the
   recorded MySQL BEGIN, inspect the saved original token with compatible
   artifacts before any new transaction; unknown is neither rollback nor rejection.
   Re-run the SQL gateway fault profile and record the owner conflict/timeout
   boundary actually reached, independently of workload setup and Queue retention.

**PR units:** original-outcome investigation and independent regression; any
demonstrated owner fix with disk/recovery cases; installed evidence. Commit subjects
use `test(queue)`, `perf(storage)` or `fix(queue)` according to the actual change.

**Exit:** the remaining failure is explained with a controlled regression and
the original observation/operation status is recorded; affected claim/ACK,
maintenance and cold-recovery schedules pass under unchanged controls. If an
original outcome or cause cannot be established, name that remaining gap rather
than marking this exit complete. This gate does not qualify all six baseline profiles.

#### Batch 1 — complete baselines and freeze resource budgets

**Owners:** [log workload](../../tests/performance/storage/log_runtime.md),
[Station workload](../../tests/performance/load/station_turn.md), existing console
latency driver and the performance ledger.

1. Reuse the registered harnesses. Finish all six Stream/Queue profiles with
   independent retained readback after restart. Preserve the passed Station
   baseline and repeat its logical workload on the selected comparison revision
   before replacing the runtime. Do not substitute admission/drain throughput
   for real handler commit latency. The current log driver uses a bare node
   without automatic maintenance: retain it as the frozen control and add a
   distinct ordinary installed-server profile with default maintenance. Neither
   a graceful restart nor a process-cold owner proves a cold OS cache or power loss.
   Freeze runtime, shared libraries, SDKs, drivers and the new definition together.
   Compare a fresh control and candidate installation; never open the retained
   earlier-definition failures with current binaries. If comparing the future
   Station cutover across definitions, use an explicitly reviewed two-definition
   comparison manifest and identical workload/oracle, retaining ordinary reporter
   mismatch rejection.
2. Add separate hot-tail, sealed/cold, producer retry, group coverage, empty wait,
   wakeup, delayed visibility, lease-expiry and saturation profiles. Separate
   sequential latency from offered load and concurrent workers. Include FIFO
   over 64 keys and a hot key, long/collated keys and cache overflow.
3. Freeze explicit per-operation bytes/rows/examined offsets, resident workspace,
   slab/cache, active handler/lease/waiter, timer work and control-reserve budgets.
   Measure retained population above caches; measure startup/recovery work
   separately from warmed operations. Reclamation eligibility can be constant
   time from verified summaries; actual retained-graph collection remains bounded
   traversal, not a claimed constant-time full cleanup.
4. Add counting-allocator checks to warmed owner paths changed by M6. Cover
   tail reads, claims, settlement and transaction preparation with reusable
   scratch/output ownership. Identify the measured boundary; client allocation
   counts alone do not establish zero server allocations. Keep unrelated M13
   subsystem redesign outside this change.
5. Report raw samples, successful/refused/failed/unknown counts, p50 and supported
   p95/p99, peak memory, allocation attempts/bytes and available CPU/storage
   counters. Record unmeasured counters. Retain at least 20 successful samples
   for p95 and 100 for p99; a failed required operation fails that profile.
6. Set regression budgets from these measurements and the declared workload
   policy before optimization. Keep Table's existing numeric targets; introduce
   no guessed absolute Stream/Queue/Station latency promise.

**Exit:** complete reproducible log and Station comparison reports, with no
missing required profiles, and explicit resource/regression budgets for later
batches. Failed-run observations remain useful evidence but not a passing baseline.

#### Batch 2 — qualify the existing mixed and automatic DLQ owners

**Owners:** `DirectTransaction*`, `TransactionDirectory`,
`TransactionDecisionLog`, `LogTransaction`, retained-root traversal and the
protected Queue transfer worker. Use the existing coordinator and node scheduling.

1. Exercise Table/KV changes, Stream/Queue append, Queue ACK and authenticated
   Stream progress in one decision. Cover repeated statements, duplicate/conflicting
   tokens, savepoints, abort, absent-key guards and multiple statements touching
   one partition. Preserve the admitted participant and operation limits.
2. Inject faults before/after every preparation barrier, decision append and
   lost reply, participant finalization and cleanup. Delay one participant and
   read through real public callers; neither a half-result nor partial settlement
   may be disclosed. Recovery after a committed decision finishes that decision
   without handlers, current-time reinterpretation or external dispatch.
3. Revoke rights or change activation/definition/lease state between preparation
   and decision. Include lease expiry without reassignment and expiry during
   preparation. Abort/no-decision work must not make outputs visible; an accepted
   decision must remain recoverable after later expiry or revocation, with current
   rights still required for disclosure.
4. Expand the existing finite models and concrete replay for Stream progress,
   Queue leases and mixed decisions with guard-removal negative controls. State
   time, storage and scheduler assumptions. A repaired workspace model alone is
   not correspondence for the Queue owner or conditional progress under load.
5. Extend the delivered automatic DLQ proof across competing maintenance workers,
   worker/account replacement, destination rename/DROP/policy change, capacity
   refusal and source exhaustion. Recover the protected original transfer before
   selecting fresh work. A recorded failed/aborted attempt remains inspectable;
   it cannot silently become a new attempt to another destination.
6. Combine pending preparations, open claims, timer merge roots, old read cuts
   and source/destination payloads with trim/collection and data/control saturation.
   Verify checkpoint/reopen and fair bounded progress under the existing shared
   maintenance memory envelope, without retaining the durable population in RAM.
7. Include M12's `DirectTransactionRecord` ownership in those schedules: lost
   reservation/readiness replies, registration before a collector cut with
   creation during grace, frozen-owner late writes, and abort after participant
   preparation. A committed decision retains its candidate pages/manifest;
   collection after abort requires completed authoritative cleanup. Inspect the
   original decision and read retained results after collection. Do not infer
   safety from a decreased object count or reclaim generic work records.
8. Re-run retained-root/mark/grace schedules against #359's changed collectors,
   reusing #355's one-page acquisition/closure method as a starting oracle. Add
   log preparations, open claims, released payloads, independent immutable Table
   fork pins and multi-row managed candidates. Verify exact original contents and
   continued collection of a known orphan; a collector step count or lower object
   count alone establishes neither safety nor liveness.
9. Extend those schedules to CPR1 replacement and SOR1 attachment/closure,
   including creation after a collector cut, lost readiness replies, a late
   writer after closure and retained terminal lookup after byte collection.
   Reuse M7's retained Document membership/head-page evidence when C5 joins;
   neither independent Table forks nor independent Document cuts imply a common
   transaction cut. Preserve #384's named-publication durability/fault boundary
   when preparing or reclaiming new runtime artifacts.

M7 C5 supplies a separate Document participant packet: partition-aware common
cuts, private logical changes/raw-part roots, prepare/finalize and savepoint
behavior. Qualify Table + Document + Queue ACK + Stream append using this same
decision owner before the Document-backed Station consumer joins Batch 7. The
new ordered-tree storage path does not remove those rejection gates by itself.

**PR units:** model/owner fault correspondence; combined maintenance/retained-root
proof; installed mixed and automatic-transfer regression. No new DLQ coordinator
or second discovery service is required.

**Exit:** all state, append and settlement effects share one original decision;
terminal source transfer requires destination durability; original outcomes and
protected payloads survive faults and replacement. Record component, installed,
formal and resource evidence separately.

#### Batch 3 — finish shared workload contracts and caller composition

**Owners:** neutral workload/lease/progress types, `DirectWorkloadIntent`,
`DirectWorkloadResult`, SQL results/service/client and M9's existing Context/store.

1. Keep delivered durable closure/cancellation, original-result reopening,
   receipt-bound ACK/NACK/renewal and SGH1/SPH1 group progress. Define SQL WAIT
   timeout/resume/recovery first, then native acquisition predicates and mixed
   SQL statement attribution before their compiler/service integration.
2. Persist complete canonical requests before dispatch, including parameters,
   exact interpretation, original native identity and any projection/predicate.
   Resume the original owner after lost replies. Missing receipt, recovering
   owner, stopped wait and durable rejection remain distinct outcomes.
3. Preserve delivered empty/partial/terminal consumption metadata and interval
   settlement after a SQL LIMIT. Extend its proof through wait/resume and mixed
   SQL: both endpoints come from the same live read, while display exhaustion
   and filtered row counts establish no coverage. Keep pin release explicit and
   independent of ACK/offset progress.
4. Compose saved log attempts, result readers and native transactions through the
   existing shared client ownership model. Coordinate M9's handles and recovery
   adapters; do not add per-language recovery state machines or another recovery
   store. Close local buffers deterministically without settling durable work.
5. Update generated types, independent fixtures, parser capability inventories
   and all affected protocol consumers in each coherent current-v1 change.
   Preserve M10 interpretation descriptors and M12 workload/dataflow tag separation.
6. Extend #359's before/after-binding fault controls to the new workload kinds.
   A failure before possible acceptance can return its typed refusal; binding
   loss preserves the original token even when no operation ID was observed.
   Keep result availability separate from settlement. Specify how service
   recovery handles a parked/timed-out native wait; generic `advance` must not
   execute it as a plain claim/consume and thereby accept an unintended empty cut.

**Exit:** source-bound requests survive caller/service replacement; no result
refetch mutates or renews work; current rights are checked after buffering,
including repeated/empty/terminal output. Each newly admitted semantic has an
independent malformed/foreign-definition fixture and a complete recovery path.

#### Batch 4 — finish workload SQL and the analytical bridge

Each slice includes contract-approved grammar, compiler/corpus diagnostics,
Catalog binding, shared service/client integration, actual native SQL/console/
PostgreSQL/MySQL callers and the owning public references. Existing append,
positional/grouped consume, offset settlement, claim, ACK/NACK and original
renewal results form the regression baseline. Extend the existing owners, not a transport-specific
workload runner.

**4a — Stream groups, waits and offset settlement (R3/R6).**

**4a.1 is delivered** by #367; retain it as a regression gate. Its
[qualification](../history/qualification/query.md#sql-stream-groups-and-authenticated-offsets--2026-11-03)
does not close **4a.2** (bounded WAIT), automatic assignment/rebalancing or a
continuous-query service. Preserve explicit native assignment and read release.

The implementation owners are `LogConsumeSql`, `DirectLogPreparedConsume`,
`DirectLogPreparedOffset`, `DirectWorkloadIntent`/`DirectWorkloadResult`,
`WorkloadRead`, `Statement` and the shared result/client packages:

| Delivered boundary | Implementation to preserve | Regression obligation |
| --- | --- | --- |
| Assignment and descriptors | SGH1 binds exact target, group ID, generation, principal and expected checkpoint; SPH1 carries owner-authenticated read progress | Independent fixtures reject foreign definitions and forged/mismatched cursors; descriptors grant no assignment or permission |
| Grouped consume | Original finite read starts at the checkpoint; shared completion carries interval coverage separately from row count | LIMIT 0, filtered/empty results, partial LIMIT and repeated fetch; reassignment fences delivery/reopening without rewriting the original outcome |
| Offset settlement | `COMMIT OFFSET ... RECEIPT` uses the native owner and original Catalog token | Lost replies, replacement, stale checkpoint/generation, released reads, forged MAC and buffered revocation through all four SQL callers; close neither settles nor releases |

For **4a.2**, reuse 4b.2's shared wait recovery/result contract and dispatch the
existing native Stream wait with the exact consume request. Wait for the declared
offset frontier, not a matching payload or a row-count threshold. Test explicit
upper/open-ended bounds, register/recheck races, publication at timeout,
cancellation, revocation/reassignment while parked and saturation. A successful
wait yields one finite retained cut; later appends never extend it. Preserve
observed high watermark/lag attribution and keep data locks out of parked work.
The [next-slice plan](#next-slice-sql-stream-wait-4a2--2026-11-05) fixes the
SQL/native boundary: existing SQL upper-offset predicates remain filters;
explicit native upper-frontier waits remain native regression coverage.

- Extend the delivered offset regression through waited reads, compaction gaps
  and released/unavailable history. Reopening an accepted wait result must return
  the original finite read without waiting or assigning again.
- Qualify producer-sequence duplicate/conflicting requests and declared Arrow
  batch ingress without claiming unsupported Flight or cross-partition append.

**4b — Queue acquisition, waits, NACK and renewal (R4/R6).**

NACK with an optional absolute `visible_at` is delivered by #336; receipt-returning
renewal is delivered by #341. Preserve both as settlement regressions; reason
strings and relative-delay operands are not current native capabilities.
Unfiltered WAIT (**4b.2**) now uses the shared original-operation contract below.
Native predicate selection (**4b.3**) remains a separate review unit after its
Batch 3 acquisition contract.

**4b.1 — Original renewed lease through SQL (delivered; regression gate).**

`DirectLogPreparedSettlement` now freezes the descriptor-only result projection;
`DirectWorkloadResult` serves a `renewal` selection and `WorkloadRead` delivers
the original binary `_receipt_handle`. Preserve the
[executed source-specific qualification](../history/qualification/query.md#sql-queue-renewal-original-results--2026-11-02)
and [post-merge results and failures](../history/qualification/query.md#post-merge-validation-and-fault-proxy-cleanup--2026-11-02).
No renewal feature implementation remains in this unit; requalify its behavior
when changing the shared result, admission, definition or runtime boundaries.

Required regressions: the one-row descriptor survives scratch reset and remains
identical after another renewal, compatible ALTER, expiry, ACK, DROP or restart;
missing receipts stay unresolved; rejected renewals produce no success row.
Fresh settlement with a superseded handle refuses while an exact retry recovers
its original outcome. Preserve parameter-buffer destruction, lost execute/fetch
responses and after-buffer revocation across all four SQL callers. Descriptor
disclosure requires settlement inspection rights and supplies no payload access
or proof of current lease liveness.

Keep the compiler's existing receipt-expiry-plus-duration interpretation explicit;
do not replace it with a retry-time deadline. Validate the native maximum duration
and live-lease rule at publication. Refetch, early close, local cancellation and
delivery failure perform no renewal, settlement or payload-read release. Keep
renewal outside attached interactive transactions until a participant contract
explicitly admits it. Preserving ACK/NACK command shape while adding a renewal
row result is an extension of M4's shared model, not a console-only protocol.

The renewal cutover's earlier definition remains historical attribution; current
artifacts use the integrated definition above. Keep foreign/missing-definition
refusal and generated fixture parity when later incompatible changes land.

**4b.2/4b.3 — Wait and predicate acquisition.**

The selected **4b.2** profile now freezes a mandatory nullable `wait_ms` in
`DirectWorkloadIntent`. A Queue WAIT uses the native 1–1000 ms attempt bound,
exact partition, claim maximum, lease policy and unfiltered result projection.
A timeout leaves the SQL operation pending with typed `Workload.Wait` evidence;
only the actual timeout response carries its cut. Passive status, same-token
execute and background recovery cannot claim later arrivals. Explicit workload
resume borrows the data lane and reuses the saved native operation; cancellation
and accepted-receipt replay retain their native owners. PostgreSQL returns
SQLSTATE 57014; MySQL maps it to error 1317 / SQLSTATE 70100. Both include the
original operation ID when no claim completed; the
console emits an unresolved JSON outcome and exits nonzero. Current syntax and
caller semantics live in the [SQL reference](../handbook/reference/sql/streaming.md#wait-for-eligible-queue-work)
and [session contract](../../contracts/SQL_SESSION_V1.md#queue-wait-attempts).

The current-v1 cutover replaces the definition and regenerates schemas, bindings
and signed fixtures. Missing saved wait policy and foreign definitions reject.
The Catalog tests cover owned parameters, allocation failure and restored intent
identity; shared-client peer tests cover lost wait/resume replies and foreign
observations. The installed [WAIT schedule](../../tests/interfaces/sql_sessions/waits.py)
is included in the full log-session gate and also has a focused selector. It
checks pending timeout, late arrival, original replay, replacement, cancellation,
revocation and caller-specific carriage. An arrival that loses the timeout race
requires explicit same-original resume. These test definitions are acceptance
obligations; executed commands and outcomes must accompany the implementation PR.
Native saturation, lease algorithms and broader milestone profiles retain their
independent qualification owners.

The review units below remain the regression map for **4b.2** and prerequisites
for the planned **4b.3** extension. Stream WAIT is delivered by the separate
**4a.2** unit above.

| Review unit | Owning change | Required exit |
| --- | --- | --- |
| Wait contract and fixtures | Extend Stream/Queue, direct workload and shared SQL session/result contracts with canonical wait policy, transient attempt deadline, timeout observation, explicit same-token resume and durable closure | Model/fixtures distinguish no native receipt, accepted empty claim, accepted nonempty claim, stopped wait, durable refusal and lost response. Specify carriage for native SQL, console, PostgreSQL and MySQL without reporting a timeout as successful empty completion |
| Saved work and recovery | Extend `DirectWorkloadIntent` and `WorkloadOperations`; adapt `DatabaseRuntime` and the shared SQL caller's saved-attempt path | Receipt-first lookup always wins. Passive recovery after timeout/service restart cannot call ordinary claim/consume. Explicit resume invokes native wait with the same operation; cancellation races through the existing native closure owner |
| Admission and parking | Extend `DirectLogPreparedClaim`, `Statement` and SQL service scheduling through the existing native Queue waiter | Admit unfiltered routed WAIT only after the contract is executable. Park without data locks, respect native/declaration waiter bounds and reserve control capacity. Session loss cancels/joins local work without claiming durable rollback |
| Original result and installed proof | Reuse `DirectWorkloadResult`/`WorkloadRead`, SQL results/client and the existing installed log-session/fault drivers | Lost wait/execute/fetch responses, timeout/enqueue races, explicit resume, accepted empty/nonempty replay, replacement and post-buffer revocation pass through all four callers; no reselection, implicit renewal or hidden ACK |

Bind the SQL wait policy into the saved canonical request/fingerprint. A resumed
attempt may use a fresh bounded transport deadline but must not replace the
native operation, frozen definition, routing, claim maximum or lease duration.
When a native response is lost, retain uncertainty until original lookup or
explicit native cancellation establishes an outcome; absence alone does not
fence a request still in flight. Reuse ordinary result delivery only once the
original claim/read actually exists. Reject unsupported wire carriage until its
shared adapter can preserve those distinctions.

Use these acceptance cases across 4b.2 and 4b.3:

- Add native deterministic predicate selection before SQL exposes it. Bind
  parameters/schema/collation and bound examined candidates independently of
  acquired/delivered rows. Preserve canonical FIFO head blocking and unrelated
  key progress, including hash collisions and long keys.
- Add claim WAIT using the native waiter owner and original operation. Distinguish
  timeout with no accepted claim, accepted empty claim, incomplete selection and
  delivery of an accepted selection whose leases have since expired.
  Preserve the native 1–1000 ms attempt bound, four wait lanes and shared 64
  Stream/Queue registrations, plus smaller declaration limits. Test final
  authorized rechecks at timeout and ensure session cancellation/shutdown joins
  parked work without blocking unrelated control. A SQL timeout must not trigger
  unconditional background acquisition under the original token.
- Reuse delivered NACK scheduling and 4b.1's exact renewal results. Preserve
  current claimant/settle rights, compatible policy edits, expiry/renewal races
  and original outcome recovery. Any later NACK metadata needs native semantics
  and evidence before SQL admission.
- Re-run delayed retry/exhaustion/DLQ and the 65-row bounded-result case through
  all four SQL callers. Result close or repeated fetch performs no settlement.

**4c — Finite retained `STREAM_SLICE` (R3/R6; M12 handoff).**

- Add a real catalog-bound Fuze source over one retained definition and finite
  offset/time range. Reuse existing TVF semantics and native readers, without
  materializing the whole Stream or using the in-memory evaluator as storage.
- Pin hot and sealed placements; preserve sparse offsets, tombstones, half-open
  timestamp semantics and event-time disorder. Push only sound predicates/zone
  pruning under the declared type/codec/collation; preserve owned Batch lifetimes.
  Reuse M14's shared encoded traversal and byte/row budgets where applicable;
  a cached dictionary match set must not outlive its exact reader/interpretation.
  Reuse `PreparedPredicate` for owned literals and comparison semantics where
  compatible, charging its real arena reserve. The current Table implementation
  is a reusable component, not proof that log payload evaluation or acquisition
  predicates are integrated.
- Integrate bounded projections, filters and supported finite joins. Record each
  source cut; independent cuts are not a global atomic snapshot. Close pins on
  success, early close and failure, preserving uncertain acquisitions.
  Use #383's shared grouping, HAVING, ordering and LIMIT operators where the
  new source meets their typed contracts; do not implement a Stream-only sorter
  or aggregator. Bound sort/aggregate state and preserve ordered failures,
  complete source coverage and current authorization before result disclosure.
- Prove no group/Queue progress changes, current rights after buffering, pin
  survival through compaction/restart and explicit unavailable-history failure.
  Hand this source and exact coverage to M12; continuous activation and complete
  transaction-to-WAL feed coverage remain its separate gates. Keep native source
  pages, Fuze batches, multi-row `DFP1` retained pages, wire batches and display
  windows independent; recent M12 page packing does not change a Stream cut.

**4d — Mixed SQL transactions (R5/R6).**

- Extend the existing transaction selection/workspace and statement lowering
  for supported log append and authenticated settlement participants. Preserve
  one statement sequence, provisional attribution, read/conflict guards,
  savepoints and original commit/abort recovery.
- Keep claim acquisition outside the attached transaction. Define how an exact
  receipt or Stream progress handoff is supplied to the later transaction.
  Do not route log work through Table SQL or independently autocommit it.
  Admit only executable participant kinds: the native mixed owner currently
  composes ACK and offset settlement, not NACK/renewal. Keep those combinations
  refused unless their own common-decision semantics are deliberately added.
- Prove state/output/settlement visibility, abort and savepoint rollback,
  disconnect/reattach, uncertain COMMIT and final lease/permission refusal through
  real callers. Document participants wait for M7's participant gate.

**Exit per slice:** executable public behavior, bounded complete delivery and
original-operation recovery, with explicit refusals for still-unsupported syntax,
types/transports and atomic domains. Parser or component TVF passes alone cannot
close a slice.

#### Batch 5 — implement one real transactional Station behavior

**Owners:** Station behavior/turn runner and bindings, declared actor records,
shared data callers and the qualified mixed decision owner.

1. Specify stable actor and definition identities, inbox/state/journal/outbox
   references, explicit dependencies, execution rights, activation fencing,
   retention roots and inspectable lifecycle. Resolve how existing PID identity
   and authenticated origins map to declared records without creating another
   permission authority. Idle actors use paged durable records, not resident slots.
   Map the current native PID/principal/generation and retirement checks to an
   enforceable transaction-decision guard. A self-reported actor row or Queue
   receipt cannot supply ownership. Qualify stale-worker and retired-actor
   rejection before exposing the replacement runner.
2. Build a private runner that claims a `key_fifo` inbox item, freezes its state
   basis, invokes the detached handler and stages Table/KV changes, replay journal,
   outgoing Stream/Queue intents and exact inbox ACK in one standard transaction.
   Keep scratch separate from retained output; enforce read/write/output budgets.
3. Check both activation ownership and the exact live input lease at decision.
   Preserve poisoned-read behavior and read/conflict guards. Handler errors,
   uncommitted drafts or capacity refusals publish no partial state or outputs;
   define an inspectable blocked/failure disposition and retry policy.
4. Persist the original transaction binding before uncertain submission. A new
   worker resolves it before rerunning the input or claiming a successor.
   After a proved abort, any permitted retry has explicit policy and identity;
   a local timeout or missing receipt does not prove abort.
   Use the existing transaction-owned staging contract for supported candidates,
   with explicit retained roots for actor definitions, input claims, pending
   decisions, journals and output intents. New record families need their own
   registration/closure rules before collection can remove them.
   Separate transaction-owned candidate bytes from replaceable recovery progress
   and original work. Reuse `DirectTransactionRecord`, `DirectProgressRecord`
   and `DirectOwnedRecord` only for lifetimes they support; do not store an actor's
   permanent identity in a collectible progress slot. Include attachment/closure
   races and receipt persistence after worker replacement in the recovery proof.
   Reuse M12's bounded multi-row candidate/page machinery only through its owning
   interfaces and schema; runtime journals and pending decisions retain their own
   declared identities. A `DFP1` result page is not an actor journal or authority
   record. Include candidate creation during collection and worker loss after
   decision but before receipt persistence in the first handler proof.
5. Exercise the saved 128-byte baseline workload, then a separately declared
   workload above 256 bytes and four changed keys. Use both Table and direct KV
   state. Document state joins only after M7 C5 passes the same decision gate.

**PR units:** replacement runtime contract/fixtures and migration inventory;
private actor lifecycle/runner; real installed handler with fault/resource proof.
Keep activation unexposed until Batch 7's coherent consumer cutover.

**Exit:** worker death before/after decision, stale activation, lease loss,
revocation, handler failure and restart preserve one committed state/output set
and exact input settlement. Recovery does not redispatch effects. Compare actual
turn latency/resources with Batch 1 under matched workloads.

#### Batch 6 — migrate durable Station services

Reuse declared data and the same turn commit; local futures, timer caches, names
and provider observations cannot become durable authority.

| Service | Implementation | Required installed recovery |
| --- | --- | --- |
| Calls/replies | Persist correlations, original authenticated origins/destinations, wait state and closed dispositions; keep late responses attributable | Caller/worker replacement, duplicate/late reply, timeout/completion race, local await cancellation and no duplicate callback |
| Timers/waits | Durable timer identity and scheduled Queue input; bounded wait registration, replay and closure | Time uncertainty, restart/downtime, enqueue-registration race, saturated notifications, duplicate wake and joined shutdown |
| Names/lifecycle | Conditional binding/rebinding, explicit inspection rights, suspension and permanent retirement | Stale cleanup cannot erase a successor binding; names cannot redirect accepted calls or revive retired actors |
| Supervision | Durable child intent, activation generation and observed outcomes; providers reconcile physical lifecycle | Lost spawn/stop reply, controller replacement, denied rights, capacity blockage and no resurrection from restored state |

**PR units:** calls/replies; timers; registry/lifecycle; supervision/controllers;
combined installed replacement proof. Port the existing failure-policy semantics
or explicitly replace them in the contract/cutover; do not silently weaken them.

**Exit:** every existing supported service's authority, identity and closure
behavior survives worker/controller replacement on the replacement runtime.

#### Batch 7 — migrate effects and consumers and activate the cutover

**Owners:** Station/connector bindings, SDKs, private Table/Query consumers,
query-host, runtime controllers, launchers/examples and public Board reads.

Start the removal inventory with these existing owners; expand it by references
before the cutover. The table names migration obligations, not delivered replacements.

| Existing surface | Replacement and gate | Consumers that must move together |
| --- | --- | --- |
| `transit-station` GenServer/Turn and native framework records | Batch 5 actor identity/guard and one mixed transaction; Batch 6 calls/timers/lifecycle | Station bindings/host, every existing SDK handler, controllers and installed applications |
| Private Table creation/write/statement/read helpers and `TableBridge` actions | Declared Table/KV plus exact retained sources and common-decision state/output/settlement | Query capture, foreign turn actions, SDK fixtures/examples and Board metadata; keep Catalog `DirectTableBridge` |
| `transit-station-document` service and Document worker | M7 C4/C5/C7 public lifecycle, participant and consumer gates | Document APIs, Query adapters, installation/bootstrap and connector Document consumers |
| Exchange and HTTP/gRPC/Flight connector workers | Declared intent/attempt/outcome records with authorized dispatch and explicit unknown-outcome policy | Connector bindings, capture/replay readers and installed fault suites |
| `transit-delivery` and query-host courier roles | Transactional outboxes, native Queue waits and bounded original-work discovery | Node/server composition, launchers, service configurations, tests and examples |
| Station-specific stored/wire/ABI declarations | One current-v1 definition and regenerated fixtures; old artifact refusal | Protocol/schema generators, signing fixtures, SDK resources, public reads and inspection renderers |

1. Maintain a concrete removal matrix: old module/ABI/action/executable/config,
   replacement owner, affected callers, persisted artifacts, contract definition,
   public documentation and proof. Include `TableCreation`, `TableWrite`,
   `TableStatement`, `TableReader`, private `TableBridge`/foreign turn actions,
   captured Query metadata and courier roles. Preserve the separate Catalog
   `DirectTableBridge`. Inventory low-level native process support explicitly;
   no old writable Station path may survive hidden behind a renamed helper.
2. Move effect intents, attempt identities and outcomes to declared data. Dispatch
   only after the intent decision and current destination/credential checks.
   Unknown remote outcomes remain unknown under connector policy; replay disables
   dispatch. M16's Document exchange representation is an explicit later owner,
   not permission to discard current capture or delay its consumer migration.
   M7's ordered raw-part storage and M16's verified MIME candidates can supply
   representation inputs; publication, linked Document revision/intent atomicity,
   transport attempts and unknown outcomes still need their owning contracts.
3. Migrate retained query/source/result metadata with original interpretation,
   pins and rights. Preserve M12's retained revisions and source attribution;
   no replay or renderer may relabel an earlier result with a newer definition.
4. Migrate all affected existing ABI/SDK consumers, examples and launcher/service
   configurations through shared Zig semantics. M9/M21's wider redesign is not
   an excuse to leave existing languages on an incompatible writable runtime.
   Coordinate Document-dependent consumers with M7 C7; if that gate is not met,
   full runtime removal and milestone completion remain blocked on named work.
5. Replace courier/poll delivery with Queue waits and durable recovery discovery.
   Handle lost/saturated notifications by bounded authoritative rechecks, not
   blind periodic whole-backlog scans. Measure idle requests/CPU and first-work
   latency; cancel and join every waiter at shutdown.
6. Expose definition, assignment/progress, lease/retry/DLQ and turn/effect outcomes
   through current-authorized public reads. Label snapshot/counter basis and
   incomplete observations. Board must not claim, ACK, mutate configuration or
   decode application payloads as part of inspection.
   Reuse M30's observation ownership, reconnect and current-policy boundaries;
   test the default managed local data connection as well as explicit overrides.
   Planned Document-backed workbook saves remain a separately authorized data
   operation and perform no SQL or Queue settlement implicitly.
7. Activate the replacement and remove superseded paths together under one
   current-v1 definition. Regenerate neutral contracts, signatures, ABI/schema
   resources, SDK fixtures, examples and installation inputs. Incompatible peers,
   stored requests and roots reject before execution; keep prior installations
   with their compatible binaries until an explicitly supported migration exists.
   Do not silently reset data, reinterpret history or leave fallback decoders.

**Exit:** actual supported consumers/examples run through the replacement, replay
performs zero external dispatch, original unknown effects remain inspectable,
and ordinary database operations still import/call no Station runtime. Re-run
existing applicable disk-backed Ursula and Substrate authority/readiness/recovery
profiles without claiming new distributed execution guarantees.

#### Batch 8 — close Table commit composition and latency

**Owners:** `DirectCatalog`, direct token/account binding, `TablePartition`, shared
transaction publication and M8's co-hosted SQL path, coordinated with M3 and #211.
Begin this work alongside the runtime batches; it remains an M6 completion gate.

1. Define/model account-wide token uniqueness before co-locating commitment.
   Concurrent reuse across partitions, object kinds, reconnects and statement
   types must resolve one winner or reject the conflicting canonical intent.
2. Combine eligible single-partition token identity, data mutation and original
   outcome in one authoritative WAL decision. Preserve separate boundaries for
   non-joining DDL/configuration. Secondary accounting/directory indexes may be
   reconstructed only from sufficient accepted evidence; never defer the sole
   durable identity or introduce an actor ledger.
3. Reuse bounded publication groups, staged objects and the delivered explicit
   current Table capture from #356. It selects one accepted cut under the frozen
   interpretation; exact historical acquisition and already accepted cuts retain
   their separate semantics. Do not repeat the former lookup/exact-pin retry
   redesign or turn current capture into a per-batch refresh.
   Remove measured redundant control/storage work on the co-hosted path while
   retaining current policy, fencing, pin recovery and first-publication barriers.
   Preserve M10 retained catalog/interpretation, M20 independent fork pins and
   M12 transaction-owned multi-row output roots. #359's reused Catalog view and
   restored data-log binding are regression controls for owner-lifetime changes.
4. Implement the [proposed TRUNCATE contract](#proposed-truncate-contract-for-implementation)
   through frozen Table intent, reset/history event, authoritative counts,
   shared command results and original-operation recovery. Empty Tables,
   retained predecessors, concurrent writes and retry after a later INSERT must
   retain their specified behavior. No DROP/recreate or immediate physical delete.
5. Run matched fresh/warm/post-write Table profiles with fixed durability,
   hardware/load attribution and retained raw failures. Distinguish one data WAL
   commit from total statement requests, staging and Catalog settlement.
   Share M8's F0/R1/M3/C4/D5/S6/E7/Q8 experiments and #347's opt-in owner counters
   instead of creating another scorecard. Rebaseline default-maintenance reads,
   post-write reads, managed successors and retained-history startup after
   #356/#359; retain earlier failed operations and their unresolved causes
   separately. Distinguish token admission, native completion, verified result
   delivery and pending-account cleanup. Counters include attempts, so neither
   a lower counter nor multi-row packing establishes fewer physical syncs or a
   latency win. Add Stream/Queue and Station timings only after their actual
   value/outcome/recovery oracles pass.
6. Retain the separate console latency and installed scenario gates now on main.
   Passing their budgets is required where affected, but does not discharge the
   19-ms/10–20-ms targets below. The nightly container campaign measures a frozen
   promoted image, not this checkout: follow its
   [campaign guide](../../tests/performance/load/containers.md) if extending it,
   keep one-/three-node campaigns sequential, and do not substitute client-routed
   independent authorities for distributed transaction or Station evidence. M13 owns
   the broader scorecard; this plan adds no new nightly workload or benchmark run.

**PR units:** token/routing contract and model; common WAL/reconstruction path;
read-after-write refinement; TRUNCATE; matched installed performance evidence.

**Exit:** eligible operations preserve account-wide original identity and one
partition commit, and meet the 19-ms INSERT and 10–20-ms warm SELECT objectives
with the 190-ms comparison retained. These are inherited acceptance objectives,
not measurements of this HEAD. Unmatched timing, startup improvements, weaker
durability or fewer requests alone do not close them.

#### Batch 9 — qualify one revision and promote supported behavior

Freeze one committed revision and matching definitions/binaries. Execute the
[R10 obligations](#r10-qualify-and-complete-the-current-v1-cutover) and the matrix
below, retaining explicit component, installed, formal and deployment scopes.
A failure remains open; neither unioning historical passes nor testing an easier
replacement workload establishes this revision's completion.

| Gate | Required observation | Starting regression owners |
| --- | --- | --- |
| Declaration/policy | Validate/apply/inspect/change/recover; denied access, rename/DROP and original tokens | `catalog`, `direct-log-token`, `sql-log-declarations` |
| Stream/read/results | Producer deduplication; hot/sealed/reopened finite coverage; groups/WAIT/offset; empty/multi-batch/partial LIMIT/early-close; authenticated handoff and after-buffer revocation | `direct-workload-token`, `direct-workload-result` and signed Stream/SQL suites extended for 4a/4c |
| Queue/scheduling | Original claim, ACK/NACK/renewal, FIFO/predicates, deadline/wakeup races, exhaustion/DLQ and exact receipt recovery; timed-out waits never become background empty claims | `direct-table-service queues`, `sessions-log` installed profile, owner/maintenance tests |
| Admission uncertainty | Pre-binding failure versus lost binding reply; original token without observed operation ID; workload pending/closed/result distinctions after service replacement | SQL session fault driver and `direct-workload-token`, extended from #359's exact boundary |
| Mixed decisions | Faults at every prepare/decision/finalize boundary; savepoints; stale lease/current-policy guards; no half-visibility | `direct-state-transaction`, `direct-mixed-transaction`, `direct-queue-transfer`, `direct-automatic-queue-transfer`, `sql-transactions` |
| Retention/resources | Missing/corrupt objects, checkpoint/trim, open claims/preparations, larger-than-cache data, bounded allocation/work and reserved control | `local-storage-faults`, `storage-io-faults`, storage/native maintenance suites |
| Owned candidates and retained revisions | Registration/creation/mark/grace races, prepared barrier/decision/abort cleanup, no late recreation; multi-row candidates, independent fork pins and runtime roots survive changed collection | Transaction-record catalog/native tests, `local-catalog`, `managed-tables` and mixed-decision fixtures extended for runtime roots |
| Runtime/effects | Real handler/services, replacement, retirement, recorded destinations, no replay dispatch and retained unknown outcomes | `station`, actual SDK/example/connector/launcher suites, new transactional runtime schedules |
| Formal correspondence | Stream progress, multi-key Queue/lease/DLQ, mixed/runtime transitions with negative controls and stated progress assumptions | `transaction-workspace-model`, `queue-lease-transaction-model`, new concrete replay bridges |
| Performance | Matched Table targets; all required log profiles; saved/replacement Station comparison and measured budgets | `console-latency`, `log-runtime-baseline`, `station-turn-baseline` |
| Compatibility/inspection | Current-definition rejection, generated resource parity, old artifact refusal and authorized read-only inspection | Contract/binding fixtures, affected SDK families, Board, installed binaries and provider proofs |

Commands in the table are existing `just test::` recipes unless described as an
owner/profile. `sessions-log` is a profile of the existing SQL session driver,
not a newly invented task. Extend/register missing proofs with their owning
domain and independent oracle before claiming coverage. Run them inside the
pinned development shell. Preserve the underlying driver's actual options,
normal deadlines and existing failure fixtures.

During implementation run the smallest owning checks, then affected committed-
source `just ci clean --lane NAME` checks before pushing. Final closure uses the
repository's complete required lane inventory at the same revision, including
core/storage-query, formal, interfaces, SDK families, browser, installation and
launchers, plus explicit applicable provider/deployment checks outside those
lanes. An incomplete lane or unavailable provider proof is not a pass. Performance
runs remain separate from heavy qualification workloads.

Every PR, including a plan-only update, first runs the repository's independent
baseline gates from the root:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

The install command prepares dependencies; only the check supplies a handbook
pass. The fast gate includes source links but cannot replace the production
handbook build. For implementation review units, add the checks selected by the
actual diff before opening/updating the PR:

| Changed boundary | Required additions |
| --- | --- |
| Public types, saved work, wire/ABI or generated resources | `just check contracts` plus dependent package/caller checks and affected clean lanes |
| SQL wait/source/transaction, console, server or gateway startup | `just test console-latency-gate` in the pinned `ci-experience` shell and `just test server-sql-types`, plus owning installed workload/fault checks and `interfaces-sql` |
| SQL scalar or PostgreSQL/MySQL adaptation | The [SQL interface validation loop](../../tasks/README.md#sql-interface-validation), including `just test sql-wire-contracts` and `just test sql-wire-types` |
| Storage/participant/runtime behavior | Owning disk/fault/model checks, then affected `core`/`storage-query` and caller/installation/provider lanes; a unit test does not qualify replacement or physical recovery |
| Board/browser contracts or handbook behavior | `just transit-board::check` and affected browser proofs, or the [handbook browser proof](../handbook/README.md#validation-and-hosting) for navigation/rendering/hosting changes |

Run added commands inside their pinned Nix shells with locked dependencies.
Record commands, source/definition, outcomes and omissions in each PR. Rerun
affected gates after further edits; do not push/open/update a PR with required
checks failing or incomplete. Planning alone needs no runtime suite and provides
no runtime evidence.

For every delivered slice, update its public reference/component/contract owner:
Streams, SQL streaming/results, Station, state, callers, retention, storage,
connectors and inspection as affected. Put mechanisms/reasoning in their existing
Internals topics under the scientific standard; do not require a roadmap to
understand supported behavior. Reconcile stale broad unsupported statements with
actual executable scope, while preserving dated historical evidence.

**Final review artifacts:** capability and removal inventory; shared-definition
and generated-consumer inventory; source-attributed raw proof records; resource
budgets and comparative reports; public behavior/limits and explicit refusals;
and a checklist mapping every R0–R10 exit to executed evidence. Mark the milestone
and index `Completed` together only when no required behavior, consumer migration,
fault/provider schedule or performance gate remains open. This plan's link and
whitespace checks establish no runtime guarantee.

#### Review baseline after PR #303 — 2026-11-01

The earlier completion plan was based on merge `997fbfda9`, PR head `5ccf1493e`.
It identified the failing
[formal job](https://github.com/spoke-sh/transit/actions/runs/41281486165/job/124774306697),
where the workspace replay adapter treated `head.pending` as a state-only request,
and ordered budgets, mixed/DLQ proof, workload outcomes/SQL, Station/services,
consumer removal and Table latency closure. The source now contains the adapter
repair and the additional implementations assessed above. Its failure and other
incomplete runs retain their original attribution; the repair is not a combined
qualification pass.

That plan's excluded log-baseline prototype has since become a registered
harness, and the real Station baseline has executed. Workload outcome/result
ownership, append/positional SQL, routed claims/ACK and automatic DLQ have also
advanced. Their dated delivery records and qualification accounts remain the
evidence; the current batches qualify and extend those owners instead of
repeating the earlier implementation tasks. R0–R10 acceptance scope, including
Table latency and existing-consumer migration, is unchanged.

The earlier SQL delivery record retains these source-specific outcomes. Later
implementation rows do not convert pending installed checks into passes:

| Source | Delivered slice and recorded evidence |
| --- | --- |
| `a72ecf3107b75bf22020c6454185068eecaa2866` | Single-partition PRODUCE/ENQUEUE and original RETURNING passed the clean installed four-interface [append profile](../history/qualification/query.md#sql-append-admission-and-original-result-delivery--2026-11-01) |
| `9c48a5726` | Typed consumption preparation passed [compiler/independent-corpus checks](../history/qualification/query.md#typed-consumption-preparation--2026-11-01); SQL admission was still absent at that source |
| `02acf0253` | Authenticated intervals and original consumption passed [component/disk checks](../history/qualification/query.md#bounded-consumption-results-and-authenticated-intervals--2026-11-01); subsequent [installed recovery/partial settlement](../history/qualification/query.md#installed-original-results-and-partial-settlement) passed at the same definition |
| `b3300394e`, `a5965727d` | Pure positional Catalog binding, then SQL consumption admission passed [component/grammar checks](../history/qualification/query.md#positional-sql-consumption-admission--2026-11-01); the [installed profile](../history/qualification/query.md#installed-positional-consumption) records runtime and corrected-driver revisions separately |
| `0816018a7` | Pure claim preparation passed [20 independent cases and allocation/grammar checks](../history/qualification/query.md#queue-acquisition-preparation--2026-11-01); it did not enable native payload predicates |
| `00244c553` | Routed claims passed [component checks](../history/qualification/query.md#partition-routed-sql-queue-claims--2026-11-01); installed qualification remained pending |
| `9bb06504a` | Binary receipts and ACK passed [component/contract/grammar checks](../history/qualification/query.md#sql-queue-receipts-and-ack--2026-11-01); replacement-definition installed qualification remained pending |

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
  same partition, and that sealed `.tseg` queue segments reclaim only after
  explicit retention permits expiry and all retained read/recovery dependencies
  close. Terminal ACK bits alone never authorize deletion.
- **Transactional `Station` turns over Queues, Streams and Tables:** Prove that a
  `Station` runner first acquires a `key_fifo` inbox lease, then atomically ACKs
  that lease with declared `TABLE`/`KV` state changes (> 256 bytes and > 4 keys),
  journal and outbound messages/connector intents in one database transaction.
  A proved abort publishes none of that state/output/settlement; the separately
  accepted claim remains subject to explicit settlement or lease expiry.
  Resolve uncertain decisions before retry, and prove later redelivery under a
  higher `_lease_epoch` cannot duplicate committed output intents or require
  external `courier` polling. External attempts retain
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
