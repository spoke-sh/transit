# File discovery and execution measurements

These Linux x86_64 probes ask which costs belong to acquisition, schema discovery, decoding,
query execution and export, and whether retained input size changes resident
memory. They exercise the real `FileCapture`, `FileSource`, `FileQuery` and
`LogicalArrow` implementations. DuckDB is an independently pinned comparator.

```sh
nix develop .#benchmarks
just doctor
just test::file-benchmark --output .cache/fuze-baseline.json
just test::file-benchmark --project-id --output .cache/fuze-projection.json
just test::file-benchmark --query filter --modes explicit sampled full --output .cache/fuze-filter.json
just test::file-benchmark --query compound --modes explicit sampled full --output .cache/fuze-compound.json
just test::file-benchmark --query count --output .cache/fuze-count.json
just test::file-benchmark --query count-values --modes explicit partial sampled full --output .cache/fuze-count-values.json
just test::file-benchmark --query sum --modes explicit sampled full --output .cache/fuze-sum.json
python3 -B tests/fuze_benchmarks/large.py zig-out/bin/transit-file-benchmark --output .cache/fuze-large.json
```

The default matrix uses 4096 deterministic rows, three raw repetitions, explicit,
partial, sampled, full and raw modes, and nine shapes: narrow/wide CSV, nested,
sparse and decimal JSONL, leading-zero identifiers, reordered multi-file headers,
gzip and a real stdin pipe. Every process receives one CPU, a 4 GiB virtual
address-space ceiling, and a timeout. DuckDB uses one thread, a 64 MB engine
memory limit, insertion-order preservation, a 256 KiB CSV buffer and no extension
downloads. Its Python/OpenBLAS runtime needs more than 1 GiB of virtual mappings;
that reservation is distinct from resident memory. `image_peak_rss_kib` records
the executable's `/proc/self/status` VmHWM counter after its measured work.
The separate `wait4` `peak_rss_kib` includes the launcher's inherited pre-exec
memory and measures the whole process lifetime. These kernel RSS counters have
their documented accounting granularity. Fixture data and private captures live on
disk in `/var/tmp`, and are removed after the run.

Each shape is generated once and checked by SHA-256. Before every cold-input
sample, `fsync` and `POSIX_FADV_DONTNEED` evict only that fixture's pages; `mincore`
must observe zero resident pages. Warm-input samples read the fixture completely
before starting. This is **input page-cache conditioning**, not a claim about
cold device/controller caches, binaries or the entire machine. Captures are new,
private disk files and their recently written pages are warm. Alternating engine
order reduces one ordering bias; recorded host load does not imply isolation.

The JSON report records source revision/dirty state, binary/driver/lock hashes,
DuckDB version/build/module hash, PyArrow, compiler, filesystem, CPU affinity,
resource limits, exact reader options, fixture hashes, resolved schemas, every
raw repetition, CPU, RSS, allocation/byte counters and per-phase throughput.
Incorrect counts/checksums, mismatched captures, missing/duplicated phases or
missing completion fail the run. A failure replaces the report's successful
summary with an explicit failed status; existing raw samples remain evidence of
only their own completed work. A killed `running` report is incomplete.

## What the phases measure

| Phase | Included work and limits |
| --- | --- |
| Capture | Authorized CLI disk capture/hash/gzip in Transit; Python copying/hash/gzip in the comparator. Host implementations differ. |
| Discovery | Frozen source evidence and schema resolution in Fuze; table-function binding/inference in DuckDB. Input capture precedes both. |
| Compile | SQL lowering over the resolved Fuze schema; binding a DuckDB query relation. |
| Scan/convert | Complete Fuze row decoding, byte verification and a checked id sum. DuckDB's streaming API also constructs Arrow batches. |
| Query pipeline | A new scan, conversions and projection/filter/aggregate execution. DuckDB also constructs Arrow batches. First batch is measured from this phase's start; it excludes capture/discovery. |
| Cached-batch export | IPC serialization of at most eight already decoded rows, repeated with bounded scratch. This is not full-source output throughput. |

Fuze's first-batch timestamp means the first requested number of logical rows
(or the smaller completed result); those rows remain provisional until the
full scan verifies. It excludes IPC construction and stdout publication.
Ordinary cgroup records describe the inherited host group; only the dedicated
large-input proof uses them as a resource limit.

