# `transit-backend-local`

This package persists the existing native authority engine through `TransitLog`
and `TransitObjectStore` on a local POSIX filesystem. `Backend` owns an exclusive
directory; request-owned `Store` and `PageStore` instances borrow it.
`transit-node` selects this adapter with its `local_directory` configuration;
`transit server` selects it by default. See the [node configuration](../../../apps/transit-node/docs/growing.md)
for supported operations and current maintenance/diagnostic limits.

The core engine remains the authority for permissions, sequences, ownership,
retirement, resource versions, input progress, outputs and effect intents. Pages
and blocks are staged as verified immutable objects. A single conditional WAL
append publishes the next catalog and policy roots. A lost reply remains
uncertain; reopening and resubmitting the same signed operation recovers its
existing receipt without repeating staging. Recovery does not execute effects.
`requiresRecovery` observes uncertainty in all three owned WALs under their
serialization locks. It does not clear the condition: the service must join
borrowers, close the owner and validate the original directory on reopen.
The [node lifecycle](../../../apps/transit-node/docs/operations.md) defines the
bounded replacement policy and exhausted-outcome behavior.

`PageStore` owns a configured cache of at most 4,096 pages. Durable page count
does not determine cache size. Each operation has the shared candidate byte
bound, and encoded-file allocation admission uses `Storage.Limits` with a separate
control reserve. Failed/uncertain writes conservatively retain their reservation
until exclusive reopen recounts actual files. Exhausting quota stops new staging;
it never authorizes expiry, trimming or deletion. Accounting bounds encoded file
bytes and conservative publication overhead, not filesystem block/inode usage.
Direct-data quota reservations hold the journal mutex briefly; private direct
object publication and immutable reads run outside it. Per-key disk locks serialize competing
publications, and completed object-attempt counters have a separate short lock.
Concurrent attempts that both observe a missing key can reserve twice; those
conservative reservations remain charged until reopen. Direct-object syncs therefore
do not hold up unrelated native reads or control publication through this mutex.
Device contention and the serialized WAL can still delay them.
Bounded whole-object reads forward through the same direct-key boundary and
return bytes in caller-owned output. The local provider reads the descriptor
once for both metadata and payload verification. This counts as one observed
object-read attempt; separate metadata/range calls retain their separate counts.
Publication authority, payload verification and caller disclosure fences are
unchanged.
Direct creation also records a durable key/content inventory before publication.
The private FIFO and latest per-key epoch use a separate mutex: slow inventory
syncs can delay other direct creators, but do not hold the native journal mutex.
Native and direct inventory appends check cancellation before entering their
bounded WAL publication, then defer cooperative cancellation through that one
batch of at most eight fixed-size records. Cancellation remains pending for
subsequent marker/object work. A maintenance deadline can therefore stop private
work without interrupting this shared bookkeeping commit and forcing foreground
owner replacement. The deadline still reports a timeout and joins its work;
joining may wait for the in-flight durability barrier. Actual write/sync failures
retain the original uncertainty and exclusive-recovery requirement.
Reusing existing content after a storage fence records the newer epoch, which
prevents an older inventory item from removing its latest marker. Creation holds
a shared reclamation fence until publication finishes. Inventory markers, queue
records and object files all consume the physical quota and control reserve;
even deduplicated reuse can fail quota when it requires a newer epoch record.
The exclusive live owner remembers at most 64 completed immutable publications
and their exact key, content and storage epoch. Reuse checks the current object
descriptor and epoch; a match avoids repeating already acknowledged inventory
and object synchronization. Only successful completion populates this cache.
An uncertain publication, a new epoch or owner replacement must establish all
barriers again. The creation fence excludes collection during this check, and
collection cannot reclaim allocations from the current epoch. This optimization
assumes immutable content remains unchanged during exclusive ownership, like the
verified page caches; it does not continuously detect historical corruption.
This inventory supplies no reachability or deletion authority. Its mandatory
directory is created only for a fresh current-definition installation; missing
history rejects on reopen instead of being reset.
Native and direct index-page groups contain at most eight pages. Their allocation
records and quota reservations precede content creation, and the shared creator
fence covers the complete group. The object store shares directory barriers
within that group; inventory WAL records retain their individual durability.
Partial failure produces no page references or new cached confirmations, while
retaining charged reservations and any private published objects for exact retry
and ordinary collection. Page encoders use at most eight 24 KiB buffers plus
envelopes in a separate batch stack frame; single-page staging keeps its own
frame. No stored format, acceptance decision, timeout or cache capacity changes.
The native page owner also buffers up to eight private pages across tree/path
mutations in one candidate. This fixed buffer is allocated with the owner,
separately from the configurable read cache, and is included in `residentBytes`.
Reads in that candidate can resolve its buffered children even with a zero-page
cache. A full buffer flushes through the same allocation/object publication path;
`finish` flushes the remainder before preparation returns and before any native
WAL acceptance. Discard drops only unflushed private pages. Already published
private objects retain their allocation evidence and ordinary collection rules.
File barriers within a group use at most eight concurrent tasks, joined before
name/directory publication continues, including after a sync failure. Inline
execution remains valid when the supplied I/O runtime cannot schedule tasks.
Native page/block creation likewise uses its own allocation-queue mutex and
holds a shared creation/reclamation fence until immutable publication finishes.
Only the accepted-epoch check and quota reservation take the journal mutex;
private native inventory and object syncs do not hold it. Native collection
acquires the exclusive creation fence before checking and consuming an allocation,
so a paused creator cannot publish untracked bytes after its marker is reclaimed.
Independent direct-data acceptance and native reads can progress during private
native staging. Competing native creators still serialize their inventory writes.
Native collection likewise releases the journal mutex during progress-file
publication and physical reclamation. Its separate collection, creator and
inventory locks preserve deletion order; only epoch checks and quota accounting
take the journal mutex. Slow deletion still delays native creators, while
independent direct-data acceptance and native reads can proceed.

