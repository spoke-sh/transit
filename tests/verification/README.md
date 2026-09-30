# Verification foundation

[Strategy](../../docs/reference/verification.md) · [M10](../../docs/roadmap/M10.md)

This is executable test infrastructure, not an alternate authority. The existing
disk, native scheduling, browser, launcher and provider proofs remain necessary.

## Component simulation

`just test::domain-simulation` runs two seeds over real Document, Exchange,
query/refresh and core runtime implementations. `--seed N --seeds N` selects a
bounded range (at most 64 seeds). Each package runs twice; structured event
records must agree and all five domains must appear. Each run has a 120-second
deadline. The ordinary suite owns two seeds; scheduled discovery owns sixteen.

Artifacts in `.cache/verification/domain-simulation/` retain actual choices and
test logs; the adjacent JSON report records source/dirty status, compiler, binary
hashes, generator, seed range, trace hashes, elapsed time and completion. Replay
uses the same binary/seed. This package profile does not support arbitrary trace
editing or minimization. Errors, timeouts and missing domains cannot pass.

`just test::domain-simulation-mutations` uses committed source clones to omit
Document conflict retention, checkpoint floor advancement, Exchange replay holds,
refresh generation fencing and runtime readiness. Only executed contract assertion
failures count as detection; compilation and infrastructure failures do not.
The private-turn stores model atomic publication and current-reader failure;
actual WAL durability and application installation remain separate integration
checks. No connector transport runs or dispatches during these replay tests.

## External fault testing

`just test::vortex` owns a disposable node, counter worker, courier and disk Ursula.
Four rounds cover request loss/delay and response loss/delay, dropped connections,
worker/node/provider SIGKILL, courier stop/continue and restart against current
history. `--seed 19 --rounds 12` changes workload intent; rounds are bounded to
4–32. Public calls, readiness, fault observation and eligible progress have finite
deadlines. It never edits provider files or private installation checkpoints.

The peer records synthetic signed requests, actual replies and monotonic event
times. Each requested fault must fire; courier reply loss must produce an exact
retry. A consumed source prefix has the independently expected cumulative value
and original outputs, and each destination admission preserves its output/turn
origin. Current denial/stale activation and three corrupted-observation controls
challenge the checker. Full JSONL histories, process/provider logs and report JSON
are retained per run in `.cache/verification/vortex/`, with source, toolchain,
binary hashes, topology, seed, configuration, duration and cleanup status. Private
seed files remain only in the disposable fixture and are never copied to artifacts.

`just test::vortex-profile PROFILE` selects an independent experiment:

| Profile | Owned checks | Environment / boundary |
| --- | --- | --- |
| `sdk` | Installed Python wheels and Node tarballs: frozen bytes, dropped reply, seedless host recovery, await cancellation, disposal and revoked retry | Native Linux public SDKs; package/build hashes and per-host histories |
| `application` | Lost provisioning/rotation/migration/activation replies, current revocation and runtime upgrade | Local application manager and provider adapter fixture; no Kubernetes claim |
| `query` | Durable capture cancellation/expiry plus interactive Table snapshot cancellation/current denial | Distinct durable and leased query lifetimes; Docker cold-store fixture for interactive reads |
| `reactive` | Real browser refresh replacement, pause, revocation and lifecycle recovery | Owning TLS/browser rig; installed Chromium required |

The profile runner retains commands, logs, source/compiler identity and per-stage
completion in `.cache/verification/external/`; every stage has a 900-second cap.
SDK histories record actual signed attempts, receipts and host-ownership checks.
The original owning tasks remain runnable independently. A seed does not fix OS
scheduling. External failures are retained; automatic schedule minimization is
limited to the in-process JSON trace profiles. Real reference placement, physical
ENOSPC, arbitrary corruption and host power loss retain separate proof owners.

The ordinary core lane owns the four-round external regression; weekly discovery
runs sixteen rounds. The manual [external workflow](../../.github/workflows/fault-verification.yml)
selects one additional profile and preserves incomplete artifacts. Stage deadlines
are failure limits, not measured feedback targets. Local and hosted timing evidence
must remain separate; the existing hosted budgets are not requalified by adding
these tasks or by one local passing sample.

## Inventory

[suite.json](suite.json) is the task inventory used by local and hosted CI.
[invariants.json](invariants.json) maps stable claims to design/implementation
owners, exercised schedules and qualification limits. A null model means no
formal model currently covers that claim. Tasks name executable checks, not an
assertion that every possible violation is detected.

