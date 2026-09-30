# Read-only Table SQL

This page describes the specialized two-column Table compiler. `Unified.Sql`
uses the same parser for public KV/Table/Document plans; see [unified SQL](unified-sql.md) for its
separate capability, allocation and result rules.

`transit_fuze.Sql` is the allocation-free Zig frontend for
`Stream.Plan`. It parses one complete statement into an owned, bounded `Ast`,
then resolves names/types against a caller-supplied source descriptor:

```zig
const ast = try fuze.Sql.parse("SELECT value FROM items WHERE id >= 0 LIMIT 32");
const logical = try fuze.Sql.compile(ast, .{
    .name = try fuze.model.Name.init("items"),
    .schema = authorized_schema,
});
const bound = try logical.bind(authorized_basis, authorized_schema);
// Feed authorized ordered pages to fuze.Stream.step as usual.
```

`Sql.plan(text, source)` combines the first two calls. The input text can be
released immediately after `parse`; no AST or plan field borrows it. No heap,
network, catalog lookup, secret, retained source or background task is owned by
the compiler. A matching Table name/schema is not permission to read that Table.
The caller still supplies current authorization and an exact source basis.
`Stream.PlanCodec` persists the resulting plan without changing its encoding.

## Admitted SQL and semantics

| Form | Existing plan behavior |
| --- | --- |
| `SELECT *`, `id`, `value`, `id, value`, `value, id` | One/two named columns in the specified order; names come from the source schema |
| `WHERE column IS NULL` | Explicit null selection |
| `WHERE column =`, `<>`, `!=` a literal | Typed equality/inequality; null comparisons do not select rows |
| `WHERE column <`, `<=`, `>`, `>=` an integer or null | Ordered int64 comparison only |
| `LIMIT 0` through `LIMIT 32` on row selection | Whole-query limit after filtering, independent of page size |
| No `LIMIT` | `Stream.Plan.limit = null`; all selected rows, never an implicit 32-row truncation |
| `COUNT(*)` | Counts selected rows including null values; one int64 result |
| `SUM(column)` | One projected int64 column; skips nulls, null on empty/all-null, checked overflow in primary-key order |

Every query has exactly one `FROM table` and at most one predicate. Unquoted
ASCII identifiers fold to lowercase; quoted names preserve case but must still
be valid Fuze identifiers. `items.value` is accepted if the qualifier matches
the source. No source aliases or schemas/namespaces are resolved.

Literals are signed decimal int64, `TRUE`/`FALSE`, `NULL`, UTF-8 SQL strings with
doubled quotes, and bytea hex strings such as `'\x00ff'::bytea`. Backslashes
are literal (`standard_conforming_strings=on`); E strings, dollar quotes,
implicit type conversion and adjacent string concatenation are unsupported.
Keywords are case-insensitive. Whitespace, line/nested block comments and one
optional terminating semicolon are allowed. Extra tokens or statements fail.

To aggregate a limited input, use the one admitted derived-table shape:

```sql
SELECT sum(chosen.value)
FROM (SELECT value FROM items WHERE id >= 0 LIMIT 2) AS chosen;
```

The inner projection must retain the aggregate's column. The outer qualifier,
if present, must match `chosen`; the inner predicate uses the original source.
Direct aggregates may have a predicate but **no outer LIMIT**. An outer limit
would limit aggregate output in SQL, not input rows; compilation returns
`UnsupportedAggregateLimit`, including for zero. General/nested subqueries,
row-output subqueries and outer predicates are unsupported.

This is Fuze's Table SQL profile, not PostgreSQL execution compatibility.
Fuze specifies primary-key order and checked int64 sums; PostgreSQL can use
unspecified scan order without `ORDER BY` and widens int64 sums to numeric.
The [compatibility contract](../../../../contracts/sql/README.md) distinguishes
AST corpus evidence from engine semantics.

## Bounds and errors

The statement is at most 4096 UTF-8 bytes, names at most 16 ASCII identifier
bytes, block comments at most 16 levels, decoded cells at most 220 bytes.
Literal scratch storage is 442 bytes to admit the full 220-byte hex value.
These are per-operation parsing/encoding bounds, not source cardinality limits.
Parsing is a bounded linear scan with no recursive parser stack or allocations.
The AST stores two-column projections and one predicate directly.

Malformed text, non-UTF-8/NUL, unterminated strings/comments, oversized input,
out-of-range integers and unsupported syntax fail explicitly. Grammar-recognized
SQL can still fail compilation with `UnknownSource`, `UnknownColumn`,
`UnknownQualifier`, `DuplicateProjection`, `UnsupportedLimit`,
`UnsupportedAggregateLimit`, `UnsupportedAggregate`, `UnsupportedComparison`,
`TypeMismatch`, `CellTooLarge` or `InvalidBinaryLiteral`. Engine schema validation
is reused before returning a plan. No best-effort translation or successful
prefix is returned.

Joins, sorting, grouping, arithmetic, compound predicates, `COUNT(column)`,
output aliases, general casts, time travel, KV/Document sources and SQL writes
are excluded. Administrative DDL/connector statements remain reference-grammar
artifacts and produce `UnsupportedStatement` in the production frontend.
The compiler does not host an endpoint. The [Transit CLI](../../../../docs/reference/cli.md),
Board query workspace and [Flight gateway](../../../../docs/reference/flight.md)
provide separately configured ingress and capability checks. No optimizer rewrite
is enabled.

Run `just test::sql` for the shared ANTLR/PostgreSQL/Zig AST and actual paged
Arrow proof; `just check` includes the package's parser/compiler unit tests.
`just test::sql-rewrites` checks the separately scoped Lean theorems. See the
[test guide](../../../../tests/README.md)
for evidence and limitations.
