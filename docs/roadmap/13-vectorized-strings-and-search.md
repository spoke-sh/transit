# 13. First-class strings, perfect hashing and vectorized search execution

[Roadmap](README.md) · [Performance #76](https://github.com/spoke-sh/transit/issues/76) · [Standards & Multi-Model #31](https://github.com/spoke-sh/transit/issues/31) · **Status:** Planned

Make text representation, string comparison, static/immutable key lookup and
declarative lexical/structural and hybrid search first-class, cache-resident
operations in `Fuze` and `.tseg` storage. Eliminate pointer-chasing heap
dereferences on short and medium strings, push string predicates directly into
compressed `.dictionary` and `.fsst` pages, replace linear keyword/dictionary
scans with compile-time (`comptime`) and segment-sealed perfect hash tables, and
separate declarative text segmentation, pattern/proximity matching and scoring
contracts from swappable physical `.tseg` index profiles—qualifying
fully-vectorized 256-document Block-Max BM25 and hybrid search first without
boxing text or code workloads into a bag-of-words model.

## Prerequisites and scope

The proposed [issue #194 implementation plan](12-data-structures-and-performance.md#implementation-plan-for-issue-194)
defines the shared allocation contract and sequences this milestone's string,
lookup and search gates in phase H. This milestone retains ownership of those
capabilities and their prerequisites; the plan does not establish support.

Consume the qualified [local engine](02-storage-and-query-performance.md),
[installed cutover](03-live-storage-and-sql-cutover.md),
[results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[collations and historical catalogs](09-standards-and-catalogs.md),
[indexing](10-indexing-and-access-paths.md),
[analytical SQL](11-sql-and-dataflows.md) and
[data structures and resource metering](12-data-structures-and-performance.md).
Start from [queries](../handbook/reference/queries.md),
[tables](../handbook/reference/tables.md),
[storage mechanisms](../handbook/internals/storage-runtime.md),
[query mechanisms](../handbook/internals/query-engine.md) and the
[benchmark tooling](../../tests/performance/query/README.md).

Keep logical types and span projections ($\tau$), collations and deterministic
analyzers/segmenters ($\kappa$: `utf8_binary`, `ascii_ci`, `ebcdic_cp037`,
`icu:<locale>`, versioned token/span boundaries) and physical codecs and index
profiles ($\epsilon$: `.dictionary`, `.fsst`, `.rle`, `EBCDIC`, posting blocks,
trigram/substring bitmaps, suffix/automaton structures) orthogonal. Declarative
match, substring/pattern, proximity (`NEAR` / `WITHIN`) and ranking contracts
must remain independent of any single physical index or bag-of-words heuristic
so `Fuze` can swap physical access paths behind an exact scalar reference oracle.
Every string representation, sort prefix, hash probe and search index evaluation
must preserve five-state cell semantics (`missing`, `null`, `type_error`,
`conflict`, `value`), snapshot pins, `.tdel` deletion visibility and
current-authority disclosure checks.

## Delivery sequence

1. **Deliver 16-byte collation-prefixed inline strings ("Umbra / German Strings") in `Fuze` vectors and working state.**
   Adapt the 16-byte string representation introduced by [Umbra](https://umbra-db.com/)
   and [CedarDB](https://cedardb.com/) (Neumann & Freitag, CIDR 2020) for
   variable-length `UTF8` and `BINARY` column lanes in `Batch` vectors,
   join/group hash tables and sort buffers
   (`[len: u32][collation_sort_prefix: 4B][inline_or_offset: 8B]`):
   - Strings up to 12 bytes store their complete payload inline inside the 16-byte
     slot with zero out-of-line arena dereferences.
   - Strings longer than 12 bytes extend Umbra's raw-byte prefix by storing the
     first 4 bytes of the column's **collation-normalized sort key**
     (`utf8_binary` raw bytes, `ascii_ci` lowercased bytes, `ebcdic_cp037`
     translated sort bytes, or `icu:<locale>` primary-weight prefix) in the
     4-byte prefix field alongside a 32-bit arena offset and 32-bit buffer/page
     handle (or swizzled slab pointer).
   - Equality (`=`, `!=`), range (`<`, `<=`, `>`, `>=`), `ORDER BY` radix/merge
     sorts and hash-join probes compare `(len, collation_sort_prefix)` in a single
     64-bit register or `@Vector` SIMD instruction first across all supported
     collations, touching out-of-line payload bytes only when two strings > 12
     bytes share an identical 4-byte collation prefix.
2. **Execute string predicates directly in the compressed domain over `.dictionary` and `.fsst` pages.**
   Push string equality (`col = 'lit'`), `IN (...)` sets, range comparisons and
   prefix/substring (`STARTS_WITH`, `LIKE 'prefix%'`, `CONTAINS`) filters down
   into `.tseg` column readers before materializing `Batch` string views:
   - On **`.dictionary` pages**, resolve string literals against the sorted or
     perfect-hashed page dictionary once per row group, converting string equality
     into integer code equality and `IN (...)` into a compact bitset test over
     bitpacked dictionary codes.
   - On **`.fsst` (Fast Static Symbol Table) pages**, evaluate prefix and fixed-
     pattern comparisons against the 255-entry 1–8 byte symbol table or decode
     only candidate lanes selected by prior predicate bitmasks (late
     materialization) inside a stack/batch-scoped scratch buffer.
3. **Deliver pure-Zig `comptime` and segment-sealed perfect hash tables with branchless 16-byte SIMD comparisons.**
   Implement a shared zero-dependency perfect-hash package in Zig using greedy
   association-table construction (`slot = (len + asso[key[i]] + asso[key[j]]) & mask`
   with power-of-two table sizes) paired with branchless 16-byte `@Vector(16, u8)`
   SIMD shuffle-mask string comparisons:
   - **Compile-time (`comptime`) lookup tables:** Replace linear `std.mem.eql`
     chains and runtime hash maps in SQL/application lexers, DDL option parsers,
     PostgreSQL/MySQL/HTTP wire-protocol header/setting routers and diagnostic
     registries with collision-free `comptime` perfect hash maps.
   - **Plan-bound and segment-sealed perfect hash directories:** Build compact
     frozen perfect hash directories at SQL `Plan.bind()` time for constant
     `WHERE col IN ('a', 'b', ...)` literal lists, at `TableSchema` initialization
     for column-name resolution, and at `.tseg` flush time for immutable
     `.dictionary` pages and row-group equality directories.
   - **Safe wide SIMD loads:** Guarantee 16–64 bytes of trailing zero-padding on
     `.tseg` page buffers, `Batch` string arenas and `comptime` key literals so
     16-byte `@Vector(16, u8)` loads execute unconditionally on internal buffers;
     guard external unpadded caller slices against 4 KiB page boundaries
     (`(addr & 0xfff) <= 4080`) with a scalar fallback.
4. **Separate declarative text search and proximity contracts from swappable `.tseg` index profiles, and qualify vectorized 256-doc Block-Max BM25 first.**
   Define declarative text index and match specifications (`CREATE FULLTEXT INDEX`
   and swappable `USING <profile>` bindings) with versioned analyzer/segmenter
   pipelines (Unicode word/span boundaries, ASCII/case folding, configurable stop
   words, and n-gram, substring or code/structural segmenters) stored as
   immutable `.tseg`-aligned index segments and verified against a finite scalar
   reference oracle:
   - **Swappable index and scoring boundary:** Keep the logical match, phrase/span
     proximity (`NEAR` / `WITHIN`) and ranking contracts decoupled from the
     physical index layout so `Fuze` is never locked into bag-of-words tokenization.
     An index profile is selected only when its bound segmenter/collation digest,
     predicate coverage and exactness/recall contract match the query; otherwise
     `Fuze` falls back to another qualified index profile or the bounded scalar
     reference scan.
   - **Initial qualified lexical profile — 256-document bitpacked posting blocks with Block-Max impact weights:**
     Partition inverted posting lists into fixed 256-document blocks aligned with
     `.tseg` row groups. Encode doc ID deltas, term frequencies (`tf`) and
     optional positional/span streams with SIMD bitpacking (`StreamVByte` /
     `BitWeaver`) and store per-block upper-bound impact metadata (`max_tf`,
     `min_doc_len`, quantized max block score).
   - **Vectorized `MAXSCORE` and Block-Max WAND execution in `Fuze`:** Evaluate
     multi-term disjunctive (`OR`) and conjunctive (`AND`) top-$k$ queries as
     native vectorized `Fuze` operators that maintain a dynamic top-$k$ threshold
     heap and skip entire 256-document blocks whose block-max score upper bound
     cannot enter the top-$k$.
   - **SIMD bitmask intersection and late materialization:** Intersect candidate
     posting or substring/trigram blocks directly in SIMD registers with `.tdel`
     deletion bitmaps, MVCC snapshot visibility masks and relational predicate
     selection vectors (`WHERE tenant_id = ? AND MATCH(body, ?)`), deferring
     document/row payload decoding until final top-$k$ row IDs are selected.
5. **Compose pluggable multi-signal and hybrid search under one snapshot, and hand off multi-model, reactive-context and corpus-synthesis extensions.**
   Combine vectorized lexical/structural search operators (starting with
   Block-Max BM25) and segmented HNSW / IVF-PQ approximate nearest-neighbor
   (ANN) vector indexes (`VECTOR(d)`) under a single pinned Table snapshot cut.
   Support reciprocal rank fusion (`RRF`) and calibrated linear score combination
   in `Fuze` without multiple round-trips or external search engines, preserving
   per-morsel CPU/memory/IOPS metering from
   [Milestone 12](12-data-structures-and-performance.md).
   Hand off the multi-format Document Type Library (`JSON`, `XML`, `HTTP`, `FTP`,
   `EDI`) and unified gateway/connector exchange lifecycle to
   [Milestone 15](15-document-profiles-and-gateway-exchange-lifecycle.md),
   multi-model Document/Graph structural search and foreign-format
   projections to [Milestone 16](16-multi-model-and-foreign-relations.md),
   governed reactive context assembly to
   [Milestone 29](29-reactive-context-and-agent-activation.md), and speculative
   research into declarative span/proximity maps (`NEAR`), context-conditioned
   sequence continuation and branch-verified agency to
   [Milestone 34](34-declarative-language-context-and-synthesis.md).

## Candidate structures and selection evidence

| Work and candidate | Evidence required before selection |
| --- | --- |
| 16-byte collation-prefixed strings ("German Strings") | Short ($\le 12\text{B}$), medium and long UTF-8/EBCDIC/binary distributions, shared-prefix adversarial inputs, collation sort-key fidelity across `utf8_binary`, `ascii_ci`, `ebcdic_cp037` and `icu:<locale>`, five-state tag preservation and arena memory footprint |
| Compressed-domain `.dictionary` and `.fsst` string kernels | Predicate selectivity sweep ($0.01\%$ to $90\%$), dictionary cardinality, FSST symbol compression ratio, late-materialization decode savings and equivalence against decoded scalar oracle |
| `comptime` and segment-sealed perfect hashing (`ConstexprCore/perfect_hash` style) | Construction bound at `comptime` and `.tseg` flush time, fallback behavior when key sets exceed greedy association budgets, cycles/ns per lookup on 6–1,000 keys, 4 KiB page-boundary safety and zero false positives on non-member probes |
| Swappable `.tseg` search profiles: vectorized 256-doc Block-Max BM25 (`turbopuffer` style), positional/proximity streams, n-gram/trigram bitmaps and hybrid `RRF`/linear fusion | 256-doc posting block compression ratio, block-skip rate on top-$k$ ($k \in \{10, 100, 1000\}$), filtered lexical/proximity + relational predicate selectivity, `.tdel` tombstone filtering, cold/warm NVMe cache behavior and exact top-$k$ score/order agreement with the unpruned scalar reference oracle |

[Umbra's string layout](https://db.in.tum.de/~freitag/papers/p29-neumann-cidr20.pdf),
[FSST](https://www.vldb.org/pvldb/vol13/p2649-boncz.pdf),
[ConstexprCore/perfect_hash](https://github.com/ConstexprCore/perfect_hash) and
[turbopuffer's fully-vectorized search engine](https://turbopuffer.com/blog/fully-vectorized-search-engine)
are named architectural inputs. Keep upstream algorithms and license attribution
separate from evidence for Transit's Zig implementations.

## Acceptance criteria

- 16-byte collation-prefixed strings, compressed-domain `.dictionary`/`.fsst`
  predicates, `comptime`/immutable perfect hashing and vectorized search
  operators (starting with the 256-doc Block-Max BM25 profile) pass differential
  equivalence and fuzz checks against the independent scalar `Fuze` oracle
  across all supported collations, analyzer/segmenter bindings, five-state error
  lanes, snapshots and `.tdel` deletions.
- Hot-path string comparisons, dictionary probes and search block evaluations run
  with zero steady-state heap allocations after warmup and enforce per-morsel
  CPU, memory and IOPS budgets from [Milestone 12](12-data-structures-and-performance.md).
- Benchmarks on ClickBench string-heavy queries (`LIKE`, `REGEXP`, `GROUP BY`
  strings, `IN (...)`) and standard information-retrieval workloads (lexical
  top-$k$, substring/proximity filtering and hybrid search) meet predeclared
  latency, throughput and allocation budgets in the
  [qualification scorecard](32-qualification-and-benchmarks.md).
