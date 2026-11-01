# Functions and operators

Transit SQL supports column projections, bounded typed scalar expressions, Boolean predicates and COUNT/SUM aggregates. Use
[SELECT](select.md) for clause order and complete queries, and
[data types](types.md) for scalar and cell-state behavior.

## Column expressions

`*` selects all declared columns. A named logical projection contains one to 128 output
positions, optionally qualified by the declared source name or its explicit
source alias. `column AS name` names an output position; repeated inputs require
distinct result names. `AS name` names either COUNT form and `SUM(column)`.
Output names do not enter `WHERE` scope. See
[projection and alias rules](select.md#project-rows) for case, collision and
derived-input behavior. Literals cannot be selected as result expressions.
The functions below execute in logical Table and file projections. General arithmetic operators, concatenation, `CASE` and other scalar functions remain unsupported.

## Typed scalar expressions

These finite expressions execute after `WHERE` selects a row. Arguments `a`, `b`
and `value` below are columns or nested admitted expressions; untyped literal
operands and expression predicates remain unsupported. Use `AS` to give each
result a distinct name. At most 32 scalar instructions, including input
references, fit in one plan; saved plans retain the existing 8-KiB identity
budget, including embedded timezone artifacts.

| Expression | Meaning |
| --- | --- |
| `DECIMAL_ADD(a,b,p,s,rounding)`, `DECIMAL_SUBTRACT(a,b,p,s,rounding)` | Exact scale promotion followed by explicit result rescaling |
| `DECIMAL_MULTIPLY(a,b,p,s,rounding)`, `DECIMAL_DIVIDE(a,b,p,s,rounding)` | Checked decimal arithmetic with explicit result precision and scale |
| `DECIMAL_RESCALE(value,p,s,rounding)` | Explicit decimal rescaling |
| `RANGE_OVERLAPS(a,b)`, `RANGE_CONTAINS(a,b)`, `RANGE_ADJACENT(a,b)` | Boolean relationship between ranges of the same exact subtype |
| `RANGE_COMPARE(a,b)` | Canonical range order as int64 -1, 0 or 1 |
| `VECTOR_DISTANCE(a,b[,metric])` | Metric over equal dimensions and element layouts |
| `column AT TIME ZONE 'zone'` | UTC timestamp to civil time using the column's pinned rules |
| `TIME_BUCKET(column,width_micros,'zone')` | Floor UTC input in civil coordinates to a positive microsecond width |
| `LOCAL_TO_UTC(column,'zone',fold)` | Civil timestamp to UTC, rejecting gaps and applying explicit fold policy |

Decimal `rounding` is `REJECT`, `HALF_EVEN` or `TOWARD_ZERO`; no monetary rounding
is implicit. `metric` is `L2_SQUARED`, `COSINE`, `DOT_PRODUCT` or `HAMMING`.
Omitting it requires both vector columns to declare the same metric. Binary
vectors require Hamming; numeric vectors reject Hamming. Zero-norm cosine
operands fail. Timezone names must match the column's declared immutable TZif
artifact. Fold policy is `REJECT`, `EARLIER` or `LATER`; gaps and unsupported
transition coverage fail. No host timezone database is consulted.
Nested timezone expressions carry those same pinned rules: for example,
`LOCAL_TO_UTC(ts AT TIME ZONE 'Etc/UTC','Etc/UTC',REJECT)` returns the original
UTC timestamp. UTC-to-civil operations still require UTC input; preserving the
rules does not permit an implicit timestamp-domain conversion.

Scalar operands preserve missing and null. Evaluated type-error or conflict
operands fail even if another operand is null. A row rejected by `WHERE` does
not evaluate its projection. Closing an executor cannot invalidate already
returned cells, and recovery uses the original instructions and timezone bytes.

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
their [fingerprint byte budget](../../../../packages/zig/transit-fuze/docs/file-sources.md#finite-file-plans).

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
| `SUM(column)` | int64 or decimal values in source order | Checked int64 or DECIMAL(38,s), preserving decimal input scale; null/missing skipped, error/conflict fails | Null |

An aggregate returns one cell. There is no grouping, multiple aggregates,
`DISTINCT`, `AVG`, `MIN`, `MAX`, window function or user-defined
function in this single-source profile. COUNT and SUM also accept an admitted scalar expression. Decimal SUM widens precision to 38 while preserving scale; integer SUM retains int64. Neither reorders values to avoid an intermediate overflow.

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
