# SHOW

`SHOW` inspects registered settings, authorized catalog names and Table storage
progress. The console and configured PostgreSQL/MySQL gateways support the forms
below. Query-only inspection retains its single-source Table scope.

```sql
SHOW ALL;
SHOW ports.gateway;
SHOW query.statement_timeout;
SHOW DATABASES;
SHOW SCHEMAS;
SHOW TABLES;
SHOW STORAGE FOR items;
```

`SHOW ALL` returns setting name, value and description; an exact dotted key
returns one value, and an unknown key fails. [Settings SQL](settings.md) exposes
typed metadata, source information, session controls and reload history.
Console `.show` retains its separate connection/presentation settings.

`SHOW DATABASES` lists authorized bindings admitted by the endpoint. The local
console has one selected database. `SHOW SCHEMAS` lists visible schemas in that
database. `SHOW TABLES` lists Tables in the configured catalog when
`writes.catalog` is present, otherwise names in the query-source scope. These
listings do not expose a realm-wide catalog. Each page uses current authorization.

Within query-source scope, `SHOW TABLES` returns zero or one names: the configured
name when it identifies a typed Table, otherwise an empty list. Native
source/requester access and query policy must permit the declaration before and
after metadata is assembled, including empty listings. The result carries
metadata revisions and declaration/schema fingerprints and acquires no data
snapshot. See the [inspection contract](../../../../contracts/SQL_INSPECTION_V1.md).

Catalog Table listings use current inspection policy and native reads, with at
most eight definitions per page. Continuation requires an unchanged resource
revision; discard partial output after a conflict. The console's existing Table
JSON route emits `catalog_page` envelopes with full-width IDs as decimal strings;
DATABASES and SCHEMAS emit name rows. The SQL adapters emit typed name rows. The
[catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns enumeration.

## Table storage progress

`SHOW STORAGE FOR name` returns one typed row for a Table in the selected
database and schema. It uses the same authorized
[direct storage observation](../../../../contracts/DIRECT_TABLE_V1.md) as typed
callers. It does not flush rows, acquire a snapshot or change retention.
Every execution observes current storage facts, including execution of a
previously prepared statement. Repeat fetches retain that result's original
values. Current metadata-inspection authority applies before preparation and
disclosure, including repeated and terminal responses. A changed Table definition
invalidates the prepared statement.

| Columns | Meaning |
| --- | --- |
| `object`, `schema_revision`, `partition` | Table identity in the selected catalog, exact definition revision and acceptance partition |
| `accepted_lsn`, `changed_lsn`, `live_rows` | Exclusive accepted frontier, last logical-change position and current logical row count; physical maintenance can advance acceptance without changing logical data |
| `pending_rows`, `pending_bytes`, `pending_complete`, `oldest_pending_lsn` | WAL-backed row backlog at that frontier; inspection counts at most 1,024 pending rows with bounded manifest lookahead, so incomplete counts are lower bounds. Bytes describe encoded rows, not allocated filesystem space. The oldest position is NULL when no rows remain pending |
| `archive_through`, `recovery_through`, `history_floor` | Accepted archive coverage, nullable recovery-checkpoint coverage and logical history floor; physical trimming and logical expiry remain distinct |
| `next_segment` | Exclusive next segment identity, not a count of existing files |
| `archive_source_lsn`, `archived_source_lsn` | Activity eligible for archival and its completed frontier |
| `archive_target_source_lsn`, `archive_target_through_lsn` | Nullable activity and fixed acceptance cut of unfinished archive work |
| `compaction_source_lsn`, `compacted_source_lsn` | Activity eligible for compaction and its completed frontier |
| `compaction_target_source_lsn`, `compaction_target_before_segment`, `compaction_target_after_segment` | Nullable activity, exclusive segment boundary and resumable progress of unfinished compaction |

Numeric fields are unsigned 64-bit values; `pending_complete` is Boolean. The
result identifies its exact definition and declares independent metadata
observations. Its accepted frontier is an observation, not a retained read pin.
It contains no backend path, quota total or inferred failure reason. Use registered
`SHOW storage.maintenance.flush.rows`, `SHOW storage.maintenance.flush.bytes`
and `SHOW storage.maintenance.flush.age_ms` settings to inspect configured flush
thresholds where the endpoint exposes server configuration. Accepted point rows
can remain in the WAL until eligible flushing publishes a segment; a missing new
`.tseg` file after one INSERT does not imply that its accepted row was lost.

This statement requires a direct catalog session. Query-source-only inspection
and Flight SELECT interfaces do not accept it. Names are single identifiers in
the selected schema; there are no namespace arguments or result filters.

Connector catalog forms remain reference grammar only:

```sql
SHOW SOURCES;
SHOW SINKS;
SHOW CONNECTIONS;
```

There are no SHOW filters, namespace arguments, LIKE, WHERE or pagination clauses.
Use the settings relation for filters. SHOW DOCUMENTS, SHOW KV and SHOW GRANTS
have no implemented listing. Flight SQL retains its separate Table metadata and
SELECT interfaces and does not accept these inspection statements.

Source: [`showStatement`, `catalogKind`, `settingKey`](../../../../contracts/sql/TransitExtensions.g4).