Complete native `submit` calls acquire a separate submission mutex before
refreshing authority and staging their candidates. Cooperating request lanes
therefore avoid preparing competing copies of the same native root. Native
reads and direct Table requests never acquire this mutex. Explicit
`prepare`/`commit` callers remain optimistic and can still cause conditional
append conflicts. The mutex changes scheduling only: queued submissions check
current credentials, permissions and receipts after acquiring it, and every
candidate still requires its original conditional append. Cancellation while
waiting stages no bytes; uncertain storage writes still require recovery.

The object root requires the shared definition and a 64-byte `.native-owner`
marker (`TNOWNER1`, the 32 definition bytes, then 24 zeros), locked exclusively
for the owner's lifetime. An existing unmarked object collection rejects as a
native installation. Partition zero in `wal/` contains the native genesis and
operation records, with expected LSN, storage epoch and authorization revision
bindings. Records are bounded to 256 KiB. Current roots and exact retry receipts
are recovered from the latest accepted record.

Native objects have a 40-byte envelope: `TNAT`, byte `1`, kind byte (`p` page or
`b` block), two zero bytes, and the 32 shared definition bytes. Page bodies use
the core's `TPG1` codec; block bodies are their original bytes. Opaque locations
bind the current definition, kind, storage epoch, random candidate nonce,
ordinal and logical digest. Reads verify both the object-store integrity and
the core page/block digest. The cache holds owned pages, never borrowed buffers.

`DataStore` supplies nonzero data partitions and immutable objects to direct
data owners inside the same exclusive directory and physical quota. It checks
native storage and authorization epochs at append, under the physical owner
mutex. It does not compare the native progress position: an unrelated accepted
input does not invalidate an otherwise current Table candidate. Direct owners
still compare their own partition frontier. Table WAL trimming requires coverage
published in the latest accepted Table archive record; it preserves the last WAL
record and every required archived logical record. Objects are immutable;
physical collection has a separate retained-graph owner.

