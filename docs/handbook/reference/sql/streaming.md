# Streaming and effects

Transit has durable streams, application materialization and recorded connector
effects. SQL executes finite reads and explicitly routed Table DDL/DML. The transport of a result in
several batches does not make that query continuous.

## Operations and SQL coverage

| Task | Current interface | SQL coverage |
| --- | --- | --- |
| Read an explicit state projection | Fuze over declared KV, Table or accepted Document state | Finite `SELECT` |
| Configure an external connector | HTTP/gRPC connector configuration and credential references | `CREATE CONNECTION` is grammar only |
| Read captured observations | Connector capture and application decoding | `CREATE SOURCE` is grammar only; no executable connector source binding |
| Maintain application state from messages | Application freezes input identity and publishes complete Table changes with durable progress | No `CREATE MATERIALIZED VIEW` |
| Refresh a displayed query | Int64 Table watch invalidation and finite snapshot refresh | No `SUBSCRIBE` or continuous `SELECT` |
| Dispatch external work | Recorded intent, authorized attempt and captured outcome | `CREATE SINK` is grammar only; no query-to-sink binding |

`CREATE VIEW`, `CREATE MATERIALIZED VIEW`, `SUBSCRIBE`, streaming windows and
event-time watermark declarations are absent from the grammar and runtime.
The existing [historical-read fragment](as-of.md) does not enable time travel or
stream resumption.

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
