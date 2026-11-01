# SQL grammar and rewrite proofs

The public [SQL statement reference](../../docs/handbook/reference/sql.md#statement-forms)
covers every statement below with syntax, examples and execution limits, including
the [historical snapshot suffix](../../docs/handbook/reference/sql/as-of.md).
The [grammar surface inventory](../../docs/handbook/reference/sql/grammar-surface.md)
separates implemented profiles, checked grammar, proposed syntax and undecided
syntax. Column `COLLATE UTF8_BINARY`, `ASCII_CI`, `EBCDIC_CP037`,
`EBCDIC_037_PAD` and `EBCDIC_1047_NOPAD` clauses
belong to the checked Table grammar. Proposed graph, foreign-relation, physical
encoding (`ENCODING`), expression collation and branching examples remain outside
this checked grammar. `AS OF SNAPSHOT` is a statement-level suffix over the
exact retained catalog; its quoted selector is validated by `HistoricalSql`
before names are resolved. The former ambiguous integer system-time fragment
is removed. `FOR SYSTEM_TIME` remains reserved for temporal-table semantics.

The reference grammar covers finite SELECT, general typed Table DDL/DML and
administrative extension syntax. `TransitExtensions.g4` is the checked reference;
generated Python/ANTLR files stay in `.cache/verification/sql`, outside production.
The Zig compilers lower against explicit schemas and source commitments. General
Table statements share `TableDdl`, `TableDml`, `TableSelect`, typed literals and
logical descriptors; the source-bound logical query plan uses canonical `FQP1`
bytes. Runtime authorization and storage publication remain separate from parsing.

`LogDdl` owns dedicated Stream/Queue CREATE, policy ALTER, RENAME and DROP
compilation, sharing the logical column grammar with `TableDdl`. The independent
`corpus/log-declarations.json` cases cover defaults, routing, retention, FIFO,
limits and unsupported options through `just test::table-ddl-sql`. Named
`SHOW STREAM/QUEUE` and `DESCRIBE STREAM/QUEUE` use the ordinary SQL metadata
result lifecycle. The [executable profile](../../docs/handbook/reference/sql/streaming.md#stream-and-queue-declarations)
lists exact options and limits. `SHOW STREAMS` and `SHOW QUEUES` use bounded
Catalog pages with current disclosure checks; payload verbs remain outside
that profile. `just test::sql-log-declarations` exercises actual native,
PostgreSQL and MySQL sessions, original-token recovery and buffered denial.

Table schemas and projections admit up to 128 columns. Logical types, parameter
bounds, row budgets and operator/transport capabilities are checked by their
owning compiler and runtime. Reference grammar acceptance alone does not enable
a SQL entry point or an operator on every stored type. The
[proof ledger](../../docs/history/qualification/README.md) records independent grammar, schema, plan
and result checks. No optimizer rewrite is enabled.

`parameterTemplate` is a separate checked root for the explicit Zig
`Prepared` compiler. It permits typed `$n` comparison and LIMIT operands;
ordinary statements continue to reject unresolved placeholders. The
[parameter contract](../SQL_PARAMETERS_V1.md) and
[shared corpus](corpus/parameters.json) define its exact scope. This does not
enable named PREPARE/EXECUTE. The CLI and SDKs submit explicit typed bindings
through the shared compiler; see the parameter contract.

`configurationSelect`, `sessionSettingStatement` and the settings alternatives
of `showStatement` belong to the shared query package's `SettingsSql` compiler.
It lowers typed metadata predicates/projections through Fuze's `TableSelect`;
administrative reload remains a separate explicit execution operation. See
[settings SQL](../../docs/handbook/reference/sql/settings.md) for its bounded profile.

`SHOW STORAGE` reads the signed native node storage observation under a current
realm-wide inspection grant. It reports the resolved root, aggregate allocation
limits/use and volatile maintenance activity. Null fields mean unavailable.

`SHOW STORAGE FOR name` belongs to the shared SQL session's direct Table
inspection adapter. It returns one typed row from the signed direct Table
`storage` operation under current metadata-inspection rights. It does not pin a
snapshot, flush data or invoke the application runtime. The console and database
wire adapters share this operation; query-source-only and Flight SELECT entry
points do not accept it. `STORAGE` remains a contextual identifier, including in
dotted setting names. See [SHOW](../../docs/handbook/reference/sql/show.md) for the
bounded backlog and accepted-frontier semantics.

`transactionStatement` lowers through `transit-sql.TransactionSql` to the shared
session controls. It accepts serializable or read-only BEGIN/START, COMMIT,
ROLLBACK and named savepoint controls. Other isolation levels, chaining, nested
transactions and implicit commits are excluded. See
[transactions](../../docs/handbook/reference/sql/transactions.md).

## Capability ledger

[standards-ledger.json](standards-ledger.json) is the neutral owner of the
capability inventory. Each entry records its public parse, lowering, execution,
recovery and transport scope separately. An implemented entry covers only its
stated profile and deviations; it does not certify an entire ISO feature or
promote a standalone helper to SQL support. Physical-codec entries describe
typed TableSchema admission; SQL `ENCODING` remains reference-only.

`tests/query/logical/standards_ledger.py --write` regenerates the ledger digest and
its Zig projection, `StandardsLedgerData.zig`, and the generated capability
summary in the [grammar inventory](../../docs/handbook/reference/sql/grammar-surface.md#capability-ledger).
Feature records require an explicit public profile, evidence sources and a
`reference_verified` flag; unverified edition/clause labels are not standards
conformance claims. The Transit-authored MIT compiler cases bind a feature to an
actual `table_ddl`, `table_ddl_catalog`, `relational_sql` or `inspection` entry point and its expected
acceptance. Fuze executes those cases against the production compiler.
The catalog DDL cases supply exact parent metadata to the production resolver;
they do not publish a constraint or assert runtime authorization. Positive cases
require an implemented parse profile; negative cases also cover exclusions within
implemented profiles. The check compares every field, rejects dependency cycles
and contradictory positive expectations, and verifies the generated public summary. This is a consistency
check. Actual compiler tests and installed SQL session tests establish behavior;
file presence and fixture regeneration do not establish execution or recovery.

## Reproducible reference checks

From the pinned development shell:

```sh
just test::sql             # includes grammar + Zig AST/plan + Arrow checks
just test::sql-grammar     # reference-only focused check
just test::table-ddl-sql   # general schemas and selected evolution
just test::table-dml-sql   # typed mutation plans; no publication claim
just test::sql-rewrites
just test::diagnostic-grammar # parser branches and actual compiler diagnostics
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
sum. Finite source traversal follows each source's declared identity/index order;
this does not implement SQL `ORDER BY`.
DDL and connector extensions are additive syntax, not PostgreSQL compatibility
cases. The separate [mutation corpus](corpus/mutations.json) compares bounded
Table syntax and exact typed `FDM1` plan bytes against an independent Python
interpretation, including omitted/defaulted fields and compound literals. These
compiler checks do not claim stored-row uniqueness, public admission or native
recovery; the Table storage and native schedules qualify those separately. The Transit-specific state predicates use independent ANTLR/Arrow
fixtures; uint64/float64 type suffixes have parser agreement without claiming
PostgreSQL has those builtin types. Broader regression suites, fuzz discovery and server execution comparison
remain outside this evidence.

## Grammar coverage

The ordinary `statement` read grammar permits one source, an optional Boolean predicate over typed comparisons and exact cell-state tests,
a projection bounded by the declared schema or star, row output, `COUNT(*)`, `COUNT(column)`, and `SUM(column)`. Identifiers
fold to lowercase unless quoted. Column qualification is optional; `FROM source
AS alias` makes the alias its column qualifier. `AS` is required. The restricted
aggregate input subquery has a separate outer alias. Row projections and
aggregates accept explicit `AS name` output aliases. Output names are distinct;
an inner projection's renamed columns are available to the outer aggregate,
while predicates resolve original source columns. Strings
escape quotes by doubling them; bytea literals use `'\x00ff'::bytea`. Keywords
are case-insensitive. Line/block comments and one optional terminator are admitted.
The production profile additionally bounds names, literals, statement size and
comment nesting; grammar acceptance alone does not validate those budgets.
NOT binds before AND, which binds before OR; parentheses override precedence.
The production parser admits 64 postfix instructions and a 64-entry stack for
pending operators/group delimiters. It preserves source order and owns compact
literal storage within the statement byte bound. Native and local file SQL execute these
programs with the same three-valued, eager first-error semantics. Each plan
profile validates atoms against its own admitted logical types and byte budgets.

`SELECT count(*) FROM (SELECT * FROM items WHERE id > 0 LIMIT 2) AS chosen`
spells Fuze's filter → limit → aggregate order. A direct aggregate's outer
`LIMIT` is syntactically recognized but cannot be lowered as an input limit.
No optimizer rewrite is implied. General subqueries, sorting,
expression arithmetic, general casts,
and adjacent-string concatenation
are outside the grammar. `AS OF` remains a separately checked fragment.

`relationalQuery` is a separate checked root for the explicit Table relational
profile. It accepts optional EXPLAIN, one or two Table targets with explicit or
implicit aliases, one inner/left equijoin, mixed column/COUNT/SUM selections,
Boolean WHERE and GROUP BY. The [relational corpus](corpus/relational.json)
compares normalized sources, aliases, outputs, joins, group keys and predicate
instruction order across ANTLR, PostgreSQL and production Zig. `just
test::relational-sql` executes this comparison and is included in `test::sql`.
The ordinary grammar root retains its existing one-source/subquery/LIMIT
profile. Contextual join/group words remain identifiers where the existing
language allows them; unquoted implicit source aliases cannot consume clause
words. Type admission, distinct output names, grouping legality, source rights
and execution budgets remain semantic checks. LIMIT, HAVING, DISTINCT, ORDER BY,
parameters, additional joins and arbitrary expressions are excluded from the
relational root. Reference grammar predicates share literal syntax; executable
relational binding admits only exact int64 comparisons and NULL-state tests.

`TableDdl.compile` owns general CREATE/ALTER/DROP compilation. CREATE defaults
to nullable columns and supports aliases, logical descriptors, deterministic
typed defaults and explicit single/composite primary keys. ALTER binds stable
column identities to the original schema and defines a complete successor;
existing-row validation and atomic publication remain runtime obligations. DROP
binds the original object under RESTRICT semantics and preserves retained evidence.
The [schema contract](../TABLE_SCHEMA_V1.md), [DDL contract](../TABLE_DDL_V1.md)
and [Table reference](../../docs/handbook/reference/tables.md) own exact semantics.

`TableDml.compile` binds INSERT column lists or positional rows, omitted/defaulted
fields, multiple constant assignments and Boolean/state predicates. `FDM1`
encodes the original schema fingerprint, exact typed values and ordered predicate
program. Native publication accepts the complete operation or a truthful rejected
outcome; a compiled plan alone proves neither acceptance nor application.

The [declaration corpus](corpus/declarations.json) compares independent ANTLR
schema construction, aliases/defaults/keys, canonical `FTS1` bytes and selected
ALTER/DROP results. Offline KV/Document compilation retains its separate owned
definitions and review formatting. These are not PostgreSQL DDL compatibility
or administrative execution checks. General Table execution uses the configured,
authorized direct catalog owner. CREATE performs recoverable native registration
and Table publication under current policy; offline compilation performs neither.
Ownership and applicable default grants govern the resulting object's access.
Query-only transports continue to reject writes and administration.

`authorizationStatement` is the dedicated role/schema/privilege compiler root.
It includes selected GRANT/REVOKE, membership options, creator/schema defaults,
ownership and explicit SET/RESET ROLE. Production `AuthorizationSql` validates
name/statement bounds, option duplication, privilege applicability and PUBLIC
restrictions. Catalog lowering resolves stable IDs at one policy basis; native
and catalog owners perform explicit preparation/publication. The
[authorization reference](../../docs/handbook/reference/sql/authorization.md) identifies
executable interfaces and limits. Query-only roots do not apply policy changes.

`CREATE CONNECTION`/`SOURCE`/`SINK`, connector listing forms,
and KV/Document publication remain grammar-only. No offline declaration resolves
credentials, provisions resources or authorizes external effects.

## Lean scope

[FuzeRewrite.lean](FuzeRewrite.lean) has four complete Lean 4.29.1 theorems:

| Theorem                                 | Exact claim / premises                                                                                                        | Printed axioms |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------- |
| `filter_reorder_preserves_selection`    | Reordering two total boolean predicates preserves selected rows and order                                                     | `propext`      |
| `projection_pruning_preserves_rows`     | Final projection factors through retained fields, preserving output values and field/row order                                | `propext`      |
| `predicate_pushdown_through_projection` | A fallible predicate factors through a total projection; moving it before projection preserves rows and the exact first error | None           |
| `pushdown_preserves_downstream_errors`  | The same downstream fallible consumer receives the same rows or earlier error after that pushdown                             | None           |

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
