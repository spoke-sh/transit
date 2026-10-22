# 2. Storage hierarchy, `.tseg` segments and query performance

[Roadmap](README.md) · [Issue #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** Completed

Replace the current B-tree-over-HTTP-stream-pages storage bottleneck with a
four-tier storage hierarchy over two pluggable primitives (**`TransitLog`** and
**`TransitObjectStore`**), a pure-Zig hybrid OLTP/OLAP segment format (**`.tseg`**)
with composable physical codecs and collations, and partitioned/OCC concurrency.
The [performance reference](../handbook/reference/performance.md) records current
measurements; the [storage reference](../handbook/reference/storage.md) and
[storage internals](../handbook/internals/storage-runtime.md) document the current
boundary and target architecture.

## Root-cause diagnosis of current costs

Current end-to-end latency (`806 ms` for a local console 1-row `INSERT`,
`13,238 ms` over PostgreSQL wire, `1,072` Ursula HTTP attempts and `29` staged
pages per single-row write) comes from three compounding architectural bottlenecks:

1. **Quadruple indirection over an HTTP JSON stream store:** Table rows are
   serialized as `FTR1` row blobs inside `StationIndex` (`SBR1`) blocks, which
   live inside `transit-core` resource block B-tree (`TPG1`) pages, which live
   inside the global realm catalog B-tree (`TPG1`) pages, which `PackedPageStore`
   base64-encodes into JSON strings inside newly created per-turn Ursula streams,
   reading back every written frame in `192 KiB` chunks before sealing and
   appending to the realm journal.
2. **Actor turn ceremony for data-plane operations:** Every table write and
   catalog step is funneled through `send_input -> open_view -> read_blocks ->
   commit_turn` with `128 KiB` per-turn block budgets, forcing multi-turn staging
   state machines (`STW1`, `STC1`, `STG1`, `STX1`) and tens of round-trips per
   statement.
3. **Monolithic single-sequencer realm root:** Every principal, grant, PID,
   mailbox and table/resource root shares one global copy-on-write B-tree root
   serialized through a single journal tail.

## Target architecture

### Two pluggable storage primitives

Split the storage engine into two explicit Zig interfaces with swappable backends:

1. **`TransitLog` (The Sequenced Write-Ahead Log & Data-Activation Bus):**
   - Canonical binary frame format (`TWAL1`: CRC32C/xxHash64 checksum,
     `partition_id`, `writer_epoch`, `policy_epoch`, `lsn`, and typed delta
     payloads for row mutations `+row`/`-row`, catalog DDL, process mailbox
     admissions and effect intents).
   - Operations: `append(partition, expected_offset_or_epoch, batch)`,
     `tail/subscribe(partition, from_offset)` and `trim(partition, up_to_offset)`
     once changes are checkpointed into immutable object-store manifests.
   - Backends:
     - **Native Zig Local Segmented WAL (`LocalWal`):** Pre-allocated `64 MiB`
       append-only segment files using `fdatasync`/`io_uring` and group commit.
       Default for `transit server` so local development runs as a single Zig
       binary with zero external child daemons and sub-millisecond commits.
     - **Ursula (`UrsulaWal`):** Repositioned from a base64 B-tree page store to
       its natural role as a distributed log and data-activation stream backbone
       (one long-lived Ursula stream per `TransitLog` partition).
     - **Kafka / Pulsar (`KafkaWal`, `PulsarWal`):** Partitioned topic adapters
       using producer-epoch fencing and watermark-based log retention.
2. **`TransitObjectStore` (The Immutable Segment & Manifest Backbone):**
   - Operations: `put_immutable(key, bytes, sha256)`,
     `put_conditional(key, expected_etag_or_if_none_match, bytes)` and
     `get_range(key, offset, len)`.
   - Backends:
     - **Cloud Object Storage (`S3ObjectStore` for S3 / GCS / R2 / Azure Blob):**
       Durable, geo-replicated system of record for immutable data segments
       (`.tseg`), deletion vectors (`.tdel`) and versioned manifests, paired with
       a stateless local NVMe content-verified read-through cache.
     - **Native POSIX Segment Store (`LocalSegmentStore`):** Atomic
       `open(O_CREAT|O_EXCL) + fsync + rename` and direct `mmap`/`preadv` over a
       local directory. Default for `transit server` without requiring MinIO.
     - **Compose and Kubernetes/Substrate launchers (`launchers/`):** Exercise
       the distributed **Ursula + S3 + Substrate** deployment profile where
       Station placement and distributed compute over data partitions are tested.

### Four-tier memory hierarchy

| Tier | Medium | State held | Durability & recovery invariant |
| --- | --- | --- | --- |
| **Tier 0: RAM** | Bounded Zig arenas | Active **Memtables / Delta Buffers** (immediate MVCC visibility for committed WAL frames), **Catalog & Grant Head** (`policy_epoch`), and verified **Buffer Pool** (pinned `.tseg` column pages, zone maps, B-tree index nodes). | Zero durability authority; rebuilt by replaying the uncompacted `TransitLog` tail from the latest Manifest watermark. |
| **Tier 1: WAL (`TransitLog`)** | `LocalWal`, `UrsulaWal`, or `Kafka`/`Pulsar` | Sequential `TWAL1` frames for uncompacted row deltas (`+row`/`-row`), catalog transitions and process turns; live activation stream for maintained views, reactive watches, CDC (`TableChangeReader`) and Station actors. | Immediate commit durability and ordering per partition; trimmed once flushed into Tier 3 `.tseg` segments and referenced by a committed Manifest. |
| **Tier 2: Local Disk / NVMe** | Local filesystem | In cloud mode: disposable, content-verified (`SHA-256`) read-through cache of `.tseg`/`.tdel` byte ranges plus bounded query spill (`Fuze` sort/hash partitions). In local mode (`transit server`): primary `LocalWal` + `LocalSegmentStore`. | In cloud mode, node loss loses zero committed data and cold nodes warm NVMe pages on demand via `get_range`. In local mode, `fsync` before commit acknowledgement. |
| **Tier 3: Object Storage (`TransitObjectStore`)** | S3 / GCS / R2 / Azure Blob or `LocalSegmentStore` | Immutable **`.tseg` Data Segments**, **`.tdel` Deletion Vectors**, and versioned **Table / Partition / Branch Manifests (`manifest/v{N}`)** committed via conditional CAS (`If-None-Match`). | System of record for all compacted state, historical `AS OF` snapshots and branches. |

### `.tseg` hybrid OLTP/OLAP segment format, Zig codecs and collations

Instead of choosing between a write-heavy B-tree and a scan-only analytical file
format, Transit's primary native table storage format is **`.tseg`** (inspired by
Vortex and Apache Arrow), paired with multi-format foreign/exchange support:

