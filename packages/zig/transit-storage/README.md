# `transit-storage`

`transit-storage` supplies components for Transit's tiered storage boundary (`TransitLog` and
`TransitObjectStore`), the Tier 0 MVCC `TableMemtable`, the Tier 2 content-verified
`NvmeCache`, versioned immutable `TableManifest` (`"TMAN"` v1) artifacts, and the
lock-free multi-writer OCC coordinator (`PartitionLease.OccCoordinator`).

The default local launcher selects the
[local native backend](../transit-backend-local/README.md). Ursula remains an
explicit node backend. This package's
Table component tests do not establish installed SQL execution, automatic flushing,
durable snapshot pins, policy-authorized trimming or multi-process Table commits.

## Modules

- `TransitLog.zig`: Pluggable write-ahead log interface and 64-byte-aligned `"TWAL"` v1
  binary frame format with a mandatory definition in its 128-byte header,
  CRC32C + SHA-256 verification and `(writer_epoch, policy_epoch)`
  fencing.
- `LocalWal.zig`: Exclusive POSIX log owner with incremental segmented writes,
  synced frontiers/fences/trim floors, bounded recovery, and a separate volatile
  memory fixture. See the [persistence contract](../../../contracts/TRANSIT_STORAGE_V1.md#local-wal-persistence).
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
  separation, epoch-fenced `PartitionLease` records, and lock-free multi-writer OCC
  manifest rebasing.
- `TableMemtable.zig`: Tier 0 MVCC Memtable with direct data-plane WAL ingestion,
  read-your-writes snapshot queries, `.tseg`/`.tdel` segment flushing, and crash recovery.
- `TreeStore.zig`: Immutable data-index pages backed by `TransitObjectStore`,
  reusing the generic ordered tree in `transit-core`. Each page binds the current
  definition, its logical digest and its content address. Its configurable cache
  contains at most 4,096 pages (zero disables caching); private mutation work has
  a separate encoded-byte budget. Staging never publishes a root. The owning
  acceptance log must publish it and establish retention before collection.

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

Table recovery consumes every bounded WAL page through its captured frontier and
checks contiguous history and schema identity. An incomplete recovery blocks
reads and mutations until successful recovery. The component owns its schema
and reserves row-visibility allocations before attempting a durable append.
The active memtable and manifest still require separate growth and snapshot
work; paging WAL reads does not bound the full resident row set.

Keyless rows use stable `TableRow.Identity` storage keys and support identity
point reads/deletes. Equal cell values do not collapse distinct rows. Reads before
the active flush frontier return `SnapshotNotRetained`; this component does not
retain a historical basis implicitly. WAL frames, segment footers, deletion
vectors and manifests require the shared binary definition even when copied
outside their original directory. Segment lookups check schema interpretation
and deletion-vector ownership before pruning.
