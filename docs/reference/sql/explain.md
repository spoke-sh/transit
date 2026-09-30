# EXPLAIN

`EXPLAIN` describes a proposed finite SELECT plan and its output columns. The
console, query workspace `inspect` operation and shared query client use the
same Fuze compiler as query execution.

```sql
EXPLAIN SELECT value FROM items WHERE id > 0 LIMIT 2;
EXPLAIN SELECT count(*) FROM items;
```

The result lists logical operators in evaluation order, the predicate column
and operator or cell state, input projection and limit, output columns and
configured execution budgets. Literal values are omitted. Checked SUM outputs
int64 and COUNT outputs uint64. The supported SELECT syntax and type limits
apply; `EXPLAIN ANALYZE`, cost estimates and alternative physical plans are
unsupported.

The scope contains one configured source. Current source/requester read access
and query policy must authorize the declaration before name resolution and
before the response is returned. The response's metadata revision is an
observation of current authorization and schema, not a captured source basis.
The plan acquires no data snapshot and creates no query request or execution.
See the [inspection contract](../../../contracts/SQL_INSPECTION_V1.md) for the
neutral result and exact limits.

Source: [`explainStatement`](../../../contracts/sql/TransitExtensions.g4).
