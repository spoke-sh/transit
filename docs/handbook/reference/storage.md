# Storage and recovery boundary

The local server stores native history and immutable objects through the
[local backend](../../../packages/zig/transit-backend-local/README.md). Deployments
configured with Ursula use its Zig backend adapter. Transit owns
logical process/resource identities, accepted transitions, retained boundaries
and retirement. Physical streams, buckets and offsets are not an alternate
authority for execution or permissions.

## Direct Table data

The local SQL service uses the node's signed direct Table interface. The catalog
owns names and immutable definitions, while each Table has its own acceptance
partition. A complete row operation or DDL intent has one original identity and
an inspectable admitted, committed, rejected or cancelled outcome. Direct rows
are not limited by native actor frame or turn-block sizes. The
[direct interface](../../../contracts/DIRECT_TABLE_V1.md) owns request budgets,
authorization and exact-retry semantics.

Point writes can remain in retained WAL records. Bulk ingestion publishes
immutable `.tseg` objects before accepting the new Table state. A query's durable
pin protects its original interpretation and accepted frontier, including
unflushed data; independently retained Tables do not form one atomic catalog
snapshot. Read-only current observations create no pin; conditional traversal
rejects logical changes instead of preserving an earlier cut through them.
Current database/schema/Table rights apply to both paths.

Direct Table point reads use a paged key directory to select their WAL row or
immutable segment. Segment reads fetch verified footer and row-group column
ranges; the owner retains at most one footer and one bounded decoded group.
New segments use 256-row groups by default. Output rows own their values across
cache eviction, and current authorization still applies before disclosure.
Retained key-range reads seek through a separate paged full-key directory and
return bounded pages in the declaration's collation order. Their continuations
preserve the exact snapshot and interval. SQL projection and predicate pushdown
remain separate query capabilities.

The installed owner does not automatically flush point writes or expose physical
Table garbage collection. Absence of a new `.tseg` after a point write does not
imply that the write is missing: inspect its exact operation outcome and Table
data position. The [Table reference](tables.md) and
[direct owner guide](../../../packages/zig/transit-catalog/docs/direct-catalog.md)
describe the caller operations; native resource storage below has a separate
acceptance and maintenance boundary.

## Durable history and derived state

The authority accepts conditional successors into its durable history. Recovery
reconstructs committed state and required protocol evidence from that history
and validated checkpoints. Index pages and caches accelerate access; evicting a
cache does not delete logical data.

Native v1 publishes immutable state roots and uses bounded resident
pages independently of retained cardinality. That does not provide horizontal
authority throughput: the current realm journal remains a serialization point.
Do not infer cluster scaling from a growing-data test.

The current growing authority reads the latest published catalog root and loads
its immutable index pages on demand. An ordinary read does not replay the entire
application history. Root snapshots provide a consistent basis; cache capacity,
page layout and the number of native reads determine its access cost. A storage
checkpoint does not cache a SQL answer or remove the durable steps of a captured
query. These distinctions also apply when Tables or Documents materialize
application history into current state.

