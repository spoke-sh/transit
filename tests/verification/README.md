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

Every legacy total-cardinality ceiling also has a checked `growing_replacements`
entry. It names the paged/segmented replacement or explicitly unsupported family.
The checker rejects missing reviews and narrow generated v3 principal fields.
This includes process/principal/association catalogs, retained work and checkpoint
roots as well as application rows. External payload operations and growing
registry/supervision APIs are not implicitly supplied by the legacy bindings;
their unsupported status is part of the SDK handoff.

`python3 -B tests/verification/check.py` validates owners, links, classifications
and drift; `just check` includes it. Missing tasks and unreviewed limit changes
are negative controls. The growing profile's partial qualification is recorded
in the [test guide](../README.md#m10-verification-and-scale-foundations);
inventory coverage does not imply all M10 gates have passed.

## CI and clean-run cost evidence

The [CI budgets](ci-budgets.json) allow under fifteen minutes of warm feedback
and sixty aggregate runner minutes, following the accepted five-lane sample.
Under ten minutes remains an improvement target and five a stretch. `just ci::cost RUN_ID` retains hosted phase timing and restored
bytes separately from local task measurements. The completed warm-dependency run
[`36181871580`](https://github.com/rupurt/rey/actions/runs/36181871580) used 1,000s
for core, 874s for experience and 529s for bindings, plus selection/final gating.
The three lanes restored approximately 7.0 GiB total. Its task artifacts identify
growing-service qualification (260.38s), the counter launcher (344.52s), Station
launcher (172.07s), core checks (193.67s) and build smoke (97.29s) as major costs.
This baseline does **not** meet the feedback target. Splitting into five lanes
preserves each task once and shares dependency-cache keys with one writer; its
first hosted warm run
[`36194234944`](https://github.com/rupurt/rey/actions/runs/36194234944) passed in
12m37s, using 53m27s of aggregate job time and 10.69 GiB restored. Core/growth
took 622/626s, experience/launchers 696/712s and bindings 540s. Feedback improved
and the user accepted that result as close enough to defer further optimization.
Three ordinary warm samples now meet the 15-minute / 60-runner-minute budgets:

| Run | Revision | Feedback | Aggregate runner time | Restored |
| --- | --- | --- | --- | --- |
| [36194234944](https://github.com/rupurt/rey/actions/runs/36194234944) | `97f3b7e` | 12m37s | 53m27s | 10.69 GiB |
| [36197767974](https://github.com/rupurt/rey/actions/runs/36197767974) | `22aa6f0` | 14m35s | 58m08s | 10.69 GiB |
| [36199109839](https://github.com/rupurt/rey/actions/runs/36199109839) | `22aa6f0` | 13m31s | 51m53s | 10.69 GiB |

All three ran the same 33 required tasks on five 2-vCPU Linux x86_64 runners.
These samples establish the bounded calibration, not a percentile or future
latency guarantee. A fourth passing test run,
[36197683518](https://github.com/rupurt/rey/actions/runs/36197683518) at `72552a3`,
took 14m49s and 62m05s of aggregate runner time, exceeding the cost budget.
That revision unnecessarily removed unused SDKs even on warm cache hits; cleanup
is now limited to cache misses. The over-budget result remains evidence of that
regression and does not count toward the three qualifying warm samples.

The final implementation clean run at `082ea76` passed all 33 tasks in 1,018.18s
(sequential local task time), including the Process Compose restart regression,
all language bindings and five Chromium checks. Evidence is in
`.cache/ci/clean/082ea767f278-transit-ci-fo_r55s_/`. The restart test reproduces
the late shutdown error after a real child exits and verifies that errors for
a live child or unrelated manager failure do not start a duplicate process.

The subsequent clean run at `22aa6f0` passed all 33 tasks in 1,026.97s, including
the Station inspection-cut regression, expanded retained-association reads and
load-driver build smoke. Artifacts are in
`.cache/ci/clean/22aa6f0b1ca1-transit-ci-nlnqqjzn/`. Separate reference recovery/
isolation and counter launcher proofs passed; the Station reference rerun passed
after the inspection-cut fix, including Arrow exchange, same-PID worker loss,
upgrades and stop/start. Compose counter/Station and both physical ENOSPC proofs
also passed. The first Station reference attempt is retained as a failure, not
a passing retry. `test::pages-cold --keys 1024` passed all four phases separately.

The complete clean run at `264f38e` passed all 33 tasks, including the growing
service/result delivery, foreign bindings, finite models and five Chromium
checks, in 1,032.97s of sequential local task time. Evidence is in
`.cache/ci/clean/264f38e2ce99-transit-ci-1wspu7bv/`. It predates the subsequently
found legacy Station inspection-cut retry fix. The real Station proof now
invalidates a page cut with concurrent authority progress and completes the
original exchange while retaining its lost-reply and stale-owner checks.

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

The subsequent complete clean run at `52e64df` passed all 32 tasks, including
retained-version recovery/trim, growing Station scan recovery, the full foreign
binding matrix, TLA+ and all five browser checks. Completion metadata records
882.23 seconds (about 14m 42s) of sequential local execution. Artifacts are in
`.cache/ci/clean/52e64df5daae-transit-ci-nhobq0gy/`. This run includes the test-cache
change and predates incremental Fuze/query capture. It retains more scenarios
than `fd0d2d4`; neither sample measures cold Nix transfer or hosted CI percentiles.

The query capture proof at `fc9ab61` took 6.94s to seed/stage, 9.78s for the
one-page recovery and first seal, and 73.50s to finish capture/inspection with
one page. The same executable and scenarios with 64 pages in only the final
phase took 6.94s, 9.78s and 15.50s. Artifacts are
`station-query-capture-service.log` and `station-query-cache64-qualified.log`
under `.cache/verification/`. Ordinary qualification now selects 64 for that
final phase; the first recovery/seal still uses one page. Full one-page replay is
available with `just test::growing-query --finish-pages 1`. Node defaults, fault
coverage and assertions are unchanged. These samples exclude Nix transfer and
cannot establish hosted CI percentiles or a production cache recommendation.

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

The additive `resource` trace profile also generates captured-view opening and
closure, independent resource grants, atomic KV/input publication, clock rollback,
uncertainty and expiry. Its separate oracle tracks one value and one view; replay
compares the entire actual authority after every boundary. Saved schedules check
that prepared publication can win after its validation deadline at an unchanged
tail, while fresh retry must validate current time. Lost-reply retries disclose
only the original receipt under current resource rights, even after view release.
Generation preserves the original inline xorshift sequence and names the added
resource generator separately. Failure artifacts retain both the original and
minimized actions; successful evidence identifies the revision and binary hash.

The generator does not model finite process settlement, checkpoint pages or
concurrent native handles. Existing focused tests still own those obligations.
The in-memory fault store assumes conditional
append atomicity and is not a substitute for Ursula disk qualification.

## Model and guard qualification

At `ea62354`, all four compiling mutants were detected and their counterexamples
minimized. The larger generated run also passed 263 traces / 33,250 boundaries
in 475.97 seconds on the shared development host. This is a bounded exploration
cost, not a throughput benchmark. Artifacts are under
`.cache/verification/mutations/` and `.cache/verification/transitions.json`.
The five-action [view-expiry regression](corpus/view-expiry-regression.json)
is the minimized missing-deadline mutant counterexample and runs in the ordinary
corpus. It records a negative control, not a discovered production defect.

The [finite TLA+ model](models/README.md) checks publication, retry and closure
safety and replays four removed-guard counterexamples against the real engine.
`just test::model` is part of the bindings lane so ordinary core/frontend checks
do not acquire a Java dependency. Its tools use the existing nixpkgs lock.

`just test::mutations` requires committed HEAD, clones it independently and removes
one actual generation, revision, permission or captured-view deadline guard at a
time. The unmodified
baseline must pass; a compiling mutant must trigger a minimized property failure.
Build errors/timeouts do not count as detection. It retains evidence and never
edits production source in the working tree. Weekly CI runs this larger budget.

## Scale and offered load

[scale.json](scale.json) defines progressive experiment sizes and required
measurements for the growing profile. These are test datasets, not service SLOs
or claims that the legacy profile supports them.

`just test::scale` executes its smaller `qualification_matrix` twice by default,
retaining each sample under `.cache/verification/scale/` and a completion manifest.
It requires Linux and Docker for the owned cold tier. `just test::growing-load`
focuses the finite public-service offered-load case. The
[backend guide](../../packages/zig/transit-backend-ursula/docs/growing.md#proof-and-limits)
defines timing boundaries, generator queueing and storage measurements. A matrix
entry or an incomplete manifest is not passing evidence. The larger analytical
dimensions remain distinct from this executable sample matrix. The
[recorded fourteen-sample result](results/m10-scale-2026-09-25.json) preserves
measurement fields and original artifact hashes; the [test guide](../README.md#m10-verification-and-scale-foundations)
summarizes observed ranges and qualification limits.

## Codecs and allocation boundaries

`just test::codecs` runs valid/malformed/truncated signed JSON and Station frame
corpora, canonical-identity roundtrips and parser/output allocation enumeration.
The growing request/query corpus additionally exercises full-width principal
and retained-version identities under their distinct v3 signature domains.
`just test::codecs --fuzz=1000` gives each of the three targets a bounded native Zig
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

## Shared SDK conformance

M11's first native-boundary slice adds the `growing-profile-abi` scenario to
[sdk.json](sdk.json). The [operation fixtures](sdk-operations-v1.json) pin
canonical v3 bodies, full-width IDs, signature domains and exact signatures.
`just test::client-abi` checks them and the real one-page-cache node/provider
restart, lost/invalid responses, fresh-process retry and current revocation.
The public Python/TypeScript/Rust API sketches and growing Station foreign
handler runner remain unqualified; this proof only extends the raw ABI.

[sdk.json](sdk.json) is the version-1 behavioral scenario contract for M11. Each
scenario defines a sequence, required observations and executable proof owners;
the catalog checker rejects missing implementations or task ownership. These
are behavioral observations, not another copy of the wire schema. Presence in
the catalog is not a passing result.

[sdk_scenarios.py](../sdk_scenarios.py) compares all named observations exactly.
Future public SDK adapters can execute the same schedule through their own API
and supply those observations; they must retain real service/host failures and
cannot substitute expected constants for observed outcomes. Native allocation
enumeration remains in its Zig owner, linked directly from the same catalog.

`test::client-abi` runs two independent native handles concurrently with one
principal. Conflicting bodies at the same sequence yield one admission and one
`ConflictingRetry`; identical bodies recover the same receipt. Cross-handle exact
retries preserve both results. This does not make independent sequence allocation
safe. The proof separately observes admission, source processing, reply delivery
and reply consumption, and recovers a lost accepted reply in a fresh host.

`bindings::test` reuses durable continuation observations across its language
matrix. Its shared Station ABI checks malformed input becoming durably blocked
without handler dispatch or input consumption, local await cancellation, and
responsive disposal that joins native work. The generated SDKs remain M11 work;
these results qualify the current low-level Linux bindings and their shared
semantics, not public SDK packaging or foreign deployment isolation.
