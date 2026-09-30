# UPDATE

Literal value updates by primary-key equality are available through the explicit
mutation writer, shared Zig/native ABI/port callers and
[typed SDK mutation clients](../sdks.md#table-mutation-callers). The
[caller guide](../../../packages/zig/transit-station-bindings/docs/table-mutations.md)
defines signed preparation, exact recovery and durable result observation.
Applications can also compose `station.TableMutation.applySql` in a private
turn. Public read-query transports do not admit these statements.

```sql
UPDATE items SET value = 13 WHERE id = 7;
UPDATE items SET items.value = NULL WHERE items.id = 8;
```

The assignment must name the value column of the supplied Table. The predicate
must compare its int64 primary key with an int64 literal. Qualifiers must match
the Table name. Key updates, multiple assignments, expressions, general
predicates, subqueries, `FROM` and `RETURNING` are unsupported.

The replacement is NULL or an exactly typed literal for the declared nullable
int64, boolean, UTF-8 or binary value. Text and binary values have a 220-byte
bound. The helper returns one affected row when the key exists, including when
the value is unchanged, and zero for a missing key. This result is provisional
until the enclosing turn commits its input progress and changes together.

The application authorizes the command and invokes its fenced writer. A prior
SELECT neither reserves the row nor grants write permission. The helper uses the
private turn's validated read basis and restores the prior proposal on failure;
native commit still checks current writer ownership, grants and write revision.
There is no SQL transaction spanning an earlier query and this operation.

The [mutation contract](../../../contracts/TABLE_MUTATION_V1.md) and
[Table guide](../tables.md) define atomicity, bounds and errors. Recover an
uncertain admitted command using its original identity under the
[caller contract](../callers.md). KV and Document projections do not supply a
writable Table codec. See also [INSERT](insert.md) and [DELETE](delete.md).
