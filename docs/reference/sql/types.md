# Data types and cell states

SQL reads the types in an explicitly declared query source. It does not infer a
schema from application bytes or create a resource. Query types, SQL literal
syntax and grammar-only declaration types have different coverage.

## Scalar types

| Query v1 type | Read a declared column | SQL comparison literal | Grammar-only DDL token |
| --- | --- | --- | --- |
| int64 | Yes | Signed decimal integer, such as `-42` | `INT64` |
| uint64 | Yes | None; use a typed plan | None |
| float64 | Yes | None; use a typed plan | None |
| boolean | Yes | `TRUE`, `FALSE` | `BOOL` |
| UTF-8 | Yes | Single-quoted text, such as `'ready'` | `UTF8` |
| binary | Yes | Hex bytes, such as `'\x00ff'::bytea` | `BINARY` |

The last column applies to [CREATE TABLE](create-table.md) and
[CREATE KV](create-kv.md), which do not execute. Types available to a typed query
plan do not automatically acquire SQL literal or DDL syntax. There are no
implicit conversions; a comparison must match the column's exact scalar type.

The signed integer range is -9223372036854775808 through 9223372036854775807.
Decoded SQL text/binary literal cells have a 220-byte bound. See
[syntax and literals](syntax.md#query-literals) for escaping and parser bounds.

SQL has no `DECIMAL`, date, time, timestamp, interval, array, map or JSON type
syntax. Accepted Document fields can be exposed through an explicit scalar
projection; this does not add JSON path expressions to SQL. The interface does
not choose a fixed-point representation for application monetary values.

## Cell states

Nested query cells retain a state as well as a scalar type:

| State | Meaning | SQL behavior |
| --- | --- | --- |
| Value | A value of the declared scalar type | Projected as that value; comparisons require exactly typed operands |
| Null | Explicit absence of a value | `IS NULL` selects it |
| Missing | No value at the declared Document projection | Remains distinct from null; `IS NULL` does not select it |
| Type error | The source cannot supply the declared type | Preserved in row results; not coerced to null |
| Conflict | The source carries an unresolved conflict | Preserved in row results; not coerced to null |

`COUNT(*)` counts rows in every cell state and returns uint64, including zero
for empty input. `SUM(column)` accepts int64 values, skips null/missing, fails on
error/conflict and returns null for empty or all-skipped input. Overflow fails.
See [functions and operators](expressions.md) for the available SQL operations.

## Result interfaces

Query v1 returns nested typed cells through Arrow. The selected
[Flight SQL profile](../flight.md) instead exposes primitive int64 columns over
its configured Table subset and checks conversion of counts. A type supported
by native query v1 does not imply support through every SQL transport. See
[Arrow interchange](../arrow.md) and the
[query contract](../../../contracts/UNIFIED_QUERY_V1.md).
