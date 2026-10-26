# Storage format and hierarchy contract v1

Storage v1 defines the binary wire and on-disk formats for Transit's two-primitive
storage boundary (`TransitLog` and `TransitObjectStore`), hybrid OLTP/OLAP `.tseg`
columnar segments, `.tdel` deletion vectors, and versioned `TableManifest`
(`"TMAN"`) snapshots. See [Storage](../docs/handbook/reference/storage.md) and
[Storage runtime](../docs/handbook/internals/storage-runtime.md) for the
architectural model.

## Primitives and bounds

| Artifact | Magic / Version | Alignment | Maximum Size | Integrity Check |
| --- | --- | --- | --- | --- |
| `TransitLog` frame | `"TWAL"` + `0x01` | 64 bytes | 4 MiB payload | CRC-32C (`CRC-32/ISCSI`) + 8-byte SHA-256 payload prefix |
| Row delta payload | `"TRDL"` + `0x01` | 1 byte | 4 MiB | Enclosed in `TWAL` frame + `FTR1` row layout fingerprint |
| `.tseg` segment | `"TSEG"` + `1` (`u32`) | 64 bytes | 16 MiB | Per-page SHA-256 + `"TSF1"` footer SHA-256 |
| `.tdel` deletion vector | `"TDEL"` + `0x01` | 1 byte | 512 KiB | Trailing 32-byte SHA-256 |
| `.tman` table manifest | `"TMAN"` + `0x01` | 1 byte | 512 KiB | Trailing 32-byte SHA-256 + `If-None-Match` conditional CAS |

## `TransitLog` (`TWAL` v1) frame layout

Every `TransitLog` frame begins with a 128-byte little-endian header followed by
`payload_len` bytes of payload and zero-padding to a 64-byte boundary:

| Offset | Size | Type | Description |
| --- | --- | --- | --- |
| `0..4` | 4 | `[4]u8` | Magic `"TWAL"` |
| `4` | 1 | `u8` | Format version (`1`) |
| `5` | 1 | `FrameKind` | `1 = genesis`, `2 = policy_control`, `3 = row_delta`, `4 = catalog_ddl`, `5 = process_turn`, `6 = manifest_checkpoint` |
| `6..8` | 2 | `u16` | Header size (`128`); other layouts reject |
| `8..16` | 8 | `u64` | `partition_id` (`0` reserved for Control & Policy Log; `>= 1` for data-plane partitions) |
| `16..24` | 8 | `u64` | `writer_epoch` (`>= 1`, monotonically non-decreasing per partition) |
| `24..32` | 8 | `u64` | `policy_epoch` (`>= 1`, monotonically non-decreasing per partition) |
| `32..40` | 8 | `u64` | Partition-scoped contiguous `lsn` |
| `40..48` | 8 | `u64` | `timestamp_ms` |
| `48..52` | 4 | `u32` | `payload_len` (`<= 4 MiB`) |
| `52..56` | 4 | `u32` | `crc32c` (`CRC-32/ISCSI` over header bytes `0..52` followed by `payload`) |
| `56..64` | 8 | `[8]u8` | First 8 bytes of `SHA-256(payload)` |
| `64..96` | 32 | `[32]u8` | Mandatory decoded shared contract definition |
| `96..128` | 32 | `[32]u8` | Reserved zero bytes |

The header discriminator is checked before a short frame is classified as a torn
tail. A complete older 64-byte header rejects; it is never silently truncated.
Missing or foreign definition bytes reject. Checksums do not establish permission or an accepted
application operation; the owning acceptance record supplies that binding.

## Table acceptance records and indexes

`TablePartition` is a single-owner storage component. Its
[caller contract](../packages/zig/transit-storage/docs/table-partitions.md) requires
serialization and a service-owned current-policy fence; these stored bytes do
not grant authority. The installed local SQL service uses this component through
the [direct Table owner](DIRECT_TABLE_V1.md), which supplies catalog publication,
current authorization and exact operation recovery.

