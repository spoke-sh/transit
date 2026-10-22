# UPDATE

UPDATE changes selected rows through the console's configured catalog owner and
shared typed Table callers. Current inspect and update rights are separate from
read, insert, delete and schema-lifecycle rights. Native access is also required.
Flight and Board query routes do not admit writes.

```sql
UPDATE people SET name = 'Ada Lovelace', active = DEFAULT WHERE id = 1;
UPDATE people SET active = FALSE WHERE id >= 10 AND name IS NOT NULL;
UPDATE people SET active = TRUE;
```

Assignments name distinct existing columns and use typed constants, NULL or
DEFAULT. Multiple assignments and primary-key changes are supported; all values
must satisfy the declared schema, and the complete successor must retain key
uniqueness. Assignments are validated even when no row matches. Expressions
such as `value = value + 1`, subqueries, UPDATE FROM and RETURNING are unsupported.

WHERE accepts typed scalar comparisons, exact cell-state tests, parentheses,
NOT, AND and OR, with at most 64 postfix instructions. NULL comparisons reject;
use IS NULL. A qualifier must match the Table name. Nested/JSON comparisons and
cross-Table references are unsupported. Omitting WHERE selects every row at the
frozen source basis.

A conjunction containing exactly one equality for every primary-key column and
no additional condition can use the collision-safe key index. Other predicates
scan a finite immutable source; partial keys and inequalities do not acquire
an ordered range index. The original predicate is always evaluated.

The owner freezes selection, stages changes and publishes one complete successor
with its terminal outcome. Readers cannot observe a successful prefix. An
unchanged assignment contributes to the committed matched count and not the
changed count; an empty match records zero for both. Counts are part of the
operation result, never inferred by reading the Table again.

After an uncertain response, recover the original saved operation with `.status`
and `.resume` in the [console](../../../../apps/transit-cli/docs/console.md#writing-tables-and-catalogs).
Schema changes or name reuse cannot rebind accepted work. Cancellation cannot
undo publication. See [typed DML](../../../../contracts/TABLE_DML_V1.md),
[Tables](../tables.md), [INSERT](insert.md) and [DELETE](delete.md).
