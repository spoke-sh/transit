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

| SQL | Behavior |
| --- | --- |
| `SELECT *` | All one to eight declared columns |
| One to eight named columns | Ordered projection; duplicate names reject |
| `FROM source AS alias` | Alias supplies the column qualifier; source and output column identities stay unchanged |
| One comparison | Exactly typed int64, uint64, finite float64, bool, UTF-8 or binary literal; byte ordering for text/binary |
| `IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT` | Exact cell-state selection |
| `LIMIT` | Full u64 count after filtering; no limit means no implicit truncation |
| `COUNT(*)` | uint64 count including all cell states |
| `SUM(column)` | Checked int64 sum in source order; missing/null skipped, error/conflict fails |

The existing restricted aggregate subquery spells filter → limit → aggregate.
An outer aggregate LIMIT rejects. Uint64 and finite float64 comparison literals
use explicit `'digits'::uint64` and `'decimal'::float64` forms. `column = NULL`
rejects with `UnsupportedNullComparison`. No implicit casts or rewrites occur.
Document paths, expansion and text materialization belong to the declared source,
not SQL syntax. DDL, writes, joins, arbitrary expressions and continuous queries
remain unsupported. The [syntax guide](sql.md) defines parser bounds and escaping.

The SQL proof checks the production parser and current compiler. It independently evaluates 70 rows with
six scalar types and five cell states, compares actual nested Arrow at all eight
page widths under each source-kind basis, and exercises explicit failures.
These are pure engine source-basis checks; actual adapter/service recovery has
separate evidence in the [proof guide](../../../../tests/README.md).
