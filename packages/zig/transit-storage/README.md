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

`QueueItem` computes lease, renewal, retry and exhaustion candidates using
trusted time intervals. `QueueIndex` stages paged per-offset metadata, `.tack`
roots, canonical full-key FIFO heads, eligibility and fenced deadline indexes.
Only the head of each FIFO key enters eligibility; its delay, active lease and
retry block its successors while other keys can advance. ACK moves that head;
exhaustion retains an available but blocked source. Its DLQ reason retains the
exact destination definition; it does not publish that destination or make the
source terminal. Old roots remain independently readable.
`QueuePartition.enqueue` binds initial scheduling state, payloads and original
producer receipts to one fenced WAL record. Claims also publish acquired state,
exact leases and deadlines together. Settlement changes still remain private
candidates; timing-wheel scheduling and DLQ transfer are not
enabled by these components.

`QueueSelection` retains a nonempty claim's exact leases and payload placement
cut in a bounded immutable artifact. It keeps original offsets, epochs and
attempts in canonical order and binds them to the original receipt's content
digest. Its decoder checks canonical metadata without building a dynamic JSON
tree; decoded metadata is owned while lease bytes borrow the caller's buffer.
This artifact does not establish current lease status or publish a claim. Empty
claims have no selection artifact.

`CandidateObjects` derives one proposed transition's immutable pages and bitmap
containers in bounded, reusable memory. It enforces separate byte, object-count
and total resident budgets for that operation. Reads fall through to the existing
provider; private puts reach the provider only through explicit `persist`.
Replay can reconstruct and compare roots without writing or requiring old
intermediate staging objects. Persistence alone publishes no root and supplies no
WAL acceptance. The enclosing owner must clear derived page caches when abandoning
or resetting a candidate and must preserve original identity after uncertainty.

`LogTail` reserves aligned payload slabs and borrow handles under an explicit
resident byte budget. It verifies content once on admission, returns pinned
slices without copying, and keeps 64 trailing zero bytes for internal vector
reads. A pin prevents eviction and destruction; stale or copied released handles
cannot release a later borrow. All cache operations reuse initialization storage.
Cache pressure may refuse admission without affecting the durable log. Callers
serialize access, retain the owner through release, and check current rights
before disclosing buffered bytes. A cache pin is not a durable retention pin.
Complete and sparse placements can coexist under one original append identity;
their view digests distinguish cache entries without weakening original-content
conflict checks.

`LogDeclaration` validates schema-bound partition/FIFO/compaction keys and stores
immutable schema, policy, limits and catalog property bytes. `LogInitialization`
accepts an exact original initialization only at an empty physical partition,
after reading back its staged declaration and rechecking the service's current
publication guard. Retrying a lost receipt observes the same genesis; different
operations or ordinals cannot reuse it. Disk reopen and current-policy readback
retain the original evidence. Missing or trimmed initialization blocks observation
unless an exact accepted `LogRecovery` checkpoint preserves it. These foundations
do not publish catalog names or expose append/claim APIs.

`LogBatch` encodes bounded schema-bound rows with original operation identities,
queue visibility times and explicit stream tombstones. Validation binds the
complete payload to its immutable declaration and checks collation-aware routing
for every row. A reusable scratch arena is reset between rows; decoded retained
output uses a separate allocator. Its iterator borrows encoded bytes until the
caller decodes them, and rejects trailing or truncated data before claiming
completion. Batch validation provides no append acceptance or read authority.

`StreamPartition` accepts one schema-bound batch per WAL record with its logical
offset range, producer sequence/epoch and original receipt. Paged indexes keep
backlog cardinality independent of resident page and tail caches. Original
receipts survive later producer epochs and declaration changes; conflicting
retries reject. `LogEvidence` stores bounded immutable outcomes, while
`LogPartitionRecord` binds their published indexes and payload to the previous
accepted record. Uncertain append invalidates resident readiness and requires
recovery under the original identity. `recoverStep` checks at most 256 records;
it must complete before the owner serves payloads or accepts more work.
Trusted same-process adapters can retain `RecoveryState` from a fully recovered
owner and pass it to `recoverStepSince`. Reuse verifies its exact accepted
boundary, yields to newer checkpoints and preserves current-policy checks.
These disposable hints are not persisted recovery authority.
Its publication and recovery implementation lives in the internal `LogPartition`
owner, shared with `QueuePartition`.

`QueuePartition` publishes enqueue payloads, FIFO links, eligibility entries and
`.tack` availability roots together with producer deduplication. It derives
immutable state in `CandidateObjects`, persists those bytes, then rechecks the
publication guard before appending the accepted root. A lost reply requires
recovery before further operations. Replay privately reconstructs the complete
candidate and compares its root without writing objects; collected intermediate
pages are not replay dependencies. Sealing, archive/checkpoint and WAL trimming
preserve original payloads and outcomes. The direct retained graph marks Queue
metadata, nested full-key directories and all sidecar bitmap containers before
reclamation. Recorded DLQ destinations conservatively stop collection until
their historical dependency closure is implemented.

