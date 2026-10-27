# Local physical maintenance

`StorageCollection` reclaims unreachable native pages and immutable blocks in
one exclusively owned local directory. Accepted native state, retained history,
live views and retained read versions continue to own their bytes. Unlimited
history remains unlimited. Table objects and independent payload objects have
separate ownership; this collector does not delete them.

Use the same `Backend`, `Store`, `PageStore` and native engine for collection.
Submit an authorized native `storage_fence`, then call `StorageCollection.start`
with its accepted record position. `current` exposes the private progress record.
Repeated `step` calls with a trusted `Time.Sample` perform bounded work:

1. Mark accepted history roots and the cut's live captured roots into a paged
   index. Each step follows at most four verified graph edges. Old closed capture
   metadata does not renew ownership. A racing history trim aborts incomplete
   marking without deleting objects.
2. Wait until the fence's upper time plus the maximum five-minute snapshot
   lifetime and sixty-second request bound. Native authority must also persist a
   time floor beyond this boundary. `CollectionTimeFenceRequired` requests that
   explicit authority transition; a newer signed `storage_fence` supplies it.
3. Examine the captured allocation FIFO prefix, carrying retained objects to its
   tail. A step examines one allocation or collapses at most 64 empty progress
   records. New epochs remain protected. Save an exact deletion intent before
   removing any unreachable old allocation.
4. Durably unpublish the descriptor, remove its immutable payload and checksums,
   remove the allocation marker and consume its FIFO entry. Repeating the intent
   after uncertainty is safe. Trim the consumed FIFO prefix after completion.

Native allocation intents enter their own segmented local WAL before any object
content is created. An exact marker makes retries identifiable. An uncertain
intent followed by a retry can leave duplicate inventory references; they retain
the same object or idempotently remove it. Accepted native epochs reject delayed
old creators. Direct data adapters reject the reserved `native/` object namespace.
The mandatory shared definition binds this allocation layout; an older directory
is incompatible and is never reset or inferred to contain current metadata.

`storage_compact` uses the native engine's bounded relocation operation. It
preserves logical values and resource revisions. An opted-in `checkpoint` and
`Store.maintain` can release earlier native log history, while current captured
versions independently protect their old roots. Compaction itself expires no
history and emits no application mutation.

Allocation records, private mark pages, FIFO progress and metadata publication
consume the owner's encoded-file quota. Eligible maintenance uses the control
reserve. Quota refusal does not authorize deletion. Reservations remain
conservative after uncertain I/O; exclusive reopen recounts actual file lengths.
Confirmed object unlinks release their byte charge immediately. Lock files and
unpublished atomic-file temporaries remain; filesystem blocks and inodes require
separate headroom. The FIFO inherits the local WAL's segment recovery/trim costs.
Its sequential cursor avoids a whole-inventory directory search per allocation.

The progress body is bounded to 256 KiB, traversal depth is bounded by the core
page-tree height, and page-cache residency is configured independently of durable
object count. Disk quota, time availability and successful I/O still determine
whether collection can finish. Byte counters report confirmed work in the current
execution and can undercount a deletion whose progress acknowledgement was lost.
They are not proof of erasure from filesystem snapshots or external copies.

Run `nix develop --command zig build test-local-native` from the repository root.
The [proof ledger](../../../../docs/history/qualification/README.md) distinguishes executed disk cases
from process-death and broader failure schedules. Automatic installed collection
triggers and public progress observations remain separate from this component API.

## Direct Table and catalog collection

Compose `DataCollection.Collector(transit_catalog.DirectStorageGraph)` with the
same local backend and native engine. Its `start`, `current` and `step` lifecycle
uses accepted native epoch/time fences and the same grace interval described
above. The storage package owns inventory and deletion; the catalog package owns
the typed Table/catalog dependency graph. The backend does not depend on catalog.

The graph retains complete catalog control history, current Table roots, the
selected recovery baseline and replay, unexpired history, live snapshots,
declarations, original receipts and admitted work. Unflushed snapshots retain
their exact WAL/archive frames. Explicit `TablePartition.expireHistory` can make
old history eligible; collection separately establishes whether remaining owners
need it. Releasing a snapshot does not expire logical history. Unknown object
namespaces, permanent operation identity reservations and saved direct-intent
references stay retained.

Four graph transitions, one inventory allocation or 64 empty inventory records
bound a step. Graph/index allocations have a 64 MiB simultaneous limit, one cached
page and an 8 MiB index-work budget per transition. Work items and progress are
bounded to 128 KiB and 256 KiB respectively; paged queues/marks permit larger
durable graphs. WAL buffers and fixed decoding buffers have separate bounds.
Directory discovery and segment verification can require substantial I/O.

An incomplete or corrupt graph cannot reach deletion. A racing required-history
trim aborts the pass; repairable I/O or quota errors preserve its last checkpoint.
After the grace and time fence, deletion holds the exclusive creation lock and
rechecks the latest allocation marker. Newer reuse and unfinished reuse intents
cannot delete another epoch's ownership. Exact pending identity and FIFO progress
survive process death. Work/mark objects use the normal quota and can themselves
be reclaimed by a later pass. An unfinished pass cannot be replaced by `start`.

Run `just test::local-data-collection` from the pinned development shell for disk
expiry, pinned reads, pending work, receipts and deletion process faults. The
signed catalog-policy composition is included in `just test::local-catalog`.
See the [storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#local-direct-data-collection)
for private formats, permanent roots and failure semantics. Automatic installed
triggers and public progress observations remain separate from these operations.
