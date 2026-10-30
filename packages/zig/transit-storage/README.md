# `transit-storage`

`transit-storage` supplies the log and object primitives (`TransitLog` and
`TransitObjectStore`) used by the local native backend and direct Table owner.
`TablePartition` owns atomic Table statements, retained reads and paged data
indexes. Separate components include the content-verified
`NvmeCache`, immutable `TableManifest` (`"TMAN"` v1) artifacts and optimistic
manifest rebasing (`PartitionLease.OccCoordinator`).

`Tack` binds a queue segment's available, acquired, acked and archived state
sets to its exact interpretation, offset range and accepted WAL frontier. The
488-byte envelope references immutable paged `BitmapDirectory` roots and uses
the same Roaring codec as Fuze's `.tdel`. `Audit.page` validates bounded pages;
only a completed audit establishes disjoint, complete range coverage. Missing
containers, overlaps, incorrect counts and foreign bindings reject. State edits
stage private roots; lease metadata, receipts and publication remain the owning
partition's responsibility. Terminal cardinality is a reclamation eligibility
hint and supplies no authority to delete retained payloads.

`LogTail` reserves aligned payload slabs and borrow handles under an explicit
resident byte budget. It verifies content once on admission, returns pinned
slices without copying, and keeps 64 trailing zero bytes for internal vector
reads. A pin prevents eviction and destruction; stale or copied released handles
cannot release a later borrow. All cache operations reuse initialization storage.
Cache pressure may refuse admission without affecting the durable log. Callers
serialize access, retain the owner through release, and check current rights
before disclosing buffered bytes. A cache pin is not a durable retention pin.

`LogDeclaration` validates schema-bound partition/FIFO/compaction keys and stores
immutable schema, policy, limits and catalog property bytes. `LogInitialization`
accepts an exact original initialization only at an empty physical partition,
after reading back its staged declaration and rechecking the service's current
publication guard. Retrying a lost receipt observes the same genesis; different
operations or ordinals cannot reuse it. Disk reopen and current-policy readback
retain the original evidence. Missing or trimmed initialization blocks observation
until a qualified recovery owner provides retained evidence. These foundations
do not publish catalog names or expose append/claim APIs.

