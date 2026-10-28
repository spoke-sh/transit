# transit-catalog

The catalog depends directly on the public protocol/client, Fuze and storage.
It has no Station dependency: Table declaration, authorization, acceptance and
retained reads use database owners. Named Document publication limits use the
shared data contract; application initialization retains its separate owner.

Named Tables, schemas and native KV/Document declarations, exported as
`transit_catalog`. Catalog owns names, stable identities, exact operation
bindings and dependencies. Fuze owns logical schemas and SQL/typed lowering;
`transit-storage` owns Table acceptance and retained data. Native authorization
owns roles, grants, current credentials and resource lifetime.

## Lifecycle owner

`DirectCatalog` composes paged metadata directories with independent Table logs.
DDL admission reserves its original name and intent. A Table acceptance record
makes a definition visible; catalog settlement records completion without
inventing another data commit. Row operations use the Table's own operation
index. A rejected or interrupted statement never exposes a successful prefix.

The local node exposes this owner at signed `/table/v1` when configured with a
catalog and registrar. The local server, SQL runtime, query consumers and catalog
SDKs use these operations. See the [direct catalog guide](docs/direct-catalog.md)
for initialization, ownership, authorization, storage bounds and recovery.

`DirectCatalogRoots` enumerates every control record through one accepted cut,
checking its complete hash chain and final root with the recovery decoder.
Each step owns one bounded record and preserves its cursor on failure. Catalog
recovery still reads historical directories, so a latest-root-only inventory
cannot authorize their reclamation. This traversal supplies retained roots and
actions; the storage maintenance owner must follow their object dependencies.
`DirectCatalogWalk` verifies one directory through a fixed depth cursor and
emits its pages and original Table seed declarations. Object entries retain
their catalog identity and allocation frontier; their seed remains a dependency
even after a later Table definition becomes current.

`DirectStorageGraph` supplies typed retained dependencies to the local backend's
resumable collector. It joins these catalog roots with Table history/recovery,
live snapshots, original receipts and intents. Durable work/marks and physical
deletion stay in the backend; this graph grants no read or deletion authority
on its own. See [direct-data collection](../transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection)
for invocation, bounded work and permanently retained namespaces.

`DirectResourceClient` uses the same directory for named native KV and Document
objects. Its saved bindings separate admission, caller-authorized allocation,
writer initialization and completed publication. The
[named resource guide](../transit-station-app/docs/named-resources.md) explains
permissions, interpretation, partial outcomes and explicit cleanup.

`DirectDependency` records exact-definition dependencies with bounded inspection
and DROP RESTRICT. Registering an edge neither activates its dependent nor pins
Table data. `NameAssertion` records conditional unchanged/rejected/cancelled DDL
outcomes without inventing a Table mutation. Both preserve their original
operation identity through retries and name reuse.

## Callers and policy

`DirectTableClient` signs typed requests with the caller's current credential and
selected role. The node checks database CONNECT, schema USAGE, the required
Table action or ownership, and its resource lifetime. It checks accumulated
requirements again before disclosure. Metadata is filtered by current visibility;
a saved binding, pin or cached result never grants access.

`DirectTableBridge.Session` owns one immutable local intent. SQL `compile` and
typed `prepare` return saved work; `load` and `forget` are local operations.
Persist saved work before staging, and the complete returned reference before
admission. Inspect, execute and cancel that original reference after any uncertain
response. Destroying a handle does not cancel work or release durable pins.
The [catalog caller guide](../transit-station-bindings/docs/catalog.md) specifies
neutral values, the ABI/port and independent ownership of results.

`DirectTablePreparedDml` and `DirectTablePreparedDdl` bind typed templates against
current rights and exact interpretations. `DirectTableTyped` shares pure
`TableLowering` with Station's private application Table bindings.
`DirectAuthorizationSql` uses `AuthorizationLowering` to prepare reviewable native
policy changes; compilation publishes no policy. Namespace controls use the same
catalog owner and reject stale definitions.

`DirectCatalogInspection` returns bounded pages with at most eight entries.
Cursors bind connection, selection and directory position. Table data positions
are independently observed; the directory cursor is not a transaction snapshot.
`DirectCatalogRetention` explicitly acquires, inspects and releases exact retained
cuts, including accepted unflushed data and the original schema after DROP.

`DirectTableDiagnostic` keeps failed attempts distinct from observed outcomes.
A failure after dispatch preserves unknown outcome and the saved operation
identity even if final disclosure was denied. It never supplies permission to
replace work. [Metadata and recovery](docs/table-metadata.md) connects these
operations to their contracts.

## Checks

From the pinned development shell:

```sh
(cd packages/zig/transit-catalog && zig build test)
just test::direct-table-service
just test::catalog-growth
```

Component schedules exercise real catalog transitions with bounded caches.
The [proof ledger](../../../docs/history/qualification/README.md) separately records disk recovery,
public caller, installed language and deployment qualification.

`DirectTableReader.readRange` traverses an explicitly retained Table in full-key
collation order with bounded owned pages. Optional inclusive/exclusive bounds and
continuations retain the exact source and interval. Range reads leave sequential
scan coverage unchanged; callers explicitly release their pins. See the
[retained read contract](../../../contracts/DIRECT_TABLE_V1.md#retained-reads-and-binary-payloads)
for bounds, current authorization and historical-lease limits.
