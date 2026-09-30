# CREATE TABLE

**Catalog execution and offline compilation.** Fuze's `Declaration.compile`
validates this statement as a typed definition and formats it for review. The
[catalog helper](../../../packages/zig/transit-catalog/README.md) can create a
compatible empty Table and publish its named definition in an application's
authorized Station turn. Shared Zig and
[C ABI/native-port callers](../../../packages/zig/transit-station-bindings/docs/catalog.md)
submit to an explicit
[`catalog` host](../../../apps/transit-query-host/README.md) or application
integration. Query interfaces reject the statement. CLI, Board and
idiomatic language SDKs have no administrative route for it. Neither compilation nor the
helper provisions a native resource, chooses a writer, grants access or registers
a query source implicitly.

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

`Model.CreateTable.compile` produces the owned request for `Catalog.createTable`.
It binds realm/resource/catalog scope, operation and object IDs, a physical Table
ID, the normalized name and complete two-column schema. An explicitly initialized
catalog checks current create policy, refuses existing names/objects/Tables and
proposes four atomic writes: Table descriptor, immutable definition, name binding
and attributed receipt. Exact retries recover the original outcome; changed intent
under the same operation ID rejects. A private result is not committed until the
native turn succeeds. The [catalog contract](../../../contracts/DECLARATIVE_CATALOG_V1.md)
defines policies, conflict outcomes, bounded inspection and recovery responsibilities.
The shared Zig `Client` can prepare and submit that request to an explicitly
integrated catalog application, preserve its exact signed send across caller
replacement, and inspect its attributed outcome under current rights. A send
receipt establishes admission; publication requires an applied catalog receipt.
The supplied catalog host requires explicit native provisioning, initialization
and grants. It does not enable the query console or infer query/mutation policy.

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
writer; creating a catalog Table does not enable those routes implicitly.

Source: [`createTable`, `columnDef`, `dataType`, `nullability`](../../../contracts/sql/TransitExtensions.g4).