`TablePartitionRecord` owns its typed metadata. An acceptance payload contains
`TACCEPT1` at `0..8`, mandatory shared definition bytes at `8..40`, a little-endian
`u32` metadata length at `40..44`, up to 16 KiB of JSON metadata, then zero or more
encoded `FTR1` rows. The containing `TWAL` frame supplies the partition and LSN.
Metadata has a mandatory definition, the preceding payload's complete SHA-256
(zeros for the first record), the complete successor root and a tagged action.
The root binds interpretation, immutable declaration content, row-schema
fingerprint, retirement, partition, exclusive accepted and logical-change
frontiers, next segment identity, live row count, point/scan index roots, receipt
index, pin index, operation index and pending-operation index. Declaration
content, schema fingerprint, retirement, next segment identity and both operation
roots are mandatory; an earlier root cannot default these fields. The mandatory
`ordered_rows` reference names the full-key directory and is null exactly when
`live_rows` is zero. A root missing this field is incompatible, including an empty
Table root; it cannot acquire an empty directory by default.

A declaration object contains `TDECL001` at `0..8`, mandatory shared definition
bytes at `8..40`, then six little-endian `u64` identities (realm, resource,
catalog, branch, object, definition revision), a `u64` retirement flag (`0` or
`1`), and `u32` property/schema lengths. Its 104-byte header precedes up to
4 KiB of exact catalog-owned property bytes and up to 64 KiB of encoded Table
schema. Its key is `table-definitions/<digest>.data`. The complete byte hash is
the definition digest; the row-schema fingerprint is separate. Staging these
bytes publishes neither a definition nor a name.

RENAME preserves row interpretation and indexes. ALTER streams the accepted
source into bounded segments and private replacement indexes, validating all
rows and new keys before publishing one successor. Segment identities advance
within that successor, including when one rewrite emits several segments.
DROP publishes a permanently retired successor; it preserves retained read roots
and receipts. These transitions and their receipts share the Table acceptance
record. Catalog name reservation and dependency checks remain the caller's duty.

Row mutation records use `row_delta`; declaration, operation control, checkpoint, pin and release records use
`manifest_checkpoint`. The action carries the exact neutral binding, complete
ordered mutation digest, ingestion choice and outcome, or the affected pin owner
and immutable basis. An accepted mutation publishes its result and all four row
indexes (hash, physical, identity and full-key order) atomically. Outcomes carry mandatory `matched`, `affected` and `live_rows`
counts with the accepted position; `affected` cannot exceed `matched`. Identical
canonical row replacements retain their locators and logical-change frontier.
Root `next_lsn` equals frame LSN plus one. Control/physical
records preserve `changed_lsn`. Recovery verifies contiguous positions, chain
links, stable partition/object identity, permitted definition succession and
top-level page roots before serving. It loads the exact accepted declaration;
row reads compare row-schema fingerprints, independently of naming revisions.
Descendants are checked when read. There is no scan for an independently
published latest manifest and no fallback to another payload definition.

Each `TreeStore` object is `TDIX`, byte `1` and three zero bytes at `0..8`, the
mandatory definition at `8..40`, then the core generic immutable-page encoding.
Its key is `data-index/<SHA-256(payload)>.data`. References bind both the logical
page digest and that content address. Pages hold at most eight leaf records or
32 branch children, have at most 32 levels and encode within 24 KiB. Caller
cache and candidate-work budgets are independent of durable record count.

The point index key is the SHA-256 of the complete collation-aware storage key
(or keyless row identity). The full decoded key is checked on access; collision
is an error. Its 49-byte value contains kind (`1` WAL, `2` segment), little-endian
`u64` LSN/segment ID, `u32` row offset, `u32` byte length and a 32-byte digest.
For WAL rows, offset is relative to the acceptance payload's row suffix and the
digest covers the encoded row. For segment rows, offset is the footer's global
row ordinal; length/digest identify the immutable `.tseg` object. Segment keys are
`table-segments/<digest>.tseg`.

