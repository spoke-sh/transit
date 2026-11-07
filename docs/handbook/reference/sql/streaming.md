# Streaming and effects

Transit has durable streams, application materialization and recorded connector
effects. SQL executes finite reads, Table DDL/DML and Stream/Queue declarations
and appends, positional and grouped Stream consumption, bounded Stream/Queue
waits, partition-routed Queue claims and
receipt-bound ACK/NACK and lease renewal. The transport of a result in
several batches does not make that query continuous.

## Operations and SQL coverage

| Task | Current interface | SQL coverage |
| --- | --- | --- |
| Declare and inspect a Stream or Queue | Shared Catalog declaration owner | `CREATE`, policy `ALTER`, `RENAME`, `DROP`, named `SHOW` and `DESCRIBE` below |
| Append schema-bound events or work | Stream/Queue native owner with Catalog operation identity | `PRODUCE INTO`, `ENQUEUE INTO`, optional `RETURNING` below |
| Consume a finite Stream cut | Native read with retained identity and bounded Fuze projection | Positional or explicitly grouped `CONSUME`, typed predicates, logical `LIMIT` and bounded `WAIT` below |
| Settle Stream progress | Native group checkpoint owner with authenticated read boundaries | `COMMIT OFFSET ... RECEIPT` below |
| Acquire Queue work | Native fenced leases and retained original selection | `CLAIM ... WITH LEASE`, optional bounded `WAIT`, one partition and an acquisition maximum below |
| Settle or renew Queue work | Native settlement of an exact lease | `ACK`, `NACK` and `EXTEND LEASE` below |
| Read an explicit state projection | Fuze over declared KV, Table or accepted Document state | Finite `SELECT` |
| Configure an external connector | HTTP/gRPC connector configuration and credential references | `CREATE CONNECTION` is grammar only |
| Read captured observations | Connector capture and application decoding | `CREATE SOURCE` publishes and inspects declarations in native cohosted SQL; HTTP capture is not installed |
| Maintain application state from messages | Application freezes input identity and publishes complete Table changes with durable progress | No `CREATE MATERIALIZED VIEW` |
| Maintain a supported relational result | Typed Zig owner publishes complete revisions and deltas from Table history, with explicit host activation and wakeups | No SQL view, materialized-view or subscription adapter |
| Refresh a displayed query | Int64 Table watch invalidation and finite snapshot refresh | No `SUBSCRIBE` or continuous `SELECT` |
| Dispatch external work | Recorded intent, authorized attempt and captured outcome | `CREATE SINK` is grammar only; no query-to-sink binding |

`CREATE VIEW`, `CREATE MATERIALIZED VIEW`, `SUBSCRIBE`, streaming windows and
event-time watermark declarations are absent from the grammar and runtime.
The existing [historical-read fragment](as-of.md) does not enable time travel or
stream resumption.

## Stream and Queue declarations