`QueuePartition.claim` freezes a bounded original selection from eligible FIFO
heads, capped by declared and deployment limits and remaining active-lease
capacity. Exhausted capacity cannot become an accepted empty result. The claim
persists exact epochs, attempts, trusted time bounds and its immutable selection
before acknowledgement, and rechecks current authority and conservative liveness
at publication. Original claims, including empty selections, remain exact on retry
after expiry or loss of authoritative time; a fresh selection needs a new identity.
The retained graph preserves each original selection's earlier batch and placement
directories. This storage receipt does not establish current lease status or
settle any message.

The Queue wrapper exposes enqueue, claim, observation, original outcome recovery and
physical maintenance. It has no Stream consumption, group or age-expiry API.
The service must still compose this storage boundary with the shared catalog
operation namespace and current grants; installed Queue execution, current lease
inspection and durable settlement publication remain open.

The storage owner also persists explicit group assignments and generations.
Current batch reads return borrowed verified slabs and an observed cut; that cut
does not pin history or prove completed consumption. `beginRead` separately
publishes a finite read pin over an exact immutable `LogRead` basis. Bounded
`readPage` windows retain their output independently of cache and scratch and
carry authenticated cumulative coverage over that same cut. Later appends never
extend it. Group progress advances only through `commitOffset` with completed,
owner-authenticated coverage, current generation and expected checkpoint. Release
closes a pin without advancing group progress; early close is not completion.
Original offset and release receipts remain recoverable after further progress,
key rotation, pin closure and restart. Missing read/evidence objects block replay.

The adapter supplies the private read-authentication key, serializes catalog
changes, enforces current grants and binds global operation identity across
objects. Every read, including terminal metadata, rechecks current authority after
buffering. The catalog and native service compose the owner into signed payload
operations and bounded notification waits; see the
[Streams reference](../../../docs/handbook/reference/streams.md).
`flush` seals one accepted batch per call through a fixed physical cut, preserving
its original receipt and offsets. Shared `.tseg` columns and a separate immutable
delivery-metadata sidecar must reproduce the original payload digest before their
paged placement index is published. Existing read pins keep their old placements;
new reads can traverse sealed batches and the hot tail through the same iterator.
An optional declared UTC timestamp column supports finite half-open microsecond
bounds. Verified zone maps prune nonmatching sealed groups without assuming time
follows offset order. Returned-row and scanned-offset budgets are separate;
filtered empty pages keep exact continuation and completion evidence.
Build and cold-read work have a separate 64 MiB default allocation budget, with
at most 1,024 rows per segment group. These finite operation bounds do not cap
the durable segment directory. Missing sidecars reject without falling back to
different history. The retained graph protects both objects and allows obsolete
WAL copies to be collected once pins and recovery no longer need them.
`LogHistory` shares the immutable TWAL archive codec with Tables, staging at most
eight frames per unit. `checkpoint` publishes an exact `LogRecovery` baseline;
`trimArchived` requires both accepted archival coverage and that checkpoint,
preserving the publishing record. Cold recovery verifies the publication and
replays bounded successors. Pinned reads and original receipts remain usable
through physical WAL trim; missing checkpoints or required archive bytes block
recovery or reads. `LogStorageRoots` enumerates the selected checkpoint and
hash-linked replay in bounded steps. The native adapter admits only qualified
trim floors; the catalog retained graph keeps live pins, original receipts and
required archive frames through physical collection. The local node composes
these units through bounded catalog traversal and current native maintenance
authority, sharing its allocation budget with Table work.

`archiveMaintenanceUnit` persists a fixed archive/checkpoint target and advances
it by at most one publication per call. `compactionMaintenanceUnit` resumes a
frozen key-compaction cut in at most 64-row steps. Accepted source and completion
frontiers let both become idle after finite input; their own bookkeeping does
not create another pass. Lost replies and restart recover those same targets.
Later appends and consumer progress can select further work. Retirement closes
unpublished compaction without discarding accepted payloads or read pins.

After logical compaction, `rewriteMaintenanceUnit` replaces one sparse accepted
batch per unit under a retained sealed frontier. It preserves original encoded
row identities and removes only offsets proven hidden. Batches with at most half
their original rows still visible qualify; empty placements retain range and
receipt evidence without a segment. `LogView` encodes sparse ordinals in bounded
caller buffers. Reads and collection validate omitted offsets against each
retained visibility root. Prior pins and replay keep the old placement until
closure and a later checkpoint permit collection. The node composes rewriting
with logical compaction under the same maintenance budget.

