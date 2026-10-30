# transit-catalog

`DirectCatalogRead.apply` composes read-only inspection, resource and dependency
callers for data exploration. It returns bounded pages and exact Table metadata;
lookup checks the supplied interpretation rather than accepting a changed name
binding. Its preview SQL is identifier-quoted by this owner and includes an exact
expected definition for the SQL result reader's pre-disclosure check. It neither
executes that SQL nor inspects storage on behalf of a renderer.

The catalog depends directly on the public protocol/client, Fuze and storage.
It has no Station dependency: Table declaration, authorization, acceptance and
retained reads use database owners. Named Document publication limits use the
shared data contract; application initialization retains its separate owner.

Named Tables, Streams, Queues, schemas and native KV/Document declarations, exported as
`transit_catalog`. Catalog owns names, stable identities, exact operation
bindings and dependencies. Fuze owns logical schemas and SQL/typed lowering;
`transit-storage` owns Table acceptance and retained data. Native authorization
owns roles, grants, current credentials and resource lifetime.

## Lifecycle owner

`DirectQueue.apply` composes durable enqueue, exact original claims, fenced
settlements and bounded claim pages with current catalog declarations and native
grants. Its host supplies one serialized, bounded resident slot and trusted time;
neither the time capability nor request authorization is retained. Queue work
uses the common operation namespace, so an identity cannot be reused for another
partition, intent or data kind. Claim receipt inspection and pages require
current read and acquire privileges; settlements require settle privileges.
Pages retain the original schema and payload while reporting current lease state
separately. `DirectQueueResponse` validates that attribution, observation basis,
row identities, byte budgets and exact cursor advance. The signed `queue` action
and `DirectQueueClient` expose standalone operations through the native service.
Saved work preserves the exact original mutation and payload commitment. The
local node performs bounded automatic lease expiry through catalog maintenance.
SQL, DLQ transfer and mixed transactions remain unavailable.

`DirectStreamResponse` validates exact operation attribution, pinned schemas,
ordered row identities, byte budgets and finite coverage. Pages carry the
original source declaration, including after a later ALTER or DROP.

`DirectStream.apply` composes Stream append, original-operation inspection,
finite reads, consumer assignment and offset settlement with the current catalog
declaration and native grants. The embedding host supplies a serialized owner
slot, private cursor authority and trusted time source. Bounded recovery returns
explicit incomplete progress before any new mutation executes. Request proofs,
scratch allocations and time callbacks never remain in the cached owner;
returned pages own their encoded rows and expose deterministic cleanup.
Group reads recheck acquire rights on every cursor/page disclosure, and original
read closure survives later policy revisions and DROP. The signed `stream`
action and `DirectStreamClient` expose these operations through the local node.
Bounded `wait` selects one finite consume cut or returns a timeout without
accepting a read. The host owns register/recheck notifications and an absolute
deadline; accepted identity remains the original consume request. SQL execution
is unavailable.

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
on its own. Queue declarations and blocked items retain exact historical DLQ
definitions, including their own destination dependencies. A separate bounded
work item resolves each immutable definition; current names or later revisions
cannot substitute for the recorded identity. Missing or invalid destinations
refuse closure. See [direct-data collection](../transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection)
for invocation, bounded work and permanently retained namespaces.

`DirectResourceClient` uses the same directory for named native KV and Document
objects. Its saved bindings separate admission, caller-authorized allocation,
writer initialization and completed publication. The
[named resource guide](../transit-station-app/docs/named-resources.md) explains
permissions, interpretation, partial outcomes and explicit cleanup.

`DirectLogClient` provides typed Stream/Queue preview, admission, bounded
execution, inspection, ALTER, RENAME and DROP. CREATE reserves its stable object,
name and partition range privately; one execution step verifies one partition's
genesis. The catalog publishes the definition only after all partitions and native
permission registration are complete. Exact retries retain that allocation.
ALTER changes retention, operation limits and compatible Queue policy; schema,
partition count, routing, key and ordering changes reject before admission.
DROP hides the live name and preserves original operations and definitions.
DLQ references bind an exact compatible Queue definition and add dependency edges
in the publication record. Edges remain retained until the Queue closure owner
can establish safe removal. The storage graph follows original intents,
declarations and every initialized partition, including cancelled work.
These lifecycle operations do not yet append or claim payloads or implement SQL
Stream/Queue verbs. See the [wire contract](../../../contracts/DIRECT_TABLE_V1.md#stream-and-queue-lifecycle).

`DirectDependency` records exact-definition dependencies with bounded inspection
and DROP RESTRICT. Registering an edge neither activates its dependent nor pins
Table data. `NameAssertion` records conditional unchanged/rejected/cancelled DDL
outcomes without inventing a Table mutation. Both preserve their original
operation identity through retries and name reuse.

## Callers and policy

`LogAuthority` defines the Stream/Queue action masks over separate native
domains: inspect, read, append, acquire and settle. It shares database CONNECT,
schema USAGE/CREATE and ownership checks with `TableAuthority`; it stores no
grants. The current configuration requires all five domain identities, including
Stream and Queue. Lifecycle publication uses these domains and the existing
native registrar, with the caller's rights checked at every publication boundary.
`DocumentAuthority` similarly defines direct Document action masks (`inspect`,
`read`, `mutate`, `checkpoint`, `administer`) and domain-separated authorization
bindings, while `DirectStorageGraph` enumerates retained `DocumentPartition`
declarations, states, payloads, operation evidence, live read bases, and
recovery checkpoints.

`DirectTableClient` signs typed requests with the caller's current credential and
selected role. The node checks database CONNECT, schema USAGE, the required
Table action or ownership, and its resource lifetime. It checks accumulated
requirements again before disclosure. Metadata is filtered by current visibility;
a saved binding, pin or cached result never grants access.

Callers that have already observed their signing credential epoch can supply
`DirectTableClient.credential_epoch` to avoid another identity lookup for each
signature. The node still authenticates every claim against the current epoch
and privileges. A stale epoch rejects; the client never refreshes or replays an
operation implicitly. Leave it null to acquire the epoch before signing.

`DirectClientToken.bind` records an account/token's original staged Table intent
in the catalog WAL; `lookup` recovers it after a lost reply. Matching fingerprint
retries return the first accepted intent under current rights. Binding does not
admit or execute data. See the
[token contract](../../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings)
for identity, quota and uncertainty rules. SQL account recovery uses these
Catalog records independently of Station.

`DirectTransaction.Reference` binds a begin descriptor through that token owner.
Acceptance reserves one coordination partition and preserves it across lost
replies and retries. The paged selection remains a descriptor: this operation
does not acquire a common cut or execute a transaction. Its limits and current
execution boundary are specified in the token contract.

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
