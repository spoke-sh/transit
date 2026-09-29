# SHOW

**Grammar only.** This statement names a catalog listing. It does not resolve
catalogs or return rows in the console, Board query workspace or Flight SQL.

## Syntax and examples

These four examples illustrate syntax only:

```sql
SHOW TABLES;
SHOW SOURCES;
SHOW SINKS;
SHOW CONNECTIONS;
```

These are all four alternatives in the grammar. There are no filters, namespace
arguments, `LIKE`, `WHERE` or pagination clauses. `SHOW DOCUMENTS`, `SHOW KV` and
`SHOW GRANTS` are not part of this rule. The grammar defines no result schema,
ordering, visibility or continuation contract.

## Meaning and current interface

`TABLES` names typed state Tables; `SOURCES` and `SINKS` refer to the connector
declarations, while `CONNECTIONS` refers to reusable connector configuration.
The statement recognizes those object families without implementing a catalog.

For current console metadata use the dot commands documented in
[the console guide](../../../apps/transit-cli/docs/console.md). Console `.show`
displays effective settings; it is distinct from SQL `SHOW`. Use
[Board inspection](../../guides/inspect-board.md) for bounded runtime evidence
under its configured read scope. Neither interface promises these SQL result sets.

Source: [`showStatement`, `catalogKind`](../../../contracts/sql/TransitExtensions.g4).
