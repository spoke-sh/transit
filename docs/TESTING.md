# Testing and verification strategy

Status: [M10](roadmap/M10.md) is qualified within its recorded profile and workload
limits. Conservative workflow selection, separate unit/build checks, clean-run
timings, generated transitions, reviewed bounds, finite TLA+ models and concrete
negative controls are implemented. Repeated disk/S3 growth and hosted CI budgets
have measured evidence. The
[test guide](../tests/README.md) records what actually runs and what has passed.
[Conformance](CONFORMANCE.md) owns required adversarial guarantees; this document
owns how we obtain and maintain their evidence without making every edit run
every deployment. The [post-M9 review](reviews/PRE_M10.md) records the baseline.

## Confidence and evidence

Organize verification around invariants and failure boundaries, not test counts
or blanket coverage percentages. Each critical invariant needs a stable ID,
design owner, implementation boundary, positive/negative cases, and a mapping
to fast checks and real integration evidence. A scenario records its preconditions,
action/fault schedule, durable outcomes, forbidden outcomes and supported profile.
Keep one machine-readable catalog rather than divergent language-specific lists.
The [verification inventory](../tests/verification/README.md) owns the initial
executable task/invariant mapping, source-checked bound classifications, generated
schedules and saved corpus. Its qualification limits are part of each claim.

Report revision, toolchain/provider versions, workload, topology, seed/trace and
limits with results. Distinguish passed, failed, intentionally not selected and
inconclusive. A missing required proof, aborted model search or unavailable
reference runner is not success. The evidence is scoped: process SIGKILL does
not simulate host power loss, and an authorized proposal does not prove honest
application computation.

