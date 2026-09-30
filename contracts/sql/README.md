# SQL grammar and rewrite proofs

The public [SQL statement reference](../../docs/reference/sql.md#statement-forms)
covers every statement below with syntax, examples and execution limits, including
the separate [historical-read fragment](../../docs/reference/sql/as-of.md).

The reference grammar covers read-only single-Table `SELECT` and the existing
administrative extension syntax. `TransitExtensions.g4` is the checked reference;
generated Python/ANTLR files stay in `.cache/verification/sql`, outside production.
The implemented [Zig compiler](../../packages/zig/transit-fuze/docs/unified-sql.md)
lowers SELECT syntax against declared KV/Table/Document schemas to the current
`Unified.Plan` and canonical `FZP1` bytes. The shared parser owns the AST and
cursor assistance; there is one compiler and execution definition. Its capability
matrix covers whole-query limits, star projection, nested cell states, full-width
count and unsupported null comparisons. Administrative reference grammar does not
imply an executable administrative operation. The [proof ledger](../../tests/README.md)
records independent grammar, plan and result checks. The shared grammar admits
projection lists; lowering accepts up to eight explicit declared columns.
No rewrite is enabled.

## Reproducible reference checks

From the pinned development shell:

```sh
just test::sql             # includes grammar + Zig AST/plan + Arrow checks
just test::sql-grammar     # reference-only focused check
just test::sql-rewrites
```

[sql-tools.nix](../../nix/sql-tools.nix), exported by `flake.nix`, selects ANTLR
4.13.2, Lean 4.29.1 and pglast 7.13 from the existing `flake.lock`. The latter
packages `libpg_query`'s PostgreSQL 17.7 parser. These are verification tools;
none is a Fuze runtime dependency. No lock update or compiler upgrade is needed.
The bindings shell roots this optional closure for CI caching.

The grammar recipe regenerates with `-Werror`, requires empty diagnostics,
and parses the shared corpus with exact ambiguity detection enabled. This
establishes no reported generation conflicts or ambiguities on those inputs;
it is not a proof of global grammar unambiguity.

## Compatibility corpus

[statements.json](corpus/statements.json) includes 14 unchanged statements from
PostgreSQL **REL_17_5** `int8.sql` and `select.sql`. Vendored excerpts preserve
original text; the manifest records original URLs, line ranges and SHA-256 hashes
of both complete upstream files and excerpts. The [upstream license](corpus/POSTGRES-COPYRIGHT)
applies to those excerpts. Qualification verifies excerpt hashes and each
statement's exact correspondence to the vendored lines without a network fetch.

The remaining Transit-authored cases cover operators, signed integer boundaries,
nulls, boolean/text/binary literals, projections, comments, input limits,
aggregates and compilation exclusions. ANTLR and `libpg_query` must produce the
same normalized AST for every positive case, including statements deliberately
rejected later for schema, type or limit reasons. Negative cases require complete
input rejection; prefixes and additional statements cannot pass as one query.

“Compatible” here means acceptance and AST agreement for this declared subset,
under `standard_conforming_strings=on`. It does **not** mean all PostgreSQL SQL
is accepted, full execution equivalence, or a formal superset theorem. In
particular, Fuze's checked int64 sum differs from PostgreSQL's widened numeric
sum, and Fuze supplies deterministic primary-key order without a SQL `ORDER BY`.
DDL and connector extensions are additive syntax, not PostgreSQL compatibility
cases. The Transit-specific state predicates use independent ANTLR/Arrow
fixtures; uint64/float64 type suffixes have parser agreement without claiming
PostgreSQL has those builtin types. Broader regression suites, fuzz discovery and server execution comparison
remain outside this evidence.

## Grammar coverage

The read grammar permits one Table, one optional typed comparison or exact cell-state test,
one to eight columns or star, row output, `COUNT(*)`, and `SUM(column)`. Identifiers
fold to lowercase unless quoted. Column qualification is optional; table aliases
are admitted only on the single restricted aggregate input subquery. Strings
escape quotes by doubling them; bytea literals use `'\x00ff'::bytea`. Keywords
are case-insensitive. Line/block comments and one optional terminator are admitted.
The production profile additionally bounds names, literals, statement size and
comment nesting; grammar acceptance alone does not validate those budgets.

`SELECT count(*) FROM (SELECT * FROM items WHERE id > 0 LIMIT 2) AS chosen`
spells Fuze's filter → limit → aggregate order. A direct aggregate's outer
`LIMIT` is syntactically recognized but cannot be lowered as an input limit.
No optimizer rewrite is implied. General subqueries, joins, grouping, sorting,
compound predicates, expression arithmetic, writes, general casts,
`COUNT(column)`, aliases on output columns and adjacent-string concatenation
are outside the grammar. `AS OF` remains a separately checked fragment.

`CREATE TABLE`/`DOCUMENT`/`KV`/`CONNECTION`/`SOURCE`/`SINK`, `GRANT`, `REVOKE`,
`SHOW` and `DESCRIBE` are grammar-only. They do not execute typed commands,
resolve catalogs or authorize effects. SQL writes are not grammar-checked here.

## Lean scope

[FuzeRewrite.lean](FuzeRewrite.lean) has four complete Lean 4.29.1 theorems:

| Theorem | Exact claim / premises | Printed axioms |
| --- | --- | --- |
| `filter_reorder_preserves_selection` | Reordering two total boolean predicates preserves selected rows and order | `propext` |
| `projection_pruning_preserves_rows` | Final projection factors through retained fields, preserving output values and field/row order | `propext` |
| `predicate_pushdown_through_projection` | A fallible predicate factors through a total projection; moving it before projection preserves rows and the exact first error | None |
| `pushdown_preserves_downstream_errors` | The same downstream fallible consumer receives the same rows or earlier error after that pushdown | None |

The recipe requires these named theorems, rejects Lean errors/warnings and
`sorryAx`, and checks the printed axiom sets. No deferred theorem is represented
by a placeholder proof. Moving limits across filters and reassociating checked
int64 sums are generally false and are not asserted. Partial/effectful projection
rewrites need additional premises; implementation refinement remains deferred.

The correspondence note maps validated `Plan.matches` predicates, null selection,
ordered projections and `Stream.step`'s unchanged limit/sum consumer to the
abstract model. It is an explicit assumption, not a proof about Zig or Arrow.
Schema validation precedes execution. Source identity, current authorization,
allocation failure, cancellation and retained-source availability require their
own implementation qualification. No optimizer rewrite is enabled by these
proofs, and the downstream theorem does not prove moving a limit or aggregate.