The native host gives admitted requests independently owned engines, provider
clients and bounded caches. Immutable reads and candidate preparation can
overlap storage I/O. The conditional realm-journal append remains the acceptance
boundary: an intervening publication conflicts rather than accepting stale
permissions, ownership or resource versions. Snapshot reservations use a short
shared registry operation and retain the global pin quotas. See the
[node limits](../../../apps/transit-node/docs/growing.md#public-surface-and-limits)
for execution-lane and memory budgets.

The [performance reference](performance.md) quantifies current small-page read
and write amplification. Catalog reads stop at namespace boundaries. Bounded tree mutation batches copy
shared paths once, and the backend stages sibling immutable pages in groups.
The catalog also shares point-read paths when counting inserted and deleted
records in a mutation batch. It reads the original immutable root and installs
the new count only after all candidate pages stage successfully.
Verified pages use a bounded LRU cache. A separate 16-record cache holds verified
immutable authority metadata so data scans cannot evict it. Its key includes the
complete catalog root; a root change invalidates the records. Native reads still
refresh authority and execute all current permission/lifetime checks. This cache
holds at most about 35 KiB of record bytes and is independent of the configured
page-cache slots. Pages and blocks first enter private immutable storage: packed
segments with Ursula, individual verified objects with the local backend.
Each backend reserves storage and makes the bytes durable before the final
authority commit. Failed staging cannot publish a partial turn. The current v1
page encoding includes opaque storage locators.
Application mutation quotas and durable payload publication bounds are unchanged.
The [workload model](workloads.md#architectural-priorities) distinguishes hot
keyed state, append-heavy history and analytical read structures; none bypass
the public authorization boundary.

Each state resource also owns a separate immutable block index. A turn can
publish up to sixteen complete blocks and 128 KiB alongside its four small
metadata mutations; each block is at most 64 KiB. Signed descriptors bind keys,
lengths and content digests. The transport carries the bytes separately, and the
authority journal retains only the signed logical request. The backend verifies
durable bytes before the root can be accepted. Captured views, retained versions
and leased snapshots resolve the block index at their original catalog cut.
Public block reads materialize a bounded batch, then validate current authority
before disclosure. Missing/corrupt data is a failure, never an absent value.

Applications and Board use public clients, not backend journals or provider
credentials. The node composes the core and backend; core remains deterministic
and independent of Ursula/provider types. Pin the consuming backend's upstream
dependency rather than embedding storage implementation details into callers.

## Failure and maintenance

A timeout can follow a successful durable mutation. Retry/reconcile the original
identity; do not initialize a new realm because the provider is unreachable.
Ordinary recovery validates the current durable state. A rolled-back provider or
old snapshot is not safe evidence for live restart, because it may predate
revocation, retirement or an external effect.

Checkpoint publication precedes authorized prefix trimming. Logical tombstones
and retained identity floors prevent reuse/resurrection after physical cleanup.
Maintenance is bounded, fenced and resumable. An acknowledged provider delete
does not establish erasure from all backups or copied application data.

Physical maintenance advances a durable storage epoch before traversing retained
roots and current read pins. A paged mark index and durable deletion intent let
it resume after interruption. Collection waits for the maximum volatile-read
lifetime and request grace, then records that elapsed time in authority before
deleting unreachable segments. Incomplete marking cannot authorize deletion.
Late uncertain creates are fenced with permanent closed stream names; their data
can be trimmed while the small fence remains accounted.

Optional compaction relocates bounded pieces of current data and indexes while
preserving logical values and resource revisions. Old roots remain independent
owners until their configured retention or pin release permits collection.
Unlimited history retains them. The [segment guide](../../../packages/zig/transit-backend-ursula/docs/pages.md)
explains allocation quotas, control reserve, configuration and provider limits.
These quotas measure reserved encoded segment bytes; provider metadata, work
ledgers, snapshots, WAL and filesystem headroom have separate costs.

The local CLI profile composes the native log and object store inside the node.
Lifecycle maintenance and accepted-floor trimming run in that owner; local
immutable-object collection and compaction are unavailable. The physical
collection and compaction mechanisms above apply to Ursula. Provider budgets,
disk headroom and trusted clock assumptions are deployment responsibilities;
an in-memory store test does not establish WAL or host power-loss behavior.
See [retention](retention.md) and [deployment](deployment.md).

The [backend package](../../../packages/zig/transit-backend-ursula/README.md) and
[storage mapping](../../../packages/zig/transit-backend-ursula/docs/storage.md) own
the journal/checkpoint layout, adapter operations, cold-store setup and recovery
requirements. A replacement provider must satisfy those same requirements.

## Four-tier storage hierarchy and `.tseg` segment architecture

The architecture distinguishes active working state, accepted history, local
read caches and immutable objects. The installed local owner uses
`LocalWal` and `LocalSegmentStore`; its direct Table path uses `TablePartition`.
The [storage package](../../../packages/zig/transit-storage/README.md) also
contains separate memtable, cache, provider and manifest-coordination components.
Their presence does not enable an installed four-tier deployment automatically.

| Layer | Components and current integration |
| --- | --- |
| Active working state | Native page/block caches and the direct Table's bounded operation work and data-index cache. `TableMemtable` is a separate component; it does not replace the installed Table owner. |
| Accepted history | `TransitLog` supplies framed, fenced history. The local native backend and each direct Table preserve their own acceptance boundaries. Explicit history readers expose accepted changes; automatic activation of computations is separate. |
| Local read cache | `NvmeCache` supplies verified range chunks as a component. The installed local owner does not configure a remote-object cache hierarchy. |
| Immutable objects | `TransitObjectStore` supplies immutable and conditional object operations. Local bulk Table ingestion creates `.tseg` objects. The S3-compatible adapter is a separate provider component; the configured local Table service does not select it. |

Exact WAL, segment, deletion-vector and manifest bytes belong to the
[storage format contract](../../../contracts/TRANSIT_STORAGE_V1.md).
[Table interpretation](tables.md#schemas-and-identities) specifies admitted
codecs/collations and the limits of query execution. A physical layout descriptor
alone does not establish decoder compatibility or an executable operator.

`PartitionLease.OccCoordinator` tests optimistic manifest rebasing as a separate
component. The installed local Table owner serializes acceptance under current
native authorization; it does not expose independent multi-process Table writers.
Conditional object publication can use process locks and synchronous I/O.
Provider adapters and component conflict tests therefore do not establish a
lock-free runtime, distributed atomicity or interchangeable durability guarantees.
The [storage analysis](../internals/storage-runtime.md#four-tier-storage-architecture-tseg-segments-and-multi-writer-occ)
explains the intended topology and its remaining integration boundaries.
