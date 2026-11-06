# Table joins and grouped aggregation

The relational Table profile executes one inner or left equijoin over two
explicit Tables, or grouped and ordered execution over one Table. Referenced
columns support BOOL, INT8, INT16, INT32 (INT/INTEGER), BIGINT, UINT64, FLOAT64,
DECIMAL, DATE, TIME, TIMESTAMP, UUID, TEXT and BINARY. SUM accepts BIGINT or
DECIMAL. Signed integer keys may join across widths: for example, an INT key
can match a BIGINT key. Comparison widens without truncation, while result
columns retain their original types. Other join keys require the same logical
descriptor and collation. Text comparison and grouping preserve the
column's declared collation, including its padding rule.
SQL, typed plans and the captured query owner use the same Fuze operators.

```sql
SELECT l.value AS left_value, r.value AS right_value
FROM observations l JOIN readings r ON l.key = r.key;

SELECT l.key, COUNT(*) AS pairs, COUNT(r.value) AS present,
       SUM(r.value) AS total
FROM observations AS l LEFT JOIN readings AS r ON l.key = r.key
GROUP BY l.key;

SELECT key, COUNT(*) AS rows, SUM(value) AS total
FROM observations WHERE value >= 0
GROUP BY key
HAVING COUNT(*) > 1
ORDER BY total DESC NULLS LAST, key ASC
LIMIT 10;
```

The console uses the selected account's service-owned catalog, independent
retained Table snapshots and bounded execution; see
[configuration and results](../../../../apps/transit-cli/docs/console.md#finite-relational-queries).
The Zig query API accepts one authorized catalog route per source in SQL order.
Routes share a realm and caller. A Table alias is local to the query and grants
no access. Aliases may use explicit `AS` or follow the Table name directly.
Qualify ambiguous column names; output names must be distinct.

`SELECT *` expands every column from the left Table followed by every column
from the right Table, preserving each declaration's column order. Joined
wildcards label all outputs as `table.column`, or `alias.column` when a Table
alias is present, so both join keys remain visible:

```sql
SELECT * FROM people INNER JOIN items ON items.id = people.id;
```

For example, the two `id` columns are named `people.id` and `items.id`.
`JOIN` and `INNER JOIN` are equivalent. Single-Table `*` retains the original
column names. Wildcards obey the existing projection, type and name limits;
use explicit columns with `AS` names if qualification exceeds a name limit or
quoted identifiers containing dots produce duplicate labels. Qualified wildcards
such as `people.*` and mixing `*` with explicit columns are not supported.

Tables retain bag multiplicity. Every equal-key pair contributes, including
duplicate rows. NULL keys do not match. A left join emits one null-extended row
only after complete right-side coverage proves that no right row matches.
`WHERE` filters the joined rows before grouping. Boolean predicates use the
existing three-valued, eager evaluation rules; this profile accepts typed scalar
comparisons and `IS [NOT] NULL`.

`COUNT(*)` counts contributors, `COUNT(column)` counts non-null values and
`SUM(column)` adds non-null BIGINT or DECIMAL values with checked arithmetic.
Decimal sums preserve the declared precision and scale, using i128 coefficients. SUM follows
stable left/right row-identity order and preserves the first overflowing
contributor, even if later values would reduce the mathematical total. It does
not widen to PostgreSQL's numeric result. Ungrouped empty input returns zero
counts and null sums; grouped empty input returns no rows. `HAVING` filters
completed groups using the same three-valued Boolean predicate semantics over
grouped columns and `COUNT`/`SUM` aggregates. Without `ORDER BY`, group output is
lexicographic under the declared collations with NULL first. `ORDER BY` sorts
grouped or ungrouped rows by up to eight column or aggregate expressions (`ASC`
or `DESC`, with `NULLS FIRST` default for `ASC`, `NULLS LAST` default for `DESC`,
and explicit `NULLS FIRST`/`NULLS LAST` overrides), breaking ties by canonical
group key or row-pair identity. Unqualified identifiers in `HAVING` and `ORDER BY`
resolve explicit `AS` output aliases before source columns. `LIMIT` truncates the
final ordered output. Aggregate names can also be unquoted aliases:

```sql
SELECT value, COUNT(*) AS count
FROM items GROUP BY value ORDER BY count ASC;
```

`COUNT` and `SUM` are function calls when followed by `(`; otherwise they can
name columns or aliases. A text group retains
the first contributor’s original spelling, including under ASCII_CI.

Prepared queries can bind WHERE, HAVING and LIMIT operands using typed `$1`
parameters (or MySQL `?` parameters). Types, repeated uses and parameter gaps
are checked before execution. NULL comparisons remain unknown; LIMIT requires a
non-null unsigned value. Single-Table queries also support the existing
scalar expressions in projections and ordering, including ordering by an alias.
Filtering precedes scalar evaluation. Sorting and LIMIT never hide a later
source-order arithmetic failure. Sorting uses bounded external storage; LIMIT
does not cap the number of spill records.

Direct Tables have separate partition cuts even within one catalog resource.
Repeated aliases of the same Table share one retained pin. This independent
vector provides no common catalog frontier or causal cross-Table guarantee.
Native-resource query sources retain their separate per-resource cut contract;
the result basis identifies which atomic domain each source uses. Current
source access is required even when a source contributes no output rows. The
[query reference](../queries.md#relational-boundary) describes interactive leases,
captured jobs, complete coverage and cleanup. A delivered prefix cannot replace
a complete relation.

Relational `EXPLAIN` resolves authorized metadata and reports a prepared plan,
output schema and proposed physical operators. It opens no data snapshot or
spill file and returns a null execution basis. Concurrent metadata revision
changes reject preparation. A later SELECT acquires its own basis and checks
read access independently.

The profile excludes DISTINCT, OFFSET, more than one
join, right/full/cross/non-equality joins, general subqueries,
type coercion beyond signed join-key widening and float sums. Existing single-source limits retain
their own semantics. Board, Flight and foreign-language query bindings retain
their separately declared profiles; parser support does not enable an operator
through another transport. Maintained execution has a separate contract from
these finite queries.

The checked `relationalQuery` grammar root and production `RelationalSql`
compiler are compared with an independent PostgreSQL AST on the selected corpus.
See the [grammar contract](../../../../contracts/sql/README.md) and
[relational contract](../../../../contracts/RELATIONAL_V1.md) for exact identities,
types and bounds.
