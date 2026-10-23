# CREATE SOURCE

**Grammar only.** This statement describes a query source backed by a connector's
captured observations. It does not create a state resource, register a source
adapter, start polling or make a source available to `SELECT`.

## Syntax

```text
CREATE SOURCE name FROM connector_kind CONNECTION connection_name
  [ [WITH] (option = option_value [, ...]) ];
option_value := 'text' | SECRET('credential_reference')
```

The source name, connector kind and connection name are identifiers. Options are
optional; if supplied, the parenthesized list must be nonempty. `WITH` can prefix
that list, but cannot appear on its own. The grammar accepts any connector-kind
identifier without resolving the connection or checking configuration compatibility.

## Examples

These examples illustrate syntax only:

```sql
CREATE SOURCE observations FROM HTTP CONNECTION remote_api;
CREATE SOURCE updates FROM HTTP CONNECTION remote_api WITH (poll_ms = '1000');
CREATE SOURCE readings FROM GRPC CONNECTION sensor_api (method = 'Read');
```

`poll_ms` and `method` are illustrative option names, not an implemented SQL
configuration contract. Bare `1000` would not satisfy the option-value grammar.

## Meaning and current interface

The reference distinguishes a connector-backed query adapter from durable
KV, Table or Document state. Captured data and a declared decoder/schema still
need explicit identity, current read authorization and a bounded source basis.
The statement alone defines none of those runtime bindings.

Executable SQL uses an explicitly configured [query source](../queries.md#source-declarations).
Use [source configuration](../../../../packages/zig/transit-query/docs/unified-client.md) for
the supported KV/Table/Document path and [connectors](../connectors.md) for
recorded remote observations. Neither interface enables this SQL declaration.

See [streaming and effects](streaming.md) for the distinction between captured
observations, retained state and continuous query processing.

Source: [`createSource`](../../../../contracts/sql/TransitExtensions.g4). See also
[CREATE CONNECTION](create-connection.md) and [syntax](syntax.md).
