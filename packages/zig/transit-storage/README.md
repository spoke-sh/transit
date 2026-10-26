# `transit-storage`

`transit-storage` supplies the log and object primitives (`TransitLog` and
`TransitObjectStore`) used by the local native backend and direct Table owner.
`TablePartition` owns atomic Table statements, retained reads and paged data
indexes. Separate components include the MVCC `TableMemtable`, content-verified
`NvmeCache`, immutable `TableManifest` (`"TMAN"` v1) artifacts and optimistic
manifest rebasing (`PartitionLease.OccCoordinator`).

The default local launcher selects the
[local native backend](../transit-backend-local/README.md). Ursula remains an
explicit node backend. This package's
Table component tests do not establish installed SQL execution, automatic flushing,
collector races, policy-authorized trimming or multi-process Table commits.

## Modules

- `TransitLog.zig`: Pluggable write-ahead log interface and 64-byte-aligned `"TWAL"` v1
  binary frame format with a mandatory definition in its 128-byte header,
  CRC32C + SHA-256 verification and `(writer_epoch, policy_epoch)`
  fencing.
- `LocalWal.zig`: Exclusive POSIX log owner with incremental segmented writes,
  synced frontiers/fences/trim floors, bounded recovery, and a separate volatile
  memory fixture. Each cached partition retains only three volatile frame
  coordinates for latest/repeated/sequential reads; returned frames are verified
  from disk. See the [persistence contract](../../../contracts/TRANSIT_STORAGE_V1.md#local-wal-persistence).
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
- `TableMemtable.zig`: Tier 0 MVCC Memtable with direct data-plane WAL ingestion,
  read-your-writes snapshot queries, `.tseg`/`.tdel` segment flushing, and crash recovery.
- `TreeStore.zig`: Immutable data-index pages backed by `TransitObjectStore`,
  reusing the generic ordered tree in `transit-core`. Each page binds the current
  definition, its logical digest and its content address. Its configurable cache
  contains at most 4,096 pages (zero disables caching); private mutation work has
  a separate encoded-byte budget. Staging never publishes a root. The owning
  acceptance log must publish it and establish retention before collection.
  `staged_pages`/`staged_bytes` count acknowledged staging calls and their encoded
  bytes, including immutable deduplication; they do not count device writes.
- `OrderedKeyIndex.zig`: Full ordered keys up to 4 KiB, mapped to row hashes
  through immutable 64-byte key chunks over `TreeStore`. Point lookup and
  inclusive/exclusive range seeking use bounded paths; mutation candidates share
  the owner's staging budget. Table acceptance publishes its root atomically
  with row locators and identity indexes, preserving earlier retained roots.
  `mutate` accepts up to eight distinct keys. Short-key terminal changes share
  page paths; longer keys retain bounded chunk traversal and preserve prefixes.
- `TablePartition.zig`: A serialized Table storage owner with one WAL acceptance
  record for rows, paged indexes and exact operation receipts. It supports point
  WAL batches, staged `.tseg` batches, bounded flushing and durable read pins.
  Frozen row admission, rejection and cancellation share that Table WAL; row
  acceptance atomically clears pending work and records matched/changed counts.
  Bounded logical-history inspection separates accepted statements from physical
  maintenance while preserving original no-op receipts and a fixed upper cut.
  See [Table partition ownership](docs/table-partitions.md) for caller obligations,
  budgets and the current integration boundary.

The direct owner reads immutable Table data through Fuze's shared `TSegReader`.
Point lookup selects one segment through its paged hash-key directory; footer
and selected row-group ranges replace full-object buffering. Decoded groups have
an explicit allocation budget and returned rows own their values. Physical
groups default to 256 rows, independently of statement and response bounds.
Retained `rangeSnapshot` reads follow the paged full-key directory in collation
order. SQL predicate/projection pushdown remains separate from these source reads.

Opening a disk WAL validates every retained partition before returning, even
when segment names span multiple directory pages. Nested recovery scans use an
independent startup directory handle; caller reads are not the startup gate.
Each loaded partition inventories segment bounds/count once, then recovery and
sequential reads follow verified LSNs directly across segment files. Missing,
overlapping and noncanonical segment names reject. The inventory retains no
filename array; cold partition loads still enumerate the directory, and trim
may enumerate it repeatedly.

`zig build test` includes real temporary-directory WAL tests: cache eviction,
segmented recovery above 64 MiB, durable empty-log fencing and full trim,
incomplete tails, missing/corrupt acknowledged history, incompatible definitions,
exclusive ownership and an injected sync failure. Power interruption and
filesystem rollback are separate qualification boundaries. Run through the
pinned development shell described in [contributing](../../../docs/handbook/guides/contributing.md).

Data-index tests reopen 513 records through a one-page cache, scan with no cache,
retain an earlier root across updates/deletes, reject corrupt or missing pages,
and keep the accepted root unchanged when a private work budget is exhausted.
These tests establish an index primitive, not Table publication or snapshot pins.

The disk object cases exercise two independent handles, concurrent publication,
stale conditions, immutable identity, corrupted chunks/checksums, 513 objects
through a 16 KiB owner allocator, incompatible definitions and six sync failures.
The root unit task also launches three races of twelve independent processes and
checks their results against a Python oracle. Descriptor deletion unpublishes the
key; physical content collection still requires retained-reader/pin ownership.

`just test::local-storage-faults` kills real local owner processes at WAL
append/fence/trim and object-publication boundaries. Fresh processes verify data,
epochs, trim floors and exact object retries against an independent Python
oracle. The root unit task includes this proof. Repeating an already-published
WAL trim boundary finishes interrupted prefix removal. These schedules preserve
the operating system and its page cache; they do not simulate power loss or
disk exhaustion. See the [proof ledger](../../../tests/README.md#local-storage-process-death-boundaries--2026-10-26).

`just test::storage-io-faults` exercises injected `NoSpaceLeft` and `InputOutput`
errors around real disk writes and syncs. A WAL owner requires reopening after
an uncertain write, preserving complete recoverable frames; object publication
keeps private partial files out of the public descriptor. These error schedules
do not exhaust the host filesystem or establish hardware failure behavior.

Standalone `TableMemtable` recovery consumes every bounded WAL page through its captured frontier and
checks contiguous history and schema identity. An incomplete recovery blocks
reads and mutations until successful recovery. The component owns its schema
and reserves row-visibility allocations before attempting a durable append.
Its active memtable and manifest still require separate growth and snapshot
work; paging WAL reads does not bound its full resident row set. The installed
`TablePartition` owner instead uses the paged indexes and durable read pins
described above.

Keyless rows use stable `TableRow.Identity` storage keys and support identity
point reads/deletes. Equal cell values do not collapse distinct rows. Reads before
the active flush frontier return `SnapshotNotRetained`; this component does not
retain a historical basis implicitly. WAL frames, segment footers, deletion
vectors and manifests require the shared binary definition even when copied
outside their original directory. Segment lookups check schema interpretation
and deletion-vector ownership before pruning.

Focused storage checks use `zig build test -Dtest-filter='Table ALTER'` inside
`nix develop`. Filters select test names; omit them for the complete suite.
