# Table joins and grouped aggregation

The relational Table profile executes one inner or left equijoin over two
explicit Tables, or grouped aggregation over one Table. Referenced columns have
the exact int64 type (`BIGINT`); other columns can remain in the stored schema.
SQL, typed plans and the captured query owner use the same Fuze operators.

```sql
SELECT l.value AS left_value, r.value AS right_value
FROM observations l JOIN readings r ON l.key = r.key;

SELECT l.key, COUNT(*) AS pairs, COUNT(r.value) AS present,
       SUM(r.value) AS total
FROM observations AS l LEFT JOIN readings AS r ON l.key = r.key
GROUP BY l.key;

SELECT key, COUNT(*) AS rows, SUM(value) AS total
FROM observations WHERE value >= 0 GROUP BY key;
```

The console uses the selected account's service-owned catalog, independent
retained Table snapshots and bounded execution; see
[configuration and results](../../../../apps/transit-cli/docs/console.md#finite-relational-queries).
The Zig query API accepts one authorized catalog route per source in SQL order.
Routes share a realm and caller. A Table alias is local to the query and grants
no access. Aliases may use explicit `AS` or follow the Table name directly.
Qualify ambiguous column names; output names must be distinct.

Tables retain bag multiplicity. Every equal-key pair contributes, including
duplicate rows. NULL keys do not match. A left join emits one null-extended row
only after complete right-side coverage proves that no right row matches.
`WHERE` filters the joined rows before grouping. Boolean predicates use the
existing three-valued, eager evaluation rules; this profile accepts int64
comparisons and `IS [NOT] NULL`.

`COUNT(*)` counts contributors, `COUNT(column)` counts non-null values and
`SUM(column)` adds non-null int64 values with checked arithmetic. SUM follows
stable left/right row-identity order and preserves the first overflowing
contributor, even if later values would reduce the mathematical total. It does
not widen to PostgreSQL's numeric result. Ungrouped empty input returns zero
counts and null sums; grouped empty input returns no rows. Group output is
lexicographic with NULL first. This canonical order does not enable `ORDER BY`.

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

The profile excludes LIMIT, HAVING, DISTINCT, arbitrary ORDER BY, more than one
join, right/full/cross/non-equality joins, general subqueries, parameters,
implicit type coercion and float sums. Existing single-source limits retain
their own semantics. Board, Flight and foreign-language query bindings retain
their separately declared profiles; parser support does not enable an operator
through another transport. Maintained execution has a separate contract from
these finite queries.

The checked `relationalQuery` grammar root and production `RelationalSql`
compiler are compared with an independent PostgreSQL AST on the selected corpus.
See the [grammar contract](../../../../contracts/sql/README.md) and
[relational contract](../../../../contracts/RELATIONAL_V1.md) for exact identities,
types and bounds.