The scan index key is kind followed by big-endian `u64` LSN/segment ID and `u32`
offset. Its value is the 32-byte point key followed by the 49-byte locator.
Acceptance publishes all row indexes together; physical-order traversal does not
claim SQL sort order. Receipt keys are big-endian principal/operation `u64` pairs
within the owning Table. Their values are the little-endian accepted frame LSN.

Operation and pending indexes use the same principal/operation key and an
eight-byte little-endian control-frame LSN. Operation controls retain the exact
binding, immutable intent content, definition/frontier/logical-change basis,
phase (`admitted`, `rejected` or `cancelled`) and typed rejection reason. A new
control is admitted or rejected; an admitted operation can become terminal once.
An accepted mutation retains its admission evidence and removes pending work in
the same append that publishes its receipt. Terminal operations cannot reopen.
DDL requires an empty pending-operation index.

Frozen row work has `TDMLREQ1` at `0..8`, mandatory definition bytes at `8..40`,
and a little-endian `u32` metadata length at `40..44`. At most 4 KiB of JSON
metadata encodes binding, original stored declaration, ingestion, mandatory
`work` (`rows` or `statement`) and `u16` change count. The complete object fits
4 MiB and is addressed by its SHA-256 at `table-intents/<digest>.data`.
Statement work requires zero concrete changes and bulk ingestion. Its remaining
bytes are one complete FDM1 typed UPDATE/DELETE plan under the original schema;
the expected data frontier is mandatory. Row work contains ordered changes.
Each ordered change is either tag `1`, an expectation
byte (`0` absent, `1` present, `2` any), little-endian `u32` row length and typed
binary row; tag `2`, little-endian `u32` storage-key length and key bytes; or tag
`3`, little-endian `u32` original-key length and key bytes followed by a
little-endian `u32` replacement-row length and typed binary row. Replacement
preserves row identity, validates original keys and all destinations, and can
atomically exchange primary keys. No prefix is published when a destination
conflicts with a surviving row.
The admitted action restricts the permitted change shapes. Typed binary rows
preserve supported finite floating-point bits. Staging has no admission effect;
missing or altered retained bytes cannot be replaced during execution.

An optional expected data frontier is checked exactly at admission. Execution
checks the retained definition and logical-change frontier from that admission,
so intervening control records or flushing do not invalidate the work. A new
logical data change rejects conditional work. An absent expected data frontier
does not imply predicate-conflict detection or a consistent multi-source cut.
Catalog-wide operation-to-target binding remains the enclosing catalog's duty.

Snapshot objects have `TPINOBJ1` at `0..8`, mandatory definition at `8..40`,
little-endian metadata/schema lengths at `40..44` and `44..48`, up to 16 KiB JSON
owner/read-root metadata and up to 64 KiB encoded Table schema. Their keys are
`table-snapshots/<digest>.tman`. The read root omits receipt/pin indexes. Content
length/digest, owner and interpretation are checked together. A pin-index key
uses the owner principal/operation pair; its value is one released byte (`0` or
`1`), little-endian `u64` object length and 32-byte digest. Acquisition and release
are accepted Table log transitions. Object existence alone is not a pin.

This component retains all WAL and immutable objects and exposes no physical
trim/GC operation. Pins preserve accepted unflushed rows, exact schema and both
row indexes across restart. Snapshot retirement does not claim physical deletion.
Its tests do not qualify catalog name publication, installed SQL, distributed transactions or
a collector racing with snapshots.

## Ordered full-key index component

`OrderedKeyIndex` maps nonempty byte keys of at most 4,096 bytes to 32-byte row
hashes. Key order is unsigned lexicographic byte order; callers supply the full
collation-aware storage key. The component does not infer a collation, accept a
mutation, retain a source or grant access. `TablePartitionRecord.Root.ordered_rows`
binds this directory to the accepted Table. Recovery verifies its top-level page
before exposing the root and verifies descendants on access. Flushes preserve
this mapping because its values identify keys independently of row placement.

Each level uses the existing immutable `TreeStore` pages with keys of up to 64
bytes. A full 64-byte chunk may have a child index for the remaining suffix;
a shorter chunk is terminal. A terminal sorts before every extension of that
key. Paths contain at most 64 levels and mutations use the caller's existing
`TreeStore.begin` encoded staging allowance. Earlier immutable roots retain their
own contents. Removing the last terminal also removes empty prefix nodes.

