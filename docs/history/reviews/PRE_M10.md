# Post-M9 capability and verification review

Reviewed 2026-09-24 against implementation commit **a7b41da**. This is a
source, contract, test and CI review of the bounded M0–M9 implementation.
This review led to M10 verification and scale foundations;
idiomatic SDKs moved to M11. References use the current
sequence; the implementation evidence still describes the reviewed revision.
The filename preserves the original review link. New capabilities remain planned.

## Assessment

The architecture is a sound starting point for idiomatic SDKs: authority stays
in Transit, Station executes on the caller, public contracts are generated, and
real storage and foreign-host recovery are exercised. The biggest risks before
M11 are how public APIs expose those semantics, how durable collections grow
beyond the small resident-state profile, and how we test combinations without
repeating expensive deployment scenarios for every language.

Prioritize deterministic state-machine testing and reusable SDK conformance
scenarios. Explore a small TLA+ model of the protocol. Defer Lean adoption until
there is a particular algorithm and theorem worth maintaining. Neither tool
replaces the existing tests of Ursula, native scheduling, FFI ownership or
Substrate isolation.

## Coverage and qualification

| Area reviewed | Existing capability and evidence | Boundary that still matters |
| --- | --- | --- |
| Authority and protocol | [Core](../../../packages/zig/transit-core/src/root.zig) separates prepare/conditional commit; [adversarial tests](https://github.com/spoke-sh/transit/blob/425b7243595f46397be2f4165bd8f6b2ecc2b6ee/packages/zig/transit-core/src/tests.zig) cover fencing, current grants, duplicate requests, ordered input and closure | Protocol validity does not establish honest handler computation. The realm journal remains a serialization point. |
| State and retention | [Resource tests](https://github.com/spoke-sh/transit/blob/425b7243595f46397be2f4165bd8f6b2ecc2b6ee/packages/zig/transit-core/src/resources_test.zig) cover atomic mutations, view expiry, grants, replay and full view capacity; [state contract](../../../contracts/STATE_V1.md) defines bounds | One mutated resource per turn; four resources and four active views per realm. Association, access and lifetime ownership remain separate. |
| Storage and recovery | [Backend](../../../packages/zig/transit-backend-ursula/README.md), [storage proof](../../../tests/storage.py), and [physical capacity proof](../../../tests/capacity.py) exercise their actual boundaries | Process SIGKILL is not a host power-loss test. Provider behavior and full-store handling cannot be qualified by a pure model. |
| Station | [GenServer](../../../packages/zig/transit-station/src/GenServer.zig), [Turn](../../../packages/zig/transit-station/src/Turn.zig) and [services](../../../packages/zig/transit-station/docs/services.md) implement detached turns, calls, names, timers and bounded supervision | Host-pumped ABI, one call per input, explicit recovery; no durable suspended language stack or general dynamic supervision tree. |
| Fuze and Arrow | [Finite execution](../../../packages/zig/transit-fuze/src/execute.zig), [tests](https://github.com/spoke-sh/transit/blob/c5ac253365ba7dfa136cc4dadf99ba0c21570af1/packages/zig/transit-fuze/src/tests.zig) and independent [PyArrow checks](../../../tests/arrow.py) | Two-column bounded Tables; captured replies at most 672 IPC bytes. No optimizer rewrites, SQL, streaming query engine or cross-resource transaction support. |
| Language bindings | [Matrix](../../../tests/sdk/bindings.py) exercises service/requester roles and host restart; [ABI proof](https://github.com/spoke-sh/transit/blob/425b7243595f46397be2f4165bd8f6b2ecc2b6ee/tests/station_abi.py) and runtime-specific bridge tests cover ownership/cancellation | Low-level bindings are qualified, not installable idiomatic SDKs. Foreign-language Substrate workers and broad platform compatibility remain outside M11. |
| Operator surfaces and diagnostics | [Board](../../../apps/transit-board/README.md), [observability proof](../../../tests/interfaces/inspection/observability.py), browser tests and launcher recovery | Board is inspection-only, admitted through a private deployment boundary. Observations do not grant execution authority. |
| Deployment | [Runtime adapter](../../../packages/zig/transit-runtime-substrate/README.md), launcher upgrade proofs and [reference workflow](../../../.github/workflows/reference.yml) | Pinned provider, reviewed Zig workload and topology; reference/physical-capacity qualification is manually triggered, not part of ordinary hosted CI. |

This review did not rerun every runtime proof. Timing evidence below uses the
previous successful clean local run and explicitly identified hosted jobs;
failed overall runs are not presented as successful system qualification.
For this documentation-only change, just check passed, including Zig unit tests,
contract generation checks, frontend checks and all local documentation links.

## Priority findings for M11

### 1. Define concurrency at the principal boundary, not just the handle

**High priority, existing constraint needing a public API decision.**
[Session.receive](../../../packages/zig/transit-client/src/Session.zig) obtains the
principal's next sequence; each native handle independently rejects concurrent
use. Two handles or PIDs sharing a principal can still compete for that same
sequence. The [raw binding guide](../../../packages/zig/transit-client/docs/bindings.md)
already requires application-level sequencing; a convenient SDK must not hide it.

Choose and document how runners scope activation credentials and coordinate
operations sharing a principal. Keep authority validation decisive across hosts;
a local mutex cannot coordinate another host. Test two handles, two PIDs, a lost
acknowledgement and revocation. An uncertain operation must retain its original
identity rather than becoming a fresh request after a sequence conflict.

### 2. Make sustained operation an explicit SDK acceptance case

**High priority, supported limits rather than a newly discovered corruption bug.**
[Station's profile](../../../contracts/STATION_V1.md) has 32 live keys per resource,
shared by application values, schemas, waits, registry records and query results.
Completed waits and acknowledged results remain retained. The
[Table guide](../../../packages/zig/transit-station/docs/tables.md) explicitly says
applications eventually exhaust capacity without a chosen reclamation policy.
M8's kernel catalog collection does not reclaim all Station records.

The initial recommendation to expose these bounds and select cleanup was
insufficient: they are compiled total-cardinality ceilings, not cache settings.
M10 now requires a growing-state path with bounded resident
memory before SDKs stabilize. Explicit retention remains an application policy,
not a requirement to make a fixed array reusable. Test retained calls/results
beyond the old ceilings, then test deliberate quota exhaustion without losing
accepted work. Safe opted-in cleanup still needs late-reply/retry disposition
evidence; deleting a wait must not silently change its promised outcome semantics.

### 3. Make durable continuation different from a local await

**High priority, sharpen the existing M11 entry gate.** A Python coroutine,
JavaScript promise or Rust future cannot survive host loss. A cross-process
Station call closes a turn and later processes a recorded reply, timeout or
cancellation. An ordinary-looking await inside a held turn can incorrectly imply
stack durability, hold an expiring state view, or block its own mailbox.

Review equivalent Python, TypeScript and Rust examples with a host killed after
request commitment but before reply handling. Make the durable continuation
visible in the API. Keep local asynchronous I/O separate. Cover decode failure,
handler exception, use after turn completion, revocation during a wait, and
shutdown with an uncertain proposal. Use the same abstract outcome vocabulary
across languages without forcing identical method signatures.

### 4. Centralize error meaning, compatibility and ownership

**High priority before public packages stabilize.** The
[client ABI](../../../packages/zig/transit-client/src/Abi.zig) and
[Station ABI](../../../packages/zig/transit-station-bindings/src/Abi.zig) already preserve
uncertainty, including response-allocation failure after a mutation. Public SDKs
must preserve both the status category and structured protocol rejection; mapping
everything to a retryable exception would undo those guarantees.

Maintain a shared machine-readable outcome/conformance catalog for host glue.
Test missing/incompatible native artifacts, unsupported codecs, invalid UTF-8,
wide integers, binary values, cancellation and exact pending-operation import.
Version wire protocol, ABI, host transport and application codecs separately.
Treat the qualified 8 MiB native calling-stack requirement and bounded worker
count as runtime requirements, not installation trivia. A per-handle bound does
not establish a bound for an unbounded number of handles.

Keep M11's clean-consumer installation gate. It catches repository-relative
imports and native-path assumptions that source-tree tests cannot. Start with
owned IPC results; qualify optional Arrow adapters and their buffer lifetime
independently before offering zero-copy claims.

### 5. Replace selected examples with generated combinations where valuable

**High priority for confidence per second.** The repository has many valuable
handwritten adversarial sequences. The reviewed package/test sources contain no
systematic stateful property harness, native fuzz targets, allocation-failure
enumeration or mutation-testing workflow. There are already selected allocation,
capacity, malformed-input and scheduler-failure cases; this is a gap in systematic
exploration, not an absence of negative tests.

Use small independent models and generated action schedules for ownership,
grant changes, pending commits, replay, cancellation and retained results. Record
and shrink failures into normal regression fixtures. Keep real adapter proofs
for the boundaries those models deliberately omit.

## CI cost and improvements

### Observed costs

The previous clean local run at a7b41da passed all 23 ordinary tasks, totaling
**731.11 seconds of task time**. The separately run browser lane passed five
tests. These are existing run records, not a fresh performance benchmark;
local task totals exclude Nix setup and cannot predict hosted wall time.

| Local task | Seconds |
| --- | ---: |
| Local counter launcher | 208.71 |
| Local Station launcher | 97.54 |
| Bindings integration matrix | 114.83 |
| Standalone package tests | 67.61 |
| Station integration | 52.77 |
| Foundation/core checks | 46.72 |
| Storage integration | 42.49 |
| Service integration | 28.37 |
| Remaining ordinary tasks | 72.07 |

The local launcher pair accounts for **41.9%** of that total. Its logs were
retained locally at .cache/ci/fix-clean.log; these are not committed artifacts.

In [hosted run 36085614545](https://github.com/spoke-sh/transit/actions/runs/36085614545),
experience passed in **15m29s**, including 800 seconds of lane checks. Its two
launcher tasks took **370.26 + 225.40 = 595.66 seconds**, about 74% of those
checks. Core passed in 11m44s; bindings failed, so neither its duration nor the
overall result establishes a complete successful baseline. The earlier
[run 36083552672](https://github.com/spoke-sh/transit/actions/runs/36083552672) similarly
had a successful 16m16s experience job and failures elsewhere.

In run 36085614545, Nix restores took **49s core, 31s experience, 141s bindings**;
shell preparation added 19s, 19s and 23s. Restored cache archives reported about
2.1 GB for core and 1.6 GB for experience. These individual samples show why
adding jobs has a cost; they are not stable averages. Track wall time, aggregate
runner time, cache hit/size, setup, compile, scenario and cleanup separately.

### Recommended order

1. **Remove duplicate event runs.** The [workflow](../../../.github/workflows/ci.yml)
   runs on every push and pull request, with different concurrency keys. Runs
   36087124104 and 36087126679 exercised the same PR head through both events.
   Prefer PR validation plus main-branch push validation, preserving explicitly
   needed non-PR branch or merge-queue coverage. This reduces aggregate work;
   it does not halve a single run's duration.
2. **Measure inside the expensive tasks.** [The task runner](../../../tests/runner/ci.py)
   already reports timings. Add build/setup/scenario/cleanup subdivisions and
   retain small JSON/failed-trace artifacts. The clean-checkout runner currently
   deletes successful timing files with its temporary clone. Preserve summaries
   outside that clone. Compare several cold and warm runs before promising gains.
3. **Separate fast unit checks from compilation and package isolation.**
   [The root build](../../../build.zig) makes its unit-test step also compile apps,
   examples and integration probes. [Package tests](../../../tasks/test.just) run
   many of those same library tests independently. Give fast library checks,
   executable build smoke checks and standalone-manifest qualification distinct
   owners. Preserve unique checks such as Fuze's upstream compute suite. Measure
   actual cache reuse before treating all package time as removable duplication.
4. **Build reusable artifacts once per required profile.**
   [Launcher update tests](../../../tests/interfaces/deployment/launcher_updates.py) intentionally build
   Debug candidates against ReleaseSafe selections; the distinct-artifact proof
   must remain. Prebuild required artifacts once and reuse their immutable paths
   across scenarios. Separate pure configuration/selection cases from repeated
   full service startup. Keep at least one clean real build/update/restart path;
   cached developer output previously hid a real missing dependency.
5. **Keep fewer real-time schedules, add many virtual-time schedules.** The
   [Station lifetime proof](../../../tests/station_lifetime.py) waits about 25 seconds
   to exceed the configured uncertainty window. The
   [launcher proof](../../../tests/interfaces/deployment/launchers.py) deliberately survives a 32-second
   historical readiness-failure window. These waits have reasons. Cover boundary
   combinations using the existing core clock seam and test-only scheduling
   controls; retain representative real-clock/manager regressions. Do not merely
   shorten sleeps or add a production clock override.
6. **Select checks conservatively by dependency impact.** Run docs/link checks
   for genuinely docs-only changes. Run SDK host tests plus shared conformance
   for language changes; changes to contracts, shared Zig, build/toolchain,
   launchers or test infrastructure select their transitive consumers. Unknown
   paths select the full suite. The aggregate required check must distinguish
   intentional exclusions from failed, cancelled or accidentally missing jobs.
   Keep full integration on main and before release, with reference/capacity
   qualification for relevant changes and an agreed periodic cadence.
7. **Optimize caches after the task graph.** Retain existing separate Nix
   closures, shell GC roots, conditional saves and one Zig-cache writer. Measure
   restoration versus fetching closures before adopting a binary cache or more
   persistent runners. A smaller core shell alone does not remove dependencies
   still required by its flake/toolchain checks. Avoid uploading multi-GB checkout
   build trees on every source revision. Rebalance the existing three lanes only
   after removing repeated work; more lanes can improve latency while increasing
   total build and cache cost.

The local clean suite deliberately excludes the browser lane while hosted CI
includes it. Preserve the documented distinction or provide an explicit complete
clean-validation mode; do not label one as identical to all hosted qualification.
Changing the pre-push policy in AGENTS.md should accompany any adopted selector.

## Testing strategy

| Technique | First targets | Fast path / deeper path |
| --- | --- | --- |
| Stateful property testing | Core prepare/commit/retry, revocation, retirement, resource views; Station wait/result transitions | Small deterministic seeded schedules and saved regressions on PRs; larger seeds/schedules periodically |
| Differential and metamorphic testing | Fuze queries against a simple independent interpreter; generated IPC consumed by PyArrow; replay versus checkpoint plus retained tail | Finite random cases without services; broaden types/operators as introduced |
| Fuzzing | Signed-operation import, canonical JSON, Station frames, Arrow IPC and fragmented host-port input | Fixed minimized corpus per PR; time-budgeted fuzz discovery periodically |
| Allocation and scheduler fault injection | Native result allocation after commit, proposal rollback, host disposal, admission/cancellation races | Enumerate failures in focused units; retain small real single-CPU bridge proofs |
| Targeted mutation testing | Remove a fence, current-grant check, resource revision guard or late-result rejection | Selected compiling mutants against focused tests periodically; triage survivors instead of requiring an arbitrary score |
| Real recovery and deployment | Disk WAL/CAS, lost response, worker kill, launcher update, provider isolation, full store | Representative ordinary integration; reference/capacity on relevant changes and periodic qualification |
| Consumer/package and compatibility tests | Installed SDK with explicit native dependencies; old/new supported versions; documentation examples | Each affected language, shared contract consumers, full matrix for shared changes/releases |
| Bounded soak and performance | Repeated calls/results, handle/thread budgets, retained metadata and recovery cost | Short deterministic capacity runs; separately measured longer runs with generous performance thresholds |

The pinned Zig standard library already exposes std.testing.fuzz and
checkAllAllocationFailures. Qualify their actual compiler/runtime behavior before
adding a workflow. Production ABIs use page_allocator, so exhaustive OOM testing
requires an internal injectable allocation seam rather than pretending existing
calls are controllable. Use caller-supplied Fuze buffers to test bounded failures.

Python's [Hypothesis state machines](https://hypothesis.readthedocs.io/en/latest/stateful.html)
generate sequences of actions and shrink failures. A small Zig test executable
can expose deterministic transitions to that harness. Keep it alive across a
scenario; starting Ursula and a process for every generated action would erase
the speed advantage. Alternatively keep generation in Zig, provided failures
have replayable traces and useful minimization.

Example properties must respect actual semantics:

- Fresh ownership prevents old-owner publication; a rejected proposal never
  advances application input progress or publishes its mutations.
- Exact retries do not duplicate an accepted operation. Current revocation can
  deny receipt disclosure; idempotence does not mean unconditional read access.
- Checkpoint plus retained tail preserves the specified recoverable projection,
  not byte-for-byte WAL identity. Maintenance is allowed to write its own records.
- Reply/cancel/timeout order has one durable winner. Unknown outcomes stay unknown
  until authorized reconciliation, and final closure never reopens.
- Fuze preserves defined values, schema, null behavior, errors and source basis.
  Generated comparisons need an independent oracle, not the same predicate helper
  copied into a test. Checked overflow also constrains future algebraic rewrites.

The current cross-language suite is already a selected pairing graph, not every
possible pair. Keep every language qualified as both requester and service;
avoid multiplying every kernel fault by every language pair. Prove shared
semantics centrally and host-specific ownership, codecs and cancellation through
each SDK. Retain representative mixed-language end-to-end failures.

## Formal methods: a small TLA+ pilot now, Lean selectively later

TLA+ describes a state machine and allowed transitions. Its
[TLC checker](https://docs.tlapl.us/using:tlc:start) explores reachable states of
finite models and reports violating traces. This fits our ordering problem:
two owners, delayed persistence, dropped acknowledgements, a grant change and an
expiry transition can interleave in ways a few handwritten schedules miss.

Start with one PID, two competing workers/authority proposals, two inputs and
one associated resource. Bound counters, epochs, requests and logical time so the
model is actually finite; bounding worker count alone is insufficient. Model:

- durable head, owner generation, permission revision and consumed position;
- prepared proposals separately from conditional append and observed replies;
- exact retry identity, lost responses and recovery from durable state;
- admission cutoff, recorded turn permit, bounded settlement and final closure.

Check safety first: one successor per predecessor, no stale-owner publication,
no skipped input, no partial state/output commit, no resurrection and no duplicate
application of an exact retry. Encode trusted time with uncertainty. Existing
semantics validate time at the compared journal tail; they do not guarantee
physical append before a wall-clock deadline. Do not accidentally model a
stronger contract. Add effects and checkpoint/collection in separate small models
after the first model is useful.

For liveness, state the assumptions: eventual storage response, an authorized
worker scheduled often enough, available control capacity and no intervening
terminal policy. Under permanent outage, revocation or expiry, successful work
completion is not a valid unconditional promise. An aborted/exhausted model check
is not a passing exhaustive run.

Tie the model to implementation with a versioned abstract trace format and a
test runner that applies traces to the real Zig transition engine. Check permitted
outcomes and invariants after each step. Export counterexamples into regression
fixtures. Deliberately remove a modeled guard and the corresponding implementation
guard in isolated tests to show that the checks detect the failure. This is
conformance evidence, not a machine-checked refinement proof of Zig, Ursula or
the operating system. Keep one small PR configuration; larger models get a
separate budget. Adopt the pilot only if the invariants are understandable and
maintaining the model improves reviews.

Lean checks theorem proofs against formal definitions and their assumptions;
its [proof-validation guidance](https://lean-lang.org/doc/reference/latest/ValidatingProofs/)
also distinguishes a valid proof from a correctly intended theorem. It could
later help with a selected CRDT merge law, checkpoint preservation theorem or
Fuze rewrite under precise null/overflow rules. A Lean model does not automatically
verify our Zig implementation. Establishing that link is additional work.
Audit theorem assumptions and reject incomplete/admitted proofs in dependencies.
There is no reason to translate the whole kernel to Lean or gate M11 on it now.

## Implications for later milestones

- **M17 Documents:** reuse generated histories for duplicate/reordered changes,
  missing causal dependencies, tombstones and stale offline replicas. Decide
  merge laws and authorization/retention interaction before implementation;
  convergence alone does not establish valid admission. Checkpoint/large-body
  requirements will pressure today's inline state and result bounds.
- **M15/M16 connectors:** reuse lost-response and cancellation schedules, but
  supply protocol-specific remote-effect oracles. Test that replay performs no
  network action. Bounded reconciliation cannot roll back the remote system or
  make an unknown attempt safe to retry. Streaming adds directional flow control.
- **M22 Arrow interoperability:** extend the independent IPC checks with actual
  Flight/ADBC consumers, ticket revocation and incomplete-stream failures. Preserve
  source evidence and capability reporting; transport success is not completeness.
- **M35 clustering/portability:** model partition and ownership interleavings,
  measure journal contention and prove provider-specific failure behavior. More
  workers or SDK handles do not remove the current realm serialization point.

## Recommended next slice

First remove duplicate CI event work and establish retained timings. Then give
fast unit checks a narrow build graph, add one reusable deterministic transition
harness and one SDK failure-scenario catalog. Use those while reviewing M11's
Python/TypeScript/Rust examples, including shared-principal contention, capacity
exhaustion and restart during a durable call. Prototype the small TLA+ model
alongside that work, without making a broad formalization project a prerequisite.

This preparation is now scoped as M10, including the
collection-growth correction above; M11 follows its exit
gates. The [testing strategy](../TESTING.md) owns the selected verification policy.
