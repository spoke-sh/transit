# ALTER TABLE

ALTER TABLE changes a Table in the configured catalog under current inspect and
alter permissions. It binds the original object and immutable metadata; saved
work is never rebound to a renamed or replacement Table.

```sql
ALTER TABLE people ADD COLUMN email VARCHAR(320);
ALTER TABLE people RENAME COLUMN name TO full_name;
ALTER TABLE people ALTER COLUMN email SET DEFAULT 'unknown';
ALTER TABLE people ALTER COLUMN email DROP DEFAULT;
ALTER TABLE people ALTER COLUMN full_name SET NOT NULL;
ALTER TABLE people ALTER COLUMN full_name DROP NOT NULL;
ALTER TABLE people ALTER COLUMN id TYPE BIGINT;
ALTER TABLE people DROP COLUMN email;
ALTER TABLE people RENAME TO contacts;
```

One statement contains one action. SET DATA TYPE is also accepted for type
changes. New columns receive new stable identities. Rename preserves identity;
dropped identities are never reused. Dropping the last column, dropping a key
column or making a key column nullable rejects. CHECK and explicitly staged
foreign keys support `ADD [CONSTRAINT name]`, `DROP CONSTRAINT name [RESTRICT]`
and (for CHECK) `VALIDATE CONSTRAINT name`. USING expressions reject.

Table and non-key column renames, default changes, supported column drops and
nullable or constant-default additions publish metadata without rewriting rows.
Reads interpret old rows through their exact physical schema and stable column
identities. Changing a default affects future INSERT/DEFAULT assignments;
existing rows retain the value selected when the column was added, including
nullable NULL. Reusing a dropped column name creates a new identity and initial
value. Adding a required column
without a default can succeed for an empty Table; it fails if any existing row
cannot acquire a valid value.

Nullability and character-limit tightening and CHECK validation scan existing
rows under explicit row/byte budgets. Exceeding a budget rejects the change.
Physical type, codec, collation and key-layout changes on populated Tables reject
with a rewrite-required outcome pending the online phased rewrite runtime.
The pure type-conversion helpers do not establish that runtime. Key column
renames preserve identity and need no rewrite. Later flushes and bounded compaction normalize selected old rows while
retained readers keep their original interpretation.

The owner freezes the source/schema, fences conflicting DDL/DML and stages
bounded work. Readers see the original schema and rows until the complete
successor publishes atomically. A conversion or constraint failure preserves
that original head and records an attributed rejection. Current authorization
still applies during continuation and outcome inspection.

Captured readers retain their original schema and cut. New plans resolve the
new metadata; previously prepared or pending work cannot silently recompile.
The console checks the original request after uncertainty and reports an
unconfirmed outcome if it cannot establish completion. Cancellation
can close pending work but cannot reverse an applied schema change.

See [Tables](../tables.md), [schema evolution](../../../../contracts/TABLE_SCHEMA_V1.md#pure-schema-evolution)
and the [catalog lifecycle](../../../../packages/zig/transit-catalog/docs/table-metadata.md).