[limits.json](limits.json) classifies the current operation, encoding, resident
working-set and deployment quota bounds. Its `removed_bounds` entries retain the
names of eliminated total-cardinality ceilings; `collections` names each current
paged or segmented owner. The checker rejects lost replacement owners, drift in
reviewed constants, unclassified `max_*` declarations in audited files and narrow
generated principal fields. Other component-specific bounds still require review
when those components change. A bounded resident array does not establish a bound
on retained collection size.

`python3 -B tests/verification/check.py` validates owners, links, classifications
and drift; `just check` includes it. Missing tasks and unreviewed limit changes
are negative controls. The [current cutover evidence](../README.md#native-v1-cutover-checkpoint--2026-09-30)
separates newly executed proofs from historical qualification. An inventory entry
or preserved historical result is not evidence that its replacement passed.

M21 registers the reactive API/client/refresh and placement proofs and adds the
actual M20 browser peer plus Board/counter consumer schedules to the complete
browser lane. The ordinary five lanes keep their existing task allocation.
These additions have local proof timings in `tests/README.md`; no new hosted
warm/cold feedback or runner-minute qualification is claimed for the expanded
complete suite. Preserve the measured M10 budgets until new hosted evidence is
available rather than deriving a new budget from one local browser run.

M22's manual [Flight workflow](../../.github/workflows/flight.yml) runs the pinned
native clients, fault/load schedules, recorded outbound replay and Compose
recovery, retaining logs and elapsed times. Reference placement remains an
explicit proof against owned reference infrastructure. The ordinary growth lane
includes inbound transport and metadata checks; the complete browser lane owns
M21's consumer schedules. Local pass evidence does not establish a new hosted
feedback or aggregate runner-minute budget for either addition.

M23/M24 register generated application, placement, terminal and local-supervisor
proofs as explicit focused/external tasks. The application migration, console and
local installation invariants identify the owning implementations and their
executed limits. These additions do not expand the ordinary five CI lanes;
physical ENOSPC and reference placements remain explicit environment-dependent
proofs. The proof ledger records each selected source and placement separately.

M23/M24's [final clean report](results/m23-m24-clean-2026-09-28.json) records all
59 ordinary tasks at `21089bb654f0`, using one fresh checkout per lane. The five
completed reports share a revision and cover the committed inventory exactly.
These local timings do not requalify the earlier hosted 33-task budget samples.
Individual lanes and interrupted attempts must never be reported as the full gate.

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

The complete cold run
[36200208768](https://github.com/rupurt/rey/actions/runs/36200208768) at `082ea76`
passed all 33 tasks in 31m09s, with 111m51s aggregate runner time and no GitHub
dependency-cache restore. It fits the separate 35-minute / 135-runner-minute
budget. This is one cache-miss baseline, not a cold-variance guarantee; upstream
Nix substitutes remain available and their transfer is outside the archive-byte
measurement. The [retained report](results/m10-ci-2026-09-25.json) includes all
four qualifying runs, task timings, revisions, artifact hashes and excluded runs.

Cold run `36196325993` failed during bindings setup with exhausted disk and in
the launcher restart race. Run `36197837630` passed four lanes but hit core's
old 30-minute deadline. Both remain inconclusive and do not qualify a budget.
The final run includes cache-miss-only SDK cleanup, the 45-minute cold job
deadline and the confirmed-exit launcher fix. No larger runner was provisioned.

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
available with `just test::query --finish-pages 1`. Node defaults, fault
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

## Authority and delivery simulation

```sh
just test::simulation
just test::simulation --seeds 64 --steps 128
just test::simulation --trace .cache/verification/simulation/minimized.json
just test::simulation-mutations
```

[delivery_simulation.zig](../delivery_simulation.zig) executes real signed authority
and outbox transitions with producer PIDs 4 and 5, worker principals 1 and 2,
destination PID 6 and courier principal 3. Root principal 0 owns provisioning and
policy changes. The fixed topology and eight delayed-decision slots bound this
test, not production cardinality. A synthetic turn copies one admitted integer
into one committed output. No application handler, resource, HTTP or effect runs.

[simulation.py](simulation.py) independently checks operation outcomes, sequences,
ownership, lifecycle, output phases, values and destination-input provenance after
every event. A separately recovered engine must match the live engine's selected
logical state without staging pages. The live engine/cache survive until explicit
restart. Delayed slots retain immutable prepared decisions and exact signed
requests; they are controlled pending work, not recovered worker memory.

The store injects `before_append` or `after_append` on one commit/retry event.
Failed validation or receipt deduplication cannot leak that fault into the next
operation. Conditional append is assumed atomic and immutable pages stay
available. Page faults, capacity, checkpoint/trim, time and real disk/network
behavior remain separate proofs. No physical durability claim follows.

The generator is `xorshift64-delivery-v1`. Defaults run eight 48-step schedules
alongside six saved cases for reply loss, independent routes, stale proposals,
competing principals, denied/retired outputs and failed preparation. Every trace
runs twice with identical observations. Generated traces append a healthy progress
phase: restore permissions, admit no fresh input, consume eligible producer input,
resolve pending routes and check drain before and after restart. Retirement stays
terminal. This checks the finite explicit schedule, not automatic worker fairness.

Test-format-1 traces contain at most 4,096 actions. Discovery permits 1–10,000
seeds and 1–512 random steps per seed, plus the healthy suffix. Each driver run
has a 90-second deadline. Delta debugging tries at most 96 reductions while
preserving failure category. Driver errors, malformed/incomplete output and
timeouts fail without becoming minimized invariant counterexamples. The store
and oracle retain bounded test history in memory; they do not measure production
resident-memory independence.

The runner also intentionally leaves one input undrained and requires the actual
driver's failed progress check to fail the task's checker, even though it agrees
with the oracle. Removing the final observation must classify the trace as
incomplete. These negative controls are counted separately from explored events.

`.cache/verification/simulation.json` records revision/dirty status, compiler,
binary/oracle hashes, generator, trace digests, counts, outcome coverage and time.
Each invocation marks completion false before running, preventing an interrupted
run from leaving an earlier success as its result. Failures retain `failure.json`,
`failure-evidence.json` and, for correspondence/progress failures, `minimized.json`
under `.cache/verification/simulation/`. Traces use synthetic keys and values.

The mutation task requires committed HEAD and a passing baseline. In an isolated
clone it separately removes real core route ordering and corrupts destination
provenance. Both must compile, execute and yield a minimized correspondence failure;
compile errors/timeouts do not count. Artifacts are under
`.cache/verification/simulation-mutations/`.

The ordinary core lane owns the small task. Weekly discovery runs 64 seeds with
128 steps and both delivery mutants. Earlier hosted budgets do not qualify these
additions; local timings and hosted cost evidence remain separate. Real disk,
service, SDK, browser and provider suites retain their independent obligations.

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
measurements for the native v1 authority. These are test datasets, not service SLOs.

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
and retained-version identities under their distinct v1 signature domains.
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
canonical v1 bodies, full-width IDs, signature domains and exact signatures.
`just test::client-abi` checks them and the real one-page-cache node/provider
restart, lost/invalid responses, fresh-process retry and current revocation.
This scenario qualifies the raw ABI. The growing Station boundary and public
language runners have separate scenarios and proof owners.

[sdk.json](sdk.json) is the version-1 behavioral scenario contract for M11. Each
scenario defines a sequence, required observations and executable proof owners;
the catalog checker rejects missing implementations or task ownership. These
are behavioral observations, not another copy of the wire schema. Presence in
the catalog is not a passing result.

[sdk_scenarios.py](../sdk_scenarios.py) compares all named observations exactly.
Public SDK adapters execute the same schedule through their own API
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

`bindings::python-test` adds clean installed public clients/runners and the
`public-runner-lifecycle` observations. It covers every persistence gate and
confirmation callback, native and host response ownership, exact retry after
host/node/store loss, full-width reply resumption, retained Table reads and
six complete owned IPC segments. Separate checks exercise poisoned reads,
codec stop/block policy, scoped/thread access, cancellation/join, expiry and
revocation during result reading. Other public languages must add equivalent
observations; Python evidence does not qualify those runtimes.

`bindings::python-test` also runs installed synchronous and asynchronous Table
mutation clients through `test::table-mutation --sdk python`. Each compiles an
UPDATE, replaces its caller after an accepted-but-lost receipt, retries the
original saved bytes, observes application and rejects disclosure after current
grant revocation. `bindings::mutation-python` selects this schedule independently.

`bindings::node-sdk-test` runs the installed TypeScript mutation caller with the
same lost-receipt and current-grant schedule at namespace `18446744073709551615`.
It also checks generated response validation, byte ownership and preservation of
uncertainty on unconfirmed submit responses. `bindings::mutation-node` selects
these checks independently.

`bindings::ruby-sdk-test` adds immutable mutation values through the existing
owned Ruby worker and native port. Its installed schedule uses namespace
`9223372036854775825`, rejects an altered request commitment, replaces the caller
after receipt loss, recovers the original command and enforces current status
denial. `bindings::mutation-ruby` selects that schedule independently.

`bindings::rust-sdk-test` adds owned requests and exclusively borrowed mutation
calls through the existing native worker. The installed crate consumer uses
namespace `9223372036854775826`, rejects an altered commitment, replaces the
caller after receipt loss, recovers the original command and enforces current
status denial. A separate compiler check rejects overlapping mutable borrows.
`bindings::mutation-rust` selects this schedule independently.

`bindings::c-sdk-test` adds installed C11 and C++17 mutation callers at full-width
namespaces. It checks copied request/prepared buffers, saved commands after native
client close, cleared C failure outputs, caller replacement after receipt loss,
exact retry and current status denial. C++ copy attempts reject during compilation.
`bindings::mutation-c` selects the shared mutation schedule independently.

`bindings::java-sdk-test` adds immutable Table mutation values and bounded futures
over the existing generated-schema port. Its installed caller uses namespace
`9223372036854775829`, replaces the caller after receipt loss, recovers the exact
saved command, rejects changed request commitments and enforces current status
denial. `bindings::mutation-java` selects that schedule independently.

M25 registers `test::server-applications`, `test::server-application-faults` and
`test::server-application-capacity` with invariant `CLI-03`. Their
[selected proof evidence](../README.md#m25-local-application-qualification) keeps
native loss/revocation, consumer lifecycle and physical capacity separate.
The ordinary hosted lanes and accepted M10 budgets remain unchanged.

## Resource publication simulation

`just test::resource-simulation-smoke` replays six saved storage-fault schedules.
`just test::resource-simulation --seeds 2` also explores first/middle/last I/O
boundaries of generated two-turn control schedules. `--exhaustive` enumerates
every observed I/O call; select it explicitly because page reads multiply runs.
`--trace PATH` replays concrete events independently of generator changes.
`just test::resource-simulation-mutations` uses committed isolated clones to omit
resource writes or input progress and requires actual correspondence failures.

The Zig driver uses the real core, four frozen decision slots, one resource/key,
captured views, a self-directed outbox, and a two-page provider cache. Stage faults
apply inside the real tree's individual/batch path; an after-stage fault may leave
orphan bytes without publishing a root. Read unavailability, pre/post-append
faults, explicit cache eviction and interrupted prefix trimming have distinct
trace events. Atomic conditional append and durable immutable pages are premises.
There is no disk, physical page deletion, provider rollback or corruption model.

The logical oracle checks state/input/output atomicity, captured values, exact
retry and accepted history floors. Recovery must stage no pages and match the
live engine. Generated healthy suffixes restore required permissions/time,
consume eligible input and check recovery after checkpoint/trim; pending outputs
remain recorded rather than implicitly delivered. The trace cap is 512 events
and 1 MiB, with 1..64 seeds and a 90-second per-driver deadline. Failures that did
not exercise their requested fault cannot pass. Every trace runs twice; checker
controls alter resource state, input progress, outputs and view evidence, omit
observations and leave input undrained.

`.cache/verification/resource-simulation.json` records completion, source/dirty
status, compiler/binary/oracle hashes, generator/configuration, fault counts,
trace hashes and duration. Failure details, concrete replay and bounded minimized
counterexamples live in `.cache/verification/resource-simulation/`. Numbered I/O
coordinates can change with implementation changes; a fault that no longer fires
requires an explicit corpus review, not silently accepting the run.

## Shared-client scheduling simulation

`just test::scheduler-simulation [--seeds N --steps N]` runs four saved cases and
four generated schedules by default. `--trace PATH` replays concrete events.
`just test::scheduler-simulation-mutations` requires committed HEAD and detects
omitted Session activation validation or discarded uncertain courier requests.

Real shared Session/courier functions use a test transport that signs native
queries and invokes the core, preserving response validation and modeled error
classes. Worker events separate preparation from submission. Four fault kinds
cover request versus response loss at query and submit boundaries. Saved cases
require the selected fault to fire. Host-loss events discard volatile pending
state; durable input/output progress remains observable. A finite profile tests
recorded permits, settlement, maintenance-driven expiry, checkpoint/trim and
clock rollback/uncertainty. This does not test HTTP framing or host task joining.

The independent checker conserves original admitted values, consumed prefixes,
outputs, destination admissions and provenance, plus ownership and current
permissions. It checks frozen pending digests and terminal dispositions. The
finite fair suffix admits no further input and gives two Sessions and the courier
twenty rounds to drain four inputs per producer. At most 512 events, 1 MiB input,
1..64 seeds, 1..256 random steps and 90 seconds per driver run are admitted.
Replay must be identical. Incomplete/invalid/time-limited runs cannot pass.

Evidence and replay/minimized failures live under
`.cache/verification/scheduler-simulation{.json,/}` with source, compiler,
binary/oracle, generator/configuration, exercised faults and completion identity.
The provider is the modeled atomic journal, not a real disk. Real caller and
courier integration remains `just test::callers`.
