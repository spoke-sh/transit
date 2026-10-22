# Vectorization intake measurements

This page retains measurement summaries at the stated revisions. References marked
“archived” name raw files removed from the current tree; those bytes are available
only in repository history before the cleanup. These observations do not qualify
current builds.

The frozen ReleaseSafe runtime is merged source
`73dca03a59a9eb79384957d69ee8fc94428c37c7`. The decoded-kernel/owned-row
measurement driver was committed at `34ca32c0` before runtime changes. Its
[raw baseline](scalar.json.gz) verifies exact counts/checksums independently in
Python and retains nine repetitions plus a discarded warmup. There are no tail
percentile claims. The eight-row fixture deliberately selects no rows.

The file control (archived) uses the existing real captured CSV
COUNT pipeline: 4096 rows, explicit schema, warm input and nine repetitions.
Its binary was built before runtime changes. Its dirty flag includes the user's
untracked file and measurement-driver work; this is intake evidence, not a
clean-checkout performance qualification. The driver does not read that file.

[Budgets](budgets.json) freeze numerical thresholds before candidate tuning.
Both decoded-operator and owned-row pipeline improvements are required before
considering default replacement; packing alone is not a kernel speedup. Existing
file and eight six-scalar regression budgets remain applicable independently.

Reproduce the scalar operator/pipeline run with:

```sh
nix develop
zig build vector-benchmark -Doptimize=ReleaseSafe
python3 -B tests/fuze_benchmarks/vector.py zig-out/bin/transit-fuze-vector-benchmark --output .cache/vector.json
```

The pipeline includes plan admission, owned source-row allocation, filtering,
projection and consumption. It excludes native authorization/storage, file
decoding and Arrow export. The existing file harness separately measures actual
capture, discovery, decode, execution and cached Arrow export. General Table
native evidence must be recorded separately; a synthetic scan is not native I/O.

## Dependency and compiler audit

The pinned zarrow-compute revision
`def4d0654b4d6cdc2f4a7e6ad4a5930301f3391a` uses chunk iterators and per-value
Boolean builders in `src/kernels/compare.zig`. Its `aggregate.zig` COUNT returns
signed int64 and distinguishes Arrow null from values. These kernels cannot
supply Transit's missing/type-error/conflict states, uint64 COUNT or original
failure witnesses without a semantic adapter. No upstream defect or dependency
change is established. Keep Fuze's semantic ownership and existing compute tests.

The pinned Zig `0.17.0-dev.2267+48abf1a34` library's
`std/zig/system/x86.zig` detects CPU features and gates AVX/AVX2 on XCR0 state.
That source inspection is not a qualified runtime dispatch implementation.
Portable and AVX2 objects, a supported-feature disable control and generated
instruction checks remain V3 work. This first slice makes no SIMD claim and
changes neither compiler nor dependency pins.

## Executed int64 experiment

Candidate runtime **`244c83f674d2a77f7ad3e098a549685286a8d9ea`** retains production
executor selection. The [operator/pipeline samples](candidate.json.gz),
[324 file samples](files.json.gz), [experimental gates](gates.json),
eight six-scalar controls (archived) and [control gates](six-gates.json)
retain raw results and failures. Candidate/scalar comparisons use the same
ReleaseSafe binary and CPU affinity; the separate six-scalar control binary was
frozen before runtime changes. Measurements run sequentially on CPU 12, on a
shared host with other qualification work assigned different physical cores.
This is not a dedicated-machine or device-cache isolation claim.

| Measurement | Candidate / scalar median | Meaning |
| --- | --- | --- |
| 4096-row decoded comparison and consumption | 0.119 | About 8.4 times faster; packing and source I/O excluded |
| 4096-row owned-row pipeline | 0.253 | About 4 times faster; includes plan binding, source-row allocation, packing, projection and consumption |
| Eight-row empty-selection pipeline | 6.06 | About 115 microseconds extra per query; passes the precommitted 250-microsecond additive allowance |
| CSV filter pipeline across nine configurations | 0.951–0.972 | Complete file decoding/verification retained |
| Sparse JSONL filter pipeline | 0.730–0.973 | Three paired samples per configuration; no tail or universal speedup claim |
| File COUNT pipelines | 0.951–1.024 | Approximately unchanged; decoding remains substantial |
| Existing six-scalar controls | 0.963–1.026 | All eight remain below the unchanged 1.15 ceiling |

All **115 experimental checks** pass. The owned-row pipeline's allocator-tracked
peak is 262004 bytes, including its backing allocation and source/output rows;
this counter excludes stack structs and decoded kernel fixtures. The physical
batch separately accounts for its struct and backing bytes. Neither counter is
whole-process RSS. Source decoders and caller-retained output have their separate
bounds, as explained in the [batch guide](../../../../packages/zig/transit-fuze/docs/batches.md).

The complete file sweep covers CSV and sparse JSONL filter, COUNT(*) and
COUNT(column), three compute targets and three byte budgets, with three
alternating pairs per case. Independent expected counts/checksums, complete
source verification and first-batch timing pass in every sample. The kernel and
owned-row driver retains nine measured pairs plus one warmup. No percentile is
estimated from these sample counts.

## Retained failed experiments

- [Repeated validation](experiment-repeated-validation.json.gz) produces correct
  answers but a slower owned-row pipeline. Revalidating each copied cell repeats
  work already established by the exact source decoder. The final adapter calls
  `appendValidated` only after that original complete-row validation; public
  `append` still validates its inputs. This exploratory run has a dirty source
  marker and is not clean qualification.
- [Read-ahead samples](experiment-read-ahead.json.gz) fail
  [18 first-batch gates](experiment-read-ahead-gates.json): returning one prompt
  row does not make the first eight-row file output batch prompt. Single-row
  acquisition now serves that existing initial output boundary before filling
  compute targets. It does not change validation or wire batch sizes.
- [Eager reservation samples](experiment-reservation-touch.json.gz) fail
  [six first-batch gates](experiment-reservation-touch-gates.json) at the 1-MiB
  budget. Initializing unused conflict-payload pages dominates startup. The
  final arena reserves its complete bounded allocation but initializes payload
  storage when used, with every active lane written before evaluation. No
  optimization mode or safety check is disabled.

These results qualify the selected experiment, not production replacement or
completion of the tracking issue. Wider types, compound programs, ordered SUM,
Unified/resumable/relational integration, SIMD, bounded parallel scheduling and
integrated default qualification remain outside this implementation.
