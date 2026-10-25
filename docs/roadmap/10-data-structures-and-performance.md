# 10. Data structures, query optimization and runtime performance

[Roadmap](README.md) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** Planned

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
[client foundation](06-client-foundation-and-language-apis.md),
[historical interpretation](07-standards-and-catalogs.md),
[indexing](08-indexing-and-access-paths.md) and
[managed computations](09-sql-and-dataflows.md).
Earlier owners must already meet their boundedness, correctness and performance
gates. This milestone owns deeper structure selection, statistics/costing,
cross-layer optimization and an integrated local performance checkpoint.

Qualify database and existing native runtime paths together: Table/KV/Document
operations, queries, committed change consumption, native message delivery,
Station turns and accepted-work recovery. Use already qualified installed
callers; broader [SDK coverage](13-service-and-sdk-coverage.md) and
[mixed composition](25-programming-model.md) repeat the measures as they land.
Do not make their future APIs prerequisites of this local milestone. Full
distributed and complete TPC qualification stay with their later owners.

Start from [performance](../handbook/reference/performance.md),
[benchmark coverage](../handbook/reference/benchmarks.md),
[query mechanisms](../handbook/internals/query-engine.md),
[storage mechanisms](../handbook/internals/storage-runtime.md),
[execution](../handbook/internals/execution-model.md) and the
[benchmark tooling](../../tests/benchmarks/README.md).
The current component benchmark inventory does not execute complete TPC suites.

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
2. **Evaluate and deliver physical structures against their real lifetimes.**
   Use the candidate matrix below, maintaining a simple independent oracle and
   matched baseline for each replacement. Preserve collation, five-state errors,
   stable row/version identity, current authorization and atomic publication.
   Separate short-lived working state from immutable retained/checkpoint state.
   Qualify allocation failure, resize/split/merge, reclamation and restart before
   reporting a faster replacement. Keep CPU cache-line layout, storage pages,
   execution vectors and wire/display batches independently budgeted.
3. **Deliver statistics and physical plan selection.** Maintain bounded,
   inspectable statistics with source/definition provenance: row/distinct counts,
   distributions, relevant correlations and collection cost. Define sampling,
   refresh and invalidation; stale estimates may affect speed but cannot justify
   excluding possible rows. Cost scans versus index probes, segment pruning,
   join order/strategy, aggregation, ordering and spill using selectivity,
   locality, projected columns, coverage and expected I/O. Include parameter
   sensitivity and skew; qualify prepared-plan lifetime with the transaction and
   schema owners. Rewrites preserve checked arithmetic, fallibility, multiplicity
   and any specified result ordering. `EXPLAIN` remains non-executing; observed
   execution counters come from a separately authorized, explicit execution.
4. **Optimize the durable runtime and shared client path.** Measure admission,
   WAL append/sync, mailbox selection, dispatch/wakeup, turn commit, checkpoint,
   recovery and result delivery separately. Evaluate batching/group commit,
   allocation/copy reduction, queue/scheduler layout, worker-local caches and
   contention removal while preserving accepted identity, ordering, fairness,
   fencing and input/state/output atomicity. Specify acknowledgement timing for
   group commit; delayed persistence cannot masquerade as durable acceptance.
   Bound active work and reserve control/recovery capacity under overload. Direct
   data access stays independent of actor mailbox limits when no actor logic is
   invoked. In-process rates are separate from durable disk and installed caller
   rates; effect replay never dispatches to improve a score.
5. **Qualify selected implementations and maintain regression gates.** Run mixed
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
| Immutable indexes: paged prefix trees, sparse directories and segment-level routing | Actual index depth, candidate segments, range requests and bytes fetched under cold/warm caches, projected columns, compaction and retained snapshots; no universal one/two-read claim |
| Membership filters: cardinality-sized conventional or split-block Bloom filters | False-positive rate, bits per distinct key, hash/collation consistency, filter loading/build cost and net I/O avoided across skew and saturation; no false negatives |
| Deletion and candidate sets: sparse arrays, dense bitmaps and Roaring-style containers | Sparse/dense/run-heavy distributions, intersection/union cost, version/deletion correctness, conversion and resident/storage overhead |
| Join/aggregation working state: Swiss-style or Robin-Hood hashing, partitioned arenas and spill | Key skew, collisions, bounded resize, larger-than-RAM execution, deterministic error behavior and checkpoint/recovery composition; an ephemeral hash table does not replace durable ordered roots by itself |
| Vector and encoded execution: compact strings, dictionary-aware kernels, late materialization and batching | Independent encoded/decoded oracles, CPU portability, allocation/copy counts and end-to-end gains over required storage codecs; no universal zero-copy assumption |
| Runtime dispatch and coordination: bounded queues, scheduler/wakeup structures and batching | Durable completion latency/throughput, contention, starvation controls, overload/backpressure, recovery capacity and caller cancellation/uncertainty under mixed load |

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
working-state comparisons; they do not supply Transit's durable publication,
snapshot or ordered-iteration contract. Keep upstream algorithms and license
attribution separate from evidence for the selected Zig implementation.

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

[Foreign models](11-multi-model-and-foreign-relations.md),
[branches](12-branches-merges-and-restore.md),
[providers through clustered execution](14-storage-providers-and-concurrency.md),
and [language composition](25-programming-model.md) extend this scorecard for their
new semantics and placements. Include index build/rebuild, historical-read and
recovery interference rather than measuring only a steady-state hot lookup.
The [combined qualification](26-qualification-and-benchmarks.md) owner repeats
database and runtime comparisons with the complete supported system and full
benchmark drivers. It does not defer earlier measurement or regression gates.
Publish supported limits and reproduced findings in the existing performance,
benchmark and Internals owners as implementation lands.
