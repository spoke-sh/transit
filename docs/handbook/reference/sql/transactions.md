# Table transactions

A transaction retains a common catalog and data cut, reads its own private Table
changes, and publishes one commit or abort decision. Native SQL, the console,
PostgreSQL and MySQL share these controls through the database runtime. The
supported domain is one local catalog and branch, with multiple Tables under
one fenced authority.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
UPDATE accounts SET balance = 80 WHERE id = 1;
SAVEPOINT adjusted;
UPDATE accounts SET balance = 70 WHERE id = 1;
ROLLBACK TO SAVEPOINT adjusted;
COMMIT;
```

`BEGIN`, `BEGIN WORK`, `BEGIN TRANSACTION` and `START TRANSACTION` select
serializable read/write execution by default. `READ ONLY` selects the same
retained-cut reads without mutations. `READ WRITE` and `ISOLATION LEVEL
SERIALIZABLE` can be explicit, in either order. Other isolation levels, nested
BEGIN, chaining and autocommit-off are unsupported. No operation implicitly
commits a transaction to accommodate unsupported work.

BEGIN selects the currently authorized catalog Tables under one stable catalog
basis. Data includes committed, unflushed WAL changes. Later statements cannot
add a newly created or newly accessible Table to that cut. Names and definitions
remain those captured at BEGIN; current permissions govern every read, buffered
batch and commit. Retaining a cut never preserves a revoked grant.

Supported statements are finite Table SELECT, INSERT, UPDATE and DELETE, with
their existing types, predicates, primary-key and NOT NULL constraints. The
selected relational join/group profile can read multiple private Tables at the
same revision. DDL, authorization/configuration changes, captured queries,
source-bound KV/Document queries and external effects do not participate.
Metadata results keep their catalog/settings observation; they do not invent
a data snapshot. An error leaves the attached session requiring ROLLBACK or
ROLLBACK TO a saved point before further data work.

## Outcomes and conflicts

DML matched/changed counts are **provisional**: they describe the completed
statement in the private workspace. COMMIT supplies the actual durable decision.
Read results identify the original cut and private workspace revision; their
completion does not imply transaction commit. Previously delivered rows and
counts cannot be retracted by rollback.

Serializable commits validate conservative whole-Table logical versions,
including selected read dependencies and absent/predicate reads. Concurrent
changes on disjoint keys of the same selected Table can conflict. A failed
validation records abort through the original attempt. Physical flush,
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

The [direct transaction contract](../../../../contracts/DIRECT_TABLE_V1.md#signed-transaction-action)
defines owner operations and quotas. [Statement results](../../../../contracts/SQL_RESULTS_V1.md)
define provisional attribution, and [SQL sessions](../../../../contracts/SQL_SESSION_V1.md)
define original-token recovery.
