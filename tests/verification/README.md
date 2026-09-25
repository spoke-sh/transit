# Verification foundation

[Strategy](../../docs/TESTING.md) · [M10](../../docs/roadmap/M10.md)

This is executable test infrastructure, not an alternate authority. The existing
disk, native scheduling, browser, launcher and provider proofs remain necessary.

## Inventory

[suite.json](suite.json) is the task inventory used by local and hosted CI.
[invariants.json](invariants.json) maps stable claims to design/implementation
owners, exercised schedules and qualification limits. A null model means no
formal model currently covers that claim. Tasks name executable checks, not an
assertion that every possible violation is detected.

[limits.json](limits.json) distinguishes total-cardinality ceilings from operation
budgets, encodings, working sets and quota ceilings in the legacy profile. The
checker rejects unreviewed changes to these constants and new `max_*` declarations
in the audited files. Other component-specific transport/parser bounds still
require review when those components change. It does not infer that a fixed
array is scalable because its memory use is bounded.

`python3 -B tests/verification/check.py` validates owners, links, classifications
and drift; `just check` includes it. Missing tasks and unreviewed limit changes
are negative controls. The growing profile's partial qualification is recorded
in the [test guide](../README.md#m10-verification-and-scale-foundations);
inventory coverage does not imply all M10 gates have passed.

## Local execution cost evidence

The complete clean run at `94ab60a` passed all required lanes, including language
bindings and five Chromium checks. Its sequential task total was 795.69 seconds;
the earlier `b9dd595` run took 765.71 seconds with less coverage. This comparison
does not establish an overall speedup. Timings and completion metadata remain in
`.cache/ci/clean/94ab60ae889d-transit-ci-z0etigj7/`. The later public v3 service and
activation-session changes have focused evidence, not that clean run's coverage.

A subsequent complete clean run at `ce751a3` passed all 32 tasks, including the
public growing client/maintenance proofs, foreign bindings, TLA+ checks and five
Chromium checks. Total elapsed task execution was 787.23 seconds (about 13m 7s).
Evidence is in `.cache/ci/clean/ce751a3cccb6-transit-ci-fg16ffzz/`. Core checks took
42.28 seconds; local counter and Station launcher qualification took 208.26 and
96.04 seconds. These are sequential local tasks on a shared host, not hosted
parallel lane timing or cold Nix transfer measurements. This run predates named
association lookup and the growing Station changes; it cannot qualify those
later revisions. No overall CI latency/cost gate is closed by this comparison.

The complete clean run at `fd0d2d4` passed all 32 tasks, including growing
Station behavior and scoped retry. Its sequential task total was 928.17 seconds
(about 15m 28s); the expanded growing service proof took 169.30 seconds.
Evidence is in `.cache/ci/clean/fd0d2d46458c-transit-ci-aq5q8fsa/`. This run
predates Table paging and retained read versions. The additional coverage costs
time; these measurements do not show an aggregate CI speedup or close its budget gate.

Profiling the standalone Debug core binary at `94ab60a` found 38.73 seconds of
execution, including 24.20 seconds in the retained-catalog exchange test. That
test crosses the legacy capacity boundaries and retains its full scenario.
Removing duplicate authentication/refresh on normal `submit` instead produced a
27.80-second local run, with that test at 16.26 seconds and two additional
publication-race regressions. No safety checks or iteration counts were removed.
These single runs share a development host with other work; they do not establish
a hosted latency distribution, cold Nix benefit or millisecond service guarantee.
Local artifacts `core-test-profile.json` and `core-profile-after.json` under
`.cache/verification/` record individual test timings; the latter records the
changed binary hash and dirty base `ce4c550`.

The growing Station service proof at `1bee187` subsequently took 91.43 seconds
for its 40-call exchange and 7.13 seconds for one-page-cache recovery in Debug.
Running the same service corpus in ReleaseSafe during `cf1ebe5` qualification
took 26.92 and 1.72 seconds respectively; the entire command took 107.04 seconds
including recompilation and the other growing service faults. Reproduce it with
`just test::growing-service-release`. Both profiles keep the same fault schedules,
assertions and single-CPU service restriction. These local runs include slightly
different scoped-retry coverage and are not a controlled production benchmark.
Ordinary CI keeps Debug. A subsequent two-CPU build experiment at `d567188`
(with the compile-only target uncommitted) used fresh local object caches and
warmed fetched packages/global toolchain cache. Debug compiled the three growing
service proof binaries in 13.22 seconds (18.15 child CPU seconds); ReleaseSafe
took 111.90 seconds (187.75 child CPU seconds). Both compiled successfully.
The optimized build cost exceeds the observed scenario saving on a cold object
cache; these shared-host samples do not justify changing the ordinary CI profile.
Reproduce the compile step with `just build::debug test-growing-service-build`
or `just build::release-safe test-growing-service-build`, using a fresh
`ZIG_LOCAL_CACHE_DIR` for each. Local `growing-build-profiles.json` records the
cache conditions and timings. Nix setup, cache transfer, warm-cache hit rates
and hosted lane distributions still need separate measurement.

The expanded Station proof at `0893a98` also resumes a retained scan across a
second caller/node/provider restart. On the same one-CPU Debug corpus, the
40-call exchange took 92.96 seconds with 16 resident pages and 49.15 seconds
with 64; recovery (still one page) took 27.38 and 27.43 seconds. Artifacts are
`station-versions-focused.log` and `station-versions-cache64.log` under
`.cache/verification/`. These shared-host single runs are local cost evidence,
not hosted percentiles. Ordinary qualification now uses the bounded 64-page
exchange cache, retaining all calls/faults and one-page recovery. Node defaults
remain 16. Reproduce either configuration with
`just test::growing-station --resident-pages 16` (or `64`). This changes no Nix
setup/cache transfer and does not by itself establish whole-CI latency savings.

## Generated transitions

```sh
just test::properties
just test::properties --seeds 128 --steps 128
just test::properties --trace .cache/verification/transitions/failure.json
```

[transition_driver.zig](../transition_driver.zig) executes `Engine(Store)` with
real signatures, caller proposals and replay. Its test-only store separates
failure before append from lost acknowledgement after append. Each step recovers
the durable history and compares its logical state with the live engine. It does
not run application handlers or make network calls.

[transitions.py](transitions.py) independently tracks one PID, caller permission,
ownership, mailbox progress, retained receipts and caller-supplied opaque results.
It compares every boundary against the driver, including preparations that never
publish. Generation uses a fixed xorshift64 algorithm; failure evidence saves the
actual action list as well as the seed. Bounded delta debugging removes irrelevant
actions and writes a replayable trace. Corpus cases cover competing same-principal
proposals, lost acknowledgements, historical retries, revocation and stale owners.

This first generator does not model resource views, finite lifetimes, external
settlement, checkpoint pages or concurrent native handles. Existing focused
tests still own those obligations; M10 must extend the harness before closing
its generated-schedule gate. The in-memory fault store assumes conditional
append atomicity and is not a substitute for Ursula disk qualification.

## Model and guard qualification

The [finite TLA+ model](models/README.md) checks publication, retry and closure
safety and replays four removed-guard counterexamples against the real engine.
`just test::model` is part of the bindings lane so ordinary core/frontend checks
do not acquire a Java dependency. Its tools use the existing nixpkgs lock.

`just test::mutations` requires committed HEAD, clones it independently and removes
one actual generation, revision or permission guard at a time. The unmodified
baseline must pass; a compiling mutant must trigger a minimized property failure.
Build errors/timeouts do not count as detection. It retains evidence and never
edits production source in the working tree. Weekly CI runs this larger budget.

[scale.json](scale.json) defines progressive experiment sizes and required
measurements for the growing profile. These are test datasets, not service SLOs
or claims that the legacy profile supports them.

## Codecs and allocation boundaries

`just test::codecs` runs valid/malformed/truncated signed JSON and Station frame
corpora, canonical-identity roundtrips and parser/output allocation enumeration.
`just test::codecs --fuzz=1000` gives each of the two targets a bounded native Zig
fuzz budget. The request parser has a fixed 128 KiB workspace and bounded input;
no generated input can initiate a request or authority mutation.

The pinned Zig native x86 backend emitted empty coverage metadata, and fuzzing
through Arrow's C compression dependencies produced unresolved coverage symbols.
The qualified target explicitly uses LLVM and the exported standalone Station
frame module. These findings do not justify claiming Arrow/C fuzz coverage; the
independent Arrow integration proof remains required.

The raw client ABI additionally injects failure at every response allocation after
an accepted receipt through the production status/encoding path. The fake
transport counts exactly one submission; allocation failure must remain
`uncertain`. Native allocator checks detect leaks, while real HTTP/host proofs
retain responsibility for network and scheduler assumptions.
