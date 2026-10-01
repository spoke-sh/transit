# INSERT

**Run INSERT through an explicitly configured Table mutation writer. The console
and Flight SQL query interfaces are read-only.** A successful `SELECT` from
`items` does not configure a writer or authorize changes to that Table.

Bounded literal inserts are available through the shared Zig mutation client,
[native ABI/port caller](../../../packages/zig/transit-station-bindings/docs/table-mutations.md),
[typed SDK mutation clients](../sdks.md#table-mutation-callers) and
[mutation CLI](../../../apps/transit-cli/docs/mutations.md), with an explicitly
configured writer. Applications can also compose the private
`station.TableMutation.applySql` helper. The console, Board query workspace, Flight SQL
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

`INSERT INTO items VALUES (1, 100)` omits the required column list and is outside
this syntax. `INSERT INTO items (id, value) VALUES (1, 100)` has supported mutation
syntax, but submitting it in the console reports that its query interface is
read-only. Run `transit mutate --help` and follow the
[saved-command workflow](../../../apps/transit-cli/docs/mutations.md) with your
writer connection. Compilation, submission and observing the applied result are
separate steps; query credentials do not implicitly supply write authority.

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
that operation explicitly. The supplied query host has an opt-in
[`table_writer` role](../../../apps/transit-query-host/README.md) and a combined
`table_query_writer` role, requiring
authorized initialization and a separate mutation policy. Its terminal result
commits with the rows and input progress. Reconcile the original signed send,
observe its processed input and separate rejection, then read durable status;
a send receipt alone does not prove rows were applied.

The [combined owner](../../../contracts/TABLE_QUERY_WRITER_V1.md) serves finite
queries and mutations over the same Table with independent policies. Its two
durable initialization turns create metadata and then enable dispatch. A finite
query retains its admitted source cut across later row changes; a new query
captures a new cut. Query and mutation clients keep their separate operations
and result types.

`INSERT ... SELECT`, `DEFAULT VALUES`, `ON CONFLICT` and `RETURNING` are unsupported.
[CREATE TABLE](create-table.md) does not provision a SQL target, and inserting
rows does not dispatch a [sink effect](create-sink.md).

See also [UPDATE](update.md), [DELETE](delete.md) and [Table mutation](../tables.md).
