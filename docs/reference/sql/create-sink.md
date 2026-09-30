# CREATE SINK

**Grammar only.** This statement describes a connector effect target. It does
not create durable row storage, dispatch an effect or enable SQL writes.

## Syntax

```text
CREATE SINK name INTO connector_kind CONNECTION connection_name
  [ [WITH] (option = option_value [, ...]) ];
option_value := 'text' | SECRET('credential_reference')
```

Names and connector kinds are identifiers. The option list is optional and, when
present, nonempty. `WITH` is optional only before a supplied list. The grammar
does not resolve a connection name or validate option names, duplicates or values
against a connector implementation.

## Examples

These examples illustrate syntax only:

```sql
CREATE SINK deliveries INTO HTTP CONNECTION remote_api;
CREATE SINK notices INTO HTTP CONNECTION remote_api WITH (path = '/events');
```

`path` is an illustrative option, not an implemented SQL sink configuration.
There is no `INSERT INTO sink`, `SELECT INTO` or continuous query-to-sink form
in the SQL grammar.

## Meaning and current interface

A sink represents external I/O through a connector, with recorded intent,
authorization for an attempt and a captured outcome. It is distinct from a Table
or KV mutation. Replay reads the recorded outcome; it must not redispatch.
An unknown remote outcome still needs the connector's reconciliation policy.

Use the existing [effect APIs](../connectors.md) to perform supported HTTP/gRPC
operations. Naming a sink would not authorize dispatch, resolve credentials or
promise cancellation of remote work. See [CREATE CONNECTION](create-connection.md)
for the configuration syntax and secret references.

See [streaming and effects](streaming.md) for query-to-effect boundaries and
[INSERT](insert.md) for the absence of SQL writes.

Source: [`createSink`](../../../contracts/sql/TransitExtensions.g4).
