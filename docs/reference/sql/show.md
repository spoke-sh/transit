# SHOW

`SHOW TABLES` in the console lists its configured catalog when `writes.catalog`
is present; otherwise it lists the query-source scope. The query workspace
`inspect` operation retains its single-source scope. `SHOW SOURCES`, `SHOW SINKS`
and `SHOW CONNECTIONS` remain grammar-only connector catalog forms.

## Syntax and examples

The Table listing is executable:

```sql
SHOW TABLES;
```

The connector listings illustrate syntax only:

```sql
SHOW SOURCES;
SHOW SINKS;
SHOW CONNECTIONS;
```

These are all four alternatives in the grammar. There are no filters, namespace
arguments, `LIKE`, `WHERE` or pagination clauses. `SHOW DOCUMENTS`, `SHOW KV` and
`SHOW GRANTS` are not part of this rule.

## Result and access

`TABLES` names typed state Tables; `SOURCES` and `SINKS` refer to the connector
declarations, while `CONNECTIONS` refers to reusable connector configuration.
Within query-source scope, `SHOW TABLES` returns zero or one names: the configured name when it identifies a
typed Table, otherwise an empty list. This is not a realm-wide catalog. Native
source/requester access and query policy must permit the configured declaration
before and after metadata is assembled, including empty listings. The result
contains current metadata revisions and declaration/schema fingerprints; it
acquires no data snapshot. See the [inspection contract](../../../contracts/SQL_INSPECTION_V1.md).

Catalog listings use current inspect policy and native reads, with at most eight
definitions resident per page. Continuation requires an unchanged resource revision;
a conflict stops the listing, and any partial output must be discarded before retry.
JSON emits `catalog_page` envelopes with full-width IDs as decimal strings. This
route uses the [catalog contract](../../../contracts/DECLARATIVE_CATALOG_V1.md).

Console `.show` displays effective settings; it is distinct from SQL `SHOW`.
See the [console guide](../../../apps/transit-cli/docs/console.md) for related
metadata commands. [Board inspection](../../guides/inspect-board.md) presents
bounded runtime evidence under its configured read scope. Flight SQL retains
its separate Table metadata and SELECT interfaces and does not accept these
SQL inspection statements.

Source: [`showStatement`, `catalogKind`](../../../contracts/sql/TransitExtensions.g4).
