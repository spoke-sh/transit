# 11. Data structures, query optimization and runtime performance

[Roadmap](README.md) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · [Allocation guidance #194](https://github.com/spoke-sh/transit/issues/194) · **Status:** In Progress

Make declared data operations and durable runtime work fast under explicit
latency, throughput, memory and recovery budgets. Pursue leadership against
reproducible database and runtime baselines, with equal semantics and resources.
Deliver measured physical structures, statistics and plan selection plus runtime
improvements through actual callers. Performance claims identify the workload,
configuration, comparison and evidence; the ambition to be the fastest database
and runtime does not establish a universal ranking.

## Prerequisites and scope

Consume the qualified [local engine](02-storage-and-query-performance.md),
[installed cutover](03-live-storage-and-sql-cutover.md),
[results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[client foundation](07-client-foundation-and-language-apis.md),
[historical interpretation](08-standards-and-catalogs.md),
[indexing](09-indexing-and-access-paths.md) and
[managed computations](10-sql-and-dataflows.md).
Earlier owners must already meet their boundedness, correctness and performance
gates. This milestone owns deeper structure selection, statistics/costing,
cross-layer optimization and an integrated local performance checkpoint.

Qualify database and existing native runtime paths together: Table/KV/Document
operations, queries, committed change consumption, native message delivery,
Station turns and accepted-work recovery. Use already qualified installed
callers; broader [SDK coverage](16-service-and-sdk-coverage.md) and
[mixed composition](29-programming-model.md) repeat the measures as they land.
Do not make their future APIs prerequisites of this local milestone. Full
distributed and complete TPC qualification stay with their later owners.

Start from [performance](../handbook/reference/performance.md),
[benchmark coverage](../handbook/reference/benchmarks.md),
[query mechanisms](../handbook/internals/query-engine.md),
[storage mechanisms](../handbook/internals/storage-runtime.md),
[execution](../handbook/internals/execution-model.md) and the
[benchmark tooling](../../tests/performance/declarative/README.md).
The current component benchmark inventory does not execute complete TPC suites.

The [issue #194 implementation plan](#implementation-plan-for-issue-194)
sequences allocation removal in existing paths and tracks the related string,
search and compilation work through its numbered owners. Phases A–E are accepted early implementation work; the broader milestone
prerequisites and later phases remain outstanding.

## Delivery sequence

1. **Freeze workload contracts and establish baselines before choosing winners.**
   Define supported operations, correctness oracles, selected competitor versions,
   hardware/toolchains, resource budgets, durability, isolation, retained history
   and measured boundaries. Set numeric latency/throughput and regression budgets
   before optimization runs. Capture component, subsystem and installed-client
   measurements separately; profile where time, allocation, bytes and contention
   actually go. Use complete operation outcomes, not transport acknowledgements,
   as the durable-work boundary. Publish baseline gaps and failed/unexecuted cases
   alongside wins. Benchmarks and focused improvements begin in earlier milestones;
   this owner expands and compares them at a common local revision.
2. **Evaluate and deliver physical structures and zero-steady-state-allocation hot paths against their real lifetimes.**
   Use the candidate matrix below, maintaining a simple independent oracle and
   matched baseline for each replacement. Preserve collation, five-state errors,
   stable row/version identity, current authorization and atomic publication.
   Separate short-lived working state from immutable retained/checkpoint state,
   and enforce **explicit `scratch` versus `output` allocator discipline**:
   pre-allocate worker, partition and batch slabs/arenas and reset `scratch`
   workspaces with `.retain_capacity` so steady-state hot loops (ingestion,
   `.tseg` flush, point/range lookups, vectorized scans and wire batching) perform
   zero OS/heap allocations after warmup, verified by counting-allocator unit
   gates. Qualify allocation failure, resize/split/merge, reclamation and restart
   before reporting a faster replacement. Keep 64-byte CPU cache-line alignment,
   L1d/L2 working-set residency, storage pages, execution vectors and wire/display
   batches independently budgeted.
3. **Deliver statistics, deep join-graph optimization, physical plan selection, partitioning and clustering layouts.**
   Maintain bounded, inspectable statistics with source/definition provenance:
   row/distinct counts, histograms/distributions, relevant correlations, declared
   `FOREIGN KEY` referential cardinality invariants and collection cost. Define
   sampling, refresh and invalidation; stale estimates may affect speed but cannot
   justify excluding possible rows. Support declarative **Table Partitioning**
   (`PARTITION BY` range/time/list so retention and archival can drop or detach
   whole partitions in $O(1)$ manifest metadata work rather than row-by-row `.tdel`
   bitmaps) and **Multi-Dimensional Clustering Keys** (`CLUSTER BY` linear sort
   keys and space-filling Z-order / Hilbert curves over columns such as
   `(event_time, symbol, venue)` decoupled from the primary-key uniqueness
   constraint) so analytical and time-series scans prune `.tseg` segments across
   multiple predicate dimensions. Cost scans versus index probes, segment/partition
   pruning, join order/strategy—including `DPhyp` / adaptive join-graph ordering,
   universal `D-Join` subquery unnesting, `FOREIGN KEY` join elimination,
   **directory-tagged relational hash joins** (with embedded 16-bit Bloom/tag
   signatures in the directory slot for a ~10-instruction probe filter),
   **Diamond-Hardened / Worst-Case Optimal Joins (WCOJ / FreeJoin)** for cyclic
   and skewed multi-way queries, and streaming $O(N + M)$ bitemporal `AS OF JOIN`
   merge plans—window frames, aggregation, ordering and external NVMe spill using
   selectivity, locality, projected columns, coverage and expected I/O. Qualify
   join ordering and skew handling against the **Join Order Benchmark (JOB)**.
   Include parameter sensitivity and skew; qualify prepared-plan lifetime with the
   transaction and schema owners. Rewrites preserve checked arithmetic,
   fallibility, multiplicity and any specified result ordering. `EXPLAIN` remains
   non-executing; observed execution counters come from a separately authorized,
   explicit execution.
4. **Enforce LSM/segment compaction invariants, shared `TablePartition`/`StreamPartition`/`QueuePartition` `.tseg` + Roaring-bitmap structures, LeanStore/Umbra-inspired zero-copy buffer management, scan-resistant caching and fine-grained resource metering.**
   Specify and qualify leveled/size-tiered `.tseg` compaction policies that bound
   the maximum number of overlapping `.tseg` runs per key range ($K_{\max}$),
   trigger segment rewrite/merge when `.tdel` deletion-vector ratios exceed
   configured thresholds, and reclaim sealed `QueuePartition` `.tseg` segments in
   $O(1)$ once their `.tack` Roaring-bitmap state vectors mark all offsets
   acknowledged ([Milestone 6](06-streams-queues-and-durable-runtime.md)),
   preventing point and range lookups from degrading to
   $O(K \log N)$ across fragmented segments or accumulating unbounded tombstone
   overhead under update-heavy workloads. Coordinate with
   [branches](15-branches-merges-and-restore.md) so compaction accounts for
   branch-shared segments and pinned snapshots. Upgrade [`NvmeCache`](../../packages/zig/transit-storage/src/NvmeCache.zig)
   and the in-memory page/chunk buffer pool using **LeanStore and Umbra buffer-management
   principles**: verify SHA-256 cryptographic integrity **once on chunk admission/load**
   from Tier 3/disk into the immutable slab rather than re-hashing and
   `@memcpy`-ing on every L1/RAM read hit, and replace centralized linear/hash
   table lookups and atomic pin/unpin contention with **pointer swizzling /
   optimistic version-latched zero-copy slices** over **variable size-class page
   slabs** ($64\text{ KiB}, 128\text{ KiB}, 256\text{ KiB}, \dots$) with a
   lock-free cooling stage, **scan-resistant eviction** (2Q, ARC or W-TinyLFU)
   and **I/O token-bucket pacing** so sequential analytical scans, bulk imports,
   online index builds and background compactions cannot evict hot OLTP
   index/memtable pages or saturate disk bandwidth. Pair cache and I/O pacing with
   **fine-grained per-query and per-tenant resource metering**—chaining a
   hierarchical `MeteredAllocator` vtable for exact byte accounting with
   per-`Batch` morsel CPU cycle/tick charging and storage range-read/write IOPS
   counters—so queries exceeding their memory budget deterministically spill to
   Tier 2 NVMe or fail with a typed budget error rather than OOM-crashing the
   process, providing the local enforcement substrate for
   [Hierarchical Workload Management (WLM)](22-control-and-policy-plane.md).
5. **Optimize the durable runtime and shared client path.** Measure admission,
   WAL append/sync, mailbox selection, dispatch/wakeup, turn commit, checkpoint,
   recovery and result delivery separately. Evaluate batching/group commit,
   allocation/copy reduction, `comptime` perfect hashing with 16-byte SIMD string
   comparisons for SQL lexing and wire-protocol header/parameter dispatch,
   queue/scheduler layout, worker-local caches and contention removal while
   preserving accepted identity, ordering, fairness, fencing and input/state/output
   atomicity. Specify acknowledgement timing for group commit; delayed persistence
   cannot masquerade as durable acceptance. Bound active work and reserve
   control/recovery capacity under overload. Direct data access stays independent
   of actor mailbox limits when no actor logic is invoked. In-process rates are
   separate from durable disk and installed caller rates; effect replay never
   dispatches to improve a score.
6. **Qualify selected implementations and maintain regression gates.** Run mixed
   database/runtime load with background index builds, flush, compaction and
   maintained computations. Establish sustained throughput at declared tail-
   latency budgets, bounded memory and recovery progress. Reject incorrect or
   unbounded candidates regardless of microbenchmark speed. Retain baseline
   implementations as test oracles where useful, without introducing parallel
   legacy runtime protocols. Any incompatible format/ABI change follows the
   current-v1 cutover with consumer/fixture migration and accepted-work recovery.

## Candidate structures and selection evidence

| Work and candidate | Evidence required before selection |
| --- | --- |
| Hot ordered indexes: cache-conscious B/B+ trees, adaptive radix trees, compact prefixes, SIMD and batched probes | Point/range/mixed-write workloads, composite and collated keys, collision/full-key checks, version visibility, contention, allocation failure and memory reclamation under growth and shrink |
| Immutable indexes: paged prefix trees, sparse directories, per-segment minimal perfect hashing / association tables and segment-level routing | Actual index depth, single-probe equality versus binary-search cost, candidate segments, range requests and bytes fetched under cold/warm caches, projected columns, compaction and retained snapshots; no universal one/two-read claim |
| Membership filters: cardinality-sized conventional or split-block Bloom filters | False-positive rate, bits per distinct key, hash/collation consistency, filter loading/build cost and net I/O avoided across skew and saturation; no false negatives |
| Deletion and candidate sets: sparse arrays, dense bitmaps and Roaring-style containers | Sparse/dense/run-heavy distributions, intersection/union cost, version/deletion correctness, conversion and resident/storage overhead |
| Join, window, temporal and aggregation working state: CedarDB-style directory-tagged relational join hash tables (~10-instruction probe filter with embedded 16-bit Bloom tags), Diamond-Hardened / Worst-Case Optimal Joins (WCOJ / FreeJoin), Swiss-style or Robin-Hood aggregation tables, partitioned arenas, streaming `AS OF` merge and external NVMe spill | Join Order Benchmark (JOB) and cyclic/many-to-many join graphs, key skew, collisions, bounded resize, larger-than-RAM execution (grace/hybrid hash join, external merge sort, window-frame spill), deterministic error behavior and checkpoint/recovery composition; an ephemeral hash table does not replace durable ordered roots by itself |
| Compaction, partitioning, clustering and LeanStore/Umbra-style buffer caching: leveled/tiered `.tseg` mergers, Z-order/Hilbert clustering keys, pointer-swizzled / optimistic version-latched variable size-class slabs ($64\text{ KiB}\text{–}1\text{ MiB}$), admission-only SHA-256 verification and 2Q/ARC/W-TinyLFU caches | Overlapping-run bounds ($K_{\max}$), `.tdel` tombstone reclamation, multi-attribute segment pruning ratios, $O(1)$ partition-drop retention, zero per-hit SHA-256/`@memcpy` overhead on warm RAM hits, multi-core latch scalability, OLTP cache hit-rate preservation during concurrent sequential scans and background I/O pacing |
| Vector and encoded execution: encoded column predicates, late materialization and batching (extended by [Milestone 12](12-vectorized-strings-and-search.md) for 16B collation-prefixed strings, perfect hashing and Block-Max BM25, and [Milestone 13](13-data-centric-compilation-and-specialization.md) for data-centric pipeline fusion and AOT specialization) | Independent encoded/decoded oracles, trailing buffer padding guarantees (16–64 bytes) for branchless SIMD loads, CPU portability, allocation/copy counts and end-to-end gains over required storage codecs; no universal zero-copy assumption |
| Runtime dispatch, zero-steady-state-allocation slabs and resource metering: pre-allocated `scratch`/`output` arenas, hierarchical `MeteredAllocator` vtables, per-`Batch` morsel CPU/IOPS accounting, bounded queues and scheduler/wakeup structures | Zero steady-state heap allocations after warmup under counting-allocator gates, deterministic Tier 2 NVMe spill or typed budget refusal on exhaustion, durable completion latency/throughput, contention, starvation controls, overload/backpressure, recovery capacity and caller cancellation/uncertainty under mixed load |

[BBTree](https://github.com/XiangpengHao/bbtree) and its
[design discussion](https://blog.xiangpeng.systems/posts/bbtree/) are named
evaluation inputs for compact keys, batched traversal and concurrency. They do
not select a Transit algorithm or supply measured Transit speedups. Evaluate
retained allocation/high-water behavior and safe reclamation for each owner;
optimistic version validation alone does not prove race freedom, lock-freedom
or transaction serializability. Implement selected runtime structures in Zig,
with portable fallback and independently qualified target-specific SIMD. Verify
generated instructions and bounds; a vector expression promises no fixed
instruction count or speedup.

[Parquet's split-block filter specification](https://parquet.apache.org/docs/file-format/bloomfilter/#sizing-an-sbbf)
provides sizing guidance; a 256-bit block is an implementation unit, not a fixed
budget for every row group or a guaranteed false-positive rate.
[Swiss-table design notes](https://abseil.io/about/design/swisstables) inform
group-by working-state comparisons, while
[Umbra](https://umbra-db.com/) (Neumann & Freitag, CIDR 2020),
[LeanStore](https://db.in.tum.de/~leis/papers/leanstore.pdf) (Leis et al., CIDR 2018),
[CedarDB](https://cedardb.com/) and
[Diamond-Hardened Joins](https://www.vldb.org/pvldb/vol17/p3215-birler.pdf)
(Birler, Kemper & Neumann, VLDB 2024) inform pointer-swizzled variable size-class
buffer management, ~10-instruction directory-tagged relational join hash tables
and Worst-Case Optimal Joins (WCOJ); they do not supply Transit's durable
publication, snapshot or ordered-iteration contract.
[Egres's resource-control architecture](https://manishrjain.com/egres/) informs
per-query and per-tenant CPU tick, disk IOPS and Zig allocator byte metering;
Transit binds those meters to `Fuze` batch morsels, Tier 2 NVMe spill thresholds
and [Milestone 22's](22-control-and-policy-plane.md) Hierarchical Workload
Management (WLM) without replacing durable acceptance or authority boundaries.
Keep upstream algorithms and license attribution separate from evidence for the
selected Zig implementation.

## Workload scorecard and completion evidence

| Family | Required local journey and observations |
| --- | --- |
| Transactional data | Point/range reads, inserts/updates/deletes, composite secondary access, constraint checks and mixed transactions; committed throughput, conflict/abort rates, p50/p95/p99 latency, WAL/sync and index-maintenance cost |
| Analytical computation | Selective and broad scans, joins, grouping, sorting and bounded spill on supported operators; first-row and verified-completion latency, rows/bytes processed, peak memory and temporary I/O |
| Maintained computation | Committed source changes through activation, catch-up and completed revisions; freshness lag, retained backlog, amplification, backfill interference and recovery |
| Durable runtime | Accepted messages through delivery/turn completion, KV/Document state and recorded intent handling; latency distributions, sustained throughput, fairness, active/resident bounds and restart recovery |

Vary uniform and skewed keys, hits/misses, numeric/string/composite/collated keys,
range selectivity, read/write mix, batch size and concurrency. Cross cache and
RAM boundaries; measure cold/warm disk, repeated growth/shrink, retained history
and background maintenance. Cover claimed x86-64 and ARM profiles separately.
Report throughput versus offered load, queueing/tail latency and overload
outcomes; a benchmark that omits stalled work cannot establish a latency target.

Pin source/compiler/build flags, hardware, datasets, seeds, configuration and
comparison versions. Use warm-up, repeated paired runs, sufficient tail samples
and disclosed variance. Keep durability/isolation/resource budgets equivalent
for comparative claims; identify genuinely different profiles separately. Include
memory, index/storage footprint, read/write/space amplification, build cost and
recovery time so a speedup's tradeoffs remain visible. Compare actual workload
results with independent oracles and exercise faults on each selected structure.

Completion requires installed improvements for the named database and runtime
bottlenecks, a populated scorecard with predeclared targets and regression
budgets met, reproducible raw samples and explicit remaining competitive gaps.
An evaluated candidate may lose; shipping a particular named tree is not a gate.
Preserve every required workload in the report, including unsupported or blocked
comparisons; revise an unattainable scope/target explicitly rather than omitting
its result. A common-revision report must distinguish measured leadership from
the broader ambition and must not present reduced workloads as compliant TPC
scores.

## Continuing performance ownership

[First-class strings and search](12-vectorized-strings-and-search.md),
[data-centric compilation and specialization](13-data-centric-compilation-and-specialization.md),
[foreign models](14-multi-model-and-foreign-relations.md),
[branches](15-branches-merges-and-restore.md),
[providers through clustered execution](18-storage-providers-and-concurrency.md),
and [language composition](29-programming-model.md) extend this scorecard for their
new semantics and placements. Include index build/rebuild, historical-read and
recovery interference rather than measuring only a steady-state hot lookup.
The [combined qualification](30-qualification-and-benchmarks.md) owner repeats
database and runtime comparisons with the complete supported system and full
benchmark drivers. It does not defer earlier measurement or regression gates.
Publish supported limits and reproduced findings in the existing performance,
benchmark and Internals owners as implementation lands.

## Implementation plan for issue #194

**Review status: accepted for phases A–E; implementation in progress.**
Source inspection uses `e377f2945`, which includes
[PR #193](https://github.com/spoke-sh/transit/pull/193). This plan proposes how to implement
[issue #194](https://github.com/spoke-sh/transit/issues/194) through the existing
milestone owners. The early result-path work precedes milestone 5; it adds no
current allocation guarantee or claim that the remaining performance milestone
prerequisites are complete. Phases F–J remain planned with their owning milestones.

Applications need to ingest declared data, query an exact source basis and
consume complete results under explicit resource policies. The target is zero
steady-state backing heap/OS allocations after finite warmup, with bounded
resident memory and unchanged accepted-work recovery. Stable Table, schema,
operation, result and snapshot identities remain with their existing owners;
a reusable buffer, pool slot or cache generation grants no data authority.

The first delivery checkpoint is the existing result path: the service builds
and retains batches, the transport transfers them, and the shared client and
console consume them. The second covers installed storage, query execution and
durable runtime work. The third extends the same allocation gates to the
string/search and compiled execution capabilities as their prerequisites land.
The issue stays open across those checkpoints. Completing its first checkpoint
does not complete the broader guidance or this milestone's unrelated optimizer
and workload obligations.

### Allocation contract and measurement boundary

Each tested profile declares its owner lifetime, maximum active concurrency,
input/schema/row/byte bounds, reserve capacities, finite warmup schedule and
measurement interval before execution. Keep these definitions in the owning
contracts/component guides when implemented, with machine-readable cases in
the performance harness.

| Quantity | Required meaning and acceptance |
| --- | --- |
| Backing allocation | A request reaching the heap/page allocator below reusable pools. After warmup: zero allocation attempts, zero remap attempts and zero capacity-growing resize attempts, including unsuccessful attempts followed by a fallback. |
| Scratch reservation | A bounded bump/free-list reservation within already owned storage. Record it separately; it may occur per row/batch without acquiring new heap memory. |
| OS memory acquisition | Attribute mapping/growth and worker-stack/TLS allocation to the relevant process and thread. Verify independently when making an OS-level claim; the kernel's ordinary network/file bookkeeping is not a claim about Transit user-space allocations. |
| Live versus reserved bytes | Count reserved backing capacity, metadata, allocator headers, alignment, padding, transport state and worker stacks. A reset can reduce live contents while reserved bytes remain charged. |
| Borrowed bytes | Record the backing owner and lifetime. Charge physical storage once; child quotas may constrain a borrow without counting it twice in process totals. |
| Setup and admission | Measure process initialization, connection/TLS authentication, pool reservation and initial plan binding separately. Repeated statements, fetches, shape changes, normal connection turnover and retries cannot restart warmup. |
| Growth beyond an admitted envelope | Reuse another already reserved size class, spill through an implemented bounded owner, or return the owning typed budget refusal. No silent fallback to the general allocator or reinterpretation as a successful partial result. |

The fixed allocation budget is zero; it is not a percentage reduction. Define
latency/throughput regression budgets from matched baseline samples before
implementation. Retain the existing 32-row/1 MiB canonical-cell result limit,
4 MiB native message bound and configurable client resident limit (currently
at most 16 MiB). These describe different quantities; no plan step enlarges
them to hide allocation churn. A valid large server batch can still exceed a
client's smaller admitted memory allowance and must fail visibly.

Warmup reserves/touches the declared workspace and exercises its reset path.
It must not scan the complete dataset or grow with retained row count. Subsequent
checks vary values, schema shapes and batch sizes within the declared limits,
including cache misses on previously unseen keys. Runtime-created sessions and
queries obtain reusable slots from a bounded host reserve. Unsupported capacity
or an unqualified external runtime path remains an explicit open item; it cannot
be omitted from a broader zero-allocation claim.

### Inspected starting points

These observations identify implementation work, not a complete allocation
profile. Phase A records actual counts through all allocator layers.

| Owner | Observed work and proposed change |
| --- | --- |
| [BatchBuilder](../../packages/zig/transit-sql-results/src/BatchBuilder.zig), [Window](../../packages/zig/transit-sql-results/src/Window.zig) | Batch reset frees all arena capacity; windows allocate an owner, row directory and copied cells. Introduce reusable bounded workspaces while preserving detached window lifetime and the unread next row. |
| [ResultColumns](../../packages/zig/transit-sql-protocol/src/ResultColumns.zig), [ResultFrame](../../packages/zig/transit-sql-protocol/src/ResultFrame.zig) | Columns allocate directories/pages and the frame encoder allocates aligned output. Add caller-owned encode/parse destinations and persistent validation scratch. Keep the current wire bytes and full validation. |
| [NativeResult](../../packages/zig/transit-sql-client/src/NativeResult.zig), [Executor](../../packages/zig/transit-sql-client/src/Executor.zig) | Each batch releases its arena/response; each statement creates outcome/result owners. Reuse stable client slots and separate statement metadata from batch/frame lifetime. |
| [SQL Client](../../packages/zig/transit-sql-client/src/Client.zig) | Each call builds JSON request bytes, an owned parse arena and an exact-sized aligned receive body; HTTP also builds a URL. Reuse buffers and precompute endpoint targets. Audit the independent HTTP allocator, TLS, timers and `std.Io.Select` tasks. Idle replacement and the request-per-connection limit make reconnect part of repeated consumption. |
| [Registry](../../packages/zig/transit-sql/src/Registry.zig), [Session](../../packages/zig/transit-sql/src/Session.zig), [SourceSession](../../packages/zig/transit-sql/src/SourceSession.zig), [native gateway](../../apps/transit-sql-gateway/src/Native.zig) | Cursor/source arenas free capacity and the gateway creates a request arena. Reserve session/cursor/request slots and retain the latest disclosed batch independently of the request socket. |
| [PhysicalCodecs](../../packages/zig/transit-fuze/src/PhysicalCodecs.zig), [TSegReader](../../packages/zig/transit-fuze/src/TSegReader.zig) | Reusable inner decode scratch already exists, but page/group owners, directories, encoded pages and some codec temporaries still allocate. Pass persistent page/group workspaces through the full source path. |
| [RowAllocator](../../packages/zig/transit-fuze/src/RowAllocator.zig), [ComputePool](../../packages/zig/transit-query/src/ComputePool.zig) | The row cache falls back to its parent for large/simultaneous allocations. The worker pool already reserves bounded workers/stacks. Preserve that foundation and remove fallback allocation within admitted profiles. |
| [MemoryBudget](../../packages/zig/transit-fuze/src/MemoryBudget.zig), [NvmeCache](../../packages/zig/transit-storage/src/NvmeCache.zig) | Existing accounting distinguishes configured exhaustion from parent OOM. Cache misses allocate buffers/keys/directories; hits hash and copy cached bytes. Extend accounting to reserved capacity and introduce bounded immutable cache leases. |

The [retained codec baseline](../../tests/evidence/sql-results-2026-10-27/README.md)
records 30,001 → 1,565 encoder and 10,002 → 314 decoder allocation calls for
10,000 rows when moving from one-row to 32-row batches. It excludes sockets,
service execution, source authorization and storage. Preserve that evidence and
its hashes; generate new reports for the new measurement boundary.

### Ownership and resource model

Introduce a small shared Zig memory library only for the real cross-package
primitives used by Fuze, storage and clients: bounded aligned slabs, workspace
leases, hierarchical accounting and deterministic budget failures. The proposed
package name is `transit-memory`; it depends on the standard library and has its
own manifest, modules and tests. It contains no clocks, I/O, SQL, authority or
application policy. Domain owners continue to select limits and expose failures.
Move shared accounting rather than maintaining divergent Fuze/storage copies;
do not create a storage-to-Fuze dependency to reuse an allocator.

Use the following lifetimes, with stable owner addresses and explicit leases:

| Owner | Retained contents | Reset/release boundary |
| --- | --- | --- |
| Host/account reserve | Bounded worker, session, connection and control slots | After all borrowers/tasks join; idle slots return to the bounded reserve |
| Statement slot | Outcome identity, logical schema, observation and plan metadata | Outcome release; an active outcome prevents slot reuse |
| Result batch lease | Frame bytes, column views, recursive descriptors and row scratch | Next advance or close after every documented borrow ends |
| Server cursor lease | Latest logical/encoded batch and disclosure evidence | Next acknowledged ordinal or cursor closure; repeated fetch retains the same evidence |
| Request scratch | Control JSON, framing/validation temporaries and bounded diagnostics | Request completion/cancellation join; separate from the cursor and control transport |
| Materialized window / Arrow export | Explicit copied rows or a lease on immutable buffers | Independent release by the consumer; retained exports constrain pool capacity |
| Cache lease | Immutable verified page/chunk plus key, interpretation and generation | Final reader release before eviction/reuse |

The host bound is the shared reserve plus admitted concurrency times each slot's
reserved capacity, with separate worker, transport and control reserves. It must
not contain a term proportional to total results, accepted backlog or durable
collection size. Nested budgets restrict the same backing storage without
double-charging process totals. Pool exhaustion never overwrites a borrowed
frame, revokes an Arrow reference, drops accepted work or expires retained data.

Use fixed or reusable size-class storage where a hard guarantee is required.
In the pinned Zig 0.17 standard library, `ArenaAllocator.reset(.retain_capacity)`
can consolidate/reallocate and return false after freeing capacity. Exercise
that during warmup and test the returned state; replacing `.free_all` text alone
does not establish zero allocations. Reserve sufficient alignment/descriptor
overhead within the existing byte budget and test retained-capacity fragmentation.

### Delivery sequence and reviewable changes

Every phase lands with its own measured scope and ordinary correctness checks.
The proposed change groups below can be split further when an owner needs a
separate contract review. They are execution order, not calendar promises.

| Phase | Depends on | Reviewable outcome |
| --- | --- | --- |
| A. Allocation contract and baseline | Merged result model; current installed owners | Complete inventory, measured profiles and failing negative controls |
| B. Bounded memory primitives | A | Shared accounted reserves/leases and deterministic allocation guard |
| C. Logical batches and binary codecs | B | Zero-allocation warmed builder/encoder/decoder under varied legal inputs |
| D. Shared client and consumers | C | Reusable statement/result/transport/window owners and client gates |
| E. SQL producer and gateways | C; D for composed proof | Reusable service/request/cursor storage and complete disclosure/retry proof |
| F. Source, storage and durable runtime | B; coordinate current storage work | Zero-allocation supported scans, ingestion, flush, turns and recovery workspaces |
| G. Cache leases and resource metering | B, F | Safe immutable reuse, bounded pressure/spill and CPU/I/O accounting |
| H. Strings, lookup and search | B, F, G; milestones 7–9 where required | Milestone 11 implementations satisfy the same allocation/semantic gates |
| I. Fusion and specialization | B, G, qualified H inputs; milestone 9 | Milestone 12 implementations satisfy the same gates, including code storage |
| J. Combined qualification | A–I and prerequisite capabilities | One-revision installed evidence for full issue closure |

**A — Instrument before changing allocation behavior.** Extend the existing
codec and query measurement harnesses with attempted/successful alloc, free,
resize and remap counts, reserved/live/peak bytes, phase boundaries and owner
identities. The current query tracker excludes `std.Io` internals and its libc
interposer targets the external comparator; neither proves all Transit process
allocations. Add a shared test-only allocator guard through explicit test modules,
including negative controls that allocate through each vtable entry and bypass
one wrapper. Audit direct page/OS allocation sites and thread attribution.
For the installed Linux profile, collect process/thread-attributed memory-mapping
and heap-growth events alongside allocator counters; validate the observation
with deliberate direct-page and worker-creation negative controls. Report missing
tracing permissions or unsupported platforms as gaps in the OS-level claim.
Keep fixture/oracle preparation and report serialization outside the measured
interval; keep actual request encoding, source work and rendering inside their
declared profiles. Preserve unfinished/failed samples rather than averaging them
into successes. A produces a coverage manifest of every hot-path owner, transport,
operation family and its open gaps.

**B — Establish reserves and accounting.** Implement aligned reusable buffers,
bounded size-class/free-list arenas and generation-checked leases with stable
owners. Capacity is chosen at admission, never from total result cardinality.
Account alignment, padding, fragmentation, directory entries and retained slack.
Define all-or-nothing parent/child reservations, concurrent accounting and the
order in which capacity returns. Preserve the current distinction between a
configured budget refusal and parent OOM; errors must not depend on a stale
earlier failed resize. Tests cover initialization failure at each allocation,
exhaustion, interleaved borrowers, reset failure, double release, stale leases and
teardown. A guard forbids backing allocation/growth after warmup while repeated
slot acquisition/release continues successfully.

**C — Remove result-builder and codec churn.** Give `BatchBuilder` reusable
row/recursive-value storage and a transactional append checkpoint so a row that
does not fit consumes no delivery progress or permanently stranded capacity.
Keep the next row with its source and retain independent owned copies where
scratch can change. Provide caller-owned frame writing and directory parsing,
with checked sizing and existing TSR1/TCP1 alignment/validation. Bound encoding,
schema/observation serialization and nested conflict-detail scratch together;
avoid a temporary allocation for every column. Use `PhysicalCodecs` workspace
entry points to carry reuse through validation, not just the outer wrapper.
Start with unchanged wire bytes and identity compression. Prove all supported
logical types/five states, 0/1/31/32/33 and long result sequences, byte boundaries,
malformed frames and allocation-failure cleanup against independent values.

**D — Reuse shared-client state across statements.** Replace per-call
`std.json.Parsed` ownership in the hot adapter with an explicit response lease
over a reusable request/receive/parse workspace. Proposed API names are reviewed
with the implementation; the essential contract is that reuse waits for all
documented borrowers. Keep the public result model independent of transport.
Use client-owned outcome/result slots so `deinit` releases a lease while the
workspace survives for the next statement. Preserve the existing single-borrower
and active-cursor rules. Retained command metadata and independent windows consume
explicit slot capacity; refuse exhaustion rather than silently invalidating them.
Keep schema/observation stable through outcome release and preserve independent
control access during cancellation and settlement.

Precompute validated HTTP targets; write bounded control JSON into reserved
storage; receive into aligned capacity with a separate actual-length slice.
Inspect and qualify HTTP/TLS connection pools, timer tasks and the pinned I/O
runtime. Exercise idle reconnects and more than 256 requests so connection
replacement cannot escape the measurement. An unresolved TLS/runtime allocation
remains a failed profile, not a permitted hidden fallback. Join reads before
resetting buffers on timeout/cancellation. Reuse console formatting and window
storage without accumulating a relation for column widths. Migrate all affected
Zig callers together; preserve explicit owned-copy operations for consumers
whose lifetime requires them, backed by their bounded reusable storage.

**E — Reuse producer and gateway workspaces.** Reserve request slots in the
gateway and cursor/batch slots in `Registry`/`Session`; make request scratch and
retained cursor output independent. Reuse source-page, builder, codec and frame
storage through native, PostgreSQL and MySQL adapters. A failed encoding or
send must retain the existing cursor's correct ordinal/outcome; a repeat cannot
advance the source or count rows twice. Preserve fresh rights checks for every
disclosure, including repeats, metadata, zero rows and terminal counts. Keep
accepted writes and their recovery lane independent of socket buffers. Releasing
or reassigning slots erases secrets and prevents cross-account payload exposure.
Qualify the complete current delivery path at the existing budgets, including
authentication/control progress while data slots are full. Component success
can land first; the composed SQL allocation gate waits for F wherever source
or authority work still allocates.

**F — Carry reuse through source and durable owners.** Split implementation
reviews by query/read ownership, direct Table ingestion/flush, native WAL/turns,
and KV/Document operations. Coordinate with
[#128](https://github.com/spoke-sh/transit/issues/128),
[#116](https://github.com/spoke-sh/transit/issues/116) and the active
[installed storage cutover](03-live-storage-and-sql-cutover.md) before changing
shared reader or buffer APIs. Inventory each full caller path, including
authorization/catalog reads and error construction.

Extend `TSegReader`/physical codecs with caller-owned encoded/decoded workspace
leases; keep detached results and retained Arrow exports pinned until release.
Replace the 4 KiB row allocator's heap fallback inside admitted profiles with
bounded reserved alternatives; do not just increase its constant. Reuse
per-partition WAL encoding/checksum, memtable, flush/segment, range/index and
publication scratch while maintaining independent control capacity. Pool slots
bound concurrent active work, not the count of stored rows/objects. Preserve
sync/acknowledgement timing, fencing, atomic publication, retained cuts and exact
recovery. Exercise cache churn, rotations, repeated flush/compaction, checkpoint
replay and more retained data than resident slots. Recovered processes get a
new explicit startup phase; recovery's paged working loops still need their own
zero-allocation gate.

**G — Make cache reuse and resource pressure composable.** First add immutable
verified cache leases with a size-class directory and bounded key/metadata slots.
Readers must hold a lifetime guarantee; pointer/version checks alone cannot
make concurrent access to reused bytes safe. Specify locking/reclamation and
prove the lease protocol before introducing the proposed swizzling/optimistic
reads and lock-free cooling path. Record any concurrency profile still pending.
Retain scan-resistant eviction and qualify mixed hot lookups and cold scans;
previously unseen keys must reuse slots without backing allocation.

Verify immutable input against the appropriate trusted object/page commitment
at admission/reload. The present cache hashes cached bytes on hits, so removing
that behavior requires an explicit integrity/fault-model review, not deletion
of a failing corruption test. Disk corruption still rejects/reloads; untrusted
buffers are fully validated; cache generation and interpretation bind every
lease. Memory-corruption assumptions and any separate scrub policy belong in
the storage account. Do not claim the existing buffer cache is a durable NVMe
store without implementing and qualifying that owner.

Compose parent/tenant/query memory reservations with per-morsel CPU work and
I/O byte/operation charging. Clocks/device counters stay in effectful hosts;
deterministic execution consumes explicit budget charges. CPU ticks are measured
evidence, not deterministic cross-hardware replay values. Define maximum charge
granularity/overshoot, fairness and cancellation. Add bounded NVMe spill only
for operators with an owned spill format/lifecycle, disk quota and crash cleanup;
other exhausted operators use a typed budget refusal. Never turn allocation
pressure into expiry, accepted-work loss or an unbounded cleanup queue.

**H — Apply the contract to strings and search.** Keep implementation in
[milestone 11](11-vectorized-strings-and-search.md), with separately reviewable
changes for string layout, lookup tables, encoded predicates, full-text indexes
and execution, and hybrid composition. Ship usable closed-set `comptime` lookup
work early when it depends only on B; keep index/search work behind its actual
schema, collation, index-maintenance and SQL prerequisites.

Define tagged short/long 16-byte layouts, offset/handle bounds, immutable payload
leases and relocation rules. Require a scalar collation oracle: raw byte length
is not lexical order, a prefix collision needs a full-key comparison, and
collation-equivalent strings can have different byte lengths. Only use
prefix/length shortcuts whose soundness is proved for that collation. Do not
enable ICU or other unsupported semantics by adding a fast representation.
Internal 16–64-byte padding must be allocated, initialized and charged. External
inputs require bounds-safe loads/copying; remaining on the same 4 KiB page alone
does not make an out-of-bounds access valid.

Bound perfect-hash construction and verify exact non-member rejection; use a
qualified bounded lookup strategy for key sets that cannot be constructed within
budget. Keep dictionaries, FSST validation, filter masks and late materialization
under the same workspace lease. For BM25, first define tokenizer/index
identity, maintenance and snapshot/deletion coverage, then 256-document posting
blocks, conservative score upper bounds, bounded top-k state and SIMD pruning.
Compare complete scores/order/ties with unpruned execution before accepting
Block-Max WAND. Hybrid composition waits for the qualified ANN/index owner and
one supported snapshot model. Every new operator starts with allocation gates;
future syntax and algorithms do not become current supported capabilities.

**I — Apply the contract to fusion and compilation.** Keep implementation in
[milestone 12](12-data-centric-compilation-and-specialization.md). Review fused
interpreter instructions and pipeline boundaries first, then per-group dense
specialization, directory-tagged/prefetched joins, projection-specialized codecs,
adaptive compilation and AOT separately. Retain the reference interpreter and
independent scalar fixtures; compare values, five-state attribution, checked
overflow, LIMIT short-circuiting, checkpoint bytes and current disclosure rights.
`null_count == 0` alone does not establish a dense value-only group. Fusion must
preserve ordered failure frontiers and resource-meter boundaries.

Reserve compile scratch and executable-code cache capacity before measurement.
Adaptive tier-up at a morsel boundary cannot allocate a new mapping after
warmup. Specify W^X transitions, eviction, code leases, cancellation and thread
quiescence. Measure binding, code generation and permission changes separately;
precompiled dispatch does not make all planning latency zero. Enabling a stencil
or AOT path requires exact definition/type/codec/collation compatibility; stale
artifacts reject before execution under the current-v1 policy. Only use a
same-semantics qualified execution path where the owning contract explicitly
allows that choice. No fallback may reinterpret incompatible accepted work.

**J — Close against combined evidence.** Run the coverage manifest at one
committed revision with the same capacities, durability and independent result
oracles. Include retained windows/Arrow references, mixed tenants, slow readers,
cache misses, spill, source changes, control traffic and exact retries. Reconcile
component allocator totals with process-level acquisition evidence and disclose
any instrumentation blind spots. Preserve new raw reports with source, compiler,
binary, fixture, harness and host identities. Link the completed implementation
and evidence for every issue checklist item. An unexecuted or unsupported required
profile keeps that item open, even when another profile is faster.

### Verification matrix and publication gates

| Layer | Required cases | Gate |
| --- | --- | --- |
| Allocator/lease units | Warm/reset/reuse, failing alloc/resize/remap, fragmentation, concurrent reservations, stale leases and teardown | Zero forbidden backing attempts; correct accounting and no live borrow reuse |
| Codec/result units | All types/states, empty/final batches, byte/row limits, alternating sizes, nested payloads, malformed input, window/Arrow retention | Independent value and completion agreement; zero backing attempts within the admitted envelope |
| Shared client/service | Repeated statements and prepared binds; Unix, loopback HTTP and TLS; more than 256 requests; idle reconnect; same-ordinal retry; cancellation and EOF | Measured profile covers transport/runtime allocations and preserves original identity and incomplete outcomes |
| Authorization/recovery | Revocation after buffering, repeated metadata/terminal requests, retained accepted writes, process replacement and failed cleanup | No unauthorized disclosure, new submission identity, lost accepted work or manufactured completion |
| Storage/runtime | New keys, cache eviction, WAL rotation, flush/compaction, cold reads, bounded recovery and quota pressure | Zero steady-state workspace growth; durable data exceeds resident capacity; recovery/control progress preserved |
| String/compiled execution | Adversarial prefixes, collations, unpadded boundaries, five states, arithmetic failures, top-k ties, tier-up and code eviction | Oracle equivalence plus allocation/budget gates on every enabled path |
| Installed mixed workload | Repeated and growing data at fixed concurrency, retained exports, slow consumers, metadata/control and background work | Bounded total reserved memory, zero attributed backing growth and predeclared performance budgets |

For deterministic allocation checks, include multiple result lengths from empty
through at least 16,384 rows, repeated statements after one warmup, and declared
single/concurrent-owner schedules. Vary allocation patterns rather than replaying
only the largest batch. Use a negative control that reintroduces one allocation
to prove each gate fails. Test a valid workload just outside each configured
capacity and verify typed refusal or qualified spill without data loss.

Use the existing task owners first: package `zig build test` inside the pinned
shell; `just test::sql-wire-contracts`, `just test::sql-wire-encoding`,
`just test::sql-sessions`, `just test::sql-wire-gateway` and `just test::server-sql-lifetimes`
for protocol/client changes; installed SQL checks for the composed path; and
the named storage/growth/fault tasks for the affected durable owners. Extend
the [task inventory](../../tests/runner/suite.json) only when a new executable
allocation gate exists. Run affected committed-HEAD `just ci clean --lane NAME`
checks before pushing implementation changes. Result/client/gateway work needs
core/interfaces/experience coverage; query/storage work adds growth; shared
contracts and bindings add their dependent lanes. Full issue closure combines
the applicable lanes and independent workload/fault evidence at one revision.

Keep instrumentation runs separate from uninstrumented timing comparisons.
Freeze setup, warmup, workload seeds and numeric regression budgets before
optimizing. Report first-row and verified-terminal latency, throughput, CPU/I/O,
transport/copy bytes, all allocation attempts and reserved memory. The earlier
larger-batch first-row regression remains part of the baseline; do not increase
batch sizes or drop authorization checks to pass a timing gate. No SQL transport
compression is enabled by this plan; future codec negotiation must carry the
same allocation, decompression and ownership bounds through its own contract.

The early workspace work should leave current wire/storage definitions unchanged.
Any incompatible public ABI, wire, schema, stored format or accepted-work meaning
requires the existing current-v1 hard cutover, shared definition replacement,
consumer/fixture regeneration and foreign-definition rejection. Do not add
parallel legacy result profiles or retain a superseded API as a compatibility
shim.

Update current behavior in the owning result/client/storage/performance guides
with each qualified change, mechanisms in Internals, and executed evidence in
qualification history. Keep this plan and the issue checklist synchronized.
Review defaults are: implement A–E first; retain existing byte/row limits; allow
internal reservations from bounded preallocated storage; enforce zero backing
allocation attempts; and keep the issue open until F–J and the full guidance
have their required evidence. Phases A–E are authorized for implementation.
