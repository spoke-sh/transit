# DELETE

DELETE removes selected current rows through the console's configured catalog
owner and shared typed Table callers. The caller needs current inspect and
delete rights plus native access. Query access does not authorize deletion;
Flight and Board query routes remain read-only.

```sql
DELETE FROM people WHERE id = 7;
DELETE FROM people WHERE active = FALSE OR name IS NULL;
DELETE FROM people;
```

WHERE uses the same typed scalar comparisons, exact state tests and bounded
NOT/AND/OR predicate program as [UPDATE](update.md). Omitting WHERE selects all
rows at the frozen source basis. Exact complete primary-key equality can use
the key index; other predicates use a finite scan. USING, RETURNING, joins and
TRUNCATE are unsupported.

The owner freezes selection and stages one complete successor. Row removal,
index changes and the terminal matched/changed counts publish together. Every
matched row is changed; an empty match records zero for both counts. Readers
observe the old or fully published successor Table, never partial deletion.

After an uncertain response, inspect and resume the original saved operation.
Repeating SQL creates new work. Cancellation cannot undo an already published
result; dropping and recreating a name cannot redirect the saved deletion to
the replacement object. See the [console recovery guide](../../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
and [DML contract](../../../contracts/TABLE_DML_V1.md).

Removing current rows does not remove the Table definition or erase retained
snapshots, accepted inputs or receipts. Retention defaults to unlimited and
requires application opt-in; quota pressure does not authorize expiry. Use
[DROP TABLE](drop-table.md) for the selected schema-lifecycle operation, and see
[retention](../retention.md) for the separate history and cleanup boundary.