- **64-byte-aligned Arrow-compatible column buffers:** Zero-copy `mmap`/`preadv`
  directly into `Fuze`'s columnar `Batch.zig` vectors without row-by-row `FTR1`
  deserialization.
- **Native 5-state cell validity/tag streams:** Every column carries compact
  bitmasks/tags for `value`, `null`, `missing`, `type_error` and `conflict` so
  malformed foreign/mainframe fields or `REDEFINES` union variants surface
  losslessly (`IS TYPE_ERROR`, `IS MISSING`) without aborting scans.
- **Hybrid OLTP + OLAP indexing in the segment footer:**
  - **Per-row-group Zone Maps** (`min`, `max`, null/error counts, optional Bloom
    filters) for vectorized predicate pushdown.
  - **Embedded Primary-Key Prefix B-Tree Index** over sorted rows so point
    lookups (`WHERE pk = $1`) and narrow range scans execute in $O(\log N)$ via
    two range reads (`footer index -> target row-group slice`).
  - **Deletion Vectors (`.tdel` roaring/bitmap files):** Point `DELETE` and
    `UPDATE` operations write a compact `.tdel` bitmap (and append the new row to
    the active Memtable/WAL) instead of rewriting `.tseg` files until background
    compaction.
- **Composable pure-Zig physical codecs:**
  - Analytical encodings: **Bitpacking / Frame-of-Reference (FOR)**, **Run-Length
    Encoding (RLE)**, **Dictionary encoding** (with late materialization in
    `Fuze` filters and group-bys), and **FSST (Fast Static Symbol Table)** string
    compression.
  - Enterprise and mainframe encodings (decoded directly into canonical `Fuze`
    vectors in-register without intermediate heap allocations):
    - **`COMP-3` (Packed Decimal / BCD):** Variable nibble-packed digits with
      trailing sign nibble (`0xC`/`0xF` positive, `0xD` negative) decoded directly
      to `decimal128(p, s)` or `int64` with invalid-nibble capture as `type_error`.
    - **`ZONED` (Zoned Decimal / `DISPLAY` numeric):** EBCDIC (`0xF0`–`0xF9`) or
      ASCII zoned digits with overpunched trailing/leading signs (`0xC0`–`0xC9`,
      `0xD0`–`0xD9`).
    - **`COMP` / `COMP-4` / `COMP-5`:** Big-endian 2/4/8-byte two's-complement
      binary integers with implied decimal scale.
    - **`IBM_HFP` (`COMP-1` / `COMP-2`):** IBM System/360 base-16 hexadecimal
      floating point converted losslessly to IEEE-754 `float64`.
    - **`EBCDIC` fixed/variable strings (`CP037`, `CP1047`, `CP500`):** Preserved
      in physical byte form or transcodable via 256-byte SIMD lookup tables (`vpshufb`/`tbl`).
- **First-class Collation (`COLLATE`) architecture:**
  - Separate **Logical Type** (`utf8`, `decimal128`, `int64`), **Physical
    Encoding** (`FSST`, `EBCDIC_CP037`, `COMP3`), and **Collation** (`UCS_BASIC`,
    `EBCDIC_037_PAD`, `EBCDIC_1047_NOPAD`, `ASCII_CI`, versioned `UCA`).
  - Bind collation into column metadata, **Zone Map `min`/`max` bounds**,
    **Embedded B-Tree order-preserving sort keys**, and **`Fuze` vector kernels**
    (`Filter`, `OrderBy`, `HashJoin`, `Aggregate`) so EBCDIC-collated columns
    (where `'a' < 'A' < '0'`) and ASCII/UTF-8 columns prune row groups and sort
    identically to their declared source semantics.

