# CREATE KV

Direct Data Plane SQL sessions (`transit console`, native SQL sessions, PostgreSQL
and MySQL wire adapters) execute `CREATE KV`, `ALTER KV`, `DROP KV`, `PUT INTO`,
`GET FROM`, `DELETE FROM ... KEY`, `SHOW KVS`, `SHOW KV` and `DESCRIBE KV`
through the shared direct Catalog and `KVPartition` owner without a writer PID
or Station actor turns. Fuze's Zig `Declaration.compile` also validates the single-type
`CREATE KV name (data_type)` form as an offline definition.

## Syntax

```text
CREATE KV [IF NOT EXISTS] name (data_type [NULL | NOT NULL]);
ALTER KV name RENAME TO new_name;
DROP KV [IF EXISTS] name [RESTRICT];

PUT INTO name KEY key_operand VALUE value_operand [IF ABSENT | IF PRESENT];
PUT INTO name VALUES ((key_operand, value_operand) [, ...]) [IF ABSENT | IF PRESENT];
GET FROM name KEY key_operand;
DELETE FROM name KEY key_operand;
DELETE FROM name KEYS (key_operand [, ...]);

SHOW KVS;
SHOW KV name;
DESCRIBE [KV] name;
data_type := INT64 | BIGINT | BOOL | BOOLEAN | UTF8 | TEXT | BINARY | BYTEA
           | ROW (field_name field_type [NULL | NOT NULL] [, ...])
```

`name` is an identifier. Value nullability defaults to `NOT NULL` when omitted.
Keys are non-empty UTF-8 strings (`'key'`) or binary hex literals (`X'...'`,
`'\x...'::bytea`) of 1–1,024 bytes.
`ROW` (also spelled `STRUCT`) admits 1–64 ordered logical fields. Fields default
to nullable and preserve nested `VARCHAR(n)` character limits. Row literals are
supported; whole-row SQL parameters are unsupported.

## Examples

```sql
CREATE KV settings (UTF8);
CREATE KV counters (INT64);
CREATE KV sessions (ROW (identity_id VARCHAR(64), revoked BOOLEAN NOT NULL));
PUT INTO sessions KEY 'example' VALUE ROW('identity', FALSE) IF ABSENT;
```

Direct catalog sessions also accept explicit nullability, point-keyed workload verbs and inspection forms:

```text
CREATE KV settings (UTF8 NOT NULL);

PUT INTO counters KEY 'requests' VALUE 1 IF ABSENT;
PUT INTO counters KEY 'requests' VALUE 2 IF PRESENT;
GET FROM counters KEY 'requests';
DELETE FROM counters KEY 'requests';

SHOW KVS;
SHOW KV counters;
DESCRIBE KV counters;
```

## Meaning and current interface

The declarations and point-keyed workload verbs operate on a typed [KV object](../state.md)
backed by the [direct KV API](../../../../packages/zig/transit-catalog/docs/direct-kv.md):
explicit catalog declaration, atomic put/remove batches, point reads and retained
pins over `KVPartition` and current KV policy without a writer PID. Conditional
`IF ABSENT` and `IF PRESENT` writes reject when the target key's presence does not
match the condition. `GET FROM <kv> KEY <k>` returns zero or one `(key, value)` row.

Native private state used by Station retains its own resource and turn contract.
[Growing client operations](../../../../packages/zig/transit-client/docs/growing.md)
and [application installation](../applications.md#installation-and-bootstrap)
provision that state. Unified SQL's native KV source still needs an explicitly
declared decoder and schema; it does not implicitly query named direct KV.
See [query source profiles](../queries.md#source-declarations).
The [offline declaration contract](../../../../contracts/STATE_DECLARATION_V1.md)
defines owned names, complete-input validation, canonical formatting and bounds.

Source: [`createKv`, `dataType`](../../../../contracts/sql/TransitExtensions.g4).
