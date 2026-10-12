# SELECT

`SELECT` executes a finite read against one explicitly declared KV, Table or
accepted Document projection. Names and types come from that declaration. SQL neither creates the
source nor grants access to it.
For scalar types and retained cell states, see [data types](types.md).
The [function and operator index](expressions.md) lists the complete expression
subset. [INSERT](insert.md), [UPDATE](update.md) and [DELETE](delete.md) use
separately authorized mutation callers; query permission does not authorize them.

## Syntax

```text
SELECT projection FROM source [AS alias] [WHERE predicate] [LIMIT count];
SELECT aggregate FROM source [AS alias] [WHERE predicate];
SELECT aggregate FROM (
  SELECT projection FROM source [AS alias] [WHERE predicate] [LIMIT count]
) AS alias;

projection := * | column [AS name] [, column [AS name] ...]
aggregate  := (COUNT(*) | COUNT(column) | SUM(column)) [AS name]
predicate  := disjunction
disjunction := conjunction [OR conjunction ...]
conjunction := negation [AND negation ...]
negation   := NOT negation | (predicate) | column IS state | column comparison literal
state      := NULL | MISSING | VALUE | TYPE_ERROR | CONFLICT
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
SELECT chosen.value, chosen.id FROM items AS chosen;
SELECT value AS amount, id AS key FROM items;
SELECT value AS first_value, value AS second_value FROM items;
```

Explicit lists preserve the requested order and contain one to eight output
columns. `column AS name` names that output position. The same input column can
appear more than once when the resulting names are distinct. Duplicate output
names reject, including collisions between an alias and an unrenamed column.
Star selects all declared columns and cannot have an alias. Expressions and
`DISTINCT` are unsupported.

Output aliases follow the identifier case and length rules. They change result
column names without changing values, types, cell states or source identity.
`WHERE` continues to resolve original input names: an output alias does not
become a predicate column. `AS` is required for output aliases.
The [local file-query profile](../../../apps/transit-cli/docs/file-query.md)
uses these same alias and scope rules for CSV/JSONL results, including recursive
logical values. Its source acquisition, typed-plan name limits and result
completion rules are described separately.

`FROM source AS alias` gives the declared source a query-local qualifier. With
an alias, qualified columns must use that alias; the original source name is
hidden as a qualifier. Unqualified columns still resolve against the declared
schema. Source aliases follow identifier case and length rules and do not rename output
columns, change source identity or grant access. `AS` is required.

Results follow defined source order, including primary-key order for Tables.
There is no `ORDER BY`. A Document source reads accepted materialized state;
paths, expansion and text materialization belong to its declaration, not SQL.

## Filter rows

```sql
SELECT id, value FROM items WHERE id >= 0;
SELECT value FROM items WHERE value IS NULL;
SELECT id FROM items WHERE value != 7;
SELECT value FROM items WHERE value IS MISSING;
SELECT value FROM items WHERE value IS TYPE_ERROR;
SELECT value FROM items WHERE value IS CONFLICT;
```

The optional WHERE predicate composes atoms with `NOT`, `AND`, `OR` and
parentheses, with that precedence. It admits at most 64 instructions and 64
pending operators/group delimiters. `IS NOT NULL`, `IN`, `LIKE`, `BETWEEN` and
comparisons between two columns are unsupported. A qualifier must
match the alias when present, otherwise the declared source; mismatched names reject rather than selecting another
source.

| Comparison                                                          | Query semantics                                                    |
| ------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `=`, `<>`, `!=`                                                     | Exactly typed equality/inequality                                  |
| `<`, `<=`, `>`, `>=`                                                | Exactly typed comparison, including byte ordering for UTF-8/binary |
| `IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT` | Selects exactly the named cell state                               |
| Comparison with `NULL`                                              | Rejected with `UnsupportedNullComparison`                          |

There are no implicit casts. Query v1 carries value, null, missing, type error
and conflict as distinct cells. State tests inspect the tag without evaluating
the value, so errors and conflicts can be selected without coercion or choosing
a conflict winner. Null/missing comparisons remain unknown through negation;
only true selects a row. Atoms evaluate eagerly in source order, so a determining
false AND or true OR does not hide a later type error or conflict. See the
[Boolean rules](expressions.md#predicate-operators) for exact truth behavior.

```sql
SELECT id, value FROM items WHERE id >= 0 AND NOT (value = 7 OR value IS NULL);
```

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
SELECT COUNT(value) AS present FROM items;
SELECT SUM(value) FROM items WHERE id > 0;
SELECT COUNT(*) AS rows FROM items;
SELECT SUM(value) AS total FROM items WHERE id > 0;
```

An aggregate returns one result cell. `COUNT(*)` counts selected rows, including
null and every other cell state. Its result is uint64;
an empty input gives zero. Flight checks conversion to its published int64
result type. `COUNT(column)` counts top-level value cells of any admitted column
type, skips null/missing and fails on type errors or conflicts in source order.
False, empty text/binary and empty collections each count as one value. Its
uint64 result is zero on empty/all-skipped input; overflow fails. Both forms
apply filtering and an input limit before aggregation, so null/missing rows
still consume a restricted derived input's LIMIT.
The default output names are `count` and `sum`; `AS name` replaces that name.

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

SELECT SUM(chosen.amount) AS total
FROM (SELECT value AS amount FROM items WHERE id >= 0 LIMIT 2) AS chosen;
```

This single derived-table form applies filter, then limit, then aggregate.
The inner projection must retain the column used by `SUM(column)` or
`COUNT(column)`. If it renames that column, the outer aggregate uses the new
name; the original name is hidden. Inner qualifiers refer to the
source or its inner alias; an outer qualifier must match `chosen`. The inner
alias is unavailable in the outer selection. General or nested subqueries,
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

Unknown sources, columns or qualifiers reject. So do duplicate output names,
type mismatches, invalid binary literals, unsupported limits/comparisons and
oversized cells. The compiler returns no successful prefix or approximate plan.
[Query SQL v1](../../../packages/zig/transit-fuze/docs/unified-sql.md) owns exact
compiler APIs and errors.

The separately configured [finite relational console profile](../../../apps/transit-cli/docs/console.md#finite-relational-queries)
adds one inner/left int64 equijoin and grouped COUNT/SUM over explicit Tables.
The single-source interfaces above do not inherit those operators. Sorting,
arithmetic, general casts, historical clauses and continuous queries remain
unsupported. This is a selected SQL subset, with
parser agreement on a checked PostgreSQL corpus; it is not PostgreSQL execution
compatibility. In particular, int64 sums remain checked int64 rather than widened
numeric results. No optimizer rewrite is enabled by the separate rewrite proofs.
