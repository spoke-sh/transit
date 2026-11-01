# Streaming and effects

Transit has durable streams, application materialization and recorded connector
effects. SQL executes finite reads, Table DDL/DML and Stream/Queue declarations. The transport of a result in
several batches does not make that query continuous.

## Operations and SQL coverage

| Task | Current interface | SQL coverage |
| --- | --- | --- |
| Declare and inspect a Stream or Queue | Shared Catalog declaration owner | `CREATE`, policy `ALTER`, `RENAME`, `DROP`, named `SHOW` and `DESCRIBE` below |
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
keys or timestamp identity. `IF EXISTS`, `IF NOT EXISTS`, schema evolution,
plural SQL listings, and workload verbs (`PRODUCE`, `CONSUME`, `COMMIT OFFSET`,
`ENQUEUE`, `CLAIM`, `ACK`, `NACK`, `EXTEND LEASE`) are outside this SQL profile.
Typed callers provide payload operations and bounded catalog listings.

Named `SHOW` returns the published object identity, definition revision,
partition count, configuration and limits. `DESCRIBE` returns typed columns
through the ordinary bounded result lifecycle. Their observation identifies
the exact definition, without claiming a data snapshot. Current metadata
rights and the same named definition are rechecked before each disclosure,
including repeated or terminal batches. A replacement, rename or policy change
invalidates an earlier prepared description.

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
