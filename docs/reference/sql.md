# SQL reference

Transit executes a finite, read-only `SELECT` subset through Fuze. SQL compiles
to the same typed plan used by native callers. It does not grant access, create
a source or change its declaration. Query workers capture an authorized source
basis and publish bounded Arrow result segments.

Choose the profile before writing a query:

| Capability | Table v1 | Unified v2 |
| --- | --- | --- |
| Interfaces | `transit query`, Board v1 workspace, Flight SQL | `transit console`, `transit query-v2`, Board v2 workspace |
| Sources | One explicitly configured Table | One explicitly declared KV, Table or accepted Document projection |
| `SELECT *` | Two schema columns | All one to eight declared columns |
| Explicit projection | One or two column names | One or two column names; wider explicit lists require typed plans |
| Predicate | One comparison or `IS NULL` | One comparison or `IS NULL` |
| Ordering | Defined source / primary-key order | Defined source order |
| `LIMIT n` | 0–32 | Full u64 count |
| No limit | No implicit truncation | No implicit truncation; execution budgets still apply |
| `COUNT(*)` | int64 result | uint64 result, counting every cell state |
| `SUM(column)` | Checked int64, skips null | Checked int64, skips missing/null; error/conflict fails |
| `column = NULL` | Selects no rows | Rejected; use `IS NULL` |
| Results | Primitive Arrow | Nested typed cells: value, null, missing, type error, conflict |

## Statement forms

Given an authorized source named `items` with `id` and `value` int64 columns:

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

Unquoted ASCII names fold to lowercase. Double-quoted names preserve case but
must satisfy Fuze's identifier rules. A column qualifier must match the declared
source (or the restricted derived-table alias). The compiler does no catalog or
schema-name lookup. Keywords are case-insensitive.

Literals include signed decimal int64, `TRUE`, `FALSE`, `NULL`, UTF-8 strings
with doubled single quotes and binary hex such as `'\x00ff'::bytea`. Backslashes
are literal. There are no implicit casts, E strings or dollar quotes.

Both profiles accept `=`, `<>`, `!=`, `<`, `<=`, `>` and `>=` under their type
rules. V1 ordered comparisons require int64; v2 uses exactly typed comparisons,
including byte ordering for text/binary. Uint64 and float64 columns can be
projected in v2, but comparison literals for them require typed plans.
`IS NULL` selects explicit null, not a missing Document field.

## Bounds and unsupported operations

Input is at most 4096 UTF-8 bytes; names are at most 16 ASCII identifier bytes;
nested block comments are bounded to 16 levels. One optional semicolon, whitespace,
line comments and nested block comments are accepted. Additional statements and
trailing tokens fail. The v1 public request additionally limits encoded plans
to 207 bytes; v2 uses an explicitly budgeted finite upload.

Joins, sorting, grouping, arithmetic, compound predicates, output aliases,
`COUNT(column)`, general casts, writes and continuous queries are unsupported.
`CREATE`, `GRANT`, `REVOKE`, `SHOW` and `DESCRIBE` in the
[reference grammar](../../contracts/sql/README.md) are **grammar-only**.
They do not execute in the console, Board query workspace or Flight SQL.

This is not PostgreSQL execution compatibility. The checked corpus establishes
selected parser/AST agreement. Fuze's ordered, checked int64 sum differs from
PostgreSQL's widened numeric result. No optimizer rewrite is enabled by the
separate rewrite proofs.

See [Table SQL v1](../../packages/zig/transit-fuze/docs/sql.md) and
[unified SQL v2](../../packages/zig/transit-fuze/docs/unified-sql.md) for compiler
APIs, exact error families and source-binding rules. The
[console guide](../../apps/transit-cli/docs/console.md) explains explicit submission,
namespace selection, completion and recovery after a lost response.
