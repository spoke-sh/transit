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
mandatory `definition`, exact `begin`, retained `source`, private Table `root`,
`last_statement` and `changed`. Its positions describe private evaluator progress,
not Table WAL acceptance. The evaluator accepts bulk immutable row storage and
returns transaction-attributed provisional counts or rejection. It cannot export
an accepted Table recovery hint. Restoration requires the original live pin;
rollback retains consumed statement/operation identities. The embedding owner
must publish and retain the descriptor and its referenced pages before it becomes
durable work. The descriptor alone defines no installed workspace wire protocol,
collector root or transaction decision.

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
(`guard` and Table snapshot `pin`). A source pin's owner must equal the original
begin operation; source directories have zero writes. Tree keys encode the
nonzero object ID as eight big-endian bytes; values encode the object byte length
as eight little-endian bytes followed by its 32-byte digest. Tree pages retain
their ordinary definition/digest checks. Entry kind and identity must match the
root, and its object ID must match the key. Count is durable cardinality, not
resident capacity. Sealing a root grants no acceptance or retention authority.

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
these records. The components do not change current Table acceptance formats.

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
segment identity and row count. Retained Table reads use the accepted roots and
durable pins owned by `TablePartition`; segment artifacts alone do not establish
a retained snapshot.