`DataCuts` walks the local nonzero partitions under an accepted native storage
fence. It fixes each partition's observed tail, then reads one frame per step
backwards to its last acceptance in an older storage epoch. Later appends cannot
extend that walk. The fixed cursor owns its fields and resumes after reopen;
each selected cut binds the frame header and full payload hash. Empty owners
and owners created after the fence contribute no older cut. Missing or trimmed
required history stops traversal. This discovery supplies neither a complete
object graph nor deletion authority; catalog and Table retained-root traversal
must account for the selected owners before collection.

`DataAuthority` authenticates the original signed subject and checks the supplied
generic native requirements. It separately verifies the catalog resource's
current lifetime, owner and dependencies through the existing state rules.
The service must bind the proof context to the complete request and choose its
requirements; the adapter cannot infer those from a row batch. A shared authority
fence covers the check and data commit/disclosure. Native publication takes its
exclusive side. Private staging holds neither side, and independent data owners
can hold shared fences together. The first successful acquisition fixes the
candidate's storage epoch. Later acquisitions recheck current permissions and
resource lifetime but preserve that epoch: a storage fence during private
staging makes publication fail with `StaleStorageEpoch`. A fresh request may
rebuild the same unaccepted operation under the current epoch; accepted retries
still resolve to their original receipt. Reads continue to check current rights
and can disclose an accepted receipt across a storage fence. Short data commits
can delay native publication;
this is a local serialization profile, not a distributed fencing protocol.

The component tests compose this guard and quota adapter with `TablePartition`,
including actual native revocation after segment staging. The
[node's public Table route](../../../apps/transit-node/README.md) uses this
adapter's request-owned guards through `LocalCatalogPolicy` for direct catalog
and Table operations, and the
[local SQL service](../../../docs/handbook/reference/sql.md) uses that same
acceptance owner. Native resource turns and direct Table mutations retain
separate commit boundaries.
Component race tests cover point/WAL and bulk/segment staging across a storage
fence, unchanged accepted roots, fresh retries and original receipt recovery.

`Store.maintain` trims only an already accepted native history floor and keeps
the latest entry. `StorageCollection` separately collects native pages and blocks
after a signed storage fence, complete retained-root marking and the snapshot
and request grace interval. Its durable allocation FIFO, paged marks and deletion
intent resume after reopen. `storage_compact` relocates bounded native data while
retained captures keep their original values. See [native maintenance](docs/maintenance.md)
for invocation, ownership, quotas and recovery. Table objects and standalone
payloads retain separate ownership; this collector does not delete them.
The node schedules native and direct collection through these component owners.
`PayloadStore` implements explicit
[standalone payload publication and retirement](docs/payloads.md) under the
existing native declarations. The local node composes them into authenticated
payload publication/read operations and opted-in maintenance deletion, with
current service authorization rechecked under the physical owner's fence.

`DataCollection.Collector(transit_catalog.DirectStorageGraph)` composes the local
allocation/deletion mechanism with complete Table/catalog dependency traversal.
It retains current data, unexpired history, live pins, recovery and original
operation evidence. Explicit history expiry and pin release can make old objects
eligible; a complete mark, native epoch/time fences and exact allocation identity
are still required before removal. Paged private work and deletion progress
resume after reopen. See [direct-data collection](docs/maintenance.md#direct-table-and-catalog-collection)
for invocation, memory limits and permanent saved-intent ownership.
Each marking step reuses one eight-page immutable batch buffer within its
existing 64 MiB memory budget. Each bounded graph unit flushes its private index
pages before the collection checkpoint can publish their roots. Partial staging
failure preserves the prior checkpoint and cannot authorize a sweep.

Run `nix develop --command zig build test-local-native` from the repository root,
or `zig build test` here inside the pinned development shell. The root unit task
includes the same checks. See the [proof ledger](../../../docs/history/qualification/README.md) for
executed cases and the [storage contract](../../../contracts/TRANSIT_STORAGE_V1.md)
for the underlying local persistence boundaries.
