# CREATE DOCUMENT

**Offline compiler; no publication.** Fuze's Zig `Declaration.compile` validates
this statement as a named Document definition and formats it for review. It does
not create a resource, initialize a replica or accept a change. SQL query
interfaces reject it; CLI, Board and language SDKs have no administrative route
for it.

## Syntax

```text
CREATE DOCUMENT name;
```

`name` is an identifier. There are no fields, options, initial JSON value,
schema, replica configuration or `IF NOT EXISTS` clause in this rule.

## Example

This example compiles as an offline definition:

```sql
CREATE DOCUMENT notebook;
```

## Meaning and current interface

The declaration refers to Station's [Document model](../documents.md), whose
structured values and collaborative text live in an explicitly provisioned
resource. Document identity, replica identity, accepted revision and merge epoch
remain distinct. Tentative edits are not accepted state.

Use the [Document service](../../../../packages/zig/transit-station-document/docs/service.md)
and [caller interface](../../../../packages/zig/transit-station-document/docs/remote.md)
for initialization, changes and reads. Current authorization and writer fencing
still apply. Querying requires an explicit accepted Document projection; this
grammar form neither creates one nor makes arbitrary Document paths valid SQL.
The [offline declaration contract](../../../../contracts/STATE_DECLARATION_V1.md)
defines owned names, complete-input validation, canonical formatting and bounds.

Source: [`createDocument`](../../../../contracts/sql/TransitExtensions.g4). See also
[SELECT](select.md) and [state resources](../state.md).
