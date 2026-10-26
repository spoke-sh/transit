# Native physical maintenance

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
The [proof ledger](../../../../tests/README.md) distinguishes executed disk cases
from process-death and broader failure schedules. Automatic installed collection
triggers and public progress observations remain separate from this component API.
