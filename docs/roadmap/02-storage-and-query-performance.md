# 2. Local durable storage, `.tseg` segments and bounded queries

[Roadmap](README.md) · [Tracker #109](https://github.com/spoke-sh/transit/issues/109) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** In Progress

Replace the current B-tree-over-HTTP-stream-pages storage bottleneck with a
four-tier storage hierarchy over two pluggable primitives (**`TransitLog`** and
**`TransitObjectStore`**), a pure-Zig hybrid OLTP/OLAP segment format (**`.tseg`**)
with composable physical codecs and collations, bounded native persistence and
correct local conditional publication. [Provider/concurrent-writer qualification](15-storage-providers-and-concurrency.md)
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

The local object path now stages immutable raw payloads and chunk checksums, then
publishes one definition-bound descriptor under a per-key process lock. Range
reads do not populate a whole-object cache. Three twelve-process races establish
one winner for create, compare-and-swap and competing immutable puts; component
tests cover restart, corruption, bounded allocation and six sync failures. This
advances #114 and the object-read portion of #116. Physical collection remains
dependent on retained-root/pin ownership, and Table/native integration remains
open.

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
qualification to [milestone 15](15-storage-providers-and-concurrency.md).
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

### Current implementation assessment — 2026-10-25

Baseline: merged tree `b720c488` (identical to implementation `4dc0d3ba`).
Issues #109, #113–#118, #123–#128 and #76 were refreshed for this assessment.
Their earlier source diagnoses remain historical evidence, not a description
of this tree. The lifecycle acceptance follow-up retains ownership of its
pending full-suite qualification; this assessment does not mark that work passed.

| Criteria | Current code and recorded evidence | Remaining local delivery |
| --- | --- | --- |
| Acceptance and identities (#111/#112/#115/#125) | `TablePartition.apply`, `admit`, `perform` and `changeDefinition` publish immutable row/index roots and original receipts through one Table WAL. `DirectCatalog` owns names; `TableSnapshot` retains exact definitions and unflushed cuts. [Partition evidence](../history/qualification/storage.md#table-partition-acceptance-and-retained-read-pins--2026-10-22) and [installed recovery](../history/qualification/runtime.md#installed-direct-execution-recovery--2026-10-23) cover the delivered boundary. | Preserve these guarantees through each physical change. Independent Tables remain independent cuts. Multi-Table transaction sessions belong to milestone 5. |
| Segmented WAL (#113) | `LocalWal` rolls incremental files, persists epochs/frontiers/floors, recovers bounded frames and rejects missing acknowledged history. [Disk evidence](../history/qualification/storage.md#data-operation-contracts-and-local-wal-persistence--2026-10-22) includes 73 partitions, more than 64 MiB and sync uncertainty. | Complete process-death and disk-full/I/O schedules, group-commit disposition and retention-owner integration. Repeated directory enumeration is bounded in memory, not indexed in I/O. |
| Local object publication (#114) | `LocalSegmentStore` locks per key, publishes immutable payload/checksum files through a durable descriptor and verifies touched chunks. Existing independent-process races establish one winner. | Publication-boundary process-death schedules and retained-root/orphan collection remain; descriptor deletion does not reclaim payload files. |
| Native control/process/KV/Document persistence (#126) | `transit-backend-local` persists native roots, turns, blocks and exact receipts in partition zero and immutable objects. [Native evidence](../history/qualification/storage.md#native-authority-over-local-storage--2026-10-22) covers restart, accepted-floor trim, control reserve and signed callers. | Qualify local immutable-object collection/compaction, standalone payload ownership and all retained native roots; Table tests cannot close these criteria. |
| Complete replay and hot state (#115/#116) | The live owner uses `TreeStore` paged point/physical/identity indexes, not `TableMemtable`. Its recovery follows all contiguous hash-linked records. The separate memtable consumes all WAL pages but retains an unbounded active row set and whole manifest. | Reconcile or retire the separate component profile; bound all remaining builders/decoders and measure cold recovery beyond cache. Do not wire the standalone component into the live path as a substitute. |
| Immutable reads and primary-key access (#116/#128) | `TablePartition.getAt` uses a paged hash-key directory and checks the decoded key. `readSegment` still fetches the complete object; `readRowWithSchema` decodes every column in one group. `TSeg.Footer.pk_index` is a sorted resident array, not a paged B-tree. | Shared verified range reader, explicit decode ownership/budgets, projection/pruning before payload reads, ordered primary-key range access and table-wide candidate/I/O measurements. |
| History and pins (#127) | `history`, `retainHistory`, `historyAt` and retained scans distinguish logical acceptance from flush/control progress. `TableChangeReader` provides complete snapshot/tail transactions with explicit retained leases. | Archive/checkpoint coverage, retention floors, resumable physical trimming and collection with slow/offline consumers and live pins. Current Table retention keeps all WAL and objects. |
| Maintenance (#116/#127) | `TablePartition.flush` rewrites one bounded live WAL group through the same acceptance log; old roots retain original locators. Native maintenance only trims an accepted history floor. | Bounded checkpoint/compaction/deletion-vector consolidation and safe collection, restartable progress and control reserve. Milestone 3 wires automatic triggers and public observations; local mechanisms remain here. |
| Codecs and collations (#118/#128) | `TableSchema`, `PhysicalCodecs` and `Collation` admit explicit profiles; ICU rejects, CP037 uses a full table, HFP admission is exact, and the symbol-table format does not claim FSST interchange. SQL rejects non-binary text comparison. | Independent encoded/decoded and pruned/unpruned query oracles, encoded operators, five-state provenance, compatible borrowing and complete comparison/hash/order propagation. Explicit rejection is not delivery of the remaining selected profiles. |
| Bounded execution (#116/#128) | Direct sources return owned bounded rows; Fuze has separate compute budgets and relational disk-backed group state. | Audit sort/hash/spill, decoded expansion and cancellation across the shared reader, including data larger than caches and many small segments. |
| Evidence and public claims (#123/#124/#76) | Public storage/Table owners distinguish installed acceptance from separate helpers. Earlier performance measurements and failures remain recorded. | Matched disk-backed owner and installed SQL controls, byte/range/allocation/RSS attribution, focused recovery proofs, repository checks and committed-HEAD clean lanes. No latency target is inferred. |
| Providers/concurrent writers (#117/#121) | Local exclusive ownership and process-locked object publication are implemented. OCC/cache/provider helpers do not establish installed concurrent writers. | Milestone 15 retains distributed providers, disk cache and integrated concurrent-writer obligations; local safety and fencing remain here. |

Implementation order: first build and qualify the shared bounded segment range
reader and integrate it into live Table reads; then complete ordered access and
encoded/pruned execution against independent controls; then implement retained
checkpoint/history and physical maintenance for both Table and native owners.
Run focused proofs per slice, retain the current-v1 cutover gate for incompatible
formats, and qualify installed performance/recovery with milestone 3. This is an
implementation sequence, not a transfer or reduction of outstanding criteria.

### Implemented increments after the baseline

- The [ingestion/commit matrix](../../tests/storage_benchmarks/2026-10-26-ingestion/README.md)
  completes 384 independently verified write/readback samples with median/p95
  owner and WAL timings, allocation/RSS and retained-file attribution. Bulk
  ingestion reduces WAL bytes without a consistent total latency/storage gain.
  The [full growth attempt](../../tests/storage_benchmarks/2026-10-26-growth/README.md)
  remains failed at native setup timeout, despite both Table fixtures completing
  under the fixed process memory ceiling. These source-attributed accounts
  advance #124/#76; native growth, final-revision qualification and the local
  group-commit disposition remain open.

- Table history/recovery root enumeration follows a fixed accepted cut with
  one bounded frame or capsule per step. Complete-chain checks bind its final
  root and selected checkpoint while keeping historical control graphs weak.
  This advances #116/#127; live pin/data edges, all-owner selection, durable
  marks/inventory and physical deletion still require collector integration.

- Native policy evaluation reuses at most eight verified membership/grant scan
  pages at one exact immutable policy root. Typed decoding, evaluator budgets,
  current authority and publication/disclosure fences still run. This targets
  repeated index I/O observed while investigating the native growth timeout
  (#124/#126); complete growth and matched performance qualification remain open.

- A fixed-memory Table directory walker verifies page paths and emits typed
  row, pin, evidence and archive edges. Long ordered-key child directories are
  separate queued work; released pins do not recursively retain snapshots.
  This advances the collection foundation for #116/#127. Global retained-root
  selection, durable work/mark queues, allocation inventory and physical
  Table-object deletion remain open.

- Table receipts and operation controls reference bounded immutable evidence
  instead of full accepting WAL frames. The original definition, outcome,
  request identity and frozen intent remain retained without holding an old
  row-root graph. This advances the retention dependency foundation for
  #116/#127. Safe collection still requires a complete inventory and traversal
  of all live owners, history, snapshots and recovery roots; no Table collector
  is implied by the evidence format.

- Explicit Table history expiry now publishes a monotone logical floor through
  the existing acceptance WAL, after archive and recovery coverage. A paged
  directory of live history leases protects offline consumers without scanning
  all pins. Exact snapshots, receipts and admitted work remain retained. Required
  root fields use a shared current-v1 cutover. This advances #127; safe physical
  Table-object collection and automatic installed scheduling remain open.

- Direct Table/catalog guards retain the storage epoch from their first
  successful authorization through staging and publication. A native fence
  rejects an old candidate even after it reacquires current policy. Point and
  bulk race tests, the complete local backend suite and signed Table
  authorization proof cover fresh retries and original receipts. This closes a
  prerequisite for safe data-object collection; it does not supply the
  remaining retained-root inventory or physical collector (#114/#116/#127).

- A paired ReleaseSafe disk-owner matrix completes 768 verified samples across
  native/Table sizes, checkpoint variants, scan/range access and cold/warm file
  pages. The [measurement account](../../tests/storage_benchmarks/2026-10-26-owners/README.md)
  retains raw values, build/fixture identities and phase/allocation/RSS/I/O
  evidence. Narrow ranges reduce requested data; Table checkpointing reduces
  logical replay and warm recovery. Cold recovery gains are inconsistent, and
  native straddling-segment startup/read work remains. This advances #124/#76;
  ingestion/commit percentiles, larger-than-RAM growth and final common-revision
  qualification remain open.

- Concrete Table writes, retained statement execution, ALTER rewrites and flushes
  now share an explicit private allocation ceiling, independent of encoded-row
  and index-work limits. This advances the remaining builder audit in #116/#128.
  Exhaustion preserves accepted state or records the admitted operation's existing
  work-limit outcome; transient allocator failure remains distinct. This is an
  allocation bound, not matched whole-process RSS/performance qualification.

- Table recovery checkpoints now publish a bounded complete root and chain basis
  through the same acceptance WAL. Restart validates that publishing transition
  and all later records while preserving receipts, pending operations, pins and
  unlimited logical history. This advances #115/#116/#127; historical integrity
  remains checked on access, and logical expiry/object collection remain open.
  The mandatory stored reference requires a shared current-v1 cutover.

- Bounded Table compaction now consolidates live rows from older segments, omits
  deleted/replaced rows and preserves logical roots, retained snapshots and exact
  operation evidence. A fixed segment boundary plus accepted locators provides
  restart progress; private build allocations, rows, bytes and index work have
  explicit bounds. This advances #116/#127 and the builder audit. Old physical
  objects remain retained pending the separate collection/retention owner.

- Table roots now publish a paged archive of complete original WAL records before
  physical prefix trimming. Bounded archive calls and resumable trimming preserve
  receipts, admitted operations, unflushed snapshots and offline history cursors;
  recovery still validates the complete chain through archive plus WAL. The
  mandatory archive coordinates require a shared current-v1 cutover. This advances
  #113/#115/#127; logical retention floors,
  Table-object collection and automatic scheduling remain separate obligations.
  The subsequent increments add replay checkpoints and compaction. Executed validation is recorded in the proof ledger.

- Finite Table comparisons now bind binary, ASCII_CI and CP037 semantics through
  scalar/vector/page execution, prepared parameters, captured source descriptors,
  UPDATE/DELETE and range-count qualification. CREATE TABLE and ADD COLUMN accept
  column COLLATE declarations. The shared current-v1 cutover replaces FQP1/TQS1
  identities and regenerates consumers; older accepted artifacts reject.
  Independent scalar/vector masks, 280 grammar cases and the signed disk-backed
  Table collation proof cover the delivered profile. Text relational joins,
  grouping/order and general SQL encoded pushdown remain outstanding.

- The standalone unbounded `TableMemtable`, `TableStorageEngine` and
  `TableSegmentScan` profile is retired. The installed paged `TablePartition`
  remains the Table acceptance and retained-read owner. The shared current-v1
  definition is replaced because the stored `TRDL` interpretation is removed;
  earlier artifacts reject without reset. This resolves the separate-profile
  item in the baseline's replay/hot-state row (#115/#116), not all builder,
  recovery, compaction or resident-memory criteria. Current interfaces and
  compatibility are documented in the [storage owner](../../packages/zig/transit-storage/README.md)
  and [versioning policy](../handbook/reference/versioning.md); the
  [proof ledger](../history/qualification/README.md) records executed validation.

- The exclusive local WAL has a finite TLA+ publication/recovery model with
  independent durability states and removed-guard controls. Its counterexamples
  motivated file and directory recovery barriers; disk regressions check their
  ordering. This does not close physical power-loss, retention-owner or complete
  clean-CI qualification. See the [proof ledger](../history/qualification/README.md).

- Verified segment range reads and bounded decoding are wired into live Table
  point/scanned reads; 256-row groups separate decoder residency from result
  batches. The WAL keeps bounded verified seek coordinates to avoid repeated
  prefix decoding. Focused disk and signed service evidence is recorded in
  [the proof ledger](../history/qualification/README.md); clean qualification remains separate.
- Local process-death schedules cover WAL append/fence publication, interrupted
  partial/full trimming and conditional/immutable object publication. Retrying a
  persisted trim boundary resumes physical prefix removal. The
  [scoped proof](../history/qualification/storage.md#local-storage-process-death-boundaries--2026-10-26)
  advances #113/#114; disk-full/I/O schedules, retention-owner integration and
  retained-root/orphan collection remain open.
- Injected `NoSpaceLeft` and sync-error schedules exercise actual partial disk
  writes for WAL append/rollover and conditional/immutable objects, preserving
  accepted bytes and exact retry/recovery. The host filesystem is not filled;
  broader device failures and safe physical collection remain separate work.
- Startup now uses an independent directory handle while recovering partitions,
  preserving the full integrity gate when segment names span directory pages.
  A 384-segment regression exposed skipped partitions in the former nested walk;
  this fixes validation coverage without changing persisted bytes or authority.
- Recovery inventories segment bounds/count once per loaded partition and follows
  verified contiguous LSNs across files. Sequential reads also open successor
  segments directly. Cold partition loads and trim still enumerate directories;
  this is a bounded local traversal improvement, not a persistent segment index.

- Full collation-aware primary keys now have a paged immutable directory in each
  accepted Table root. Retained intervals use source/interval-bound cursors and
  bounded owned pages through the signed direct API and shared reader. Mutation,
  schema rewrite, flush, DROP and current disclosure checks preserve that root's
  meaning. This stored-root and wire cutover replaces the shared v1 definition
  and regenerates native, host and browser resources together.
- Accepted row updates and physical flushes stage index mutations in bounded
  batches under the original single acceptance boundary. Finite retained SQL
  SELECTs, including prepared execution, also use the existing complete-key
  equality qualification rather than scanning every source page.
- A disk-backed, same-snapshot control now compares a narrow ordered interval
  with a complete scan across eight segments, using fresh owners and one cached
  index page. The [measurement](../handbook/reference/performance.md#retained-table-key-range-measurements)
  attributes segment ranges/bytes and index misses; installed latency and broader
  mixed-workload controls remain unqualified.
- Selected column decoding now preserves complete-page validation while retaining
  only requested cells. The shared reader caches verified encoded groups with
  separate encoded and combined decoded/scratch budgets. Live current/retained
  point reads use that path; scans retain full-group decoding. Independent byte
  fixtures, all-codec state/provenance checks, allocation failures and a same-cut
  disk control establish the [scoped behavior and memory counts](../history/qualification/storage.md#selected-table-segment-decoding--2026-10-26).
  This advances #116/#118/#128; repeated selection still validates skipped data.
- Finite `COUNT(*)` now qualifies conjunctions of comparisons over one complete
  single-column primary key for retained interval traversal. Bound bytes are
  owned and cursors remain source/interval-bound; the original predicate and
  final current-authorization gate still execute. Row output, ordered aggregates,
  composite ranges, general predicates and captured execution retain their
  existing paths. This advances SQL inequality pushdown for #116/#128 without
  claiming general pruning or encoded predicate execution. See the
  [query owner](../../packages/zig/transit-query/README.md) for the exact profile.
- Compatible borrowed batches, relational text comparison/hash/order,
  retained checkpoint/maintenance and native-owner obligations remain
  open. A passing Table range test does not close #113–#118 or #123–#128.

- Finite identity-ordered Table SELECTs, including prepared execution, push
  required output/predicate/key columns through the signed retained reader to
  segment page selection. Projected cursors bind the exact column set; source
  coverage and original plan/error attribution remain intact. WAL fallback keeps
  bounded full-row decoding. This advances projection integration for #116/#128;
  compatible borrowed batches and relational text comparison/hash/order remain
  outstanding.

- Encoded filtering accepts bounded visible-candidate pages in logical traversal
  order, with an explicit selected-prefix boundary. It preserves failure order
  when segment positions differ from identities and excludes semantic failures
  in omitted rows. Whole-page integrity checks still run. This supplies a
  prerequisite used by retained Table filtering; signed source attribution and
  final SQL disclosure are exercised by the integration below.

- The retained Table owner now applies encoded predicates to live identity
  locators, caches bounded deferred group decisions and reports skipped-row
  coverage, per-row offsets and plan-bound continuations. Mixed segment/WAL
  sources, deletion, restart, finite collations, allocation failures and final
  authorization have focused component checks. Signed `filter_scan` now binds
  canonical FQP1 to the exact source, schema, collation vector and plan identity.
  The retained reader validates sparse offsets and complete coverage; finite
  direct/prepared SQL preserves original failure positions and LIMIT prefixes.
  Signed disk-owner, delegated/borrowed-read and post-compute revocation proofs
  pass. Projected and filtered reads share the node's per-Table lock stripe.
  This advances #116/#118/#128 without claiming borrowed segment batches,
  relational predicate lowering or new installed performance measurements.

- Retained snapshot/history metadata resolves the selected interpretation and
  current authority through one request-local recovered Table owner. Original
  delegation checks still precede historical successor reads. The focused
  metadata fixture reduces snapshot object ranges from 14 to 8 while checking
  identical retained evidence, final denial, allocation failures and no writes.
  The broad history-replay rerun remains an independent completion gate.

- Table group scans retain verified encoded pages and borrow plain text, binary
  and JSON payloads through an explicit group owner. Recursive/conflict metadata
  and compressed expansion retain bounded decoded ownership; result rows detach
  before cache replacement. This advances shared reader ownership in #128 without
  changing stored formats. Arrow-compatible physical buffers, broader batch
  handoff and relational text comparison/hash/order remain open.

- Finite direct Table computation now borrows variable and recursive cells from
  one retained decoded reader page. The executor stops at its page boundary and
  resets views before replacement, while returned results remain independently
  owned. Focused lifetime and allocation-failure controls cover this handoff.
  This advances #128 without changing stored pages or claiming Arrow-compatible
  physical buffers; transport decoding and output materialization still copy.

- Qualified plain segment columns now store aligned Arrow validity, offsets and
  value buffers under a new shared current-v1 definition. Buffered Table scans
  use these arrays without retaining a decoded cell array; sparse error/conflict
  details preserve the complete state model. The group supplies a borrowed
  nullable Arrow value-child view with explicit directory/group lifetimes.
  Recursive and other encoded columns retain bounded decoding. This advances
  #128's physical-buffer boundary; external C data import/export, relational text
  comparison/hash/order and the remaining maintenance/evidence gates retain
  their explicit owners.

- The shared codec walker now supports encoded single-column predicates with
  one-byte row outcomes, dictionary/run evaluation reuse and detached selected
  output. `TSegReader.filteredGroup` combines collation-aware zone-map pruning
  with late projected decoding under the existing resident budgets. Independent
  byte/mask controls and allocation-failure checks cover this component path;
  general SQL lowering and installed/disk performance
  qualification remain open. This advances #118/#128 without closing their
  integration or complete comparison/hash/order obligations.
- Encoded group filtering also executes bounded multi-column Boolean programs.
  Zone-map abstract truth preserves unknown and eager source errors under
  NOT/AND/OR, and the shared row machine arbitrates row/instruction order.
  Logical program lowering keeps its original atoms and borrows their literals
  under the exact Table interpretation; no wire or accepted-plan identity changes.
  This is reader-component execution, with direct-service lowering still open.
- Local native collection now uses an allocation FIFO over a separate segmented
  WAL, accepted epoch/time fences, shared retained-root traversal, paged marks
  and resumable exact-object deletion. Disk cases preserve captured block values
  across bounded native compaction/checkpoint and restart; process-death schedules
  exercise deletion and FIFO progress. This advances #114/#116/#126/#127 and
  replaces the shared current-v1 definition for the mandatory inventory layout.
  Table checkpoint/history/collection, standalone payload ownership, automatic
  installed triggers and complete performance qualification remain open.
- The local standalone payload adapter now binds one immutable creation attempt
  and verification/deletion to the current native payload record. Recovery syncs
  observed publication without repeating creation; opted-in retirement retains a
  permanent attempt marker. This advances the payload ownership item in #126.
  Installed local payload routes and lifecycle scheduling remain milestone 3
  integration work; Table retention and full storage acceptance remain open.

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
partitioned concurrent-writer delivery belong to milestone 15. Existing helper
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
[Milestone 15](15-storage-providers-and-concurrency.md) delivers enforceable
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
and [milestone 15](15-storage-providers-and-concurrency.md). This owner proves
the declared local sync/restart profile and explicitly excludes losing the only
durable disk. Distributed providers, cache qualification and concurrent writer
integration have moved; local safety, native recovery, codecs and bounded
query/maintenance obligations have not. Replication, disaster recovery and
automatic placement each retain their later acceptance owners.

## Delivery sequence

Resolve #125/#111, #126/#127 and #128/#118 contracts before their dependent
formats and code. Qualify the local component foundation here and the actual
installed caller paths in milestone 3 before milestone 15 extends distributed
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
   as installed acceptance in milestone 3 and provider acceptance in milestone 15;
   their observations must not be replaced by library-only measurements.

## Completion evidence

The [indexing](08-indexing-and-access-paths.md) and
[data structures/performance](10-data-structures-and-performance.md) milestones
extend this foundation. Bounded memtables/manifests, paged primary-key access,
range reads and sound pruning remain requirements here. Measure candidate
segments, index/data pages and bytes fetched; whole-segment reads cannot stand
in for promised bounded point access. Size membership filters against distinct
key counts and measure false positives and net I/O avoided. Preserve independent
scan oracles, collation-correct comparisons and local recovery while replacing
the current array/full-segment baselines. Establish database and native-runtime
baselines now; later algorithm comparisons do not defer these gates.

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
