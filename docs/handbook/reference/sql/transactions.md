# Transactions

A transaction retains a common catalog and data cut, reads its own private Table
and direct KV changes, stages private Stream and Queue actions, and publishes one
commit or abort decision. Native SQL, the console, PostgreSQL and MySQL share
these controls through the database runtime. The supported domain is one local
catalog and branch, combining accessible Tables, row Documents, direct KV stores
and partitioned Streams/Queues under one fenced authority.

SQL `BEGIN` discovers `authorized_catalog_objects` under one stable catalog
basis: Tables and direct KV stores with current `READ` rights, plus Stream and
Queue partitions with current `READ`, `APPEND`, or `SETTLE` rights in
`SERIALIZABLE` read/write mode (or `READ` rights in `READ ONLY` mode;
source-captured Streams require `APPEND`). Append-only (`INSPECT` + `APPEND`)
and settle-only (`INSPECT` + `SETTLE`) principals can execute transactional
`PRODUCE INTO`, `ENQUEUE INTO`, `COMMIT OFFSET` and `ACK` without Stream/Queue
`READ` grants. Partitioned `causal_crdt` Document targets reject before
admission. See [Streams](../streams.md) for the log composition rules.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
UPDATE accounts SET balance = 80 WHERE id = 1;
PUT INTO account_cache KEY 'acct:1' VALUE '80';
SAVEPOINT adjusted;
UPDATE accounts SET balance = 70 WHERE id = 1;
ROLLBACK TO SAVEPOINT adjusted;
PRODUCE INTO account_events VALUES (1, 'debited');
ACK ON QUEUE settlement_jobs RECEIPT $1;
COMMIT;
```

`BEGIN`, `BEGIN WORK`, `BEGIN TRANSACTION` and `START TRANSACTION` select
serializable read/write execution by default. `READ ONLY` selects the same
retained-cut reads without mutations. `READ WRITE` and `ISOLATION LEVEL
SERIALIZABLE` can be explicit, in either order. Other isolation levels, nested
BEGIN, chaining and autocommit-off are unsupported. No operation implicitly
commits a transaction to accommodate unsupported work.

BEGIN selects the currently authorized catalog objects under one stable catalog
basis. Data includes committed, unflushed WAL changes. Later statements cannot
add a newly created or newly accessible object to that cut. Names and definitions
remain those captured at BEGIN; current permissions govern every read, buffered
batch and commit. Retaining a cut never preserves a revoked grant.

Supported statements are finite Table `SELECT`, `INSERT`, `UPDATE` and `DELETE`,
direct KV `GET`, `PUT` and `DELETE`, and Stream/Queue non-`RETURNING` `PRODUCE
INTO`, non-`RETURNING` `ENQUEUE INTO`, authenticated `COMMIT OFFSET` and
lease-fenced `ACK`. The selected relational join/group profile can read multiple
private Tables at the same revision, and private `GET` reads uncommitted KV
writes from the same workspace. DDL, `PRODUCE`/`ENQUEUE RETURNING`, `CONSUME`,
`STREAM_SLICE`, `CLAIM`, `NACK`, `EXTEND LEASE`, authorization/configuration
changes, captured queries and external effects fail with SQLSTATE `0A000`
without implicit autocommit. Metadata results keep their catalog/settings
observation; they do not invent a data snapshot. An error leaves the attached
session requiring ROLLBACK or ROLLBACK TO a saved point before further data work.

## Outcomes and conflicts

Table DML, KV `PUT`/`DELETE`, and non-`RETURNING` `PRODUCE INTO`/`ENQUEUE INTO`
matched/changed counts are **provisional**: they describe the completed
statement in the private workspace without fabricating public log offsets before
`COMMIT`. `COMMIT OFFSET` and `ACK` likewise complete provisionally without
relational row counts. `COMMIT` supplies the actual durable decision and makes
Table, KV, Stream and Queue changes visible together. Read results identify the
original cut and private workspace revision; their completion does not imply
transaction commit. Uncommitted Stream and Queue appends remain behind the
commit barrier and are not readable before `COMMIT`. Previously delivered rows
and counts cannot be retracted by rollback.

Serializable commits validate conservative whole-Table, KV and log logical
frontiers, including selected read dependencies, absent/predicate reads, live
Queue lease expiry/fencing, producer sequence fencing and consumer-group
generations. Concurrent changes on a selected Table, KV store or log partition
with a read or write dependency conflict (`40001`). Pure append-only or
settle-only log participants validate their staged actions, producer/lease/group
fences and definition stability without requiring `READ`. A failed validation
records abort through the original attempt. Physical flush, checkpointing,
compaction and pin bookkeeping do not constitute logical changes. This profile
does not claim distributed atomicity or strict real-time serializability.
Read-only transactions can finish on their retained cut despite later writes.

A decision and completed publication/pin cleanup are separate observations.
Preparation barriers prevent ordinary reads from treating an unfinished
participant publication as an independent current Table. Bounded background
recovery continues the original command through cleanup.

## Savepoints and cursors

`SAVEPOINT name` records private roots. `ROLLBACK TO [SAVEPOINT] name` restores
those roots, discards newer savepoints and keeps the named point. `RELEASE
[SAVEPOINT] name` removes the named point and newer points. The newest matching
name wins. Rollback can require several bounded owner calls; reads and COMMIT
refuse an incomplete rollback.

All accepted statement numbers, original requests, outcomes and conflict
dependencies remain recorded. Repeating a rolled-back statement's original token
returns its original provisional outcome without executing it again. Each
statement or savepoint control changes the workspace revision. Prior private
cursors cannot continue or disclose buffered rows at the newer revision. Closing
a cursor releases local traversal state, not the transaction's source pins.

## Session loss, recovery and bounds

The database owns accepted commands independently of temporary SQL sessions.
A deadline, cancellation, disconnect or session expiry does not prove rollback.
Cancellation stops waiting; an accepted transaction command can still complete.
Explicit ROLLBACK addresses the original attempt, and cannot reverse a recorded
commit. Inspect the original account/token or known operation before deciding
what to do after an uncertain reply. Never submit the SQL as new work to resolve
that uncertainty.
PostgreSQL/MySQL report SQLSTATE `25000` when ROLLBACK discovers an already
committed decision. A refused COMMIT reports SQLSTATE `40001` only after a known
abort; missing decision evidence remains uncertain.

Native command evidence includes a versioned transaction handle. After replacing
a SQL session, `Client.attachTransaction(handle)` explicitly attaches that same
transaction under current rights. Inspection alone does not attach a transaction
or restore an interrupted result cursor. Wire protocols report active/failed
state but do not carry native recovery handles; use authenticated native recovery
operations after losing a wire session.

Open transactions retain their pins until an explicit decision and cleanup;
session expiry does not delete accepted history or silently release their cuts.
The account's `transaction_limits` defaults to 16 MiB resident memory, 256 MiB
cumulative workspace staging, 100,000 selected participants, 10,000 statements
and 128 active savepoints. Savepoint controls have their own sequence bounded by
the statement limit. The node separately caps each request and aggregate pending
reservations. Capacity refusal is not expiry or abort. Private data and roots are
durable; retained collection size is independent of resident pages. Released
roots become eligible for physical collection separately from logical rollback.

The SQL caller checks fixed statement/control and savepoint ceilings before
admitting the next command. Accepted work that cannot advance because of storage
or workspace capacity keeps its original recovery identity. A replacement native
attachment can explicitly roll back a stalled lifetime; losing or cancelling a
wait never performs that rollback automatically.

The [direct transaction contract](../../../../contracts/DIRECT_TABLE_V1.md#signed-transaction-action)
defines owner operations and quotas. [Statement results](../../../../contracts/SQL_RESULTS_V1.md)
define provisional attribution, and [SQL sessions](../../../../contracts/SQL_SESSION_V1.md)
define original-token recovery.
