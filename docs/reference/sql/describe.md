# DESCRIBE

`DESCRIBE` returns the ordered column names and types of one configured KV,
Table or Document query source through the console or query workspace `inspect`
operation.

## Syntax

```sql
DESCRIBE items;
```

The object name is a single identifier. The rule has no object-kind keyword,
qualified name, query argument, `EXTENDED` modifier or `DESC` shorthand. Quoting
follows the [shared syntax](syntax.md#names). Unquoted names fold to lowercase;
quoted names resolve exactly against the configured source name.

## Result and access

The result identifies its scope as one configured source, with source kind,
resource, full declaration and schema fingerprints, current metadata and policy
revisions, and column names/types. It does not enumerate other realm objects or
read application rows. Current native source/requester access and query policy
are checked before resolving the name and again before disclosing the result.
`DESCRIBE SELECT ...` is unsupported; use [EXPLAIN](explain.md) for a query's
output columns. See the [inspection contract](../../../contracts/SQL_INSPECTION_V1.md).

Related metadata interfaces are documented in the
[console guide](../../../apps/transit-cli/docs/console.md), the
[Board API](../board-api.md), and the declared [query source schema](../queries.md#source-declarations).
Flight SQL retains its separate Table metadata and SELECT interfaces and does
not accept this SQL statement.

Source: [`describeStatement`](../../../contracts/sql/TransitExtensions.g4).
See also [SHOW](show.md).