### Eliminating the single global sequencer (3-level progression)

1. **Level 1 — Partitioned Authority:** Split the global realm root into a small,
   cache-resident **Control/Policy Log** (Principals, Grants, `policy_epoch`,
   Catalog Directory, Partition Lease table) and independent **Data & Process Log
   Partitions** (each Table partition and Station process group owns its own
   `TransitLog` stream and `Manifest` chain).
2. **Level 2 — Fenced Partition Leases for Direct Data-Plane Writes:**
   `transit-node` issues scoped, epoch-fenced **Partition Leases**
   `(partition_id, writer_epoch, policy_epoch)` to authorized writers. Holding a
   valid lease allows a writer to append directly to the partition's `TransitLog`
   and flush `.tseg` segments and Manifests directly to `TransitObjectStore`
   without proxying row payloads through `transit-node`. Any permission `REVOKE`
   increments `policy_epoch` and fences stale leases at storage boundaries.
3. **Level 3 — Lock-Free Multi-Writer OCC:** Multiple writers stage immutable
   `.tseg` files in parallel to `TransitObjectStore` (`put_immutable` with UUIDv7
   content keys) and commit via conditional Manifest CAS (`If-None-Match` on
   `manifest/v{N+1}` or conditional `TransitLog` append). Non-conflicting appends
   and disjoint primary-key ranges rebase automatically in $O(1)$ metadata time;
   overlapping primary-key mutations are detected using `.tseg` footer key
   indexes and rejected or retried deterministically.

## Delivery sequence

1. **Define and implement `TransitLog` and `TransitObjectStore` with native local backends.**
   Specify `TWAL1` frames and the `TransitObjectStore` conditional-put/range-read
   contract. Build `LocalWal` (`fdatasync`/`io_uring` + group commit) and
   `LocalSegmentStore` (`O_CREAT|O_EXCL` + `fsync` + `rename`, `mmap`/`preadv`)
   and wire `transit server` to run standalone without child Ursula daemons.
2. **Implement Tier 0 Memtables, `.tseg` v1 segments, `.tdel` deletion vectors and Manifest CAS.**
   Route table DML and batch writes into `TransitLog` + Tier 0 Memtables for
   immediate MVCC read-your-writes visibility, flush immutable `.tseg` segments
   and `.tdel` bitmaps to `TransitObjectStore`, and commit `manifest/v{N}` heads.
   Retire `PackedPageStore` base64 B-tree page streaming and multi-turn table
   staging state machines (`STW1`, `STC1`, `STG1`, `STX1`).
3. **Add composable Zig codecs, 5-state tags and Collation (`COLLATE`) execution.**
   Implement bitpacking, RLE, dictionary, FSST, `COMP-3`, `ZONED`, `COMP`/`COMP-4`,
   `IBM_HFP` and `EBCDIC` codecs in `.tseg` and `Fuze`. Thread explicit collation
   descriptors through zone maps, order-preserving B-tree sort keys and `Fuze`
   comparison/sort/join/group-by kernels.
4. **Implement `UrsulaWal`, `S3ObjectStore` and the local NVMe read-through cache.**
   Reposition Ursula as a `TransitLog` stream backend and add `S3ObjectStore`
   with content-verified (`SHA-256`) local NVMe range caching and `Fuze` disk
   spill. Qualify Compose and Kubernetes/Substrate launchers on the distributed
   Ursula + S3 profile.
5. **Split authority into Partitioned Logs, Fenced Leases and Multi-Writer OCC.**
   Separate the Control/Policy Log from per-table/per-process partitions, add
   epoch-fenced partition leases for direct data-plane writes, and implement
   optimistic manifest CAS rebasing and key-conflict detection across concurrent
   writers.
6. **Re-baseline end-to-end latency, IO amplification and memory bounds.**
   Reproduce matched controls across SQL sessions, PostgreSQL/MySQL wire, Flight
   and SDK callers, attributing ingestion, WAL commit, Memtable/segment scan,
   vector execution and manifest publication separately.

## Completion evidence

Require independently verified values/counts, matched ReleaseSafe controls, raw
samples, sufficient observations for percentiles and explicit remaining limits.
Report `TransitLog` appends, `TransitObjectStore` range reads/puts, bytes
transferred, resident RAM (Tier 0) and retained storage (Tier 2/3) alongside
latency.

Qualify crash recovery between WAL commit and manifest flush, lost receipts,
`policy_epoch` revocation fencing, concurrent OCC writer rebase versus key-conflict
rejection, corrupted mainframe nibble/codepage preservation as `type_error`,
collation-consistent zone-map pruning, and datasets exceeding resident RAM and
NVMe cache bounds. Tighten regression ceilings in the
[performance reference](../handbook/reference/performance.md) as each slice lands.
