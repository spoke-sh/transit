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
settlements, bounded claim waits and pages with current catalog declarations and native
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
SQL Stream/Queue statements and automatic DLQ transfer scheduling remain unavailable.

`DirectLogIntent` freezes complete Stream/Queue declaration work in an immutable,
account-scoped record before caller-token acceptance. The Catalog verifies the
body, current declaration rights and original operation reservation. Exact token
recovery resumes the existing declaration owner without resolving a new name or
recompiling a proposal. Accepted work remains pending through incomplete partition
initialization; only the owner's actual terminal observation permits settlement.

`DirectLogPreparedDdl` binds the shared `LogDdl` compiler to current Catalog
metadata and resolves named DLQ references to exact definitions. Native preview
checks current declaration and destination rights before staging.
`DirectLogClient.requireCurrent` revalidates a cached named definition for SQL
metadata and prepared declaration disclosure.

Typed transactions can select Stream/Queue partitions as read dependencies
alongside Table/KV state. The common cut retains original log pins, checks
current READ rights and validates logical frontiers for serializable completion.
Read-only completion preserves its old cut after later writes. Typed log
statements share state statements' sequence, pending slot and savepoints. Their
paged action directories compose append, authenticated offset commit and fenced
ACK and paired dead-letter transfer with Table/KV changes in the common decision.
Transfers reserve both operation identities, open one temporary Queue owner at a
time, verify the original source row against the destination encoding, and check
current source and destination rights. `DirectTransactionClient`
exposes staging, admission, evaluation and original outcome inspection. Prepared
data verification traverses the owning graph with a metered depth-first stack;
the final lease/retention check uses trusted host time immediately before the
decision. Ordinary mutation cannot reuse a private operation reservation, while
read-only operation lookup can disclose its actual receipt after commit.

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

`DirectBranch` creates named immutable branches of one explicitly selected
Table through signed or typed direct calls. `DirectCatalog` reserves the name
and original client token, acquires the exact Table pin and publishes the head
and terminal result together. Reads retain unflushed rows and the original
schema while the source advances; current source authorization still applies.
Cancellation durably releases unpublished preparation. See the
[installed branch contract](../../../contracts/BRANCH_V1.md#installed-immutable-table-branches)
for recovery, retention, caller ownership and profile limits.

`BranchLifecycle` and `BranchMergeRestore` are bounded in-memory models outside
the direct catalog execution path. Their stored cuts borrow caller data;
`validateAndPublishThreeWayMerge` additionally requires caller-owned `MergeRows`
that remains alive and unchanged while any cut refers to it. Exact request
digests reject changed-content token reuse, and receipt capacity is checked
before head movement. Schema-only promotion with a changed schema refuses until
an explicit conversion exists. These helpers provide no disk recovery, atomic
catalog/data publication, retention pins, remote transfer or measured latency.

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

`DirectKVClient` declares and accesses [named direct KV](docs/direct-kv.md) over
`KVPartition`, without a writer PID. `DirectResourceClient` uses the same directory
for named native Document objects. Its saved bindings separate admission, caller-authorized allocation,
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
grants. The current configuration requires all six domain identities, including
Stream, Queue and KV. Lifecycle publication uses these domains and the existing
native registrar, with the caller's rights checked at every publication boundary.
`KVAuthority` separates metadata inspection, value reads and writes, with
CONNECT, USAGE/CREATE and native ownership checks. Its registered domain is
required even before direct KV lifecycle operations are enabled.
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

`HistoricalCatalog` supplies pure, borrowed historical-cut validation and query
fixtures. Its digest includes the complete supplied cut: schemas, interpretation
profiles, constraint and dependency descriptors, column origins, segments and
rows. `HistoricalTimeline.publishHeadConditional` accepts a caller-owned complete
successor sequence, verifies the retained prefix, and updates both the sequence
and its head. The caller must keep that sequence immutable and alive. This helper
performs no WAL publication, synchronization or durable retention; those remain
with `DirectCatalog` and the storage owner. Segment projection inspection reuses
one segment's scratch workspace independently of segment count.

Historical helper fetches keep a row cursor within each borrowed segment and
write at most the caller's row capacity. A failed fetch leaves the cursor
unchanged. Every fetch, including terminal observation, requires current grants;
filter evaluation reports `QueryTypeError` and `QueryConflict` rather than
silently excluding those cells. These borrowed fixtures do not establish disk
paging, a SQL historical selector or runtime policy integration.

Browser declaration administration is a typed public interface in
`BrowserAdministration`: inspect a key, list an eight-entry page, conditionally
change a declaration, or prepare a publication against a live Table schema.
`BrowserDeclarations` owns provider, secret-reference, explicit native-reader
binding and generic `PublishedResource` declarations. The preparing operation
compiles the declared SELECT and records its actual source definition and output
schema; it neither publishes nor executes it. These operations do not invent
SQL declaration forms.

`BrowserRecordStore` uses public `DirectRecord` immutable bodies and
`DirectClientToken` conditional revisions. Retained identity/session cardinality
is independent of resident directories. A write carries an explicit mutation
identity and expected revision; lost replies require inspecting the original
record/history. Pending admission bookkeeping can be reconciled in bounded pages,
without dispatching an exchange. Expiry and disablement never delete accepted
history. Native owner quotas still apply. Private secret bytes stay outside these
records. Signing in confers no native privilege; bindings refer to an existing
reader's actual credential and reject the bootstrap owner/root role.
