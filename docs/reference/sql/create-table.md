# CREATE TABLE

**Grammar only.** This statement describes a typed Table schema. Query interfaces
reject it; it does not provision a resource, choose a writer, establish grants
or register a query source.

## Syntax

```text
CREATE TABLE name (column_name data_type [nullability] [, ...]);
data_type   := INT64 | BOOL | UTF8 | BINARY
nullability := NOT NULL | NULL
```

At least one column is required. Names are identifiers. Each column has one of
the four listed types and can omit nullability or spell `NULL` or `NOT NULL`.
The grammar defines no default-nullability policy or runtime provisioning rules.

## Examples

These examples illustrate syntax only:

```sql
CREATE TABLE items (id INT64 NOT NULL, value INT64 NULL);
CREATE TABLE events (id INT64 NOT NULL, label UTF8, active BOOL, body BINARY);
```

The wider schema in the second example does not establish executable Table DDL.
The production Table v1 query profile still uses its declared two-column schema;
query v1's wider query schema does not implement this creation statement.

## Meaning and current interface

The form is a relational spelling of typed Table creation. Actual
[Tables](../tables.md) are Station state over a resource, with explicit writer
ownership, current grants and bounded mutation batches. Schema declarations do
not expand the atomic commit boundary across resources.

Use the [Station APIs](../station.md) or an application's
[installation declaration](../applications.md#installation-and-bootstrap) to
configure supported state. A query source remains an explicit separate declaration.

Primary keys, defaults, uniqueness, foreign keys, generated columns, `IF NOT EXISTS`
and `CREATE TABLE AS SELECT` are outside this grammar. It does not detect
duplicate column names or impose the production model's schema bounds.
`ALTER TABLE` and `DROP TABLE` are also absent. Bounded [INSERT](insert.md),
[UPDATE](update.md) and [DELETE](delete.md) use an explicitly configured Table
writer; their availability does not make this creation statement executable.

Source: [`createTable`, `columnDef`, `dataType`, `nullability`](../../../contracts/sql/TransitExtensions.g4).
