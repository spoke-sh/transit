# INSERT

INSERT publishes typed rows through the console's configured catalog owner and
shared Zig/native ABI/port and typed SDK Table callers. The caller needs current
inspect and insert rights plus native access. Read permission and a successful
SELECT do not authorize a write. Board and Flight query routes remain read-only.

```sql
CREATE TABLE people (
    id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    active BOOLEAN DEFAULT TRUE
);
INSERT INTO people VALUES (1, 'Ada', TRUE), (2, 'Grace', FALSE);
INSERT INTO people (name, id) VALUES ('Edsger', 3);
INSERT INTO people (id, name, active) VALUES (4, 'Barbara', DEFAULT);
```

## Columns, values and bounds

An omitted column list uses all columns in schema order. An explicit list may
reorder or omit columns; every named column must exist and appear once. Omitted
fields use the declared typed default or nullable NULL. A required field without
a default rejects. Explicit NULL never selects a default. `INSERT INTO name
DEFAULT VALUES` constructs one row entirely from defaults and nullability.

Values bind to the exact declared type, including the supported logical nested
constructors. Numeric overflow, inexact conversion, invalid temporal values,
Unicode character limits and NOT NULL violations reject. See
[CREATE TABLE](create-table.md), [data types](types.md) and the
[constant grammar](../../../../contracts/TABLE_DDL_V1.md#type-and-literal-profile).

One plan admits 1–1024 rows and a 4 MiB canonical intent. SQL text has a separate
4096-byte bound. Schema, row and logical-value budgets also apply; these bounds
limit one operation, not total Table cardinality. Without a declared primary
key, repeated row values remain separate rows with stable internal identities.

## Atomic result and recovery

The owner freezes the object, schema and source basis, validates the complete
candidate, then publishes all rows, indexes and terminal counts together.
A duplicate primary key or invalid later row cannot publish a successful prefix.
Readers see the previous Table until final publication. A send receipt proves
input admission; only the recorded terminal outcome establishes the DML result.

The result records matched and changed counts at commit. Rejections preserve the
attributed reason and available constraint witness under current disclosure
rights; they do not require rereading a possibly changed Table. A primary-key
conflict never authorizes disclosure of the existing row's other values.

The console's [SQL service](../sql-sessions.md)
saves the original intent and exact signed steps before sending. After an
uncertain response, use `.status` and `.resume`; repeating the SQL creates new
work. `.cancel` cannot undo a published operation. Saved work remains bound to
its original object and schema across ALTER, DROP and name reuse.

`INSERT ... SELECT`, `ON CONFLICT`, other upsert forms and `RETURNING` are
unsupported. Inserting rows does not dispatch a sink effect or establish a SQL
transaction session. The [DML contract](../../../../contracts/TABLE_DML_V1.md) owns
compilation; the [catalog owner](../../../../packages/zig/transit-catalog/docs/table-metadata.md)
owns authorization, staging, atomic publication and exact recovery.

See also [UPDATE](update.md), [DELETE](delete.md) and [Tables](../tables.md).
