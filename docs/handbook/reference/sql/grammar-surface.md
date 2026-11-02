# Grammar surface: implemented and planned

This inventory distinguishes the SQL surface implemented at this source revision
from planned language features. Use it alongside the [statement reference](../sql.md)
to find syntax, its execution owner and the contract still needed for a planned
operation. **Planned forms do not run in any Transit SQL interface.**

## How to read support

| Label | Meaning |
| --- | --- |
| **Implemented — execution** | The named caller executes the documented bounded profile; other transports can still reject it |
| **Implemented — compilation** | A production compiler validates a definition for review; publication is a separate capability |
| **Planned — checked grammar** | The reference parser recognizes syntax; the operation has no executable implementation |
| **Planned — proposed syntax** | An illustrative spelling exists, but neither the checked grammar nor production compiler accepts it |
| **Planned — syntax undecided** | The semantic target is selected; exact syntax depends on its typed contract |
| **Outside selected profile** | No implementation commitment is made by this inventory |

These are Transit support labels, not standards-conformance ratings. Parsing,
typed lowering, execution, recovery and transport exposure are separate facts.
For example, compiling `CREATE KV` is implemented while publishing that
declaration is planned. A native operation, a UI action or a parser rule does not
establish an equivalent SQL operation.

The checked owners are [TransitExtensions.g4](../../../../contracts/sql/TransitExtensions.g4)
and the separate [Application.g4](../../../../contracts/application/Application.g4).
Their [corpus and limits](../../../../contracts/sql/README.md) establish selected
syntax/AST agreement, not general PostgreSQL or SQL-standard compatibility.

## Implemented reads and inspection

Every row is **Implemented — execution** within its stated profile.