Each page entry's value is exactly 97 bytes: one flag byte, a 32-byte terminal
row hash, a 32-byte child logical digest and a 32-byte child content location.
Flag bit 0 denotes a terminal and bit 1 denotes a child; at least one is present
and every other bit is zero. Absent fields are zero-filled. A child on a partial
chunk or beyond the full-key length limit is invalid. The enclosing data page
retains its mandatory shared definition, logical digest and content address.

`seek` returns the first complete key satisfying optional inclusive/exclusive
lower and upper bounds. Empty intervals return no entry. Continuing uses the
returned key as an exclusive lower bound against the same root. Point reads and
seeks verify each traversed page; missing or corrupt pages are errors. These
operations do not collect all retained keys, promise a two-read lookup, or supply
an independently authoritative checkpoint.

## Segment range reader

`TSegReader` consumes the existing TSEG bytes without changing their definition.
The 64-byte header and 16-byte trailer must agree on the aligned footer range;
version, dimensions, identities and layout prefix agree with the checked footer.
Footer counts must fit their minimum encoded footprint before allocation.
Row groups cover the complete row count contiguously; page ranges are aligned,
ordered, non-overlapping and precede the footer. Primary-key entries have strictly
increasing sort keys and exact group/local/global row coordinates. Zone-map state
counts sum to the group size. The footer remains a complete sorted array.

The host binds one immutable object length/digest and supplies verified ranges.
Opening reads only header, trailer and footer. Each selected column page is
checked against its footer digest before decoding. Encoded page scratch and owned
decoded values have separate lifetimes; freeing scratch, closing the reader or
evicting its source does not invalidate returned values. Projection skips omitted
payload ranges. A caller-specified footer/page allowance bounds encoded buffers;
the owned group additionally bounds real decoder arena allocations. Corruption,
incompatible interpretation, transport failure or exhausted budget fails the read
without establishing an empty or complete query result. The reader acquires no
source pin or permission, and the service must recheck rights before disclosure.

## Local WAL persistence

`LocalWal.openDisk` holds an exclusive POSIX file lock for its directory. A second
owner fails with `WalInUse`; callers serialize operations within one owner.
The directory requires `.definition`, exactly the 32 decoded bytes of the shared
current contract identifier. A nonempty directory without it, or a foreign
identifier, rejects without conversion or reset. Empty-directory initialization
does not establish authority over an older installation.

Each partition has `part-<partition>.meta` and rolling
`part-<partition>-<first-lsn>.twal` segment files. Metadata is 128 bytes:

| Offset | Meaning |
| --- | --- |
| `0..8` | `LWMT`, byte `1`, three zero bytes |
| `8..40` | Mandatory current definition bytes |
| `40..48` | Partition ID, little-endian `u64` |
| `48..56`, `56..64` | Minimum writer and policy epochs |
| `64..72` | Exclusive trimmed prefix |
| `72..80` | Persisted exclusive accepted frontier |
| `80..96` | Reserved zero bytes |
| `96..128` | SHA-256 over `0..96` |

Append writes a bounded frame at the current segment offset, syncs the file and
new directory entry, then atomically replaces and syncs the metadata and its
directory before acknowledging. Existing segment bytes are not rewritten.
The frame's complete durable presence can precede acknowledgement: an error or
lost reply requires reconciliation of the original application operation.
Any uncertain disk mutation makes that open owner return `WalRecoveryRequired`;
it cannot continue from a guessed frontier.
Cancellation while loading an uncached partition before a disk mutation publishes
no cached descriptor and leaves the owner usable. Cancellation after recovery
starts truncating an incomplete tail still requires reopening the owner.

