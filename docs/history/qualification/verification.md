# Verification and qualification: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Formal checks, simulation, suite execution, CI costs and cross-domain qualification.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Shared direct preview repository check — 2026-10-24

`nix develop -c just check` passes on frozen source `1af0494e7`, including
contracts, independent fixtures, the disk-backed unit suite, CLI diagnostics,
console history, frontend checks and the documentation tests/build. Later host
inspection, administration, dependency and resource changes have their own scoped
evidence below and require the final combined and clean-checkout gates. This run
is not `just ci-clean` or installed-placement qualification.

## Installed lifecycle qualification checkpoint — 2026-10-26

[Retained task records](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-qualification-2026-10-26/report.json)
distinguish completed checks from partial lanes. Local clean `check-core` passes
at `9ab5fb64a` in 1,877.37 seconds. Full `just check` subsequently passes in the
same committed checkout. Eighteen core tasks pass before `test::station` fails
its captured-query completion deadline; the containing lane does not pass.

Clean bindings-2 at `90b0fc45e` completes all five owning tasks: Go (297.17
seconds), C/C++ (2,732.99), Java (756.83), .NET (666.85) and BEAM (1,753.81).
The BEAM task includes Erlang and Elixir. The retained task inventory, completion
metadata and compressed log identify that earlier revision and definition;
this is not final-source qualification after the later cutover and fixes.

Hosted run `40274455146` executes merge revision `7afcbcc7f`, including main's
count-range changes. Both launcher tasks pass. Eight experience tasks pass,
including Board/docs checks, observability, server logging, direct Table SQL,
direct fault recovery and database/native session lifetimes. `server-sql` then
fails on a capacity refusal with empty stdout during its Unicode read; later
experience tasks do not run. Its fixed Unicode/NULL observations now use the
existing 30-second capacity-refusal window, alongside the two fixed COUNT
queries. No mutation, denial, partial result or generic error uses this path.
The four unfinished core/growth/SDK lanes were cancelled when superseded by
run `40278906228`; they are not complete passes.

The [local diagnostic record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/installed-sql-diagnostics-2026-10-26/report.json)
retains the separate cancelled-append/restart failure. Its console was killed
by the fixture after 180 seconds, before the client's existing 270-second
accepted-operation settlement budget. The fixture now allows 300 seconds and
preserves the original SQL exception if cleanup finds an already-joined worker.
The following rerun executes those fixture and diagnostic changes.

The clean experience rerun at `e3dd9e68a` passes its first five tasks, including
server logging's native-attempt assertion. Installed direct SQL then passes
Table DDL and namespace checks, abrupt restart, retained operation inspection,
and deliberate Table deletion. After the next restart, the final CREATE for
name reuse returns `SqlOutcomeUnknown`; no SQL resubmission follows. The retained
manager log records native unavailability, replacement and exhaustion of the
three-restart budget while reconciling an original activation grant. This is a
failed 855.99-second task, not successful original-CREATE recovery or completion
of the experience lane.

The later public observation of that retained installation finds original
CREATE 751 still `uploading`, with no outcome or visible Table. No SQL is
resubmitted. This is incomplete intent publication, not accepted execution or a
recovered successful CREATE. The [retained observation](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/installed-sql-diagnostics-2026-10-26/final-create-observation.json)
and controller identify the exact binary hashes and operations inspected.

A fresh diagnostic installation using the same `e3dd9e68a` binaries passes the
complete unchanged direct Table schedule in 205.84 seconds, including final
name reuse. A native exec wrapper captures stderr; it changes the configured
artifact path/hash for that fixture, but executes the same binary and PID.
The heavy repository unit stage has finished before this run; this is not a
matched load comparison or an explanation of the earlier failure. Successful
fixture cleanup removes its native stderr file. The retained controller,
binary hashes and final task log establish the observed pass. The normal hosted
direct Table task also passes at the same Git tree, without that wrapper.

After the Station task correction, full `just check` passes in 1,573.24 seconds.
Its controller starts at `31b48b73e` with the task patch; the task/documentation
commit `2f5018ad2` lands during the unit stage without changing runtime sources.
The subsequent committed-HEAD clean launcher lane at `2f5018ad2` passes both
tasks: build smoke in 48.54 seconds and local launchers in 442.23 seconds.
The [validation record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-qualification-2026-10-26/post-168-validation.json)
and separate launcher metadata retain those source boundaries. These are
completed checks; the remaining combined lanes are still separate gates.

## Installed lifecycle follow-up and Station CI dependency — 2026-10-26

The [retained records](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-post168-2026-10-26/report.json)
include a further full `just check` pass after the database-client correction.
Committed-checkout experience at `0582556e3` passes nine tasks, then fails an
UPDATE in local SQL authentication. Public signed inspection after restarting
that same installation finds original operation 194 still `uploading` and
dispatch-ineligible, with no terminal outcome. SQL is not resubmitted. This is
incomplete publication, not accepted execution or successful UPDATE recovery.

A fresh diagnostic using the same binaries and explicit exec wrappers loses a
CREATE connection after `native.append` reports `Canceled` and the WAL requires
recovery. The retained native/gateway stderr identifies that sequence, but not
the cancelled I/O stage or its environmental cause. A subsequent full diagnostic
passes local authentication and accepted-owner bootstrap recovery with a node
rebuilt to label WAL I/O failures; none occurs. Its patch and changed binary
hash are retained. Neither diagnostic is an installed-adjacency qualification;
no diagnostic instrumentation or recovery-gate change ships in the runtime.

Hosted run `40285606874`, at merge revision `c19beb45e`, passes the first twelve
experience tasks, including the complete source-bundle SQL schedule (636.39
seconds) and Board query recovery. Its final Station launcher task fails at
import because the experience shell lacks PyArrow. The shell now supplies
PyArrow 23.0.0 from the existing locked nixpkgs input. At `0a0f46ec5` plus that
shell/documentation patch, `nix develop .#ci-experience --command just
launchers::local::test-station` passes registry/call/Arrow exchange, worker
recovery and upgrades, Board provenance, and persistent stop/start. Injected
read refusals cause one courier replacement in 30.381 seconds and query completion
in 16.581 seconds, within the unchanged separate 60-second deadlines. Doctor,
Nix formatting and imports pass; compiler/package pins and lockfiles are unchanged.

Hosted bindings-2 also completes all five Go/C/C++/Java/.NET/BEAM tasks at
`e4b4955cb` (4,226.22 seconds) and `289e42b40` (2,726.58 seconds). Both use the
current shared definition; BEAM includes Erlang and Elixir. Their exact task
inventories and metadata are retained. These completed SDK lanes and focused
Station pass do not complete the failed experience lanes or the remaining
combined qualification.

## Installed lifecycle qualification after CI prerequisites — 2026-10-26

The same [evidence bundle](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/catalog-prefix-2026-10-26/report.json)
retains completed hosted core at `c19beb45e`: all 28 tasks in 3,537.72 seconds
under the revised outer cap. Bindings-1 at `e4b4955cb` completes all seventeen
tasks in 6,951.89 seconds with the current shared definition. Together with the
separately recorded bindings-2 pass at that revision, all SDK tasks complete.
These source-attributed passes predate the catalog-prefix implementation.

At committed `14c7175e3`, full `just check` passes in 249.15 seconds. Clean
experience passes seven tasks, then its lifetime fixture's initial INSERT
reports `SqlOutcomeUnknown`. Public signed status after restarting that same
installation finds original operation 98 `uploading`, dispatch-ineligible and
without a terminal outcome. SQL is not resubmitted. A same-binary diagnostic
with explicit exec wrappers passes all lifetime phases in 168.26 seconds; the
normal owning task then passes in the corrected CI shell without wrappers.
Neither establishes the failed clean run's cause or turns it into a pass.

Hosted run `40293594898`, merge revision `b22d9a03b`, completes all thirteen
experience tasks in 2,327.25 seconds, including installed SQL authentication,
lifetime/recovery, Board queries and the Station launcher. The subsequent
Chromium schedule passes four of five tests, then rejects the query JavaScript
asset at **913,584 bytes** against the unchanged **900,000-byte** bound. Its
trace and page context remain in artifact `12639750899`; task metadata and the
job log are retained here. The combined experience/browser job has failed and
does not establish final qualification.

## SQL branch integration of seeded simulations

