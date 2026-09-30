# DELETE

Deletion by primary-key equality is available through the explicit mutation
writer, shared Zig/native ABI/port callers and
[typed SDK mutation clients](../sdks.md#table-mutation-callers). The
[caller guide](../../../packages/zig/transit-station-bindings/docs/table-mutations.md)
defines signed preparation, exact recovery and durable result observation.
Applications can also compose `station.TableMutation.applySql` in a private turn. The console, Board query workspace,
Flight SQL and language SDK query clients do not admit SQL mutations.

```sql
DELETE FROM items WHERE id = 7;
```

The predicate must compare the supplied Table's int64 primary key with an int64
literal. An optional qualifier must match the Table name. General predicates,
`USING`, `RETURNING` and unqualified whole-Table deletion are unsupported.
`TRUNCATE` is also unsupported.

The helper returns one affected row when the key exists and zero when absent.
It changes only the private Station proposal. The result becomes durable when
the enclosing turn commits its input progress, row removal and outputs together.
Any error restores the complete prior proposal; underlying read failure still
prevents commit. The application must authorize the caller and route the command
to its current fenced writer. Query access does not confer write permission.

The [mutation contract](../../../contracts/TABLE_MUTATION_V1.md) defines exact
semantics and bounds. Preserve the original admitted identity when recovering an
uncertain response under the [caller contract](../callers.md).

Removing a current row does not retire the resource or erase retained history,
accepted input or receipts. Retention defaults to unlimited and requires
application opt-in; quota pressure does not authorize expiry. Deletion cannot
retract a completed external effect. See [retention](../retention.md),
[streaming and effects](streaming.md), [INSERT](insert.md) and [UPDATE](update.md).