Opening validates every retained partition before returning an owner, including
partitions beyond the first directory page or the resident descriptor cache.
Recovery checks contiguous LSNs, frame integrity and the persisted frontier.
It reads one bounded frame at a time. Only an incomplete frame in the final
segment beyond the persisted frontier can be truncated; missing acknowledged
history, a damaged earlier segment and checksum failures reject. Complete frames
beyond the metadata frontier remain recoverable uncertain work. Missing metadata
does not turn existing segments into a new empty partition.

Epoch fences persist even without an append. Trim persists the exclusive floor
and frontier before removing complete prefix segments; a partially covered
segment remains until a later trim. Repeating the persisted floor resumes prefix
segment removal after interruption, including when the whole log is trimmed.
It does not advance the floor or grant permission to remove retained frames.
Trimming every frame preserves the next LSN and epochs.
Retention authority must establish checkpoint, receipt, pin and
logical-history coverage before calling trim. Disk pressure grants no permission
to trim, and this backend does not implement that higher-level retention owner.

The disk owner caches eight partition descriptors. Partition and segment counts
can exceed this cache. Defaults roll segments at 64 MiB and bound returned pages
to 1,024 frames and 8 MiB of encoded frame bytes. A single frame may exceed a
configured roll target, up to the 4 MiB payload bound. `openDiskWithOptions`
configures these operation bounds; the result page also owns bounded frame
descriptors. Ordered directory traversal uses constant resident memory but may
scan the directory repeatedly. No throughput claim follows from these bounds.

Within each cached partition, three volatile frame coordinates retain the latest
accepted frame and the start/continuation of the last read. They contain no
payload or authority. Sequential bounded pages resume at a verified offset and
stop immediately at their requested frame count; repeated latest-frame reads
do not decode the preceding segment again. Without a usable coordinate, one
directory pass locates the newest segment starting at or before the requested
LSN, then bounded frames are decoded to that position. This fallback is not a
persistent random-access index or a constant-I/O guarantee.

Recovery still validates the entire required retained history. Every returned
frame is read and integrity/identity checked again; stale/missing/corrupt bytes
cannot be supplied from a cached payload. Trim clears seek coordinates and
descriptor eviction discards them. No format, frontier, fence, sync or uncertain
append semantics change. Disk-owner counters `read_frames`, `read_bytes` and
`directory_scans` distinguish frame-read work from recovery and directory walks;
they do not count all filesystem metadata I/O or establish physical device reads.

`initMemory` supplies a separate volatile fixture limited to 64 partitions and
64 MiB of retained encoded frames. It does not qualify disk durability.

## Local object persistence

The local disk object owner requires the shared `.definition` marker and rejects
an unmarked nonempty directory. It publishes a fixed 512-byte descriptor under
`keys/<SHA-256(key)>`. This descriptor binds the original key, immutable or
conditional kind, payload length, payload SHA-256, chunk-checksum SHA-256 and the
current definition. Its last 32 bytes verify all preceding descriptor bytes.
The key is checked after lookup, independently of its filename hash.

Descriptors have `TOBJ`, byte `1` and three zero bytes at `0..8`; definition bytes
at `8..40`; kind (`1` immutable, `2` conditional) at byte `40`; little-endian key
length at `41..43`; zero reserved bytes at `43..48`; little-endian payload length
at `48..56`; payload and chunk-checksum digests at `56..88` and `88..120`; key bytes
at `120..120+length`; zeros through byte `479`; and descriptor SHA-256 at
`480..512`. Keys have no empty or `.` path components.

Payloads are raw immutable files in `objects/`, named by key and payload hashes.
They retain `.tseg`, `.tdel` or `.tman` suffixes when present in the logical key;
other payloads use `.data`. Each has a `.checks` file containing one SHA-256 per
64 KiB payload chunk. The descriptor commits the checksum file itself. Staging
links content without replacing an existing file and verifies an existing exact
copy on retry. All content is synced before its descriptor can become visible.

Every mutation holds the key's POSIX lock through reading the current descriptor,
testing the condition, staging content and atomically replacing/syncing the new
descriptor. Different keys use different locks. Immutable keys reject different
bytes and conditional replacement. `If-Match` compares the current content digest;
`If-None-Match` requires an absent descriptor. The linearization point for object
publication is descriptor replacement, with its directory synced before success.
This physical publication is not an application operation's acceptance record.
An error after replacement is uncertain; reread the owning application operation
and original intent, rather than treating a failed retry precondition as rejection.

