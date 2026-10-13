# Vectorization intake measurements

The frozen ReleaseSafe runtime is merged source
`73dca03a59a9eb79384957d69ee8fc94428c37c7`. The decoded-kernel/owned-row
measurement driver was committed at `34ca32c0` before runtime changes. Its
[raw baseline](scalar.json.gz) verifies exact counts/checksums independently in
Python and retains nine repetitions plus a discarded warmup. There are no tail
percentile claims. The eight-row fixture deliberately selects no rows.

The [file control](file-count.json.gz) uses the existing real captured CSV
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
python3 -B tests/fuze_benchmarks/vector.py zig-out/bin/transit-vector-benchmark --output .cache/vector.json
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
