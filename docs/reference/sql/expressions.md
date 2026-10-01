# Functions and operators

Transit SQL supports column projections, bounded Boolean predicates and one of two aggregate
functions. It has no general scalar expression evaluator. Use
[SELECT](select.md) for clause order and complete queries, and
[data types](types.md) for scalar and cell-state behavior.

## Column expressions

`*` selects all declared columns. A named projection contains one to eight output
positions, optionally qualified by the declared source name or its explicit
source alias. `column AS name` names an output position; repeated inputs require
distinct result names. `AS name` names either COUNT form and `SUM(column)`.
Output names do not enter `WHERE` scope. See
[projection and alias rules](select.md#project-rows) for case, collision and
derived-input behavior. Literals cannot be selected as result expressions.
Arithmetic, concatenation, `CASE` and scalar function calls are unsupported.

## Predicate operators

| Operator                                                            | Operands                         | Behavior                                                       |
| ------------------------------------------------------------------- | -------------------------------- | -------------------------------------------------------------- |
| `=`, `<>`, `!=`                                                     | Column and exactly typed literal | Equality or inequality                                         |
| `<`, `<=`, `>`, `>=`                                                | Column and exactly typed literal | Comparison; text and binary use byte ordering                  |
| `IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT` | Column                           | Selects exactly the named cell state                           |
| `NOT`, `AND`, `OR`, parentheses                                     | Predicates                       | Three-valued composition; precedence is NOT, then AND, then OR |

The literal forms cover int64, uint64, finite float64, boolean, UTF-8 and binary. Comparisons to `NULL`
reject; there is no implicit cast to another column type. `IS NOT NULL`, `IN`,
`LIKE`, `BETWEEN` and column-to-column comparison are unsupported; use
`NOT (column IS NULL)` for the negated state test.

Native KV/Table/Document and local file queries support up to 64 predicate instructions: each
comparison/state test and each NOT/AND/OR counts once. Parentheses do not count
as instructions, but pending operators and group delimiters share a 64-entry
parser stack. The statement byte limit still applies. File plans also retain
their [fingerprint byte budget](../../../packages/zig/transit-fuze/docs/file-sources.md#finite-file-plans).

Null/missing comparisons produce unknown; NOT preserves unknown. AND is false
if either operand is false and true only if both are true. OR is true if either
operand is true and false only if both are false. Other combinations are unknown.
Only true selects a row. All atoms evaluate eagerly in source order; the first
evaluated type error or conflict fails the query, including a false AND or true
OR with an erroneous later operand. State tests inspect those states without
raising their value errors. No reordering or short-circuit rewrite is enabled.

## Aggregate functions

| Function | Input | Result | Empty input |
| --- | --- | --- | --- |
| `COUNT(*)` | Selected rows, including all cell states | uint64 | Zero |
| `COUNT(column)` | Top-level values of any admitted column type; null/missing skipped, error/conflict fails | Checked uint64 | Zero |
| `SUM(column)` | int64 values in source order | Checked int64; null/missing skipped, error/conflict fails | Null |

An aggregate returns one cell. There is no grouping, multiple aggregates,
`DISTINCT`, `AVG`, `MIN`, `MAX`, window function or user-defined
function. `SUM` does not widen its result type or reorder values to avoid an
intermediate overflow.

A direct aggregate cannot have an outer `LIMIT`. To aggregate a limited input,
use the [restricted derived-table form](select.md#aggregate-a-limited-input).

## Conversion and external work

String literals accept `::bytea`, `::uint64` and `::float64` type suffixes.
They decode binary hex, unsigned decimal integers and finite decimal floating
point respectively. SQL supports neither `CAST` nor arbitrary `::type` conversion. Secret references in
[connection options](create-connection.md) are separate grammar-only syntax;
they are not query functions.

A `SELECT` does not invoke HTTP, gRPC or application handlers. External work
uses the recorded [connector effect contract](../connectors.md), independently
of query evaluation. See [streaming and effects](streaming.md).
