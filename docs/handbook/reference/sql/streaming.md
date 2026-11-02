# Streaming and effects

Transit has durable streams, application materialization and recorded connector
effects. SQL executes finite reads, Table DDL/DML and Stream/Queue declarations
and appends, positional Stream consumption, partition-routed Queue claims and
receipt-bound ACK. The transport of a result in
several batches does not make that query continuous.

## Operations and SQL coverage

| Task | Current interface | SQL coverage |
| --- | --- | --- |
| Declare and inspect a Stream or Queue | Shared Catalog declaration owner | `CREATE`, policy `ALTER`, `RENAME`, `DROP`, named `SHOW` and `DESCRIBE` below |
| Append schema-bound events or work | Stream/Queue native owner with Catalog operation identity | `PRODUCE INTO`, `ENQUEUE INTO`, optional `RETURNING` below |
| Consume a finite Stream cut | Native read with retained identity and bounded Fuze projection | Positional `CONSUME`, typed predicates and logical `LIMIT` below |
| Acquire Queue work | Native fenced leases and retained original selection | `CLAIM ... WITH LEASE`, one partition and an acquisition maximum below |
| Read an explicit state projection | Fuze over declared KV, Table or accepted Document state | Finite `SELECT` |
| Configure an external connector | HTTP/gRPC connector configuration and credential references | `CREATE CONNECTION` is grammar only |
| Read captured observations | Connector capture and application decoding | `CREATE SOURCE` is grammar only; no executable connector source binding |
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
are outside this SQL profile. Group consumption, waits, `COMMIT OFFSET`,
`NACK` and `EXTEND LEASE` still require typed native callers. The admitted
partition-routed CLAIM and receipt-bound ACK profiles are described below.

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

GROUP and WAIT can be parsed by the dedicated compiler but are refused by SQL
admission. Consumption cannot run inside an attached interactive transaction
in this profile. Group assignment and offset settlement retain their native
owners; positional consumption does not advance a group checkpoint.

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
`WHERE _partition = <unsigned value or parameter>`. Other predicates and WAIT
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

CLAIM is outside attached interactive transactions. NACK and EXTEND LEASE are
not yet admitted by SQL. Native settlement retains its existing owner and current
lease checks.

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

## Connections, sources and sinks

[CREATE CONNECTION](create-connection.md) names reusable configuration and
secret references. [CREATE SOURCE](create-source.md) describes an adapter over
captured connector observations. [CREATE SINK](create-sink.md) describes a
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
