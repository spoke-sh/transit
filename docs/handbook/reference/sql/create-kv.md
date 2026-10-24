# CREATE KV

**Offline compiler; no publication.** Fuze's Zig `Declaration.compile` validates
this statement as a named KV definition and formats it for review. It does not
provision state, choose a writer or install a decoder. SQL query interfaces
reject it; CLI, Board and language SDKs have no administrative route for it.

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

These examples compile as offline definitions:

```sql
CREATE KV settings (UTF8);
CREATE KV counters (INT64);
```

## Meaning and current interface

The form refers to a native v1 [KV resource](../state.md).
Actual reads and mutations use the public client under current resource policy
and writer ownership. Mutations share a turn's commit decision with input
progress and outputs; the declaration creates no new transaction boundary.

The typed [named resource operations](../../../../packages/zig/transit-station-app/docs/named-resources.md)
allocate, initialize and publish named KV resources with explicit interpretation,
writer and current permissions. They are separate from this offline SQL form.
[Growing client operations](../../../../packages/zig/transit-client/docs/growing.md)
and [application installation](../applications.md#installation-and-bootstrap)
also provision native state. Unified SQL needs an explicitly declared
KV decoder and schema; arbitrary stored bytes are not implicitly SQL values.
See [query source profiles](../queries.md#source-declarations).
The [offline declaration contract](../../../../contracts/STATE_DECLARATION_V1.md)
defines owned names, complete-input validation, canonical formatting and bounds.

Source: [`createKv`, `dataType`](../../../../contracts/sql/TransitExtensions.g4).
