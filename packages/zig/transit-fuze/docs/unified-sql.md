# Unified state SQL

`Unified.Sql.plan(allocator, text, source)` parses the complete read-only
SELECT grammar and lowers it to `Unified.Plan`. `compile(allocator, ast, source)`
accepts the same owned AST. Supply one explicit `Source { name, schema }`; the
compiler performs no catalog lookup, I/O or authorization. Projection and literal
slices belong to the supplied allocator. A bounded request arena is recommended.
The caller must bind the plan to the exact source basis before execution.

The source schema can describe KV, Table or accepted Document projections.
`transit-query.Bundle.fromSql` combines an explicit definition, SQL name and
positive execution budgets. `UnifiedClient.compileSql` first verifies current
source policy and its permitted budgets. Neither operation admits a query or
retains a source version. Subsequent finite upload and source admission establish
the committed source cut recorded in the result.

The [v1 SQL contract](../../../../contracts/UNIFIED_QUERY_V1.md#sql-capability-profile)
defines the exact profile:

| SQL | V2 behavior |
| --- | --- |
| `SELECT *` | All one to eight declared columns |
| One/two named columns | Ordered projection; duplicate names reject |
| One comparison | Exactly typed int64, bool, UTF-8 or binary literal; byte ordering for text/binary |
| `IS NULL` | Explicit null only; missing remains distinct |
| `LIMIT` | Full u64 count after filtering; no limit means no implicit truncation |
| `COUNT(*)` | uint64 count including all cell states |
| `SUM(column)` | Checked int64 sum in source order; missing/null skipped, error/conflict fails |

The existing restricted aggregate subquery spells filter → limit → aggregate.
An outer aggregate LIMIT rejects. Uint64/float64 columns can be projected;
comparison literals for those types, additional state tests, and more than two
explicit projection names currently require the typed API. `column = NULL`
rejects with `UnsupportedNullComparison`. No implicit casts or rewrites occur.
Document paths, expansion and text materialization belong to the declared source,
not SQL syntax. DDL, writes, joins, arbitrary expressions and continuous queries
remain unsupported. Parser bounds and escaping are unchanged from [v1](sql.md).

`just test::sql` checks both compilers. V2 independently evaluates 70 rows with
six scalar types and five cell states, compares actual nested Arrow at all eight
page widths under each source-kind basis, and exercises explicit failures.
These are pure engine source-basis checks; actual adapter/service recovery has
separate evidence in the [proof guide](../../../../tests/README.md).
