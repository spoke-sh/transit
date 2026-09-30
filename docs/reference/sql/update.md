# UPDATE

**Unsupported: absent from the SQL grammar and runtime.** Transit SQL cannot
change existing rows. `UPDATE`, assignments in `SET`, `UPDATE ... FROM` and
`RETURNING` have no accepted syntax or execution contract.

## Change state through an application

Send the domain command to the owning application. Its fenced writer reads the
required state, checks domain conditions and proposes mutations against the
validated basis. An accepted turn publishes its mutations, input progress and
outputs together. See [Table mutation](../tables.md#mutation-and-visibility)
and the [application guide](../../guides/applications.md).

A prior `SELECT` does not reserve rows for a later command. Query snapshots,
current write grants and the writer's commit basis are separate. There is no SQL
transaction spanning the read and write, and no SQL affected-row count or
concurrent-update policy. Use the application's conditional operation and
[exact recovery](../callers.md) where supplied.

## Resource boundary

A Table mutation concerns one durable resource. Updating a Document uses its
accepted change protocol; a query projection of that Document is not a writable
Table. A KV decoder similarly supplies a read interpretation, not an update
codec. See [Documents](../documents.md) and [state resources](../state.md).

Changes larger than one turn require an explicit publication or workflow
contract. Splitting work across turns does not provide an atomic SQL statement.
See also [INSERT](insert.md), [DELETE](delete.md) and
[query execution](../queries.md).
