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
column or making a key column nullable rejects. General constraint addition or
removal and USING expressions are unsupported.

Names/default changes are metadata-only. Changing a default affects future
INSERT/DEFAULT assignments without rewriting existing values. Added columns use
their default or nullable NULL for existing rows. Adding a required column
without a default can succeed for an empty Table; it fails if any existing row
cannot acquire a valid value.

Nullability and character-limit tightening validate every existing row. Physical
layout changes rewrite rows by stable column identity. Admitted type changes use
exact checked integer/decimal, integer-to-float and float-width conversions;
overflow and inexact rounding reject. Different text, temporal and nested
descriptors do not acquire implicit conversions. Key type changes rebuild the
index and revalidate uniqueness.

The owner freezes the source/schema, fences conflicting DDL/DML and stages
bounded work. Readers see the original schema and rows until the complete
successor publishes atomically. A conversion or constraint failure preserves
that original head and records an attributed rejection. Current authorization
still applies during continuation and outcome inspection.

Captured readers retain their original schema and cut. New plans resolve the
new metadata; previously prepared or pending work cannot silently recompile.
After uncertainty use `.status` and `.resume` on the saved operation. Cancellation
can close pending work but cannot reverse an applied schema change.

See [Tables](../tables.md), [schema evolution](../../../contracts/TABLE_SCHEMA_V1.md#pure-schema-evolution)
and the [catalog lifecycle](../../../packages/zig/transit-catalog/docs/table-metadata.md).
