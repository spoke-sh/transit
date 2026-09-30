# CREATE TABLE

**Offline compiler; no publication.** Fuze's Zig `Declaration.compile` validates
this statement as a typed definition and formats it for review. Query interfaces
reject it; it does not provision a resource, choose a writer, establish grants
or register a query source. CLI, Board and language SDKs have no administrative
route for this declaration.

## Syntax

```text
CREATE TABLE name (column_name data_type [nullability] [, ...]);
data_type   := INT64 | BOOL | UTF8 | BINARY
nullability := NOT NULL | NULL
```

At least one column is required. Names are identifiers. Each column has one of
the four listed types and can omit nullability or spell `NULL` or `NOT NULL`.
The compiler preserves omitted nullability as `unspecified`; it chooses no
default-nullability policy or runtime provisioning rules. It accepts one to eight
columns with distinct normalized names. The reference grammar itself has no
column count bound or duplicate check.

## Examples

These examples compile as offline definitions:

```sql
CREATE TABLE items (id INT64 NOT NULL, value INT64 NULL);
CREATE TABLE events (id INT64 NOT NULL, label UTF8, active BOOL, body BINARY);
```

The wider schema in the second example does not establish executable Table DDL.
The production Table v1 query profile still uses its declared two-column schema;
query v1's wider query schema does not implement this creation statement.

`Definition.tableSchema()` accepts only exactly two columns: an explicitly
`INT64 NOT NULL` first column and an explicitly nullable second column. It maps
the first column to the existing immutable primary key and returns the shared
Table schema. The first example passes this check; the second does not. Omitted
nullability, a non-int64 or nullable key, and a non-null value column reject this
conversion. The adapter still needs an authorized resource, writer and Table ID.
See the [offline declaration contract](../../../contracts/STATE_DECLARATION_V1.md)
for canonical formatting, bounds and errors.

## Meaning and current interface

The form is a relational spelling of typed Table creation. Actual
[Tables](../tables.md) are Station state over a resource, with explicit writer
ownership, current grants and bounded mutation batches. Schema declarations do
not expand the atomic commit boundary across resources.

Use the [Station APIs](../station.md) or an application's
[installation declaration](../applications.md#installation-and-bootstrap) to
configure supported state. A query source remains an explicit separate declaration.

Primary keys, defaults, uniqueness, foreign keys, generated columns, `IF NOT EXISTS`
and `CREATE TABLE AS SELECT` are outside this grammar.
`ALTER TABLE` and `DROP TABLE` are also absent. Bounded [INSERT](insert.md),
[UPDATE](update.md) and [DELETE](delete.md) use an explicitly configured Table
writer; their availability does not make this creation statement executable.

Source: [`createTable`, `columnDef`, `dataType`, `nullability`](../../../contracts/sql/TransitExtensions.g4).
