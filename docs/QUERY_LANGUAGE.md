# Query language: relational and dataframe surfaces over one plan

Status: design; nothing here is implemented. It elaborates [FUZE.md](FUZE.md)'s
already-decided pipeline — *"structured query API / later SQL frontend → typed
logical plan → qualified logical rewrites → physical plan → bounded Arrow
operators → result sink"* — into a concrete answer for DDL, DML, a dataframe
surface, and the connector/transport namespace idea. It does not reopen
[M16](roadmap/M16.md)'s existing commitment to a bounded **read-only** SQL
subset over Flight SQL, or [M12](roadmap/M12.md)'s decision that no SQL/textual
query language ships there. It proposes where a fuller relational surface would
sit relative to those, not a new milestone by itself.

## The one-line answer

Relational and dataframe are two **surface syntaxes**, not two engines. Both
compile to the same typed [logical query plan](GLOSSARY.md#arrow-execution-and-interchange)
Fuze already defines (`Stream.Plan`'s predicate/projection/limit/aggregate
today); neither becomes a second source of query semantics, matching the
roadmap's existing rule that *"SQL or RPC transport never replaces durable
authority."* A relational parser and a dataframe builder are both frontends
sitting to the left of "typed logical plan" in FUZE.md's pipeline — nothing
about the boundary changes if one, both, or neither ships.

## DDL: mostly a spelling problem, with one real prerequisite

`CREATE TABLE` is not a new capability. Station already has a typed
resource-creation path — `Table.create`/the `table_create` action, and the
growing profile's `create_resource` plus schema declaration — authorized and
executed identically to every other durable mutation. A relational DDL surface
is a text encoding of that same typed command, checked by the same
authorization before it ever reaches durable state; it does not bypass
anything or add a second creation path. `CREATE DOCUMENT` and `CREATE KV`
follow the same shape once [M13](roadmap/M13.md#entry-gates)'s Document model
and its KV adapter are specified — DDL surfaces what those milestones already
commit to build, it does not itself decide their schema/merge semantics.

The real prerequisite this exposes: today's Table schema is fixed at exactly
two columns (`id: int64`, one typed value column) — a KV-shaped table, not a
general relational one. `CREATE TABLE orders (id INT, sym TEXT, qty INT, px
FLOAT, ...)` with an arbitrary multi-column schema needs the Table model
itself to grow first. That is real scope, not a parser detail, and belongs
with whichever milestone owns schema evolution — plausibly M13's unified-query
work, plausibly its own. Naming DDL now should not be read as claiming
multi-column tables already exist.

## DML: SELECT is the qualified path, writes reuse what Table already has

`INSERT`/`UPDATE`/`DELETE` map onto Table's existing typed mutation API
(`insert`/`update`/`upsert`/`delete`) one-to-one — again a spelling of an
existing, authorized operation, not a new one. `SELECT` is the interesting
case: it compiles to Fuze's typed `Plan` (predicate, projection, limit,
aggregate) and executes through the same bounded, credited pipeline
[M10](roadmap/M10.md) qualified this cycle and [M12](roadmap/M12.md) is
scoped to expose — `WHERE`/column selection/`LIMIT`/`COUNT`/`SUM` map
directly onto the plan's existing shape; joins, grouping, subqueries and
window functions do not exist in that shape yet and would each need their own
qualification before a relational surface could claim to support them, not be
silently accepted as parsed syntax with unqualified execution.

[M16](roadmap/M16.md) already commits to exactly this SELECT-only slice,
narrower and further out: *"a bounded read-only SQL subset... translating
into Fuze's M9 plans; no separate engine."* A full DDL/DML relational
surface — this document's scope — is bigger than that existing commitment in
two ways: it writes, and M16 ties its SQL specifically to the Flight SQL
ingress path. Treat M16 as the first, narrowest instance of the relational
surface described here, not as the whole of it; a general DDL/DML surface
(`transit query`'s shell, a future direct SQL endpoint) is separate,
unscoped work this document intentionally does not turn into a milestone
number yet.

## The dataframe surface

A typed builder — `table.filter(col("qty") > 0).select("sym", "px").limit(100)`,
in whatever each [M11](roadmap/M11.md) language SDK's idiom is — compiling to
the identical `Plan` value SQL text would produce. This is the natural home for
programmatic query construction (composable, typed, no string interpolation,
no injection surface) and maps cleanly onto `Stream.Plan`'s existing Zig shape,
which already looks like a builder's target IR more than a parser's. It ships
per-language as part of M11's SDK surface, not as a separate engine feature —
one dataframe implementation per SDK, one plan representation underneath all
of them.

## Later: naming non-data components as queryable relations

The idea worth recording now, to implement later: `SELECT * FROM
connector.attempts WHERE ...`, `SELECT * FROM transport.connections`, or a
process/effect catalog addressed the same way — extending the relational
surface beyond Table/KV/Document to the [transport/connector/integration
tiers](CONNECTORS.md#transport-connector-and-integration) as read namespaces,
the way PostgreSQL's `pg_catalog` or SQLite's virtual tables expose system
state through ordinary `SELECT`.

This needs to be a **second kind of source**, not a stretched version of the
first. Table/KV/Document are versioned, authorized data Fuze reads through one
plan model with a stable revision. Connector attempts, transport state and
process/effect catalogs are exactly what [Board's public inspection
contract](BOARD.md#public-inspection-contract) already exposes — typed,
filtered, paginated facts with explicit coverage, not a queryable snapshot
with the same consistency contract as a Table read. The natural design is a
`schema.name` two-part namespace exactly like SQL's own `schema.table`
convention — `table.*`/`kv.*`/`document.*` naming Fuze's data sources,
`connector.*`/`transport.*`/`process.*` naming read-only projections of
Board's existing inspection API through the identical relational syntax,
without pretending the two have the same freshness or transaction semantics.

`INSERT INTO connector.blah` — spelling an effect dispatch as a relational
write — is a further step again: it would use DML syntax to trigger work at
an external boundary, not to durably store a row. That is worth having named
here so it is not lost, but it stays speculative until connectors
([M14](roadmap/M14.md)) exist to dispatch through at all; do not treat this
section as scoping that milestone's design.

## CONNECTION, SOURCE and SINK: naming the DDL for external data

This is a well-trodden shape, not a novel one — Materialize's `CREATE
CONNECTION ... TO KAFKA (...)`, `CREATE SOURCE ... FROM ... CONNECTION`,
`CREATE SINK ... INTO ... CONNECTION`, and the same three-way split in
RisingWave, ksqlDB and Flink SQL, exist for exactly the reason ours would:
separate *how to reach an external system* from *what shape of data flows
through it*, and let several sources/sinks share one authorized connection.
That split is also already ours, independently derived, in
[CONNECTORS.md](CONNECTORS.md#transport-connector-and-integration) — which
makes adopting the vocabulary a confirmation, not a borrowed dependency.

- **`CREATE CONNECTION`** is the DDL spelling of establishing one of
  [CONNECTORS.md](CONNECTORS.md)'s authorized, credentialed handles — a named,
  reusable binding to a transport/connector configuration (endpoint, secret
  reference, capability scope), not a live socket held open by the statement.
  It reuses [CONNECTORS.md](CONNECTORS.md#variables-and-secrets)'s existing
  secret-reference design: a connection names a credential binding, never
  stores or echoes the secret value.
- **`CREATE SOURCE`** declares a read relation whose rows arrive through a
  named connection. This is a new *kind* of Fuze [query source
  adapter](GLOSSARY.md#arrow-execution-and-interchange) — the same interface
  Table/KV/Document already implement — backed by a connector's captured
  observations instead of durable authoritative state. `SELECT` against it
  still compiles to the same typed plan; what differs is the adapter behind
  it, not the query surface.
- **`CREATE SINK`** declares a write target whose rows dispatch a connector
  effect. This is where a DML write stops meaning "durably store a row" and
  starts meaning "authorize an attempt" — it must carry
  [CONNECTORS.md](CONNECTORS.md#effect-boundary)'s attempt identity,
  idempotency and reconciliation contract, not a silent fire-and-forget
  write. A sink is the concrete, scoped form of the speculative `INSERT INTO
  connector.blah` idea above.

None of CONNECTION/SOURCE/SINK exist in Postgres; they are additive statement
forms, not a reinterpretation of anything Postgres already defines. That is
consistent with "superset": ordinary Postgres SQL keeps its Postgres meaning,
and Transit adds statement forms Postgres has no opinion on. Their exact
grammar productions, capability declarations and authorization checks are
follow-on work once the base grammar and its verification loop (below) exist;
this section fixes the shape and its grounding, not the syntax.

## Defining and verifying the grammar

### Postgres compatibility is a testable claim, not a formal one

"Superset of Postgres" should mean: every query Postgres accepts, ours parses
to an equivalent statement, and ours additionally accepts CONNECTION/SOURCE/
SINK and whatever else this document names. That is a *differential-testing*
claim, and it has a genuinely authoritative oracle: [`libpg_query`](https://github.com/pganalyze/libpg_query),
which packages Postgres's actual parser (extracted from Postgres source, not
re-derived) as a standalone library. Compatibility is proved by parsing a
corpus — Postgres's own regression-test SQL, `sqllogictest`, or a generated
corpus from a SQL-aware fuzzer such as [SQLancer](https://github.com/sqlancer/sqlancer)
— through both parsers and asserting agreement, the same "independent
consumer" pattern this repo already uses everywhere else (independent PyArrow
decoding, `Delivery.tla`'s independent projection, mutation testing against a
real guard). It is evidence with a stated corpus and a stated failure mode,
not a proof that no Postgres query exists that we mishandle.

### Grammar definition: a spec-and-checked format, not the production parser

Write the grammar in a format existing tools can mechanically check for
left-recursion, ambiguity and shift/reduce or reduce/reduce conflicts —
[ANTLR4](https://github.com/antlr/antlr4)'s `.g4` format is the most
practical choice: mature conflict/ambiguity diagnostics, and (since ANTLR
targets Java/Python/C#/Go/C++/JavaScript/Swift, none of them Zig) a
generated *reference* parser in one of those, used purely for cross-checking,
never shipped. Fuze's engine, planner and operators stay Zig native — nothing
about ANTLR's output becomes a runtime dependency. The production parser is
hand-written (or Zig-generated from the same `.g4` as its single source, if a
suitable code-generation path exists by then) Zig, tested for AST-equivalence
against the ANTLR reference parser on the same corpus. General context-free
grammar ambiguity is undecidable — no tool proves an arbitrary grammar
unambiguous — but ANTLR's parser construction succeeding without conflicts
*is* a real, tool-checked, meaningful property for the restricted grammar
class it builds, and worth stating precisely as that rather than as a
stronger claim.

### Is LEAN4 or TLA+ the right tool? Mostly no, with one real exception each

**TLA+ is the wrong tool for grammar syntax.** It specifies state machines —
sets, functions, sequences, and how they evolve across steps — which is
exactly why `Authority.tla` and `Delivery.tla` model *protocol behavior*
correctly. A context-free grammar isn't a state machine; encoding one as a
TLA+ spec would fight the tool for no benefit an actual parser generator
doesn't already give you for free. There is a genuine, narrower use nearby:
modeling the *execution* semantics of a DDL/DML statement against the
authority engine — does `CREATE SOURCE` interact safely with concurrent
grant changes, does a `SINK` write's effect dispatch compose correctly with
[`Delivery.tla`](../tests/verification/models/Delivery.tla)'s credit model —
but that models what a statement *does* once compiled to a plan, not the
grammar that parses it.

**LEAN4 has a real, narrow use here, already scoped by this repo before this
conversation**: [`docs/TESTING.md`](TESTING.md#formal-models) already says
Lean "is deferred until a specific theorem has value, such as a selected
CRDT's merge laws **or a Fuze rewrite with exact error semantics**." A query
*rewrite* — predicate pushdown, projection pruning, anything FUZE.md's
planning section requires to "preserve the specified result schema,
null/missing/conflict interpretation, numeric/error behavior and ordering" —
is precisely that kind of theorem, and grammar work is what would finally
generate enough concrete rewrite rules to make proving one worthwhile. Using
Lean to prove "this grammar is a superset of Postgres's" would mean first
formalizing the whole of Postgres's grammar in Lean, which doesn't exist and
would be a vastly bigger undertaking than the differential-testing approach
above for the same practical confidence. Don't reach for Lean until a
specific rewrite rule is written down and its preservation claim needs more
than test coverage — which may never be this grammar's job at all, since
rewrites operate on the compiled plan, not on parsed syntax.

## What this document is not

It does not select a SQL grammar, a dataframe API shape per language, or a
parser implementation. It does not move DDL/DML ahead of M12's read-only,
Table-only scope or M13's Document work, and it does not commit the
connector/transport namespace idea to a milestone number. It exists so the
next concrete proposal in this area — a grammar, a builder API, a system
catalog design — starts from one settled shape (surfaces compile to Fuze's
plan; system state is a different kind of source than data) instead of
re-deriving it.
