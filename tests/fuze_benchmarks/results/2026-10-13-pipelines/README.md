# Typed column pipeline measurements

This page retains measurement summaries at the stated revisions. References marked
“archived” name raw files removed from the current tree; those bytes are available
only in repository history before the cleanup. These observations do not qualify
current builds.

The selected runtime is **`5b3d1ba6`**, built with pinned Zig
`0.17.0-dev.2267+48abf1a34` in ReleaseSafe. The wider immutable input fixture and
scalar baseline were committed at `c3dca7f1`; [numerical budgets](budgets.json)
were committed at `9b3de419` before runtime tuning. The input fixture remains
unchanged. Artifact metadata (archived) records build commands, hashes
and the separate native control revision. Later test/documentation commits do
not silently become the measured source.

## Results and selection

All **960 typed pipeline**, **120 decoded/operator pipeline**, **324 real file**,
**180 file-worker** samples and **20 paired native-control processes** complete
with independently checked results. Semantic completion alone is not a speed
gate: the [24 wider/default checks](release-qualified-gates.json) and
[115 original int64/file checks](release-vector-gates.json) both pass their
unchanged budgets. The selected defaults are portable computation, 256 rows,
256 KiB and one worker. AVX2 and two/four host workers remain explicit choices.

| Owned-row workload | Large portable/scalar median | Tiny additional microseconds/query |
| --- | ---: | ---: |
| int64 | 0.098 | 146.8 |
| uint64 | 0.087 | 130.0 |
| float64 | 0.084 | 127.8 |
| boolean | 0.088 | 116.8 |
| eager | 0.087 | 136.2 |
| sum | 0.199 | 136.6 |
| utf8 | 0.097 | 116.9 |
| nested | 0.184 | 162.6 |

Large inputs contain 4096 rows repeated 20 times per process; tiny inputs contain
eight rows repeated 100 times. Each engine has one discarded warmup and nine
paired measurements. Tiny numeric comparisons deliberately select no rows;
Boolean/UTF8 and aggregate cases have their own independently expected results.
The tiny setup penalty is within the frozen 250-microsecond additive allowance;
these results do not establish that batching accelerates short queries.

The decoded int64 comparison/consumption ratio is **0.081 portable/scalar**.
Explicit AVX2 is **1.031 times the portable decoded loop** on this run, and its
large owned-row ratios relative to portable range from 0.958 to 1.063. Earlier
baseline-target measurements put AVX2 at 1.120 times portable. There is no
consistent measured reason to choose it automatically on this host.

Two/four workers also fail to establish a general gain: the large owned-row
ratios relative to direct portable execution range from 1.008–2.187 and
1.000–3.813 respectively. SUM deliberately stays ordered on its caller. The
real file worker comparison ranges from 0.952–1.038 relative to one worker.
These are workload comparisons, not a claim that parallelism cannot help a
larger compute-heavy application. A host owns its concurrency policy.

Default real-file pipeline ratios are 0.945–1.085, including unchanged complete
CSV/JSONL decoding and verification. The eight existing native controls are
0.979–1.035, all below their 1.15 ceiling. Neither result shows the synthetic
owned-row speedup carrying through storage/decoding/transport costs.

## Mechanism and measurement boundaries

The complete owned-row timer includes plan admission, row acquisition,
validation, packing, predicates, ordered aggregates, projection and consumption.
One stable 4 KiB cache reuses temporary row-arena allocations; a projection copies
into an independently owned arena, including the oversized-row path. State-only
columns avoid copying unused recursive payloads after validation. SUM still
checks every contribution in source order. The measured large pipeline gain
combines these mechanisms; it is not an isolated SIMD attribution.

Decoded arrays, scratch and host-pool startup use the enclosing allocator outside
the owned-row timer/tracker. Reports identify pool reservations separately. The
real-file worker timer includes pool setup. Allocator-tracked owned-row peaks
include the physical buffer, row cache and source/output allocations, but exclude
stack structs, fixture arrays and OS accounting. Physical batch accounting and
shared pool admission have separate executable tests; these counters are not
whole-query RSS. Existing growing-source and durable-spill proofs remain required.

All matrix binaries target `-Dcpu=baseline`; the separately linked AVX2 object
targets baseline plus AVX2. Native controls use matching native-target artifacts
on both sides. The frozen control revision is `73dca03a59a9eb79384957d69ee8fc94428c37c7`.
Its runtime is unchanged; the identical eight-case measurement driver supplies
both programs. Native control signatures include exact Arrow export lengths.