The native SQL service, console, PostgreSQL and MySQL sessions use the same
[declaration lifecycle](../streams.md#declarative-streams-and-queues).
The configured account needs current schema CREATE rights for creation and
object ownership for changes. A declaration completes after its partitions
are initialized and published. An accepted token retains the complete original
declaration through a disconnect or service replacement; retry that token to
observe the same operation.

```sql
CREATE STREAM events (
  tenant TEXT NOT NULL COLLATE ASCII_CI,
  payload JSON
) PARTITION BY HASH (tenant) PARTITIONS 4
WITH (retention = '7d', compaction = 'key');

CREATE QUEUE work (
  entity BIGINT NOT NULL,
  payload TEXT
) PARTITION BY HASH (entity) PARTITIONS 4
WITH (mode = 'key_fifo', lease_duration = '5s', max_attempts = 7);

ALTER STREAM events SET (retention = 'unlimited');
ALTER QUEUE work SET (retention = '1d', max_attempts = 9);
ALTER STREAM events RENAME TO history;
SHOW STREAM history;
SHOW QUEUE work;
DESCRIBE STREAM history;
DESCRIBE QUEUE work;
DROP STREAM history;
DROP QUEUE work;
```

Columns use the [shared Table type and default grammar](create-table.md).
Primary keys are refused: log offsets supply record identity. Names remain
contextual identifiers. Omitted partitioning declares one manually selected
partition; `PARTITIONS n` declares several manual partitions. Automatic routing
uses `PARTITION BY HASH (column) PARTITIONS n` with a non-null supported key type.

`WITH (...)` supplies CREATE options; `ALTER ... SET (...)` changes only the
specified compatible policies and operation limits. Options are case-insensitive,
unique and checked before admission. Durations are positive integers followed
by `ms`, `s`, `m`, `h` or `d`.

| Option | Meaning and default |
| --- | --- |
| `retention` | Unlimited by default; a duration opts into age eligibility. `'unlimited'` or `NULL` removes that age policy. |
| `compaction` | Stream `'none'` by default, or `'key'` using `key_column` or the routing column. |
| `timestamp_column` | Optional Stream non-null UTC timestamp column, named by a string literal. |
| `mode` | Queue `'competing'` by default, or `'key_fifo'`. |
| `key_column` | Explicit compaction/FIFO column name; FIFO can otherwise use its routing column. |
| `lease_duration`, `max_lease_duration` | Queue default and maximum lease, both `'30s'`. A larger default also requires a sufficient maximum. |
| `max_attempts` | Queue attempt limit, default 5. |
| `backoff_initial`, `backoff_maximum`, `backoff_multiplier` | Queue retry backoff, defaults `'1s'`, `'60s'`, and 2. |
| `dead_letter_queue` | Existing compatible Queue name, or `NULL`. Binding captures its exact definition and checks current destination append rights. |

Operation limits are also options: `append_rows` and `read_rows` default to 128;
`append_bytes` and `read_bytes` to 1,048,576; `claim_rows` to 16; and
`active_leases`, `waiters`, and `timer_steps` to 64. All are positive unsigned
32-bit counts; `claim_rows` cannot exceed `active_leases`. These declarations
bound individual operations and active work, independently of total retained
history. Deployment memory and storage quotas still apply.

ALTER cannot change schema, partitioning, routing keys, ordering, compaction
keys or timestamp identity. `IF EXISTS`, `IF NOT EXISTS` and schema evolution
are outside this SQL profile. Group assignment requires typed native callers.
Stream and Queue waits use the interfaces below. SQL group reads and offset
settlement use their native descriptors. The admitted partition-routed CLAIM and
receipt-bound settlement profiles are described below.

Named `SHOW` returns the published object identity, definition revision,
partition count, configuration and limits. `DESCRIBE` returns typed columns
through the ordinary bounded result lifecycle. Their observation identifies
the exact definition, without claiming a data snapshot. Current metadata
rights and the same named definition are rechecked before each disclosure,
including repeated or terminal batches. A replacement, rename or policy change
invalidates an earlier prepared description.

`SHOW STREAMS` and `SHOW QUEUES` return visible names in the current namespace,
with one UTF-8 `stream` or `queue` column. The reader traverses bounded Catalog
pages and returns ordinary SQL batches; it does not materialize the whole
Catalog. Traversal is limited to 10,000 native pages and the statement deadline.
Reaching either limit fails the result instead of reporting complete coverage.
Listings record independent metadata observations, not one atomic Catalog or
data snapshot. Each buffered row retains its exact definition for current
authorization and definition checks on delivery and repetition. Namespace
authorization also protects empty results and terminal counts.

## Append events and work

Native SQL, the console, PostgreSQL and MySQL admit dedicated `PRODUCE INTO`
and `ENQUEUE INTO` statements through the same Catalog token and native log
owners. Values use the declared schema, nullable/default rules and typed
parameters. Each statement appends to one partition: a hash key routes all
rows to that partition, or `PARTITION n` selects it explicitly. A multi-partition
declaration without a hash key requires `PARTITION`. Rows routing to different
partitions are refused before admission; the service never publishes a prefix.

```sql
CREATE STREAM audit_events (id BIGINT NOT NULL, message TEXT);
PRODUCE INTO audit_events VALUES (1, 'accepted') RETURNING id, _offset;
CREATE QUEUE tasks (id BIGINT NOT NULL, message TEXT);
ENQUEUE INTO tasks VALUES (1, 'process') RETURNING id, _partition, _offset;
```

Optional `PRODUCER ID uuid EPOCH n SEQUENCE n` binds the native producer fence
and sequence. Queue `WITH (visible_at = timestamp)` accepts a nonnegative UTC
timestamp with whole-millisecond precision. See the
[exact append grammar](../../../../contracts/sql/README.md) for operand types.
Declared append row/byte budgets and SQL text, parameter, intent and result
budgets apply independently. An append cannot execute inside an attached
interactive transaction in this profile.

`RETURNING` projects application columns and unqualified `_partition`/`_offset`
metadata from the original native append receipt. `*` expands only application
columns. Output names must be distinct; expressions, predicates, aggregates and
LIMIT are excluded. Qualify an application column whose name collides with
metadata. Selecting both that column and its same-named metadata field is
currently refused by the frozen projection layout.

Without RETURNING, completion reports the native accepted row count. With
RETURNING, the shared result reader opens the original operation's retained
rows, copies bounded batches, and verifies completion independently of delivery.
Closing, repeating or reopening delivery does not append again. Current rights
and the exact definition are checked before disclosure, including retained
terminal batches. Revocation, incompatible definitions and unavailable retained
history are failures, not empty successful results. Retain the original native
SQL client token or reported wire operation after a lost reply; submitting new
SQL creates new work.

## Consume a finite Stream cut

Native SQL, console, PostgreSQL and MySQL sessions admit positional consumption
through the same Catalog workload identity and native Stream read owner:

```sql
CONSUME id, message, _offset FROM audit_events
WHERE _offset >= 0 AND id >= 1 LIMIT 100;
```

The declared schema owns application types and collations. Projections accept
columns, aliases and unqualified `_partition`/`_offset` metadata; `*` includes
only application columns. Boolean comparisons and cell-state predicates use
the same typed Fuze semantics as finite reads. Parameters are typed across
the projection's predicate and LIMIT. Aggregates, joins, sorting and `_timestamp`
metadata are outside this consumption profile.

A statement selects one partition. For a multi-partition Stream, its predicate
must establish one valid partition, for example `WHERE _partition = 2`.
Conservative bounds preserve AND/OR/NOT semantics; an ambiguous selector is
refused. Contradictory metadata bounds are also refused in this profile.
A lower offset bound selects the start, defaulting to zero. Acceptance retains
the then-current upper cut; later appends cannot enlarge it. An upper offset
comparison remains a row predicate, so it does not truncate traversal coverage.
Unavailable retained history and a start beyond the accepted cut are errors.

LIMIT bounds returned rows after filtering. A result completes when that limit
is reached or the original native read is exhausted. LIMIT 0 completes with no
rows at the initial position. Completion retains the original native cursor:
filtered rows contribute to traversal coverage, and reaching LIMIT can leave
that cursor partial. A complete SQL result therefore does not imply that the
whole Stream cut was traversed or that consumer progress was committed.

Native SQL requires a client token because acceptance retains a durable read.
The prepared descriptor exposes its row schema and mutation-admission flag.
Wire adapters admit once and open that original result; PostgreSQL reports
`CONSUME n` using the verified returned-row count. Repeating, closing and
reopening delivery never captures another cut. Preserve the original identity
after uncertainty. Current read rights and exact definitions are rechecked for
buffered and terminal responses, including empty results. Native read release
remains explicit and is separate from closing local result buffers.

### Consume and settle an assigned group

Bind the binary `StreamHandle.Group` returned from an explicitly managed native
assignment to `CONSUME ... GROUP $1` (MySQL uses `?`). This descriptor carries the
exact target, group ID, generation, principal and checkpoint. It selects the
partition and starting checkpoint; offset predicates filter rows without skipping
input. Current rights and the native assignment remain authoritative.

Grouped completion includes authenticated `progress`, separately from returned
row count. The shared result model's `Workload.Completion.streamProgress` combines
it with the original observation into a `StreamHandle.Progress`. Encode that
bounded descriptor and bind it to:

```sql
COMMIT OFFSET ON STREAM events RECEIPT $1
```

The native SQL result API exposes this completion metadata, including empty
results and partial LIMITs. PostgreSQL/MySQL and the console accept the same
binary descriptors; their row counts and command tags cannot construct a
progress proof. Callers using those transports obtain progress through the native
result API. Group assignments use the 152-byte `SGH1` encoding; progress uses
`SPH1`, at most 357 bytes. Both require the current definition.

Offset settlement returns command completion without relational row counts.
Native verification rejects forged boundaries, stale assignments/checkpoints and
released reads. Preserve the original token after lost replies; retries recover
the same settlement even after reassignment. Reassignment fences further delivery
of the old grouped read, including buffered and reopened results; the original
operation and accepted settlement remain recoverable. Closing results advances
no offset and releases no native pin. Group assignment and read release remain native
operations. Attached interactive workload transactions remain outside this SQL
profile.

### Wait for a Stream frontier

```sql
CONSUME value, _offset FROM events WHERE _offset >= $1 LIMIT 128 WAIT '1s';
CONSUME value FROM events GROUP $1 LIMIT $2 WAIT $3;
```

WAIT accepts a duration or bound string parameter from 1 through 1000 whole
milliseconds. Transit freezes that policy with the original SQL operation and
makes one bounded native attempt. A positional read waits for an offset after
its starting position; a group read waits after its supplied checkpoint. Upper
`_offset` comparisons, payload filters and LIMIT, including LIMIT 0, filter or
bound output without changing readiness. A ready read can therefore complete
with zero rows. The accepted upper cut is finite and never grows on resume or
result reopening.

A timeout leaves the original SQL operation pending, without an accepted read,
result rows or group progress. Only the response to that attempt carries its
observed timeout cut; passive status has no timeout cut. Same-token execute,
status and service recovery do not begin another attempt. Use the shared SQL
client's `Executor.resumeWorkload` or native session `resume` to make another
bounded attempt for the same saved operation. Current rights, group assignment
and checkpoint are checked again. Assignment or checkpoint conflicts do not
refresh the saved descriptor; inspect or cancel that original operation.

The shared client returns typed `unresolved` evidence with reason `waiting`.
PostgreSQL reports SQLSTATE 57014 and MySQL reports error 1317 / SQLSTATE 70100,
including the original operation ID. The console exits nonzero and its JSON
output preserves the pending identity. A timeout is not a successful empty
result. Preserve the original identity after a lost reply; an accepted receipt
or recorded closure wins over waiting. Successful grouped reads still require a
separate authenticated `COMMIT OFFSET`. Closing delivery commits no progress
and releases no native pin. See the
[Stream wait contract](../../../../contracts/SQL_SESSION_V1.md#stream-wait-attempts).

## Acquire Queue work

```sql
CLAIM value, _partition, _offset, _lease_epoch, _attempt, _receipt_handle
FROM jobs LIMIT 16 WITH LEASE '30s';
```

CLAIM acquires up to LIMIT eligible messages from one declared Queue partition.
Omitting LIMIT uses the declaration's `claim_rows` budget. LIMIT must be positive
and cannot exceed that budget. WITH LEASE is required and accepts positive whole
`ms`, `s` or `m` units within the Queue's maximum lease policy. Native eligibility,
FIFO ordering, active-lease capacity and trusted-time checks remain authoritative.
A genuinely empty accepted claim is a complete empty result; capacity or budget
refusal is not an empty claim.

A one-partition Queue needs no WHERE clause. For multiple partitions, use exactly
`WHERE _partition = <unsigned value or parameter>`. Other predicates
are refused before admission in this profile. Payload predicates require native
selection before acquisition; SQL never leases unrelated rows and hides them
with a result filter. Star includes application columns only. `_partition`,
`_offset`, `_lease_epoch`, `_attempt` and binary `_receipt_handle` can be projected
explicitly and aliased. The handle is the exact original lease descriptor; it is
not a credential or a current liveness check.

Native SQL requires a client token. Admission freezes the exact target, maximum,
duration and projection. Delivery returns every originally acquired row, across
bounded batches, without another output LIMIT. PostgreSQL emits `CLAIM n` after
verified exhaustion; MySQL uses its ordinary row-result completion. Repeating,
closing or reopening delivery neither acquires again nor ACKs or renews a lease.
Original payload delivery may outlive the lease; the returned epoch and attempt
are original attribution, not proof of current settlement authority. Current
read and acquire rights are rechecked before disclosure.

CLAIM is outside attached interactive transactions. Native settlement retains
its existing owner and current lease checks.

### Wait for eligible Queue work

```sql
CLAIM value, _receipt_handle FROM jobs LIMIT 16 WITH LEASE '30s' WAIT '1s';
```

WAIT accepts a duration or bound parameter from 1 through 1000 milliseconds.
Transit makes one bounded attempt using the native Queue waiter and its existing
capacity, FIFO and lease policies. The duration is frozen with the original claim.
A timeout leaves that operation pending; it does not accept an empty claim.
Status and background recovery never acquire later arrivals for a timed-out wait.

The shared SQL client returns a typed `unresolved` outcome with reason `waiting`.
`Executor.resumeWorkload` explicitly makes another bounded attempt for that same
original operation. Native `status` and `cancel` remain available, including after
service replacement. Same-token execute observes the original work without another
attempt. Once accepted, resume and result reopening preserve the original rows
and lease handles without renewal or reselection.

When waiting ends without completion, PostgreSQL reports SQLSTATE 57014 and
MySQL reports error 1317 / SQLSTATE 70100. Both include the original operation ID.
The console exits nonzero and its JSON output
includes the pending identity and wait observation. Repeating the SQL creates a
new operation; use the shared client or native operation interface to resume or
cancel the original. See the [wait contract](../../../../contracts/SQL_SESSION_V1.md#queue-wait-attempts)
for timeout evidence and interrupted requests.

## Acknowledge Queue work

```sql
ACK ON QUEUE jobs RECEIPT $1;
```

Bind the exact binary `_receipt_handle` returned by CLAIM. A binary `X'...'`
literal is also accepted; SQL never interprets text as a receipt. ACK has its own
client token and operation identity. It completes only with the original native
settlement receipt, has no row result or relational matched/changed count, and
emits the PostgreSQL `ACK` command tag. MySQL's completion has zero affected rows;
that transport field is not a count of Queue messages.

The named Queue must resolve to the handle's stable object and partition, and the
caller must be the original claimant. A newly prepared ACK may use an older
receipt after a compatible declaration change: it preserves the original lease
and separately captures current preparation metadata. The Queue owner rechecks
current settle rights, the exact live lease and trusted time before acceptance.
A copied or modified handle cannot acquire those rights. Expiry or fencing can
produce a recorded rejection; missing observations remain unresolved.

Retry an uncertain ACK using the same token and original SQL/parameters. Its
accepted result remains recoverable after expiry, rename or retirement without
acknowledging again. A different token submits a different operation. ACK does not
release the original claim's payload-read pin or erase its original result.
ACK is outside attached interactive transactions in this SQL profile.

## Return Queue work for retry

```sql
NACK ON QUEUE jobs RECEIPT $1;
NACK ON QUEUE jobs RECEIPT $1
  WITH (visible_at = TIMESTAMP '2027-01-01T00:00:00Z');
```

NACK uses the same exact binary receipt, original claimant, current settle rights
and live-lease checks as ACK. Its own token freezes the native settlement before
dispatch. Optional `visible_at` is a UTC timestamp literal or parameter with
whole-millisecond precision at or after the Unix epoch. It requests the earliest
visibility time; the Queue owner also applies retry backoff from its accepted
trusted time. Omitting it leaves scheduling to that policy. An old timestamp
cannot bypass backoff, FIFO ordering or the attempt limit. Relative delays and
reason strings are not supported.

A delayed FIFO head continues to block later work for its key. Other keys can
remain eligible. Exhausted work stays blocked for its native dead-letter owner;
NACK does not discard it or authorize a source-only transfer.

Completion reports `nack` with no result rows or relational counts. PostgreSQL
emits `NACK`; MySQL emits an OK completion with zero affected rows. Retrying the
same token returns the original outcome and visibility request, including after
replacement or DROP. A new token cannot reuse the old lease after NACK commits.
Current rights still govern recovery. Missing responses remain unresolved until
the original operation is inspected; stopping a wait does not settle the lease.
NACK does not release the original claim's payload-read pin and cannot execute
inside an attached interactive transaction.

## Renew a Queue lease

```sql
EXTEND LEASE ON QUEUE jobs RECEIPT $1 BY '5s';
```

Bind the exact binary handle from CLAIM or a previous renewal. BY accepts a
positive duration in whole `ms`, `s` or `m` units, either literally or as a UTF-8
parameter. The proposed deadline is the supplied handle's expiry plus that
duration, with checked arithmetic. It is not measured from the time the result
is fetched. Current settle rights, claimant identity, live-lease fencing, trusted
time and the Queue's maximum lease policy govern acceptance.

The statement requires its own native SQL client token and returns exactly one
binary `_receipt_handle` column and one row after verified acceptance. PostgreSQL
emits `EXTEND LEASE` after the result; there are no relational matched/changed
counts. Use the returned handle for subsequent ACK, NACK or renewal. A fresh
operation using the old expiry-bearing handle is fenced.

Retry uncertainty with the original token, SQL and parameters. Result reopening
and repeated fetches derive the same handle from that operation's accepted
settlement receipt, including after another renewal, expiry, settlement or
restart. Delivery does not renew again or establish that the handle remains live.
Current settle rights are rechecked before metadata, buffered rows and terminal
responses are disclosed; payload READ rights are not required for this
descriptor-only result. Compatible ALTER preserves the original lease's
interpretation. Renewal does not release the claim's payload-read pin and is
outside attached interactive transactions.

## Connections, sources and sinks

[CREATE CONNECTION](create-connection.md) names reusable configuration and
secret references. [CREATE SOURCE](create-source.md) declares HTTP ingestion into an explicit existing
Stream; its typed parser validates options without publishing or activating it. [CREATE SINK](create-sink.md) describes a
connector effect target. These grammar rules do not resolve dependencies,
validate connector options, provision resources or authorize attempts.

An executable [query source](../queries.md#source-declarations) is instead an
explicit state declaration with names, types and source identity. It is not
created by the connector `CREATE SOURCE` statement. Queries require current
read rights even when a source or connection name is known.

## Materialization and observation

An application can [materialize mailbox input](../tables.md#materialize-a-stream)
by binding durable input identity to its staged operation and publishing the
complete Table successor with its recorded outcome. The
application owns decoding and transformation. Fuze does not install a maintained
query graph or automatically recompute Tables after upstream changes.

The separate [maintained relational owner](../queries.md#maintained-table-revisions)
uses Fuze to recompute each recorded Table-history basis and publish a complete
result and delta. Named definitions, authorization, activation and wakeups have
explicit typed Zig interfaces. An application host schedules advancement; SQL
declarations do not install a background service. This differs from refreshing
a displayed finite query after an invalidation notice.

[Reactive APIs](../reactive.md) notify a viewer that its source may have changed.
The viewer acquires a new finite result and replaces the displayed result after
complete verification. Notifications can be coalesced; they do not promise every
intermediate row change, insert/delete deltas or an event-time frontier. Missing
retained watch coverage requires reset rather than invented continuity.

A source revision identifies a captured state basis. A Table data watermark
tracks data progress separately from bookkeeping. Neither is a SQL event-time
watermark. Source cuts from different resources do not establish a global
snapshot.

## External effects

A sink declaration alone cannot send a request. The supported
[effect lifecycle](../connectors.md#intent-attempt-and-outcome) records intent,
authorizes an attempt and captures its outcome. Replay consumes those records;
it does not dispatch. A changed or deleted input row cannot undo a remote effect.

An unknown remote outcome stays unknown until connector policy and evidence
resolve it. Local cancellation, grant revocation and successful socket writes
cannot establish remote rollback or safe retry. Secrets remain references in
definitions and transcripts. SQL supplies no automatic retries, scheduling,
external exactly-once guarantee or unbounded live connector stream.

See [application declarations](application.md) for the separate offline compiler
and explicit interface publication. Publishing a UI definition does not activate
a continuous query or connector effect.
