# Historical catalog selection

`AS OF SNAPSHOT` selects an explicitly retained catalog and its Table data cuts
before the SQL service resolves names or compiles columns and comparisons.
Acquire the catalog through the public Zig `DirectHistory` operations, then use
`DirectHistory.Selector.encode` on its published `DataLifecycle.Snapshot`.
Acquisition, publication and release are separate operations; SQL does not
silently acquire or release this retention.

## Syntax

```text
SELECT ... [LIMIT ...] AS OF SNAPSHOT 'selector';
DESCRIBE table_name AS OF SNAPSHOT 'selector';
SHOW TABLES AS OF SNAPSHOT 'selector';
EXPLAIN SELECT ... AS OF SNAPSHOT 'selector';
SELECT ... AS OF SNAPSHOT 'selector' IN SCHEMA schema_name;
```

The suffix applies to the entire statement. Its optional `IN SCHEMA` resolves
that schema's name inside the selected catalog before resolving any Table name.
It applies to SELECT, SHOW TABLES, DESCRIBE and EXPLAIN. A live schema rename or
reuse of its old spelling cannot redirect this lookup. Without it, the session's
stable namespace ID is used. This is a Transit extension, not a temporal clause.

`selector` must be the exact
594-character lowercase hexadecimal value produced from a published snapshot.
The grammar checks its placement; the SQL service verifies its canonical shape,
current Transit definition, actual publication and current access.

For example, replace the placeholder string with your published selector before
submitting this statement:

```sql
SELECT id FROM items AS OF SNAPSHOT 'selector';
```

The snapshot is a selected set of Tables, not complete database history.
Names, stable object/column identities, schemas, defaults and collations come
from that selection. After a live rename or name reuse, the old spelling still
resolves to the selected original object. A column added later is absent.
Unsupported or unavailable selections fail; they never fall back to live data.

## Results and access

SELECT uses the retained Table pins, including accepted rows that had not yet
been flushed when selected. Its observation reports the snapshot identity and
each source's exact definition, data position and schema commitment. Independently
selected Tables are explicitly `independent`; no cross-Table atomicity follows.
A snapshot transferred from an acquired transaction reports `common_transaction`
and that original cut's operation, acquisition position and source commitment.
It owns independent retention, so completing the transaction does not release it.
Physical maintenance does not change a result's observation or permit restarting
it against a newer cut.

SHOW, DESCRIBE and EXPLAIN carry catalog metadata observations. They require
current metadata rights on original objects; SELECT additionally requires current
row access. Retained grants and possession of a selector confer no permission.
Disclosure checks apply again to buffered and repeated batches and completion.
EXPLAIN compiles metadata without acquiring data pins or executing the plan.

Prepared statements preserve the same selector on every execution. Closing a
result releases local computation, while the separately retained catalog remains
available until explicit release. Release first blocks new historical reads,
then performs bounded pin cleanup under its original operation identity.
A timeout does not release retention or establish a rejected acquisition.

Explicit Table source sessions also accept this selector. Interactive reads use
the selected pin. Captured execution freezes the complete source descriptor and
any explicit projection target before admission, then copies the exact pin into
its own operation. A lost copy reply recovers that same identity. Once the copy
is accepted, releasing the original selection or replacing a live definition
cannot change the computation or its retained result. Release before acceptance
fails explicitly. Closing an interactive read does not release the selection.

The current profile rejects historical writes, active transaction composition,
KV/Document query-source selection and unselected objects. Historical graph/foreign execution,
branch/tag convenience selectors and temporal-table queries require their own
qualified owners. `FOR SYSTEM_TIME AS OF` remains reserved for temporal semantics;
the former reference-only integer fragment has been removed. An LSN, resource
revision or timestamp cannot substitute for a catalog snapshot.

See the exact [historical catalog contract](../../../../contracts/HISTORICAL_CATALOG_V1.md),
[retained-read contract](../../../../contracts/READ_VERSIONS_V1.md) and
[query reference](../queries.md). The reference grammar owns `snapshotClause`;
`transit-sql.HistoricalSql` owns production selector decoding.