| Form | Executable profile | Public owner |
| --- | --- | --- |
| `SELECT *`, ordered column list | One declared KV, Table or accepted Document projection; logical Table output supports up to 128 positions with distinct result names | [SELECT](select.md) |
| `WHERE column comparison literal` | Exactly typed comparisons combined by bounded NOT/AND/OR: `=`, `<>`, `!=`, `<`, `<=`, `>`, `>=` | [Expressions](expressions.md) |
| `IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT` | Exact cell-state predicates; general Table predicates also accept IS NOT; missing and null remain distinct | [Types and cell states](types.md) |
| `LIMIT n` | Full uint64 row count; omission does not truncate or remove execution budgets | [SELECT](select.md) |
| `COUNT(*)`, `COUNT(column)`, `SUM(column)` | One aggregate; uint64 count or ordered checked int64 sum | [Aggregates](expressions.md#aggregate-functions) |
| Aggregate over one derived table | Only the restricted filter → limit → aggregate form, with its required alias | [Limited aggregate input](select.md#aggregate-a-limited-input) |
| `FROM source AS alias` | Query-local column qualifier; explicit `AS`, unchanged source and output column identities | [Project rows](select.md#project-rows) |
| Output `AS name` | Names row or aggregate output positions; distinct names allow repeated inputs; renamed inner columns resolve in the outer aggregate | [Project rows](select.md#project-rows) |
| `SHOW ALL`, dotted-key SHOW, settings relations, SET/RESET and standalone reload | Shared settings compiler; configured console/database-wire adapters with current scoped authority | [Settings SQL](settings.md) |
| `SHOW DATABASES`, `SHOW SCHEMAS` | Authorized configured bindings and selected database schemas | [SHOW](show.md) |
| `SHOW STORAGE FOR name` | Direct Table storage progress through the shared SQL session and current metadata-inspection authority | [SHOW](show.md#table-storage-progress) |
| `DESCRIBE name`, `SHOW TABLES` | Authorized configured-catalog Tables in the console, or the explicit source in query-source scope | [DESCRIBE](describe.md), [SHOW](show.md) |
| `JOIN`, `GROUP BY`, mixed COUNT/SUM | Explicit relational Table profile: one inner/left int64 or UTF-8 equijoin, int64/UTF-8 grouping and ordered checked aggregates; separate opt-in console connection | [Table joins and grouping](relational.md) |
| `EXPLAIN SELECT ...` | Validated finite plan and output columns; no query admission or row execution; snapshot behavior depends on the inspection profile | [EXPLAIN](explain.md) |

The [syntax reference](syntax.md) owns names, comments, literals and parser
bounds. General Table predicates bind literals against logical column descriptors
and require the selected comparison trait. JSON has no equality/order trait;
intervals and maps have equality without ordering. The local finite scalar
compiler has its separately documented six-scalar literal profile. Neither
profile implies general SQL casts.

Query callers, the CLI/console and Board share Fuze's finite compiler and source
contract. [Flight SQL](../flight.md) exposes its narrower configured Table
profile. Inspection has its own [caller contract](../../../../contracts/SQL_INSPECTION_V1.md);
acceptance through that entry point does not make an inspection statement a
SELECT. Interactive leased sessions and durable captured queries retain their
different [recovery behavior](../queries.md).

## Implemented mutations and definitions

| Form | Support | Caller and boundary |
| --- | --- | --- |
| `INSERT INTO ... VALUES ...` | **Implemented — execution** | Bounded multi-row typed values, reordered/omitted fields, DEFAULT and NULL through the configured catalog; up to 1,024 rows and a 4 MiB typed intent, with a separate 4 KiB SQL text bound |
| `UPDATE ... SET ... [WHERE ...]` | **Implemented — execution** | Multiple constant/default assignments and typed Boolean/state predicates; frozen selection and one atomic publication |
| `DELETE FROM ... [WHERE ...]` | **Implemented — execution** | Point or selected finite predicates; committed matched/changed counts |
| `PRODUCE INTO`, `ENQUEUE INTO` | **Implemented — single-partition execution** | [Typed VALUES, metadata and original-operation RETURNING](streaming.md#append-events-and-work) through native SQL, console, PostgreSQL and MySQL; cross-partition and attached-transaction appends are excluded |
| `CONSUME ... FROM` | **Compiler only** | Typed projection, predicate, logical LIMIT and group/wait preparation; no SQL-service admission, group assignment, waiting or offset settlement |
| `CREATE TABLE` | **Implemented — execution** | 1–128 columns, all logical families, explicit single/composite/no primary key, nullable defaults and deterministic typed defaults; authorized catalog routing |
| `ALTER TABLE` | **Implemented — execution** | Add/drop/rename columns, rename Table, defaults, nullability and constraints; lazy projection and bounded validation; populated physical rewrites reject pending the phased runtime |
| Table-level `CHECK` | **Implemented — execution** | Bounded deterministic comparisons and NULL tests, new-write enforcement with optional NOT VALID, explicit bounded validation |
| `FOREIGN KEY ... NOT ENFORCED` | **Implemented — staged declarations** | Exact parent definitions and primary-key columns with recoverable dependency protection; row enforcement and referential actions remain unavailable |
| `DROP TABLE` | **Implemented — execution** | IF EXISTS and RESTRICT, explicit dependency checks, live-name retirement and safe name reuse; retained evidence remains separate from cleanup |
| `CREATE KV`, `CREATE DOCUMENT` compilation | **Implemented — compilation** | Separate offline definitions and canonical review SQL |
| `CREATE KV`, `CREATE DOCUMENT` publication | **Planned — checked grammar** | No catalog creation operation, provisioning or default decoder/replica follows from offline compilation |
| `CREATE INTERFACE`, `CREATE THEME`, `CREATE SCREEN`, `CREATE BINDING`, `CREATE ACTION` | **Implemented — compilation**, with separate implemented publication | One complete application definition; explicit reviewed conditional publication, outside the query grammar |

Use [INSERT](insert.md), [UPDATE](update.md), [DELETE](delete.md),
[state declarations](../../../../contracts/STATE_DECLARATION_V1.md),
[CREATE TABLE](create-table.md), [ALTER TABLE](alter-table.md),
[DROP TABLE](drop-table.md) and [application declarations](application.md)
for exact schemas and bounds. Query transports reject writes and administration.
Table CREATE reserves an object and performs recoverable native authorization
registration before direct Table publication. Current ownership and applicable
default grants determine access; compilation alone grants nothing. Mutation
callers retain admission, processing and application outcomes separately,
including accepted work with a lost reply.

The [SDK matrix](../sdks.md#catalog-callers) and
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) identify the
available language callers. All ten SDKs expose general typed catalog lifecycle,
DML, controls, exact saved recovery and owned lookup/definition/page values through
the shared native implementation. The console routes supported Table statements
through its configured catalog;
other administrative SQL families retain their own stated support boundaries.

## Planned declarations and relational composition

| Form or family | Support | Semantic target and boundary |
| --- | --- | --- |
| `CREATE CONNECTION`, `CREATE SOURCE`, `CREATE SINK` | **Planned — checked grammar** | Typed options, secret references, dependencies and separately authorized activation; declarations confer no access |
| `CREATE SCHEMA`, `ALTER SCHEMA ... RENAME`, `DROP SCHEMA RESTRICT` | **Implemented — native SQL execution** | Exact direct-catalog bindings, current ownership, durable outcomes and bounded dependency checks; PostgreSQL/MySQL and query-only interfaces exclude these forms |
| Role administration, ownership transfer, `GRANT`, `REVOKE` | **Dedicated authorization compiler and explicit apply** | [Selected forms](authorization.md) lower to native policy operations; console and query-only interfaces reject administrative execution |
| `SHOW SOURCES`, `SHOW SINKS`, `SHOW CONNECTIONS` | **Planned — checked grammar** | Authorized paged catalog inspection; a configured-source listing is not a global catalog |
| Further expressions and reusable queries | **Planned — syntax undecided** | Selected SQL expressions with explicit type, five-state conversion and error-order rules; no general evaluator exists today |
| `ORDER BY`, further expressions, aggregates and query composition | **Planned — syntax undecided** | Broader selected relational operations with explicit error/order semantics and bounded state; individual variants still need contracts |
| `CREATE VIEW`, `CREATE MATERIALIZED VIEW`, `SUBSCRIBE` | **Planned — syntax undecided** | Named definitions, complete changes, resumable backfill, snapshot/change handoff and current disclosure |
| Event-time windows and watermarks | **Planned — syntax undecided** | Time domains, lateness, corrections and finality; resource revisions are not event time |
| Query-to-sink bindings and triggers | **Planned — syntax undecided** | Explicit activation, stable recorded intent, atomic input progress plus intent, authorized attempt and captured outcome |
| Broader object ALTER/DROP, `TRUNCATE` | **Planned — syntax undecided** | Lifecycle for other object families and TRUNCATE; selected Table ALTER/DROP is implemented above |
| `COPY`, SQL `MERGE INTO`, upsert | **Planned — syntax undecided** | Bounded typed transfer or one-resource mutation/conflict semantics; no implicit file/network authority |
| `BEGIN`, `COMMIT`, `ROLLBACK`, savepoints | **Implemented — local Tables** | [Serializable common cuts, private statements and original decisions](transactions.md); no implicit cross-owner atomicity or rollback of a committed decision |
| `PREPARE`, `EXECUTE`, parameters | **Explicit parameter bindings; named statements planned** | [Typed `$n` binding](parameters.md) owns plans, checks complete source definitions and current policy; CLI and all SDKs accept explicit bindings; named statements have no execution route |
| Richer `EXPLAIN` and query description | **Planned — syntax undecided** | Shared logical/physical operators, effects and budgets without executing them; current `EXPLAIN SELECT` remains implemented |

The checked connector, privilege and listing forms have individual pages in the
[statement index](../sql.md#statement-forms). All other rows are absent from the
checked grammar. [Streaming and effects](streaming.md) explains the current
application materialization, watch/refresh and connector alternatives. A finite
result delivered in batches is not a continuous query; a retracted row cannot
undo an external effect.

The implemented Table join/group profile excludes `HAVING`, `DISTINCT`,
arbitrary sorting, general subqueries, non-equality/full/right joins and more than
one join. It also excludes `LIMIT` on the new composed profile; implemented
single-source limits keep their existing meaning. Broader composition does not
implicitly select every SQL operator or relax these initial bounds.

## Planned standards and data-model surface

The selected targets are features of **SQL:2023**, not the whole language.
Standard editions, application schema history and Transit's
[single current v1 contract definition](../versioning.md) are different axes.

| Language family | Support | Intended profile |
| --- | --- | --- |
| SQL:2023 Foundation and SQL/JSON | **Planned — syntax undecided** beyond the implemented subset above | Audit selected relational/type features and explicit structured-value projections, including missing/null/error/conflict conversion |
| SQL/PGQ: `CREATE PROPERTY GRAPH`, `GRAPH_TABLE` | **Planned — proposed syntax** | Catalog graph mappings over existing resources; finite, read-only, fixed-length patterns with stable element identity and bag multiplicity |
| SQL/MED: `CREATE FOREIGN TABLE` | **Planned — proposed syntax** | Typed foreign relation over a recoverable immutable capture (`parquet`, `arrow_ipc`, `csv`, `jsonl`, or mainframe `fixed_record`/`variable_record` copybook layouts); filesystem and S3 bindings require explicit qualification |
| Column `COLLATE` | **Implemented — Table declarations and finite predicates** | CREATE TABLE and ADD COLUMN accept `UTF8_BINARY`, `ASCII_CI`, `EBCDIC_CP037`, `EBCDIC_037_PAD`, `EBCDIC_1047_NOPAD` on text columns; [Table semantics](../tables.md) bind prepared and retained queries to the declaration |
| Expression collation and physical codec clauses (`ENCODING`) | **Planned — proposed syntax** | Expression overrides, versioned Unicode collations and physical codec clauses require explicit contracts |
| GQL frontend | **Outside selected profile** | Future frontend target over shared semantics; no accepted GQL grammar |
| Cypher and PGQL | **Outside selected profile** | Named comparison/import dialects; independent compatibility evidence and explicit selection are required before support |

Primary language references are
[SQL:2023 Foundation](https://www.iso.org/standard/76584.html),
[SQL/PGQ](https://www.iso.org/standard/79473.html),
[SQL/MED](https://www.iso.org/standard/84804.html) and
[GQL](https://www.iso.org/standard/76120.html). A catalog listing or vendor example
does not establish feature conformance. Exact feature identifiers, dependency
closure, corrections and deviations require an audit of the relevant normative
text and fixtures with appropriate redistribution rights. That audit and typed
capability reporting are planned, not supplied by this handbook table.

KV, Table and Document remain the native resource kinds. A property graph is a
catalog mapping plus graph-aware operators, not a new resource kind. Storage
binding, finite/maintained execution and compiler-checked effects are separate
dimensions of a query definition. The planned shared model tracks source reads,
state writes, external capture and dispatch, together with determinism,
fallibility, change mode and work budgets. A user annotation cannot grant
authority or turn an external operation into a pure expression.

### Proposed graph and foreign-relation syntax

**Planned — proposed syntax.** The following text is illustrative, is not checked
grammar and cannot be submitted. It assumes richer Table schemas than the
implemented creation profile. Exact standard feature spellings remain subject to
the normative audit.

```text
CREATE PROPERTY GRAPH social
  VERTEX TABLES (
    people KEY (person_id) LABEL person PROPERTIES (name)
  )
  EDGE TABLES (
    follows KEY (edge_id)
      SOURCE KEY (follower_id) REFERENCES people (person_id)
      DESTINATION KEY (followed_id) REFERENCES people (person_id)
      LABEL follows NO PROPERTIES
  );

SELECT person_name, followed_name
FROM GRAPH_TABLE (
  social MATCH (a IS person)-[e IS follows]->(b IS person)
  COLUMNS (a.name AS person_name, b.name AS followed_name)
);

CREATE FOREIGN TABLE event_archive (
  event_id BIGINT, actor_id BIGINT, payload VARCHAR(4096)
)
SERVER archive_reader
OPTIONS (
  transit_binding 'filesystem',
  transit_root 'approved_archive',
  transit_path 'events/',
  transit_format 'parquet',
  transit_read_basis 'captured_manifest'
);

CREATE FOREIGN TABLE core_banking_ledger (
  acct_id     VARCHAR(10)   COLLATE EBCDIC_037_PAD OPTIONS (encoding 'EBCDIC_CP037', byte_len '10'),
  branch_code INT32                                OPTIONS (encoding 'COMP',         byte_len '4'),
  balance     DECIMAL(13,2)                        OPTIONS (encoding 'COMP3',        byte_len '7'),
  tx_rate     DECIMAL(7,4)                         OPTIONS (encoding 'ZONED_EBCDIC', byte_len '7')
)
SERVER mainframe_s3
OPTIONS (
  transit_format 'fixed_record',
  transit_record_bytes '28',
  transit_read_basis 'captured_manifest'
);
```

Graph keys/endpoints, self-loops and parallel edges require explicit identity and
multiplicity validation. Graph mutation, variable-length paths and arbitrary
recursion are outside this selected profile. Graph syntax follows the shape of
the examples analyzed in the [query-engine account](../../internals/query-engine.md#standards-and-multiple-data-models);
it does not claim full SQL/PGQ support.

`CREATE FOREIGN TABLE` is the intended canonical foreign-relation spelling;
there is no separate `EXTERNAL` object model. `archive_reader` and `mainframe_s3`
denote planned typed bindings with credential references, permitted roots and
budgets. Their foreign-server/connection relationship must have one credential
authority. `transit_*` options and column-level `encoding`/`COLLATE` descriptors
are proposed Transit extensions over the shared `SegmentReader` boundary
([logical types, physical codecs and collations](../../internals/query-engine.md#logical-types-and-physical-codecs-and-collation-semantics)).

A directory or S3 prefix listing is not a snapshot. A complete paged manifest
must identify input bytes and their schema/decoder, retain them or establish an
explicit retrieval policy, and recover interrupted capture. Missing or changed
input fails explicitly. Foreign DML, continuous ingestion and external writes
are not implied: writes require separately activated recorded effects.

## Planned historical schemas and branches

| Operation | Support | Required meaning |
| --- | --- | --- |
| `FOR SYSTEM_TIME AS OF ...` | **Reserved — rejected** | Temporal-table semantics; the ambiguous integer fragment is removed |
| `AS OF SNAPSHOT ...` | **Implemented — selected direct Tables** | Exact published catalog selector, resolved before object/column names; [syntax and limits](as-of.md) |
| `AS OF BRANCH ...` | **Planned — proposed syntax** | Resolve a branch head once to a qualified immutable basis |
| Tag selector and exact resource-revision selector | **Planned — syntax undecided** | Keep tags, snapshot IDs, branch generations and resource-scoped journal revisions distinct |
| Historical `DESCRIBE` and `SHOW TABLES` | **Implemented — selected direct Tables** | Inspect the selected historical definitions under current metadata rights; row rights remain separate |
| `CREATE SNAPSHOT`, `CREATE BRANCH`, `USE BRANCH` | **Planned — proposed syntax** | Frozen catalog/data basis, isolated full-data or schema-only branches and explicit session defaults |
| Projection into a different schema | **Planned — syntax undecided** | Stable identities or reviewed mappings, typed conversion/default/conflict policies; no silent rebinding |
| Branch diff, three-way merge and schema-only promotion | **Planned — syntax undecided** | Frozen base/source/target, reviewable conflicts and constraints, conditional target-head publication; separate from SQL `MERGE INTO` |
| Restore and dataflow activation | **Planned — syntax undecided** | New application-state successor; preserve current authority and recorded effects, with explicit pending-work disposition |

**Planned — proposed syntax.** This branch workflow does not parse or execute.
The isolated ALTER TABLE rename form is implemented for a current catalog Table.

```text
CREATE SNAPSHOT before_change FROM BRANCH main;
CREATE BRANCH schema_trial FROM SNAPSHOT 's42';
USE BRANCH schema_trial;
ALTER TABLE people RENAME COLUMN name TO display_name;

SELECT name FROM people AS OF SNAPSHOT 's42';
DESCRIBE people AS OF SNAPSHOT 's42';
SHOW TABLES AS OF SNAPSHOT 's42';
SELECT display_name FROM people AS OF BRANCH 'schema_trial';

CREATE BRANCH schema_test FROM SNAPSHOT 's42'
  WITH (transit_data = 'schema_only');
```

`s42` stands for an immutable snapshot identity returned by the proposed snapshot
operation, not a journal position. The historical catalog binds rows together
with schemas, views, graph mappings and KV/Document decoders. A renamed column
retains identity; dropping and recreating its name does not. The old snapshot
resolves `name`, while the renamed head resolves `display_name`. Converting old
data to a different schema requires an explicit projection. A moved branch or
session default cannot change already accepted work.

The [historical selector reference](as-of.md) describes the implemented selected
Table profile. Its canonical selector replaces the ambiguous integer fragment;
`s42` above remains only a placeholder in this proposed branch workflow. No
fallback interprets temporal expressions as snapshot IDs or resource revisions. Timestamp convenience remains undecided until branch scope,
publication clock, ties and unavailable-history behavior have a contract.

The branch model requires isolated catalog/data ownership and conditional head
publication. Full-data export needs explicit source authority; borrowed history
continues to require current source permission. An authorized independent copy
has separate destination ownership after publication. Schema-only branches
record data exclusion so absent rows cannot become merge deletions; promotion
validates migration of the target's current rows.

Copy-on-write must preserve the same logical isolation as a full copy, including
parent/child deletion, retained-page reachability and bounded cleanup. Histories,
manifests and conflicts must grow beyond resident caches. A restored snapshot
cannot revive retired identities, restore grants, import live execution owners
or redispatch old effects. Restore creates a successor and explicitly addresses
pending inputs, jobs, subscriptions and uncertain remote outcomes.

The [historical query model](../../internals/query-engine.md#historical-schemas-and-query-binding)
and [branch/state model](../../internals/state-model.md#schema-history-and-branches)
explain the intended mechanisms, alternatives and limits. Current retained-read
handles and selected historical catalogs do not implement the whole-catalog
branch, merge or restore workflows above.

## Evidence required to change a label

A planned execution label changes only with its typed contract, shared lowering,
actual execution owner and applicable caller/recovery evidence. Add positive and
negative grammar fixtures; independent result/error oracles; current-authorization,
lost-reply and disk-recovery cases; and larger-than-cache checks where state grows.
Record each enabled transport explicitly. A parser test changes parsing status
only; a documentation build establishes no graph, branch or standards conformance.

Maintain this inventory and each affected statement page together. The
[verification reference](../verification.md) defines evidence boundaries and
links executed results. Generated feature-level capability views are planned;
this page is a reviewed source-revision inventory, not runtime negotiation.

<!-- standards-ledger:start -->
## Capability ledger

This generated summary describes the selected production entry points,
not the availability of internal helpers. Stage states are independent;
an implemented compiler is not execution, recovery or transport evidence.
Feature IDs and edition/clause references are inventory labels. References
marked unverified have not been audited for standards conformance.

The [neutral ledger](../../../../contracts/sql/standards-ledger.json)
records owners, evidence sources, dependencies and compiler cases.
Its compiler corpus is Transit-authored under MIT; it contains no copied
standards text. Runtime and installed caller checks remain separate.

| Feature | Parse | Lower | Execute | Recover | Transport | Reference | Scope and limits |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E021-E051 | implemented | implemented | implemented | implemented | implemented | unverified | Selected scalar types and collations. DECIMAL arithmetic uses bounded explicit DECIMAL_* functions with declared result precision, scale and rounding; ordered SUM widens to DECIMAL(38,s). Frozen column semantics carry exact TZif artifacts for AT TIME ZONE, TIME_BUCKET and LOCAL_TO_UTC. General infix arithmetic and host timezone lookup are not admitted. Installed native SQL exercises stored values, scalar expressions, decimal SUM and gateway restart. PostgreSQL/MySQL expose admitted boolean/float results and explicitly refuse unsupported decimal result types. |
| F031-F034 | implemented | implemented | implemented | implemented | implemented | unverified | Selected CREATE/ALTER/DROP operations, lazy projection and bounded validation scans. Populated physical rewrites reject pending the phased rewrite runtime. |
| F491 | implemented | implemented | implemented | implemented | implemented | unverified | Table-level bounded AND comparisons and IS NULL predicates; stable IDs, NOT VALID new-write enforcement and bounded validation. OR, inline CHECK, subqueries and effects reject. |
| F492 | implemented | implemented | staged | staged | staged | unverified | Explicit NOT ENFORCED declarations bind exact parent definitions and primary-key columns. Bounded recoverable column protection precedes publication; enforcement and referential actions require the maintained-index runtime. |
| F111 | implemented | implemented | implemented | implemented | implemented | unverified | Admits SERIALIZABLE and READ ONLY common cuts; rejects weaker isolation levels. |
| T181-X003 | implemented | implemented | implemented | implemented | implemented | unverified | Selected direct Table catalogs have paged acquisition, exact WAL/segment retention, original-operation recovery and explicit release. The SQL service binds canonical AS OF SNAPSHOT suffixes before names; raw Fuze relational parsing still rejects the suffix. Explicit forward schema projection binds an accepted CURRENT or snapshot-selected target separately from source evidence. Temporal syntax and historical graph/foreign execution are separate unfinished profiles; independent sources are not a common transaction cut. |
| X001-RANGE | implemented | implemented | implemented | implemented | implemented | unverified | Schema-bound RANGE and MULTIRANGE values, Table row/page codecs, SQL declarations and string literals, neutral JSON and logical Arrow are implemented. RANGE_OVERLAPS, RANGE_CONTAINS, RANGE_ADJACENT and RANGE_COMPARE execute as bounded scalar projections; symbolic interval operators remain staged. |
| X002-VECTOR | implemented | implemented | implemented | implemented | implemented | unverified | VECTOR descriptors and unboxed 64-byte-aligned values, Table row/page codecs, SQL declarations and string literals, persisted metrics, neutral JSON and logical Arrow are implemented. VECTOR_DISTANCE executes typed scalar projections using an explicit or persisted compatible metric. Zero-norm cosine refuses. |
| G001-PGQ | rejected | rejected | rejected | rejected | rejected | unverified | CREATE PROPERTY GRAPH and traversal remain rejected SQL profiles. The separate Transit typed interpretation API persists versioned graph key/label/property bindings, protects exact Table dependencies and retains historical metadata; this does not qualify PGQ execution. |
| M001-MED | rejected | rejected | rejected | rejected | rejected | unverified | CREATE FOREIGN TABLE and general foreign scans remain rejected SQL profiles. The separate Transit typed interpretation API persists exact layouts, captured input content/availability and decoder policy. Historical inspection never refetches provenance URIs; durable corruption is not a malformed value cell. |
| X006-EXPLAIN | implemented | implemented | implemented | rejected | implemented | unverified | Native direct Table SELECT explanation reports typed traits under metadata-inspection rights; no data pins or scans. Results are session-local and must be prepared again after replacement. |
| X004-GERMAN-STRING | implemented | implemented | implemented | staged | staged | unverified | Existing finite string comparisons use lossless inline raw bytes through 12 bytes, cached collation prefixes for longer values, and explicit owned/borrowed Batch lifetimes. Dictionary predicates cache one outcome per physical code; binary/ASCII_CI FSST comparisons stream and validate all tokens. This adds no string wire ABI. Retained relational keys and end-to-end performance/recovery qualification remain separate work. |
| X005-SEARCH-WAND | rejected | rejected | rejected | rejected | rejected | unverified | Standalone search/index helpers. No production SEARCH SQL admission, durable index lifecycle or installed result transport. |
| F401-JOIN | rejected | rejected | rejected | rejected | rejected | unverified | Standalone generalized join/unnesting helpers. The separate production relational profile admits one inner/left equijoin; it does not admit this multi-way/lateral/unnesting family. |
| T611-WINDOW | rejected | rejected | rejected | rejected | rejected | unverified | Standalone window evaluator; no production OVER/QUALIFY compiler, durable cursor recovery or transport. |
| T121-RECURSIVE-CTE | rejected | rejected | rejected | rejected | rejected | unverified | Standalone recursive/set evaluators; no production WITH RECURSIVE compiler or durable recursive execution. |
| X007-PERFECT-HASH-IN | rejected | rejected | rejected | rejected | rejected | unverified | Internal perfect-hash IN evaluator; production SELECT does not lower IN/NOT IN into this helper. Keyword lookup is an independent implementation detail. |
| X008-VECTOR-UDF | rejected | rejected | rejected | rejected | rejected | unverified | Standalone macro/vector UDF helpers; no production CREATE FUNCTION, SQL call binding or installed Wasm execution. |
| T182-BITEMPORAL-AS-OF | rejected | rejected | rejected | rejected | rejected | unverified | Standalone temporal evaluator; no production temporal-table or AS OF JOIN admission. Snapshot selection is separate from temporal meaning. |
| X009-CHANGES-STREAM-SLICE | rejected | rejected | rejected | rejected | rejected | unverified | Standalone array-backed TVF helpers; no production catalog-bound CHANGES/STREAM_SLICE source. |
| F312-MERGE | rejected | rejected | rejected | rejected | rejected | unverified | Standalone merge evaluator; no production MERGE INTO admission or transactional publication. |
| X011-DBSP-ZSET | rejected | rejected | rejected | rejected | rejected | unverified | Standalone delta algebra; existing maintained relational queries recompute finite results. No SQL DBSP lifecycle or durable arrangement integration. |
| X010-DATAFLOW-LIFECYCLE | implemented | implemented | implemented | implemented | implemented | unverified | Cohosted native SQL supports finite one-Table recomputation into an existing schema-matched Table, durable lifecycle controls, publication wakeups, common Table/KV output/checkpoint decisions and SHOW DATAFLOW name REVISION number metadata. The shared Zig reader streams immutable completed rows under current grants; SQL historical row fetching is not exposed. Incremental or ordered change consumers, multi-source plans, dependent computation chains, PostgreSQL/MySQL and standalone gateways are rejected. |
| X012-CONTROL-POLICY-PLANE | rejected | rejected | rejected | rejected | rejected | unverified | Component policy descriptors/evaluators; no production SQL lifecycle for this combined enterprise feature family. Existing native grants remain a separate implemented owner. |
| X-CATALOG-DEFINITIONS | rejected | implemented | implemented | implemented | implemented | unverified | One control record publishes immutable definition, qualified name, original outcome and dependency replacement. Historical metadata retains exact artifacts separately from Table pins. Metadata-only catalogs have zero Table sources. |
| X-HISTORICAL-VIEWS | implemented | implemented | implemented | implemented | implemented | unverified | View definitions admit one Table, projection and filter. Outer finite expressions/parameters/aggregates run after that filter. Joins, captured views, transactions and explicit view schema projections refuse. No view text is reparsed. |

<!-- standards-ledger:end -->
