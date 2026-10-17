# SHOW

`SHOW` inspects registered settings and authorized catalog names. The console
and configured PostgreSQL/MySQL gateways support the settings and catalog forms
below. Query-only inspection retains its single-source Table scope.

```sql
SHOW ALL;
SHOW ports.gateway;
SHOW query.statement_timeout;
SHOW DATABASES;
SHOW SCHEMAS;
SHOW TABLES;
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
snapshot. See the [inspection contract](../../../contracts/SQL_INSPECTION_V1.md).

Catalog Table listings use current inspection policy and native reads, with at
most eight definitions per page. Continuation requires an unchanged resource
revision; discard partial output after a conflict. The console's existing Table
JSON route emits `catalog_page` envelopes with full-width IDs as decimal strings;
DATABASES and SCHEMAS emit name rows. The SQL adapters emit typed name rows. The
[catalog contract](../../../contracts/DECLARATIVE_CATALOG_V1.md) owns enumeration.

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

Source: [`showStatement`, `catalogKind`, `settingKey`](../../../contracts/sql/TransitExtensions.g4).
