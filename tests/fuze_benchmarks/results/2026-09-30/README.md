# Frozen baseline and regression budgets

These measurements establish a local regression baseline before optimizing the
file implementation. They do not establish DuckDB parity, a service latency
promise, or durable file-query recovery. The [harness](../../README.md) defines
phase boundaries, instrumentation scopes, semantic differences and reproduction.

## Environment and executed samples

Linux x86_64, AMD Ryzen Threadripper 3960X, 48 logical CPUs, one selected CPU per
child on a shared host. Zig `0.17.0-dev.2267+48abf1a34`, ReleaseSafe; DuckDB 1.5.2
build `8a5851971f`, PyArrow 23.0.0, one DuckDB thread and 64 MB engine memory.
The locked comparator is available only in the optional benchmark development
shell. Each report records exact CPU/platform/load, lock and executable hashes,
reader options, fixture hashes, schemas, resource limits and raw samples.

The production implementation is unchanged across these baseline revisions;
intervening commits update measurement checks and documentation. The final main
matrix and strengthened six-type driver use `420e3279`; other exact revisions
remain in their reports. Every accepted report started with a clean worktree.

| Artifact | Executed evidence |
| --- | --- |
| [Main matrix](baseline/baseline.json.gz) | 540 samples: nine shapes, five modes, cold/warm input pages, three repetitions, both engines; 4096 rows |
| [Projection](baseline/projection-baseline.json.gz) | 108 samples: narrow/wide/nested, explicit/sampled/full, both cache conditions and engines, three repetitions |
| [One-row batch](baseline/batch1-baseline.json.gz) | 36 samples: narrow/wide/nested, explicit, both cache conditions and engines, three repetitions |
| [Filter](baseline/filter-baseline.json.gz), [COUNT](baseline/count-baseline.json.gz), [SUM](baseline/sum-baseline.json.gz) | 36 samples each: narrow/wide/nested explicit inputs, both cache conditions and engines, three repetitions; exact query checksums |
| [Six-type control](baseline/six-baseline.json.gz) | Same eight-query driver against original `d5541301` production code and candidate; one discarded warmup and nine measured processes per binary; selected counts and exact SUM checked |
| [RAM/cache proof](baseline/large-baseline.json.gz) | 600058901 input bytes, 10000 long records; explicit/sampled/full/raw; 268435456-byte cgroup RAM/cache ceiling, no swap; actual peak 268435456 bytes and no OOM in every mode |

The [control provenance](control-provenance.json) identifies the detached base
checkout, sole driver substitution and frozen binary. Every raw JSON report is
stored as deterministic gzip; decompress it without discarding repetitions.

For orientation, explicit warm-input medians are below. Query pipelines repeat a
scan; DuckDB's streaming API also constructs Arrow. Fuze checks every field and
row. These timings are neither identical operators nor quantities to subtract.

| Shape | Fuze query pipeline | DuckDB query/Arrow pipeline | Fuze executable peak RSS | DuckDB executable peak RSS |
| --- | ---: | ---: | ---: | ---: |
| Narrow CSV | 38.966 ms | 7.463 ms | 9696 KiB | 131256 KiB |
| Wide CSV | 461.055 ms | 42.623 ms | 9712 KiB | 142904 KiB |
| Nested JSONL | 224.880 ms | 11.967 ms | 10728 KiB | 130924 KiB |

RSS uses the executable's VmHWM counter. Separate wait4 counters include inherited
launcher memory before exec. First logical-batch timing excludes capture,
discovery and Fuze IPC encoding; a first batch remains provisional until EOF.
Cached-batch export contains at most eight rows, not the full result. Three
samples describe observed variation; they do not estimate p95/p99 tails.

## Budgets fixed before optimization

[budgets.json](budgets.json) freezes concrete numeric limits for every case from
these observations. The baseline itself passes the
[gate report](baseline-gates.json). Its archived report hashes bind the source
observations. The checker refuses different fixtures, drivers, compiler, CPU,
cache/mode/query settings, missing repetitions, dirty or incomplete reports, and
incorrect results. It recomputes metrics from raw records, not the summary table.

- Median phase wall time and first-batch time: baseline median × 1.50 + 250 µs.
- Median phase CPU: baseline median × 1.30 + 250 µs.
- Allocation requests, requested bytes, source bytes and source-read calls: at
  most the observed baseline maximum for that phase/case.
- Tracked live bytes: observed maximum + 1024 bytes of bounded metadata allowance.
- Executable-image peak RSS: observed maximum × 1.25 + 2048 KiB.
- Specialized six-type median candidate/control ratio: at most 1.15 in each of
  eight queries. Baseline ratios range from 0.9960 to 1.0480.
