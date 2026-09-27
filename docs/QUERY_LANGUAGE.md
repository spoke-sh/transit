# Query language: relational and dataframe surfaces over one plan

Status: M12's read-only, single-Table `SELECT` frontend is implemented and
qualified. The [SQL guide](../packages/zig/transit-fuze/docs/sql.md) owns its
exact grammar, budgets and `Sql.parse` / `Sql.compile` / `Sql.plan` API.
It produces the existing `Stream.Plan`/`PlanCodec` and runs through Fuze's
bounded Arrow engine. It introduces no public query endpoint or CLI.
The DDL/DML-write, broader dataframe and connector/transport namespace designs
below remain direction, not implemented SQL capabilities. [M13](roadmap/M13.md)
owns public typed query access; [M19](roadmap/M19.md) owns Flight SQL ingress
and should reuse this compiler. Neither milestone acquires new authority from
accepting query text.

## The one-line answer

Relational and dataframe are two **surface syntaxes**, not two engines. Both
compile to the same typed [logical query plan](GLOSSARY.md#arrow-execution-and-interchange)
Fuze already defines (`Stream.Plan`'s predicate/projection/limit/aggregate
today); neither becomes a second source of query semantics, matching the
roadmap's existing rule that *"SQL or RPC transport never replaces durable
authority."* A relational parser and a dataframe builder are both frontends
sitting to the left of "typed logical plan" in FUZE.md's pipeline — nothing
about the boundary changes if one, both, or neither ships.

## Declarative model and visual interfaces

Design Board over this declarative model. A Table schema, connection definition,
source dependency, sink destination or access policy should have the same meaning
whether inspected as SQL, a form, a diagram or a typed API value. Start with the
language and owning operation contract, then choose the visual representation.
Adding an SQL preview to an independently designed configuration form is not
enough: the field constraints, dependencies, validation and resulting operation
must agree across surfaces.

Queries lower to Fuze's shared typed plans. Administrative declarations and
controls require their own typed public-operation lowering; they do not become
Fuze operators or grant new kernel authority. The target is shared semantics,
not a requirement to send SQL text through every API. Durable accepted state
remains authoritative, rather than a browser draft or a second configuration
database. Keep a proposed definition, accepted definition and observed runtime
state distinguishable. Declarative intent does not imply automatic reconciliation,
continuous execution or safe retries without an owning lifecycle contract.

Every visual design must identify which operations execute today, which exist
only in the reference grammar, and which still need syntax and semantic design.
`CREATE` syntax does not define `ALTER`, `DROP`, migration or idempotent apply;
SQL names do not yet supply catalog resolution, identity or authorization.
For unsupported constructs, preserve the text and show a precise limit rather
than silently translating or discarding part of a declaration. UI-only layout,
selection and chart settings are presentation state, not new SQL capabilities.

[Board console D2](design/board-console/D2.md) applies this principle to a
two-level Workspace/Operations hierarchy, black-and-white studies and a mapping
from the existing grammar to proposed screens. Its hierarchy and interactions
remain a design proposal. It neither implements the administrative grammar nor
expands M12/M13's qualified query profile.

[Board console D4](design/board-console/D4.md) makes Explore a SQL-first browser
shell over this model. Grammar-derived lexical/context information, executable
capability rules and authorized catalog metadata jointly drive proposed completion
and highlighting. The checked grammar is an input to a future editor service,
not an existing incremental/completion API. Editing assistance must handle
incomplete text without weakening complete-statement compilation at execution.
Resource discovery uses the same authorized metadata through the top navigation's
Transit-wide search, with section/object context influencing relevance and explicit
filters narrowing scope. Its Data view keeps typed results, inline statistics
and schema previews. [Search notes](design/board-console/SEARCH.md) separate
retrieval/index projections from ranking and declarative authority; no search
or vector SQL syntax is invented. Search text is not SQL;
inserting a resource name is an explicit, context-checked SQL edit. Catalog
statistics describe their resource and observation, not the worksheet's result.
Its live refinement proposes automatic evaluation of qualified read queries
as text changes, including probabilistically selected complete candidates.
Live/Paused controls scheduling; Snapshot/Stream controls time semantics.
Probability may choose which work is useful, not weaken compilation, authority
or evidence. A speculative answer names its candidate separately from the draft.
Result summaries describe an exact execution or committed stream frontier and
explicit profile coverage; chart/summary controls do not independently dispatch
queries. A closable right panel shows returned-column cardinality, nulls, ranges
and distributions; query provenance is available in Query info on the result-state
control. Closing or reopening the panel preserves the query and result identity.
The [console notes](design/board-console/CONSOLE.md) and
[live scheduling notes](design/board-console/LIVE.md) record the proposed editor,
admission and source contracts. No continuous SQL syntax or runtime is introduced;
the qualified snapshot profile and deferred streaming scope below remain intact.

## DDL: mostly a spelling problem, with one real prerequisite

`CREATE TABLE` is not a new capability. Station already has a typed
resource-creation path — `Table.create`/the `table_create` action, and the
growing profile's `create_resource` plus schema declaration — authorized and
executed identically to every other durable mutation. A relational DDL surface
is a text encoding of that same typed command, checked by the same
authorization before it ever reaches durable state; it does not bypass
anything or add a second creation path. `CREATE DOCUMENT` and `CREATE KV`
follow the same shape once [M17](roadmap/M17.md#entry-gates)'s Document model
and [M18](roadmap/M18.md)'s KV decoder/source model are specified. Those
milestones do not themselves select SQL DDL; a later DDL frontend would expose
their supported operations without deciding new schema/merge semantics.

The real prerequisite this exposes: today's Table schema is fixed at exactly
two columns (`id: int64`, one typed value column) — a KV-shaped table, not a
general relational one. `CREATE TABLE orders (id INT, sym TEXT, qty INT, px
FLOAT, ...)` with an arbitrary multi-column schema needs the Table model
itself to grow first. That is real scope, not a parser detail, and belongs
with a separately scoped schema-evolution milestone informed by M18's
unified-query work. Naming DDL now should not be read as claiming
multi-column tables already exist.

## DML: SELECT is the qualified path, writes reuse what Table already has

`INSERT`/`UPDATE`/`DELETE` map onto Table's existing typed mutation API
(`insert`/`update`/`upsert`/`delete`) one-to-one — again a spelling of an
existing, authorized operation, not a new one. `SELECT` is the interesting
case: it compiles to Fuze's typed `Plan` (predicate, projection, limit,
aggregate) and executes through the same bounded, credited pipeline
[M10](roadmap/M10.md) qualified this cycle and [M13](roadmap/M13.md) is
scoped to expose — `WHERE`/column selection/`LIMIT`/`COUNT`/`SUM` map
onto the existing plan. The admitted aggregate-input subquery spells
filter → limit → aggregate without confusing an outer SQL limit with an input
limit. Omitted limits remain unlimited under `Stream.Plan`; explicit limits
are 0–32 in this SQL profile. Joins, grouping, general subqueries and window
functions require separate qualification. Unsupported constructs fail explicitly.

[M19](roadmap/M19.md) already commits to exactly this SELECT-only slice,
narrower and further out: *"a bounded read-only SQL subset... translating
into Fuze's M9 plans; no separate engine."* A full DDL/DML relational
surface — this document's scope — is bigger than that existing commitment in
two ways: it writes, and M19 ties its SQL specifically to the Flight SQL
ingress path. M12 now supplies the local read compiler; M19 supplies remote Flight SQL
ingress over it. Neither delivers the full relational surface; a general DDL/DML surface
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
([M15](roadmap/M15.md)) exist to dispatch through at all; do not treat this
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

CONNECTION/SOURCE/SINK are additive Transit syntax. Their reference grammar
productions are checked, but capability declarations, authorization and execution
remain future connector work. Their presence does not imply that the current
SELECT subset is a PostgreSQL superset or that every PostgreSQL execution
semantic is supported.

## Defining and verifying the grammar

### Postgres compatibility is a testable claim, not a formal one

A full PostgreSQL grammar superset would accept every PostgreSQL query with
an equivalent parsed meaning, plus Transit's extensions. M12 does **not** make
that claim. It establishes acceptance and normalized AST agreement for the
explicit Table subset in a pinned corpus, using
[`libpg_query`](https://github.com/pganalyze/libpg_query)'s PostgreSQL parser
through pglast 7.13. Fourteen unchanged PostgreSQL REL_17_5 regression statements
and Transit-authored boundary cases run through that parser, ANTLR and Zig.
Original source hashes, excerpt provenance and exclusions are recorded in
[the grammar contract](../contracts/sql/README.md).

Corpus agreement is evidence, not a universal grammar theorem or PostgreSQL
execution-equivalence claim. Fuze retains its deterministic primary-key order
and checked int64 sum, which differ from PostgreSQL's broader execution model.
A full regression suite, `sqllogictest` and SQL-aware fuzzing could extend future
coverage; they have not run as part of this qualification.

### Grammar definition: a spec-and-checked format, not the production parser

[`TransitExtensions.g4`](../contracts/sql/TransitExtensions.g4) now includes
`SELECT`, projection, typed predicates, aggregates and the restricted input
subquery, alongside the grammar-only administrative extensions and AS-OF
fragment. Pinned ANTLR 4.13.2 generates a Python reference parser with warnings
fatal and diagnostics required to be empty. The shared corpus also runs with
exact ambiguity detection. No generation conflict or corpus ambiguity is
reported; that does not prove global grammar unambiguity.

The production frontend is a hand-written, bounded recursive-descent Zig parser
with an iterative lexer, owned fixed-shape AST and no allocations or I/O. Its
AST is compared with the independent reference tree on every shared SELECT
case. Compilation resolves only caller-supplied source/schema metadata and
reuses engine type validation. Generated parser files are verification artifacts,
never runtime dependencies. `just test::sql` reruns generation, AST comparisons,
real plan encoding and independent paged Arrow checks on grammar changes.

`CREATE TABLE`/`DOCUMENT`/`KV`/`CONNECTION`/`SOURCE`/`SINK`, `GRANT`, `REVOKE`,
`SHOW` and `DESCRIBE` remain grammar-only, with `UnsupportedStatement` from the
production frontend. `INSERT`/`UPDATE`/`DELETE` are not in the grammar. Neither
accepted grammar nor a compiled plan bypasses the later source authorization
and exact-revision binding requirements.

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

**Lean checks selected rewrite semantics.** M12's
[`FuzeRewrite.lean`](../contracts/sql/FuzeRewrite.lean) proves total filter
reordering, projection pruning, predicate pushdown through a total projection
with explicit first-error preservation, and preservation by an unchanged
fallible downstream consumer. The [proof inventory](../contracts/sql/README.md#lean-scope)
records exact premises and axioms; pinned Lean 4.29.1 reports no `sorryAx`.

These are specification theorems. The correspondence note maps validated
predicates, ordered projection and unchanged limit/sum consumption to current
Zig operators, while leaving implementation refinement, allocation, cancellation
and current authority outside the model. No optimizer rewrite is enabled.
Limit pushdown and checked-sum reassociation are generally false; partial or
effectful projection needs stronger premises. Those claims are explicitly
excluded, not represented by incomplete proofs. A PostgreSQL grammar-superset
proof remains a different and much larger undertaking than this corpus check.

## What we're missing, against RisingWave/ksqlDB/Flink SQL/Materialize

Modeling entities on these systems (as inspiration, not a compatibility
target) surfaces gaps worth naming honestly rather than discovering later.
Some are already named elsewhere in this repo; some are not named anywhere
yet; and on a few axes Transit's existing design is already ahead of what's
typical in that class of system. Keeping all three lists explicit is the
point — a gap analysis that only lists gaps overclaims the comparison.

**Real, currently unnamed gaps** — nothing in the roadmap today has a
position on these, unlike the excluded items below:

- **Ingestion format decoding at the SOURCE boundary.** A `CREATE SOURCE`
  needs a story for turning connector bytes into typed rows (JSON/Avro/
  Protobuf/CSV, schema-on-read vs. a bound schema). `CONNECTORS.md` specifies
  HTTP text capture; it does not yet specify decoding captured bytes into
  Fuze rows.
- **`SHOW`/`DESCRIBE` as the relational-surface answer to `transit-cli`'s
  planned `/`-prefixed meta-commands** (`docs/roadmap/M13.md`). Both need to
  read the same catalog; today only the CLI side is named.
- **Multi-column schema evolution.** Already flagged in this document's DDL
  section as a Table-model prerequisite; every system named above has an
  `ALTER`/schema-registry story this repo hasn't needed yet because Table
  has had no columns to alter.

**Already named and deliberately excluded**, not missing from the analysis,
just missing from scope right now: continuous/materialized/subscribed
queries (M13, M17 and M18 exclude them explicitly), cross-source joins
(`FUZE.md`), multi-resource/cross-table transactions (M10), UDFs and
dynamic plugins (`FUZE.md`'s extensibility section).

**Places Transit's existing design is already ahead of the typical bar in
this class of system**, worth leaning into rather than importing an external
pattern for:

- **Sink delivery semantics.** Most streaming-SQL sinks default to
  at-least-once with exactly-once as a per-connector special case. Transit's
  connector model ([`CONNECTORS.md`](CONNECTORS.md#effect-boundary)) already
  forces attempt identity, idempotency and explicit reconciliation for
  *every* effect — a `CREATE SINK` inherits that for free; it would be a
  regression to design something weaker.
- **`AS OF` / forensic reconstruction.** Retained read versions
  ([`READ_VERSIONS_V1.md`](../contracts/READ_VERSIONS_V1.md), `GROWTH-10`)
  already durably support historical reads more rigorously than these
  systems typically offer out of the box — see the dedicated section below.
- **Flow control.** [`FLOW_CONTROL.md`](FLOW_CONTROL.md)'s receiver-driven,
  formally modeled credit pattern is a more explicit backpressure contract
  than most of these systems document for their own internal operator chains.
- **Retention.** [`RETENTION.md`](RETENTION.md)'s explicit lifetime/compaction
  contract is more precisely specified than typical topic/table retention
  policies.

## Forensic first: OLTP-snapshot semantics, windowing deferred

Decided: the query model targets exact point-in-time reconstruction over an
OLTP-shaped snapshot history, not wall-clock event-time windowing. Windowing
stays a later, explicitly deferred addition — not excluded, not designed,
revisited once forensic reconstruction itself is solid — rather than a
parallel initial priority. This is a scoping decision worth stating plainly:
it resolves the open question the windowing gap above used to leave open,
and it changes what "the query language" is for at this stage — proving
exactly what happened, not approximating what a stream looked like over an
interval.

This is not a compromise relative to the systems compared above — it is
leaning into what Transit's kernel already *is*: an append-only durable
history with explicit monotonic revisions that already answers "what
changed, in what order, provably," backed by `QueryRecords.Segment`'s
domain-separated digest chain, `Authority.tla`'s publication safety, and
[`STATE.md`](STATE.md#turn-and-commit-boundary)'s one durable commit decision
per turn. That is a stronger starting point for forensic reconstruction than
typical OLTP audit logs, which usually bolt change-data-capture on after the
fact rather than having it as the kernel's native representation. Windowed
aggregation is a different, later problem — summarizing approximately over
time — that should not be allowed to shape the initial grammar or planner
around wall-clock intervals this kernel does not natively organize itself by.

Concretely, this is why `TransitExtensions.g4`'s time-travel fragment is
named `FOR SYSTEM_TIME AS OF <revision>` — SQL:2011's actual
system-versioned-table clause, real standard syntax rather than an invented
`AS OF`, deliberately taking a Transit **revision** (an integer journal
position) as its argument rather than the standard's wall-clock `TIMESTAMP`
literal, because Transit's time is protocol-position-based, not wall-clock —
consistent with this section's decision, not a shortcut around it.

Two more forensic primitives worth naming now, both already real concepts in
Board's inspection model rather than new capability to design:
[Journey](GLOSSARY.md#inspection-and-interpretation) ("a bounded view of
recorded causal relationships between inputs, turns, outputs, admissions and
effects") is the provenance question — *what produced this value, through
what chain* — and a natural target for a relational read the same way
`connector.*`/`transport.*` are proposed above (`journey.*`, read-only,
through Board's existing inspection contract, not Fuze's mutation-capable
plan). [Observation basis](GLOSSARY.md#inspection-and-interpretation) (source,
read position, policy revision, retained boundary and coverage) is what
every forensic answer needs to carry explicitly so "what happened" and "how
confident/complete is this view of what happened" are never conflated —
exactly the discipline `FOR SYSTEM_TIME AS OF` and a `journey` read both need
to inherit, not something either gets to skip for convenience.

## A second use for this: a checked interface for human/agent development

Everything above was scoped as an end-user query surface. It is also,
incidentally, a better interface for developing and verifying Transit
itself — worth stating explicitly since it changes how "done" some of this
work should be judged.

A machine-checked grammar rejects a malformed statement at parse time with a
precise error, not three layers deep in a runtime failure. That is exactly
the class of mistake that costs real time in this repo's own session
history — a wrong field (an input ordinal where a journal position was
required), a misordered setup call, an off-by-one discovered only after a
build/test cycle. A typed DDL surface for constructing test fixtures and
scenarios — "spawn a process, create this table, grant this principal" as
checked statements — catches that class of error before either a human or
an agent burns a build cycle on it, the same value a type system provides
over untyped data, just one layer higher.

The same idea applies to `tests/verification/invariants.json`'s scenario
catalog and `transitions.py`'s generated schedules: both are currently
hand-written prose/Python. A grammar-checked scenario language — expressing
"competing prepared successors," "revoke or replace owner between prepare
and commit" as structured, parseable statements rather than free text a
human transcribes into Python — would let an agent propose new adversarial
scenarios that are mechanically well-formed before a human reviews their
substance, narrowing review to "is this the right scenario" instead of also
"did they write valid Python."

`EXPLAIN` (already planned in `FUZE.md`) is the same idea from the other
direction: a versioned, structured plan explanation is something an agent
can parse and reason about precisely, where a prose log forces re-deriving
structure from text every time. And the `libpg_query` differential corpus
implemented above is reusable exactly this way too — an acceptance check either
a human or an agent can run against a grammar change without re-deriving
"is this still Postgres-compatible" from first principles each time.

None of this is a reason to build the full grammar faster than the query
capability it serves needs it. It is a reason to keep it machine-checked
rather than prose-only as it grows, since the checking is most of the value
described here.

## What this document is not

The linked M12 contract fixes the implemented Table read grammar and parser;
this document also records broader design direction. It does not move SQL writes
or DDL execution into M13's public query scope or qualify Document queries before
M18. The connector/transport namespace remains unassigned. Later builder and
catalog proposals should preserve the same boundary: surfaces compile to Fuze's
plan, and system inspection is a different source kind from versioned data.
