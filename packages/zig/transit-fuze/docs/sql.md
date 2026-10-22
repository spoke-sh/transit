# Read-only SQL syntax

`transit_fuze.Sql` parses one complete SELECT into an owned, bounded `Ast` and
supplies grammar expectations for editor assistance. `Unified.Sql` is the single
compiler: it resolves the AST against an explicitly supplied KV, Table or Document
schema and produces the current `Unified.Plan`. See [SQL execution](unified-sql.md)
for types, operators and result semantics.

```zig
const ast = try fuze.Sql.parse("SELECT value FROM items WHERE id >= 0 LIMIT 32");
const logical = try fuze.Unified.Sql.compile(allocator, ast, .{
    .name = try fuze.Unified.Name.init("items"),
    .schema = authorized_schema,
});
const bound = try logical.bind(authorized_basis, authorized_schema);
// Feed authorized pages to fuze.Unified.Stream.step.
```

Parsing allocates nothing and owns every parsed byte. The input text may be
released immediately after `parse`. `parseInto(text, result, location)` fills
caller-owned AST storage directly; discard that output on failure. It shares
parsing and optional location evidence with `parseLocated`. Compilation owns its projection and literal
slices in the supplied allocator. Neither step performs I/O, resolves a catalog,
retains a source version or grants access. The caller supplies current authority
and the exact source basis before execution. `Unified.Codec` is the canonical
plan codec.

The compiler supports exact cell-state tests and full-width uint64/finite
float64 literal suffixes. See [typed SQL](unified-sql.md) for their semantics.

## Syntax and escaping

Every query has exactly one `FROM` source and an optional Boolean predicate. Unquoted
ASCII identifiers fold to lowercase; quoted names preserve case and must still
be valid identifiers. `FROM source AS alias` supplies a query-local qualifier;
qualified columns use that alias when present, otherwise the declared source.
`AS` is required. Source aliases preserve the source and output column identities.
Catalog/schema resolution is unsupported.

`column AS name`, either COUNT form with `AS name`, and `SUM(column) AS name` supply owned output
names. Repeated source columns require distinct resulting names. Output aliases
do not change predicate scope, types or cell states. An inner projection's
aliases become the names available to the outer aggregate.

Literals are signed decimal int64, `TRUE`/`FALSE`, UTF-8 SQL strings with doubled
quotes, and bytea hex strings such as `'\x00ff'::bytea`. `IS NULL` selects explicit
null; comparisons with the `NULL` literal reject. Backslashes are literal. E
strings, dollar quotes, implicit casts and adjacent string concatenation are
unsupported. Keywords are case-insensitive. Whitespace, line and nested block
comments, and one optional terminating semicolon are allowed. Extra statements
or tokens fail.

To aggregate a limited input, use the admitted derived-table shape:

```sql
SELECT sum(chosen.value)
FROM (SELECT value FROM items WHERE id >= 0 LIMIT 2) AS chosen;
```

The inner projection must retain the aggregate column. The outer qualifier must
match the derived-table alias; the inner projection and predicate use the source
or its own explicit alias. Direct
aggregates can have a predicate but no outer LIMIT. An outer limit would apply
to aggregate output in SQL, so compilation returns `UnsupportedAggregateLimit`,
including for zero. Nested/general subqueries, row-output subqueries and outer
predicates are unsupported.

This is not PostgreSQL execution compatibility. Source order and checked int64
sums belong to the Fuze contract. The [grammar contract](../../../../contracts/sql/README.md)
distinguishes AST agreement from engine semantics.

## Bounds and errors

Statements are at most 4096 UTF-8 bytes; parsed names are at most 16 ASCII
identifier bytes. Block comments nest at most 16 levels. SQL literal decoding
admits at most 220 value bytes with 442 bytes of hex scratch storage. Typed plans
have their own larger cell and name bounds. These limits bound one operation,
not retained source cardinality. Parsing is a linear scan with no recursive
parser stack. The AST holds up to eight explicit projection items, each with an
optional owned alias, and up to 64 postfix predicate instructions. NOT binds
before AND, which binds before OR; parentheses override precedence. Operators
and group delimiters share a bounded 64-entry stack. The AST stores string
literal bytes in one statement-sized pool and owns its instruction storage;
copying it does not retain pointers into the input or the original AST. AND,
OR and NOT are reserved words. Single-atom/grouped-atom predicates retain their
existing plan representation; no Boolean algebra rewrites are performed;
`SELECT *` expands to every declared column during compilation.

Malformed encoding, NUL, unterminated strings/comments, oversized input,
out-of-range integers and unsupported syntax fail explicitly. Schema/name/type
validation runs before returning a plan. Unsupported DDL, writes, joins, sorting,
aggregation grouping, arithmetic and general casts do
not become executable merely because the reference grammar describes them.
There is no best-effort translation or successful partial parse.

The compiler does not host an endpoint. The [Transit CLI](../../../../docs/handbook/reference/cli.md),
Board query workspace and [Flight gateway](../../../../docs/handbook/reference/flight.md)
provide separately configured ingress and capability checks. No optimizer rewrite
is enabled.

The [test guide](../../../../tests/README.md) owns commands, evidence and limits
for ANTLR/PostgreSQL/Zig AST agreement, independently encoded current plans,
actual paged Arrow results, parser/compiler unit tests and scoped Lean theorems.
