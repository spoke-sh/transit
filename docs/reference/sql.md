# SQL reference

Transit executes finite `SELECT` queries through Fuze and bounded Table writes
through configured console writer/catalog routes. The automatic local connection
supplies the writer for `items`; other connections configure their own routes. SQL compiles
to the same typed plan used by native callers. It does not grant access, create
a source or change its declaration. The console uses a fresh authorized snapshot
session for each query; explicit durable queries capture a source basis and
publish bounded Arrow result segments. See [query execution](queries.md).

Transit does not claim SQL Core, full PostgreSQL, SQL/PGQ or GQL conformance.
The [checked compatibility corpus](../../contracts/sql/README.md#compatibility-corpus)
establishes syntax and AST agreement for its declared PostgreSQL subset; execution
keeps Transit's documented types, cell states, ordering and arithmetic limits.
The [standards and data-model analysis](../internals/query-engine.md#standards-and-multiple-data-models)
explains future language targets without expanding the supported interface.
The [grammar surface inventory](sql/grammar-surface.md) labels implemented and
planned operations, including the intended graph, foreign-relation and historical
schema syntax. Planned examples are proposals, not runnable SQL.

## Find an operation

| Task                                                    | Reference                                                                                                                                                                                                                                                                                |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Measure declarative components and inspect TPC coverage | [Benchmarks](benchmarks.md)                                                                                                                                                                                                                                                              |
| Compare implemented and planned grammar                 | [Grammar surface and semantic targets](sql/grammar-surface.md)                                                                                                                                                                                                                           |
| Read rows, filter or aggregate                          | [SELECT](sql/select.md)                                                                                                                                                                                                                                                                  |
| Understand names and literal syntax                     | [Syntax](sql/syntax.md)                                                                                                                                                                                                                                                                  |
| Check scalar types, nulls and missing values            | [Data types and cell states](sql/types.md)                                                                                                                                                                                                                                               |
| Find a function or operator                             | [Functions and operators](sql/expressions.md)                                                                                                                                                                                                                                            |
| Insert, change or remove rows                           | [INSERT](sql/insert.md), [UPDATE](sql/update.md), [DELETE](sql/delete.md) through an explicitly enabled writer, shared Zig/native ABI/port and [typed SDK callers](sdks.md#table-mutation-callers), or the [console](../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs) |
| Inspect definitions and plans                           | [DESCRIBE](sql/describe.md), [SHOW TABLES](sql/show.md), [EXPLAIN](sql/explain.md) within the configured source scope                                                                                                                                                                    |
| Connect streams, materialize data or dispatch effects   | [Streaming and effects](sql/streaming.md)                                                                                                                                                                                                                                                |
| Define an application interface                         | [Application declarations](sql/application.md)                                                                                                                                                                                                                                           |

## Support and execution

This reference covers every statement in the
[SQL grammar](../../contracts/sql/TransitExtensions.g4), its separate historical-read
fragment, and the [application declaration grammar](../../contracts/application/Application.g4).
Syntax recognition, query compilation and administrative publication are separate
capabilities. Each operation has an explicit support boundary:

| Status            | Meaning                                                                               |
| ----------------- | ------------------------------------------------------------------------------------- |
| Executable        | The stated interface compiles and executes the documented subset                      |
| Grammar only      | The reference parser recognizes the form; query interfaces do not execute it          |
| Separate compiler | Application definitions compile offline and use explicit publication operations       |
| Offline compiler  | State definitions parse, validate and format for review; no SQL publication operation |
| Zig integration   | An application explicitly invokes a typed helper inside its authorized Station turn   |
| Unsupported       | The form has no accepted SQL grammar or execution contract                            |

The console dispatches each supported SQL family to its configured execution owner. Console SELECT statements
compile in Fuze and run through authorized query snapshots; Flight adapts its
finite query client. Table mutations instead use the separately configured writer
and its saved-command/result protocol. The local native gateway carries signed
operations, not a general SQL session with implicit write routing.

### Diagnosing rejected SQL

The console and Flight query adapter distinguish parse errors, unsupported
constructs, reference-grammar-only families, and syntax supported through a
different interface. Recognizing a grammar-only family does not validate the
submitted statement or establish execution support. Valid syntax can still fail
source binding, type checks, budgets or current authorization.

Console parse errors include statement-relative line and byte-column coordinates,
a caret and correction guidance. Context is bounded; literals, quoted identifiers
and comments are masked, and control bytes are escaped. Flight returns a compact
message with coordinates where available and a next step, without SQL excerpts.
Syntax/binding failures use INVALID_ARGUMENT; unavailable syntax or interfaces
use UNIMPLEMENTED. The [console guide](../../apps/transit-cli/docs/console.md#sql-errors)
shows the display and explains how compile failures differ from uncertain work.

State definitions have an offline Zig compiler. Shared Zig/C ABI/native-port
catalog callers and the [console](../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
also create and publish named two-column Tables. General SQL administrative
routes, grants and connector catalog listings remain unavailable;
their examples describe syntax and do not execute in the query console. Unsupported command entries
explain the current alternatives without defining new syntax.

The console, CLI and Board use the same query v1 source and plan contract.
Flight SQL uses its configured Table subset and adapts results to primitive
Arrow int64 columns.

| Capability | Query v1 |
| --- | --- |
| Sources | One declared KV, Table or accepted Document projection |
| `SELECT *` | All one to eight declared columns |
| Explicit projection | One to eight output positions in the requested order; result names must be distinct |
| Output aliases | Explicit `AS name` on columns, `COUNT(*)`, `COUNT(column)` and `SUM(column)`; distinct names permit repeated inputs |
| Predicate | Boolean composition of typed comparisons and exact cell-state tests |
| Ordering | Defined source order |
| `LIMIT n` | Full u64 count; no implicit truncation when omitted |
| `COUNT(*)` | uint64, counting every cell state; Flight checks conversion to int64 |
| `COUNT(column)` | uint64, counting top-level values; skips missing/null; error/conflict fails; Flight checks conversion to int64 |
| `SUM(column)` | Checked int64; skips missing/null; error/conflict fails |
| Comparison with `NULL` | Rejected; use `IS NULL` |
| Results | Nested typed cells: value, null, missing, type error, conflict |

## Statement forms

Each statement page gives its syntax, examples, meaning and support boundary.
Start with [syntax, names and literals](sql/syntax.md) for notation and shared rules.

| Statement                                                  | Support                                                                                 | Reference                                                                 |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `SELECT`                                                   | Executable finite read in the profiles above                                            | [Projection, filtering, limits and aggregates](sql/select.md)             |
| `INSERT`                                                   | Console with explicit writer, Zig/native ABI/port and typed SDK callers; Flight rejects | [Row insertion and current application APIs](sql/insert.md)               |
| `UPDATE`                                                   | Primary-key equality through the explicit mutation writer                               | [State changes and commit boundaries](sql/update.md)                      |
| `DELETE`                                                   | Primary-key equality through the explicit mutation writer                               | [Row removal and retained history](sql/delete.md)                         |
| `CREATE CONNECTION`                                        | Grammar only                                                                            | [Connector configuration and secret references](sql/create-connection.md) |
| `CREATE SOURCE`                                            | Grammar only                                                                            | [Captured connector observations as a source](sql/create-source.md)       |
| `CREATE SINK`                                              | Grammar only                                                                            | [Connector effect target](sql/create-sink.md)                             |
| `CREATE TABLE`                                             | Console with explicit catalog, offline compiler and shared callers; Flight rejects      | [Columns, types and nullability](sql/create-table.md)                     |
| `CREATE DOCUMENT`                                          | Offline compiler; no publication                                                        | [Document declaration](sql/create-document.md)                            |
| `CREATE KV`                                                | Offline compiler; no publication                                                        | [Typed KV declaration](sql/create-kv.md)                                  |
| `GRANT`                                                    | Grammar only                                                                            | [Privilege declaration](sql/grant.md)                                     |
| `REVOKE`                                                   | Grammar only                                                                            | [Privilege revocation](sql/revoke.md)                                     |
| `SHOW`                                                     | `TABLES` executes in configured scope; connector listings are grammar only              | [Tables, sources, sinks and connections](sql/show.md)                     |
| `DESCRIBE`                                                 | Executable in configured scope                                                          | [Named-object description](sql/describe.md)                               |
| `EXPLAIN`                                                  | Executable for finite SELECT; no query execution                                        | [Proposed plan and output columns](sql/explain.md)                        |
| `FOR SYSTEM_TIME AS OF`                                    | Separate grammar fragment; not part of `SELECT`                                         | [Revision selection](sql/as-of.md)                                        |
| `CREATE INTERFACE`, `THEME`, `SCREEN`, `BINDING`, `ACTION` | Separate application compiler; publication is explicit                                  | [Application declarations](sql/application.md)                            |

### Other SQL operations

| Operation | Current boundary |
| --- | --- |
| `DESCRIBE SELECT` | Use `EXPLAIN SELECT` for output column inspection |
| `ALTER`, `DROP`, `TRUNCATE` | No SQL object replacement, retirement or bulk deletion |
| `BEGIN`, `COMMIT`, `ROLLBACK` | No SQL transaction session; application turns retain their own atomic boundary |
| `COPY`, `MERGE`, upsert forms | No SQL import/export or mutation contract |
| `CREATE VIEW`, `CREATE MATERIALIZED VIEW` | No named SQL view or maintained-query definition |
| `SUBSCRIBE`, streaming windows, event-time watermarks | No continuous SQL contract; see [streaming and effects](sql/streaming.md) |
| `PREPARE`, `EXECUTE`, parameters | [Typed templates, SDK and CLI bindings](sql/parameters.md) use a separate grammar entry; named prepared statements remain unsupported |

These forms are absent from the checked grammar. Native operations, transport
metadata and console dot commands do not establish equivalent SQL support.

## Query examples

Configure an authorized [query source](../../apps/transit-cli/docs/unified-query.md)
before submitting SQL. The examples use `items`, with int64 `id` and nullable
int64 `value` columns. SQL does not create this source:

```sql
SELECT * FROM items;
SELECT id, value FROM items WHERE id >= 0 LIMIT 8;
SELECT value FROM items WHERE value IS NULL;
SELECT COUNT(*) FROM items;
SELECT SUM(value) FROM items WHERE id > 0;
```

A single restricted derived-table form aggregates a limited input:

```sql
SELECT SUM(chosen.value)
FROM (SELECT value FROM items WHERE id >= 0 LIMIT 2) AS chosen;
```

An outer `LIMIT` on a direct aggregate rejects; it does not silently become a
limit on input. The inner projection must retain the aggregate column. General
subqueries, outer predicates and nested derived tables are unsupported.

## Names, literals and comparisons

The [syntax reference](sql/syntax.md) describes lexical rules and option lists;
[data types](sql/types.md) distinguishes scalar types and cell states, and
[functions and operators](sql/expressions.md) lists available expressions.
[SELECT](sql/select.md) describes clause behavior and failures.

Unquoted ASCII names fold to lowercase. Double-quoted names preserve case but
must satisfy Fuze's identifier rules. A column qualifier must match the declared
source, its explicit `AS` alias, or the restricted derived-table alias in its own
scope. The compiler does no catalog or
schema-name lookup. Keywords are case-insensitive.

Literals include signed decimal int64, `TRUE`, `FALSE`, `NULL`, UTF-8 strings
with doubled single quotes and binary hex such as `'\x00ff'::bytea`. Backslashes
are literal. There are no implicit casts, E strings or dollar quotes.

Queries accept `=`, `<>`, `!=`, `<`, `<=`, `>` and `>=` under their type
rules. Operands are exactly typed,
including byte ordering for text/binary. Uint64 and float64 comparisons use explicit string literals such as
`'18446744073709551615'::uint64` and `'1.25e2'::float64`.
`IS NULL` selects explicit null, not a missing Document field. `IS MISSING`,
`IS VALUE`, `IS TYPE_ERROR` and `IS CONFLICT` select those exact states. Native
and local file queries compose predicates with NOT, AND, OR and grouping; [Boolean rules](sql/expressions.md#predicate-operators)
define precedence, unknown values, eager errors and the 64-instruction bound.

## Bounds and unsupported operations

Input is at most 4096 UTF-8 bytes; names are at most 16 ASCII identifier bytes;
nested block comments are bounded to 16 levels. One optional semicolon, whitespace,
line comments and nested block comments are accepted. Additional statements and
trailing tokens fail. Durable requests use an explicitly budgeted finite plan
upload.

Joins, sorting, aggregation grouping, arithmetic,
general casts and continuous queries are unsupported.
Public query transports reject writes. Applications can explicitly integrate
the [bounded Table mutation helper](sql/insert.md) in their fenced writer.
`CREATE TABLE/KV/DOCUMENT` compile offline through Fuze's
[`Declaration` API](../../contracts/STATE_DECLARATION_V1.md). Compatible empty
Tables can also be created through explicit Zig/C ABI/native-port catalog callers
and `transit catalog`; native
provisioning and query/mutation policy remain separate. Other `CREATE`
forms, `GRANT`, `REVOKE` and connector forms of `SHOW` in the
[reference grammar](../../contracts/sql/README.md) are grammar-only.
None executes in the console, Board query workspace or Flight SQL.

This is not PostgreSQL execution compatibility. The checked corpus establishes
selected parser/AST agreement. Fuze's ordered, checked int64 sum differs from
PostgreSQL's widened numeric result. No optimizer rewrite is enabled by the
separate rewrite proofs.

See [query SQL v1](../../packages/zig/transit-fuze/docs/unified-sql.md) for compiler
APIs, exact error families and source-binding rules. The
[console guide](../../apps/transit-cli/docs/console.md) explains explicit submission,
namespace selection, completion and recovery after a lost response.
