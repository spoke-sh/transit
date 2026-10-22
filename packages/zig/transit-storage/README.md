# `transit-storage`

`transit-storage` implements Transit's tiered storage boundary (`TransitLog` and
`TransitObjectStore`), the Tier 0 MVCC `TableMemtable`, the Tier 2 content-verified
`NvmeCache`, versioned immutable `TableManifest` (`"TMAN"` v1) artifacts, and the
lock-free multi-writer OCC coordinator (`PartitionLease.OccCoordinator`).

## Modules

- `TransitLog.zig`: Pluggable write-ahead log interface and 64-byte-aligned `"TWAL"` v1
  binary frame format with CRC32C + SHA-256 verification and `(writer_epoch, policy_epoch)`
  fencing.
- `LocalWal.zig`: Native segmented POSIX/memory `TransitLog` backend with `sync`
  durability and torn-tail crash recovery.
- `TransitObjectStore.zig`: Pluggable immutable segment and conditional manifest
  object store interface (`putImmutable`, `putConditional` with `if_none_match` / `if_match`,
  `getRange`, `head`, `delete`).
- `LocalSegmentStore.zig`: Native POSIX/memory `TransitObjectStore` backend with atomic
  file replacement and SHA-256 verification.
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