The shared Linux host has an AMD Ryzen Threadripper 3960X, 48 logical CPUs,
`schedutil`/`acpi-cpufreq`, and microcode `0x830107c`. Single-thread probes use CPU
0; worker probes use CPUs 0–3. Clean qualification runs on other assigned cores,
and some frontend/build activity overlaps the shared host. Affinity is not CPU,
thermal, frequency, memory-bandwidth or device-cache isolation. Medians are not
latency percentiles. [Host controls](host-controls.json) and [topology](host-cpu.json)
are retained. [Hardware counters were denied](perf-stat.txt) with
`perf_event_paranoid=4`; no cycle, instruction, branch-miss or bandwidth claim is
made, and host policy was not changed.

## Dispatch and recovery evidence

The [CPU probe](release-cpu-dispatch.json) runs the baseline artifact natively
with forced AVX2, under QEMU 10.2.4 Nehalem with automatic portable selection,
and under Nehalem with forced AVX2. Both admitted executions have the independent
1776-row/10912677-checksum result. The last rejects with
`UnsupportedVectorCpu`, no result stdout and no illegal instruction.
[Disassembly](avx2-codegen.txt) retains the isolated symbol's packed comparisons
and YMM instructions. CPUID and OS XSAVE/XCR0 checks guard entry to that object.
The baseline-target package also passes natively. Under Nehalem its full
[313-test executable](release-nehalem-tests.log.gz) reports 312 passed, one skipped
(the hardware-specific AVX2 execution case), and zero failed. Canonical
checkpoints, restored execution and relational oracles run in that suite; this
is an emulated CPU check, separate from real native recovery. The
[build log](release-portable-tests.log.gz) records the exact baseline target and
executable. These tests qualify this Linux x86_64 profile, not other architectures
or every physical CPU. The [proof ledger](../../../README.md#integrated-vector-execution)
records checkpoint, native recovery, worker and caller qualification separately.

## Retained trials

The first generalized [typed candidate](typed-candidate.json.gz) missed the
generic nested and SUM thresholds. [Payload specialization](fused-candidate.json.gz)
removed the nested regression but did not establish the required SUM gain.
[Earlier integrated measurements](qualified-pipelines.json.gz) still measured
SUM at 1.036 times scalar; that failed improvement threshold was not relaxed.
The bounded temporary-row cache closes it at 0.199 in the final paired run.
Other [intermediate pipeline](final-pipelines.json.gz) and
[dispatch](baseline-kernels.json.gz) measurements retain their own source/dirty
metadata and do not substitute for the final committed-source reports.

The first final native-control comparison (archived) mistakenly
paired the baseline-target candidate with the native-target frozen control.
All eight [control ceilings failed](release-pipeline-gates.json). This is a
build-profile mismatch, retained rather than relabeled as a pass. Rebuilding the
candidate with the original native target gives the qualified
matching-target comparison (archived). No threshold changed.

## Reproduction

Enter `nix develop`, check out the measured revision, and use the exact commands
in artifact metadata (archived). The measurement guide describes the
[frozen control build](../../README.md#six-scalar-native-regression-control).
Run the following sequentially on the selected cores:

```sh
python3 -B tests/fuze_benchmarks/pipelines.py VECTOR_BINARY --engines scalar batch simd parallel1 parallel2 parallel4 --output pipelines.json
python3 -B tests/fuze_benchmarks/vector.py VECTOR_BINARY --engines scalar batch simd --output kernels.json
python3 -B tests/fuze_benchmarks/vector_files.py FILE_BINARY --output files.json
python3 -B tests/fuze_benchmarks/file_workers.py FILE_BINARY --output workers.json
python3 -B tests/fuze_benchmarks/six.py CONTROL_NATIVE CANDIDATE_NATIVE --control-revision 73dca03a59a9eb79384957d69ee8fc94428c37c7 --output six.json
python3 -B tests/fuze_benchmarks/pipeline_gates.py --pipelines pipelines.json --controls six.json --budgets tests/fuze_benchmarks/results/2026-10-13-pipelines/budgets.json --output gates.json
python3 -B tests/fuze_benchmarks/vector_gates.py --vector kernels.json --files files.json --budgets tests/fuze_benchmarks/results/2026-10-12-vector/budgets.json --output file-gates.json
```

`simd` forces guarded AVX2 and rejects unsupported hosts. `batch` selects portable
kernels; `parallel1/2/4` use portable kernels through a host pool. Inspect the
recorded implementation and reservation rather than inferring them from an
engine label. Reproduce unsupported dispatch with `qemu-x86_64 -cpu Nehalem
VECTOR_BINARY automatic pipeline 4096 1 int64`; replacing `automatic` with
`avx2` must reject. The original [scalar baseline](scalar.json.gz) and all final
raw reports retain per-process results, repetitions, allocation data and hashes.
