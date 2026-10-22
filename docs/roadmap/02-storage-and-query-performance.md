# 2. Local durable storage, `.tseg` segments and bounded queries

[Roadmap](README.md) · [Tracker #109](https://github.com/spoke-sh/transit/issues/109) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Replace the current B-tree-over-HTTP-stream-pages storage bottleneck with a
four-tier storage hierarchy over two pluggable primitives (**`TransitLog`** and
**`TransitObjectStore`**), a pure-Zig hybrid OLTP/OLAP segment format (**`.tseg`**)
with composable physical codecs and collations, bounded native persistence and
correct local conditional publication. [Provider/concurrent-writer qualification](12-storage-providers-and-concurrency.md)
receives distributed-provider and partitioned-writer integration explicitly;
its contracts are still designed with this foundation before dependent formats.
The [performance reference](../handbook/reference/performance.md) records current
measurements; the [storage reference](../handbook/reference/storage.md) and
[storage internals](../handbook/internals/storage-runtime.md) document the current
boundary and target architecture.

## Reopened assessment — 2026-10-22

Source review of local snapshot `a0a8a3ed`
found useful standalone work from
[PR #106](https://github.com/spoke-sh/transit/pull/106): storage interfaces,
TSEG/TDEL/TMAN encoding, physical codec/collation helpers, a memtable, local
persistence implementations, an Ursula adapter and an OCC helper. Their component
tests do not establish the durable, bounded replacement described below.

The local WAL rewrites retained partition contents and cannot reload a partition
file beyond its 64 MiB read limit. Local manifest publication uses a
check-then-replace sequence rather than atomic cross-writer CAS. Recovery reads
only one 4,096-frame batch; keyless row identity and snapshots spanning flush
are incorrect. Readers, object caches and manifests grow resident state with
retained data. `S3ObjectStore` uses an in-memory signing loopback, `NvmeCache`
holds heap buffers, and partition authority/OCC are not integrated into the node.
The live runtime still uses the existing Table page path.

The subsequent local WAL implementation replaces the whole-partition rewrite
with incremental rolling files and bounded recovery. Disk component tests now
cover 73 partitions with eight cached descriptors, more than 64 MiB of history,
fence-only and full-trim restart, exclusive ownership and injected sync failure.
The [persistence contract](../../contracts/TRANSIT_STORAGE_V1.md#local-wal-persistence)
defines mandatory current-definition metadata and uncertain outcomes. This
advances #113; it does not establish the live acceptance, pin/retention or node
cutover gates, or the object-store and memtable repairs listed above.

| Remaining work | Tracking issue |
| --- | --- |
| WAL/manifest/catalog acceptance, visibility and contiguous checkpoint contract | [#111](https://github.com/spoke-sh/transit/issues/111) |
| Catalog/partition roots, transaction domains and durable snapshots | [#125](https://github.com/spoke-sh/transit/issues/125) |
| Native control/process/KV/Document persistence and recovery | [#126](https://github.com/spoke-sh/transit/issues/126) |
| Logical changefeeds, snapshot-to-tail handoff, pins and safe retention | [#127](https://github.com/spoke-sh/transit/issues/127) |
| Encoded column execution and shared reader/buffer ownership | [#128](https://github.com/spoke-sh/transit/issues/128) |
| Segmented local WAL, durable epochs/trim state and exact restart recovery | [#113](https://github.com/spoke-sh/transit/issues/113) |
| Atomic immutable writes and conditional manifest publication across processes | [#114](https://github.com/spoke-sh/transit/issues/114) |
| Keyless identities, MVCC snapshots, idempotence and complete replay | [#115](https://github.com/spoke-sh/transit/issues/115) |
| Bounded manifests/indexes/scans, range reads, spill and safe compaction | [#116](https://github.com/spoke-sh/transit/issues/116) |
| Partition authority, durable scoped fencing and integrated multi-writer OCC | [#117](https://github.com/spoke-sh/transit/issues/117) |
| Independent codec/collation conformance and consistent query/storage semantics | [#118](https://github.com/spoke-sh/transit/issues/118) |
| Real Ursula/S3, disk caching and reference deployment qualification | [#121](https://github.com/spoke-sh/transit/issues/121) |
| Coordinated current-v1 definition and artifact cutover | [#112](https://github.com/spoke-sh/transit/issues/112) |
| Accurate current documentation and scoped proof claims | [#123](https://github.com/spoke-sh/transit/issues/123) |
| Real disk/failure/growth evidence and matched performance controls | [#124](https://github.com/spoke-sh/transit/issues/124), [#76](https://github.com/spoke-sh/transit/issues/76) |

Resolve commit authority before wiring storage, establish the correct bounded
local slice, then complete the [installed cutover](03-live-storage-and-sql-cutover.md).
The sequencing review transfers #117/#121 implementation and distributed runtime
qualification to [milestone 12](12-storage-providers-and-concurrency.md).
#109 remains the umbrella for its original outstanding local and provider scope;
this milestone remains In Progress. Local cross-process CAS, fencing at its
supported authority boundary and all local recovery obligations remain here.
The target architecture and completion criteria below incorporate the authorized
transcript review.
The [shared contract gates](README.md#firm-scope-and-contract-gates) must resolve
exact transaction, layout, codec/collation, trust and provider semantics before
dependent implementation. Zero-copy access, bounded lookup I/O and efficient
rebasing remain design objectives with scoped evidence; unsupported universal
conversion, latency or complexity guarantees are not acceptance assumptions.

## Shared durable system and commit profiles

The storage foundation covers control/policy and catalog state, native process
mailboxes/turns, KV roots, Document causal state, accepted-operation receipts,
effect evidence and supported captured/stream payloads as well as Tables.
[#126](https://github.com/spoke-sh/transit/issues/126) assigns each owner its log
transitions, checkpoint evidence and immutable object representation. Shared
primitives do not require every resource kind to use columnar Table pages.

[#125](https://github.com/spoke-sh/transit/issues/125) defines catalog roots and
snapshots; [#111](https://github.com/spoke-sh/transit/issues/111) defines one
acceptance protocol for two ingestion paths. Small writes use WAL/memtable
admission and later flushing. Bulk writers may stage immutable segments directly;
their durable publication record must join the same query visibility, conflict,
receipt and changefeed semantics. An uploaded object is not an accepted write,
and a manifest checkpoint must not become a second independent authority.

[#127](https://github.com/spoke-sh/transit/issues/127) distinguishes recovery
state, net snapshot deltas and complete ordered logical changes. A row changing
`A -> B -> A` has an empty endpoint diff but two transitions. Define transaction
boundaries, subscriptions, before/after information, archival and consumer
positions accordingly. Compaction creates no user mutation. Physical WAL removal
requires all retained recovery/history/pin obligations to remain satisfied;
logical expiry remains opt-in. Snapshots and future branches include accepted
unflushed WAL state through durable pins, not just the latest flushed manifest.

[#128](https://github.com/spoke-sh/transit/issues/128) owns reader/array contracts,
encoded operators and buffer lifetime. [#116](https://github.com/spoke-sh/transit/issues/116)
owns bounded physical access and maintenance; [#118](https://github.com/spoke-sh/transit/issues/118)
owns independent type/codec/collation correctness. Their contracts are developed
together, without waiting for all maintenance or foreign-format implementations.

## Recorded bottleneck diagnosis

The earlier end-to-end baseline (`806 ms` for a local console 1-row `INSERT`,
`13,238 ms` over PostgreSQL wire, `1,072` Ursula HTTP attempts and `29` staged
pages per single-row write) identified three compounding architectural bottlenecks.
These figures are historical observations, not a new measurement from the
reopening review:

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

The architecture below includes future backend choices to keep the shared
interfaces coherent. This milestone qualifies the native local profile and
codec/query foundation; the named distributed backends, disk range cache and
partitioned concurrent-writer delivery belong to milestone 12. Existing helper
implementations retain only their recorded component evidence.

### Two pluggable storage primitives

Split the storage engine into two explicit Zig interfaces with swappable backends:

1. **`TransitLog` (The Sequenced Write-Ahead Log & Data-Activation Bus):**
   - Canonical binary frame format (`TWAL1`, with integrity and compatibility
     defined by the owning storage contract), carrying
     `partition_id`, `writer_epoch`, `policy_epoch`, `lsn`, and typed delta
     payloads for row mutations `+row`/`-row`, catalog DDL, process mailbox
     admissions and effect intents.
   - Operations: `append(partition, expected_offset_or_epoch, batch)`,
     `tail/subscribe(partition, from_offset)` and `trim(partition, up_to_offset)`
     once changes and all required recovery/history evidence are checkpointed
     or archived and the retention floors in #127 permit physical removal.
   - Backends:
     - **Native Zig Local Segmented WAL (`LocalWal`):** Pre-allocated `64 MiB`
       append-only segment files using `fdatasync`/`io_uring` and group commit.
       Default for `transit server` so local development runs as a single Zig
       binary with no external storage daemons. Resolve runtime composition in
       #122/#126; measure commit latency instead of promising a universal bound.
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
     - **Cloud Object Storage (S3, then separately qualified GCS/R2/Azure profiles):**
       Provider-backed system of record for immutable data segments
       (`.tseg`), deletion vectors (`.tdel`) and versioned manifests, paired with
       a disposable local NVMe content-verified read-through cache. Provider
       conditions, credentials, integrity and durability require their own
       conformance profile; an S3 adapter does not prove all providers.
     - **Native POSIX Segment Store (`LocalSegmentStore`):** Atomic
       `open(O_CREAT|O_EXCL) + fsync + rename` and direct `mmap`/`preadv` over a
       local directory. #114 must prove immutable creation and cross-process CAS;
       a check-then-rename recipe alone is insufficient. Default for
       `transit server` without requiring MinIO.
     - **Compose and Kubernetes/Substrate launchers (`launchers/`):** Exercise
       the distributed **Ursula + S3 + Substrate** deployment profile where
       Station placement and distributed compute over data partitions are tested.

### Four-tier memory hierarchy

| Tier | Medium | State held | Durability & recovery invariant |
| --- | --- | --- | --- |
| **Tier 0: RAM** | Bounded Zig arenas | Active **Memtables / Delta Buffers** (immediate MVCC visibility for committed WAL frames), **Catalog & Grant Head** (`policy_epoch`), and verified **Buffer Pool** (pinned `.tseg` column pages, zone maps, B-tree index nodes). | Zero durability authority; rebuilt by replaying the uncompacted `TransitLog` tail from the latest Manifest watermark. |
| **Tier 1: WAL (`TransitLog`)** | `LocalWal`, `UrsulaWal`, or qualified `Kafka`/`Pulsar` | Accepted row changes, segment-publication references, catalog/control transitions, native turns and required logical history. | The selected commit protocol and provider profile define acknowledgement. Checkpoint/archive coverage and retained pins/consumer obligations govern physical trim. |
| **Tier 2: Local Disk / NVMe** | Local filesystem | In cloud mode: disposable, verified `.tseg`/`.tdel` range cache and bounded query spill. In local mode: primary `LocalWal` + `LocalSegmentStore`. | Cache-node loss is safe only when authoritative WAL/object state survives elsewhere. Local sync establishes the specified local-disk guarantee, not recovery after losing that disk. |
| **Tier 3: Object Storage (`TransitObjectStore`)** | Qualified cloud provider or `LocalSegmentStore` | Immutable Table segments/deletion vectors, other resource objects, recovery/history checkpoints and versioned catalog/partition/snapshot manifests. | Durable published objects plus required WAL/history retain the accepted state. Head publication remains authorized; object CAS alone does not establish a transaction or current access. |

### `.tseg` hybrid OLTP/OLAP segment format, Zig codecs and collations

Instead of choosing between a write-heavy B-tree and a scan-only analytical file
format, Transit's primary native table storage format is **`.tseg`** (inspired by
Vortex and Apache Arrow), paired with multi-format foreign/exchange support:

- **64-byte-aligned Arrow-compatible plain column buffers:** Borrow qualified
  layouts into Fuze/Arrow without row deserialization. Define actual offsets,
  nested layouts, five-state sidecars, pin/release and export semantics in #128;
  compressed/foreign profiles use bounded decoding where borrowing is impossible.
- **Native 5-state cell validity/tag streams:** Every column carries compact
  bitmasks/tags for `value`, `null`, `missing`, `type_error` and `conflict` so
  malformed foreign/mainframe fields or `REDEFINES` union variants surface
  explicitly (`IS TYPE_ERROR`, `IS MISSING`) without aborting scans. Preserve
  error/conflict payloads and original-byte provenance according to the selected
  contract; a state tag by itself is not lossless source preservation.
- **Hybrid OLTP + OLAP indexing in the segment footer:**
  - **Per-row-group Zone Maps** (`min`, `max`, null/error counts, optional Bloom
    filters) for vectorized predicate pushdown.
  - **Embedded Primary-Key Prefix B-Tree Index** over sorted rows so point
    lookups (`WHERE pk = $1`) and narrow range scans use bounded paged index and
    row-group access. Measure I/O under explicit cache/index-depth assumptions;
    the two-range-read target is a qualified profile, not a universal guarantee.
  - **Deletion Vectors (`.tdel` roaring/bitmap files):** Point `DELETE` and
    `UPDATE` operations write a compact `.tdel` bitmap (and append the new row to
    the active Memtable/WAL) instead of rewriting `.tseg` files until background
    compaction.
- **Composable pure-Zig physical codecs:**
  - Analytical encodings: **Bitpacking / Frame-of-Reference (FOR)**, **Run-Length
    Encoding (RLE)**, **Dictionary encoding** (with late materialization in
    `Fuze` filters and group-bys), and **FSST (Fast Static Symbol Table)** string
    compression.
  - Enterprise and mainframe encodings (selected physical-codec kernels and
    bounded canonical-vector decoding, with allocation/copy costs measured):
    - **`COMP-3` (Packed Decimal / BCD):** Variable nibble-packed digits with
      trailing sign nibble (`0xC`/`0xF` positive, `0xD` negative) decoded directly
      to `decimal128(p, s)` or `int64` with invalid-nibble capture as `type_error`.
    - **`ZONED` (Zoned Decimal / `DISPLAY` numeric):** EBCDIC (`0xF0`–`0xF9`) or
      ASCII zoned digits with overpunched trailing/leading signs (`0xC0`–`0xC9`,
      `0xD0`–`0xD9`).
    - **`COMP` / `COMP-4` / `COMP-5`:** Binary integers with explicit dialect,
      width, byte order, range and implied decimal scale; do not assign all
      source dialects one physical interpretation.
    - **`IBM_HFP` (`COMP-1` / `COMP-2`):** IBM System/360 base-16 hexadecimal
      floating point with explicit precision, range and rounding rules when
      converting to IEEE-754 `float64`; retain exact source representation where
      lossless interpretation is required.
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

### Partitioned authority and concurrent-writer extension

Design control/policy, independent data/process partitions, writer epochs and
conditional publication with #117/#125/#111 before freezing local log formats.
Do not require every unrelated write to advance one global catalog CAS.
[Milestone 12](12-storage-providers-and-concurrency.md) delivers enforceable
provider leases, scoped credentials and integrated multi-writer OCC, including
read/predicate validation required by the selected isolation contract. Local
atomic publication must already be safe across independent processes; it cannot
use an unsafe check-then-rename implementation pending that extension.

## Maintenance, inspection and deployment gates

Assign service owners for flush thresholds/timers, checkpoint publication,
compaction, logical-history archival, orphan collection and shutdown. Bound
their memory and concurrency, apply backpressure before accepting unsupported
work, and reserve control/recovery capacity. Storage pressure never authorizes
expiry. Inspection reports the selected backend/root, committed and flushed
positions, pending bytes, maintenance failures and retention floors through
authorized public reads; Board receives no raw provider access.

Provider acknowledgement, durable-copy locations, disk/host loss and network
partition profiles remain in [#121](https://github.com/spoke-sh/transit/issues/121)
and [milestone 12](12-storage-providers-and-concurrency.md). This owner proves
the declared local sync/restart profile and explicitly excludes losing the only
durable disk. Distributed providers, cache qualification and concurrent writer
integration have moved; local safety, native recovery, codecs and bounded
query/maintenance obligations have not. Replication, disaster recovery and
automatic placement each retain their later acceptance owners.

## Delivery sequence

Resolve #125/#111, #126/#127 and #128/#118 contracts before their dependent
formats and code. Qualify the local component foundation here and the actual
installed caller paths in milestone 3 before milestone 12 extends distributed
providers and concurrent writers. Contract collaboration can proceed early;
each milestone closes only against its own explicit evidence.

1. **Define and implement `TransitLog` and `TransitObjectStore` with native local backends.**
   Specify `TWAL1` frames and the `TransitObjectStore` conditional-put/range-read
   contract. Build `LocalWal` (`fdatasync`/`io_uring` + group commit) and
   `LocalSegmentStore` (`O_CREAT|O_EXCL` + `fsync` + `rename`, `mmap`/`preadv`)
   and compose them with native durable owners from #126 in disk-backed owner
   proofs. Milestone 3 owns actual live-server wiring and installed acceptance.
2. **Implement Tier 0 Memtables, `.tseg` v1 segments, `.tdel` deletion vectors and Manifest CAS.**
   Route table DML and batch writes into `TransitLog` + Tier 0 Memtables for
   immediate MVCC read-your-writes visibility, flush immutable `.tseg` segments
   and `.tdel` bitmaps to `TransitObjectStore`, and publish authorized heads.
   Also support direct immutable-segment bulk staging under the same acceptance
   and logical-change protocol, preserving native-owner checkpoint evidence.
   Retire `PackedPageStore` base64 B-tree page streaming and multi-turn table
   staging state machines (`STW1`, `STC1`, `STG1`, `STX1`).
3. **Add composable Zig codecs, 5-state tags and Collation (`COLLATE`) execution.**
   Implement bitpacking, RLE, dictionary, FSST, `COMP-3`, `ZONED`, `COMP`/`COMP-4`,
   `IBM_HFP` and `EBCDIC` codecs in `.tseg` and `Fuze`. Thread explicit collation
   descriptors through zone maps, order-preserving B-tree sort keys and `Fuze`
   comparison/sort/join/group-by kernels. Implement #128's encoded column access,
   selected pushdown/late materialization and correct bounded fallback paths.
4. **Re-baseline local latency, IO amplification and memory bounds.**
   Measure disk-backed owner paths, attributing ingestion, WAL commit,
   Memtable/segment scans, vector execution and manifest publication separately.
   Preserve the end-to-end SQL, PostgreSQL/MySQL, Flight and SDK matched controls
   as installed acceptance in milestone 3 and provider acceptance in milestone 12;
   their observations must not be replaced by library-only measurements.

## Completion evidence

The acceptance matrix in [#124](https://github.com/spoke-sh/transit/issues/124)
includes complete disk-backed native KV/Document/process-owner recovery, both ingestion paths,
snapshot pins over accepted unflushed data, complete-change versus net-result
consumers, compaction without logical mutations, and encoded/decoded reader
equivalence. A Table-only library proof cannot close this milestone. These owner
proofs qualify the local foundation; milestone 3 must separately pass actual
installed lifecycle and performance gates before the cutover is complete.

Require independently verified values/counts, matched ReleaseSafe controls, raw
samples, sufficient observations for percentiles and explicit remaining limits.
Report `TransitLog` appends, `TransitObjectStore` range reads/puts, bytes
transferred, resident RAM (Tier 0) and retained storage (Tier 2/3) alongside
latency.

Qualify crash recovery between WAL commit and manifest flush, lost receipts,
current-policy enforcement, competing local conditional publications,
corrupted mainframe nibble/codepage preservation as `type_error`,
collation-consistent zone-map pruning, and datasets exceeding resident RAM and
local cache/spill budgets. Tighten regression ceilings in the
[performance reference](../handbook/reference/performance.md) as each slice lands.