Reads capture one descriptor and open its immutable content. They validate the
checksum file and each touched payload chunk, using a bounded scratch buffer;
they do not load or cache whole objects. Head returns committed descriptor
metadata. A missing descriptor is absence; missing/corrupt referenced content is
an error. The 32 MiB object limit gives at most 16 KiB of chunk hashes and a 64 KiB
chunk buffer, separately from the caller's output buffer and fixed metadata.

Delete unpublishes and syncs the descriptor under the same key lock. Content,
chunk hashes and lock files remain; superseded and staged content likewise remain.
Their physical collection requires an owner that accounts for retained roots,
uncertain publication and captured readers. This component does not infer safe
collection from absence of a live key or implement that retention authority.

The [process fixture](../tests/local_objects.py), run by the root unit task,
checks competing conditional/immutable publication through separate processes.
The [disk component cases](../packages/zig/transit-storage/src/disk_objects_test.zig)
cover bounded allocation, verified ranges, stale observations, definition rejection
and six sync failure points. They do not qualify filesystem rollback, distributed
locks, durable snapshot pins or installed catalog transactions.

## Native authority on local storage

The local native adapter owns one object directory and a `wal/` subdirectory.
A mandatory 64-byte `.native-owner` file contains `TNOWNER1` at `0..8`, the
shared definition at `8..40`, and zero bytes at `40..64`. Its exclusive lifetime
POSIX lock prevents independent native owners. Existing object history without
this marker rejects; a foreign or incomplete nonempty marker rejects. The
shared object and WAL markers retain their own validation responsibilities.

Native genesis and operation records are bounded JSON encodings of the core
`growing.Entry` in partition zero. Their frame kind is `genesis` at LSN zero and
`process_turn` subsequently. Frame writer epoch equals the published head's
storage epoch; policy epoch equals its authorization revision plus one. Expected
LSN and the native record position must agree. The append accepts the complete
catalog/policy roots, including resource state, input progress, outputs, effect
intents and exact retry evidence. Staged objects grant no visibility or rights.

Native pages and blocks have this object envelope:

| Offset | Meaning |
| --- | --- |
| `0..4` | `TNAT` |
| `4` | Byte `1` |
| `5` | ASCII `p` for a core page, `b` for an immutable block |
| `6..8` | Zero reserved bytes |
| `8..40` | Mandatory shared definition bytes |
| `40..end` | Core `TPG1` page bytes or the exact block body |

The logical key is `native/<kind>/<64 lowercase hexadecimal location bytes>`.
The 32-byte location is SHA-256 over `transit.local.native.object.v1` plus NUL,
definition bytes, kind byte, little-endian `u64` storage epoch and ordinal,
16 secure random candidate bytes, and the logical page/block digest. Reads check
both the envelope and that logical digest, in addition to object-store integrity.
No page or block reference grants access independently of native authorization.

`Storage.Limits` bounds candidate bytes and encoded-file allocation admission.
The core carries its control classification with the prepared transition through
commit; a later candidate cannot change its reserve eligibility. Reservations
remain conservative after uncertainty. Exclusive reopen counts actual file
lengths with bounded directory traversal. These are encoded-file bounds, not a
filesystem block or inode quota. Current local object retention keeps staged and
superseded content, so admission can eventually stop at the configured quota.

The latest accepted native WAL entry is the recovery root. A native accepted
history floor can authorize trimming older frames while retaining that entry.
Exact retry records and durable captures remain in its catalog. This adapter's
trim does not collect objects or dispatch effects. Standalone payload publication,
retained-root physical collection and installed runtime composition are separate
owners; the adapter alone does not establish those capabilities.

## `.tseg` (`TSEG` v1) hybrid segment layout

