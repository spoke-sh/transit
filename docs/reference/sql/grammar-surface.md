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

The checked owners are [TransitExtensions.g4](../../../contracts/sql/TransitExtensions.g4)
and the separate [Application.g4](../../../contracts/application/Application.g4).
Their [corpus and limits](../../../contracts/sql/README.md) establish selected
syntax/AST agreement, not general PostgreSQL or SQL-standard compatibility.

## Implemented reads and inspection

Every row is **Implemented — execution** within its stated profile.

| Form | Executable profile | Public owner |
| --- | --- | --- |
| `SELECT *`, ordered column list | One declared KV, Table or accepted Document projection; one to eight output positions with distinct result names | [SELECT](select.md) |
| `WHERE column comparison literal` | One exactly typed comparison: `=`, `<>`, `!=`, `<`, `<=`, `>`, `>=` | [Expressions](expressions.md) |
| `IS NULL`, `IS MISSING`, `IS VALUE`, `IS TYPE_ERROR`, `IS CONFLICT` | One exact cell-state predicate; missing and null remain distinct | [Types and cell states](types.md) |
| `LIMIT n` | Full uint64 row count; omission does not truncate or remove execution budgets | [SELECT](select.md) |
| `COUNT(*)`, `SUM(column)` | One aggregate; uint64 count or ordered checked int64 sum | [Aggregates](expressions.md#aggregate-functions) |
| Aggregate over one derived table | Only the restricted filter → limit → aggregate form, with its required alias | [Limited aggregate input](select.md#aggregate-a-limited-input) |
| `FROM source AS alias` | Query-local column qualifier; explicit `AS`, unchanged source and output column identities | [Project rows](select.md#project-rows) |
| Output `AS name` | Names row or aggregate output positions; distinct names allow repeated inputs; renamed inner columns resolve in the outer aggregate | [Project rows](select.md#project-rows) |
| `DESCRIBE name`, `SHOW TABLES` | Current authorized metadata for the configured source; not a realm-wide catalog | [DESCRIBE](describe.md), [SHOW](show.md) |
| `EXPLAIN SELECT ...` | Validated finite plan and output columns; no query admission, snapshot acquisition or execution | [EXPLAIN](explain.md) |

The [syntax reference](syntax.md) owns names, comments, literals and parser
bounds. Int64, uint64, finite float64, boolean, UTF-8 and binary comparisons are
implemented; their literal forms do not imply general casts or DDL type support.

Query callers, the CLI/console and Board share Fuze's finite compiler and source
contract. [Flight SQL](../flight.md) exposes its narrower configured Table
profile. Inspection has its own [caller contract](../../../contracts/SQL_INSPECTION_V1.md);
acceptance through that entry point does not make an inspection statement a
SELECT. Interactive leased sessions and durable captured queries retain their
different [recovery behavior](../queries.md).

## Implemented mutations and definitions

| Form | Support | Caller and boundary |
| --- | --- | --- |
| `INSERT INTO ... VALUES ...` | **Implemented — execution** | One to three literal rows through an explicitly enabled Table writer, shared client, typed SDKs or configured console |
| `UPDATE ... SET ... WHERE key = literal` | **Implemented — execution** | One value-column assignment at one primary key through that writer |
| `DELETE FROM ... WHERE key = literal` | **Implemented — execution** | One primary key through that writer |
| `CREATE TABLE`, `CREATE KV`, `CREATE DOCUMENT` compilation | **Implemented — compilation** | Shared offline state compiler; owned definitions and canonical review SQL |
| Compatible empty `CREATE TABLE` publication | **Implemented — execution** | Explicit catalog host/caller/console; two columns: int64 non-null key and explicitly nullable int64/bool/UTF-8/binary value |
| `CREATE KV`, `CREATE DOCUMENT` publication | **Planned — checked grammar** | No catalog creation operation, provisioning or default decoder/replica follows from offline compilation |
| `CREATE INTERFACE`, `CREATE THEME`, `CREATE SCREEN`, `CREATE BINDING`, `CREATE ACTION` | **Implemented — compilation**, with separate implemented publication | One complete application definition; explicit reviewed conditional publication, outside the query grammar |

Use [INSERT](insert.md), [UPDATE](update.md), [DELETE](delete.md),
[state declarations](../../../contracts/STATE_DECLARATION_V1.md),
[CREATE TABLE](create-table.md) and [application declarations](application.md)
for exact schemas and bounds. Query transports reject writes and administration.
Table creation does not provision its native resource or implicitly grant query
or mutation policy. Mutation callers retain admission, processing and application
outcomes separately, including accepted work with a lost reply.

The [SDK matrix](../sdks.md#table-mutation-callers) and
[catalog contract](../../../contracts/DECLARATIVE_CATALOG_V1.md) identify the
available language callers. All ten SDKs expose typed catalog creation, controls,
exact saved recovery and owned lookup/definition/page values through the shared
native implementation. The console exposes compatible CREATE TABLE through an explicit catalog route;
other administrative SQL families retain their own stated support boundaries.

## Planned declarations and relational composition

| Form or family | Support | Semantic target and boundary |
| --- | --- | --- |
| `CREATE CONNECTION`, `CREATE SOURCE`, `CREATE SINK` | **Planned — checked grammar** | Typed options, secret references, dependencies and separately authorized activation; declarations confer no access |
| `GRANT`, `REVOKE` | **Planned — checked grammar** | Lower to current owning authorization operations; names and PID ownership do not grant rights |
| `SHOW SOURCES`, `SHOW SINKS`, `SHOW CONNECTIONS` | **Planned — checked grammar** | Authorized paged catalog inspection; a configured-source listing is not a global catalog |
| Expressions, boolean composition and reusable queries | **Planned — syntax undecided** | Selected SQL expressions with explicit type, five-state conversion and error-order rules; no general evaluator exists today |
| `JOIN`, `GROUP BY`, `COUNT(column)` | **Planned — syntax undecided** | One inner or left int64 equijoin over Tables, optional int64 grouping, count and ordered checked int64 sum; explicit source vectors and bag multiplicity |
| `ORDER BY`, further expressions, aggregates and query composition | **Planned — syntax undecided** | Broader selected relational operations with explicit error/order semantics and bounded state; individual variants still need contracts |
| `CREATE VIEW`, `CREATE MATERIALIZED VIEW`, `SUBSCRIBE` | **Planned — syntax undecided** | Named definitions, complete changes, resumable backfill, snapshot/change handoff and current disclosure |
| Timestamp/interval types, event-time windows and watermarks | **Planned — syntax undecided** | Time domains, lateness, corrections and finality; resource revisions are not event time |
| Query-to-sink bindings and triggers | **Planned — syntax undecided** | Explicit activation, stable recorded intent, atomic input progress plus intent, authorized attempt and captured outcome |
| `ALTER`, `DROP`, `TRUNCATE` | **Planned — syntax undecided** | Conditional definition/dependency lifecycle; logical retirement is separate from physical cleanup |
| `COPY`, SQL `MERGE INTO`, upsert | **Planned — syntax undecided** | Bounded typed transfer or one-resource mutation/conflict semantics; no implicit file/network authority |
| `BEGIN`, `COMMIT`, `ROLLBACK` | **Planned — syntax undecided** | A defined transaction scope above Station; no implicit cross-resource atomicity or rollback of uncertain commits |
| `PREPARE`, `EXECUTE`, parameters | **Planned — syntax undecided** | Owned typed bindings, exact source/schema identity and bounded plan lifetime |
| Richer `EXPLAIN` and query description | **Planned — syntax undecided** | Shared logical/physical operators, effects and budgets without executing them; current `EXPLAIN SELECT` remains implemented |

The checked connector, privilege and listing forms have individual pages in the
[statement index](../sql.md#statement-forms). All other rows are absent from the
checked grammar. [Streaming and effects](streaming.md) explains the current
application materialization, watch/refresh and connector alternatives. A finite
result delivered in batches is not a continuous query; a retracted row cannot
undo an external effect.

The first planned Table join/group profile excludes `HAVING`, `DISTINCT`,
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
| SQL/MED: `CREATE FOREIGN TABLE` | **Planned — proposed syntax** | Typed foreign relation over a recoverable immutable capture; filesystem first, S3 only after separate qualification |
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
```

Graph keys/endpoints, self-loops and parallel edges require explicit identity and
multiplicity validation. Graph mutation, variable-length paths and arbitrary
recursion are outside this selected profile. Graph syntax follows the shape of
the examples analyzed in the [query-engine account](../../internals/query-engine.md#standards-and-multiple-data-models);
it does not claim full SQL/PGQ support.

`CREATE FOREIGN TABLE` is the intended canonical foreign-relation spelling;
there is no separate `EXTERNAL` object model. `archive_reader` denotes a planned
typed binding with credential references, a permitted root and budgets. Its
foreign-server/connection relationship must have one credential authority.
`transit_*` options are proposed Transit extensions. Parquet illustrates a format
option; the first decoder is not selected here.

A directory or S3 prefix listing is not a snapshot. A complete paged manifest
must identify input bytes and their schema/decoder, retain them or establish an
explicit retrieval policy, and recover interrupted capture. Missing or changed
input fails explicitly. Foreign DML, continuous ingestion and external writes
are not implied: writes require separately activated recorded effects.

## Planned historical schemas and branches

| Operation | Support | Required meaning |
| --- | --- | --- |
| `FOR SYSTEM_TIME AS OF integer` | **Planned — checked grammar fragment only** | A separately parsed token sequence, not a historical-query contract; reserve system-time spelling for SQL temporal semantics |
| `AS OF SNAPSHOT ...`, `AS OF BRANCH ...` | **Planned — proposed syntax** | Typed catalog selectors, resolved once to immutable identities before name resolution |
| Tag selector and exact resource-revision selector | **Planned — syntax undecided** | Keep tags, snapshot IDs, branch generations and resource-scoped journal revisions distinct |
| Historical `DESCRIBE` and `SHOW TABLES` | **Planned — proposed syntax** | Inspect the selected historical definitions under current metadata rights; row rights remain separate |
| `CREATE SNAPSHOT`, `CREATE BRANCH`, `USE BRANCH` | **Planned — proposed syntax** | Frozen catalog/data basis, isolated full-data or schema-only branches and explicit session defaults |
| Projection into a different schema | **Planned — syntax undecided** | Stable identities or reviewed mappings, typed conversion/default/conflict policies; no silent rebinding |
| Branch diff, three-way merge and schema-only promotion | **Planned — syntax undecided** | Frozen base/source/target, reviewable conflicts and constraints, conditional target-head publication; separate from SQL `MERGE INTO` |
| Restore and dataflow activation | **Planned — syntax undecided** | New application-state successor; preserve current authority and recorded effects, with explicit pending-work disposition |

**Planned — proposed syntax.** These examples do not parse or execute:

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

The [system-time fragment reference](as-of.md) explains the existing isolated
parser rule. The intended implementation replaces its integer-revision ambiguity
deliberately. No fallback interprets a temporal expression as a snapshot ID or
resource revision. Timestamp convenience remains undecided until branch scope,
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
handles and the declaration catalog do not implement these historical operations.

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