An optional control store must address the same physical namespace and current
authority with the deployment's reserved capacity. Offset settlement, read
release, reassignment, expiry, archive and checkpoint use it; fresh append, read-pin and
group admission use ordinary capacity. Native disk tests fill ordinary quota,
complete progress and closure, and verify that revocation still refuses both
mutation and original-outcome disclosure. Reserved capacity grants no expiry or
permission, and remains finite.

`LogTime.Source` supplies a trusted closed UTC interval when timing is configured or
required by retention. Append persists its pre-staging upper bound and rechecks
time under the publication guard. Missing/regressing clocks and an already
elapsed retention window refuse fresh publication. Accepted clock floors survive
restart; original receipts and recovery do not depend on current clock
availability. Explicitly untimed unlimited history cannot be assigned a synthetic
time by a later policy change.

`expireHistory` advances the logical retained boundary by at most one sealed
batch through a fixed physical cut. It requires a declared age and trusted time,
and cannot cross the oldest consumer checkpoint. A paged offset index finds that
checkpoint without loading all groups. Ineligible work reports whether it is
unsealed, untimed, not due or protected by a consumer. Existing pins retain their
original bytes; new reads below the boundary report `LogRangeExpired`.
Expiry requires a lower UTC bound proving that the append's upper bound plus its
age has elapsed. The accepted record preserves that lower proof separately from
the upper clock floor, so recent appends do not prevent eligible older expiry.
Original outcomes, producer fences and logical offset allocation survive expiry.
Physical collection separately waits for pins and recovery dependencies to close.

`compactStep` captures a fixed source cut and performs two bounded passes: a
paged full-key index identifies the latest offset under the declared collation,
then a Roaring mask hides superseded sealed values below protected consumer
checkpoints. Each call handles at most 64 rows. Publication rechecks consumer
protection; original pins keep their earlier visibility and newer reads preserve
scanned coverage across hidden offsets. Tombstones remain until history expiry.
Work resumes after restart or explicit cancellation, which does not undo any
published visibility. Sparse segment payload rewriting remains separate; the
current pass preserves original batch bytes and receipts.

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
- `DocumentDeclaration.zig`, `DocumentInitialization.zig`, and `DocumentShredder.zig`:
  Immutable `DDECL001` Document declarations in `document-definitions/{sha256}.data`,
  fenced `DINIT001` `.genesis` partition initialization at `lsn == 0` under
  `PublicationGuard`, and adaptive `.tseg` subcolumn shredding into five-state
  (`value`, `null_value`, `missing`, `type_error`, `conflict`) columns with
  `RBC1` presence/null/conflict bitmaps, collation-aware (`utf8_binary`,
  `ascii_ci`, `ebcdic_cp037`) zone maps, and `SuccinctTree` residual topologies.
- `DocumentPartition.zig`, `DocumentEvidence.zig`, `DocumentRead.zig`,
  `DocumentPartitionRecord.zig`, `DocumentRecovery.zig`, and
  `DocumentStorageRoots.zig`: Serialized direct Document partition owner accepting
  single-append WAL mutations (`DOCPART1`), immutable operation outcomes
  (`DEVID001` in `document-evidence/{sha256}.data`), retained read bases and
  HMAC-SHA-256 cumulative coverage cursors (`DREAD001` in
  `document-reads/{sha256}.data`), finite merge-window checkpoints, WAL archival,
  recovery checkpoints (`DCHECK01` in `document-checkpoints/{sha256}.data`),
  physical WAL trim (`trimArchived`), and bounded retained root enumeration.
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
  object store interface (`putImmutable`, bounded `putImmutableBatch`, `putConditional` with `if_none_match` / `if_match`,
  `getRange`, `head`, `delete`).
- `LocalSegmentStore.zig`: POSIX object owner with per-key process locks, atomic
  descriptor publication, immutable content, chunk-verified range reads and no
  whole-object disk cache. A separate memory fixture implements the same typed
  operations. See [object persistence](../../../contracts/TRANSIT_STORAGE_V1.md#local-object-persistence).
  An immutable batch borrows up to eight distinct keys and their bytes until
  return. Success makes every item durable; failure may leave a visible subset
  and writes no output metadata. Exact retry uses the same keys/content. This
  supplies no atomic multi-object visibility or SQL acceptance. Disk batches
  lock keys in canonical order, sync each content file, share one content-directory
  barrier, sync/replace each descriptor, then share one descriptor-directory
  barrier. Providers without grouped publication execute individual durable puts.
  `TreeStore.stageMany` uses these batches with bounded stack scratch; no backing
  allocation or cross-command queue is introduced.
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
