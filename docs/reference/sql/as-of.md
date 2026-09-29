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

The reference form names a Transit revision, an integer journal position. Its
SQL system-time spelling does not imply a wall-clock timestamp, an event-time
window or PostgreSQL compatibility. The grammar does not check revision
availability or define a complete historical-query operation.

The [retained-read contract](../../../contracts/READ_VERSIONS_V1.md) owns supported
read-version machinery. [Query execution](../queries.md) binds each current query
to an explicit captured basis or leased snapshot; neither grants arbitrary
historical `AS OF` access. Retention, source liveness and current permissions
still apply. A source revision is not a global snapshot across resources.

Source: [`asOfFragment`, `asOfClause`](../../../contracts/sql/TransitExtensions.g4).