- Large-input proof: the same 256 MiB RAM/cache limit, swap disabled, no OOM,
  all four modes complete, and input exceeds twice actual peak. The kernel peak
  permits the harness's predeclared 2% charge-batching margin.

The time margins account for a shared host and short-phase timer/scheduling noise;
CPU limits and exact allocation/I/O counts supply separate regression signals.
The RSS allowance covers executable/allocator accounting variation, while the
cgroup proof enforces the stronger RAM-plus-file-cache ceiling. These budgets
are deliberately local regression gates, not comparative speed targets. An
exceeded budget is a failure to investigate, not permission to raise the limit
or erase a run. A changed measurement method requires a separately identified
baseline before using it to justify an optimization.

```sh
python3 -B tests/fuze_benchmarks/budgets.py check \
  tests/fuze_benchmarks/results/2026-09-30/baseline \
  tests/fuze_benchmarks/results/2026-09-30/budgets.json \
  --output .cache/fuze-baseline-gates.json
```

## Retained diagnostics and limits

[The failed explicit-header run](diagnostics/positional-header-failure.json.gz)
retains 362 samples, ending in an incorrect DuckDB id checksum. Explicit DuckDB
column names were positional across reordered files; the corrected comparator
aligns each header by name inside discovery. Small smoke fixtures now use disjoint
id/value domains so this mistake cannot pass accidentally.

The `diagnostics/pre-image-rss-*` reports retain the earlier complete runs before
executable VmHWM instrumentation. Their wait4 measurements include launcher
memory and are excluded from the frozen budgets. The
[overlapping-smoke matrix](diagnostics/diagnostics-overlapping-smoke-matrix.json.gz)
records a later run whose start overlapped a small instrumentation check; the
isolated final matrix above replaces it for acceptance. The
[earlier six-type run](diagnostics/diagnostics-six-before-selected-check.json.gz)
predates the driver's explicit selected-row assertion. All of these remain
inspectable observations with their original revisions/statuses; none supplies
the accepted budget inputs.

The host is shared, cache conditioning covers only fixture input pages, and
acquisition hosts/allocator scopes differ. Large-input cgroups qualify Transit
memory behavior, not a large-input DuckDB performance comparison. Temporal,
extreme-integer, malformed/outlier and cancellation cases have independent
correctness fixtures; these timing shapes do not cover every such value. Native
KV/Table/Document persistence and recovery remain separate from ephemeral file
capture. See the [proof ledger](../../../README.md) for those scopes.

## Withdrawn metadata experiments

After committing these budgets at `5052c59e`, `19d3ba7d` removed one repeated
validation traversal. Its [36-sample isolated run](experiments/validation-pass.json.gz)
passed result checks and observed lower wide-query CPU. `f509cdfb` additionally
cached at most 128 header-to-column indices and guarded binding replacement.

Two complete 792-sample matrix runs, paired six-type runs and four-mode cgroup
proofs passed their result/completion checks. They failed the unchanged numeric
gates: [first run](experiments/first/archived-gates.json),
[complete repeat](experiments/repeat/archived-gates.json). Each directory retains
all raw reports, including passed cases. Original gate-report hashes refer to
uncompressed input JSON; archived gate reports hash the compressed artifacts.

The first run failed 12 phase-wall limits and one discovery-CPU limit; the repeat
failed seven capture/discovery timing limits in different cases. Allocation,
source-read counts/bytes, live memory, executable RSS, scan/query timing,
specialized-path and cgroup gates passed. For example, the first wide/filter
cold capture had 89.756 ms median wall time versus a 5.241 ms baseline, while
individual capture CPU remained 3.823–5.761 ms versus 3.960–5.510 ms. Shared-host
I/O pressure was observed. This supports an interference hypothesis; it does not
prove an isolated cause for every CPU or elapsed-time difference.

Both optional changes were withdrawn in `cffa7b56`; their timing failures were
not waived and the budgets were not raised. The
[implementation comparison](experiments/restored-implementation.json) verifies
that implementation, generated contracts, build and toolchain paths match the
accepted baseline at that checkpoint. The type/source/CLI/Arrow/SDK features
remain. Subsequent integration of `main` brings shared SQL aliases, diagnostics
and current native contract definitions; it preserves the file discovery/scan
metadata algorithm. These reports measure their recorded revisions, not that
integration. No optimization or speedup is claimed. Further optimization needs
complete matching evidence under these budgets
or an explicitly reviewed new measurement profile established beforehand.
