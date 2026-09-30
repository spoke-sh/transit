# Functions and operators

Transit SQL supports column projections, one predicate and one of two aggregate
functions. It has no general scalar expression evaluator. Use
[SELECT](select.md) for clause order and complete queries, and
[data types](types.md) for scalar and cell-state behavior.

## Column expressions

`*` selects all declared columns. A named projection contains one to eight distinct
columns, optionally qualified by the declared source name. Literals cannot be
selected as result expressions. Arithmetic, concatenation, `CASE`, output
aliases and scalar function calls are unsupported.

## Predicate operators

| Operator | Operands | Behavior |
| --- | --- | --- |
| `=`, `<>`, `!=` | Column and exactly typed literal | Equality or inequality |
| `<`, `<=`, `>`, `>=` | Column and exactly typed literal | Comparison; text and binary use byte ordering |
| `IS NULL` | Column | Selects explicit null only |

The literal forms cover int64, boolean, UTF-8 and binary. Comparisons to `NULL`
reject; there is no implicit cast to another column type. The syntax allows one
predicate, with no `AND`, `OR`, `NOT`, `IS NOT NULL`, `IN`, `LIKE`, `BETWEEN` or
column-to-column comparison. General precedence and boolean-expression rules
are therefore not part of this SQL profile.

## Aggregate functions

| Function | Input | Result | Empty input |
| --- | --- | --- | --- |
| `COUNT(*)` | Selected rows, including all cell states | uint64 | Zero |
| `SUM(column)` | int64 values in source order | Checked int64; null/missing skipped, error/conflict fails | Null |

An aggregate returns one cell. There is no grouping, multiple aggregates,
`COUNT(column)`, `DISTINCT`, `AVG`, `MIN`, `MAX`, window function or user-defined
function. `SUM` does not widen its result type or reorder values to avoid an
intermediate overflow.

A direct aggregate cannot have an outer `LIMIT`. To aggregate a limited input,
use the [restricted derived-table form](select.md#aggregate-a-limited-input).

## Conversion and external work

`'\x00ff'::bytea` is a binary literal form, not a general cast facility. SQL
supports neither `CAST` nor arbitrary `::type` conversion. Secret references in
[connection options](create-connection.md) are separate grammar-only syntax;
they are not query functions.

A `SELECT` does not invoke HTTP, gRPC or application handlers. External work
uses the recorded [connector effect contract](../connectors.md), independently
of query evaluation. See [streaming and effects](streaming.md).
