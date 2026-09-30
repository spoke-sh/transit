# INSERT

Bounded literal inserts are available through the Zig application writer helper
`station.TableMutation.applySql`. The console, Board query workspace, Flight SQL
and language SDK query clients do not admit SQL mutations.

## Syntax and values

```sql
INSERT INTO items (id, value) VALUES (7, 12), (8, NULL);
INSERT INTO items (value, id) VALUES (13, 9);
```

Supply both distinct columns of the declared Table, in either order, and one to
three rows. The primary key is a non-null int64. The value is a nullable int64,
boolean, UTF-8 or binary literal matching the Table descriptor; text/binary values
are at most 220 bytes. There are no implicit conversions or omitted/default
columns. Repeated keys within the statement reject before application.

## Application and result

The application explicitly authorizes the caller and routes the statement to
its fenced writer. A query source declaration or read grant does not authorize
writes. The helper inserts into the supplied private Station turn and returns a
provisional affected-row count. Any existing key rejects the whole statement;
there is no upsert or implicit overwrite.

An accepted enclosing turn commits all rows, input progress and its outputs
atomically. The helper restores the entire prior proposal on error, including
budget exhaustion. The three-row bound leaves one of a fresh turn's four
mutation slots for an application-owned outcome; the helper does not reserve or
write that outcome itself. Current writer ownership, grants and source revision
remain native acceptance conditions.

The [mutation contract](../../../contracts/TABLE_MUTATION_V1.md) defines the typed
plan, errors and recovery. Reconcile an uncertain application command with its
original identity under the [caller contract](../callers.md).

An application exposing the shared admission owner can use
`transit-query.TableMutationClient` for signed preparation, saved exact retries,
bounded upload resumption and durable status observation. The writer must expose
that operation explicitly; the supplied query hosts do not install it implicitly.

`INSERT ... SELECT`, `DEFAULT VALUES`, `ON CONFLICT` and `RETURNING` are unsupported.
[CREATE TABLE](create-table.md) does not provision a SQL target, and inserting
rows does not dispatch a [sink effect](create-sink.md).

See also [UPDATE](update.md), [DELETE](delete.md) and [Table mutation](../tables.md).