The SQL branch rebases onto `a53d6262` (merged PR #33), preserving the expanded
resource, shared Session/courier, component and external fault suites. The
consolidated query and protocol owners remain in use. All 75 rebased commits
retain their author dates and use matching committer dates. Conflict resolution
preserves both task/invariant inventories and roadmap scope; Session and courier
production files match main exactly.

On development source based on `9140972c`, pinned Zig
`0.17.0-dev.2267+48abf1a34` and the bindings shell:

- Full `just check` passes, including unit tests, generated contracts, CLI
  diagnostics, frontend checks and the documentation build. Final direct checks
  pass 4581 links across 480 files and 56 invariants/53 bounds/13 SDK scenarios.
- `just test::domain-simulation --seeds 8` passes **40 package schedules with
  identical replay in 13.302 s**. The new catalog domain runs 512 requests over
  eight seeds: 128 fresh Tables and 128 conflicts of each kind. Every round
  injects a point/page failure and compares committed state with an independent
  accepted-request ledger; seeded choices also cover revocation, discarded
  proposals and replacement after lost replies. Each seed ends with 115 keys,
  sixteen created Tables and all 64 original receipts. Sorted bounded pages and
  changed-cut rejection are checked throughout.
- The catalog test binary SHA-256 is
  `8d69a473d37ba62b800965f8f0f372c11b58f20aab3ff522c421062fecc53a05`;
  runner SHA-256 is
  `2b157b687d1c9f12e87efc56f7277e7b0605e802099da974846d694a3c361a06`.
  `.cache/verification/domain-simulation.json` records all five binary hashes,
  source/dirty status and per-seed trace hashes; its adjacent directory retains
  original and replay events/logs.

Logs are `/tmp/transit-sql-pr33-full-check.log` and
`/tmp/transit-sql-pr33-domain.log`. These private-turn stores model atomic
publication; they do not qualify physical journal faults, native catalog growth,
signed transports or installed SDKs. Compiling catalog policy/receipt mutants
are registered for the committed-source checker; registration alone is not a
passed mutation proof. Separate execution results follow their completed runs.

Committed `08fd00a6` also passes `just test::domain-simulation-mutations`.
All seven compiling mutants are detected by executed assertions, including the
new current-create-policy bypass (2.420 s) and overwritten receipt position
(2.375 s). The baseline and original five component defects pass their expected
checks; build failures are not counted. Evidence is
`.cache/verification/domain-simulation-mutations/evidence.json` with per-mutant
traces/logs, and `/tmp/transit-sql-pr33-domain-mutations.log`.

The rebased resource run (`just test::resource-simulation --seeds 4`) passes
**402 traces / 7804 events with identical replay in 216.661 s**. The shared-client
run (`just test::scheduler-simulation --seeds 8 --steps 96`) passes **12 traces /
1410 events in 37.499 s**. Both began on development source based on `9140972c`;
reports retain exact binary/oracle hashes and configuration. Logs are
`/tmp/transit-sql-pr33-simulations.log`. Resource faults use the atomic in-memory
journal premise; the scheduler uses signed in-process transport. Neither result
expands the documented physical-durability or host-cancellation evidence.

Python, TypeScript, Rust and Ruby packages are rebuilt against the rebased
libraries before `just test::catalog --sdk python --sdk node --sdk rust --sdk ruby`.
The combined installed schedule passes in **48.876 s**, including **25.066 s**
installation: **2157 reads, 51 accepted turn responses, ten lost caller receipts
and three lost owner receipts**. Original receipts, current catalog/native denial
and replacement after lost admission pass for all selected callers. Bounds remain
four mutations, 133-byte values and eight resident pages; twelve Tables do not
establish native catalog growth. This report binds `08fd00a6` with dirty status
(the resumed C/C++ source is uncommitted and not selected). Artifact hashes and
execution output are retained in `/tmp/transit-sql-pr33-sdk-native.json` and
`/tmp/transit-sql-pr33-sdk-native.log`.

Rebuilt native SHA-256 values:

| Artifact     | SHA-256                                                            |
| ------------ | ------------------------------------------------------------------ |
| `node`       | `6f27157343edbf4311ceaeba4444566c9ce91a761ce2f6b647a2e0667d393e8c` |
| `proof`      | `03074b53ddcb92a57e63a00f2e2b53093fc61efaf5b8cdca4ae3214f1464340f` |
| `host`       | `64fd1efeeb6cee7a182271439cb429fa2fc4c68d31e8a68c2e82b74bb70faa72` |
| `port`       | `67db289ec20b1e2dc94ebe918694f17be34d5c33dc1e219e8bc72a723f284643` |
| `library.so` | `85411c09a7e8bc832050fead3fc93c5eb54eeb37966f847ff6f2f7792dc9780c` |
| `cli`        | `ec1ee54bcf1e41a345b7a52e4398fbcfa012adc530240af943677aefc2d76351` |

Committed-HEAD `just ci-clean --lane core` passes **all 22 tasks at `08fd00a6`
in 744.86 s**, including the added resource, shared-client, catalog/component and
external fault suites. It installs locked frontend dependencies and runs from a
fresh clone without inherited build outputs. Completion and per-task timing are
in `.cache/ci/clean/08fd00a6d234-transit-ci-9cznago1/`; the log is
`/tmp/transit-sql-pr33-ci-clean.log`. This qualifies the expanded core lane and
separately recorded focused schedules, not a full clean suite or the resumed
uncommitted C/C++ implementation. Existing incomplete proof runs remain recorded.

## Interrupted CI evidence — 2026-10-01

Hosted launcher job `110201098691` reaches its 30-minute execution cap after
`test::build` passes in 592.32 seconds, while `launchers::local::test` is active.
The original runner writes results only in `finally`; cancellation leaves no
CI JSON for artifact upload. Shell preparation alone takes 623 seconds.
The [interruption record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-ci-interruption-2026-10-01.json)
retains the job phases, timeout annotation and log hash.

The corrected runner atomically checkpoints each completed task and the current
attempt before/after execution. Its actual entry point retains one passed task
and the interrupted second task under both SIGTERM and SIGKILL, never running
the third. A subsequent complete run records all three successes. The original
runner fails this control because the checkpoint is absent. Existing definite
failure propagation and aggregate-gate checks pass. A cancelled task receives no
invented exit status or duration; metadata remains incomplete at its checkpoint.

CI also saves the rooted Nix shell before long checks and uploads the separate
Station readiness record. Cache keys, cold-mode exclusion, job execution caps,
proof deadlines and provider guards remain unchanged. Workflow ordering requires
hosted validation; these controls do not qualify a complete lane or cost budget.

## Qualification checkpoint — 2026-10-01

At frozen committed `88fc1d0d`, clean experience and browser (archived)
pass all seven tasks in each lane. Full `just check` passes in 228.407 seconds;
experience takes 521.652 seconds and browser takes 2,580.391 seconds, including
clean setup. The original Station reply arrives in **59.7616 seconds** under its
unchanged 60-second cap, before cleanup restarts the courier. This narrow pass
does not diagnose earlier progress failures. The browser lane includes complete
HTTP/RPC crash-recovery proofs, reactive transport, live-view verification and
lifecycle checks. Core, growth, launchers and bindings at this revision remain
unrun; earlier source results do not fill those gaps.

The completed continuation run (archived)
`36809340716` records **61 ordinary passes, one failure, two interrupted tasks
and ten unrun tasks** out of 74 at synthetic merge `7e0d6a69`. The separate browser
tier has one pass, one failure and five unrun tasks. The failures are the upload
marker comparison and cleared-result redisplay corrected below; launchers reaches
its job cap and the next push cancels bindings during its C SDK task. Completed
bindings tasks come from retained job logs because no final artifact is uploaded.
This incomplete run takes **76m40s** feedback and **223m21s** aggregate job time,
restoring **4,947,520,314 bytes** with mixed/missing cache hits. It does not qualify
a cost budget.

The next ordinary and discovery runs (archived)
at `88fc1d0d` are refused before any job executes. GitHub reports an account
payment/spending restriction. Both runs contain zero test results; neither
supplies passing or failing proof evidence.

The [cost-inventory control](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-ci-cost-inventory-2026-10-01.json)
exposes a reporting error: a synthetic successful core-only run with known warm
caches meets the old collector's full-suite budget check. The corrected collector
requires exactly one job for each ordinary inventory lane and reports missing or
duplicate lanes as inconclusive while retaining measured timings and cache bytes.
Controls cover each missing lane, duplicates, full warm/cold selections, skipped
jobs, incomplete timestamps and missing cache evidence. The CI runner checks pass.
These synthetic checks do not supply hosted cost samples or change any budget.

The completed hosted record (archived)
for run `36803044000` retains **53 passed, two failed and thirteen unrun** ordinary
tasks out of 68 at synthetic merge `03ab0209`. Its tree matches merged `9fdf1d02`.
Core, launchers and ordinary experience complete; bindings stops at the optional
Node Arrow installation, and growth stops at the HTTP example's upload-marker
comparison after nineteen passing tasks. The separate browser tier fails its
first task and leaves six unrun. The corrections below retain those failures.

This failed, partially cached run takes **70m02s** from creation through final
gating, **196m22s** aggregate job time and restores **12,257,714,802 bytes**.
All job logs are available. Its cache profile is neither warm nor explicit cold;
it does not qualify a budget. The numeric budgets retain their earlier 33-task
calibration and do not certify the expanded inventory.

The [local checkpoint](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m37-local-progress-2026-10-01.json)
keeps clean experience's seven passes at `5c76d03e` separate from its later core
failure after nineteen passes. Clean experience at `31f071d0` passes six tasks,
then misses the original 60-second Station Arrow-reply window following the
courier readiness fault. The original reply later exists without resubmission,
after the fault fixture restores the original endpoint and restarts the courier
during cleanup. This observation does not prove completion without that
intervention. The owned
installation is then stopped and its disk state retained. Current evidence does
not establish the cause of that progress delay. The local Station proof writes
`.cache/m9/station-local-readiness.json` after its timed schedule and cleanup,
including replacement timing, reply time, whether it passed before cleanup, and
whether cleanup restarted the courier. Writing this evidence does not extend
the 60-second reply deadline.

A focused disk-backed query run at clean `5c76d03e` passes, with delivery taking
84.552 seconds under its unchanged 180-second cap. Nineteen matching request
coordinates from the earlier failed tail have identical cache-miss counts and
negligible authority-lock waits, but longer engine/provider work. These two
source/host observations narrow the investigation; they do not establish cause
or erase the earlier timeout.

The complete Node SDK task also passes under `CI=true GITHUB_ACTIONS=true` on the
development source with the installation correction, including Station, HTTP,
gRPC, mutation and catalog schedules. It is a focused development run; edits and
commits during that run prevent treating it as committed-source clean evidence.
The remaining clean, hosted/browser and expanded cost gates stay open.

## Expanded fault-verification qualification — 2026-09-30

The local experiment record (archived)
binds the source revisions, dirty development runs, compiler/binary/runner hashes,
counts, fault coverage, negative controls and elapsed times. The last implementation
revision is `b0462904`; subsequent ledger changes contain documentation/evidence.
Passing profiles below retain their actual source identity. They do not combine
into a complete ordinary-suite pass.

| Executed profile             | Result and scope                                                                                                                                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Repository checks            | `just check` passed at committed `fb912908`, including units/contracts, ownership inventory, frontend checks and the public Docusaurus build                                                    |
| Expanded resource simulation | At committed `5b267061`, 204 traces / 3,958 events replayed identically in 111.250 s; staging/read/publication/trim faults and independent atomicity/view checks                                |
| Clean ordinary simulations   | At `e92087ff`, 14 authority traces / 749 events, six resource traces / 112 events, eight Session/courier traces / 542 events and eight component package schedules passed with identical replay |
| Compiling mutations          | At committed `5b267061`, all nine new resource, scheduler and component mutants were detected by executed contract checks; build failures/timeouts did not count                                |
| External supervisor          | At `f7d0361f`, seed 19 / twelve rounds passed in a fresh checkout in 19.588 s; the later clean core run also passed four rounds, with requested faults observed and cleanup joined              |
| Installed SDKs               | Python/Node package builds and independent installed consumers passed in 30.343 s total; signed histories, cancellation/disposal and exactly two admissions retained                            |
| Application/provider fixture | Lost provisioning, rotation, migration and activation replies plus runtime upgrade passed in 28.531 s total                                                                                     |
| Query lifetimes              | Durable lifecycle, durable expiry and interactive Table cancellation/current denial passed in 385.887 s total                                                                                   |
| Browser/reactive lifecycle   | The real TLS/browser owner passed refresh replacement, pause, revocation, stream loss/resume, pagehide/expiry and reset/resnapshot in 169.381 s total                                           |

`just ci-clean --lane core` passed all 22 tasks at `e92087ff` in 1,186.95 s.
`just ci-clean --lane experience` passed all seven tasks at `b0462904` in
443.77 s, including the real local Station launcher and clean Node dependency
build. The clean launchers lane passed both tasks at `4df41ba5` (57.56 s for
artifact builds and 283.36 s for local lifecycle, replacement and cleanup).
These are distinct committed revisions; only this final evidence update follows
the last launcher qualification.

Repository-wide qualification remains incomplete:

- At `5b267061`, 27 tasks passed before the publication expiry assertion failed;
  37 tasks were unrun. The clock-bound fixture correction subsequently passed
  the complete publication proof in the `fb912908` clean run.
- At `fb912908`, 37 tasks passed before HTTP cancellation follow-up admission
  failed; 27 tasks were unrun. The corrected fixture chooses its finite
  reconciliation window before initial acceptance and checks that every follow-up
  preserves it; production deadlines are unchanged. The corrected complete HTTP
  proof passed at `b0462904` in 492.21 s excluding compilation: sixteen remote
  sends, eight applications, two cancellations and 1,153 cold objects.
- The parallel `e92087ff` growth lane passed three tasks, then exceeded the
  existing 180-second query delivery deadline. No deadline was relaxed.
- The `e92087ff` bindings lane passed native bindings and the full installed
  Python/Node SDK tasks, then its Rust Station consumer terminated with SIGSEGV
  in `decode-block`. Eleven later tasks were unrun. A focused full Rust
  Station/HTTP rerun and 32 additional fresh malformed-input blocking cases
  passed with the same implementation; the original crash remains unexplained.

The earlier clean Node check failed because it checked Station before emitting
its client's package exports. The corrected dependency ordering passed the
complete clean experience lane above. None of these corrections relabels a
failed or incomplete run as successful.

The installed/service/browser runs are separate selected local profiles, with their
original revision/dirty flags retained in the record. They do not certify other
hosts or Kubernetes placement. Vortex checks quiescent public correspondence,
not arbitrary concurrent-read linearizability; process SIGKILL is not power loss.
Simulation assumes atomic journal append and does not qualify physical page GC.
Component schedules replay seeds with pinned binaries; only the JSON-trace profiles
provide edited-trace replay and bounded minimization.

Hosted run [36678421267](https://github.com/spoke-sh/transit/actions/runs/36678421267)
produced no test execution: GitHub refused job startup because of account
payments/spending limits. The local observations do not requalify hosted feedback,
aggregate runner time or cache budgets. Hosted ordinary/discovery runs and cost
measurement remain tracked by [issue #26](https://github.com/spoke-sh/transit/issues/26).

## Component simulation

At dirty source based on `d3562a07`, `just test::domain-simulation --seeds 8`
passed 32 package schedules, each replayed identically, in 9.586 seconds with
pinned Zig `0.17.0-dev.2267+48abf1a34`. Five domains cover concurrent Document
assignments and dependencies, checkpoint discard/final floors, Exchange closure
and replay holds, query refresh ownership/source cuts, and provider activation.
These are real component operations over private-turn stores. They do not qualify
physical storage, application installation, transport or remote dispatch. See the
[harness guide](../../../tests/verification/simulation/domains/README.md) for exact bounds,
artifacts, seed replay and separate mutation qualification.

At committed `a59e0d9c`, all five real-code mutations were detected by executed
contract assertions (1.245–1.508 seconds each). Trace logging is enabled only by
the component runner; ordinary package tests execute the same assertions quietly.
The two-seed replay after that logging change passed in 2.377 seconds.

## Shared-client scheduling simulation

The shared Session/courier driver runs production preparation, frozen retry,
activation checks and courier selection against controlled signed transport.
Its [guide](../../../tests/verification/simulation/scheduler/README.md) defines
faults, invariants and limits. At dirty source based on `b6626cae`, the ordinary
run passed four saved and four generated schedules: eight traces / 542 events,
each replayed identically, in 15.876 seconds. The finite case exercised recorded
permits through settlement, expiry maintenance, trim/recovery, clock rollback and
untrusted time. The standalone client package tests and `just test::callers`
also passed, including real counter/byte-log programs, automatic courier delivery,
exact retries, stale activation and disk recovery. The proxy printed a broken-pipe
diagnostic during its interruption scenario; the complete caller task exited zero.
These are shared-host development observations, not hosted cost or OS scheduling
qualification. Compiler/binary/oracle identities are retained in the artifacts.

The shared-client ABI proof passed at `982b85b0`. At `d3562a07`, both compiling
shared-client mutants were detected: discarded courier uncertainty (2.646 seconds)
and omitted Session activation validation (1.739 seconds). The earlier checker
missed uncertainty created and lost within the first courier step; the corrected
oracle explicitly requires that submission's digest to remain pending. Its full
eight-trace / 542-event run passed in 16.730 seconds before mutation qualification.

## Resource publication simulation

The resource profile adds numbered page staging/read faults, a two-page cache,
resource/input/output correspondence, captured view roots and checkpoint/trim
recovery. The [harness guide](../../../tests/verification/simulation/resources/README.md)
owns commands and model limits. On the shared Linux host with pinned Zig
`0.17.0-dev.2267+48abf1a34`, the first development sweep based on `38ac8781`
passed 99 traces / 1,923 events, each replayed identically, in 53.290 seconds.
After adding the saved corpus, `just test::resource-simulation-smoke` passed
six traces / 112 events in 3.409 seconds. Both were dirty development runs;
metadata records binary/oracle identity. At committed `b6626cae`, both actual
core mutants were detected: omitted resource writes in 2.128 seconds and omitted
input progress in 2.079 seconds, including bounded minimization. These in-memory observations do not
establish actual WAL durability, physical page reclamation, full CI completion
or hosted cost. Compiling core mutation qualification is a separate command.

## Authority and delivery simulation

The multi-process simulator executes real signed authority/outbox transitions for
two producer PIDs and one destination, with eight delayed-decision slots and an
atomic in-memory journal. Its independent oracle checks every operation outcome,
ownership/sequence/lifecycle projection, output and destination-input provenance.
Cold recovery must match the live engine without writing pages; the live engine
and cache persist until an explicit restart. The
[harness guide](../../../tests/verification/simulation/storage/README.md) owns
commands, fault assumptions, bounded progress and artifact formats.

The initial development run of `just test::simulation` passed six saved cases and
eight generated 48-step schedules: 14 traces, 749 events, each replayed identically,
in 18.287 seconds on the shared Linux development host. The healthy suffixes add
events beyond the requested random steps. These are test execution timings, not
throughput or deployed latency measurements. The run used the pinned Zig
`0.17.0-dev.2267+48abf1a34`; evidence records the binary hash and dirty source status.

Initial driver bring-up exposed an optional-slot assignment that became populated
before failed preparation completed. The minimized two-event schedule is retained
in `failed-preparation.json`; preparation now finishes before assigning the slot.
This was a harness defect, not a discovered Transit protocol defect.

At committed source `76ad31e3`, `just test::simulation-mutations` passed its
unmodified baseline and detected both compiling real-core mutants. Omitting the
route-order guard minimized to seven events; corrupting delivered output provenance
minimized to five. Mutation executions took 9.626 and 6.235 seconds respectively,
including minimization. Artifacts are in `.cache/verification/simulation-mutations/`.

The expanded development run, `just test::simulation --seeds 64 --steps 128`,
passed 70 traces and 10,535 events with identical replay in 246.809 seconds.
It ran alongside repository checks on the shared host; its metadata identifies
dirty source based on `6f629aaa`, the unchanged driver later committed in
`76ad31e3`, and the oracle hash. `just check` passed formatting, package/unit and
contract checks, verification ownership, frontend checks and the Docusaurus
production build. These runs do not establish clean-checkout qualification or
new hosted CI costs.

After adding runner negative controls, the ordinary simulation passed the same
14 traces / 749 events in 18.884 seconds and rejected both deliberately undrained
work and incomplete output. The unchanged authority/resource property suite also
passed its 40 traces / 1,687 steps in 14.345 seconds. These development runs were
based on `76ad31e3` with the recorded runner/documentation changes.

The profile does not execute application handlers, resource mutations, an
automatic worker/courier scheduler, clocks, HTTP or real disk. Its progress check
restores permissions and explicitly schedules finite eligible work with available
storage. It does not prove scheduler fairness or general liveness. The complete
external real-binary program remains tracked by
[issue #26](https://github.com/spoke-sh/transit/issues/26).

## Test ownership

This directory owns conformance harnesses, fault injection, test-only executors,
and proof results. Application examples live under [examples](../../../examples/README.md);
tests launch those real binaries rather than a separate implementation of their
logic. The [conformance design](../../handbook/reference/verification.md) owns the required adversarial
scenarios. Results below describe the recorded bounded milestone profiles, not
a claim that all commands are rerun on every documentation change.

## Running checks

`just check` includes `tests/reference_launcher_state.py`: isolated launcher
regressions cover missing infrastructure, replaced clusters/namespaces, original
identity recovery, interrupted namespace creation and explicit local cleanup
after cluster deletion. Docker failure cannot count as absence. These mocked
boundary checks supplement the real reference launcher proof; they do not claim
Kubernetes recovery or isolation by themselves.
The 2026-09-26 local repair also exercised fresh counter provisioning and a real
reference stop/start cycle: state remained 12, realm/PID/namespace/Actor stayed
fixed, and ownership advanced from generation 4 to 7 with a different worker.
That focused recovery check did not rerun the full reference isolation corpus.

M7 evidence is recorded in [the state proof](runtime.md#m7-state-resources). The ordinary
suite includes the public state API and real resource-backed Zig caller.

M9 proofs include `just test::arrow` (independent PyArrow validation
of Fuze IPC, including nulls, empty results and wide integers) and
`just test::client-abi` (a generated C header, real authority calls, canonical
signatures, receipt loss, fresh-host retry, revocation and malformed input).
The [Fuze integration notes](../../../packages/zig/transit-fuze/docs/integration.md) and
[client binding guide](../../../packages/zig/transit-client/docs/bindings.md) record
their limits. `just test::station` launches the real Zig Station ledger/requester
and courier, proving private state/call commits, lost receipts, fresh ownership,
worker plus store recovery, authenticated replies, scoped registry/supervision,
timers, poison-input blocking and opted-in lifetime expiry/reclamation.
The [M9 evidence](catalog.md#m9-station-bindings-and-tables) below distinguishes native
language qualification from reference worker qualification.

M11 extends `just test::client-abi` with the explicit growing raw-client boundary.
Its [shared fixtures](../../../tests/sdk/sdk-operations-v1.json) pin v3 canonical bytes,
signatures and full-width IDs. The real disk proof checks principal 65,536,
node/provider restart, opaque retry in a fresh process, lost/malformed accepted
replies and revoked reads/receipt recovery. Allocation enumeration covers both
mutation profiles. `just check` and the complete `just bindings::test` matrix
passed after this extension.
The same raw-client task now also runs the independent
[client port](../../../apps/transit-client-host/README.md), including metadata identity,
profile/command classification, malformed canonical recovery and seedless retry
from a fresh process. Its executable imports no Station implementation. The raw
port and `station_codec_host.py` also verify explicit shutdown acknowledgements
and successful exit while stdin remains open. Station covers local-codec, raw,
legacy and query-enabled growing handles. Native cleanup precedes the response;
this lifecycle acknowledgement does not replace mutation receipts.

`just bindings::test` also runs the [growing Station ABI proof](../../../tests/sdk/station_growing_abi.py)
against disk-backed Ursula. It checks every mutation's preparation/dispatch gate,
41 Table rows through bounded pages, retained sources, stale scopes/cursors,
poisoned reads, explicit stop behavior, revocation, native port parity and exact
retry from a fresh process after caller/node/store loss. Native allocation-failure
enumeration preserves accepted receipts until the host can receive them. Both
`just check` and the complete existing language matrix pass with this boundary.
The companion [query ABI proof](../../../tests/sdk/station_query_abi.py) uses the native query
profile's bounded 64-page cache. It captures and delivers 41 rows in six IPC
segments, retries lost staging receipts, restarts workers/node/provider after a
seal, checks complete source metadata and decodes owned IPC with PyArrow after
native disposal. Port parity, disabled query access, stale scope and revocation
are covered by the shared `query-abi` scenario. Public language adapters have separate qualification below.

`just bindings::python-test` builds Python wheels, installs only `transit-client`
and `transit-native-client` into an isolated consumer outside the source tree,
and exercises the public raw API against disk Ursula. It covers typed bounds,
copied mutable payloads, canonical classification, a dropped accepted receipt,
seedless retry in another process, host allocation failure after a receipt,
revoked historical retry, one-operation admission and responsive async close
after await cancellation. Strict typing covers the public client and native
artifact resolvers. A second isolated consumer installs Station and the example
package, then exercises the typed runner against a real disk node. It covers
persistence and confirmation failures for permit/open/commit, post-acceptance
host allocation, escaped/wrong-thread turns, strict ingress with stop/block
policies, a poisoned read caught by a handler, responsive cancellation during
an accepted commit, and exact seedless retry after killing the host and restarting
node/provider. Installed counter CLI roles preserve a full u64 reply across a
fresh requester activation. Table/query handlers prove 41 rows/six pages, retained
point reads after mutation, six original IPC segments after disposal, current
access revocation during a result read and process expiry. The optional PyArrow
23 adapter uses the pinned Nix consumer after the independent clean core install.
The shared `public-runner-lifecycle` scenario records comparable observations for
all targets. Qualification is Linux x86_64 with Nix-linked native wheels.

`just bindings::node-sdk-test` builds the independent Node client/native tarballs,
checks the strict public API and installs them outside the checkout using ordinary
package-manager overrides for unpublished local artifacts. No Station package or
manual native loader path is present. Python and Node run the same
[raw-client schedule](../../../tests/sdk/sdk_raw_client.py): copied input/export buffers, native
classification, a lost accepted response, seedless host restart, failed host
response parsing/allocation, current revocation, bounded overlap and responsive
close after a local await/abort. A second clean consumer installs Station and the
executable counter/query examples. Python and Node share the
[runner authority schedule](../../../tests/sdk/sdk_station_runner.py), including every mutation's
persistence/confirmation hooks, dropped accepted commits, exact seedless recovery
after host/node/store restart, stale/revoked/expired callers, poisoned reads,
41-row retained Tables and six original IPC segments. Node additionally checks
dropped, overlapping, escaped and foreign-context turn calls, callback reentry,
and responsive stop/join during an accepted commit. Its runner unit proof injects
a retained confirmation after host allocation failure; raw port-response failures
and native allocation enumeration retain their separate real boundary proofs.
The optional Apache Arrow JavaScript 21.2 adapter is installed only after the core
proof and preserves int64/null values after disposal and mutation of input copies.
The consumer selects the root manifest's pnpm version through `vp env exec` and
uses normal package-cache fallback; a different filesystem may have its own cache.
Strict checks compile both public examples. Linux x86_64/Nix-linked tarballs are
qualified.

`nix develop .#bindings --command just bindings::rust-sdk-test` builds the
independent raw Rust client and matching native crate. The external consumer
builds with the lockfile and ordinary Cargo patches for unpublished artifacts,
then deletes extracted crates and build outputs before running its installed
executable. The embedded library loads without a Cargo-cache or loader path.
It runs the same raw authority schedule, plus compile-fail checks for overlapping
mutable use, shared handles and use after consuming close. Its initial API is
blocking: `blocking-owner-disposal` abandons an application's receive, keeps
native work owned through explicit close, joins responsively and recovers the
same receipt. It does not claim an async executor adapter.

The Rust Station consumer installs five crates and builds core and optional
Arrow variants using the SDK lock. Registry versions/checksums remain unchanged;
the core dependency tree excludes Arrow. After deleting extracted sources and
builds, it runs `sdk_station_runner.py`, including both installed counter CLI
roles. Compiler rejection covers overlapping turn helpers, `Send`/lifetime escape
and a boolean passed to the u64 codec. The real schedule covers persistence errors
and panics at permit/open/commit gates, handler errors and panics under stop/block
policies, retained confirmation receipts, responsive stop/join during an accepted
commit, caught poisoned reads, exact seedless retry after disk/host restart,
fencing, retirement and revoked result access. Retained Tables span six pages;
six owned IPC streams preserve i64 extremes/nulls and complete source metadata.
The optional Arrow Rust 59 adapter decodes after runner disposal and its batches
survive mutating the SDK bytes; independent PyArrow verifies the same streams.
Rust does not inject an allocator failure into its own FFI wrapper; native retained
confirmation behavior is also covered by the shared ABI/Python proof.

`nix develop .#bindings --command just bindings::ruby-sdk-test` builds and installs
separate Ruby 3.4.9 client/native gems outside the checkout. Its raw schedule
qualifies owned binary strings, full principal bounds, native canonical kind
classification, lost receipts, seedless recovery and revoked historical retries.
Killing the controller thread during an accepted send leaves native work owned;
concurrent work rejects, close joins responsively and retains the known receipt.
Missing/incompatible host overrides and oversized, invalid-UTF-8, malformed-status
and truncated port replies fail with read/uncertainty distinctions. The client
has no Station dependency. Interrupted block acquisition waits for startup and
then joins both the Ruby worker and native child. The bindings CI lane includes
these public proofs.

The Ruby Station consumer installs five gems and invokes both documented counter
CLI roles. It runs the shared `sdk_station_runner.py` schedule with full-width
codec fixtures, all persistence/confirmation gates, reentrant-call rejection,
normal and non-StandardError handler failures under stop/block policy, expired
helpers and cross-thread/fiber access. Killing a waiting caller retains owned
native work through responsive close, including an accepted commit. Exact retry
survives host/node/disk loss without a seed, and fresh owners resume durable calls.
Poisoned reads, retirement, stale ownership and revoked result access retain their
meaning. Retained Tables span six pages, and original IPC buffers survive runner
close and mutation of returned copies. Independent PyArrow decodes all six
segments, including i64 extremes and nulls. Ruby has no selected native Arrow
adapter; the optional-adapter step is explicitly disabled for it, while the full
IPC/metadata/independent-consumer proof runs. Codec reentry is rejected, and a
caught state decoder failure aborts without committing or blocking the head even
under `block_input`.

`just bindings::c-sdk-test` builds versioned C SDK/native archives and C++ headers,
installs them into external prefixes and compiles separate C11 and C++17 callers
with standard pkg-config discovery. Consumers use installed rpaths and adjacent
native discovery without a library-path environment variable or Station library.
Both run the shared raw-client schedule: owned input/export bytes, metadata and
canonical-kind checks, lost accepted receipts, seedless recovery, revoked retry
and responsive joining of an owned blocking task after its controller stops
waiting. C also checks overlap/closed rejection; C++ checks move-only types and
distinct process/resource references. Missing libraries, incompatible native
versions and C SDK version mismatches fail explicitly. The implementation owns
one admitted job and an 8 MiB worker stack. Asynchronous POSIX thread cancellation
is not supported; the controller's local wait is the cancellation boundary.
This qualifies raw clients on pinned Zig/Linux x86_64 with the Nix runtime closure.

The same task installs C/C++ Station SDKs and the actual counter CLI/application
artifacts. A shared C++ conformance controller selects the direct C runner with
compiled C11 callbacks, then the public C++ runner with typed C++ handlers. Both
execute the full `sdk_station_runner.py` schedule: golden codec names/bytes and
u64/i64 extremes, persistence/confirmation failures for each mutation purpose,
callback reentry, exceptions and malformed input under stop/block policy, retained
scope rejection, responsive stop/join through an accepted commit, poisoned reads,
fencing/retirement/current access, and exact seedless recovery after host/node/disk
loss. Six-page Tables exercise retained point/page reads after mutation. Six
original IPC segments survive runner destruction and mutation of copies before
independent PyArrow decoding; no optional C/C++ Arrow adapter is selected. Installed
counter roles run as their actual C11/C++17 binaries. Compile failures reject copied
C++ runners and a boolean passed to a typed u64 state key. Native-version overrides
reject before codec/frame use. Allocation enumeration remains the shared native
proof; this C/C++ consumer does not inject a host allocator failure.

`nix develop .#bindings -c just bindings::java-sdk-test` builds independent Java
client/native JARs with POM dependency manifests and installs only those JARs plus
pinned Gson into an external consumer. Strict Java 21 compilation precedes the
shared raw authority schedule. The proof covers typed bounds, copied buffers,
native metadata, lost accepted responses, exact seedless recovery and revoked
retry. Cancelling both dispatch and a close-future view preserves owned work;
joined cleanup retains the accepted receipt while the controller remains
responsive. Missing/mismatched native JARs, ABI-version overrides, malformed
status, duplicate JSON members, invalid UTF-8, oversized lines and partial output
are rejected. No Station JAR is installed in the raw proof.
The Java artifacts require the Nix runtime closure; Maven resolution/publication,
portable Linux artifacts and JVM allocation-failure injection are not qualified.

The same task installs Java Station/native/example JARs and strictly compiles a
consumer outside the checkout. Its shared runner proof covers all mutation hooks,
exceptions and `Error` callbacks, reentrant/wrong-thread/expired scope rejection,
stop/cancel/join with retained commitment, malformed ingress, caught poisoned
reads, stale ownership, expiry, revoked access and exact recovery after host,
node and disk-provider restart. Both actual counter CLI roles run; full u64 values
survive restart. Typed compile failures reject boolean values for u64 KV keys and
int64 Tables. Six-page retained Tables and six owned IPC segments remain valid
after disposal and are independently decoded with PyArrow; no optional Java Arrow
adapter is selected. ABI/native-artifact and mismatched public-client versions
reject before handler work. Status validation uses each generated ABI's range,
including Station's stale/not-ready/budget statuses. Full-width values are exact
`BigInteger`/`long`, with no floating-point conversion at the public boundary.

`nix develop .#bindings -c just bindings::dotnet-sdk-test` packs independent
`Transit.Client` and `Transit.Native.Client` NuGet artifacts, restores them from
an isolated local feed into an external .NET 8 consumer, and deletes build source
and package caches before execution. No Station package is installed. The shared
raw schedule checks typed bounds, copied payload/export bytes, native metadata,
lost accepted responses, exact seedless recovery and revoked retry. Cancelled
dispatch/close awaits preserve owned native work and the accepted receipt while
the caller stays responsive. Missing artifacts, ABI mismatches and closed handles
reject explicitly; credential-read errors omit private paths. Native calls and
destruction use one owned 8 MiB thread. Portable Linux packages, NuGet.org
publication and CLR allocation-failure injection are not qualified.

The same task independently restores Station/native/example NuGet packages,
compiles typed consumers with warnings as errors, rejects mismatched state/Table
value types, and runs the shared runner schedule. Every mutation persistence and
confirmation hook fails once without rerunning the handler. Both handler failure
policies, expired/wrong-thread/reentrant scopes, poisoned reads, fencing, expiry,
revocation, cancellation/stop/join and exact seedless disk recovery are covered.
`async void` handlers and persistence hooks reject before activation work. The
installed counter executable resumes a durable requester; Table/query handlers
verify bounded pages, retained revisions, nullable signed extremes and complete
provenance. Six owned original IPC segments survive disposal and are decoded by
independent PyArrow; no optional .NET Arrow adapter is selected. Generated-schema
checks reject absent nullable fields, invalid cursors, fractions and oversized
exponents. Native package/ABI checks precede use; SDKs require exact 0.2.0 peers.

`nix develop .#bindings -c just bindings::beam-sdk-test` builds standard OTP
applications with separate Erlang core, Elixir wrapper and native dependencies.
External consumers install only these raw packages through `ERL_LIBS`; the Erlang
consumer compiles with warnings as errors and no Elixir/Station dependency.
Both languages pass the shared typed/raw schedule: native classification, exact
seedless retry, rejected non-send/noncanonical material, caller/task death during
accepted I/O, responsive joined cleanup with retained receipts, and revoked
retry. The admission proof distinguishes a dead unpublished reservation from an
active worker-owned job. Supervisor start/handle/close and parent termination
join native cleanup. Missing artifacts, native/package/SDK version mismatches,
malformed/duplicate/fractional/oversized/partial/invalid-UTF-8 responses and closed
handles reject. Boundaries use generated schemas and binary JSON keys. Native
shutdown acknowledgement precedes successful child exit; no cancellation is
inferred from local task death. Rebar/Mix registry resolution, Hex publication,
portable artifacts and BEAM allocation-failure injection are not qualified.
The public Station schedule also installs independent Station/native/example
applications and runs both language APIs through the shared authority schedule.
A common Erlang test controller drives adapters using the public Erlang records
and Elixir structs/behaviours; both real language counter CLIs run from installed
artifacts. It covers full-width codecs, all three mutation gates, retained
confirmation, callback throw/exit failures, scoped owner/reentry checks, sticky
read failures, caller kill/stop/join, exact seedless disk recovery, stale/revoked/
expired authority, retained Tables and six owned IPC segments after close.
Original segments are independently decoded with PyArrow; no BEAM Arrow adapter
is selected. Sources are removed after consumer compilation. The builder derives
application metadata from each `.app.src` or Mix manifest.

### Public SDK interoperability

`nix develop .#bindings -c just bindings::sdk-interop` builds all public artifacts,
installs clean external consumers and runs ten counter/query pairs. Every target
is both service and requester in this ring:

`Python → Node/TypeScript → Rust → Ruby → C → C++ → Java → .NET → Erlang → Elixir → Python`.

Each counter path uses the installed documented CLI and a direct authority base
URL with a trailing slash. Fault proxies also preserve the original HTTP request
target, so they cannot mask an incorrectly joined route. The requester exits after
recording its call, reacquires ownership and resumes through a recorded reply of
`18446744073709551615`. Table/query paths use the same public proof adapters around
installed example handlers, restart the requester, and expose original complete
IPC after closing both runners. Independent PyArrow checks three rows containing
null, `i64::MIN`, `i64::MAX` and `9007199254740993`, plus source/destination,
resource and byte-count metadata. The ring does not select optional host Arrow
adapters; those remain in the separate six-segment per-SDK schedules. It covers
ten edges, not all 100 ordered pairs, and does not repeat each fault for each pair.
`public-language-ring` in the [SDK catalog](../../../tests/sdk/sdk.json) owns the exact
observations. M9's separate low-level matrix remains executable and passed again.

All artifacts below are version 0.2.0 on Linux x86_64 with their pinned Nix native
closure; the [runtime table](../../../bindings/README.md#build-and-verification) owns exact
compiler/runtime versions.

| Public target      | Installed artifact                                                        | Optional host Arrow adapter |
| ------------------ | ------------------------------------------------------------------------- | --------------------------- |
| Python             | Separate client/Station/native wheels and examples wheel                  | PyArrow 23                  |
| Node.js/TypeScript | Separate public/native npm tarballs and examples package                  | Arrow JavaScript 21.2       |
| Rust               | Versioned crates with separate embedded-native crates and examples        | Arrow Rust 59               |
| Ruby               | Separate client/Station/native gems and examples gem                      | None                        |
| C/C++              | Independent pkg-config prefixes, headers/libraries and C11/C++17 binaries | None                        |
| Java               | Independent client/Station/native/example JARs and POM manifests          | None                        |
| .NET               | Independent client/Station/native/example NuGet packages                  | None                        |
| Erlang/Elixir      | Separate compiled OTP core/wrapper/native/example applications            | None                        |

Public registry publication, Java Maven resolution, BEAM Hex/Rebar/Mix registry
resolution, portable native distributions and foreign Substrate workers are
not qualified. Package guides document current low-level escape hatches and
migration. These tests do not qualify arbitrary callback honesty or I/O isolation.

The [2026-09-26 local record](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m11-sdk-2026-09-26.json) measured
**3m58.7s** for clean consumer installation and the complete ring,
including 56.8s of installation/consumer compilation.
The authority ran on one CPU; provisioning used the same five-second deadline
as the authority and SDK defaults. The record includes per-pair timing, machine scope,
SDK source revision and proof-source hashes. It excludes artifact builds, other
SDK failure suites, setup and cache transfer, so it is not a full CI measurement.
The `bindings` lane now owns the per-SDK tasks and this public ring. M10's hosted
budgets remain unchanged; their old passing samples do not qualify M11's larger
inventory. New hosted cost measurement and runner optimization remain deferred.

### Local and clean verification

Enter `nix develop` and run `just transit-board::install` at the repository root. `just ci` runs the ordinary local
suite. Capacity and reference proofs have extra prerequisites and are separate.

`just check` includes Board contract/validator drift and frontend formatting,
lint, types and unit tests, even for changes made only to shared Zig types or
frontend Markdown. Regenerate deliberately with `just transit-board::generate`;
use `just fmt` to fix formatting.

Before pushing committed work, run `just ci-clean`. It refuses uncommitted source
changes, clones the exact HEAD into a temporary directory, installs the locked
frontend dependencies, and runs the same core/growth/experience/launchers/bindings
task inventory as hosted CI. It inherits the
Nix store and global compiler caches, but no checkout build outputs, launcher
state, dotenv file or `node_modules`. Successful runs remove the temporary clone;
timing/completion evidence survives under `.cache/ci/clean/`;
failed runs retain it for diagnosis and print its location. The local launcher proof must use its
selected artifacts; a binary left in the developer's `zig-out` cannot mask an
undeclared dependency. Compose explicitly builds a native caller for its
host-side stale-credential check. The browser proof remains a separate
`just transit-board::browser` step, as it is in hosted CI; neither command
qualifies the separate reference or physical-capacity profiles.

`just ci-clean --lane NAME` qualifies one inventory lane in its own fresh clone
with the pinned binding toolchain. Independent invocations may run concurrently
without sharing checkout outputs. A passing lane is partial evidence: the ordinary
clean gate requires completed metadata and every expected task for core, growth,
experience, launchers and bindings at the **same committed revision**. Retain all
five reports; do not combine different revisions or count an interrupted lane.
This changes neither hosted lane allocation nor the M10 feedback/cost budgets.

Use `just ci::complete` or `just ci-clean --complete` to include Chromium in the
same invocation after `just transit-board::browser-install`. `just test::unit`
only runs library/protocol tests; `just test::build` separately compiles the
application and probe entry points formerly hidden in that unit target. Core CI
runs both and retains standalone package checks.

| Evidence                                                                                                      | What it proves                                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just check`, `just test::packages`                                                                           | Independent package composition; signed requests/current grants; one conditional successor; ordered input, invalid proposals and blocked failures; runtime fencing; bounded clocks, settlement, closure and outboxes; shared valid/invalid JSON traces and bounded view encoding                                           |
| `just test::callers`, `just contract::check`                                                                  | Runnable counter and byte-log examples use the same generic node; opaque bytes, state revisions, atomic outputs, denied effects, lost commit responses, ownership replacement and restart recovery; generated schema matches public types                                                                                  |
| `just test::storage`                                                                                          | Disk WAL SIGKILL/restart; competing authorities, lost receipts and revoked grants; 100 inputs beyond the 16-record window; checkpoint/trim with pending effect/outbox/control evidence; live authority catch-up; immutable payload deletion after a lost receipt; native long-poll/offset continuation                     |
| `just test::state`                                                                                            | Signed KV/association reads, current independent grants, immutable read views, exact retry, two Zig caller activations, disk recovery, and clock-independent opted-in background reclamation                                                                                                                               |
| `just test::service`                                                                                          | Real signed ingress/read revocation/key renewal, request deadlines and paused-worker fencing; Python/Zig wire vectors; actual-clock background expiry/trim; synthetic external I/O with paused dispatch, late results, unknown closure and no replay sends; background payload deletion preserving default-retention bytes |
| `just test::capacity`                                                                                         | Real ENOSPC on an owned ext4 image; release of preallocated control space; closed admissions, preserved/drained backlog, revocation/expiry/closure/checkpoint and restart; completed maintenance issues no further storage mutations                                                                                       |
| `just test::deployments`                                                                                      | Rendered/linted Transit Helm chart; explicit bootstrap, existing credential references, retained/reused PVCs, private services and network policies; unsupported values fail before deployment                                                                                                                             |
| `just launchers::reference::infra-up`, `just launchers::reference::images`, `just launchers::reference::test` | Real provider setup; controller crash after creation; backlog wakeup, killed worker and fresh activation; Ursula/authority pod restart; opted-in expiry; blocked overflow stops replacement; gVisor egress/credential bypass denials                                                                                       |
| `just test::runtime-upgrade`, `just launchers::reference::test-launcher`                                      | Fenced same-PID workload changes, provider response loss, complete persistent reference startup, isolated service updates and state-preserving stop/start                                                                                                                                                                  |

The capacity proof uses a finite allocation and a measured physical reserve;
online expansion and arbitrary write amplification are not promised. Retention
policies are immutable in M1. Checkpoint/trim requires quiescent or explicitly
cancelled mailboxes; pending effect/outbox metadata survives in the checkpoint.
Payload deletion is limited to closed standalone bytes with explicit opt-in and
an unlimited-lifetime owner. Unsupported finite body/dependency contracts fail
before admission. Full compaction, live dependency graphs and backup import
remain later work.

The trusted Linux time source reports synchronization/error bounds; acceptance
uses a validated sample at the compared journal tail, not physical append time.
An authorized external send may occur after closure; its result cannot reopen
Transit. Ursula cursors are cache tokens separate from read positions. The client
model is fixed and continuation verified; the server documentation mismatch is
tracked in [Ursula #317](https://github.com/tonbo-io/ursula/issues/317). This profile
uses verified record positions/offsets and never reuses physical names.
A rolled-back whole-store backup is not an authorized live restore.

Hosted CI runs `just ci::core`, `just ci::experience` and `just ci::bindings`
in parallel, then `just ci::browser` in the experience lane. Locally, `just ci`
loads the pinned bindings tools, runs all three sequentially and records timings
in `.cache/ci/`. The
[toolchain guide](../../../nix/README.md#ci-lanes) explains cache ownership and the
smaller experience shell. A weekly/on-demand dedicated runner workflow exposes the
reference and physical-capacity proofs. Local runs supply the current runtime
evidence. A passing hosted end-to-end timing and native validation on the other M0
platforms still require their own runners/runs.

Integration tests use Nix-provided Python, temporary directories, and loopback
ports with their own disk Ursula; they never use an existing deployment.
Toolchain smoke checks verify binary execution and first-use Vite+ setup, not
cluster conformance. See the [command reference](../../../tasks/README.md) for all tasks.

On Linux, `just test::service` limits the harness and its child processes to one
available CPU. This exercises deadline cancellation without spare async workers,
including slow ingress, stalled protocol responses and maintenance storage I/O.
The affinity change is confined to the test process tree; compilation and the
parent shell retain their existing CPU allocation.

The Station ABI portion of `just bindings::native` / `just bindings::test` also
runs on one CPU on Linux, restoring affinity before the remaining language
matrix. It exercises back-to-back exact raw-client retries and Station polling
with bounded native pools. Client unit tests inject unavailable concurrency at
either scheduling slot: transient contention recovers, persistent contention
hits the original deadline, and transport failure is never retried. Those
deterministic tests run in `just test::unit` and therefore `just check`.

The synthetic effect harness sets `NO_COLOR=1` for captured child logs so exact
error checks work under interactive and forced-color builds too. Its rejection
checks also verify the durable effect state, mailbox counts, and remote sends.

## Extending the proof

The M1 mechanisms above now have concrete implementations and adversarial
results. Extending them to general behaviors, connectors or another storage/
runtime profile requires preserving these contracts and adding its own evidence.
A failed proof requires revising the owning design, not relabeling a weaker
implementation as conformant. The client cursor-model bug and separate upstream
documentation mismatch are recorded in the [backend README](../../../packages/zig/transit-backend-ursula/docs/upstream.md#client-integration-surface). The corrected
client proof verifies offset-plus-cursor and record-plus-cursor continuation;
Transit's journal reads use record positions.

## Recording new evidence

Record tested pins, topology, failure boundary, authoritative operation point,
input schedule, and durable outcomes. A workflow definition is not evidence of
a remote run. The [reference runbook](../../../deploy/reference/README.md) records its
runner requirements and owned-resource cleanup. Keep synthetic endpoints, test
keys, transcripts, and private proof files out of Git.

Benchmarks record compiler/tool versions, hardware, dataset, concurrency,
durability settings, and p50/p95/p99 latency together with throughput and memory.
A failed proof requires revising the owning design, not weakening its label.

## M10 verification and scale foundations

The [2026-09-25 growth evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m10-scale-2026-09-25.json)
records **14 passing samples**: two each at 64/256/1,024 rows with one resident
page, 256 rows with 16 pages, eight retained views, and two public-service offered
loads. All use real Ursula WAL plus pinned MinIO on the checkout's ext4 filesystem,
on a shared Linux x86_64 Threadripper 3960X host (48 logical CPUs, about 121 GiB
RAM), Zig `0.17.0-dev.2267+48abf1a34` and Ursula 0.5.1. Each sample records actual
binary hashes, revision/dirty state and timing boundaries. Six cases ran through
`just test::scale`; the added eight-view case ran twice separately before joining
the executable matrix. These are shared-host observations, not production SLOs.

| Rows / cache pages / retained views | Write plus verification, seconds | Turn p99, ms | Full recovery verification, seconds | Maximum authority-driver RSS, KiB |
| ----------------------------------- | -------------------------------: | -----------: | ----------------------------------: | --------------------------------: |
| 64 / 1 / 1                          |                      54.86–57.31 |      952–978 |                           4.21–4.58 |                            12,596 |
| 256 / 1 / 1                         |                    109.01–113.49 |    984–1,013 |                         14.33–15.19 |                            12,596 |
| 1,024 / 1 / 1                       |                    366.91–366.94 |  1,166–1,315 |                         61.64–62.37 |                            12,660 |
| 256 / 16 / 1                        |                      85.31–86.17 |      825–839 |                         11.77–12.05 |                            12,720 |
| 256 / 16 / 8                        |                      91.08–92.72 |    780–1,792 |                         15.66–15.89 |                            12,744 |

The one-page cache remains **8,532 bytes** while retained application values grow
from 16 to 256 KiB, alongside 70 PIDs, 21 principals, six resources and 69
associations. The eight-view driver also checks every retained association after
restart; its timing difference is not solely view-count cost. At 1,024 rows,
engine opening took 1.04–1.06s on first recovery; checkpoint publication took
107–109ms, separately from full verification. Recovery/trim created zero pages.
Ursula peaked around 95 MiB and MinIO around 327 MiB. Write/setup/verification
made 289,558 page requests and attempted 45.09 MB of immutable page payloads,
retaining about 47 MB in cold files. These costs expose substantial index/history
and request amplification despite the fixed authority cache.

Each offered-load run scheduled 48 independent signed requests, then verified
exact retries, control revocation, every drained row and restart digests. With
16-byte uniform updates, one generator worker and 100ms offer intervals, p99 was
3.28–3.42s and control latency 208–238ms. With 256-byte updates, 90% hot-key
selection, four workers and 1ms intervals, p99 was 9.11–9.73s and control latency
805–880ms. All requests were admitted; accepted backlog survived provider/node
loss. Generator queueing is included in latency and was substantial; these
finite bursts do not establish service capacity. Both load cases and all
four authority phases retain process/provider metrics and correctness evidence.
A preceding setup attempt timed out during severe host I/O contention and remains
inconclusive; it is not included in the passing sample count. Two repeats do not
establish stable performance-regression tolerances or cold-run tail guarantees.

`just test::arrow` also qualifies Fuze's incremental engine independently of
Station persistence. Python checks the typed plan fingerprint and 143-byte
progress format; PyArrow decodes variable-sized segments across 70 rows. The
text result totals 16,008 bytes in seven complete IPC segments. Global limits,
count/sum, nulls and exact integers agree across boundaries. Package/root unit
tests additionally reject changed basis/plan/order, signed intermediate overflow,
insufficient workspace/output and cancellation without publishing progress.
This does not qualify durable large-result staging, delivery or recovery; those
remain integration gates in the [incremental contract](https://github.com/spoke-sh/transit/blob/c5ac253365ba7dfa136cc4dadf99ba0c21570af1/contracts/FUZE_STREAM_V1.md).

`just test::query` (also part of `test::growing-service`) separately
qualifies durable **capture**. Real Zig callers retain a 41-row Table, stage
221-byte fragments, and recover through disk Ursula/node/caller replacement
first during staging, then after the first seal. The first recovery uses one
resident backend page; the remaining capture defaults to 64. Use
`just test::query --finish-pages 1` to retain one page throughout both
recoveries. The proxy loses an accepted staging reply and a seal reply; exact
retry returns the original receipt without rerunning a handler. Each recovered
segment is decoded by independent PyArrow, and Python checks the ordered digest
chain: 41 rows, 9,984 bytes in six segments. The source is released with the final
seal and rejects later reads. The requester's wait is still waiting: capture is
not delivery or acknowledgement. In-memory tests add 70-row private capture,
changed staging, duplicate/future/forged continuation, policy revocation, sticky
read failure, explicit closure and corrupt/missing fragments.

Growing result **delivery** now has both in-memory and real disk/service
qualification. `query_growing_test.zig` drives two independent in-memory
`Store` fixtures as separate producer and receiver peers exchanging real
`QueryDelivery.dispatch` frames through an explicit message queue, matching
the wire protocol rather than calling capture and delivery in the same
process. One run publishes and independently decodes 41 rows across six
segments end to end, closing exactly once before acknowledgement despite a
duplicated fragment redelivery, a forged reply source, and a closed wait
staying closed against a late corrupted resend. A second, focused test rejects
out-of-order/conflicting/premature evidence (`UnorderedResultFragment`,
`ConflictingResultFragment`, `ConflictingResultIdentity`, `IncompleteResult`,
`InvalidArrowResult`) without ever closing the receiver's wait, and checks
cancellation mid-dispatch. `Inspect.segment`
(`packages/zig/transit-fuze/src/Inspect.zig`) independently validates every
received Arrow segment — bounded allocation, schema/row/cell bounds, UTF-8 and
nullability — before its fingerprint enters the chain; it is exercised
separately in `inspect_test.zig`.

`just test::query` now adds `publish` and `deliver` phases to its
existing real disk Ursula/node proof, driving two separate `GenServer.Growing`
instances (sender and receiver) that each explicitly configure
`.query = .{ .workspace, .cancellation }` — the growing GenServer still
rejects these frames by default; nothing wires this in a production host yet.
The proxy loses an accepted publish reply and a receive reply in addition to
the existing stage/seal faults; exact retry recovers all four without
rerunning a handler or reopening released source rows. It also cancels the
sender mid-submit while an authority outcome is uncertain and confirms the
uncertain mutation is retained, not discarded. Independent PyArrow decodes
every segment the receiver durably stored and diffs it byte-for-byte against
the sender's own captured segment, and Python checks the received manifest's
basis/plan/chain/schema against the sender's. One run: 41 rows/9,984 bytes in
six segments; publish took 3.99s and deliver 69.36s on this one-CPU Debug
sample, on top of the existing 8.30s/10.24s/18.14s write/seal/recover. Six
segments against a two-segment credit window means the sender genuinely blocks
and resumes under real cross-process delay here, not just in the in-memory
proof below; these are finite shared-host proof timings, not service SLOs.

Receiver-issued credit (`GQG1`, [`contracts/STATION_QUERY_V1.md`](../../../contracts/STATION_QUERY_V1.md#flow-control))
is implemented, not just designed: the sender will not start a segment more
than `credit_window` (2) ordinals past the last credit it has observed, the
destination grants credit only for segments it has itself durably sealed, and
a regressing or forged grant is rejected rather than tolerated.
`query_growing_test.zig` qualifies this in-memory — a forged-peer grant is
rejected, a regressing grant errors, a repeated or post-completion grant is
inert, and the two-sided delivery proof asserts exactly one grant per sealed
segment (six, for six segments). [`Delivery.tla`](../../../tests/verification/models/Delivery.tla)
checks the same shape abstractly via `just test::model-delivery`; it is not
yet wired to a Zig trace replay the way `test::model` is for `Authority.tla`.
`just test::query --finish-pages 1` retains one resident page through
the seal/recover phases instead of the 64-page default measured above; the
first recovery (after staging, before any seal) always uses one page and no
faults or assertions are removed either way. These are finite shared-host
proof timings, not service SLOs or hosted Nix/CI budgets.

The [verification guide](../../../tests/verification/README.md) owns the versioned inventory,
bound audit and generated transition harness. `just test::properties` checks the
real Zig authority against an independent mailbox/fencing/retry projection,
including replay after every step and bounded failure minimization. The initial
21-trace corpus/generation run passed 826 boundaries in 8.46 seconds on this host.
That measures the harness, not service throughput or exhaustive exploration.
The captured-view extension passed 39 saved/generated traces with 1,682
boundaries in 18.91 seconds on this host. It additionally compares atomic KV/input
publication, view release/expiry, clock rollback/uncertainty and current resource
rights. These finite in-memory schedules preserve the real disk and host checks.
The larger run passed 263 traces / 33,250 boundaries in 475.97 seconds. At
`ea62354`, all four compiling guard mutants were detected, with minimized
counterexamples retained by the mutation task.

The [shared SDK scenario contract](../../../tests/sdk/sdk.json) now has executable
owners for admission/commit/reply distinctions, same-principal multi-handle
contention, host-loss retry, durable continuation, decode failure, local await
cancellation/disposal and response allocation after commitment.
`just test::client-abi` passed its disk-backed contention and boundary checks;
`just bindings::test` passed the shared host cases and continuation observations
through every existing language pair. Malformed framework input becomes durably
blocked without being consumed. Public M11 SDKs must reuse these scenarios
through their own interfaces; the current matrix qualifies low-level bindings.

M10 is qualified within the [recorded limits](../../../tests/verification/README.md).
CI separates library unit tests from
application/probe builds, avoid duplicate feature-push/PR runs, and select
runtime checks conservatively. Standalone package manifests are compile-checked
with `test::packages-build`; root unit tests own their shared runtime suites, and
`test::compute` separately owns the upstream compute tests. Focused
`test::packages` remains a complete standalone run. `tests/ci_runner.py` exercises actual Git rename/
delete selection, missing revisions, failure propagation and all combinations
of aggregate-gate results. Unknown/shared changes remain full; only foundational
prose-only PRs omit runtime lanes. Main, release tags and merge queues run full.

`just ci::complete` includes Chromium, and `just ci-clean --complete` uses that
inventory on committed HEAD. Each lane records required tasks, completion and
revision beside task timings; successful clean runs preserve these outside the
disposable checkout. Hosted CI budgets and growing-state qualification have
separate measured evidence below; local timings do not qualify massive scale.

The initial M10 model also passed 30,140 states with a four-transition journal
bound and replayed all four removed-guard counterexamples against Zig. The first
CI optimization commit (`b9dd595`) passed `just ci-clean --complete`, including
all language bindings and five Chromium checks; timing and completion metadata
survive under `.cache/ci/clean/b9dd595faade-transit-ci-7c3pzmzd/`.

`just test::pages` qualifies the immutable page primitive with disk-backed Ursula,
cold bounded caches, old roots, unpublished staging and root-only checkpoint/trim.
`just test::pages-cold` separately exercises the pinned S3-compatible cold tier
with owned Docker MinIO and measures both provider processes. The ordinary WAL
fixture disables that tier; it cannot establish bounded provider memory.
The [adapter guide](../../../packages/zig/transit-backend-ursula/docs/pages.md) describes
measurement fields and their limits. The launcher-default v2 authority retains
bounded catalogs; the explicit v3 authority uses these paged roots. Unit checks also compare randomly ordered updates
and deletion against an independent map and preserve old roots after lost staging
acknowledgements.

The initial [growing authority tests](../../../packages/zig/transit-core/docs/growing.md)
also cross the legacy process/principal catalogs and retain historical receipts
in immutable pages. They qualify the implemented control transitions against an
injected conditional journal, including lost acknowledgements and stale prepared
roots. State checks also publish rows, input progress and outputs together,
reject staged partial proposals and fence expired required dependencies. Signed
read checks cover bounded current/captured pages, current permissions, stale
ownership/cuts, expiry and hidden association filtering. These engine checks
use injected storage; delivery/settlement also have injected-storage checks.
Station integration has separate service evidence below. Launcher defaults
continue to use v2; each explicitly configured growing capability has its own
proof owner.

An explicit control reserve now has injected-storage evidence too
(`GROWTH-11`, [growing capacity](../../../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity)):
past a configured ceiling, sends/spawns/grants/new resources/views/associations
and turns that would emit a new output or effect are refused before
acknowledgement, while ownership reassignment, revocation, retry, termination,
delivery, effect observation/closure, an opted-in checkpoint and output-free
turns keep draining and closing existing work through an explicit reserve band
— until even that is exhausted and every command is refused. A restarted
engine recovers the identical ceiling and reserve state. The signed
`capabilities` query now returns `admission_ceiling` and `control_reserve`
alongside every response's own `position`, checked at three points in the
same test (before, at the ceiling, and past the exhausted reserve) so a
caller can compute remaining headroom directly rather than discovering it by
provoking `AdmissionClosed`/`ControlCapacity`. This qualifies the admission
mechanism and its observability. The additional
[physical-capacity and service/Station proofs](#growing-physical-capacity)
qualify the finite deployment profile separately.

`just test::growing` runs the growing core against real Ursula and a single-page
Transit cache. It crosses legacy process/principal/resource/row bounds, stages
private candidates, rejects stale publication after revocation, injects failure
before append and response loss after real acceptance, and verifies retained
views/receipts/progress/outboxes across SIGKILL. Opted-in root checkpoint/trim
retains all that state and rejects an uncommitted retention intent. It finally
removes page storage in its disposable fixture to prove recovery fails closed.
The [adapter guide](../../../packages/zig/transit-backend-ursula/docs/growing.md) owns
measurement details and compatibility limits. This is authority/provider
qualification, not node/client/Station support or a scale SLO.

`just test::growing-service` runs an independent Zig caller using only
`transit-client` against the real v3 node, with disk Ursula on one CPU. It uses a
wide principal, six resources and 64 rows, reading individual captured keys and
bounded current pages. A malformed receipt after acceptance survives caller/node/
provider restart as the exact same signed request and receipt; current revocation
then denies both reads and that historical retry. The response validator also
rejects mixed realm/revision, page holes and invalid continuations while accepting
empty filtered catalog pages. No launcher, Station or foreign ABI changes profile
implicitly. Existing v2 ingress and observability proofs cover the shared loop.
The caller also inspects blocked metadata, uses a PID-scoped administrator to
retry the exact failed input and consumes it only after fresh ownership. Core
tests additionally race retry with revocation, recover a lost retry receipt,
reject stale repeated-failure generations, and preserve dependency expiry,
process deadlines and permanent retirement.

The [retained-version proof](../../../contracts/READ_VERSIONS_V1.md) adds an atomic
pre-write 60-row snapshot to the lost-reply turn. It reads current and retained
state after caller/node/provider restart, fences the old activation and explicitly
declares/releases the version from a replacement. Core checks cover missing
snapshot pages, filtered discovery, source expiry, release and grant changes
between reading and publication. The separate provider proof retains these roots
across actual checkpoint/trim/recovery; it preserves immutable page storage.

The task also runs two real [growing Station callers](../../../tests/runtime/application/growing_station.zig),
retaining 41 typed Table rows and completed calls without reclamation. A proxy
enforces point reads during handlers, corrupts a captured read and loses an
accepted turn reply. A swallowed read failure cannot publish its private work;
the accepted turn retries byte-for-byte without rerunning the handler. After
caller/node/provider restart, fresh ownership fences a prepared old turn and
recovers the unconsumed call without rerunning committed initialization. The
proof uses a bounded 64-page cache for exchange, one resident backend page
after restart, and explicit public-client delivery. It
does not qualify background courier, registries, supervision, runtime bindings
or foreign APIs. Separate query and quota proofs below own those
implemented capabilities.
After restart, the writer also reads all 41 Table rows in six typed pages before
committing its completion count. Continuations cannot change view, resource,
Table or schema; unit cases cover extreme keys, a neighboring Table, caught scan
failure and exclusion of private writes. This is paged state access, not yet
large-result capture or whole-query execution.

Run just this scenario with `just test::growing-station`. It also retains the
earlier 40-row source, commits one scan page plus a self-continuation, and loses
caller/node/provider again. A replacement continues from durable progress across
new handler views, finishes the same source in six pages total, and releases it
with the final count. Retained reads automatically become proposal dependencies.
This is an application-managed scan; it does not implement the Arrow result gate.

The caller now drives M11's separate `prepare`/`dispatchPending` methods. It
checks that repeated preparation preserves frozen work, discard rejects a pending
mutation, and successful dispatch exposes the same input identity and a positive
receipt. Native units cover permit/view/turn preparation with no usable I/O
client, stop without a failure marker and read poisoning under stop policy.
`just test::unit`, this disk recovery proof and the legacy `just test::station`
service/recovery/lifetime proofs passed after the change. Foreign persistence
callbacks and public SDK runner qualification are still separate work.

The same service task runs growing maintenance on one CPU with owned proxy
faults: kill after an accepted snapshot loses its reply, then restart from the
recorded trim intent; loss of an accepted immutable-page reply before root
publication; timeout after accepted physical trim; current maintenance
revocation and later regrant; node/provider/worker restart. Terminal-source work
is disposed without delivering to the destination, independent state and an
unresolved authorized attempt survive, and retained output bytes stay readable.
Core checks separately cover clock loss/uncertainty, bounded finite scan passes
under continuing admission, current control authorization and revalidation of
stale scan suggestions. These are not sweep-latency or full-store guarantees.

### Growing physical capacity

`just test::growing-capacity` uses the same owned Docker/ext4 fixture as the
legacy capacity proof, with the real v3 authority and disk Ursula. The declared
profile has 96 admission positions and a 96-position control reserve. One decoded
page (8,532 bytes) serves 40 retained 256-byte rows, retained receipts, accepted
backlog, a finite process and an unresolved authorized effect. Applications have
not opted into row/result reclamation; root-history trimming is explicitly enabled.

The 2 GiB filesystem preallocates a 1 GiB reserve. Filling the remainder triggers
real ENOSPC and Ursula's WAL pressure gate. A control publication then fails while
the authority stays at position 96 and all data and permissions remain intact.
Only the reserve file is released; the filler remains throughout control work
and restart. Revocation, opted-in expiry, effect closure, complete backlog drain
and root checkpoint/trim finish at position 154. SIGKILL/restart preserves every
row, exact historical receipt, retirement and closure. Repeated maintenance and
verification issue only GET/HEAD requests and stage no pages.

One local Debug run took 29.43 s for setup, 0.95 s under pressure, 31.55 s for
control/drain/checkpoint and 1.42 s for recovery/verification. Control work added
1,310,720 allocated WAL bytes while using 58 of the 96 reserved positions. These
are one finite workload's measurements, not a worst-case allocation formula,
production reserve recommendation or host-power-loss proof. The node does not
provision physical headroom automatically. Evidence is written to
`.cache/growing-capacity-evidence.json`; the legacy task retains its own artifact.
The dedicated reference workflow runs both proofs and preserves their metadata.

`just test::growing-quota`, also included in `test::growing-service`, uses the real
node and Station on one CPU with one resident page, a 24-position ceiling and four
control positions. A previously captured output-free handler turn commits after
admission closes. Opening a view for the next input is refused, and the host
retains its exact signed proposal. Caller/node/provider replacement preserves
15 admitted inputs, one consumption and zero cancellations. The same request
still receives `AdmissionClosed`; authorized revocations exhaust the reserve,
after which a new control operation receives `ControlCapacity`. Current rights
still govern retry disclosure. Reads confirm the same retained data and backlog.

## M23 and M24 final clean qualification

The final implementation and proof harnesses at **`21089bb654f0`** pass all
**59 ordinary CI tasks** through `just ci-clean --lane NAME`, with one fresh
checkout per lane. Every completion report names that same full revision;
expected task lists, task order, unique coverage and zero exit codes were checked
against its committed `suite.json`. All five invocations exited successfully.
The [retained report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/m23-m24-clean-2026-09-28.json) includes
task timings, machine information and the original local evidence directories.

| Lane       | Tasks | Local lane task time |
| ---------- | ----: | -------------------: |
| Core       |    17 |             385.38 s |
| Growth     |    18 |           1,970.07 s |
| Experience |     6 |             341.32 s |
| Launchers  |     2 |             312.88 s |
| Bindings   |    16 |           3,943.77 s |

Lanes ran concurrently on one local machine, with tasks sequential within each
lane. Times exclude clone/dependency installation; their 6,953.42-second sum is
aggregate local lane time, not PR feedback or a hosted runner-minute measurement.
The bindings lane includes every installed SDK, the ten-language public ring,
model checks, SQL qualification and RPC fault recovery. The ordinary gate does
not include the complete browser tier: M23 application/placement/browser and
M24 Table/KV/Document terminal/TLS/server/capacity proofs are recorded separately
above. No new hosted warm/cold budget, platform or production-scale claim follows.

The first isolated experience attempt at `3717c50` exposed an implicit evidence
directory dependency in `board_query.py`. The proof now creates its own parent
directory before writing the real wire fixture. The other four attempts were
interrupted so all final lanes could run the corrected revision; no processes
remained from those interrupted checkouts. They do not count as passing evidence.
The corrected full C/C++ SDK task also passed separately, and a pinned Ruff
`F823` scan of `tests/` found no further unbound-local fixture errors. Earlier
failed clean runs remain incomplete and are not included in the final report.

## Combined repository check after direct-owner retirement — 2026-10-24

`nix develop --command just check` completes after the independent Unified
fixtures were regenerated for the shared definition. The run includes core
units and contract/diagnostic checks, 96 CLI artifact/file cases, 193
server/console cases, console history, frontend formatting/types/unit tests and
the handbook production build. The earlier fixture-mismatch run remains a
failure. This is working-tree repository validation, not clean-checkout evidence
or a pass for the separately running resource-growth/reference schedules.

## Direct Follow reference qualification checkpoints — 2026-10-25

The direct-owner reference browser schedule remains unqualified at this
checkpoint. Placement now selects an explicit IPv4 Docker bridge, retries the
same signed native bytes within its existing ten-second recovery budget, and
recreates only its own failed port-forward on the same local port. Transient
non-JSON readiness replies remain within the existing readiness deadline.
Failure diagnostics retain bounded current/previous direct-node logs before
owned namespace cleanup. These fixture changes establish no runtime guarantee
on their own.

Earlier attempts exposed opaque intermediary 503 responses and an exhausted
native CAS reprepare response; the client and worker fixes have separate focused
evidence above. Attempt 9 kept both workers alive but exceeded the 120-second
browser handshake while preparing 19 sequential rows. The row-setup handshake
now allows the aggregate of the existing ten-second admission and 30-second
outcome budgets per row. Individual operation deadlines and browser result,
recovery, denial and memory assertions are unchanged. This is a finite correctness
schedule; increasing its aggregate setup budget is not performance evidence.

## Lifecycle qualification failures and phase diagnostics — 2026-10-25

The 139-resource named KV/Document schedule remains unqualified at this
checkpoint. An early setup attempted to reuse an owned writer and failed;
each later resource now has its own native writer. A one-page native-cache
attempt was interrupted, and a subsequent setup exceeded its 1,800-second
aggregate deadline. With the installed eight-page native cache, a further run
exceeded 3,600 seconds. Its last saved declaration targeted resource 139, but
the last periodic completion marker was 129. Neither that marker nor the saved
declaration proves all resources initialized or recovered. The direct catalog
still uses its 16-page cache with eight-entry leaves.

The setup helper also performed a complete directory/value readback before
returning. Setup and readback now have separate explicit phases: 3,600 seconds
for provisioning and per-resource typed reads, then 900 seconds each for the
complete readback before and after node SIGKILL/restart. The same original
receipt, saved bytes, all 139 values and bounded directory assertions remain.
Phase markers identify completed setup and each sixteen verified readback values.
No successful full schedule or latency target follows from this fixture change.

Reference Follow attempt 11 failed its first application mutation while an
owned clean-checkout run was also performing disk-heavy unit work. That clean
run was interrupted before any lane completed; neither run passed. Attempt 12
ran without that clean-checkout process and still exceeded the initial query's
180-second result deadline. This rules out treating the simultaneous clean run
as an established explanation for every placement failure.

Attempt 13 completed and fully verified the original 20-row query, recovered
the same result after physical service replacement, and prepared all eight
finite Follow captures. It then exceeded the unchanged 180-second refreshed
result deadline. The last observed refresh was admitted; workers continued
consuming inputs and the browser retained a frozen uncertain control through
capacity refusals. The run's counter visibility and physical recovery observations
were 15,140 ms and 57,888 ms respectively. These are partial observations from a
failed schedule, not a qualified reference deployment or performance comparison.

The browser now records bounded query and refresh phase changes. On failure it
also makes one bounded public status read for the selected finite query, without
activating, replacing or cancelling it. The next reference run retains the
existing deadlines, result identity/coverage, recovery and denial assertions.

## Clean-checkout packaging and maintenance repairs — 2026-10-25

The full working-tree `just check` passes after the direct-owner and Follow
changes, including contracts, diagnostics, Zig units, frontend checks and the
handbook build. A second full check also passes during packaging repair. These
checks do not replace the ordinary clean-checkout suite.

The clean run at `6aad68b1a` passed its first 14 core tasks, then failed
`bindings::runtime-boundary`: the Nix frontend-store hash still described the
workspace before the handbook moved out of `apps/`. Updating that fixed-output
hash exposed an obsolete `transit serve --help` install check. The current CLI
provides `server` and `console`; the obsolete assertion is removed, with both
supported command checks retained. No dependency version, lockfile or CLI alias
changes. An intervening packaging attempt was interrupted and is not a pass.

After the repair in `1db162d60`, `bindings::runtime-boundary` passes against the
actual Nix runtime and SQL gateway packages, checking their SDK-free source
boundary and installed executables. `just doctor` and the `transit-local` Nix
bundle build also pass. The bundle build does not establish server startup. The
subsequent clean core run at `81691d09d` passes this boundary again.

That core run later stops at `test::service`. Maintenance emitted three bounded
`MaintenanceTimeout` events, but the fixture searched for JSON fields while
standalone services used their text default. `c9935bc2c` explicitly selects JSON
and info logging for the fixture's children. Its original two-timeout assertion,
two-second operation deadline and eight-second observation window are unchanged.
The complete `test::service` then passes signed ingress, current/revoked reads,
fencing, expiry, checkpoint/trim, stalled storage, synthetic I/O, payload deletion
and disk recovery. The maintenance fixture separately passes with the parent
environment set to `LOG_FORMAT=text LOG_LEVEL=off`, demonstrating that its own
logging selection is effective. Applying that suppression to the entire service
suite first failed an unrelated log assertion before maintenance ran; that attempt
is not qualification of the fix.

The failed clean runs retain their incomplete reports and checkouts. Neither is
a completed core lane. The other isolated lanes continue qualifying the recorded
revision; complete ordinary qualification still requires all six lane reports at
one committed revision.

## Isolated lifecycle qualification after parallel-run failures — 2026-10-25

The clean growth lane at `46d42df84` passes its first ten tasks, including growing
service recovery and the local catalog. Direct Table provisioning and writes then
pass, but its aggregate `recover` subprocess exceeds the existing 180-second
deadline. `45b1c1209` adds progress messages after the seven recovery stages;
it changes no runtime behavior, deadline, cache, operation count or assertion.
The complete focused `just test::direct-table-service` passes with 1,418 typed
calls, a 64 KiB point row, actual `.tseg` bulk publication, full CRUD/DDL and
namespace evolution, retained reads/history, original receipts, current denial,
three restarts and explicit pin closure. Every original phase deadline remains
in force. The earlier timeout remains failed evidence.

Two overlapping `test::server-direct-tables` attempts report `SqlOutcomeUnknown`
during DDL with the query worker paused. Their supervisor logs record repeated
incomplete health observations and authority timeouts; one restarts the node and
joins the paused worker. After the remaining parallel clean jobs are interrupted
and joined, the same task passes alone with unchanged runtime behavior and
budgets. It covers direct CRUD/DDL and namespace lifecycle while the worker is
stopped, inert preparation, stale schema rejection, RESTRICT, conditional
outcomes, abrupt restart, deliberate default-Table deletion and name reuse.
The isolated result qualifies this schedule, not behavior under arbitrary
competing I/O or a latency target. The parallel failures are not relabeled as
successful recovery tests.

The server logging proof also passes alone after making its initial-readiness
assertion precise: before the first `accepting` observation, `unavailable` must
carry a reported cause. After confirmed readiness, loss of a health observation
can itself establish `unavailable`. Final confirmed readiness, cleared error,
current admission-pressure reporting and gateway replacement checks remain.

The launcher clean lane completes both tasks at `f2b7f6116`. The other interrupted
lanes do not complete; their partial reports include a 1,879.33-second Python SDK
pass at `46d42df84`. This collection spans revisions and does not establish
ordinary-suite completion. Final qualification runs the entire ordinary inventory
sequentially from one committed clean checkout; CPU headroom alone did not
establish independent disk latency for the earlier parallel schedules.

## Clean lifecycle growth budget failure — 2026-10-25

The complete sequential `just ci-clean` attempt at
`1d534f9523dfc574f8dfb514a61b8d9f2dff61f4` passes all 28 core tasks and the
first 19 growth tasks. The direct Table service passes 1,418 typed calls,
actual `.tseg` publication and every original recovery-phase deadline in
329.66 seconds. The catalog task then fails after 3,861.84 seconds: its named
resource initialization subprocess exceeds the 3,600-second aggregate budget.
The ordinary suite is incomplete; its later tasks do not run. Reports remain
in `/var/tmp/transit-ci-fjvml5gc/src/.cache/ci/`, with the retained command log
at `/var/tmp/transit-lifecycle-clean-ci-3.log`.

The last periodic completion marker verifies 129 initialized resources. A later
inspection observes the saved declaration for resource 134 and advancing native
receipts; it does not establish that declaration's completion or any later
resource. Full directory/value readback and SIGKILL/restart do not run. No
individual request timeout or failed value assertion is reported before the
aggregate timeout. This failed run does not replace the earlier complete
139-resource pass or qualify this source revision's full schedule.

A live process observation at resource 113 records about 31 minutes of node CPU
time and roughly 335 GB in `/proc/<pid>/io`'s `rchar`, while `read_bytes` is about
1 MB. `rchar` includes reads served from cache; it is not physical disk traffic.
This single observation identifies substantial repeated cached-read work, not a
controlled throughput benchmark or a complete bottleneck diagnosis. The growing
metadata cost remains part of the open performance qualification.

The fixture now gives provisioning and per-resource typed readback a 5,400-second
aggregate setup budget. Both complete before/after-replacement readbacks keep
their 900-second budgets. Each caller request retains its 30-second cap; the
eight native resident pages, sixteen direct pages, 139 initialized resources,
original receipts, saved bytes and every value assertion are unchanged. No
runtime or cache change is made. Extending this correctness observation budget
does not establish a pass or meet the failed one-hour setup window. Fresh
committed-source ordinary qualification remains required.

## Clean SDK schema projection failure and repair — 2026-10-25

At `ccf5387f35006a23f5459d0b3d959c134d9da917`, the isolated clean experience
lane completes all 13 tasks in 1,374.77 seconds. The bindings lane's first
attempt fails during Nix shell setup, before any task executes, because a
cached shell derivation is missing. Reevaluating that shell with the Nix
evaluation cache disabled restores it; the normal shell then opens. No pinned
dependency, compiler or lockfile changes.

The fresh bindings retry passes native contracts and the full Python, Node,
Rust and Ruby schedules, then fails in `bindings::sdk-interop` while installing
the Elixir consumer. Its existing handler schema round-trip assertion exposes
an adapter bug: the catalog converter matches a four-element logical-element
tuple, while the shared Erlang record contains three elements. Nested list
descriptors therefore retain an Erlang tuple instead of the public Elixir
`Logical.Element` struct. The interoperability exchange does not run after this
installation failure, and the lane is incomplete.

The unchanged installed-artifact logical proof reproduces the failure with
the failed checkout's artifacts. Correcting the tuple match makes
`just bindings::logical-beam` pass after rebuilding independent OTP artifacts.
The existing schema test now checks nested list, array, map and structure
round trips as well as saved Table mutations. Elixir format checks pass.
The correction changes host value projection, not the shared wire definition,
storage formats or runtime authority. The full interoperability schedule and
remaining clean qualification are still required.

## Native Linux CI library and loader selection — 2026-10-25

Hosted run [40241628332](https://github.com/spoke-sh/transit/actions/runs/40241628332)
at `c4c5e75359dc211f1dfebb32e065e1a05d305326` fails the core CLI diagnostic
task because Nix shared libraries require glibc symbols absent from the host
Ubuntu libc. Experience and launchers separately fail to find OpenSSL while
linking. The local core lane also fails Station: its original attempt exhausts
the authority-availability retry during resource association, and an unchanged
retry later exhausts the query-upload wait after SELECT revocation. Neither
Station attempt passes; the loader findings do not establish their causes.

The default and CI shells now supply explicit OpenSSL/libc build dependencies
and the native Linux Zig launcher selects the matching Nix ELF interpreter.
An offline OpenSSL consumer reproduces a second defect with that explicit path:
the pinned build runner passes a dangling slice from a temporary target query,
emitting an empty or corrupted loader argument and crashing compilation.
The version-asserted helper patch copies those argument bytes into its arena.
The upstream compiler executable remains byte-identical, and no lockfile input
or library version changes. Nix cache keys include the helper patches.

With the correction, `nix flake check` passes on Linux x86_64. Its offline proof
builds and runs the OpenSSL consumer through both direct compilation and the
build runner, verifies their exact Nix interpreter paths, and verifies explicit
caller loader overrides without executing those deliberately non-runnable
artifacts. Other configured systems are not executed by this check.
`nix develop .#ci-experience --command just test::cli-diagnostics` passes all
96 helper and 193 CLI cases. `nix develop --command just doctor`, workflow lint
and documentation link checks pass. Complete committed-source and hosted lanes
remain separate qualification gates.

## Local WAL model and recovery barriers — 2026-10-26

Source basis: WAL traversal commit `0eea3cc1`, rebased onto main `b65546ff`,
followed by the recovery barriers and finite model in this change. Run
`nix develop --command just test::wal-model`. The locked TLC 2.19 exhausts
**201,771 distinct states**, with an empty queue, at two LSNs and two values of
each epoch. One worker, fingerprint/seed `0`/`1`, a 512 MiB heap and a 60-second
per-configuration timeout are used. Six independent removed obligations produce
their required invariant violation and complete explicit counterexample:

| Removed obligation | Detected invariant |
| --- | --- |
| Append file sync | `PublishedHistory` |
| Writer/policy epoch admission | `AppendFenced` |
| Floor publication before deletion | `DeletionAuthorized` |
| Repeated-floor physical cleanup | `TrimComplete` |
| Recovered complete-frame sync | `PublishedHistory` |
| Recovered directory sync | `PublishedHistory` |

The [model guide](../../../tests/verification/models/README.md#finite-local-wal-model) defines
assumptions, state abstraction and exclusions. The runner retains source hashes,
configurations, logs, counterexamples and completion evidence under
`.cache/verification/wal-model/`; parser/tool errors, timeout or incomplete
exploration cannot pass. The ordinary bindings lane owns the task. This is a
finite safety result, not a Zig refinement proof, liveness theorem or experiment
on actual host power loss. Counterexamples are not automatically replayed into
production code.

The initial model reproduced a missing recovery barrier: complete unacknowledged
bytes survive process death in the OS cache; recovery adopts them; a subsequent
fence publishes a frontier whose supporting file has never been synced. The
focused disk regression fails against the preceding implementation because open
returns successfully without reaching the required segment sync. The fixed
owner syncs segments containing complete frames beyond the saved frontier before
adopting them. A related directory barrier stabilizes visible segment names and
metadata, including a trim-floor rename whose previous directory sync failed.
It runs once after all partitions have been validated and before open returns.

`nix develop --command just test::storage-io-faults` passes **7/7 tests**:
the existing 37 write/sync error schedules plus four recovery-barrier schedules
(same file/rollover, recovered-file/directory sync errors), an observed trim-floor
rename/directory-error schedule, and the import test. The original recovery
regression passes **2/2 tests** after the fix. Payloads, next LSNs, successful
successor publication, removed prefix files and retained frames are checked on
real disk. These injected errors establish ordering and error propagation;
they do not suppress the host's background writeback or simulate device loss.
`nix develop --command just test::local-storage-faults` also passes all **42**
process-death schedules after both barriers. SIGKILL retains the OS page cache.
The broader filtered disk WAL/recovery suite passes **14/14 tests**, including
all-partition startup, direct segment traversal, cancellation, full trim, bounded
descriptors and recovery beyond 64 MiB. Diagnostic inventory/mappings, the
verification catalog, documentation links, Zig formatting and whitespace checks
pass.

The earlier PR qualification still has unresolved failures: the hosted bindings
lane exceeds a public-query deadline, and hosted and local clean growth runs
exceed the direct Table lifecycle proof's 180-second subprocess budget. The
local clean experience run has a separate authority/restart-budget failure.
These are not passes, not attributed to the model, and not fixed by increasing
fixture budgets here. Full checks and committed-source clean lanes on the final
PR revision remain separate gates.

## Physical reactive qualification — 2026-10-26

The clean browser lane at `717f55793` passes embedded Board (378.52 seconds),
query-browser (316.13), HTTP browser/worker (1,111.86) and gRPC browser/worker
(731.58). It then fails `test::reactive-browser` after 285.32 seconds including
compilation: the original serving operation remains `service_admitted` at the
fixture's 10-second completion deadline. Capacity refusals and slow native
calls are recorded. The two remaining reactive-view tasks do not execute.
The containing clean run fails after 2,854.08 seconds; four completed tasks do
not establish a complete browser lane.

A diagnostic uses the exact compiled binaries and unchanged fixture with full
failure-state retention and timed public observations. On `/var/tmp` (ext4), it
reproduces the failure in 84.02 seconds. Its 68 native setup commands take 51.96
seconds collectively; the original operation is not replaced. A control with
those same binaries and fixture on `/tmp` (tmpfs) passes the complete protocol
and browser trace in 23.30 seconds. That control establishes protocol behavior
and process replacement on the stated filesystem, not physical durability.
Earlier focused invocations did not record mount provenance; the current Nix
shell's default temporary parent resolves to tmpfs, so their shorter timings
must not be treated as physical-storage qualification.

Reusing one frozen signed status request removes repeated credential preparation
while preserving the gateway's current authorization checks, but the physical
control still fails the same completion assertion. That experimental source
change is removed. The [source-attributed evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-reactive-physical-2026-10-26/report.json)
retains all controls, binary hashes, patches and full telemetry logs. Private
fixture state stays outside Git. The original clean fixture deleted its own
temporary state on failure; later diagnostic fixtures retain theirs. Runtime
and protocol deadlines are unchanged. Physical reactive qualification and its
cause remain open; no successful control relabels the failed run as passed.

## Cache-conditioning retries and incomplete clean lane — 2026-10-26

The ingestion matrix at `1330787a3` stops after **231 of 384 samples** because
the cold-cache observation finds resident fixture pages. That run is failed and
has no complete percentile result. The revised driver records whole-fixture
observations after each conditioning sweep and retries mismatching files at
most three times. Every timed sample still requires the exact requested
residency state; exhaustion reports the mismatches and fails. The ingestion
driver also freezes and verifies its executable before running the matrix.

Nine harness tests pass, including transient conditioning and bounded permanent
failure. With the aligned-buffer probe built at `040959617`, the revised driver
passes the **12-sample ingestion smoke** and **24-sample read/checkpoint smoke**.
All values, accepted positions, original receipts, retained cuts, allocation
accounting and fresh-process readback checks pass. These small runs validate the
driver, not the pending full ingestion percentiles or beyond-memory growth.

The committed-HEAD clean core lane at `d80f5c1ed` finishes `check-core`, including
the full unit suite, and the subsequent simulations, package builds, Zig SDK,
Nix packages, compute and client ABI checks. It then fails in `test::station`:
the query-upload capture proof times out waiting for Station domain work.
The complete clean lane therefore fails. This older revision does not establish
clean-lane qualification for the later aligned-buffer implementation.

## Final lifecycle qualification and remaining checks — 2026-10-26

Merged PR #170 (`4434047222851efa5e26cf661d66158df88c0171`) has the same Git
tree, `90ce763836c21c92023a02019228375f976072ec`, as tested source
`a048b154f081d80dbbf2b57f70e3fb787d546ca1`. Its runtime change separates private
immutable-object I/O from the native journal mutex. It changes no wire/ABI or
stored definition, actor workflow, runtime deadline or test assertion. The
[paused-sync and negative-control evidence](storage.md#private-object-io-and-native-progress--2026-10-26)
establishes the shared backend's scoped concurrency behavior.

`nix develop --option eval-cache false --command just check` passes at that
source in 2,070.32 seconds after the locked Board dependency installation. It
includes contracts, diagnostic mappings, the full unit stage, CLI checks,
frontend checks and the handbook build. The earlier check fails on generated
diagnostic inventory counts; its original result remains in the bundle, and
the corrected inventory is committed before the passing run.

The committed-HEAD `just ci-clean --lane experience` run on ext4 **fails** in
445.13 seconds. Board checks, docs checks, Node binding checks and observability
pass; `test::server-logging` fails after 237.78 seconds including its build.
The no-argument node exits 1 with empty stdout but emits `service.starting` and
`telemetry.loss` (`dropped: 1`) without the expected `service.failed` event.
Argument validation returns `ExpectedConfigAndMode` before configuration reading
or storage opening. The exact telemetry-loss cause is not established.
[#171](https://github.com/spoke-sh/transit/issues/171) tracks this observability
failure. The original lane's later eight tasks do not run, and its recorded
result remains failed.

The remaining eight owning tasks run separately from the preserved isolated
checkout: seven pass and the Station launcher bootstrap fails. Fixtures,
assertions and deadlines are unchanged. The controller runs
each ordinary `just` task in the pinned bindings shell with that checkout's
physical scratch directory. It does not reuse outputs from the main checkout,
alter the CI inventory or overwrite the failed lane's records. This is focused
installed qualification, not a completed `ci-clean` lane.

| Task | Seconds, including task build | Outcome |
| --- | ---: | --- |
| `test::server-direct-tables` | 177.88 | Pass |
| `test::server-direct-faults` | 81.67 | Pass |
| `test::server-sql-lifetimes` | 76.66 | Pass |
| `test::server-sql` | 142.12 | Pass |
| `test::server-sql-local` | 458.99 | Pass |
| `transit-board::test` | 30.99 | Pass |
| `transit-board::query-test` | 328.51 | Pass |
| `launchers::local::test-station` | 38.47 | Fail |

Total focused-run time is 1335.31 seconds. The seven passes
establish their installed lifecycle, original-operation recovery, current access
and result behavior. They do not establish every filesystem, provider,
concurrent-writer or application latency profile.

The Station bootstrap's original native sequence 10 encounters cancellation
during append near the request's two-second work budget; the exact I/O stage is
not established. The owner then refuses with `WalRecoveryRequired`. The launcher
keeps the original request and retries the same temporary owner until its existing
20-second wait expires. Its long-lived service manager has not yet started.
[#173](https://github.com/spoke-sh/transit/issues/173) owns bootstrap-owner
replacement/recovery in the installed-runtime cutover.

A separate diagnostic reopens the original directory with the same binary and
configuration. Signed reads report position 11/principal sequence 10. The existing
exact-retry helper recovers the saved original request's receipt at position 10;
a second signed read still reports position 11/sequence 10. There is no new
acceptance, new operation identity, SQL resubmission or continued provisioning.
This proves recovery of that original receipt, not the complete Station launcher
schedule. The WAL recovery refusal, authority checks and runtime deadlines remain
unchanged.

The separate hosted run
[40344710693](https://github.com/spoke-sh/transit/actions/runs/40344710693) tests
merge `3db30c84a0d01a0b32d8129e38feacb18769025e`. Its tree
`2fe496883aeb40d81d5caa119587c024df8e2e94` equals PR #169 head
`ce26cccb93a52f95a33f77aeaaba628860ce2b2e` and merged `17b73b4f2`; it predates
the mutex correction. Core passes 28/28 (4,291.74 seconds), launchers 2/2
(927.79), bindings-1 17/17 (6,830.81), bindings-2 5/5 (4,252.89), and experience
13/13 (2,604.74), including SQL lifetimes in 61.53 seconds. These exact-source
passes do not identify the cause of an earlier missing-stderr SQL timeout.

That hosted job's later browser stage is **failed**: embedded Board passes,
then query-browser fails a five-second visibility assertion after **Resume
without rerunning**. The error snapshot still shows **Checking current query
evidence** with the original query reference; it does not establish a terminal
runtime failure. The later five browser tasks do not run. Separately, the
[physical reactive failures](#physical-reactive-qualification--2026-10-26)
and the 17.917-second original-operation diagnostic remain unchanged. No browser
pass, isolated Table latency improvement or complete combined-suite pass is
inferred from the successful installed tasks. Those broader browser failures remain
with #124; startup logging and bootstrap recovery remain with #171 and #173.

The [evidence bundle](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/lifecycle-final-qualification-2026-10-26/report.json)
retains exact commands, sources, task outcomes, compressed logs and hashes,
including the failed clean lane and hosted artifacts. Private configurations,
credentials and durable uncertain-outcome fixtures remain outside Git. Earlier
DELETE/CREATE/UPDATE/INSERT observations retain their original attribution; no
SQL was resubmitted to replace those uncertain outcomes.

The documentation base also includes subsequently merged PR #172
(`ceb109a03f4e0c9495b5a34721b09e683f0b94fc`), which extends Table execution and
storage maintenance and changes the current-v1 definition. The runs above retain
their earlier source and definition attribution. They do not qualify that later
implementation or establish cross-definition compatibility; current storage
integration and qualification remain separate.

## Test ownership and development workflow — 2026-10-27

This qualification asks whether contributors can find and execute the required
checks with less repeated preparation, without losing installed-language,
physical-disk, recovery, protocol or browser coverage. It evaluates test ownership,
build inputs, artifact reuse, check selection and scheduling. It does not qualify
a new storage engine or change the application's accepted-operation semantics.

The [implementation plan](../../roadmap/development-workflow.md),
[file dispositions](../../roadmap/development-workflow-migration.json) and
[ownership audit](../../roadmap/development-workflow-audit.md) retain the delivery
and migration details. Current commands and limits belong to the
[runner](../../../tests/runner/README.md), [task guide](../../../tasks/README.md)
and [toolchain guide](../../../nix/README.md).

### Comparison basis and method

The original inventory at `a610ecd5dcff22f2d0177b61b905a8e985252c13` contains
1,405 test files and 103 ordinary tasks. The migration preserves 670 original
files with their domain owners and archives 735 generated observations at their
original source/hash. Only README.md and AGENTS.md remain at the root. All 103
ordinary tasks still run exactly once; seven browser tasks remain an explicit
continuation. The 14 original SDK scenario identities remain, with one additional
registry entry for the collation repair also present in the comparison source.

The successful comparison source is `40e70d2029acf2478cd7c185b57adc2dbdae49d7`.
Obtaining that baseline required correcting existing collation fixtures, HTTP
body-read cancellation and terminal logging. The same semantic repairs are in
the candidate. Production application/package and SDK implementation sources
match between that comparison and candidate `93503e966`; differences in those
owners are documentation, diagnostic reference paths and test source imports.
Build/test registration and preparation are the changes under evaluation.
This is not a claim of identical compiled binaries across different source paths.

[Comparison run 40441691526](https://github.com/spoke-sh/transit/actions/runs/40441691526)
passes all ordinary and browser checks. It takes 98.1 elapsed minutes and 400.4
aggregate runner minutes. Its Nix cache reuse is partial, which prevents treating
the entire elapsed difference from a warm candidate as a pure code speedup.
Task/build phases and controlled local experiments provide narrower comparisons.
Additional runner controls increase fast-check coverage from 29 to 39 groups;
the ordinary scenario inventory is preserved, not every internal instruction.

Hosted candidate records identify four logical CPUs and fresh checkouts without
workspace object files. The comparison selects the same hosted runner class but
predates the added resource snapshots; exact physical-host matching is not
established. All samples use the pinned toolchain, with Debug and ReleaseSafe
as distinct inputs. The three warm manual dispatches start together on
independent hosted workers and share one branch's immutable dependency caches.
The seven-job ceiling applies to each workflow, not the combined calibration
campaign. Hosted timestamps and the date of this account use UTC.
Warm means each configured GitHub cache restores its matching key. Formal uses
upstream Nix substitutes in both modes and restores only the Zig dependency cache.
The explicit cache-miss mode disables GitHub restores/saves while retaining Nix
binary substitutes. Neither mode means an empty upstream cache.

All three successful warm runs use `93503e966` and the current ordinary/browser
inventory hash `774c79bc32565ed2c797e1e8bc8e6770ef5bc1119c9c53e60c63627cf1b1e86b`
(103 ordinary tasks, eight lanes, seven browser tasks). The comparison uses
`8645c92b17ea210bf0e99f80922d7b6c6bea4c8bb75aeb4996d184e3ae786c45`
with the same task inventory in seven lanes.

| Successful sample | Full feedback, minutes | Aggregate runner minutes | First completed lane, seconds | GitHub restored GiB |
| --- | ---: | ---: | ---: | ---: |
| [Comparison](https://github.com/spoke-sh/transit/actions/runs/40441691526), partial reuse | 98.1 | 400.4 | 338 | 13.39 |
| [Warm 1](https://github.com/spoke-sh/transit/actions/runs/40455488048) | 75.2 | 363.3 | 226 | 22.01 |
| [Warm 2](https://github.com/spoke-sh/transit/actions/runs/40455490500) | 82.0 | 416.1 | 205 | 22.01 |
| [Warm 3](https://github.com/spoke-sh/transit/actions/runs/40455492918) | 74.7 | 375.0 | 230 | 22.01 |
| [Cold](https://github.com/spoke-sh/transit/actions/runs/40465924045) | 85.7 | 463.5 | 226 | 0 |

The successful cold source is `ab715025057a5949c76014a396f6f3f83a038278`, with the
same task/lane/browser identity. It adds the browser transport-fault assertion,
provider-listener controls and cost-reporting corrections described below.
All ordinary jobs, the browser continuation and the aggregate required gate pass.
Later changes to the public explanation, reporting thresholds and this account
retain those implementation-source boundaries.

The warm median is 75.2 minutes of full feedback and 375.0 runner-minutes.
Elapsed feedback is 16.5–23.9% shorter than the comparison, but that comparison's
partial cache reuse prevents attributing the whole difference to code changes.
Aggregate cost spans 9.3% below to 3.9% above the comparison; these observations
do not establish a consistent aggregate saving. The 20–30-minute full target
remains unmet. The fast target is met by the scoped local measurement below;
the 5–15-minute focused-PR target has no matched hosted sample yet.

Warm regression reporting uses 100 minutes of full feedback, 500 runner-minutes
and 27 GiB restored. Each is the largest successful warm observation plus 20%
headroom, rounded up to five minutes or one GiB. The same method applied to the
successful cold observation gives 105 minutes, 560 runner-minutes and zero GitHub
restored bytes. One cold sample does not establish cold variance. These are initial regression
thresholds, not achieved improvement targets or statistically established tails.
The three samples do not establish long-term variance. The cost command reports
budget violations; correctness CI does not fail solely for exceeding a cost
budget. Future comparisons must retain this scenario inventory or recalibrate it
explicitly; moving work to another lane cannot inherit these thresholds silently.
Calibration reports retain their original `budget_met: false` because
the only active budget when they were collected described the historical 33-task
suite. Publishing a new budget does not rewrite those observations.

Queue/selection time is included in required feedback. Aggregate runner cost sums
job wall time, not a billable price. The first completed lane is a scoped result,
not the first assertion or complete qualification. Resource observations retain
initial and final snapshots (or the latest
task boundary on failure): child CPU/block I/O are cumulative; largest child RSS is
not the sum of concurrent memory; free disk/available memory are not interval
minima. Host I/O pressure can include unrelated host work.

In the retained first warm sample, largest-child RSS spans 0.90–3.44 GiB and
final workspace free space spans 75.3–89.2 GiB. These boundary observations do
not show aggregate peak RAM or minimum free disk. Together with the controlled
package experiment they support retaining two compilation workers and the
seven-job workflow ceiling, not adding more concurrency to live disk schedules.

### Controlled preparation changes and retained boundaries

At clean `8333fdfcd`, fresh local workspaces restricted to CPUs 0–3 compile all
34 package manifests. One worker takes 293.8 seconds and two take 153.1 seconds
inside the package runner. Child CPU totals are 426.9 and 422.1 seconds; largest
child RSS is 544,280 and 544,396 KiB. Dependency caches are retained.
This single sequential pair supports a two-worker default for package compilation; it does not isolate
cache-order effects or establish cold variance or aggregate peak RAM.
Package tests remain sequential.

The full C/C++ installed aggregate and both Document schedules pass after lazy
peer preparation. Six private installations previously compiled 24 peers; they
now compile ten. Local installation/peer phases fall from 140.9 to 91.9 seconds.
That is a preparation observation under concurrent host work, not a whole-lane
speedup. Matching immutable native artifacts and separate optimization-profile
packages remain mandatory. No independent scenario shares mutable state.

The ten-language interoperability ring passes with automatic installation and
pair phases. Its ordered durable history remains one schedule; splitting the
ring would change its recovery claim. Keep private installations for unrelated
grants, quotas, snapshots and destructive recovery. The documentation experiment
measures 64.5 seconds after clearing generated state and 10.8 with it retained;
keep clean production checks because correct invalidation of references/search
and generated specifications has not been established for retained state.

Executed task time, excluding hosted setup/cache transfer, retains the slower
observations alongside the improvements:

| Scope, minutes | Comparison | Warm 1 | Warm 2 | Warm 3 |
| --- | ---: | ---: | ---: | ---: |
| First SDK lane | 72.8 | 69.7 | 77.2 | 49.0 |
| Second SDK lane | 51.3 | 59.9 | 64.0 | 62.0 |
| C/C++ aggregate | 26.8 | 30.5 | 33.2 | 31.7 |
| Interoperability ring | 20.4 | 18.4 | 19.7 | 12.9 |

C/C++ and its enclosing SDK lane are slower in all three warm observations
despite fewer peer compilations. The other SDK lane varies in both directions.
These runs do not establish a consistent whole-SDK execution speedup. In the
first warm sample, core is 58.9 versus 60.6 minutes, its core aggregate 23.3
versus 22.1, and package compilation 3.1 versus 5.6. Live schedules still dominate.
The comparison's first SDK lane takes 72.8 minutes and core 60.6, so splitting
C/C++ alone would not shorten that measured critical path. Preserve those
schedules and leave residual execution costs with their runtime/storage owners.

The Actions `Prepare development shell` step takes 18 seconds in each comparison
SDK job and 16–19 seconds across the six warm candidate SDK jobs. These SDK jobs
already have matching restored Nix archives in the comparison; its partial cache
classification comes from other lanes. Shell entry therefore shows no material
speedup in this matched-cache subset. In the final cold source, those two shell
steps take 493 and 524 seconds (8.2 and 8.7 minutes). Cache restoration,
hosted-tool reclamation,
locked package installation and checks are separate costs. The retained
[shell step observations](../../../tests/evidence/development-workflow-2026-10-27/sdk-shell-steps.json)
are explicit API-field extracts with their endpoints and original timestamps.

Splitting the former 39-task growth lane uses existing task boundaries. The
successful comparison spends 40.3 minutes in the first 20 tasks and 44.4 in the
remaining 19. The candidate has separate growth and interfaces lanes while
retaining the seven-job ceiling. The new job repeats preparation, so elapsed
time and aggregate cost must be assessed together. With roughly 400 runner
minutes and seven workers, unchanged work alone implies a lower bound near
57 minutes; a 20–30-minute full-suite target requires substantially less work.

The cache-capacity investigation finds a configured 10 GB repository limit.
One generation of core/bindings/experience/formal archives totals approximately
10.5 GiB before the Zig cache, while temporary branches duplicate archives.
Formal's Nix tools take about 31 seconds to obtain from upstream substitutes in
the observed run. Removing its 1.1 GiB archive and unrelated hosted-SDK cleanup
reduces pressure; independent manual dispatches can share one branch's caches.
No quota, runner class or dependency pin is changed. Old keys and unrelated
branches can still evict entries; a reuse request alone never establishes warmth.

### Selection, failures and scope limits

Only reviewed Authority/WAL/Console/Delivery inputs and the Go SDK dependency
graph select narrower ordinary coverage. Generated Go declarations also select
binding-generation drift checks. Shared contracts, fixtures, build/runner policy,
other SDKs and unknown paths remain full; both rename endpoints contribute.
Main, release, merge-group and manual qualification remain full. Foreign/missing
source identity, omitted/duplicated tasks and unsupported selection formats reject
before any child command starts.

The selected tasks are compared with successful full-run observations. Actual
local execution through the selection-aware runner at `27b8d5a97` passes four
formal tasks in 40.5 seconds and the installed Go task in 29.0 seconds. These
manually supplied representative inputs use warm workspace artifacts; they do
not measure a hosted focused PR.
Clean fast qualification at `49546a3f4` passes all 39 groups in
28.6 seconds of recorded check execution. Clean-clone/development-shell setup
is outside that sum; this is a local measurement, not hosted full feedback.

Earlier failed and cancelled runs retain their outcomes. The migration exposed
a missing maintained-query Python launch root, obsolete interactive-task arguments
and a CI selection variable leaking into strict application configuration. Each
has an owning regression control and real execution evidence. A stale connection
after deliberate authority replacement now retries only the identical expiry
read once; persistent transport failure and disclosed results still fail.

The terminal-diagnostic correction in `8333fdfcd` closes the mechanism described
by [#171](https://github.com/spoke-sh/transit/issues/171). Ordinary telemetry's
try-lock could discard the sole service failure while the writer popped its
queue. A separate bounded terminal slot preserves that event, and the writer
marks an in-flight write before releasing the queue lock so shutdown cannot
mistake it for a drained sink. Debug/ReleaseSafe controls exercise contention,
filtering and oversized records; the full logging schedule and blocked/closed
pipe tests pass. The correction retains the 200 ms flush attempt and does not
promise delivery through a blocked sink or abrupt termination. It is present in
both comparison and candidate, and is not an actor/data-plane optimization.

The relational browser assertion previously inspected the first HTTP attempt,
which may be a documented pre-dispatch 429 refusal. At `28ad2c80e` the browser
schedule injects one such refusal, requires byte-identical close requests within
the existing three-retry bound, then verifies the successful final response and
settled UI. The real disk-backed browser schedule passes (504 public requests),
as do Board contracts, strict frontend checks and 102 frontend tests, including
persistent-refusal exhaustion. Production code and deadlines are unchanged.
The warm timing samples retain their earlier source; this added transport
fault control is not relabelled as executed in those runs. The final cold source
includes the control.

The replacement cold attempt at `722ae22df`,
[40459344495](https://github.com/spoke-sh/transit/actions/runs/40459344495), fails
when Ursula exits with `Address already in use` during Rust's deliberate store
restart. All seven other lanes, including the corrected browser continuation,
pass; the enclosing run remains failed. The hosted log does not identify the socket owner.
The pinned provider binds admin first; the fixture selected a public port but left admin ephemeral,
allowing the admin listener to take that public port. `ab7150250` allocates two
distinct ports together and preserves the configuration across restart. Three
child-process controls reproduce the permitted collision, verify stable restart
identity and reject another owner's occupied endpoint without retries. This
removes a demonstrated self-collision mechanism; it does not retrospectively
prove which process held the hosted socket. Ports remain discovery results,
not reservations against other processes.
The complete installed Rust SDK task passes locally from clean committed
`ab7150250`: raw client, Station disk/host recovery, public queries, HTTP/gRPC
effects and the direct catalog schedule (80 public requests). All 39 fast groups
also pass through committed-source clean qualification.

The cost reporter at `722ae22df` distinguishes emitted cache-policy observations
from GitHub's echoed shell command. Actual hosted-log and negative controls verify
that missing or conflicting declarations cannot establish a warm-cache result.
At `a6828e255`, the reporter also compares requested and restored keys directly: the
pinned cache action uses the same restored-key message for exact and prefix hits.
Missing key declarations, mismatches and conflicting policies cannot qualify a
warm budget. These reporting corrections do not change the measured workload.

The successful full samples execute the preserved installed SDK, local/Ursula,
application runtime, catalog/query and interface schedules, including all seven
browser tasks. Their pass conclusions do not resolve the historical failures
above or the separate failed manual profiles below.

The external SDK and query profiles pass locally at `87ce7b164` and `c78be2f79`.
Hosted application, discovery and reactive profiles pass in runs
[40441787577](https://github.com/spoke-sh/transit/actions/runs/40441787577),
[40441786385](https://github.com/spoke-sh/transit/actions/runs/40441786385) and
[40445518654](https://github.com/spoke-sh/transit/actions/runs/40445518654).
These are separate profiles, not ordinary cost samples. Reference-provider
infrastructure remains unavailable and unqualified.

Actual migrated vector (`04d37829a`), typed-pipeline and frozen-file (`7af0cd9ba`)
workloads pass 80, 320 and 324 samples; all four page-layout variants and the
default console-latency and growing-load (`3acdc1b04`) drivers execute.
The mutation driver is corrected to inspect the
current completion envelope and, in a dirty working tree based on `cf71149c9`,
verifies 17 default samples before a write returns `SqlOutcomeUnknown`; a wide profile verifies five before the same class
of failure. The generic installed-server task also exposes bootstrap/confirmation
timeouts already observed during runtime qualification. Those complete schedules
remain failed, their private installations remain available, and no operation is
resubmitted to replace an uncertain original outcome. Similar symptoms do not
prove that the causes tracked in [#124](https://github.com/spoke-sh/transit/issues/124)
and [#173](https://github.com/spoke-sh/transit/issues/173) are identical. No data-path deadline or
actor/storage implementation is changed to turn these observations into passes.

The [selected automatic records](../../../tests/evidence/development-workflow-2026-10-27/README.md)
retain the cost samples, controlled package comparison, fast result, selected
SDK/task/resource observations and final affected scopes beyond ordinary artifact
retention. Their [checksums](../../../tests/evidence/development-workflow-2026-10-27/SHA256SUMS.txt)
verify retained bytes, not execution. Raw routine logs stay in CI and ignored
runner output. The [active budgets](../../../tests/runner/ci-budgets.json) cite
this calibration and preserve the older 33-task limits through their immutable
historical source; those old limits never qualify this expanded suite.

## Former verification guide narratives

The [former guide at its recorded source](https://github.com/spoke-sh/transit/blob/b4a3411e7246f1a10709c1089eaf06a0a0cad867/tests/verification/README.md)
preserves the earlier CI/clean-run cost discussion, SDK qualification stages,
model/guard observations, offered-load account and codec/tool limits. Those
statements describe their stated revisions and inventories; they do not qualify
the reorganized suite. Current execution, automatic result retention and scope
navigation are owned by the [runner](../../../tests/runner/README.md) and
[verification index](../../../tests/verification/README.md). Reusable deterministic
methods now live beside their [scenario owners](../../../tests/verification/simulation/README.md).
