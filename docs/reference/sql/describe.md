# DESCRIBE

**Grammar only.** This statement names an object to describe. It does not perform
catalog lookup or return a schema through SQL query interfaces.

## Syntax

```text
DESCRIBE object_name;
```

`object_name` is a single identifier. The rule has no object-kind keyword,
qualified name, query argument, `EXTENDED` modifier or `DESC` shorthand. Quoting
follows the [shared syntax](syntax.md#names). No result schema or name-resolution
policy is defined by this grammar.

## Example

This example illustrates syntax only:

```sql
DESCRIBE items;
```

## Meaning and current interface

The form represents metadata inspection, separate from granting access or reading
application values. An implementation would need a scoped catalog and exact
description/result contract; grammar acceptance supplies neither.

Use the supported metadata commands in the
[console guide](../../../apps/transit-cli/docs/console.md), the
[Board API](../board-api.md), or the declared [query source schema](../queries.md#source-declarations).
Current permissions still determine which metadata may be disclosed.

Source: [`describeStatement`](../../../contracts/sql/TransitExtensions.g4).
See also [SHOW](show.md).
