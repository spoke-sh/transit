# FOR SYSTEM_TIME AS OF

**Grammar fragment only.** The reference parser checks this fragment through its
separate `asOfFragment` entry point. It is not a complete statement and is not
part of the executable `SELECT` grammar. Adding it after a source in the query
console rejects.

## Syntax

```text
FOR SYSTEM_TIME AS OF revision
```

`revision` is unsigned decimal digits. The fragment entry point requires end of
input immediately after the clause, apart from whitespace/comments; unlike
`statement`, it does not admit a terminating semicolon.

This is a fragment example, not a runnable query:

```sql
FOR SYSTEM_TIME AS OF 240
```

## Meaning and current interface

The syntax notation calls its integer token `revision`; no production operation
interprets it. This token sequence does not implement SQL temporal tables, a
timestamp selector or historical-query execution. The grammar does not check history
availability or bind a historical schema. Do not use its integer as a public
snapshot-selection contract.

## Planned temporal and historical selectors

**Planned; not accepted by the query compiler.** The intended language reserves
`FOR SYSTEM_TIME AS OF` for SQL temporal meaning. Typed Transit snapshot, branch
and tag selectors are separate from resource-scoped journal revisions. The
[grammar surface inventory](grammar-surface.md#planned-historical-schemas-and-branches)
shows proposed `AS OF SNAPSHOT` and `AS OF BRANCH` forms and their historical
schema binding. Their syntax and execution are not enabled by this fragment.

The isolated integer fragment remains unchanged until a deliberate grammar and
contract cutover replaces its ambiguous spelling. There is no dual interpretation
or fallback from a temporal expression to a Transit resource revision. Selecting
old data must also bind the old schema, views, graph mappings and decoders before
name resolution; inspecting a retained resource alone cannot supply that catalog.

The [retained-read contract](../../../../contracts/READ_VERSIONS_V1.md) owns supported
read-version machinery. [Query execution](../queries.md) binds each current query
to an explicit captured basis or leased snapshot; neither grants arbitrary
historical `AS OF` access. Retention, source liveness and current permissions
still apply. A source revision is not a global snapshot across resources.

Source: [`asOfFragment`, `asOfClause`](../../../../contracts/sql/TransitExtensions.g4).
