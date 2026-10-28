# Result reserve comparison

This selected [automatic report](codecs.json) preserves the baseline/candidate
samples behind the fixed result-codec regression budget beyond ordinary CI
retention. The performance owner retains this comparison because the pre-reserve
baseline is a historical executable, not a current supported result profile.
It is evidence, never an input to correctness checks or runtime packaging.

Control source is `a87d7ac1c`; candidate source is
`00dce3a06225bddc7529be046a3d27adb1221446`. Both use the pinned Zig
`0.17.0-dev.2267+48abf1a34` compiler in ReleaseSafe. The control was built from a
Git archive of its source using the owning result-encoding task. The candidate
uses the current probe from the gateway build. Binary hashes, driver and budget
hashes, all five alternating pairs, each process's five repetitions, workload
sizes and allocation counters are embedded in the report. The original bytes
are copied without transformation from `result-codecs-py64dckc/evidence.json`.

Reproduction follows the [codec measurement guide](../../performance/results/README.md)
with those revisions and the unchanged budget file. The recorded AMD Threadripper
3960X host has 48 logical CPUs; both arms were pinned to CPU 47. Other user work
remained active, with recorded one-minute loads of 15.68 initially and 19.05 at
completion. No other workload launched for this change ran alongside the comparison.
This is a matched local comparison, not isolated-host or service qualification.

All eight timing ratios meet the frozen 1.05 maximum, and the native candidate
attempts no backing allocation, growing resize or remap. Each native owner
reserves 8 MiB; the decoder separately borrows its input frame. See the
[qualification account](../../../docs/history/qualification/performance.md#result-reserves-and-codec-costs--2026-10-28)
for interpretation and limits. Ordinary integration, client trace and failure
logs remain in ignored runner output and CI artifacts.
