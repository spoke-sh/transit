# DELETE

**Unsupported: absent from the SQL grammar and runtime.** Transit SQL cannot
remove rows. `DELETE FROM`, predicates on a delete, `USING` and `RETURNING` have
no accepted syntax or execution contract. `TRUNCATE` is also unsupported.

## Remove state through an application

Use the application's command API and authorized resource writer. The owning
application defines which records can be removed and commits the change through
the [state boundary](../state.md#read-and-commit). SQL supplies no affected-row
count, missing-row policy or multi-row deletion transaction.

A selected row is not a deletion permit. Current grants, fenced writer ownership
and commit validation still apply when the application processes the command.
Use the original command identity to [recover an uncertain response](../callers.md).

## Rows, resources and history

Removing a current row, retiring a resource and physically cleaning retained
history are separate operations. A row change does not erase accepted input,
receipts or earlier outcomes. Retention defaults to unlimited and requires
application opt-in; capacity pressure does not authorize deletion or expiry.
See [retention and capacity](../retention.md).

A deletion also cannot retract a completed external effect. Connector outcomes
retain their own identity and recovery evidence. See [streaming and effects](streaming.md),
[UPDATE](update.md) and [INSERT](insert.md).