A `.tseg` segment stores immutable rows sorted by their composite primary-key
collation sort key. A Table without a primary key instead uses the big-endian
20-byte `TableRow.Identity` as its storage key. Identical cell values in different
rows remain distinct; repeated identities within a segment reject. Keyless
point reads/deletes require that identity, not an empty primary key.

1. **Header (`64 bytes` at offset `0`)**: `"TSEG"`, version `1` (`u32`),
   `segment_id` (`u64`), `object_id` (`u64`), `schema_revision` (`u64`),
   `total_rows` (`u32`), `group_count` (`u16`), `column_count` (`u16`),
   `footer_offset` (`u64`), `footer_length` (`u32`), and the first 12 bytes of the
   schema's `layoutFingerprint`.
2. **Column Pages (`64-byte` aligned)**: For each row group and column, a
   `"TCP1"`, the mandatory 32-byte shared definition, u8 encoding, u32 row count,
   one state byte per row, state details and physical values. The page uses the column's declared
   `TableSchema.Encoding` (`plain`, `bitpacked`, `rle`, `dictionary`, `fsst`,
   `comp`, `comp_3`, `zoned`, `ibm_hfp`, `ebcdic`), preserving all five cell states
   (`value`, `null`, `missing`, `type_error`, `conflict`).
   The decoder requires the exact definition and encoding, at most 65,536 rows,
   complete framing with no trailing bytes, valid run/dictionary bounds and
   non-overflowing bitpacked offsets. The
   [schema representation profile](TABLE_SCHEMA_V1.md#physical-representation-and-collation)
   defines admissible types and lossless value constraints.
3. **Footer (`"TSF1"`, `64-byte` aligned at `footer_offset`)**:
   - Mandatory 32-byte shared contract definition immediately after `"TSF1"`.
   - Segment metadata and full 32-byte `layout_fingerprint`.
   - Segment-wide `[min_pk_sort_key, max_pk_sort_key]` bounds.
   - Per-row-group page offsets, lengths, SHA-256 digests, and collation-aware
     `ZoneMap`s (`min_sort_key`, `max_sort_key`, 5-state counts, 64-bit Wyhash
     `bloom_mask`).
   - Embedded Primary-Key B-Tree directory (`pk_sort_key`, `TableRow.Identity`,
     `row_group`, `row_in_group`, `global_row_offset`) enabling $O(\log N)$ point
     lookups and $O(1)$ / $O(K \log N)$ OCC primary-key overlap detection.
   - Trailing 32-byte SHA-256 over the `"TSF1"` footer body.
4. **Trailer (`16 bytes` at `EOF - 16`)**: `footer_offset` (`u64`),
   `footer_length` (`u32`), and `"TSEG"`.

## `.tdel` (`TDEL` v1) deletion vectors and `TMAN` v1 manifests

- **`.tdel` deletion vectors**: Begin with `"TDEL"` + `0x01`, mandatory 32-byte
  shared contract definition, `segment_id` (`u64`),
  `total_rows` (`u32`), `deleted_count` (`u32`), strictly ascending `u32` deleted
  row offsets, and a trailing 32-byte SHA-256 digest.
- **`TMAN` v1 table manifests**: Begin with `"TMAN"` + `0x01`, mandatory 32-byte
  shared contract definition, `catalog_id` (`u64`),
  `object_id` (`u64`), `manifest_version` (`u64`), `schema_revision` (`u64`),
  `layout_fingerprint` (`[32]u8`), `writer_epoch` (`u64`), `policy_epoch` (`u64`),
  `flushed_lsn` (`u64`), `live_row_count` (`u64`), the array of active
  `SegmentDescriptor`s, and a trailing 32-byte SHA-256 digest. Published to
  `manifest/<object_id>/v<N>.tman` via `TransitObjectStore.putConditional` with
  `.if_none_match`.

Segment point lookups validate the supplied object, schema revision and layout
before index pruning, including a key miss. Deletion vectors must match the
segment identity and row count. `TableMemtable` point reads use an inclusive WAL
position and reject `SnapshotNotRetained` when that position predates the active
manifest's flush frontier. This guard prevents substituting current data for an
older snapshot; it does not provide durable retained snapshot ownership.
