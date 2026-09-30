# INSERT

**Unsupported: absent from the SQL grammar and runtime.** Transit SQL cannot
insert rows into a Table or send values to a sink. The console, Board query
workspace and Flight SQL do not execute `INSERT`.

## Write rows through an application

Use the application's command API and its fenced Station Table writer. The
writer validates the row and proposes state changes with input progress and
outputs in one accepted turn. Current grants and writer ownership apply
independently; permission to query a Table does not authorize changing it.

The [application guide](../../guides/applications.md) shows a complete command
path. [Table mutation](../tables.md#mutation-and-visibility) and
[state commits](../state.md#read-and-commit) define the visibility boundary.
After an uncertain command response, reconcile the original operation through
the [caller recovery contract](../callers.md), preserving its identity.

## SQL boundary

There is no accepted `INSERT ... VALUES`, `INSERT ... SELECT`, `DEFAULT VALUES`,
`ON CONFLICT` or `RETURNING` form. SQL defines no insert result, affected-row
count, default-value policy or duplicate-key behavior. Native Table helpers do
not establish those SQL semantics.

[CREATE TABLE](create-table.md) recognizes a declaration but cannot provision a
write target. [CREATE SINK](create-sink.md) describes an external effect target;
inserting state and dispatching external work have separate commit and recovery
contracts. See [streaming and effects](streaming.md).

See also [UPDATE](update.md), [DELETE](delete.md) and the
[statement index](../sql.md#statement-forms).