Small finite test cases are valuable for exhaustive exploration. They must
exercise the same parameterized semantics as the growing system; model bounds,
test fixtures and resident buffers must never define the application's total
collection capacity. [State](STATE.md#collection-size-and-working-memory) and
[retention](RETENTION.md) distinguish growth, quota, expiry and cleanup.

## Test layers

| Layer | Primary responsibility | Execution policy to implement |
| --- | --- | --- |
| Static/contracts | Formatting, types, manifests, docs links, generated schema/ABI drift, workflow selection | Cheap checks for every applicable change |
| Deterministic units | Transition validation, private proposal rollback, codecs, ownership, budget/error handling | Focused local command and applicable PR checks; no unrelated service compilation |
| Stateful properties | Action sequences across ownership, permission, retry, time and recovery | Saved regression corpus plus bounded reproducible generation on PRs |
| Differential/metamorphic | Independent query/codec oracle, replay/checkpoint equivalence, batch/page boundary independence | Finite corpus in ordinary CI; expand with capabilities |
| Native host/SDK | Thread/port/buffer lifetime, scheduler responsiveness, cancellation, installation and compatibility | Each changed host; all affected hosts for shared ABI/protocol changes |
| Real service/storage | Signed ingress, actual Ursula conditional writes/WAL, missing replies, crash/restart | Representative ordinary integration and full main/release qualification |
| Launcher/provider | Artifact selection, update/recovery, network and sandbox boundaries | Relevant changes plus periodic/reference release qualification |
| Discovery/soak | Longer fuzzing, model exploration, mutation and sustained load/recovery | Separate bounded jobs; discovered failures become ordinary regressions |

Build each required artifact/profile once where safe and reuse immutable outputs.
Keep standalone package-manifest and clean-consumer checks: a shared root build
can hide undeclared dependencies. Keep a clean-checkout path without inherited
workspace outputs. Include browser qualification explicitly in a complete tier;
do not call a suite identical to hosted CI when it omits that lane.

## Deterministic schedules and stateful properties

The test harness should control authority storage outcomes, recorded time/error
samples and selected scheduling boundaries without adding production clock or
authentication bypasses. Separate prepare, successful conditional append,
acknowledgement loss, restart and observation. A test store is a model dependency;
real Ursula conformance must establish that its modeled guarantees hold.

Generate both legal and adversarial sequences, checking invariants after every
step. Keep a simple independent expected-state model. Avoid copying implementation
branches into the oracle. Store and minimize counterexamples into versioned traces
that the Zig engine can replay without a full deployment. Pin generators and save
the trace as well as the seed; changed generator versions can interpret a seed
differently. A long-lived Zig test driver may be driven by Python stateful tests;
do not launch a database per generated action.

Initial properties include:

- Only one conditional successor wins; stale ownership and current revocation
  forbid new publication. Denied reads cannot reveal previously accepted receipts.
- A turn publishes its state, input progress and outputs atomically. Failure and
  quota refusal never acknowledge unfinished input or publish a partial batch.
- Exact retry cannot duplicate accepted work. Uncertain outcomes remain uncertain
  until valid reconciliation; cancellation of an await cannot manufacture rollback.
- Reply, timeout and cancellation have one ordered winner; late results cannot
  reopen closure. Work admission, bounded settlement and final retirement differ.
- Checkpoint plus retained tail preserves the specified recovery projection and
  rejection evidence. Cache loss cannot lose accepted data; physical WAL equality
  is not the oracle when maintenance may append control records.
- Paging/batching does not change complete query results or their source basis.
  Current authorization and lifetime checks still apply on subsequent reads.

Extend the existing independent PyArrow checks with generated schemas/values and
a simple reference evaluator for Fuze. Specify null/missing/conflict behavior,
integer overflow, ordering and error equivalence before asserting query rewrites.

## Fuzzing, allocation failures and mutation

Use the pinned Zig compiler's supported fuzz interface for bounded input parsers
and serialization boundaries: signed-operation import, canonical JSON, frames,
Arrow IPC and fragmented port messages. Seed with valid messages plus malformed,
oversize, truncated and boundary-value cases. Check bounded allocation/work,
safe rejection and no partial publication, not merely absence of a crash.

Inject allocation failure at internal seams, including response creation after
an accepted mutation. Enumerate cleanup/rollback behavior where practical; a
generic allocation error must not erase commitment uncertainty. Inject scheduler
admission failure independently from transport failure and retain real single-CPU
checks. Do not silently retry network operations to hide local scheduling faults.

Run selected compiling mutants against focused tests: remove a generation check,
current-grant check, revision guard or final-closure guard. A surviving mutant
requires investigation; distinguish equivalent or unreachable changes from a
missing assertion. Keep mutants out of production artifacts and avoid making a
global mutation percentage a development gate. A small set of deliberately bad
variants also validates that model invariants are not vacuous.

## Formal models

The [implemented finite model](../tests/verification/models/README.md) records
its bounds, assumptions, negative controls and concrete trace bridge. These are
initial safety checks; the broader conformance and growth gates remain open.

M10 starts with a small TLA+/TLC model of ownership, preparation/commit, retry,
permission changes and finite settlement. Bound actors, requests, counters and
time explicitly. Check safety first; liveness requires stated storage, scheduling,
authority and capacity assumptions. Model trusted validation time and uncertainty,
not an unsupported guarantee of physical append before a deadline.

Connect abstract traces to real Zig transitions and preserve counterexamples as
regressions. This checks conformance for exercised behaviors; it is not a proved
refinement from all Zig executions. Finite model success does not establish all
cluster sizes. Retain actual storage/provider/native-runtime proofs. Pin tools
and give small PR configurations and larger exploration separate budgets.

M12's [Lean rewrite proofs](../contracts/sql/README.md#lean-scope) now qualify
four named specification theorems: total filter reordering, projection pruning,
predicate pushdown through total projection with first-error preservation, and
an unchanged downstream fallible consumer. `just test::sql-rewrites` checks them
with pinned Lean and rejects incomplete proofs or unexpected axioms. No optimizer
rule is enabled. The explicit model/implementation correspondence assumptions
and omitted allocation, cancellation and authority behavior prevent treating this
as a proof of Zig or the deployed system. CRDT merge laws remain future work.

## Scale, overload and recovery

The [Rey workload model](workloads/REY.md) supplies downstream demand scenarios
for market capture, context, execution and research. Its arithmetic is not
benchmark evidence. The [experiment matrix](../tests/verification/scale.json)
keeps small reproducible growth runs distinct from those application envelopes.

Define a workload matrix before promising throughput or a supported system size.
Measure retained cardinality independently of resident cache, active PIDs/views,
message rate, payload/result size, fan-out, active correlations and history age.
Vary uniform versus hot-key/hot-PID traffic, slow readers, producer bursts,
revocation, worker/store restarts, disk pressure and checkpoint/GC overlap.

The growing-state proof must cross old array ceilings and exceed the configured
cache substantially while keeping resident work within declared budgets. Increase
retained state with the budget fixed; inspect lookup, per-turn and restart costs.
Do not substitute a benchmark that just raises constants or keeps all data in
memory. Large Arrow results need bounded batches and durable complete-result
evidence. Catalog identities, tombstones, wait/result evidence and indexes count
towards storage and recovery measurements, not only application rows.

Report throughput and latency distributions alongside correctness, queue age,
RSS/stack/thread/FD counts, cache misses, scan/replay work, disk/write amplification,
checkpoint time, recovery time and control responsiveness. Include the provider's
memory/stream count and request amplification, not only the client cache.
Distinguish service restart from catching up to fresh data. Report admitted load
and rejected/backpressured demand. Include an offered-load test independent of
response completion so overload does not hide its own queueing delay. Keep load
generation separately measured; never claim capacity from a saturated generator.

Under pressure, preserve accepted work and reserved control capacity. Reads,
telemetry and application traffic must not prevent revocation, retirement or
recovery progress. Quotas are explicit operational policy; application expiry
or history deletion cannot be inferred from resource pressure.

Record hardware, filesystem, provider topology, versions, cold/warm state and
repeat counts. Establish tolerances from measured variance. Keep strict protocol
deadline assertions separate from noisy performance regressions. Single-authority
growth does not prove horizontal throughput: the current realm-wide journal is a
serialization point, and [M18](roadmap/M18.md) owns broader cluster qualification.

## CI selection, cost and local parity

The M10 warm feedback budget is **under 15 minutes**, with **60 runner minutes**
and **12 GiB** restored per full run. These budgets follow the accepted 12m37s /
53m27s five-lane measurement. Under ten minutes remains an improvement target,
with under five as a stretch; further runner optimization is deferred. These are CI budgets, not service
SLOs; [ci-budgets.json](../tests/verification/ci-budgets.json) records their
measurement rules. Require three complete warm samples for ordinary feedback
and one explicit cache-miss baseline for exceptional rebuild cost. The latter
is a calibration, not a cold-run variance claim. Failed, cancelled or incomplete
runs do not count. The calibrated cold budget is **under 35 minutes** and
**135 aggregate runner minutes**, with GitHub dependency restores disabled.
Its complete baseline took 31m09s and 111m51s. Restored-byte measurements cover
GitHub cache archives, not upstream Nix substitute traffic. The
[measurement record](../tests/verification/results/m10-ci-2026-09-25.json)
preserves all qualifying samples and the excluded failures/regression.

M11 adds installed public SDK schedules and the ten-edge language ring to the
bindings lane. Its [local cost record](../tests/verification/results/m11-sdk-2026-09-26.json)
covers consumer installation and public interoperability only. The M10 samples
above do not establish a budget pass for this larger inventory; new hosted cost
measurement and further runner optimization remain deferred.

`just ci::cost RUN_ID` reads GitHub's completed job/step timestamps and cache
byte counts into a small JSON artifact. It requires authenticated `gh` with read
access to Actions. The separate `CI cost evidence` workflow runs the same trusted
default-branch tool after CI completes. It does not execute code from the tested
PR or upload raw logs. Its report distinguishes dependency-cache restores,
setup, checks (including compilation), cleanup and cache saves; individual timed
task artifacts retain the build-smoke and scenario owners. Mixed build/test task
time must not be presented as pure execution time. Workflow creation to final
job completion includes queue time; aggregate runner time sums actual jobs and
does not estimate a monetary price.

Manual CI has a `cache_mode=cold` option disabling GitHub Nix/Zig restores and
saves. Its concurrency group is separate so calibration does not supersede
ordinary feedback. Nix can still use upstream binary substitutes. Ordinary runs restore
dependencies into fresh checkout object caches. The five lanes separate core,
growing state, frontend/Station experience, launcher/build smoke and bindings;
browser checks remain in experience. Core/growth share the core Nix cache, and
experience/launchers share theirs, with one writer per key. All tasks retain
one owner in the local/hosted inventory. `TRANSIT_CI_RUNNER` can select an explicitly
provisioned runner label; absent that variable CI still uses `ubuntu-24.04`.
No larger paid runner is implicitly provisioned. Compare both feedback and
aggregate cost before selecting one.

Use one inventory mapping invariants/scenarios to artifacts, dependencies, tasks
and tiers. Preserve stable aggregate required checks. A selector must understand
shared contracts/build/test infrastructure, select unknown paths conservatively,
and distinguish deliberate exclusions from accidentally missing work. Qualify
selection by comparison with full runs before relying on it.

Prefer PR validation and main-push validation over duplicate push/PR runs for the
same head, preserving merge-queue or standalone-branch coverage when required.
Docs-only selection still checks links and relevant schema/document generation.
Full main/release tests and a periodic reference/capacity schedule retain broad
coverage. Toolchain/provider changes require affected real qualification; an
unavailable runner leaves that evidence outstanding.

The current policy runs full ordinary qualification weekly on hosted runners,
with bounded larger model/property exploration and targeted mutations in the
bindings lane. Reference recovery/capacity runs weekly and on demand on the
dedicated runner. Missing runner capacity leaves that qualification outstanding.
Release qualification still requires the appropriate reference results; passing
ordinary PR CI alone does not establish them.

Track setup, compile, scenario, cleanup and cache-transfer time separately, plus
critical-path wall time and aggregate runner time. Keep timings outside disposable
clean clones and upload small redacted failure traces/logs. Preserve Nix closure
roots, bounded cache contents and clear cache-writer ownership. More parallel jobs
are justified by measured benefit after duplicate work has been removed.

Standalone package composition remains a separate compile check. Root library
unit checks execute the shared suites once; Fuze's configured upstream compute
suite runs through `test::compute`. `test::packages` remains a focused full
standalone run, while CI uses `test::packages-build`. Compile success never stands
in for a missing runtime owner. This removes duplicate execution without adding
a Nix/cache lane; hosted timing improvements still require measurement.

Expose focused, ordinary and complete checks through just only when implemented.
Keep local/hosted selection and environment requirements consistent. Update the
pre-push instructions when adopting tiers; the current instructions remain in
force until that change. Add regression tests for the selector and failure gate.

A local M10 package comparison found that fully warm runs already reuse Zig's
successful test results: complete standalone checks took 0.335 s versus 0.402 s
for standalone compilation plus the extra compute suite. Those numbers do not
show a warm-cache speedup. A separate fresh-cache core experiment compiled its
test artifact in 894 ms, then executed 89 tests in 39 s with compilation cached.
CI now retains that execution under root unit tests and avoids repeating it
through the standalone package task. This identifies removable execution work;
it is not a measured hosted critical-path or aggregate Nix-cache improvement.
The local evidence is in `.cache/verification/package-core-profile.log` and
`.cache/verification/package-task-timings.json`.