The default local launcher selects the
[local native backend](../transit-backend-local/README.md). Ursula remains an
explicit node backend. This package's
Table component tests do not establish installed SQL execution, automatic flushing,
automatic archive scheduling or multi-process Table commits. Physical Table-object
collection is composed by the [local backend](../transit-backend-local/docs/maintenance.md#direct-table-and-catalog-collection)
and the catalog's retained dependency graph.

## Modules

- `BitmapDirectory.zig`: Immutable paged directories of shared Roaring containers
  spanning unsigned 64-bit offsets. One cached container and caller-owned 8 KiB
  mutation scratch remain independent of durable cardinality. Container objects
  bind their high offset prefix and current definition; reads verify content
  before cache admission. Borrowed views last until the owner's next cache miss.
  A bounded edit stages its container and directory path under the caller's
  `TreeStore` work budget. Only an owning WAL may publish the returned root;
  retention traversal must retain both its directory pages and container objects.
  No accepted root or authorization is stored by this component.
- `DocumentIndex.zig`: Private Document candidates backed by bounded `.tseg`
  record batches and paged data indexes, independent of Station. Its
  [storage and integration guide](docs/document-index.md) specifies workspace
  lifetimes, budgets and the transaction/retention obligations before service use.
- `TransitLog.zig`: Pluggable write-ahead log interface and 64-byte-aligned `"TWAL"` v1
  binary frame format with a mandatory definition in its 128-byte header,
  CRC32C + SHA-256 verification and `(writer_epoch, policy_epoch)`
  fencing.
- `LocalWal.zig`: Exclusive POSIX log owner with incremental segmented writes,
  synced frontiers/fences/trim floors, bounded recovery, and a separate volatile
  memory fixture. Each cached partition retains only three volatile frame
  coordinates for latest/repeated/sequential reads; returned frames are verified
  from disk. `trimUnit` separates accepted trim coverage from bounded physical
  cleanup; repeated units or `resumeTrim` preserve progress while other work runs.
  Synchronous `Log.trim` drains those units. Cold partition recovery remains a
  separate cost. See the [persistence contract](../../../contracts/TRANSIT_STORAGE_V1.md#local-wal-persistence).
- `TransitObjectStore.zig`: Pluggable immutable segment and conditional manifest
  object store interface (`putImmutable`, `putConditional` with `if_none_match` / `if_match`,
  `getRange`, `head`, `delete`).
- `LocalSegmentStore.zig`: POSIX object owner with per-key process locks, atomic
  descriptor publication, immutable content, chunk-verified range reads and no
  whole-object disk cache. A separate memory fixture implements the same typed
  operations. See [object persistence](../../../contracts/TRANSIT_STORAGE_V1.md#local-object-persistence).
- `S3ObjectStore.zig`: S3-compatible `TransitObjectStore` adapter with AWS Signature
  Version 4 (`AWS4-HMAC-SHA256`), conditional CAS headers, and partial byte-range requests.
- `NvmeCache.zig`: Tier 2 `64 KiB` chunked range cache with SHA-256 integrity checks
  and scan-resistant W-TinyLFU / Clock eviction.
- `TableManifest.zig`: Immutable versioned `"TMAN"` v1 table manifests referencing
  `.tseg` hybrid columnar segments and `.tdel` deletion vectors.
- `PartitionLease.zig`: Control & Policy Log (`partition_id = 0`) vs. data partition
  separation, epoch-fenced `PartitionLease` records and optimistic manifest
  rebasing. This component does not implement the installed Table writer profile;
  conditional provider operations can use locks and blocking I/O.
- `TreeStore.zig`: Immutable data-index pages backed by `TransitObjectStore`,
  reusing the generic ordered tree in `transit-core`. Each page binds the current
  definition, its logical digest and its content address. Its configurable cache
  contains at most 4,096 pages (zero disables caching); private mutation work has
  a separate encoded-byte budget. Staging never publishes a root. The owning
  acceptance log must publish it and establish retention before collection.
  `staged_pages`/`staged_bytes` count acknowledged staging calls and their encoded
  bytes, including immutable deduplication; they do not count device writes.
- `TransactionDirectory.zig` and `TransactionDecisionLog.zig`: Paged private
  participant/preparation commitments and a fenced original-attempt decision
  journal. Their [integration contract](docs/transaction-decisions.md) requires
  catalog admission, Table preparation/common-decision visibility and retained
  graph ownership before runtime use. They expose no installed SQL transaction.
- `TableWorkspace.zig`: Private typed row and predicate DML over an authorized
  retained Table pin, using the existing Table evaluator and immutable indexes.
  Read-your-writes and private rollback preserve consumed statement identities;
  results are provisional and never append to the public Table WAL. Its
  [integration obligations](docs/transaction-decisions.md#private-table-evaluation)
  include durable state/result ownership, retention, aggregate quotas and commit
  preparation before service use.
- `OrderedKeyIndex.zig`: Full ordered keys up to 4 KiB, mapped to row hashes
  through immutable 64-byte key chunks over `TreeStore`. Point lookup and
  inclusive/exclusive range seeking use bounded paths; mutation candidates share
  the owner's staging budget. Table acceptance publishes its root atomically
  with row locators and identity indexes, preserving earlier retained roots.
  `mutate` accepts up to eight distinct keys. Short-key terminal changes share
  page paths; longer keys retain bounded chunk traversal and preserve prefixes.
- `TablePartition.zig`: A serialized Table storage owner with one WAL acceptance
  record for rows, paged indexes and exact operation receipts. It supports point
  WAL batches, staged `.tseg` batches, bounded flushing, durable read pins and
  accepted history archives with resumable physical WAL trimming and bounded
  recovery baselines published by that same acceptance log.
  Explicit logical history floors require archive/checkpoint coverage, preserve
  snapshots and receipts, and respect a paged minimum of live history leases.
  Explicit bounded compaction merges live segment rows below a fixed boundary
  while retained roots keep their original physical references.
  Accepted archive/checkpoint and compaction targets resume across replacement;
  separate source frontiers prevent work bookkeeping from triggering itself.
  Automatic compaction selects whole sparse inputs or merges two small adjacent
  inputs; accepted skip progress leaves packed or oversized inputs intact.
  Mutation, rewrite and flush workspaces have an explicit allocation ceiling,
  separate from encoded row limits and index/cache budgets.
  Frozen row admission, rejection and cancellation share that Table WAL; row
  acceptance atomically clears pending work and records matched/changed counts.
  Bounded logical-history inspection separates accepted statements from physical
  maintenance while preserving original no-op receipts and a fixed upper cut.
  See [Table partition ownership](docs/table-partitions.md) for caller obligations,
  budgets and the current integration boundary.
- `TableEvidence.zig`: Bounded immutable outcome and operation metadata,
  published through the Table's paged indexes. Original receipt and pending-work
  recovery do not read the accepting row payload or retain its old row roots.
  Current authorization, original declarations and exact retry identity remain
  required; missing or corrupt evidence rejects.
- `TableStorageWalk.zig`: A bounded cursor over one typed immutable Table
  directory. It verifies page paths and emits explicit row, pin, evidence and
  archive dependencies. Ordered-key child directories are separate work items.
  Selecting all retained roots, validating referenced objects and authorizing
  deletion remain the maintenance owner's responsibilities.
- `TableStorageRoots.zig`: Fixed-cut enumeration of retained history and
  recovery roots. It verifies the complete selected frame chain before a
  collector can use its marks and does not recursively open old checkpoints.

The direct owner reads immutable Table data through Fuze's shared `TSegReader`.
Point lookup selects one segment through its paged hash-key directory; footer
and selected row-group ranges replace full-object buffering. Point reads retain
verified encoded pages and expand only the requested row into owned output;
complete-page validation still checks skipped values. Adjacent point reads reuse
encoded pages. Scans retain one verified projected group. Plain int64, uint64,
float64, Boolean, text, binary and JSON columns use aligned value buffers with
sparse error/conflict details. Other plain types retain bounded metadata and
borrowed byte payloads; compressed columns use bounded owned decoding.
Encoded buffers and decoded metadata/expansion have separate allocation
budgets, and returned rows detach their values before cache replacement. Physical
groups default to 256 rows, independently of statement and response bounds.
Retained `rangeSnapshot` reads follow the paged full-key directory in collation
order. Retained column scans select required input columns; the finite query
owner uses that projection. `scanSnapshotFiltered` also supplies bounded encoded
predicate decisions over live identities, with explicit skipped-row coverage
and deferred failures. Signed filtered reads bind those decisions to the retained
source and plan; finite SQL preserves coverage, LIMIT and original error positions.

Opening a disk WAL validates every retained partition before returning, even
when segment names span multiple directory pages. Nested recovery scans use an
independent startup directory handle; caller reads are not the startup gate.
Each loaded partition inventories segment bounds/count once, then recovery and
sequential reads follow verified LSNs directly across segment files. Missing,
overlapping and noncanonical segment names reject. The inventory retains no
filename array; cold partition loads still enumerate the directory. Bounded trim
persists physical completion separately from its authorized floor, so rotating
requests and descriptor eviction do not restart completed cleanup. Interrupted
cleanup can enumerate the remaining prefix again.

`LocalWal.nextPartition(after)` discovers existing partitions in numeric order,
including empty fenced and fully trimmed partitions. Each call retains one ID
and scans the directory, checking canonical names and the selected owner's
mandatory metadata even when its descriptor is cached. Segment-only owners
reject instead of disappearing from discovery. Callers serialize each call and
establish their own acceptance cut; the cursor is not a retained snapshot.

`zig build test` includes real temporary-directory WAL tests: cache eviction,
segmented recovery above 64 MiB, durable empty-log fencing and full trim,
incomplete tails, missing/corrupt acknowledged history, incompatible definitions,
exclusive ownership, trim convergence across rotating partitions and lost replies
around cleanup completion. Power interruption and
filesystem rollback are separate qualification boundaries. Run through the
pinned development shell described in [contributing](../../../docs/handbook/guides/contributing.md).

Data-index tests reopen 513 records through a one-page cache, scan with no cache,
retain an earlier root across updates/deletes, reject corrupt or missing pages,
and keep the accepted root unchanged when a private work budget is exhausted.
These tests establish an index primitive, not Table publication or snapshot pins.

The disk object cases exercise two independent handles, concurrent publication,
stale conditions, immutable identity, corrupted chunks/checksums, 513 objects
through a 16 KiB owner allocator, incompatible definitions and five sync failures.
One disk `LocalSegmentStore` also permits concurrent operations: per-key locks
protect publication and a separate short mutex protects completed-attempt
counters. Read counters only after joining callers, and join all operations
before closing the store. The memory fixture remains caller-serialized.
The root unit task also launches three races of twelve independent processes and
checks their results against a Python oracle. Descriptor deletion unpublishes the
key; physical content collection still requires retained-reader/pin ownership.

`just test::local-storage-faults` kills real local owner processes at WAL
append/fence/trim, Table archive/compaction/checkpoint acceptance and
object-publication boundaries.
Fresh processes verify data,
epochs, trim floors, Table receipts/snapshots/history and exact object retries against an independent Python
oracle. The root unit task includes this proof. Repeating an already-published
WAL trim boundary finishes interrupted prefix removal. These schedules preserve
the operating system and its page cache; they do not simulate power loss or
disk exhaustion. See the [proof ledger](../../../docs/history/qualification/storage.md#local-storage-process-death-boundaries--2026-10-26).

`just test::storage-io-faults` exercises injected `NoSpaceLeft` and `InputOutput`
errors around real disk writes and syncs. A WAL owner requires reopening after
an uncertain write, preserving complete recoverable frames; object publication
keeps private partial files out of the public descriptor. These error schedules
do not exhaust the host filesystem or establish hardware failure behavior.
Cancellation while opening or checking the length of an existing WAL segment
leaves the log usable because those steps change no bytes. Cancellation after
segment creation or a possible write still requires reopening, as do other
storage failures. The disk WAL regressions check both boundaries and preserve
the acknowledged prefix and exact successor across independent partitions.

`TablePartition` checks an accepted recovery baseline and its contiguous later
acceptance history, or the complete chain from creation when no baseline exists,
before exposing recovered rows. It loads the exact current declaration. Its paged indexes preserve stable row identities;
equal values in keyless rows do not collapse distinct rows. Durable read pins
retain their original WAL and segment basis across flushes, changes and restart.
See the [partition contract](docs/table-partitions.md) for recovery gates and
allocation budgets.

WAL frames, segment footers, deletion vectors and manifests require the shared
binary definition even when copied outside their original directory. Segment
lookups check schema interpretation and deletion-vector ownership before pruning.
The current definition supports Table acceptance records, with no standalone
row-delta memtable format. Earlier definitions reject without conversion or reset;
preserve those artifacts with their matching build as described in the
[versioning policy](../../../docs/handbook/reference/versioning.md).

Focused storage checks use `zig build test -Dtest-filter='Table ALTER'` inside
`nix develop`. Filters select test names; omit them for the complete suite.

The [local WAL model](../../../tests/verification/models/README.md#finite-local-wal-model)
checks finite crash and publication ordering separately from disk experiments.
Recovery syncs complete frames beyond the saved frontier, and opening syncs the
WAL directory before returning. These barriers prevent a later fence, append or
resumed trim from depending on merely visible file bytes or metadata.
