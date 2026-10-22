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

Every `TransitLog` frame begins with a 64-byte little-endian header followed by
`payload_len` bytes of payload and zero-padding to a 64-byte boundary:

| Offset | Size | Type | Description |
| --- | --- | --- | --- |
| `0..4` | 4 | `[4]u8` | Magic `"TWAL"` |
| `4` | 1 | `u8` | Format version (`1`) |
| `5` | 1 | `FrameKind` | `1 = genesis`, `2 = policy_control`, `3 = row_delta`, `4 = catalog_ddl`, `5 = process_turn`, `6 = manifest_checkpoint` |
| `6..8` | 2 | `u16` | Reserved flags (`0`) |
| `8..16` | 8 | `u64` | `partition_id` (`0` reserved for Control & Policy Log; `>= 1` for data-plane partitions) |
| `16..24` | 8 | `u64` | `writer_epoch` (`>= 1`, monotonically non-decreasing per partition) |
| `24..32` | 8 | `u64` | `policy_epoch` (`>= 1`, monotonically non-decreasing per partition) |
| `32..40` | 8 | `u64` | Partition-scoped contiguous `lsn` |
| `40..48` | 8 | `u64` | `timestamp_ms` |
| `48..52` | 4 | `u32` | `payload_len` (`<= 4 MiB`) |
| `52..56` | 4 | `u32` | `crc32c` (`CRC-32/ISCSI` over header bytes `0..52` followed by `payload`) |
| `56..64` | 8 | `[8]u8` | First 8 bytes of `SHA-256(payload)` |

Reserved flags must be zero. Checksums do not establish permission or an accepted
application operation; the owning acceptance record supplies that binding.

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

Recovery checks contiguous LSNs, frame integrity and the persisted frontier.
It reads one bounded frame at a time. Only an incomplete frame in the final
segment beyond the persisted frontier can be truncated; missing acknowledged
history, a damaged earlier segment and checksum failures reject. Complete frames
beyond the metadata frontier remain recoverable uncertain work. Missing metadata
does not turn existing segments into a new empty partition.

Epoch fences persist even without an append. Trim persists the exclusive floor
and frontier before removing complete prefix segments; a partially covered
segment remains until a later trim. Trimming every frame preserves the next LSN
and epochs. Retention authority must establish checkpoint, receipt, pin and
logical-history coverage before calling trim. Disk pressure grants no permission
to trim, and this backend does not implement that higher-level retention owner.

The disk owner caches eight partition descriptors. Partition and segment counts
can exceed this cache. Defaults roll segments at 64 MiB and bound returned pages
to 1,024 frames and 8 MiB of encoded frame bytes. A single frame may exceed a
configured roll target, up to the 4 MiB payload bound. `openDiskWithOptions`
configures these operation bounds; the result page also owns bounded frame
descriptors. Ordered directory traversal uses constant resident memory but may
scan the directory repeatedly. No throughput claim follows from these bounds.

`initMemory` supplies a separate volatile fixture limited to 64 partitions and
64 MiB of retained encoded frames. It does not qualify disk durability.

## `.tseg` (`TSEG` v1) hybrid segment layout

A `.tseg` segment stores immutable rows sorted by their composite primary-key
collation sort key (`Collation.encodePrimaryKeySortKey`):

1. **Header (`64 bytes` at offset `0`)**: `"TSEG"`, version `1` (`u32`),
   `segment_id` (`u64`), `object_id` (`u64`), `schema_revision` (`u64`),
   `total_rows` (`u32`), `group_count` (`u16`), `column_count` (`u16`),
   `footer_offset` (`u64`), `footer_length` (`u32`), and the first 12 bytes of the
   schema's `layoutFingerprint`.
2. **Column Pages (`64-byte` aligned)**: For each row group and column, a
   `"TCP1"` physical column page encoded with the column's declared
   `TableSchema.Encoding` (`plain`, `bitpacked`, `rle`, `dictionary`, `fsst`,
   `comp`, `comp_3`, `zoned`, `ibm_hfp`, `ebcdic`), preserving all five cell states
   (`value`, `null`, `missing`, `type_error`, `conflict`).
3. **Footer (`"TSF1"`, `64-byte` aligned at `footer_offset`)**:
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

- **`.tdel` deletion vectors**: Begin with `"TDEL"` + `0x01`, `segment_id` (`u64`),
  `total_rows` (`u32`), `deleted_count` (`u32`), strictly ascending `u32` deleted
  row offsets, and a trailing 32-byte SHA-256 digest.
- **`TMAN` v1 table manifests**: Begin with `"TMAN"` + `0x01`, `catalog_id` (`u64`),
  `object_id` (`u64`), `manifest_version` (`u64`), `schema_revision` (`u64`),
  `layout_fingerprint` (`[32]u8`), `writer_epoch` (`u64`), `policy_epoch` (`u64`),
  `flushed_lsn` (`u64`), `live_row_count` (`u64`), the array of active
  `SegmentDescriptor`s, and a trailing 32-byte SHA-256 digest. Published to
  `manifest/<object_id>/v<N>.tman` via `TransitObjectStore.putConditional` with
  `.if_none_match`.
