# CREATE DOCUMENT

**Grammar only.** This statement names a Document. It does not create a Document
resource, initialize a replica or accept a change. It is not executable in SQL
query interfaces.

## Syntax

```text
CREATE DOCUMENT name;
```

`name` is an identifier. There are no fields, options, initial JSON value,
schema, replica configuration or `IF NOT EXISTS` clause in this rule.

## Example

This example illustrates syntax only:

```sql
CREATE DOCUMENT notebook;
```

## Meaning and current interface

The declaration refers to Station's [Document model](../documents.md), whose
structured values and collaborative text live in an explicitly provisioned
resource. Document identity, replica identity, accepted revision and merge epoch
remain distinct. Tentative edits are not accepted state.

Use the [Document service](../../../packages/zig/transit-station-document/docs/service.md)
and [caller interface](../../../packages/zig/transit-station-document/docs/remote.md)
for initialization, changes and reads. Current authorization and writer fencing
still apply. Querying requires an explicit accepted Document projection; this
grammar form neither creates one nor makes arbitrary Document paths valid SQL.

Source: [`createDocument`](../../../contracts/sql/TransitExtensions.g4). See also
[SELECT](select.md) and [state resources](../state.md).
