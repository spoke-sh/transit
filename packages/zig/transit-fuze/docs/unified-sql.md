# Unified state SQL

`Unified.Sql.plan(allocator, text, source)` parses the complete read-only
SELECT grammar and lowers it to `Unified.Plan`. `compile(allocator, ast, source)`
accepts the same owned AST. Supply one explicit `Source { name, schema }`; the
compiler performs no catalog lookup, I/O or authorization. Projection and literal
slices belong to the supplied allocator. A bounded request arena is recommended;
`Unified.Sql.deinit` releases a compiled plan with its original allocator. It must
not be used for decoded plans, which borrow encoded bytes.
The caller must bind the plan to the exact source basis before execution.

The source schema can describe KV, Table or accepted Document projections.
`transit-query.Bundle.fromSql` combines an explicit definition, SQL name and
positive execution budgets. `UnifiedClient.compileSql` first verifies current
source policy and its permitted budgets. Neither operation admits a query or
retains a source version. Subsequent finite upload and source admission establish
the committed source cut recorded in the result.

The [v1 SQL contract](../../../../contracts/UNIFIED_QUERY_V1.md#sql-capability-profile)
defines the exact profile:

| SQL                                                                 | Behavior                                                                                                  |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `SELECT *`                                                          | All one to eight declared columns                                                                         |
| One to eight named columns                                          | Ordered projection; duplicate names reject                                                                |
| `column AS name`, `COUNT(*) AS name`, `COUNT(column) AS name`, `SUM(column) AS name`         | Owned output names; repeated inputs are allowed with distinct output names                                |
| `FROM source AS alias`                                              | Alias supplies the column qualifier; source and output column identities stay unchanged                   |
| Each comparison atom                                                | Exactly typed int64, uint64, finite float64, bool, UTF-8 or binary literal; byte ordering for text/binary |
| `IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT` | Exact cell-state selection                                                                                |
| `NOT`, `AND`, `OR`, grouping                                        | Up to 64 postfix instructions; precedence in that order; eager first-error evaluation                     |
| `LIMIT`                                                             | Full u64 count after filtering; no limit means no implicit truncation                                     |
| `COUNT(*)`                                                          | uint64 count including all cell states                                                                    |
| `SUM(column)`                                                       | Checked int64 sum in source order; missing/null skipped, error/conflict fails                             |
| `COUNT(column)` | Checked uint64 value count; any admitted type, missing/null skipped, error/conflict fails |

The existing restricted aggregate subquery spells filter → limit → aggregate.
An inner output alias becomes the column name resolved by the outer sum. Output
aliases do not enter `WHERE` scope; predicates retain original source names.
Output names are inline in the plan and affect canonical bytes and result-schema
identity without changing the input schema or source basis.
An outer aggregate LIMIT rejects. Uint64 and finite float64 comparison literals
use explicit `'digits'::uint64` and `'decimal'::float64` forms. `column = NULL`
rejects with `UnsupportedNullComparison`. No implicit casts or rewrites occur.
Comparisons on null/missing stay unknown through NOT; only true selects. Atoms
evaluate in source order, including after a determining Boolean value. The first
type error or conflict aborts evaluation; no short-circuit rewrite is enabled.
Document paths, expansion and text materialization belong to the declared source,
not SQL syntax. DDL, writes, joins, arbitrary expressions and continuous queries
remain unsupported. The [syntax guide](sql.md) defines parser bounds and escaping.

`Sql.parseLocated`, `parseInspectionLocated`, `parseMutationLocated` and
`parseDeclarationLocated` accept an optional `*Sql.Location` while preserving
their ordinary parser's results and errors. A failure supplies a statement byte
offset and, when known, static expected-token vocabulary. EOF points just beyond
the final byte; lexer failures point to the offending token's start.

`SqlDiagnostic.query(text, cause, inspection)` explains a SQL compilation or
inspection failure. The boolean selects whether the calling interface accepts
SQL inspection. Unknown runtime errors return null; callers retain their own
authorization, transport and uncertain-outcome handling. This is local failure
presentation, not a runtime feature registry or authorization check. Mutation and
state-declaration syntax is checked through its production parser; grammar-only
families are labeled without claiming full syntax validation.

The returned diagnostic owns a bounded, redacted context buffer and borrows only
static vocabulary. `render` emits an ASCII excerpt/caret and guidance;
`renderRemote` emits at most 128 printable ASCII bytes, with only static vocabulary
and numeric coordinates. Neither performs I/O or copies source into telemetry.
Diagnostic rendering does not change ASTs, plan bytes or saved requests.

The SQL proof checks the production parser and current compiler. It independently evaluates 70 rows with
six scalar types and five cell states, compares actual nested Arrow at all eight
page widths under each source-kind basis, and exercises explicit failures.
These are pure engine source-basis checks; actual adapter/service recovery has
separate evidence in the [proof guide](../../../../tests/README.md).
