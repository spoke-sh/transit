# SELECT

`SELECT` executes a finite read against one explicitly declared KV, Table or
accepted Document projection. Names and types come from that declaration. SQL neither creates the
source nor grants access to it.
For scalar types and retained cell states, see [data types](types.md).
The [function and operator index](expressions.md) lists the complete expression
subset. [INSERT](insert.md), [UPDATE](update.md) and [DELETE](delete.md) are
unsupported; query permission does not authorize mutations.

## Syntax

```text
SELECT projection FROM source [WHERE predicate] [LIMIT count];
SELECT aggregate FROM source [WHERE predicate];
SELECT aggregate FROM (
  SELECT projection FROM source [WHERE predicate] [LIMIT count]
) AS alias;

projection := * | column [, column ...]
aggregate  := COUNT(*) | SUM(column)
predicate  := column IS NULL | column comparison literal
comparison := = | <> | != | < | <= | > | >=
column     := name | qualifier.name
```

The grammar also recognizes an outer `LIMIT` on aggregates; the compiler rejects
it with `UnsupportedAggregateLimit`. The forms above describe compilable shapes.
See [syntax](syntax.md) for identifiers, literals and statement bounds.

## Project rows

For an authorized source named `items` with int64 columns `id` and nullable `value`:

```sql
SELECT * FROM items;
SELECT value FROM items;
SELECT items.value, items.id FROM items;
```

Explicit lists preserve the requested order and contain one to eight different
column names. Star selects all declared columns. Output aliases,
expressions and `DISTINCT` are unsupported.

Results follow defined source order, including primary-key order for Tables.
There is no `ORDER BY`. A Document source reads accepted materialized state;
paths, expansion and text materialization belong to its declaration, not SQL.

## Filter rows

```sql
SELECT id, value FROM items WHERE id >= 0;
SELECT value FROM items WHERE value IS NULL;
SELECT id FROM items WHERE value != 7;
```

There is one optional predicate. `AND`, `OR`, `NOT`, `IS NOT NULL`, `IN`, `LIKE`,
`BETWEEN` and comparisons between two columns are unsupported. A qualifier must
match the declared source; mismatched names reject rather than selecting another
source.

| Comparison | Query semantics |
| --- | --- |
| `=`, `<>`, `!=` | Exactly typed equality/inequality |
| `<`, `<=`, `>`, `>=` | Exactly typed comparison, including byte ordering for UTF-8/binary |
| `IS NULL` | Explicit null; missing remains distinct |
| Comparison with `NULL` | Rejected with `UnsupportedNullComparison` |

There are no implicit casts. Query v1 carries value, null, missing, type error
and conflict as distinct cells. SQL does not provide tests for all those states;
use the typed API where required. Do not treat an error or conflict as null.

## Limit output

```sql
SELECT id, value FROM items WHERE id >= 0 LIMIT 8;
SELECT * FROM items LIMIT 0;
```

Filtering precedes the limit. A limit applies across the whole query, independently
of page size. The count ranges from 0–18446744073709551615.
`LIMIT 0` produces no rows. Omitting the limit adds no implicit truncation, while
operation, source and result budgets still govern execution. `OFFSET` is unsupported.

## Aggregate rows

```sql
SELECT COUNT(*) FROM items;
SELECT SUM(value) FROM items WHERE id > 0;
```

An aggregate returns one result cell. `COUNT(*)` counts selected rows, including
null and every other cell state. Its result is uint64;
an empty input gives zero. Flight checks conversion to its published int64
result type. `COUNT(column)` is unsupported.

`SUM(column)` requires int64. It adds values with checked overflow in source order,
skips missing/null, and returns null on empty/all-skipped
input. An error or conflict cell fails the sum. `AVG`, `MIN`, `MAX`, grouping,
multiple aggregates and mixing an aggregate with row columns are unsupported.

### Aggregate a limited input

```sql
SELECT SUM(chosen.value)
FROM (SELECT value FROM items WHERE id >= 0 LIMIT 2) AS chosen;

SELECT COUNT(*)
FROM (SELECT * FROM items LIMIT 2) AS chosen;
```

This single derived-table form applies filter, then limit, then aggregate.
The inner projection must retain the sum's column. Inner qualifiers refer to the
source; an outer qualifier must match `chosen`. General or nested subqueries,
outer predicates and derived tables returning rows are unsupported. An outer
`LIMIT`, even zero, rejects rather than becoming an aggregate input limit.

## Execution and results

The console opens a fresh snapshot session per `SELECT`, releases it on completion
and cancels active work on exit. Reconnecting starts a new query. Explicit durable
queries instead preserve the original submission and recover its captured result.
Both paths require current source authority and bounded Arrow output; a returned
prefix is not proof of complete execution. See [query execution](../queries.md)
and [console use](../../../apps/transit-cli/docs/console.md).

## Failures and unsupported forms

Unknown sources, columns or qualifiers reject. So do duplicate projections,
type mismatches, invalid binary literals, unsupported limits/comparisons and
oversized cells. The compiler returns no successful prefix or approximate plan.
[Query SQL v1](../../../packages/zig/transit-fuze/docs/unified-sql.md) owns exact
compiler APIs and errors.

Joins, sorting, grouping, arithmetic, writes, general casts, historical clauses
and continuous queries are unsupported. This is a selected SQL subset, with
parser agreement on a checked PostgreSQL corpus; it is not PostgreSQL execution
compatibility. In particular, int64 sums remain checked int64 rather than widened
numeric results. No optimizer rewrite is enabled by the separate rewrite proofs.
