# CREATE DOCUMENT

Direct Data Plane SQL sessions (`transit console`, native SQL sessions, PostgreSQL
and MySQL wire adapters) execute `CREATE DOCUMENT`, `ALTER DOCUMENT`,
`DROP DOCUMENT`, `SHOW DOCUMENTS`, `SHOW DOCUMENT`, `DESCRIBE DOCUMENT`, and
ordinary `INSERT INTO`, `UPDATE`, `DELETE FROM` and `SELECT ... FROM` over the
shared direct Catalog without Station actor turns. Fuze's Zig `Declaration.compile`
also validates the minimal `CREATE DOCUMENT name` form as an offline definition.

## Syntax

```text
CREATE DOCUMENT [IF NOT EXISTS] name [(column_definitions)]
  [WITH (profile = 'versioned' | 'causal_crdt', retention = 'duration' | 'unlimited')];
ALTER DOCUMENT name ADD [COLUMN] column_definition;
ALTER DOCUMENT name DROP [COLUMN] column_name [RESTRICT];
ALTER DOCUMENT name RENAME [COLUMN] column_name TO new_column_name;
ALTER DOCUMENT name RENAME TO new_name;
ALTER DOCUMENT name SET (retention = 'duration' | 'unlimited');
DROP DOCUMENT [IF EXISTS] name [RESTRICT];

SHOW DOCUMENTS;
SHOW DOCUMENT name;
DESCRIBE [DOCUMENT] name;
```

When the column list is omitted, `CREATE DOCUMENT name;` defaults to
`(id UTF8 NOT NULL PRIMARY KEY, doc UTF8 NOT NULL)` with `profile = 'versioned'`
and unlimited retention.

## Example

```sql
CREATE DOCUMENT notebook;
INSERT INTO docs (id, value) VALUES (1, 10);
SELECT id, value FROM docs WHERE id = 1;
```

Direct catalog sessions also accept typed schema, profile and inspection forms:

```text
CREATE DOCUMENT docs (id INT64 NOT NULL PRIMARY KEY, value INT64 NOT NULL)
  WITH (profile = 'versioned');
SHOW DOCUMENTS;
SHOW DOCUMENT docs;
DESCRIBE DOCUMENT docs;
```

## Meaning and current interface

Direct Document collections store structured rows and documents on the Direct Data
Plane with an explicit Document profile (`versioned` or `causal_crdt`) and
optional retention policy, while sharing typed schema validation, snapshot reads
and atomic partition mutations with the direct Catalog owner.

Profile and retention are part of the immutable definition. A pending or
cancelled `ALTER DOCUMENT` leaves the current policy unchanged; a committed
retention change advances the definition together with its policy.

The native `DirectDocument.Revision` adapter can guard a read of the versioned
row profile in a serializable common transaction. It compares the exact
definition and collection data frontier against the acquired cut; the coordinator
checks that dependency again before committing other writes. Its physical target
is the existing shared row partition. This adapter does not add SQL
`BEGIN ATOMIC`, execute installed application programs, or admit partitioned
tree Documents. See the [direct transaction contract](../../../../contracts/DIRECT_TABLE_V1.md#signed-transaction-action)
for the native boundary.

Station's collaborative [Document model](../documents.md) and typed
[named resource operations](../../../../packages/zig/transit-station-app/docs/named-resources.md)
remain separate for actor-bound replica resources. Use the
[Document service](../../../../packages/zig/transit-station-document/docs/service.md)
and [caller interface](../../../../packages/zig/transit-station-document/docs/remote.md)
for replica-assigned collaborative resources. The
[offline declaration contract](../../../../contracts/STATE_DECLARATION_V1.md)
defines owned names, complete-input validation, canonical formatting and bounds
for `Declaration.compile`.

Source: [`createDocument`](../../../../contracts/sql/TransitExtensions.g4). See also
[SELECT](select.md) and [state resources](../state.md).
