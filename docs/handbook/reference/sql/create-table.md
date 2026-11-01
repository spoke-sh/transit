# CREATE TABLE

CREATE TABLE publishes a general typed Table in the console's configured,
authorized catalog. SQL and typed callers use the same schema, lifecycle owner
and recovery contract. Compilation does not provision resources, choose an
owner or grant permissions. Board and Flight query routes remain read-only.

```sql
CREATE TABLE people (id INT64, name UTF8);

CREATE TABLE employees (
    id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    department_id INTEGER,
    active BOOLEAN DEFAULT TRUE,
    salary DECIMAL(18, 2)
);
```

The first statement creates two nullable columns without a user primary key.
The second declares an int32 primary key and a five-column schema. Use the
[console catalog configuration](../../../../apps/transit-cli/docs/console.md#configuration-and-trust)
for remote connections; the local server supplies a catalog automatically.

## Syntax and types

```text
CREATE TABLE [IF NOT EXISTS] name (
    column_name data_type [NULL | NOT NULL] [DEFAULT constant] [PRIMARY KEY],
    ...
    [, PRIMARY KEY (column_name, ...)]
);
```

Schemas admit 1–128 columns within a 64 KiB encoded-schema budget. Names contain
1–255 decoded UTF-8 bytes. Unquoted identifiers fold ASCII case to lowercase;
double quotes preserve case and escape a quote by doubling it. Column names are
distinct after normalization.

[Types and aliases](types.md) cover signed/unsigned integers through 128 bits,
finite float32/64, decimal, boolean, UTF-8, binary, date, time, civil/UTC timestamp,
interval, UUID, struct, list, fixed array, map, tagged union and JSON. INTEGER/INT
means int32; BIGINT/INT64 means int64. VARCHAR(n) counts Unicode scalars and
rejects overlength values. Parameters are validated, never parsed and ignored.

Omitted nullability defaults to nullable. A declared primary key implies NOT
NULL; explicit NULL on a key is contradictory. Keys may be single or composite.
There is no implicit first-column key. Without a key, duplicate values have
separate stable internal row identities.

Defaults are deterministic typed constants, including the supported nested
constructors. They apply to omitted INSERT fields and DEFAULT; explicit NULL
never selects a default. Defaults must satisfy the column's type, nullability
and character limit. See the [DDL value grammar](../../../../contracts/TABLE_DDL_V1.md#type-and-literal-profile).

Primary keys admit integer, finite float, decimal, boolean, UTF-8, binary, date,
time, timestamp and UUID columns. Interval, nested values and JSON are not key
types. Keys compare canonical typed values under the declared collation.
Text defaults to `UTF8_BINARY`; `ASCII_CI`, `EBCDIC_CP037`, `EBCDIC_037_PAD`
and `EBCDIC_1047_NOPAD` are also admitted. Floating zero signs compare equal for keys.

Table-level `[CONSTRAINT name] CHECK (predicate [AND predicate ...])` supports
column/literal and compatible column/column comparisons plus `IS [NOT] NULL`.
It enforces every new write. `NOT VALID` defers existing-row validation when
added later. Names bind stable column identities after the complete declaration.
There are at most 64 constraints and 32 predicates per CHECK.

Table-level `[CONSTRAINT name] FOREIGN KEY (columns) REFERENCES parent (columns)
NOT ENFORCED` freezes the exact parent definition and primary-key columns.
Optional `ON DELETE`/`ON UPDATE` actions are recorded as staged metadata.
The declaration protects the referenced columns from incompatible changes;
it does not enforce parent-row existence or execute referential actions.
An ordinary enforced foreign key rejects rather than silently becoming staged.

## Publication and recovery

The caller needs current inspect and create rights as well as native access.
The owner reserves a never-reused object identity, stages bounded schema work,
then atomically publishes the live name, metadata, head and original outcome.
Staged bytes alone do not make the Table available. Authorized catalog SELECT
and DML resolve the published Table through the same configured owner.

IF NOT EXISTS records an unchanged outcome for an existing name. It neither
checks that the existing schema matches the proposed one nor alters or adopts
that Table. In the shared direct runtime, the unchanged outcome is a catalog
name assertion bound to that exact existing definition and the complete proposed
SQL. A definition/name change before acceptance rejects the frozen condition.
An exact retry recovers the original outcome; changed intent under
an occupied operation identity rejects. Catalog admission and native registration
are intermediate evidence; only the direct owner's applied outcome establishes
successful creation.

The SQL service saves the complete direct intent and commits its reference before
dispatch. The console checks the original request after uncertainty and reports
an unconfirmed outcome if necessary. A newly issued CREATE is new work. Current
inspection rights govern outcome and metadata reads, including after later
schema changes or name reuse.

UNIQUE, inline CHECK/REFERENCES, generated/identity columns,
CREATE TABLE AS SELECT and enforced foreign keys are unsupported.
These forms reject before mutation. [ALTER TABLE](alter-table.md),
[DROP TABLE](drop-table.md) and [typed DML](insert.md) have their own selected
profiles; storing a type does not qualify every relational operator on it.

The [Table schema](../../../../contracts/TABLE_SCHEMA_V1.md),
[DDL compiler](../../../../contracts/TABLE_DDL_V1.md) and
[catalog owner](../../../../packages/zig/transit-catalog/docs/table-metadata.md)
define exact identity, encoding, publication and ownership rules.
