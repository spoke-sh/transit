# SQL reference

Transit executes a finite, read-only `SELECT` subset through Fuze. SQL compiles
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

## Find an operation

| Task | Reference |
| --- | --- |
| Read rows, filter or aggregate | [SELECT](sql/select.md) |
| Understand names and literal syntax | [Syntax](sql/syntax.md) |
| Check scalar types, nulls and missing values | [Data types and cell states](sql/types.md) |
| Find a function or operator | [Functions and operators](sql/expressions.md) |
| Insert, change or remove rows | [INSERT](sql/insert.md), [UPDATE](sql/update.md), [DELETE](sql/delete.md) through an explicitly enabled writer, shared Zig/native ABI/port and [typed SDK callers](sdks.md#table-mutation-callers), or [mutation CLI](../../apps/transit-cli/docs/mutations.md) |
| Inspect definitions and plans | [DESCRIBE](sql/describe.md), [SHOW TABLES](sql/show.md), [EXPLAIN](sql/explain.md) within the configured source scope |
| Connect streams, materialize data or dispatch effects | [Streaming and effects](sql/streaming.md) |
| Define an application interface | [Application declarations](sql/application.md) |

## Support and execution

This reference covers every statement in the
[SQL grammar](../../contracts/sql/TransitExtensions.g4), its separate historical-read
fragment, and the [application declaration grammar](../../contracts/application/Application.g4).
Syntax recognition, query compilation and administrative publication are separate
capabilities. Each operation has an explicit support boundary:

| Status | Meaning |
| --- | --- |
| Executable | The stated interface compiles and executes the documented subset |
| Grammar only | The reference parser recognizes the form; query interfaces do not execute it |
| Separate compiler | Application definitions compile offline and use explicit publication operations |
| Offline compiler | State definitions parse, validate and format for review; no SQL publication operation |
| Unsupported | The form has no accepted SQL grammar or execution contract |

State definitions have an offline Zig compiler. Administrative publication,
grants and connector catalog listings remain **grammar-only**;
their examples describe syntax and do not execute in the query console. Unsupported command entries
explain the current alternatives without defining new syntax.

The console, CLI and Board use the same query v1 source and plan contract.
Flight SQL uses its configured Table subset and adapts results to primitive
Arrow int64 columns.

| Capability | Query v1 |
| --- | --- |
| Sources | One declared KV, Table or accepted Document projection |
| `SELECT *` | All one to eight declared columns |
| Explicit projection | One to eight distinct column names in the requested order |
| Predicate | One comparison or exact cell-state test |
| Ordering | Defined source order |
| `LIMIT n` | Full u64 count; no implicit truncation when omitted |
| `COUNT(*)` | uint64, counting every cell state; Flight checks conversion to int64 |
| `SUM(column)` | Checked int64; skips missing/null; error/conflict fails |
| Comparison with `NULL` | Rejected; use `IS NULL` |
| Results | Nested typed cells: value, null, missing, type error, conflict |

## Statement forms

Each statement page gives its syntax, examples, meaning and support boundary.
Start with [syntax, names and literals](sql/syntax.md) for notation and shared rules.

| Statement | Support | Reference |
| --- | --- | --- |
| `SELECT` | Executable finite read in the profiles above | [Projection, filtering, limits and aggregates](sql/select.md) |
| `INSERT` | Bounded explicit writer with Zig/native ABI/port and typed SDK callers; query transports reject | [Row insertion and current application APIs](sql/insert.md) |
| `UPDATE` | Primary-key equality through the explicit mutation writer | [State changes and commit boundaries](sql/update.md) |
| `DELETE` | Primary-key equality through the explicit mutation writer | [Row removal and retained history](sql/delete.md) |
| `CREATE CONNECTION` | Grammar only | [Connector configuration and secret references](sql/create-connection.md) |
| `CREATE SOURCE` | Grammar only | [Captured connector observations as a source](sql/create-source.md) |
| `CREATE SINK` | Grammar only | [Connector effect target](sql/create-sink.md) |
| `CREATE TABLE` | Offline compiler; no publication | [Columns, types and nullability](sql/create-table.md) |
| `CREATE DOCUMENT` | Offline compiler; no publication | [Document declaration](sql/create-document.md) |
| `CREATE KV` | Offline compiler; no publication | [Typed KV declaration](sql/create-kv.md) |
| `GRANT` | Grammar only | [Privilege declaration](sql/grant.md) |
| `REVOKE` | Grammar only | [Privilege revocation](sql/revoke.md) |
| `SHOW` | `TABLES` executes in configured scope; connector listings are grammar only | [Tables, sources, sinks and connections](sql/show.md) |
| `DESCRIBE` | Executable in configured scope | [Named-object description](sql/describe.md) |
| `EXPLAIN` | Executable for finite SELECT; no query execution | [Proposed plan and output columns](sql/explain.md) |
| `FOR SYSTEM_TIME AS OF` | Separate grammar fragment; not part of `SELECT` | [Revision selection](sql/as-of.md) |
| `CREATE INTERFACE`, `THEME`, `SCREEN`, `BINDING`, `ACTION` | Separate application compiler; publication is explicit | [Application declarations](sql/application.md) |

### Other SQL operations

| Operation | Current boundary |
| --- | --- |
| `DESCRIBE SELECT` | Use `EXPLAIN SELECT` for output column inspection |
| `ALTER`, `DROP`, `TRUNCATE` | No SQL object replacement, retirement or bulk deletion |
| `BEGIN`, `COMMIT`, `ROLLBACK` | No SQL transaction session; application turns retain their own atomic boundary |
| `COPY`, `MERGE`, upsert forms | No SQL import/export or mutation contract |
| `CREATE VIEW`, `CREATE MATERIALIZED VIEW` | No named SQL view or maintained-query definition |
| `SUBSCRIBE`, streaming windows, event-time watermarks | No continuous SQL contract; see [streaming and effects](sql/streaming.md) |
| `PREPARE`, `EXECUTE`, parameters | No SQL prepared-statement or parameter-binding grammar |

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
source (or the restricted derived-table alias). The compiler does no catalog or
schema-name lookup. Keywords are case-insensitive.

Literals include signed decimal int64, `TRUE`, `FALSE`, `NULL`, UTF-8 strings
with doubled single quotes and binary hex such as `'\x00ff'::bytea`. Backslashes
are literal. There are no implicit casts, E strings or dollar quotes.

Queries accept `=`, `<>`, `!=`, `<`, `<=`, `>` and `>=` under their type
rules. Operands are exactly typed,
including byte ordering for text/binary. Uint64 and float64 comparisons use explicit string literals such as
`'18446744073709551615'::uint64` and `'1.25e2'::float64`.
`IS NULL` selects explicit null, not a missing Document field. `IS MISSING`,
`IS VALUE`, `IS TYPE_ERROR` and `IS CONFLICT` select those exact states.

## Bounds and unsupported operations

Input is at most 4096 UTF-8 bytes; names are at most 16 ASCII identifier bytes;
nested block comments are bounded to 16 levels. One optional semicolon, whitespace,
line comments and nested block comments are accepted. Additional statements and
trailing tokens fail. Durable requests use an explicitly budgeted finite plan
upload.

Joins, sorting, grouping, arithmetic, compound predicates, output aliases,
`COUNT(column)`, general casts and continuous queries are unsupported.
Public query transports reject writes. Applications can explicitly integrate
the [bounded Table mutation helper](sql/insert.md) in their fenced writer.
`CREATE TABLE/KV/DOCUMENT` compile offline through Fuze's
[`Declaration` API](../../contracts/STATE_DECLARATION_V1.md). Other `CREATE`
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
