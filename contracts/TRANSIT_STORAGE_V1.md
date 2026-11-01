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
| `.tseg` segment | `"TSEG"` + `1` (`u32`) | 64 bytes | 16 MiB | Per-page SHA-256 + `"TSF1"` footer SHA-256 |
| `.tdel` deletion vector | `"TDEL"` + `0x01` | 1 byte | 512 KiB | Trailing 32-byte SHA-256 |
| `.tman` table manifest | `"TMAN"` + `0x01` | 1 byte | 512 KiB | Trailing 32-byte SHA-256 + `If-None-Match` conditional CAS |

Table payloads use the acceptance records defined below. The current shared
definition has no standalone `TRDL` row-delta interpretation. The generic
`row_delta` frame kind remains available to log owners; it does not select a
Table payload decoder. Earlier shared definitions reject at the directory and
frame gates without conversion or reset, including artifacts from the earlier
paged Table owner. See the [cutover policy](../docs/handbook/reference/versioning.md).

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

## Transaction directory and decision records

The storage components use the neutral [transaction bindings](DATA_LIFECYCLE_V1.md#transaction-bindings-and-evidence).
Their [integration contract](../packages/zig/transit-storage/docs/transaction-decisions.md)
separates these formats from installed transaction execution.

`TableWorkspace.State` is an internal owned descriptor of private evaluation:
mandatory `definition`, exact `begin`, retained `source`, private Table/KV `root`,
`last_statement`, `changed`, `matched` and `affected`. Its positions describe private evaluator progress,
not Table WAL acceptance. The evaluator accepts bulk immutable row storage and
returns transaction-attributed provisional counts or rejection. It cannot export
an accepted Table recovery hint. Restoration requires the original live pin;
rollback retains consumed statement/operation identities. The embedding owner
must publish and retain the descriptor and its referenced pages before it becomes
durable work. The descriptor alone defines no installed workspace wire protocol,
collector root or transaction decision. The catalog workspace owner publishes
these states through its [reserved records](DIRECT_TABLE_V1.md#durable-client-token-bindings)
and extends the retained graph to private rows, receipts, operations and intents.
Its private evaluator positions are never used as accepted recovery baselines.
`executeKV` shares the KV owner's typed lowering and uses bulk immutable row
storage in the same workspace. KV put/remove requests retain their exact kind,
conditional writes, key/value limits and original operation identities.

`TransactionDirectory` objects start with `TXDIR1` followed by two zero bytes,
then the mandatory 32-byte shared definition at offsets `8..40`, then canonical
typed JSON. Total object size is at most 16 KiB. Canonical JSON uses declaration
order, explicit nulls and integer arrays for fixed byte arrays. Decoding rejects
noncanonical bytes, missing/foreign definitions and invalid scope. Objects are
addressed as `transaction-directory/<sha256>.data`, where the digest covers the
entire encoded object. The object descriptor's size and digest must match.

A root stores `definition`, transaction identity, directory kind (`participants`,
`preparations` or `sources`), optional immutable B-tree root, entry count and write count.
An entry is a tagged neutral participant, preparation, or acquired source
(`guard` and owner-issued `pin`). A source pin's owner must equal the original
begin operation; source directories have zero writes. Tree keys encode the
nonzero object ID as eight big-endian bytes, a one-byte ordinal-presence flag
(zero or one), then a four-byte big-endian logical partition ordinal. A null
ordinal requires four zero bytes; it is distinct from ordinal zero. All keys
have 13 bytes. State targets require null; log targets require an ordinal.
Kinds are verified against entries and cannot differ across one object's
ordinals. Values encode the object byte length
as eight little-endian bytes followed by its 32-byte digest. Tree pages retain
their ordinary definition/digest checks. Entry kind and identity must match the
root, and its object ID and ordinal must match the key. Count is durable cardinality, not
resident capacity. Sealing a root grants no acceptance or retention authority.

Read-only log dependencies have no action directory. A nonempty log action
directory groups appends and settlements under one physical owner's guard;
it contributes one write and requires one exact preparation. Acquired guards
and prepared predecessors are kind-specific. Complete membership validation
checks these neutral shapes, while the current decision journal and catalog
require executable Table or direct KV participants. Other shapes do not enable
public log transaction selection, append reservations, common visibility or terminal transfer.

`LogTransactionActions` metadata uses `TXLACT1` followed by one zero byte,
the mandatory definition at `8..40`, and canonical typed JSON within 16 KiB.
`transaction-log-actions/<sha256>.data` binds the complete encoded object.
An action object contains mandatory `work` (`Transaction.LogAction`) and
`offset_cursor` fields. The cursor is non-null exactly for Stream offset work;
its coverage and principal must match that work. Its original read handle and
authentication bytes are preserved for the partition owner's verification.
A root stores
`definition`, `identity`, exact `guard`, optional `entries` and `operations`
tree roots, `count`, cumulative `payload_bytes`, and optional `last` containing
the final cursor and statement intent. Empty roots have no trees or final cursor.
Entry keys are a nonzero eight-byte big-endian statement sequence followed by
a nonzero four-byte big-endian ordinal; values use the directory content
descriptor encoding above. Operation-index keys are eight-byte big-endian
original operation IDs, with the exact twelve-byte entry key as their value.
All operations share the root's transaction principal and scope. Duplicate
operations or conflicting bytes at an existing cursor reject.

Payload objects are exact append bytes at
`transaction-log-payload/<sha256>.data`. Their digest and byte count are the
append's content identity, and their size is bounded by the ordinary log batch
format. Directory metadata does not inline payloads. Explicit action and payload
quotas bound admitted private work independently of index-cache residency.
The statement owner must retain this graph, verify payload schemas and complete
statement membership, and preserve consumed identities across savepoint rollback.
No object in this directory establishes an append reservation, lease settlement,
partition preparation or transaction decision.

`LogTransaction.Source` uses `TXLSRC1` followed by one zero byte, the mandatory
definition at `8..40`, and canonical typed JSON within 64 KiB total. The address
is `log-tx-sources/<sha256>.data`. Required fields are `definition`, transaction
`identity` and the complete `LogPartitionRecord.Root`. The source must be live,
have no preparation reference and have a null transaction-pin directory. Its
identity must match the declared object's scope and branch. Loading checks the
entire content identity, mandatory definition, canonical encoding and exact pin
owner before returning owned fixed-size fields.

Partition roots carry mandatory `changed_lsn`, `transaction_pins` and nullable
`transaction` fields. A transaction-pin directory uses the ordinary sixteen-byte
big-endian principal/operation keys. Each value has exactly 41 bytes: released
flag (zero or one), eight-byte big-endian source length, and source SHA-256.
The `transaction_pin` and `transaction_release` actions bind the original
`Transaction.Pin`; each acceptance changes only its directory, physical frontier,
maintenance bookkeeping and, on acquisition, the supplied current declaration.
Recovery verifies the predecessor cut and source on acquisition, and the exact
original live content on release. Neither action changes `changed_lsn`.

Logical append, assignment, offset, claim, settlement, lease expiry, payload
expiry and compaction publication set `changed_lsn` to their accepted frontier.
Other physical/control actions preserve it. Recovery rejects a different logical
frontier. A live transaction pin retains its entire source graph under current
archive coverage; a released entry alone does not retain that source. Older
accepted replay roots retain their own live entries independently. These storage
operations do not admit public log transactions or confer settlement authority.

`TransactionDecisionLog` records start with `TXDEC1` followed by two zero bytes,
the same mandatory definition and canonical JSON within 16 KiB total. JSON stores
`definition`, previous-record SHA-256 and an event: `freeze` containing the exact
begin/attempt binding, or `decision` containing the original neutral decision.
They use `TWAL1` `policy_control` frames in one dedicated catalog-reserved
partition. The only accepted sequence is freeze at LSN 0, then optionally one
decision at LSN 1. The first previous digest is zero; the second hashes the entire
first payload. Decision position is that partition's exclusive frontier 2, and
its coordinator/policy epochs must equal the enclosing WAL header.

Commit requires complete exact preparation membership and the embedding owner's
held conflict, authority and participant-availability checks. Abort uses an empty
preparation directory and retains the complete potential-participant work list
in the original attempt. Neither terminal outcome can be overwritten. Incomplete
or inaccessible history cannot establish abort. Recovery verifies the exact
binding and all referenced directory evidence without staging or dispatching.
No trimming, compatibility conversion or automatic deletion is defined for
these records.

`TableTransaction` preparation objects use `TPREP1` plus two zero bytes, the
mandatory 32-byte definition and canonical typed JSON, within 64 KiB total.
`table-preparations/<sha256>.data` commits the entire object. Mandatory fields are
`definition`, `coordination`, exact journal `binding`, original logical `guard`,
actual accepted `predecessor` root and private `workspace` state. The Table/KV owner's
`transaction_prepare` action accepts its reference in the mandatory nullable
root `transaction` field. Preparation advances only the physical acceptance and
maintenance frontier; it preserves public data and logical change frontiers.

Ordinary recovery/read/write refuses an unresolved barrier. Component resolution
loads the actual coordination journal. Abort clears the barrier through
`transaction_abort`, retaining the exact preparation reference and abort decision.
Commit verifies exact prepared-directory membership and accepts a bulk aggregate
`mutation` with mandatory nullable `transaction` evidence (`prepared`, `decision`).
It replaces private data directories while preserving current public control
state. Each resulting `Receipt` and public `Evidence` has a mandatory nullable
`transaction` decision; autocommit/declaration receipts use explicit null.
Missing fields or a previous definition reject before replay. The aggregate
binding uses the original commit operation, UPDATE action and workspace digest;
this representation does not substitute UPDATE permission for original DML rights.
Current source/statement permissions are the catalog coordinator's obligation.
Prepared targets and predecessor guards preserve the actual Table/KV kind;
neither directory lookup nor journal recovery coerces KV evidence to Table.

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
catalog, branch, object, definition revision), a `u64` flags word (bit 0:
retired; bit 1: KV; every other bit must be zero), and `u32` property/schema
lengths. Its 104-byte header precedes up to
4 KiB of exact catalog-owned property bytes and up to 64 KiB of encoded Table
schema. Its key is `table-definitions/<digest>.data`. The complete byte hash is
the definition digest; the row-schema fingerprint is separate. Staging these
bytes publishes neither a definition nor a name.

The immutable descriptor and accepted root carry a mandatory `kind` (`table`
or `kv`). Recovery checks the selected kind before opening the latest record,
checkpoint or cached predecessor. It cannot change during definition succession.
The compact physical-interpretation mapping uses the same two flags in its final
byte; a live mapping cannot be retired. Missing JSON kind fields reject.

`KVDeclaration` and `KVPartition` use this common storage engine with a fixed
binary key column and a typed value column (`int64`, `boolean`, `utf8` or
`binary`, with declared nullability). These physical columns do not expose a
relational Table API. The complete canonical layout is validated on loading;
KV value types do not evolve through Table ALTER. Native writer PIDs and
`STATE_V1` values are absent from this storage owner.

KV keys contain 1–1,024 byte-exact bytes, including NUL. Text/binary values
contain at most 1,047,552 bytes, reserving the largest key within the shared
1-MiB logical-value budget. Missing/error/conflict cells reject; null requires
declared nullability. A batch contains 1–1,024 ordered put/remove changes under
the common encoded-row and candidate-memory budgets. Duplicate keys reject.
One accepted WAL record publishes the complete batch, original binding, ordered
change digest and matched/affected counts. A retry with changed changes conflicts.
Physical flush/archive/checkpoint work preserves the logical conflict frontier;
resource-wide read guards also protect absent keys. Retained cuts and receipt
recovery use the same accepted pins, archives and checkpoints as Table storage.
Decoded values own their output across later reads or mutations. Authorization
is supplied by the database adapter and held again through publication.

This storage owner does not itself publish catalog names or a caller route.
The [named KV lifecycle](DIRECT_TABLE_V1.md#direct-kv) uses this partition.
The shared catalog transaction owner composes Table and KV workspaces under one
decision. Ordinary KV batches remain single-partition operations.

RENAME preserves row interpretation and indexes. ALTER streams the accepted
source into bounded segments and private replacement indexes, validating all
rows and new keys before publishing one successor. Segment identities advance
within that successor, including when one rewrite emits several segments.
DROP publishes a permanently retired successor; it preserves retained read roots
and receipts. These transitions and their receipts share the Table acceptance
record. Catalog name reservation and dependency checks remain the caller's duty.

Row mutation records use `row_delta`; declaration, operation control, segment checkpoint, archive, recovery checkpoint, pin and release records use
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
within the owning Table. Their values reference compact original evidence, as
specified below.

Operation and pending indexes use the same principal/operation key and an
identical compact evidence reference. Operation controls retain the exact
binding, immutable intent content, definition/frontier/logical-change basis,
phase (`admitted`, `rejected` or `cancelled`) and typed rejection reason. A new
control is admitted or rejected; an admitted operation can become terminal once.
An accepted mutation retains its admission evidence and removes pending work in
the same append that publishes its receipt. Terminal operations cannot reopen.
DDL requires an empty pending-operation index.

### Compact Table outcome and operation evidence

`TableEvidence` stores original outcomes and operation controls independently of
their complete accepting WAL frames. Receipt, operation and pending index values
are exactly 40 bytes: an eight-byte little-endian object length followed by its
complete 32-byte SHA-256. Eight-byte historical LSN pointers reject. The shared
current definition changes with this stored interpretation; there is no fallback
to the earlier index layout.

The immutable object at `table-evidence/<digest>.data` contains `TEVID1` and two
zero bytes at `0..8`, mandatory shared definition bytes at `8..40`, then at most
16 KiB of JSON metadata. Metadata has an exclusive accepted `position` and a
tagged `evidence` value:

- `receipt` contains the complete original `binding`, ordered `changes` digest
  and `outcome` inside `receipt`, the original `resulting` stored declaration,
  and `ingestion` (`point`, `bulk` or `declaration`).
- `operation` contains the complete original operation control, including its
  frozen intent, interpretation/data basis, phase and reason.

These objects have no row, archive, recovery or pin directories. Outcome evidence
retains the original declaration; operation evidence retains its frozen intent.
Neither requires retaining an otherwise obsolete row payload merely to recover
an accepted outcome. Unlimited logical history, current/unflushed rows and
retained snapshots can independently require the same WAL/archive frames.

Staging evidence creates no acceptance. The same Table WAL append publishes its
index entry, row changes and pending-work transition. Publication and recovery
check that the indexed length/hash equals the canonical evidence derived from
that exact accepting record. Observations validate content length/hash,
definition, original identity and accepted position against the current owner,
under current authorization. Missing or corrupt evidence fails without falling
back to WAL bytes or substituting the current declaration. Failed staging leaves
the accepted root unchanged; lost acknowledgements recover the original result.
This representation does not itself authorize physical deletion.

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

This component retains complete logical history by default and retains immutable
objects. It can move accepted WAL records to an immutable archive and remove
covered WAL files. The separate explicit history-floor operation controls logical
expiry. Pins preserve accepted unflushed
rows, exact schema and row indexes across restart. Snapshot retirement does not
claim object deletion. Automatic scheduling and immutable Table-object collection
are separate from the archive mechanism.

### Table build memory

`TablePartition.Options.build_resident_bytes` bounds simultaneous requested
backing allocations for one concrete mutation, retained operation execution,
definition rewrite or flush. It defaults to 64 MiB and must be nonzero. It includes
retained intent decoding during execution, canonical encoders, private rows and
vectors, segment construction and arena slack. Whole-Table rewrites release each
bounded group's private allocations before building the next. The current
accepted declaration and caches use their owning allocator; no object that
survives the operation retains the private workspace allocator.

`build_resident_peak` records the last such attempt's high-water allocation count.
Caller-owned input, the separately bounded persistent declaration, segment-reader
caches, index work, publication buffers and provider memory are separate; the
private allocation count is not whole-process resident memory. This setting
limits a work attempt, never the durable number of rows, receipts or objects.

Configured exhaustion returns `TableBuildBudget` before accepting a candidate.
`perform` records an admitted operation's existing `work_limit` rejection with its
original binding and no row/definition change. Actual parent allocation failure
remains `OutOfMemory` and does not authorize that terminal outcome. The allocator
classifies its latest attempt, so an earlier refused resize followed by another
allocation cannot relabel unrelated resource failure. A caller's attempt result
still follows the ordinary uncertain-dispatch and exact-observation rules.

### Table segment compaction

`TablePartition.compact` takes an exclusive segment-ID boundary captured from an
accepted `next_segment`. It rewrites live segment rows below that boundary into
one new segment per call and publishes replacement point/physical locators with
a `compaction` action. Stable identity/full-key indexes and every logical/control
root remain unchanged. WAL rows and newer segments are excluded. The published
segment ID is at or above the fixed boundary, so repeating the same pass after a
lost reply or restart cannot select its own prior output. A bounded metadata
lookahead determines `complete` before acceptance; no post-acceptance read is
needed to construct the response.

The call admits at most 1,024 rows, at most the existing Table encoded-row byte
bound, and explicit private resident allocation. It uses the existing index-work
and reader-cache budgets separately. The private allocator charges actual blocks,
including arena slack, and returns capacity on free. Input rows own their decoded
values; output staging cannot borrow a cache that a later row read replaces.
Budget failure or denied publication publishes no partial relocation. A control
adapter can reserve physical staging/append capacity. This API rejects retired
Tables and performs no object deletion or logical expiry. Liveness comes from the
accepted paged row directory: removed/replaced rows are omitted from new segments,
while older retained roots keep their original segment references.

### Table logical history floors

Every accepted Table root and saved snapshot root has mandatory `history_floor`
(`u64`) and `history_pins` (nullable immutable page reference) fields. A new Table
starts at floor zero with no history leases. Missing fields reject; this layout
uses the replacement shared current-v1 definition. No earlier stored root gains
an implicit floor or empty lease index.

`TablePartition.expireHistory(through, guard)` is an explicit one-off opt-in to
logical expiry below a fixed partition/frontier. Its adapter must require
maintenance authority. The owner checks current authorization before work and
again at append, uses the optional control reserve, and accepts a `history_floor`
transition through the same Table WAL. The requested frontier must be accepted,
covered by the published archive and covered by a published recovery checkpoint.
It cannot exceed the original frontier of any live history lease. The floor is
monotone; retrying an already covered request returns the current floor without
another append. A lost acknowledgement requires recovery/observation as for
other Table acceptance operations. Physical maintenance, quota exhaustion and
ordinary mutations never advance this floor implicitly.

The history-lease index uses bounded `TreeStore` pages. Its 24-byte keys contain
big-endian `u64` original exclusive frontier, principal and operation, in that
order. Values use the existing unreleased 41-byte pin encoding. Acquisition and
release update this directory and the owner-keyed pin directory in one accepted
transition. Finding the oldest lease visits a bounded page path, independently
of retained lease count. Saved snapshot roots clear both pin directories; they
do not recursively retain other owners' pins. Recovery checks lease transitions
and refuses a floor transition across the indexed oldest live lease.

`history` reports `TableHistoryExpired` when its starting cursor is below the
current floor, including an empty interval. Current authorization is checked
before reporting that expiry. Live history leases preserve their original root
and all successors; ordinary snapshot pins retain their exact values below the
history floor. Current rows, schema, original operation receipts and admitted
work are unchanged. Expiry does not delete archive records, immutable objects or
WAL files. Physical collection must separately prove every remaining dependency.
The installed service exposes no automatic Table history-expiry policy.

### Table history archives

Every accepted Table root and saved snapshot root contains a mandatory `archive`
object with `through` (exclusive `u64` LSN) and `directory` (nullable immutable
page reference). Zero coverage requires a null directory; nonzero coverage requires
a directory and is strictly below the enclosing root's `next_lsn`. Missing fields
reject; the shared current-v1 definition changes with this stored layout.

An archive directory uses the same bounded `TreeStore` pages. Keys are eight-byte
big-endian LSNs. Each 36-byte value is the little-endian `u32` complete frame size
followed by its SHA-256. Its object key is `table-history/<digest>.twal`; its bytes
are exactly one complete, aligned `TWAL1` frame, including original partition,
epochs, timestamp, kind, payload and checksums. Reads verify descriptor length,
whole-object digest, current definition, frame integrity, partition and LSN.

`TablePartition.archive` moves a contiguous prefix towards a caller-specified
accepted frontier. One call stages at most eight frames, with explicit frame and
encoded-byte budgets, one input/output frame pair resident, and the existing
index cache/candidate bounds. Its archive objects and directory are durable before
one `archive` acceptance record publishes the new coverage. Coverage advances by
one through eight records and never exceeds the previous accepted frontier.
The transition preserves definitions, rows, receipts, pins, operation state and
`changed_lsn`. It may run after Table retirement. An uncertain publication requires
recovery of the original frontier; unpublished objects cannot establish coverage.
The optional control adapter supplies reserved staging/append capacity.

`trimArchived` checks current authority and removes only the WAL prefix below
accepted coverage, preserving the latest acceptance record. Repeating the call
resumes interrupted physical removal. The local native `DataStore` independently
checks the requested floor against the latest Table record while holding its
physical-owner mutex; a caller cannot substitute the WAL tail for coverage.
Reservations for removed WAL files remain conservative until exclusive reopen.

Recovery obtains archive and optional recovery-checkpoint coordinates from the
latest accepted WAL record. Without a recovery checkpoint it replays the complete
contiguous hash-linked chain from zero through archive plus WAL; with one it
validates the published baseline and every later transition as specified below.
It exposes no state before those checks succeed. Retained unflushed rows and
logical history use the latest physical directory, including when their saved
roots predate archival. Original receipts and operation controls use their
separate compact evidence. Missing required archive data fails closed; no
fallback, implicit reset or skipped cursor prefix is allowed. Archive publication
creates no logical changefeed event. Unlimited history is the default; advancing
an explicit logical floor is a separate acceptance transition. Neither operation
authorizes archive, segment or index-object collection by itself.

The archive directory records historical placement, not perpetual ownership of
every value. After explicit logical expiry, complete owner-graph collection may
remove a frame below the floor only if no selected recovery baseline/replay,
current or retained row locator, live history anchor or other retained root needs
its bytes. Directory pages remain retained. A saved snapshot resolves row locators
through the current accepted directory; its older archive coverage does not pin
the entire old archive. Missing bytes for a required frame still fail closed.

### Table recovery checkpoints

Every accepted root and saved snapshot root has a mandatory `recovery` field:
null or `{next_lsn, content}`. A reference requires `0 < next_lsn < root.next_lsn`
and a content length greater than 40 and at most 16,424 bytes. Missing fields
reject. The content-addressed key is `table-checkpoints/<digest>.tman`. Its bytes
are `TCHECK1` followed by a zero byte at `0..8`, the mandatory current definition
at `8..40`, and JSON `{root, chain}`. The root is the complete accepted state at
the reference's exclusive frontier; `chain` is the SHA-256 of its last accepted
Table record payload. Row data remains behind the root's bounded directories.

`TablePartition.checkpoint(through, guard)` requires a nonzero accepted position
in this partition. If the current recovery reference covers at least that cut,
it returns the reference under current authorization without appending. Otherwise
it stages the current verified root and chain, rechecks current authority, then
appends a `recovery` action that publishes the reference. The action increments
only `next_lsn` and changes `recovery`; all logical, physical-row, receipt, pin,
archive and operation roots are preserved. It may run after Table retirement.
A new reference covers exactly the preceding accepted frontier and strictly
advances any previous reference. The optional control adapter supplies reserved
object/append capacity. Retry the same requested cut after a lost reply; an
uncertain WAL owner must reopen before Table recovery.

Recovery selects the reference only from the latest accepted WAL record. It
verifies the capsule's descriptor, length, whole-content hash, current definition,
root shape, partition, object and exact frontier. Starting from the saved root
and chain, it verifies that the first following record is the `recovery` action
publishing that exact reference. Every later record retains that reference;
normal contiguous-position, hash-chain, monotonicity and transition checks apply.
The exact declaration and every current top-level directory must load before
readiness. Missing or corrupt capsules fail closed without replay fallback.
Private staged capsules never become authority. A superseded capsule reference
inside the saved root is structural history, not a recursive recovery dependency.

`recovery_work` reports the selected checkpoint LSN and number of replayed Table
frames after successful recovery. It does not count LocalWal startup, object or
index I/O, and confers no authority. With frontier `N` and checkpoint `C`, Table
transition replay visits `[C,N)`, including the checkpoint publication. Without
one it visits `[0,N)`. Resident state holds one bounded capsule, one replay frame
at a time and the configured index cache; replay operation checks can perform
separate bounded historical lookups. LocalWal still validates its retained files.

Checkpointing changes neither logical history retention nor WAL trim authority.
Only accepted archive coverage permits `trimArchived`. Original receipt,
admission, unflushed-row and history dependencies remain retained. Historical
records before the checkpoint and descendant objects are verified when accessed;
restart is not an eager historical integrity scan. Missing required evidence is
an error, never a new operation, empty result or cursor advance. Data snapshots
omit recovery references together with control directories. There is no automatic
checkpoint scheduling or immutable Table-object collection in this component.

### Resumable Table maintenance targets

Every accepted Table root and saved snapshot root contains mandatory scalar
`maintenance` state. Missing state rejects under the replacement current-v1
definition. It records archive and compaction source activity, the completed
source activity for each class, and nullable fixed targets. These fields select
physical work; they grant neither access nor logical expiry or object deletion.
Snapshots retain the values at their original cut and never schedule work.

`archiveMaintenanceUnit(limits, guard)` accepts or advances one target. Its
`through_lsn` is the exclusive Table frontier when work begins; `source_lsn`
records the activity that selected it. The first accepted archive publication
covering that cut fixes `checkpoint_lsn`. Completion requires accepted archive
coverage and a recovery checkpoint covering that publication. A completed pass
records its original source and clears the target. Foreground acceptances,
pins/releases, logical history-floor changes, flushes and compaction advance the
archive source; archive, recovery and work bookkeeping do not. A finite workload
therefore settles without endlessly archiving its own progress records.

`compactionMaintenanceUnit(limits, guard)` captures the current exclusive
`next_segment` boundary and source activity, with mandatory `after_segment = 0`.
Each work unit examines at most two adjacent live segments after that cursor,
using at most `rows + 8` directory entries per candidate (including one page
of lookahead) and bounded footer reads.
It rewrites an entire segment only when at least half its original rows have
been removed/replaced, or merges two complete adjacent inputs that fit the row
and encoded-byte budgets. It never splits an input to satisfy those budgets.
Otherwise a `maintenance.skip_compaction` record advances `after_segment` over
exactly the next live segment. Acceptance and recovery verify that identity;
the record cannot jump over another live input. Row bytes, logical roots and
retention obligations remain unchanged by a skip.

Completion requires no unexamined live segment between `after_segment` and the
fixed exclusive boundary. Recovery repeats that check. Completion means the
pass considered its inputs under the work budgets, not that every segment was
rewritten, normalized to the current schema or physically collected. Oversized
inputs and a lone dense segment can remain. Later source activity selects a new
pass from the beginning; a budget change alone does not do so. Logical changes and
non-compaction segment publication can select another pass; compaction output
cannot. Retirement completes unfinished compaction without rewriting retained
rows. Later writes leave either active target unchanged and can select later
work after the current pass completes.

Each successful work call accepts at most one Table record. Starting and finishing
targets use `maintenance` actions; physical relocation uses `compaction`, while
ordinary flushing retains `checkpoint`. Acceptance and replay derive the exact
maintenance state from the action. No separate progress file can publish it.
Uncertain acceptance requires owner recovery; lost replies resume the accepted
target. Current authorization is checked even when a call finds no work. The
existing per-call archive, compaction, index and object budgets still apply;
this component does not bound live scheduler concurrency or select its cadence.

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

An encoded group can retain projected pages for repeated row selections. Its
total allowance covers page buffers and their directory; the exact schema
binding and group row count travel with that owner. Selected row ordinals must
be strictly increasing, unique and inside the group. Each selection validates
all page tags, details, values and framing, including skipped rows, and compares
the decoded row count with the footer. It returns only selected owned cells.
Dictionary/validation scratch and output arena blocks share the decoded budget;
compressed strings can require transient expansion even when unselected. A
successful selection owns all nested values independently of the encoded group.
These reader operations consume the existing bytes and do not change v1 formats.

`bufferedGroup` owns verified encoded pages together with column views. Plain
int64, uint64, float64, Boolean, UTF-8, binary and JSON columns reference aligned
value buffers directly; only error/conflict metadata is allocated for these
columns. Other plain logical types retain decoded metadata and borrowed byte
payloads, including recursive children. Other codecs retain bounded owned
decoding. The encoded allowance covers all projected
page buffers and their directory; the decoded allowance covers arena backing
and simultaneously live validation scratch. Complete page validation, exact
schema binding and footer row counts still apply. Releasing this group destroys
decoded metadata before encoded buffers. Its views outlive the source and reader
but not the group; cloning a cell creates independent output ownership.
`Group.columns` distinguishes decoded cells from qualified plain buffers and
supplies common `len`/`cell` access. A plain column's `arrowValues` borrows its
nullable Arrow value child and a caller-supplied buffer directory. All non-value
states are null in that child; the column's state tags and error/conflict details
remain necessary to preserve Transit cells. Retaining an Arrow borrowed buffer
does not retain the group. `TSegReader.SharedGroup` provides a separate explicit
owner: construction transfers the buffered group only on success, and each
returned Arrow value array retains that group. Array slices and C exports keep
the same ownership through the final release callback, without copying value
payloads. The buffer directory and reference headers are allocated through the
host allocator; all backing allocators must outlive their references. The host
enforces resident limits and its allocator's thread discipline. A value child
still requires the enclosing state/error/conflict metadata to represent full
Transit cells. Neither form acquires a durable
pin, authorization or complete-result evidence. Export requires little-endian
host interpretation and 64-byte-aligned buffer addresses.

`filteredGroup` accepts one typed column predicate and a projection. It validates
the schema/layout, predicate and all projected coordinates before using trusted
footer statistics. Value comparisons use the same declared collation as zone
keys; missing or oversized keys require ordinary evaluation. A group containing
error/conflict states cannot be skipped for a value or NULL comparison. State
predicates use the corresponding state count. Skipped groups require no payload
read; their footer metadata remains bound to the host's immutable source.

Candidate predicates produce one owned outcome byte per source row without
retaining decoded values. Dictionary values and RLE runs evaluate once; all page
framing and values are validated before outcomes return. NULL/missing truth stays
unknown, and eager errors/conflicts retain row position. A failed group returns
no cells and records its first semantic failure coordinate. Selected ordinals
remain in source order and only their projected cells are retained. Outcomes,
ordinals, dictionary/validation scratch and output share the decoded budget;
one transient encoded page has the separate page budget. Projection may reread
the predicate page after selection. These component operations do not change
source retention, apply deletion vectors, enforce a query LIMIT, grant access or
establish complete SQL results. The host retains those obligations.

`filteredProgram` generalizes selection to at most 64 eager postfix instructions
over column atoms. It uses the ordinary three-valued Boolean machine and a
conservative abstract interpretation of footer counts/ranges for pruning.
Possible errors in either operand prevent pruning even when the other operand
determines the truth. Unknown remains unknown under negation. Candidate atoms
retain separate row-outcome vectors under the decoded budget; physical column
evaluation order cannot supersede first failure by source row and instruction.
The error coordinate includes the original instruction. All atoms, including
repeated references to one column, retain full page validation. The projection
is decoded only after the entire predicate group succeeds.

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
| `80..88` | Exclusive physically cleaned prefix, no greater than the trim floor |
| `88..96` | Reserved zero bytes |
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
beyond the metadata frontier remain recoverable uncertain work. Recovery syncs
each segment containing such frames before adopting their frontier. Opening then
syncs the WAL directory before returning the owner, stabilizing observed segment
names and metadata replacements, including a trim floor whose previous owner
died before its directory sync. A failed barrier prevents a usable open owner.
Missing metadata
does not turn existing segments into a new empty partition.

Epoch fences persist even without an append. Trim persists the exclusive floor
and frontier before removing complete prefix segments; a partially covered
segment remains until a later trim. Repeating the persisted floor resumes prefix
segment removal after interruption, including when the whole log is trimmed.
It does not advance the floor or grant permission to remove retained frames.
Trimming every frame preserves the next LSN and epochs.
`LocalWal.trimUnit` publishes the same floor and performs at most 32 directory
entries or one verified frame, followed by at most one segment unlink and sync.
Completion atomically publishes and syncs the physically cleaned prefix in one
metadata replacement. This frontier records work already authorized by the trim
floor; it cannot advance that floor or authorize deletion. Repeating a completed
request does no further cleanup or completion writes, including after descriptor
eviction or restart. An interrupted completion publication requires reopen and
may repeat already completed cleanup safely.
It returns whether physical cleanup through that request is complete. Repeated
units preserve an earlier partition's unfinished cursor; `resumeTrim` can advance
that cursor without a new request. Directory changes restart unfinished minimum
selection. A continuous writer can delay that selection; finite work converges.
The cursor is volatile and bounded, with one independent directory handle per WAL
owner. Restart reconstructs unfinished work from the accepted floor. New appends never reuse
an obsolete segment after a complete logical trim, even before unlink completes.
When the resident verified append descriptor and current file length establish
that the selected active segment contains retained frames, cleanup keeps it
without rescanning its prefix. Evicted descriptors use bounded frame verification;
cleanup does not introduce a cold partition load just for that shortcut.
An uncertain unlink or sync poisons the owner until reopen. The synchronous
`Log.trim` operation drains these same units before returning.
Retention authority must establish checkpoint, receipt, pin and
logical-history coverage before calling trim. Disk pressure grants no permission
to trim, and this backend does not implement that higher-level retention owner.

The disk owner caches eight partition descriptors. Partition and segment counts
can exceed this cache. Defaults roll segments at 64 MiB and bound returned pages
to 1,024 frames and 8 MiB of encoded frame bytes. A single frame may exceed a
configured roll target, up to the 4 MiB payload bound. `openDiskWithOptions`
configures these operation bounds; the result page also owns bounded frame
descriptors. Recovery inventories the first/last segment positions and file
count in one constant-memory directory pass per loaded partition, then follows
the contiguous decoded LSNs to each successor filename. It checks the visited
count against the inventory so overlapping files cannot escape validation.
This is not a persistent segment index: each uncached partition still scans the
directory. A cold partition lookup in `trimUnit` retains that recovery cost;
its bounded physical cleanup does not establish a bounded cold lookup. No throughput claim
follows from these bounds.

The local owner's `nextPartition(after)` selects the least existing partition
ID strictly greater than the optional cursor. A null cursor includes partition
zero; exhaustion returns null without wrapping the largest `u64` ID. Empty
fenced and fully trimmed partitions remain discoverable through metadata.
Discovery scans both metadata and segment names with constant resident memory,
rejects noncanonical names, and verifies the selected partition's mandatory
metadata directly. A cached descriptor cannot hide missing metadata. Unpublished
atomic-file temporaries supply no partition identity. Each call requires caller
serialization; the cursor is not a snapshot and does not freeze membership or
authorize collection. Its directory I/O grows with the file count.

Within each cached partition, three volatile frame coordinates retain the latest
accepted frame and the start/continuation of the last read. They contain no
payload or authority. Sequential bounded pages resume at a verified offset and
stop immediately at their requested frame count; repeated latest-frame reads
do not decode the preceding segment again. Without a usable coordinate, one
directory pass locates the newest segment starting at or before the requested
LSN, then bounded frames are decoded to that position. This fallback is not a
persistent random-access index or a constant-I/O guarantee.
Crossing a segment boundary uses the verified next physical LSN to open its
successor directly, including when a caller jumps forward from a cached
end-of-file coordinate. Every traversed frame's partition and LSN are checked.

Recovery still validates the entire required retained history. Every returned
frame is read and integrity/identity checked again; stale/missing/corrupt bytes
cannot be supplied from a cached payload. Trim drops coordinates below its floor
and discards end-of-file continuations when that floor advances. Coordinates for
actual retained frames remain valid, including the latest-frame seek needed by
allocation collectors between cleanup units. Descriptor eviction discards them.
No format, frontier, fence, sync or uncertain
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
other payloads use `.data`. Payloads larger than 64 KiB have a `.checks` file
containing one SHA-256 per 64 KiB payload chunk. Payloads of at most 64 KiB derive the
chunk hash from the descriptor's payload hash; empty payloads have no chunks.
The descriptor commits the chunk-hash sequence in either case. Staging
links content without replacing an existing file and verifies an existing exact
copy on retry. All content is synced before its descriptor can become visible.
The payload and any checksum file each receive a file sync, followed by one shared
`objects/` directory sync covering their names. An observed existing name on
retry still requires content verification and synchronization. Descriptor
publication retains its own file and `keys/` directory barriers. These barriers
complete within each put; a lone writer does not wait for another operation.

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
chunk-hash sequence and each touched payload chunk, using a bounded scratch buffer;
they do not load or cache whole objects. Head returns committed descriptor
metadata. A missing descriptor is absence; missing/corrupt referenced content is
an error. The 32 MiB object limit gives at most 16 KiB of chunk hashes and a 64 KiB
chunk buffer, separately from the caller's output buffer and fixed metadata.

Delete unpublishes and syncs the descriptor under the same key lock. Content,
chunk hashes and lock files remain; superseded and staged content likewise remain.
Their physical collection requires an owner that accounts for retained roots,
uncertain publication and captured readers. This component does not infer safe
collection from absence of a live key or implement that retention authority.
`LocalSegmentStore.reclaimImmutableObject` supplies an explicit physical primitive
for an exclusive owner that has already established those facts and fenced
recreation. It checks any existing descriptor's immutable kind and exact metadata,
syncs descriptor removal before deleting the named content/checksum pair, and
syncs their directory before returning confirmed removed bytes. An allocation
intent supplies the identity when descriptor publication never completed.
Missing files make the same deletion idempotent; lock files remain.

`LocalSegmentStore.confirmImmutableObject` verifies an exact immutable descriptor,
the complete object bytes and chunk checksums without a PUT. It syncs the content
and checksum files, their directory, the descriptor file and its directory in
that order. Empty objects still require both files and exact zero lengths.
Failure cannot establish durable publication. This operation resolves readable
but uncertain immutable publication before a higher-level owner records readiness.

The [process fixture](../tests/storage/local/local_objects.py), run by the root unit task,
checks competing conditional/immutable publication through separate processes.
The [disk component cases](../packages/zig/transit-storage/src/disk_objects_test.zig)
cover bounded allocation, verified ranges, stale observations, definition rejection
and five sync failure points. They do not qualify filesystem rollback, distributed
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

Direct Table and catalog requests use nonzero WAL partitions. Their request
guard captures the storage epoch on its first successful authorization, before
private staging, and preserves it through publication. Reacquiring the native
authority lock rechecks current authorization and resource lifetime; it does not
renew that candidate's storage epoch. The local adapter rejects its append with
`StaleStorageEpoch` if a storage fence intervened. Retrying an unaccepted
operation requires fresh staging under the current epoch. Accepted operation
identity and receipts survive the fence. Read disclosure still checks current
authorization; a writer's stale epoch does not itself revoke read access.

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

Every native creation first appends an allocation intent to
`native-allocations/queue/`, a separate segmented `LocalWal`. FIFO records use
partition zero, writer/policy epoch one and `manifest_checkpoint` frames. Their
232-byte payload is `TNALQ1` plus two zeros at `0..8`, definition at `8..40`,
little-endian record position and consumed-prefix cursor at `40..48` and `48..56`,
an item-present byte at `56`, seven zeros, a little-endian source-activity counter
at `64..72`, and a 160-byte allocation at `72..232`
(all zero when absent). The payload position equals its LSN; the cursor cannot
exceed that position. Carrying a live item and advancing the cursor share one
append. At most 64 empty progress records can be collapsed by one cursor advance.
Consumed prefixes are physically trimmed only after their progress is durable.
New source allocation intents increment the activity counter in the same append.
Collection mark allocations, retained-item carries and empty-prefix progress
preserve it. Exact marker retries add no activity. The counter cannot exceed the
native counter bound or position plus one; trimming does not reset it.

An exact intent marker lives at
`native-allocations/<16 hex epoch>-<kind>-<64 hex location>`. Its 160 bytes contain
`TALLOC1` plus NUL at `0..8`, definition at `8..40`, little-endian epoch at `40..48`,
kind at `48`, seven zeros, location at `56..88`, little-endian object size at
`88..96`, object SHA-256 at `96..128`, and SHA-256 of `0..128` at `128..160`.
The FIFO append precedes marker publication, which precedes content creation.
Uncertain marker publication may leave duplicate FIFO intents; it cannot leave
untracked content. Creation checks the accepted native epoch under the publication
mutex, allowing the current epoch or the next epoch for a prepared fence and
rejecting older creators. Direct data access reserves the `native/` namespace.

Native creation holds a shared creation/reclamation fence through inventory and
immutable object publication. Its allocation queue has a separate mutex; the
native journal mutex protects the accepted-epoch check and quota reservation,
without covering private inventory or object syncs. Collection takes the
exclusive creation fence before consuming an allocation or deleting its object.
A creator paused after recording its intent cannot recreate content after the
collector has discarded that intent. These locks change no stored record or
acceptance boundary; native publication still checks its original expected head
and epoch independently of private staging.
Collection progress-file publication and reclamation syncs also run outside the
journal mutex. The collection mutex serializes progress; the exclusive creator
fence and inventory mutex protect deletion through FIFO consumption. Accepted
storage epochs are monotone. Their short validation and quota accounting remain
under the journal mutex, while independent direct acceptance and native reads
can proceed during those private maintenance syncs.

Direct-data creation and reuse have a separate mandatory `data-allocations/`
directory. Every object PUT first records its key, exact metadata and observed
native storage epoch. Existing immutable content reused in a newer epoch records
a new intent before confirming its bytes; an exact same-epoch retry syncs its
existing marker without appending another intent. Older epochs reject. A
conflicting key/content binding rejects even if the first attempt did not finish
object publication. These private records establish neither acceptance nor
reachability, and do not authorize deletion.

The latest marker's name is the 64 lowercase hexadecimal SHA-256 of the object
key. Its 512 bytes contain `TDALLOC1` at `0..8`, the mandatory definition at
`8..40`, little-endian storage epoch at `40..48`, little-endian `u16` key length
at `48..50`, six zeros, little-endian object length at `56..64`, object SHA-256
at `64..96`, the key in a zero-padded 256-byte field at `96..352`, 128 zeros,
and SHA-256 of `0..480` at `480..512`. The key must satisfy the object contract
and exclude `native/`; the epoch is nonzero and within the native counter bound.
The marker filename must match the decoded key hash.

`data-allocations/queue/` is a separate segmented `LocalWal`, using partition
zero, writer/policy epoch one and `manifest_checkpoint` frames. Its 584-byte
payload contains `TDALQ1` plus two zeros at `0..8`, the definition at `8..40`,
little-endian position and consumed-prefix cursor at `40..48` and `48..56`, an
item-present byte at `56`, seven zeros, a little-endian source-activity counter
at `64..72`, and the 512-byte allocation at `72..584`
(all zero when absent). Position equals LSN, and cursor cannot exceed position.
One append atomically advances the cursor and optionally carries a retained
item; one empty-prefix advance reads at most 64 records. Queue append and latest
marker publication are durable before content creation. An uncertain attempt can
leave duplicate intents. Removal must match the latest marker exactly, so an
older item cannot erase a newer reuse. Missing queue history with existing
markers rejects; an existing owner never recreates a missing inventory directory.
The activity counter follows the native FIFO rules above. New source creation or
reuse intents increment it; collection's own work/mark allocations do not.

Direct creation holds a shared creation/reclamation fence through inventory
recording and object publication. Private inventory updates serialize separately
from the native journal mutex; only quota reservations and the accepted-epoch
read take that mutex. Reclamation requires the exclusive creation fence before
checking the latest marker. This stored-layout change replaces the shared current-v1 definition;
earlier directories reject instead of acquiring an empty inventory.

`Storage.Limits` bounds candidate bytes and encoded-file allocation admission.
The core carries its control classification with the prepared transition through
commit; a later candidate cannot change its reserve eligibility. Reservations
remain conservative after uncertainty. Exclusive reopen counts actual file
lengths with bounded directory traversal. These are encoded-file bounds, not a
filesystem block or inode quota. Confirmed native object reclamation releases
removed file lengths. Uncertainty can retain excess reservations until reopen;
retained objects and maintenance metadata can still exhaust admission.

The latest accepted native WAL entry is the recovery root. A native accepted
history floor can authorize trimming older frames while retaining that entry.
Exact retry records and durable captures remain in its catalog. This adapter's
trim does not collect objects or dispatch effects. `StorageCollection` records
its accepted fence cut, FIFO end, source-activity target, root/traversal cursor, paged mark root and exact
pending deletion in a definition-bound `.native-collection` JSON body of at most
256 KiB followed by its 32-byte SHA-256. Replacement syncs the file and parent
directory. A complete mark protects retained journal roots, current live captures
and all newer allocation epochs. A racing trim aborts incomplete marking.
Deletion waits beyond the fence's upper time plus five minutes of snapshot life
and sixty seconds of request grace, and requires a persisted native time floor
beyond that boundary. Pending deletion resumes the same immutable identity;
FIFO consume, not a transient counter, establishes completed inventory progress.
The mandatory source-activity target cannot exceed the inventory end. Automatic
callers capture it before submitting the storage fence and pass that fixed value
to `startAtActivity`; allocations arriving after that observation stay eligible
for later work. Explicit `start` claims no automatic activity coverage and records
zero. Mark-page allocations remain inventoried without increasing source
activity. These counters select work and grant no deletion authority.
Native compaction preserves logical values and captured roots through the core
`storage_compact` operation. Standalone payload publication, Table collection and
automatic installed maintenance retain separate owners.

### Local direct-data collection

`DataCollection.Collector(DirectStorageGraph)` uses the same exclusively owned
backend and an accepted native `storage_fence`. It discovers nonzero durable
partitions and fixes each owner's last acceptance before that epoch. Complete
marking includes every catalog control root and accepted intent; current Table
data, declarations, original receipts and operation intents; the selected recovery
baseline and subsequent replay; unexpired history; live snapshots and history
anchors. Snapshot/recovery metadata has its own retention and does not implicitly
restore released old data graphs. An unflushed row locator retains its exact WAL
or archive frame, without recursively owning that frame's obsolete roots.

The definition-bound `.data-collection` checkpoint is a JSON body of at most
256 KiB followed by its SHA-256. It stores the native cut, grace, owner cursor,
separate paged physical/typed marks, paged FIFO roots and positions, active owned
graph work, fixed allocation end, mandatory source-activity target and exact
pending deletion. The target follows the native collection rules above: it is
captured before the fence and cannot exceed the inventory end. Work/mark objects
remain inventoried without increasing source activity. Replacement syncs
the file and parent directory. A work item is at most 128 KiB: `TDWORK1` plus NUL,
32 definition bytes and owned JSON; its immutable key is
`data-maintenance/<sha256>.work`. Queue keys are eight-byte big-endian positions;
values are eight-byte little-endian object lengths followed by SHA-256. Mark keys
are SHA-256 of object keys, with the same 40-byte exact-metadata values. Typed
visited keys hash their traversal context and carry empty values. All private
indexes use `TreeStore`. Roots and active work publish in one checkpoint; staged
objects alone cannot advance progress.

A step performs at most four graph transitions, one allocation decision/deletion,
or 64 empty FIFO advances. A graph transition emits at most three child items;
page depth and decoding bounds remain independent of retained cardinality. The
step allocator caps simultaneous graph/index allocations at 64 MiB, with an
8 MiB per-transition index-work budget and one cached index page. Provider WAL
buffers and fixed decoding/stack buffers have separate format bounds. Scanning
partition directories or reading a bounded segment can still perform substantial
I/O; these limits do not establish a latency bound.

Incomplete marking never reaches sweep. Required history trimmed during discovery
or traversal aborts the pass; corrupt/missing dependencies or quota refusal leave
the last checkpoint for retry. Sweep requires the same snapshot/request grace and
persisted native time floor as native collection. It protects all allocations at
or after the cut epoch and any marked object. Permanent `data-operations/` identity
reservations, saved `direct-intents/` staging references and unknown namespaces
remain outside collection. Collectible namespaces are `data-index/`,
`data-maintenance/`, `catalog-intents/`, `table-definitions/`, `table-evidence/`,
`table-intents/`, `table-snapshots/`, `table-checkpoints/`, `table-history/` and
`table-segments/`.

Deletion holds the exclusive creator fence and inventory lock, checks the current
native epoch/genesis, then removes only the pending allocation's exact immutable
identity. A different latest-marker epoch skips that intent without deleting the
marker: a newer marker owns a newer reuse; an older marker means this attempted
reuse never published its marker. Descriptor, payload, checksums and matching
marker are removed before FIFO consumption. A recovered consumed cursor wins over
stale private deletion state. Repeating a pending deletion is idempotent, while
byte/object counters can undercount lost acknowledgements. Quotas include marks,
work and progress; quota pressure never authorizes expiry. Automatic installed
scheduling and public progress operations are separate from this component API.

## Local standalone payloads

The component `PayloadStore` binds physical I/O to the complete current accepted
native `Payload` record under the publication fence. It does not authenticate a
public caller or grant access independently of native operations. Its immutable
object key is `native/u/<16 lowercase hexadecimal payload ID>`; the object body
is the exact declared bytes, at most 64 KiB. Native page/block collection ignores
these objects. Direct data adapters reject the reserved namespace.

The permanent creation-attempt marker is `.payload-<16 hex payload ID>` in the
native root. Its 136 bytes contain `TPAY1` and three zeros at `0..8`, the mandatory
shared definition at `8..40`, little-endian payload ID, PID and publisher at
`40..48`, `48..56` and `56..64`, little-endian `u32` length at `64..68`, deletion
opt-in (`0` or `1`) at `68`, three zeros, SHA-256 of the declared bytes at
`72..104`, and SHA-256 of `0..104` at `104..136`. The marker's file and directory
are synced before content creation. A marker never grants publication authority.

`createPayloadOnce` requires the current `creating` record and exact body. An
existing marker rejects another attempt, including an exact retry. The trusted
publisher calls once; uncertain results use `verifyPayload`, which does not PUT.
Verification matches the marker and current `creating`/`ready` record, verifies
all bytes and syncs the observed marker and object publications before success.
Missing bytes remain unavailable. No helper manufactures `payload_ready`.

`reclaimPayload` requires the current `retiring` record, `allow_delete` and its
accepted retirement position. It confirms descriptor/content/checksum removal
while preserving the marker. Repeating deletion is idempotent; only a separate
authorized `payload_deleted` command records native completion. Quota refusal,
process ownership or an old payload record cannot authorize deletion or recreate
bytes. Physical adapter operations preserve the native identity and outcomes;
installed local payload routes and automatic reclamation remain separate.

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
     `bloom_mask`). Two hash positions use seeds `0x54534547` and `0xCAFEBABE`
     modulo 64 over the collation sort key. The fixed filter can saturate as
     distinct keys increase; it has no promised false-positive rate. Missing
     bounds disable pruning, and a possible error/conflict prevents unsafe skips.
   - Embedded sorted primary-key directory (`pk_sort_key`, `TableRow.Identity`,
     `row_group`, `row_in_group`, `global_row_offset`). Binary search is
     $O(\log N)$ after the bounded footer is decoded. This array is distinct from
     the live Table's paged ordered index and does not imply logarithmic physical
     I/O or constant-time overlap checks.
   - Trailing 32-byte SHA-256 over the `"TSF1"` footer body.
4. **Trailer (`16 bytes` at `EOF - 16`)**: `footer_offset` (`u64`),
   `footer_length` (`u32`), and `"TSEG"`.

### Qualified plain value buffers

Plain int64, uint64, float64, Boolean, UTF-8, binary and JSON pages use the
following layout after the state/detail stream. Offsets are relative to page
byte zero. Every buffer starts on a 64-byte boundary and ends with zero padding
to the next such boundary; the page ends immediately after the last padding.
The padding between details and the first buffer is also zero.

1. A validity bitmap contains `ceil(row_count / 8)` bytes, least-significant bit
   first. A bit is set exactly when the corresponding state tag is `value`.
2. Int64, uint64 and float64 have one little-endian eight-byte value per row;
   non-value rows contain zero bytes. Float64 preserves finite IEEE-754 bits,
   including signed zero. Boolean values use a second bitmap in the same bit
   order; non-value bits are zero.
3. UTF-8, binary and JSON instead have `(row_count + 1)` little-endian signed
   32-bit offsets, followed by a separately aligned byte buffer. Offsets begin
   at zero, never decrease and end at the unpadded payload length. Non-value
   rows repeat the previous offset. UTF-8 and JSON retain their logical value
   validation; binary accepts arbitrary bytes.

Unused bitmap tail bits, non-value lanes and all alignment padding must be zero.
Readers validate every offset and scalar, including unselected suffixes, before
returning buffers or selected cells. State details retain their canonical error
kind and conflict alternatives independently of these nullable value buffers.
Other plain logical types, including recursive containers, use bounded canonical
value decoding; compressed and foreign encodings retain their codec layouts.
These layouts replace the former qualified plain streams under the current
shared definition. Earlier definitions reject before interpreting page data;
there is no fallback decoder or implicit stored-data migration.

## `.tdel` (`TDEL` v1) deletion vectors and `TMAN` v1 manifests

- **`.tdel` deletion vectors**: Begin with `"TDEL"` + `0x01`, mandatory 32-byte
  shared contract definition, `segment_id` (`u64`),
  `total_rows` (`u32`), `deleted_count` (`u32`), `container_count` (`u32`),
  strictly ascending high-16-bit container records, and a trailing 32-byte
  SHA-256 digest over all preceding bytes. Integers are little-endian. Each
  record is a high prefix (`u16`), encoded container length (`u16`), and one
  canonical nonempty `RBC1` container from `transit-bitmap`, addressing the low
  16 bits of each row offset. Array, bitmap and run containers share the codec
  used by the paged bitmap directory. Prefixes are unique, every offset is below
  `total_rows`, and container cardinalities sum exactly to `deleted_count`.
  The complete sidecar remains bounded to 512 KiB. Mutation workspaces reserve
  an explicit byte budget, independent of the segment's logical row count;
  exhaustion refuses a mutation without dropping existing deletion bits.
  This replaces the former sorted-offset encoding under the new shared
  definition. Readers reject that earlier definition before interpreting the
  body; there is no fallback decoder.
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
segment identity and row count. Retained Table reads use the accepted roots and
durable pins owned by `TablePartition`; segment artifacts alone do not establish
a retained snapshot.

## `.tack` queue state manifests

The implemented `Tack` artifact is a storage foundation; it does not itself
provide queue admission, lease authority or a public queue API. It binds one
immutable payload segment and four paged sets of global logical offsets, in
order: available, acquired, acked and archived. Archived includes a completed
DLQ transfer; selecting a destination or staging an append cannot establish it.
Durable lease, attempt, delay and original-operation records are separate from
these sets and must share the owning partition's acceptance decision.

The canonical 488-byte envelope contains, in order:

- `TACK0001` (8 bytes) and the mandatory current definition (32 bytes).
- Realm, resource, catalog, branch, object and definition revision (six `u64`),
  definition digest (32 bytes), and logical partition ordinal (`u32`).
- Segment ID, first offset, exclusive next offset, physical WAL partition and
  accepted exclusive WAL frontier (five `u64`).
- Four root records: presence (`u8`, zero or one), page digest (32 bytes), page
  location (32 bytes), and total cardinality (`u64`). An absent root requires
  zero reference bytes and zero cardinality; a present root is nonempty.
- SHA-256 over the preceding 456 bytes (32 bytes).

All integers are big-endian. The nonempty half-open offset range contains at
most `u32` rows, independent of its full-width logical starting offset. Root
cardinalities sum to that range length. Envelope validation alone does not prove
coverage: a completed bounded audit also verifies referenced containers,
actual cardinalities, in-range offsets and pairwise disjointness. Each page
checks at most eight containers and their corresponding state peers. A partial
or failed audit cannot establish valid complete state.

Private transitions remove the old bit and add the new bit before returning a
candidate root set. Publication failure leaves the original roots authoritative.
Terminal states cannot transition back into available/acquired state. The owner
must separately validate current rights, authoritative time and lease generation
and commit corresponding lease metadata and original receipts. A bitmap is not
a lease capability. The accepted frontier in a sealed envelope binds the
specific state represented, rather than a later observation of the queue.

Terminal cardinality permits constant-time eligibility inspection. Physical
reclamation still requires the owning retained-graph checks for payloads,
receipts, snapshots, replay and pending transactions; terminal state does not
authorize deletion.

## Queue time-run chunks

`QueueTimeRun` stages and verifies sorted scheduling chunks through the shared
`.tseg` engine. A chunk contains at most 1,024 entries and 512 KiB. Its four
non-null internal columns are kind (`uint8`), millisecond time, logical offset
and lease epoch (three `uint64` values), with 64 rows per physical group. Kind
one denotes visibility/retry and kind two denotes a lease deadline. Entries are
strictly ordered by `(time, offset, epoch)` and share the time bucket
`time >> 20`. An offset cannot equal the maximum `u64`; lease entries additionally
require a nonzero epoch and deadline. Visibility entries may carry epoch zero.

The canonical 240-byte descriptor contains, in order:

- `QTIMRUN1` (8 bytes), mandatory current definition (32 bytes).
- Realm, resource, catalog, branch, object and genesis definition revision
  (six big-endian `u64` values), definition digest (32 bytes), and logical
  partition ordinal (big-endian `u32`). The genesis revision is one.
- Kind (`u8`), bucket and nonzero run serial (two big-endian `u64` values), and
  nonzero row count (big-endian `u32`).
- First and last `(time, offset, epoch)` triples (six big-endian `u64` values).
- Segment byte length (big-endian `u64`), SHA-256 (32 bytes), seven zero bytes.

The object key is `queue-time-runs/<sha256>.tseg`. The internal physical schema
uses the Queue's stable object ID and revision one. The footer segment ID is the
run serial; physical row identities are `(partition ordinal + 1, run serial,
row ordinal)`. Loading checks the complete content digest, physical schema,
identities, timer kind, ordering, bucket and exact descriptor bounds before
returning the complete copied scalar output. Scratch does not escape. Partial
output after a failed decode establishes neither valid events nor coverage.

These operations define an immutable storage artifact. They do not publish a
schedule, establish current time/authority, filter stale epochs or expire a lease.
The owning Queue must validate the exact genesis and publish reachability with
its accepted scheduling state. The current Queue scheduling directories have
not yet adopted time-run chunks or resumable multi-chunk merging.

### Pending timer buffers

`QueueTimeBuffer` orders at most 256 pending events in caller-owned memory and
stages an immutable `queue-time-buffers/<sha256>.data` object. It shares the
run's `(time, offset, epoch)` event and kind rules, but may span time buckets.
Sealing can split its contiguous bucket slices into `QueueTimeRun` chunks.
A full buffer returns explicit refusal without eviction; it is an operation
buffer bound, not a bound on retained Queue cardinality.

The header is 128 bytes: `QTBUF001` (8), mandatory current definition (32),
realm/resource/catalog/branch/object/genesis revision (six big-endian `u64`),
definition digest (32), partition ordinal (big-endian `u32`), kind (`u8`),
nonzero row count (big-endian `u16`), and one zero byte. Strictly ordered event
triples follow as three big-endian `u64` values per row. The exact object size
is `128 + 24 * rows`, at most 6,272 bytes. Loading verifies length, full digest,
current definition, exact expected seed/kind and ordering into copied scalar
output. No decoder allocation or encoded-byte borrow escapes.

The buffer codec does not publish pending work or retire a previous buffer.
Accepted scheduling state must own the active reference, any sealed chunks,
merge inputs and output before their physical reclamation becomes eligible.

### Paged timer-run directories

`QueueTimeDirectory` indexes one sorted logical run within one seed/kind/time
bucket. Its root contains a nullable chunk-directory reference, total row and
chunk counts, and nullable first/last event bounds. All are absent/zero together
for an empty run. Nonempty roots require compatible ordered bounds and counts
consistent with one through 1,024 rows per chunk. Counts use checked `u64`
arithmetic; directory size is independent of the configured page cache.

Each key is a chunk's last `(time, offset, epoch)` as three big-endian `u64`
values. Its 248-byte value contains the first row ordinal within the logical
run (big-endian `u64`) followed by the canonical 240-byte chunk descriptor.
Appending checks exact seed/kind/bucket, strict non-overlap and cardinality
overflow before staging private copy-on-write pages. Only chunk boundaries enter
this directory. The caller must have staged the referenced chunk and must
separately accept the resulting root.

An exclusive event-key lookup finds the first chunk whose upper key exceeds the
cursor, including a chunk containing that cursor. Lookup alone proves neither
earlier coverage nor chunk-body validity. A bounded audit carries one immutable
root, an exclusive upper-key cursor, and exact visited row/chunk counts. It
requires contiguous first-row ordinals and non-overlapping bounds, and reports
completion only after actual directory exhaustion with matching totals. Errors
leave its cursor unchanged. Chunk bodies require the separate `QueueTimeRun`
verification. Holding a root or audit cursor does not create a retention pin or
grant access to Queue data.

### Private resumable timer merges

`QueueTimeMerge` merges two immutable logical runs from the same exact genesis,
kind and time bucket. Its scalar state retains both source roots, a frozen
Queue item/sidecar basis and offset frontier, two input positions, the private
output root, discarded-row count, last examined event and completion flag.
Each position records consumed rows, completed chunks, an exclusive event cursor
and verified exhaustion. Counts are checked `u64` values; the combined input
cardinality must fit without wrapping. Output rows plus discarded rows exactly
equal consumed input rows.

One step examines at most 1–1,024 input rows and stages at most one output chunk.
Duplicates and stale events consume that same budget. Equal events across both
sources produce one output, including when their processing spans steps. Source
reads verify complete bounded chunks, contiguous row ordinals, cursor identity
and chunk counts. Completion additionally requires actual directory exhaustion
with exact totals on both inputs. A budget boundary or an empty output chunk is
not completion. Failure returns no successor state; private staged artifacts do
not replace the caller's earlier roots.

The filter receives the frozen basis explicitly. `QueueIndex.TimerFilter` checks
the corresponding item and `.tack` state before discarding older epochs, settled
leases, superseded deadlines, or blocked visibility entries. A future epoch,
missing state or inconsistent bitmap refuses the step rather than discarding
unexplained work. A matching event grants neither FIFO eligibility nor current
time, access or settlement rights. Publishing and retaining the frozen basis,
inputs, progress and output remains the Queue owner's responsibility.

The workspace holds two 1,024-entry input arrays, one 1,024-entry output array
and one 512-KiB encoding buffer, independently of logical-run size. The caller
provides reusable scratch, a bounded private page candidate and a nonzero output
serial. Identical input state, serial, budget and deterministic filter produce
identical output content and roots; `CandidateObjects` can derive them during
replay without writing the underlying provider. The Queue owner records merge
progress in accepted scheduling roots and retains its inputs, frozen basis and
partial output through the storage graph.

### Private scheduling source composition

`QueueSchedule` composes an active buffer, paged pending chunks, paged merged
runs and optional resumable merge work. Its scalar root records the active
content/count, pending directory/count, level directory/count, merge state,
next nonzero serial, finite-sweep state and an eight-unit pending/sweep counter.
These fields are mandatory when serialized. The accepted Queue root has one
schedule for visibility and one for lease deadlines, plus mandatory `timer_next`
(`visible` or `lease`) for fair physical maintenance selection.

Appending to a full 256-entry delta seals one chunk for each contiguous time
bucket. Pending keys are the first `(time, offset, epoch)` triple followed by
the serial, all big-endian `u64`; values are the 240-byte run descriptors.
Pending cardinality has no resident fan-in array or fixed total bound. Staging
still obeys the caller's private page budget and provider quotas. Intermediate
buffer candidates are not published by this helper. `QueueSchedule.Buffers`
selects only the final visibility/deadline buffer names for
`CandidateObjects.persistSelected`; every other object namespace remains
selected. Previously accepted underlying buffers are never deleted. The caller
must establish that no accepted reference in its action retains an intermediate
buffer. Runs and merge states contain scalar events or chunk directories, never
intermediate buffer references. The Queue WAL owner uses this selection for
enqueue, claim, settlement, expiry and scheduling maintenance publication.

Merged-run keys contain a big-endian `u64` bucket and `u8` level from zero
through 63; their values are exact logical-run roots. A collision merges two
runs into the next level, with checked serial and level exhaustion. Pending
chunks are filtered even when their initial level is empty. Readers continue to
use both complete input runs while a merge is in progress; private output never
hides their unprocessed suffix. New appends can extend the active/pending roots
without changing those frozen inputs.

Maintenance performs one pending promotion, bounded merge step or finite-sweep
transition at a time. The sweep hashes the item/sidecar basis solely for change
detection, advances a bucket/level cursor, and freezes the current basis for
each individual merge. Its initial buffer cleanup examines at most 256 entries.
Up to eight pending promotions alternate with a sweep transition when both have
work; an active merge finishes through bounded steps first. A completed sweep
with an unchanged basis and no pending work is idle. Changed data starts another
pass, including entries inserted before a previous pass's cursor.

Reads inspect active events, merge inputs, pending chunks and merged runs to
prove the earliest matching event after an exclusive cursor. Directory steps,
chunk decodes and candidate checks consume an explicit work budget. Immutable
event bounds prune later sources and skip earlier time buckets. An unfinished
search returns `QueueTimerReadBudget`, never an empty result or a partially
qualified earliest event. Every decoded chunk is bounded; whole scheduling
cardinality does not determine resident allocation. Matching uses the supplied
current-state filter and provides no authority or settlement decision.

`QueuePartition.scheduleMaintenanceUnit` accepts a `queue_schedule` action with
the selected kind and requested input-step budget. The budget must be positive,
at most 1,024 and no greater than the current declaration's `timer_steps`.
Publication verifies immutable declaration bytes and current authority, including
for compatible retired declarations. It leaves logical item/bitmap state,
counts, clock floor, payload offsets and original outcomes unchanged, switches
`timer_next` to the other kind, and advances the WAL frontier. If the preferred
kind is idle it may service the other; two idle schedules publish nothing.
Replay deterministically derives the complete successor using private candidate
objects and refuses a differing root. An uncertain append requires recovery.

This maintenance uses reserved control capacity and requires no time observation:
discarding a stale physical event cannot itself expire a lease. Native maintenance
services it even when optional Stream compaction is disabled. Storage traversal
verifies and retains active buffers, pending chunks, level directories, both
merge inputs, partial output and frozen item/sidecar roots. An unfinished audit
or missing artifact cannot authorize collection. The logical item root binds
the resident wheel and heap caches; physical schedule rewrites do not grant
eligibility or invalidate an otherwise unchanged logical basis.

## Declared log initialization

`LogDeclaration` stores a Stream or Queue schema independently of Station.
The `LDECL001` envelope is 104 bytes before its variable body: magic (8 bytes),
current definition (32 bytes), realm/resource/catalog/branch/object/revision
(six big-endian `u64`), retired flag (`u8`, zero or one), policy/properties/schema
lengths (three big-endian `u32`), and three zero reserved bytes. The body contains
canonical JSON `{configuration, limits}`, exact catalog-owned property bytes,
and the shared canonical `TableSchema` encoding. Policy and properties each
have a 4096-byte limit; schema retains its 65536-byte bound. SHA-256 of the entire
artifact binds the immutable definition and object-store content reference;
the descriptor separately commits the schema bytes and policies.

Canonical JSON uses the shared codec: fixed byte arrays remain numeric arrays,
including digests or producer IDs whose bytes happen to be valid UTF-8. Reading
does not reinterpret strings as those arrays.

Log schemas have no relational primary key: offsets establish append identity.
Declared routing, FIFO and compaction keys must resolve to existing nonnullable
columns with supported key types and collations. The schema owner validates
logical types, physical encodings and collations together without conflating
their roles. Loading verifies content, exact identity, canonical policy, schema
and every supplied descriptor field before exposing the declaration.

`LogInitialization` writes one `genesis` frame at physical LSN zero. Its payload
is `LINIT001`, the mandatory shared definition, and canonical JSON for the
required `Request` fields: definition, stored declaration, original operation,
logical ordinal and physical partition. The entire payload is at most 8192
bytes. Its original operation shares the declaration's scope, its ordinal is
within the fixed partition count, and the definition is live revision one.
`TWAL1` supplies frame integrity and writer/policy epoch fencing.

Initialization checks current authority before reading the staged declaration,
verifies that complete dependency, then reacquires and holds the publication
guard while checking the WAL, fencing and appending. A nonempty partition can
only return the exact matching original genesis; foreign or missing history
never authorizes a reset. Append success is followed by verified readback.
Lost or malformed append/readback results remain `LogInitializationUncertain`
and resolve under the original request. A retry cannot allocate a new identity
to conceal that uncertainty. The initialization descriptor does not itself grant
catalog membership or execution rights.

Observation checks current rights before loading and again after buffering.
The accepted initialization position remains the exclusive frontier one, even
when later records exist. Its payload digest commits the exact original
evidence. If physical trimming removed the genesis, the exact accepted
`LogRecovery` baseline and its publishing WAL record must preserve the original
request. A staged object or copied reference cannot establish initialization.
Missing required evidence rejects. Catalog publication and native authorization
registration remain separate owning operations.

### Declared log payload batches

`LOGBAT01` payloads begin with that eight-byte magic, the 32-byte shared
definition, the 32-byte schema layout fingerprint, kind (`u8`: one for Stream,
two for Queue), and nonzero row count (`u32`, big-endian). Each row contains its
encoded length (`u32`, big-endian), visibility time (`u64`, big-endian), tombstone
flag (`u8`, zero or one), and canonical `FTR1` bytes. The row's internal codec
identity is `(principal + 1, original operation, zero-based batch ordinal)`;
neither its origin nor ordinal is a physical WAL LSN or allocated Stream offset.
The whole batch is the append request's payload commitment.

Stream rows have zero visibility time; a tombstone requires declared key
compaction. Queue rows may have delayed visibility and cannot carry stream
tombstones. The declaration's row/byte limits apply to each append. Every routing
key is encoded with the shared logical type and declared collation's canonical
sort-key codec before applying the declared partition hash. A row routed to a
different partition refuses the entire candidate batch.

Validation uses a caller-owned reusable row scratch arena; no row can escape
after that arena is reset. Iteration borrows the complete immutable batch, while
decoding into a separate retained allocator detaches values from it. Consumers
must preserve the batch borrow until decode finishes. Exhaustion verifies the
declared count and exact byte end; truncated rows, extra bytes, foreign schema
layouts and different original row identities reject. These codec checks do not
establish durable append acceptance or complete Stream read coverage.

## Stream partition acceptance

`StreamPartition` is a serialized storage owner over an exact `LogInitialization`.
Its adapter owns current catalog interpretation, current authorization and the
global operation-identity directory. A validated descriptor or an acquired cache
borrow cannot supply those authorities. Fresh appends require the current live
declaration and preserve the seed's schema, partition routing and compaction key.

Each `LOGPART1` payload contains its eight-byte magic, shared definition, metadata
length (`u32`, big-endian), canonical JSON metadata and optional `LOGBAT01` bytes.
Metadata has a 32 KiB limit and contains the previous accepted payload's SHA-256,
the complete new paged root and operation or physical-maintenance action. The root records the original
initialization, declaration, physical WAL frontier, independent logical offset
frontier, retained boundary, nullable trusted-time floor, batch/segment/receipt/producer/producer-receipt/group/group-offset/pin
directories, exclusive sealed offset, accepted archive coverage, nullable recovery reference and
mandatory maintenance progress. Missing
fields reject. Append records use `row_delta`; assignment, read pin/release,
offset, expiry, flush, archival, checkpoint and maintenance records use `manifest_checkpoint` and contain no row
payload. All advance the
WAL frontier, while only append allocates logical offsets.

Original outcomes are immutable `log-evidence/{sha256}.data` objects: `LOGEVID1`,
the shared definition and canonical JSON for the exact declaration and receipt.
The entire object is bounded to 16 KiB. Directory values encode its byte length
as big-endian `u64` followed by its SHA-256. Operation keys are the original
principal and operation as big-endian `u64` values, scoped by the partition's
catalog. Batch keys are exclusive logical end offsets, so a bounded ordered
lookup finds the batch containing any retained offset. Producer keys include
the original principal and 16-byte producer ID; sequence receipts additionally
include epoch and sequence. No directory is materialized in its entirety.

Append validates the complete payload, schema, collation-aware routing, limits
and producer transition before staging private indexes. It rechecks and holds
the publication guard while appending with the exact expected WAL frontier and
writer/policy epochs. One WAL acceptance publishes payload, offset range,
producer progress and original receipt together. Exact retries inspect original
outcomes before fresh producer/declaration checks, while still requiring current
permission. Conflict and uncertainty never allocate a replacement identity.

The trusted adapter optionally supplies `LogTime.Source`. Fresh append samples
it after validation and records the nullable upper UTC bound in its receipt. A
configured source returns a closed authoritative interval with earliest and
latest milliseconds; the latest bound must not regress below the persisted
floor. A positive retention age requires it; a partition with an accepted time
floor cannot later accept untimed work. Under the final publication guard the
owner samples again, refuses regression/unavailability, and refuses an opted-in
age window already elapsed since the first observation. Private staged objects
from a refusal establish no acceptance. Replay checks the persisted monotonic
floor without consulting current time. Original-receipt lookup precedes clock
checks. Neither producer event timestamps nor a WAL header's incidental clock
field can supply this capability.

`Options.control`, when supplied, is a trusted adapter capability for the same
physical namespace and authorization owner using reserved deployment capacity.
Offset commits, read release, existing-group reassignment, expiry, archive, checkpoint and archive-target bookkeeping
stage and publish through it. Fresh append, initial group assignment and read-pin
admission use ordinary capacity. Every operation retains its current-policy
checks and normal uncertainty semantics. Restoring ordinary I/O after each
control operation prevents subsequent admission from consuming that reserve.
The reserve is finite; exhausting it is an explicit failure, never permission
to expire payloads, discard progress or forge an outcome.

`expireHistory(declared, cut, guard)` requires an explicit positive retention age
and advances the logical retained boundary by at most one complete sealed batch
within the fixed physical cut. Its trusted lower bound must be at least the
accepted append upper bound plus the declared age. Untimed accepted history
cannot acquire an invented timestamp after a policy change. The owner reports
`consumer`, `unsealed`, `untimed` or `not_due` without advancing the boundary;
`progress` and `complete` describe the selected cut, not later appends.

`QueuePartition.expireTerminalHistory` adds the Queue's terminal-state gate to
this prefix operation. Its exact `.tack` batch binding and state cardinalities
must establish that every offset is ACKed or archived; otherwise `nonterminal`
leaves the root unchanged. Queue expiry is control work after retirement as well
as before it, and replay reconstructs the complete removed-key directories in
private candidate memory. Its original claim selections store mandatory retained
lower boundaries and keep their frozen placement roots until explicit payload-
read release. Current observations can advance beyond those original offsets.
The [Queue contract](QUEUE_V1.md#terminal-payload-retention) defines that lifetime
separately from lease expiry and physical collection.

Group assignments and offset commits atomically update both the group-ID index
and a second index keyed by big-endian `(next_offset, group_id)`. The latter
stores the same complete progress value and bounds the oldest-checkpoint lookup
independently of group count. Expiry cannot cross that checkpoint. No group
means the current append frontier protects no additional unread prefix.

An accepted expiry record binds its previous root, declaration, exact original
append receipt, fixed cut, lower eligibility time (`observed_ms`), upper clock
floor (`clock_ms`) and protected checkpoint. Both time fields are mandatory.
The upper bound advances the root's floor even when its lower bound precedes a
recent append's upper observation. It removes that
batch and segment from the current placement roots while preserving original
receipts, producer fencing and the next logical offset. Replay verifies these
facts without current time. Publication rechecks current authority and time under
the guard; a lower-bound regression before publication refuses the candidate,
and an uncertain append result requires recovery. Existing read pins retain their old
placements and remain readable under current authorization. Fresh reads below
the new boundary report `LogRangeExpired`; missing required storage still reports
`LogHistoryUnavailable`. Physical collection can remove
bytes only after their pins and recovery dependencies also close.

An unknown or malformed append result marks the resident owner unready. Recovery
reads at most the requested 1–256 records, verifies the hash chain, declaration
and index/outcome agreement, and advances only through validated history. Reads
and appends refuse until recovery reaches the current physical frontier. Missing
dependencies reject; recovery neither stages replacement indexes nor resets the
partition. Required payloads remain retained in the WAL, immutable archives or
published columnar segments.

Current batch reads return an original append receipt, an observed cut and a
pinned `LogTail` borrow. Cache hits reuse verified bytes. A miss verifies the
accepted WAL record or reconstructs the exact published segment batch before
admitting its payload; pinned cache pressure is an
explicit refusal. Read authorization is checked again after buffering, including
empty terminal observations. A borrow survives other appends and prevents owner
destruction, but does not pin durable history or prove finite traversal coverage.
Explicit assignment preserves group progress across generation changes.

### Stream columnar placement

`flush` takes a fixed physical cut and seals at most one complete accepted append
per call. It reports the exclusive sealed logical offset, rows handled and whether
all appends through that cut are sealed. Appends accepted later cannot extend the
obligation. Publication advances only the physical WAL frontier; logical offsets,
producer state and original receipts do not change. Unknown publication follows
normal partition recovery before retry.

`LogSegment.Descriptor` binds the original evidence, optional `.tseg` content,
delivery metadata and materialized view content. The paged segment directory is
keyed by the original exclusive batch end. Its 165-byte value stores a layout
byte (`1` complete, `2` sparse), big-endian `u32` physical row count, then those
four contents in order, each as big-endian `u64` byte length followed by SHA-256.
Only an empty sparse view has no segment, encoded as 40 zero bytes. Segment IDs are the
original append's exclusive physical frontier. User columns preserve the declared
schema, codecs and collations. Row identities preserve principal/operation/ordinal
order within that append; no Table primary-key uniqueness semantics are added.

`log-segments/{sha256}.tseg` uses the shared segment format.
`log-segment-metadata/{sha256}.data` contains `LBMETA01`, the shared definition,
original evidence SHA-256, big-endian `u32` physical row count, then a big-endian
`u32` original ordinal, `u64` visibility time and one tombstone byte per physical
row. Original ordinals are strictly increasing and remain the row identities;
physical row positions may differ. Only zero and one are
valid tombstone bytes; Stream/Queue metadata rules remain unchanged. The metadata
bound is 76 bytes plus the maximum WAL payload size. Neither object establishes
acceptance. The owner reads back both, validates identities and reconstructs the
original `LOGBAT01` digest for a complete placement. A missing object,
foreign receipt, changed payload or unsupported lossless reconstruction refuses.

Sparse placement uses internal `LOGVIEW1` bytes: the eight-byte magic, shared
definition, schema layout fingerprint, Stream kind byte (`1`), and big-endian
`u32` retained row count form a 77-byte header. Each retained row contains its
big-endian `u32` original ordinal, `u32` encoded length, `u64` visibility time,
tombstone byte and unchanged encoded Table row. Zero retained rows are valid.
This format is not accepted as an append. A sparse view retains at most half
the original rows and cannot exceed the original payload byte budget. Its own
digest supplies the cache binding, while the original receipt remains unchanged.
Every omitted offset must be hidden in the exact retained visibility root;
read pins and collection walks cannot substitute current visibility for that
basis. Sparse timestamp reads use exact row predicates without dense ordinal
zone-map shortcuts. These storage codecs do not themselves publish rewrites.

Build and cold reconstruction share an explicit simultaneous allocation budget
(64 MiB by default, configurable up to 1 GiB). Segment row groups default to 1,024
rows and cannot exceed 1,024 for this owner. A refusal leaves the original WAL
placement usable and any private objects collectible. Each finite read base
retains both its batch and segment directories. The bounded read iterator keeps
the original cut and returns owned rows across WAL and segment boundaries; cache
admission verifies the placement's bound complete batch or sparse view. Physical copies may be reclaimed
only after the retained graph no longer needs their placement, independently of
logical payload retention.

### Retained Stream settlement and closure

Stream read closure and offset settlement may publish a current retired
declaration while keeping the request bound to its original retained read.
`LogEvidence` permits an older interpretation only for those two controls;
acceptance and replay compare it with the exact retained pin. Other outcomes
require a live, exact declaration. A partition that records retirement cannot
revert to a live declaration. Read pins and original receipts remain independent
of that retirement, and later release still closes the original pin.

### Stream key compaction

`compactStep(declared, cut, maximum, guard)` selects the exact current physical
cut when starting and resumes that same cut until publication or cancellation.
The declared compaction column supplies canonical full keys under its collation;
hash or prefix equality never establishes supersession. Each step handles at
most 1–64 rows from one original batch, under the index and allocation budgets.

The first pass builds a paged `OrderedKeyIndex` mapping each full key to its
latest logical offset within the frozen source. Values contain a big-endian
`u64` offset and 24 zero padding bytes. The second pass stages a paged Roaring
visibility mask for superseded non-tombstone rows in the sealed prefix below
the captured consumer watermark. Tombstones remain explicit records until
age-based history expiry. Appends after the source cut cannot change that pass's
supersession decisions.

The accepted root has mandatory `hidden`, nullable `compaction` work and nullable
`compacted` cut fields. Work records retain the exact declaration, cut, batch and
segment placements, original mask, protected checkpoint, phase, continuation,
private full-key index and candidate mask. Indexing and marking publish bounded
progress without changing visible rows. A final WAL transition publishes the
candidate mask and closes work. It rechecks current consumer protection; a newly
assigned lagging group blocks publication until progress or explicit cancellation.
Lost replies resume from accepted work rather than selecting a different cut.

`compactionMaintenanceUnit` resumes that accepted cut with the same row budget.
When idle it selects a new cut only after an append, assignment, offset settlement,
flush or expiry advances the mandatory `compaction_source_lsn`. Publication sets
`compacted_through_lsn` to the exact completed cut; compaction's own output and
archive/checkpoint bookkeeping do not schedule another pass. Retiring a
declaration cancels unpublished work without changing previously visible rows.

Every finite read basis captures its own mandatory `hidden` root. Previously
accepted reads preserve their visibility; new reads advance scanned coverage
over verified masked offsets without emitting those rows. Empty intermediate
pages remain incomplete until their original upper bound is reached. Original
append receipts, offsets and producer state remain unchanged.

`cancelCompaction` closes only unpublished work and can use the control reserve.
Expiry refuses while a pass owns its frozen source. Recovery and native collection
retain active work, full-key child directories, bitmap containers and pinned
visibility roots. Component batch borrows expose placement bytes
and a typed iterator preserving original identities; consumers use the
visibility-aware finite reader.

`rewriteMaintenanceUnit` follows published logical compaction with a finite
physical pass. Mandatory `rewrite_source_lsn`, `rewritten_source_lsn` and nullable
`rewrite_target {source_lsn, through_offset, after_offset}` fields retain its
source and cursor. Only logical compaction publication selects new rewrite work.
Starting a pass captures the current sealed frontier; later appends cannot extend
it. Each call accepts at most one transition: start, skip an expired prefix,
inspect/rewrite one accepted batch, complete, or cancel unpublished work after
retirement. These publications require archive coverage but cannot trigger
another logical compaction or rewrite pass themselves.

A batch is rewritten only when at most half its original rows remain visible
and at least one physically present row can be removed. Surviving encoded rows
must equal the accepted old placement exactly. The owner reads back the staged
view, verifies every omission against current accepted visibility, then publishes
its descriptor and cursor in one WAL record. Recovery repeats that comparison;
an accepted checkpoint permits later recovery without the superseded placement.
Empty placements retain original range and receipt evidence with no `.tseg`.
Sparse work uses the same finite segment allocation budget as flush. Logical
compaction counts omitted offsets against its step budget and can cross an empty
placement without inventing a row or stalling progress.

`compactionMaintenanceUnit` resumes pending physical rewrite work before selecting
another logical pass. Read pins and in-flight compaction sources keep their exact
earlier placement roots and masks. Collection validates omissions against each
root's own mask; closure and a later recovery baseline must release the earlier
placement before its segment and sidecar can be reclaimed. Original append and
producer receipts remain unchanged after that reclamation.

### Retained Stream reads and offset settlement

`beginRead` stages a `log-reads/{sha256}.data` object, then atomically publishes
its pin and original receipt. The object is `LREAD001`, the current definition
and canonical JSON for the exact request, declaration, cut, resolved end and
batch and segment directory roots, bounded to 16 KiB. It contains no earlier pin or receipt
directories. A null requested end is resolved once at acceptance. The pin
directory maps original read identity to a released flag (`u8`), source byte
length (`u64`, big-endian) and source SHA-256. Original read receipts do not
themselves establish a live retention pin.

The reader authenticates cumulative coverage with HMAC-SHA-256 over
`transit.stream.read.coverage.v1\0`, the 32-byte shared definition, and canonical
JSON `{read, coverage}`. Its private nonzero 32-byte service key is supplied by
the adapter, never a public request. Comparison is constant time. A rotated key
invalidates old cursors, while the same retained read can start again under its
original immutable cut. Cursor authentication supplies no current access rights.
The independent Python fixture verifies this byte-level domain and MAC.

`readCursor` issues only the initial zero-row frontier. `readPage` authenticates
that cursor, verifies its live pin and exact source/range, and traverses the
retained batch directory. Group reads additionally require the current assignment
generation/principal. Each window has explicit returned-row, scanned-row and encoded-byte budgets,
bounded by the declaration and owner. Owner defaults are 4096 rows and 4 MiB;
configuration refuses more than 65536 rows or 64 MiB. The independent scan budget
defaults to 4096 offsets and cannot exceed 65536. Output owns copied encoded
rows in the caller's allocator, separately from reusable scratch and cache.
Allocation or budget failure cannot return fabricated completion. A budget too
small for even the next row refuses explicitly. Metadata storage is bounded by
the row budget, separately from encoded row bytes.

An optional frozen UTC microsecond range filters the declared timestamp column.
For sealed data, the reader checks the exact segment/evidence binding, schema and
verified footer before excluding a bounded group range with its zone map. A
possible match uses the exact row predicate. Skipped group coordinates must map
to the original append identities and offsets. Event time can move backward
between adjacent offsets. Scanned offsets advance `through` and the window's
`examined` count; only matching rows advance cumulative `rows`. An empty window
at its scan budget remains incomplete unless it reached the original end.

Coverage accumulates across physical batches and stops at the original exclusive
end, including an empty end. Later appends never enter the result. Repeated
continuations preserve source identity. Current rights are rechecked after
buffering, including empty terminal windows. Early release removes retention
ownership and rejects later traversal without changing a consumer checkpoint.
Release publishes its original receipt with the released pin marker.

`commitOffset` requires the current definition, live read pin, owner-authenticated
complete coverage, the same group as that read, current group generation and
expected checkpoint. An intervening definition edit requires a read binding to
the new definition before a fresh offset commit. One WAL record publishes the
new group checkpoint and original offset receipt, including the exact submitted
cursor. Partial or altered coverage cannot advance progress. Lost replies recover
under the original operation before fresh pin/group/key checks; accepted results
survive pin release, reassignment, key rotation and restart. Recovery validates
their original read and group transition without treating a changed signing key
as revocation of accepted work. Required read bases and accepted archive objects
remain retained; physical trimming does not expire logical payload history.

### Stream archive and recovery checkpoints

`LogHistory` uses the shared immutable TWAL object codec and existing
`table-history/{sha256}.twal` namespace. Each object contains one complete frame
with verified header, checksum, payload digest, partition and LSN. Its coverage
records a physical half-open `[from, through)` range and paged directory. The
current owner starts at zero and exposes no archive-prefix expiry operation.
Archiving stages at most eight frames under byte and index-work budgets, then
publishes the extended coverage in one control record. Its fixed requested cut
is distinct from that record's newer frontier. Retrying after a lost reply
observes accepted progress and never extends the requested obligation.

`archiveMaintenanceUnit` accepts or advances one durable fixed target with at
most one WAL publication per call. Mandatory maintenance fields record the
latest non-archive source LSN, completed source LSN and nullable archive target.
The target records its fixed exclusive frontier, source LSN and the first
archive publication covering it. Completion requires a recovery checkpoint at
or after that publication. Foreground changes during a pass can select a later
pass, while archive/checkpoint bookkeeping alone cannot schedule itself forever.
Publication and replay derive these fields from the exact accepted action;
locally well-formed but invented completion progress rejects. These scheduling
fields grant neither expiry nor physical collection authority.

`LogRecovery` stages `log-checkpoints/{sha256}.data`: `LCHECK01`, the shared
definition and canonical JSON for the complete prior root and its accepted
payload commitment. The bound is 40 bytes plus 32 KiB. A reference records that
root's exclusive WAL frontier and immutable content. Only a checkpoint control
record at that frontier publishes it: the record must retain every prior root
field except its own successor frontier and new recovery reference, and its
previous commitment must equal the baseline's. Staging alone supplies no recovery
or trim authority.

Cold recovery selects the latest accepted reference, verifies the publishing
record, then replays bounded successors with the normal transition checks.
Top-level index roots are verified before readiness. A superseded reference
inside a baseline is structural history, not another checkpoint to recursively
open. Missing required baselines, publishing records or archive bytes reject;
the owner never silently restarts from an incompatible or incomplete prefix.

`trimArchived` holds the current publication guard and trims no farther than
the smaller of accepted archive coverage and the checkpoint's publishing LSN.
That record and all later WAL history remain present. Reads use current accepted
archive coverage to resolve old pinned WAL coordinates, preserving their original
cut, payload and receipt. Initialization after trim verifies the checkpoint's
publication and original request before returning its original frontier one.
Physical trimming grants no logical expiry or object-deletion authority. Native
`DataStore.trimUnit` verifies these bounds against the latest accepted record.
The local node composes these units under its current native maintenance guard
and directory/object locks. It traverses complete declarations one partition at
a time through a catalog pass with a fixed highest object ID. Up to five bounded
recovery workspaces and 64 disposable prefix hints share the configured
maintenance allocation budget with Table work. Each workspace replays at most
16 frames per turn and retains no request proof or clock capability between
turns. Physical settings enable sealing, archival
and compaction; declaration opt-in and trusted time separately gate expiry.

`StreamPartition.RecoveryState` is same-process evidence from a fully
validated immutable prefix. `recoverStepSince` first selects any newer accepted
checkpoint, then verifies a reused hint's exact root and payload commitment at
its WAL boundary before replaying successors. It rechecks current authority and
required index roots before readiness. Hints are neither persisted baselines nor
caller-supplied recovery input, and physical-owner replacement discards them.
A mismatched boundary or shortened history rejects. A collided hint is discarded
before invocation, requiring ordinary bounded recovery.

`LogStorageRoots` enumerates the current root, selected immutable baseline and
hash-linked successors. Its final root and commitment must exactly equal the
selected cut. `DirectStorageGraph` retains the directories, declarations,
original evidence, live read bases and payload frames of those roots. Replay
also retains every newly archived frame needed to verify an archive transition.
An archive directory is a weak index, not ownership of every referenced object;
required payload and replay frames have explicit graph edges. Superseded
checkpoint references inside a baseline are not recursively followed. Released
read bases remain protected while required by replay, then become collectible
after a newer checkpoint. Missing or inconsistent dependencies prevent graph
completion and therefore prevent deletion.

## Direct Document declarations, genesis, and adaptive shredding

`DocumentDeclaration` stages immutable `document-definitions/{sha256}.data`
objects (`DDECL001`) with a 104-byte big-endian header binding the current
definition, object identity, revision, retired flag, canonical JSON policy
(`Configuration` and `Limits`), catalog properties, and the encoded
`TableSchema` for declared path columns and optional partition key routing.
Relational primary keys and nullable partition key columns are rejected.

`DocumentInitialization` records the initial `.genesis` frame (`DINIT001`) at
`lsn == 0` under `PublicationGuard` after reading back and verifying the staged
`DocumentDeclaration`. Retries with the same `Request` return the original
`Evidence`; differing operations or ordinals reject with
`DocumentInitializationConflict`.

`DocumentShredder` shreds declared and frequent (`count >= frequent_path_threshold`,
bounded by `max_shredded_columns`) document paths into typed five-state
(`value`, `null_value`, `missing`, `type_error`, `conflict`) subcolumns backed
by `RBC1` presence, null, and conflict bitmaps, collation-ordered (`utf8_binary`,
`ascii_ci`, `ebcdic_cp037`) `ZoneMap` summaries, and per-row `SuccinctTree`
residual topologies.

## Direct Document partition records, evidence, retained reads, and recovery

`DocumentPartition` serializes direct Document mutations, finite merge-window
checkpoints, retained revision reads, and archival/recovery over `TransitLog`
and `TransitObjectStore`:

- `DocumentPartitionRecord` (`DOCPART1`) encodes a 40-byte header (`"DOCPART1"`
  + 32-byte definition) followed by canonical JSON binding the preceding record
  commitment, successor `Root` (`documents_root`, `revisions_root`,
  `replicas_root`, `operations_root`, `reads_root`, `archive`, `recovery`),
  action (`mutation`, `checkpoint`, `read`, `read_release`, `declaration`,
  `archive`, `recovery_checkpoint`), and optional `DocumentEvidence` content.
  Mutations use `row_delta` frames; control transitions use `manifest_checkpoint`
  frames.
- `DocumentEvidence` (`DEVID001`) stores immutable operation outcomes in
  `document-evidence/{sha256}.data` so duplicate client tokens and replica
  sequence retries resolve to the original receipt across disk reopen without
  re-reading historical payload frames.
- `DocumentRead` (`DREAD001`) stores immutable retained read bases in
  `document-reads/{sha256}.data` and authenticates cumulative revision coverage
  cursors with `HMAC-SHA256(secret, "transit.document.read.coverage.v1\x00" || definition_bytes || canonical_json({read, coverage}))`.
  The owner binds cursor creation to the recorded receipt and release to the
  retained source's logical target. Fetches enforce cumulative request byte and
  revision budgets before allocating a whole revision's state, and reauthorize
  before disclosing data or terminal completion. Budget exhaustion refuses with
  `DocumentReadLimitExceeded`; it does not establish complete coverage.
- `DocumentRecovery` (`DCHECK01`) stages immutable recovery baselines in
  `document-checkpoints/{sha256}.data`. `trimArchived` requires both accepted
  `LogHistory` archive coverage and an accepted `DocumentRecovery` checkpoint,
  preserving the checkpoint-publishing WAL record and allowing
  `DocumentInitialization.observe` and `DocumentStorageRoots.Cursor` to verify
  the original initialization and retained roots after WAL prefix trim.

`DocumentPartition.open` requires an owner-supplied, nonzero `read_secret` and
performs at most `Options.recovery_records` replay records (default 64, range
1–256). A returned owner may still require recovery. `recoverStep(guard, budget)`
returns `examined`, the recovered `position`, and `complete`; callers resume
until complete before serving operations. Checkpoint selection adds at most two
WAL frame reads and one bounded checkpoint load to a step. Replay reuses scratch
per record and verifies the current directory root pages; it does not eagerly
traverse all descendants or state objects. Those retain checks on access.

Every recovery attempt clears readiness before validation or I/O. Authorization
is checked before replay, before installing each record and before readiness;
completion requires the recovered position to match a fresh WAL tail. Failures
and incomplete steps leave the owner fenced with `DocumentRecoveryRequired`.
The same signing key must be supplied after reopen to resume retained cursors.