Do not subtract phase timings to infer an operator's isolated cost. The query
pipeline repeats a scan; it is not an additional component of the preceding
scan's elapsed time. Later passes read the same already captured content. Fuze
source-read counters include every callback read, including metadata/discovery
and repeated passes. Its allocation counters measure backing-allocator requests,
excluding arena/fixed-buffer suballocations, libc and `std.Io` internals. Arrow
uses its unchanged 4 MiB workspace and 64 KiB segment. For DuckDB, a fixed-size Linux/glibc interposer counts successful process
allocation requests and requested bytes, including Python/foreign glue and
reallocations; it neither retains pointers nor tracks live allocations. A known
allocation verifies the active hook before timing. The probe adds atomic-counter
overhead to those calls. It also exposes the statically linked jemalloc arena statistics: epoch-refreshed
allocation counts include tcache fills and byte counts include size-class
rounding. These are arena traffic, not every application malloc call. Reading
those counters occurs outside phase timers and does not flush caches. Its
read-byte counter covers process read syscalls, including reader metadata; it
is not a logical row-byte count. PyArrow pool counters are separate. The allocator scopes differ, so their counts are not interchangeable measures
of engine work. RSS counters come from the kernel; jemalloc live bytes
are endpoint snapshots. Linux preserves resource-usage metrics across exec;
the [getrusage documentation](https://man7.org/linux/man-pages/man2/getrusage.2.html)
and [proc counter definitions](https://www.kernel.org/doc/html/latest/filesystems/proc.html)
explain why launcher and executable-image peaks are recorded separately.
See the [allocator statistics](https://jemalloc.net/jemalloc.3.html) for the
counter semantics.

## Shared values and deliberate differences

Ordinary numeric CSV and explicitly typed fixtures compare shared values. Fuze
keeps missing distinct from null, exact decimal domains and ambiguous identifiers
as text; inferred DuckDB values/types can differ. Those cases are labeled in
every raw sample. Fuze checks all fields/rows despite projection or LIMIT. A
DuckDB optimizer may prune unused conversions. The first full-scan phase checks
every fixture before the query phase; no speedup claim assumes identical work.

Fuze samples a bounded prefix across sources with independent byte/record limits.
DuckDB sampling locations and per-file behavior differ. For JSON partial schemas,
the comparator first resolves the inferred schema then rebinds merged explicit
columns, keeping that extra work inside discovery. Raw CSV means text columns;
raw JSONL means whole JSON records. These are explicit selected profiles, not
claims that the engines have identical inference or result contracts. See the
upstream [CSV discovery](https://duckdb.org/docs/current/data/csv/auto_detection),
[JSON loading](https://duckdb.org/docs/current/data/json/loading_json), and
[streaming Python API](https://duckdb.org/docs/current/clients/python/reference/).

The `count-values` profile counts the first non-id column in each typed fixture:
text in wide/identifier CSV, a list in nested JSONL, decimal values, and nullable
optional integers in sparse JSONL. Top-level nested values contribute one each.
The sparse 4096-row fixture has 2184 contributing values; other shapes contribute
4096. Independent fixture-cell checks and both engines verify the scalar result
after complete-source scanning. This profile excludes raw mode and records new
capability costs; COUNT(*) over sparse input returns a different result and
cannot serve as an equivalent-result speed comparison.

Fully explicit DuckDB CSV columns assign names by position. The comparator reads
each fixture's header, orders that file's explicit column map, and projects back
to declared name order before `UNION ALL`. This Python header work is included in
discovery and its exact header order is recorded. Reordered files use disjoint
id/value domains, even in small smoke cases. Both scan and query outputs verify
independently calculated row counts and exact id/aggregate sums. The separate
file/Arrow correctness fixtures verify every field and state; benchmark checksums
alone do not establish complete value equivalence.

`six.zig` is a separate regression control using only the original public
six-scalar API. The same driver runs against the original base and candidate,
including every scalar predicate, exact uint64, negative zero, Unicode/binary,
SUM and Arrow row export. It does not exercise file acquisition or inference.
Reviewed numeric budgets and executed comparison reports are separate artifacts;
this harness alone establishes neither parity nor a performance improvement.

Build the candidate with `zig build six-benchmark -Doptimize=ReleaseSafe`. In a
detached checkout of the desired control revision, replace only
`tests/sql_bench.zig` with this exact `six.zig` and build `sql-benchmark` with the
same compiler/optimization. Record the checkout revision and both binary hashes;
the control's production code remains at its original revision. Then run
`python3 -B tests/fuze_benchmarks/six.py CONTROL CANDIDATE --control-revision REV
--output REPORT`. The runner alternates one discarded warmup plus nine recorded
processes per binary on the same CPU, verifies all eight result signatures, and
retains raw timings alongside median ratios.


`large.py` runs explicit, sampled, full and raw capture/scan/query passes in
fresh user systemd cgroups with swap disabled. Its default 600 MB input exceeds
twice the 256 MiB RAM/cache budget. Each pass verifies evicted original input
pages and records the exact enforced `memory.max`, kernel `memory.peak`, OOM
events and CPU usage from inside the cgroup. The capture and its file cache are
charged to that same group. Kernel charge batching has a documented 2% peak
margin; a process success or address-space limit alone is insufficient evidence.
The proof requires Linux cgroup v2 and a running user systemd manager.


## Paired file-plan changes

Build and preserve a ReleaseSafe `transit-file-benchmark` before changing the
runtime. Compare it with the new binary using the same pinned compiler:

```sh
python3 -B tests/fuze_benchmarks/compare.py \
  --baseline /path/to/frozen-transit-file-benchmark --baseline-revision BASE_COMMIT \
  --candidate zig-out/bin/transit-file-benchmark --output .cache/file-comparison.json
```

This runs three alternating pairs per shape and discovery mode over all nine
shapes, using 4096 rows, one CPU, warm input pages and unchanged per-process
budgets. Every sample checks capture identities, source rows and result checksums.
The report retains binary/source/driver/lock hashes, raw timing/allocation/RSS
records and median compile/pipeline ratios. `status: passed` means every sample
completed with correct results; assess ratios separately against the applicable
performance budget. Host activity is not isolated and no native latency is measured.

`--query compound` compares the baseline filter with a six-instruction program
that selects the same rows, to measure the extra predicate work. That is not a
same-workload regression comparison. Add `--baseline-query compound` to run the
same compound program against both binaries; both must support it. The report
records both query choices and labels whether operator work is identical.
Different queries are allowed only for the filter/compound pair, whose expected
rows and checksums agree. `--cpu N` selects an available CPU for both probes;
the default selects the first available CPU. Pinning does not reserve a CPU.
The ordinary matrix also accepts
`--query compound`, including its independent DuckDB result comparator.

## Experimental physical batches

`just test::vector-benchmark .cache/vector.json` compares the current scalar
operators and owned-row executor with the experimental int64 batch path. The
Python consumer computes exact expected counts/checksums without Fuze. It retains
one warmup and nine alternating repetitions for tiny and 4096-row inputs. Kernel
measurements exclude packing; the owned-row pipeline includes admission, source
allocations, packing, filtering, projection and output consumption. Decoded input
arrays and kernel scratch are allocated outside the measured allocator. Pipeline
allocation counters include compute buffers, source rows and projected rows.
These scopes are deliberately separate; a kernel timing is not file/native I/O.

`just test::vector-files .cache/vector-files.json` sweeps 64/256/1024 compute rows
and 64 KiB/256 KiB/1 MiB compute buffers over the real frozen CSV and sparse JSONL
filter, COUNT(*) and COUNT(column) pipelines. Three alternating pairs per case
retain complete source validation, exact counts/checksums, first-result timing and
allocation data. Run these measurements sequentially without other work on their
selected CPU. Timing medians are not tail percentiles. Both selectors are private
to measurement binaries; the console keeps its existing executor.

Assess the precommitted experimental thresholds after committing the source:

```sh
python3 -B tests/fuze_benchmarks/vector_gates.py \
  --vector .cache/vector.json --files .cache/vector-files.json \
  --budgets tests/fuze_benchmarks/results/2026-10-12-vector/budgets.json \
  --output .cache/vector-gates.json
```

A semantically successful report can fail its performance gates. These gates
cover the first int64 experiment and do not replace the existing file budgets,
eight native controls or integrated qualification. General Table measurements
and buffered current-denial checks run in `just test::typed-tables`; that proof
records three paired native samples per selected query, including process and
transport costs. It makes no percentile or native speedup claim. See the
[physical batch guide](../../packages/zig/transit-fuze/docs/batches.md) for ownership,
validation boundaries and the separate decoder/output memory owners.
