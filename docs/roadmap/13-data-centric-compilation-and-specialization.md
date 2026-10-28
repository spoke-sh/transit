# 13. Data-centric pipeline fusion, AOT query compilation and adaptive specialization

[Roadmap](README.md) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · **Status:** Planned

Combine vectorized morsel execution with [HyPer](https://hyper-db.de/)-style
data-centric pipeline fusion, per-row-group adaptive kernel specialization,
sub-100µs ad-hoc query specialization and true Ahead-of-Time (AOT) Zig code
generation for declared application queries, views and functions. Eliminate
interpreter instruction-dispatch loops, intermediate scratch-array round-trips
and dynamic schema-type switches while avoiding heavyweight runtime LLVM JIT
compilation latency.

## Prerequisites and scope

The proposed [issue #194 implementation plan](10-data-structures-and-performance.md#implementation-plan-for-issue-194)
defines the shared allocation contract and sequences this milestone's fusion,
specialization and compilation gates in phase I. This milestone retains
ownership of those capabilities and their prerequisites; the plan does not
establish support.

Consume the qualified [local engine](02-storage-and-query-performance.md),
[installed cutover](03-live-storage-and-sql-cutover.md),
[results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[collations and historical catalogs](08-standards-and-catalogs.md),
[indexing](09-indexing-and-access-paths.md),
[analytical SQL and dataflows](10-sql-and-dataflows.md),
[data structures and resource metering](11-data-structures-and-performance.md)
and [first-class strings and perfect hashing](12-vectorized-strings-and-search.md).
Start from [query mechanisms](../handbook/internals/query-engine.md),
[storage mechanisms](../handbook/internals/storage-runtime.md),
[declarative applications](../handbook/reference/applications.md),
[`transit-fuze`](../../packages/zig/transit-fuze/README.md) and
[`transit-station-app`](../../packages/zig/transit-station-app/README.md).

The existing interpreted [`VectorKernel`](../../packages/zig/transit-fuze/src/VectorKernel.zig)
and [`RelationalKernel`](../../packages/zig/transit-fuze/src/RelationalKernel.zig)
remain the reference semantic oracle. Every fused, specialized or AOT-compiled
pipeline must produce identical ordered outputs, five-state error attribution
([ordered failure frontiers](../handbook/internals/query-engine.md#column-execution-and-ordered-failure-frontiers)),
checkpoint bytes, post-buffer revocation behavior and per-morsel resource
accounting as the reference interpreter.

## Delivery sequence

1. **Deliver HyPer-inspired data-centric push pipeline fusion inside vectorized `Batch` morsels.**
   Follow the hybrid synthesis of compiled and vectorized execution (Kersten et
   al., VLDB 2018) and [CedarDB's](https://cedardb.com/) join probe architecture:
   - Retain **vectorized morsel stages (`Batch`)** where SIMD and out-of-order
     memory parallelism dominate: `.tseg` column scans, compressed-domain
     filtering, SIMD selection bitmasks and **staged vectorized software
     prefetching (`@prefetch`)** combined with **CedarDB-style ~10-instruction
     directory-tagged hash-join probes** (filtering non-matching probe keys via
     embedded 16-bit Bloom/tag signatures in the directory slot before chasing
     tuple pointers across L3/RAM).
   - Replace instruction-major temporary-array materialization inside each morsel
     with **data-centric push pipelines** up to the next pipeline breaker (hash
     build, group-by aggregation, sort or result batch output): keep active
     tuple/lane attributes in CPU scalar and `@Vector` SIMD registers across
     multi-atom predicates, checked arithmetic, projections and aggregate
     accumulators instead of writing and re-reading `temporary` and `scratch`
     slices for every AST node.
2. **Specialize kernel dispatch dynamically per `.tseg` row group based on physical block invariants.**
   Emit paired `comptime` kernel variants in `Fuze`—a **Dense Non-Null Fast Path**
   and the **Five-State Tagged General Path**:
   - Inspect each 256/1024-row `.tseg` row-group header and active `.tdel`
     deletion vector once before entering the inner loop.
   - When a row group has `null_count == 0`, no `missing`/`type_error`/`conflict`
     cells and an empty `.tdel` bitmask, dispatch the branchless Dense Non-Null
     Fast Path that executes straight-line `@Vector` SIMD arithmetic, comparisons
     and aggregations over raw 64-bit words or 16-byte string headers with zero
     per-row state-tag switches (`switch (state)`).
   - When a row group contains non-value states, `.tdel` tombstones or checked
     arithmetic overflow candidates, dispatch or fall back to the Five-State
     Tagged General Path while preserving exact source-ordered first-failure
     attribution.
3. **Deliver sub-100µs "Flying Start" ad-hoc SQL specialization and Adaptive Morsel Tier-Up.**
   Eliminate expression-interpreter overhead on ad-hoc interactive SQL queries
   without embedding a 100 MB LLVM JIT runtime or paying 10–100 ms compilation
   stalls, adapting [Umbra](https://umbra-db.com/) and
   [CedarDB's](https://cedardb.com/) multi-tier *Flying Start* strategy (Kersten,
   Leis & Neumann, PVLDB 2021):
   - **Zero-latency Tier 0/1 start (`Plan.bind()` Fused Superinstructions):**
     Start every ad-hoc query immediately with $0\,\mu\text{s}$ code-generation
     latency by pattern-matching multi-node predicate and projection subtrees
     into pre-compiled `comptime` fused superinstructions, including
     `RangeFilter(T)` (`(x -% low) <= (high -% low)`),
     `FusedFilterAggregate(T, op, agg)` (single-pass predicate + `SUM`/`COUNT`/`MIN`/`MAX`
     without selection-vector materialization), `FusedHashKeyCombine` (composite
     key hashing across multiple columns in one register pass) and
     `DictEqBitsetFilter`.
   - **Adaptive Mid-Query Morsel Tier-Up & Copy-and-Patch stencils (evaluated candidate):**
     Use the per-morsel CPU cycle and row counters from
     [Milestone 11](11-data-structures-and-performance.md) to monitor query
     runtime cost; only when a query exceeds a morsel/tick threshold ($> K$
     morsels), tier up cleanly at the next `Batch` morsel boundary to a fully
     fused pipeline stitched from pre-compiled Zig object-code stencils
     (Copy-and-Patch compilation in $< 50\,\mu\text{s}$ into a bounded W^X slab),
     so short OLTP queries finish instantly while long analytical scans run at
     full compiled speed.
4. **Deliver Ahead-of-Time (AOT) Zig compilation for declared application queries, views and functions (`transit-app`).**
   Extend [`transit-station-app`](../../packages/zig/transit-station-app/README.md)
   (`transit-app`) so applications that declare schemas, named relational queries,
   maintained views, streams and user-defined functions in `.sql` can compile
   them ahead of time into specialized Zig modules:
   - Monomorphize scan, filter, join, group-by and incremental delta (`+row`/`-row`)
     operators to the exact `TableSchema`, column types ($\tau$), physical codecs
     ($\epsilon$) and collations ($\kappa$) at build time, eliminating all runtime
     type/column switches.
   - Inline deterministic Zig UDFs ([Milestone 10](10-sql-and-dataflows.md))
     directly into the fused morsel register loop with zero per-row call or
     serialization overhead.
   - Bake `comptime` perfect hash tables ([Milestone 12](12-vectorized-strings-and-search.md))
     for constant `IN (...)` sets and static lookup tables directly into `.rodata`.
   - Verify the compiled module's schema/definition digest against the active
     catalog cut at pin acquisition; reject or fall back cleanly if the runtime
     schema has evolved incompatibly.
5. **Specialize storage page decoders and wire result encoders to bound projections.**
   Generate projection-specialized `.tseg`/WAL decoders and result encoders
   (native `transit-sql-results` binary columns, Arrow IPC and PostgreSQL binary
   frames) that decode only referenced columns directly into `Batch` vectors and
   serialize output batches directly from column vectors without intermediate
   row-struct allocation or per-cell dynamic dispatch.

## Candidate techniques and selection evidence

| Work and candidate | Evidence required before selection |
| --- | --- |
| Data-centric push fusion + vectorized morsels (HyPer + CedarDB + VectorWise synthesis) | Register pressure, L1d/L2 cache misses, ~10-instruction directory-tagged join probe filtering, LLC miss hiding via `@prefetch` on hash joins (TPC-H Q3, Q9 and JOB), arithmetic/aggregation throughput (TPC-H Q1, Q6, Q18) and exact ordered-failure-frontier preservation |
| Per-row-group dense non-null specialization | Branch misprediction reduction (`perf` branch-misses), throughput on clean (`null_count == 0`) versus dirty/nullable `.tseg` blocks, and zero regression when falling back on overflow or five-state errors |
| Ad-hoc SQL specialization: Fused Superinstructions + Adaptive Morsel Tier-Up (Flying Start / Copy-and-Patch stencil JIT) | Tier-0/1 startup latency ($0\,\mu\text{s}$), stencil tier-up latency ($\le 50\text{–}100\,\mu\text{s}$), morsel threshold calibration, W^X security/sandbox compliance, cross-platform support (`x86_64-linux`, `aarch64-linux`, `aarch64-macos`) and binary size impact |
| AOT application query/view compilation (`transit-app`) | End-to-end latency and throughput versus ad-hoc SQL plans, UDF inlining speedup, build-time compilation budget, and catalog definition-digest verification on schema evolution |
| Projection-specialized storage decoders and wire serializers | End-to-end query throughput across `.tseg` scans into `transit-sql-client`, Flight SQL and PostgreSQL binary clients; allocation/copy counts |

[HyPer's data-centric query compilation](https://www.vldb.org/pvldb/vol4/p539-neumann.pdf)
(Neumann, VLDB 2011),
[Morsel-Driven Parallelism](https://db.in.tum.de/~leis/papers/morsels.pdf)
(Leis et al., SIGMOD 2014),
[Compiled versus Vectorized Queries](https://www.vldb.org/pvldb/vol11/p2209-kersten.pdf)
(Kersten et al., VLDB 2018),
[Umbra](https://umbra-db.com/) (Neumann & Freitag, CIDR 2020),
[Tidy Tuples and Flying Start](https://www.vldb.org/pvldb/vol14/p1175-kersten.pdf)
(Kersten, Leis & Neumann, PVLDB 2021),
[CedarDB](https://cedardb.com/) and
[Copy-and-Patch Compilation](https://dl.acm.org/doi/10.1145/3485513)
(Xu & Kjolstad, OOPSLA 2021) are named architectural inputs. Keep upstream
algorithms and license attribution separate from evidence for Transit's Zig
implementations.

## Benchmark baseline and acceptance criteria

- Set **HyPer, Umbra and CedarDB** (alongside DuckDB and ClickHouse) as
  comparative reference baselines under matched hardware, durability, thread
  count and memory budgets on:
  1. **The Kersten et al. (VLDB 2018) Compiled-vs-Vectorized Micro-Benchmark Suite**
     (TPC-H **Q1** fixed-point arithmetic/aggregation, **Q3** & **Q9** multi-way
     hash joins with software `@prefetch`, **Q6** selective multi-predicate scan,
     and **Q18** high-cardinality group-by).
  2. **The Join Order Benchmark (JOB, Leis et al., VLDB 2015)** (113 complex
     multi-join queries over skewed real-world IMDb relations, testing `DPhyp`
     join ordering, ~10-instruction directory-tagged hash joins and WCOJ).
  3. **The HTAP CH-benCHmark** (concurrent TPC-C transactional OLTP turns +
     TPC-H analytical OLAP scans over the same live `TablePartition`s), measuring
     both OLTP p99 tail-latency isolation under per-morsel resource metering and
     OLAP fresh-snapshot scan throughput.
- Every fused, per-block-specialized and AOT-compiled query plan passes
  differential fuzzing against the reference `Fuze` interpreter across all
  five-state cell tags (`missing`, `null`, `type_error`, `conflict`, `value`),
  checked arithmetic overflows, `LIMIT` short-circuits, `.tdel` tombstones and
  mid-stream permission revocations.
- Ad-hoc plan binding/specialization completes within a bounded memory slab with
  zero steady-state heap allocations during morsel execution and respects the
  per-morsel CPU cycle, memory and IOPS budgets established in
  [Milestone 11](11-data-structures-and-performance.md).
