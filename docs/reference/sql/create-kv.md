# CREATE KV

**Grammar only.** This statement names a KV resource and a declared value type.
It does not provision state, choose a writer or install a decoder. SQL query
interfaces reject it.

## Syntax

```text
CREATE KV name (data_type);
data_type := INT64 | BOOL | UTF8 | BINARY
```

`name` is an identifier. Exactly one type token is required. This rule has no
key declaration, initial entries, nullability, retention options or
`IF NOT EXISTS` clause. It does not define a byte codec or an executable type
binding for the resource.

## Examples

These examples illustrate syntax only:

```sql
CREATE KV settings (UTF8);
CREATE KV counters (INT64);
```

## Meaning and current interface

The form refers to the growing profile's [KV resource](../state.md).
Actual reads and mutations use the public client under current resource policy
and writer ownership. Mutations share a turn's commit decision with input
progress and outputs; the declaration creates no new transaction boundary.

Use [growing client operations](../../../packages/zig/transit-client/docs/growing.md)
or [application installation](../applications.md#installation-and-bootstrap) to
provision and access supported state. Unified SQL needs an explicitly declared
KV decoder and schema; arbitrary stored bytes are not implicitly SQL values.
See [query source profiles](../queries.md#source-profiles).

Source: [`createKv`, `dataType`](../../../contracts/sql/TransitExtensions.g4).
