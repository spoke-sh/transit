# Immutable pages and segments

`PackedPageStore` implements the [core page interface](../../transit-core/docs/pages.md)
and immutable block storage for the native node. It borrows a provider client,
owns a bounded decoded-page cache, and owns at most one private candidate.
Provider success cannot authorize a turn: the authority journal publishes roots.

## Packed mapping

A physical location has 32 opaque bytes: an eight-byte storage epoch, a secure
16-byte candidate identity and an eight-byte record ordinal. The epoch and ordinal
are big-endian. A domain-separated hash of the authority bucket/journal and
candidate identity selects the segment stream. Identities are never intentionally
reused. Page references bind the compact `TPG1` content; block references bind
length and the block digest. Core treats placement bytes as opaque.

`begin` allocates one bounded private buffer. `stage`, `stageMany` and `stageBlock`
write canonical base64 JSON strings into that buffer and assign ordinals. Private
loads can read those frames while constructing their parent indexes. `stageMany`
accepts at most eight pages; the complete candidate accepts at most 1,024 frames
and eight MiB of normalized encoded data. These are operation bounds, not limits
on retained collection cardinality. `discard` releases the private buffer.

`finish` reserves the complete encoded allocation, including its closing seal,
in `AllocationQueue` before creating any provider segment. It makes one open
create attempt containing a JSON array. Ursula normalizes the array to records
and returns newline-delimited JSON on reads. The backend verifies exact record
coordinates and every frame in groups of at most 192 KiB, then appends one
conditional closing seal. Only a successful finish can produce a prepared
native command. Closure proves that this creator progressed beyond the create
reply and verified the full candidate. There are no automatic create retries.
A lost reply leaves discoverable, accounted storage; it cannot publish a partial
root. Exact already-accepted native retries reconcile their original receipt.

Loads never create storage. They validate the locator, coordinate, complete
canonical frame and digest. Missing or corrupt data fails. The LRU cache has
zero to 1,024 slots; eviction cannot remove durable bytes. `residentBytes` reports
its cache and active candidate buffer, excluding tree stacks, parsers, transport
buffers and temporary JSON-array framing. That framing is separately bounded by
the candidate limit. Each native execution lane owns these allocations.

`PageStore` remains a closed-stream primitive used by the page-layout comparison
proof. It stores raw compact page bytes and requires zero opaque locations. It
is not a decoder or migration path for a preceding native installation.

## Allocation ownership and quotas

The allocation ledger is a durable FIFO. Its latest record contains cumulative
data/control charges and a consumption cursor. Each reservation enqueues its
identity, encoded byte count, frame count and digest. Collection consumes one
record and conditionally carries a protected allocation to the tail. Cursor
advancement and quota release share one append, preventing double release after
lost replies or restart. No resident set grows with allocation cardinality.
Verified checkpoints permit trimming the consumed ledger prefix. Per-pass protected
byte counters distinguish current, captured, history, newer-epoch and permanent
fence ownership, in that precedence order. They describe the selected cut and
completed work; a lost carry acknowledgement can omit a diagnostic count. The
queue's conditional cumulative charge remains the quota authority after restart.

`storage.limits.bytes` bounds ordinary reserved encoded allocations;
`storage.limits.control_bytes` reserves independent capacity for control commands
and collection marks. Defaults are eight GiB and 64 MiB. The candidate limit is
configured by `storage.limits.candidate_bytes`, at most eight MiB. Quota includes
unpublished candidates and temporary mark pages. Refusal leaves accepted roots
and their receipts unchanged. Relocation uses ordinary capacity, keeping the
collection reserve separate. These counters describe segment records and seals,
not provider metadata, work-ledger records, WAL replication, snapshots or disk
filesystem allocation. Those require provider/disk quotas and headroom too.

## Root collection and relocation

`StorageCollection` persists a root cut, bounded traversal cursor, paged mark
index, allocation cursor and deletion intent in a private work ledger. A signed
`storage_fence` advances the authority epoch before marking; old prepared roots
cannot pass their publication CAS. The root set includes retained journal
catalog/policy roots and the cut's current open views and unreleased read
versions. Captured catalogs follow only their selected resource block index;
mark reuse distinguishes resource scope and ownership class. Historical closed-view
metadata does not recursively pin another historical catalog.

All marking completes before deletion. Missing/corrupt reachable bytes prevent
completion. A concurrent authorized history trim that removes an unvisited root
record aborts the pass; a later fence starts a new cut. Volatile readers receive
the maximum five-minute snapshot lifetime plus the native request bound as a
trusted-time grace period. A later accepted time fence records elapsed grace
before deletion, so hosts with an older clock fail their current check.

Protected segments are carried forward. An unreachable sealed segment gets a
durable deletion intent before provider deletion. Confirmed absence precedes
quota release. An absent or unsealed creation instead receives a permanent closed
stream-name fence and a verified retained-prefix trim. Delayed open creates
then conflict. Its data charge is released, while its bounded fence/checkpoint
charge remains owned in the queue; that name is never deleted. Restart repeats
the recorded intent, including deletion whose acknowledgement was lost.

`storage_compact` relocates one block or one tree leaf/path per signed transition.
Its cursor lives in the accepted head. It preserves logical resource revisions,
values, read versions and receipts; captured roots remain independent owners.
Only an authorized later history trim/pin release and collection can retire old
placement. `storage.maintenance.compact` enables this work before a collection;
it defaults to false. Unlimited retained history still owns old roots. Copying
current data alone cannot free that history, and may increase storage use.

The maintenance host alternates bounded storage work with lifecycle/control
scans. `storage.maintenance.collection_every_records` defaults to 1,024 allocation
ledger records. Provider delays remain subject to the maintenance operation
budget. No collection or quota pressure implicitly expires application data.

## Verification and limits

Run these in the pinned development shell:

```sh
just test::pages
just test::block-storage
just test::native-blocks
just test::storage-collection
just test::pages-cold --keys 1024 --cache 2
```

The [proof ledger](../../../../tests/README.md) records executed scopes, failures
and measurements. Page proofs retain both original and successor roots across
provider SIGKILL, checkpoint/trim and cache-free recovery. Collection proofs use
an injected trusted clock to exercise the full grace rule without wall-clock
sleep; production uses its configured UTC source. They separately check root
protection, corruption, publication fencing, relocation, actual segment absence,
late-create fencing, quota release and restart boundaries.

Ursula retains stream metadata and JSON record indexes in resident provider
state. Segment sizes bound each stream's record index; they do not establish a
whole-provider memory bound independent of retained segment count. Measure both
processes and configure provider headroom. Closed-name fences deliberately trade
small persistent metadata for safety after uncertain creation. A provider delete
or retention operation also does not prove erasure from backups, immediate WAL
space return, or completed asynchronous cold-object cleanup.
