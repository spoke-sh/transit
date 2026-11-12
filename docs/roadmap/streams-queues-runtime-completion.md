# Milestone 6 completion implementation plan

[Milestone 6](06-streams-queues-and-durable-runtime.md) · **Status: In Progress** · 2026-11-12

Milestone 6 has its database foundations and a private transactional Station
behavior. Completing it still requires the public runtime replacement, durable
services and effects, migration of existing consumers, Table commit and latency
work, and qualification of the complete system at one revision. Most remaining
effort sits in service migration and proof of the complete replacement.

Plan for **15–21 review units and 19–32 engineer-weeks of direct work**. Allowing
roughly 25% for integration and investigation gives **about 24–40 engineer-weeks**.
These are planning estimates, not measured delivery velocity. The largest
uncertainties are transactional turn cost, the breadth of the consumer cutover,
and the external Document participant dependency. The estimates below include
M6 integration with that participant, but exclude implementing M7 itself.

**Source basis:** local `main` at
`6552747cf58a81cab0c60ad5c39e8e1568e9a007`, after the public Queue build/test
slice. The shared definition is
`cca0376c55733fd553a43a187fee9e8c379ab1b14007009a06bfcab3a517fec2`
(`transit.v1.native-transaction-execution.2026-11-11`). This plan supersedes
earlier descriptions of what to implement next while preserving their acceptance
criteria and dated evidence. The [private Station plan](station-transaction-implementation.md)
remains the detailed record of Batch 5 and its consumer handoff.

## Delivered basis and remaining work

| Area | Present at the source basis | Remaining completion obligation |
| --- | --- | --- |
| Database independence | Database-owned SQL admission/recovery and direct execution; no Station coordination for ordinary database work | Preserve package/runtime separation through the replacement; finish the stronger combined-commit and latency objectives |
| Streams and Queues | Declarations, typed operations, SQL workloads, groups/offsets, bounded waits, predicate-aware claims, renewal, native `.tseg` log columns and finite `STREAM_SLICE` | Complete the resource, maintenance, offered-load and recovery matrix; retain original failed campaigns separately |
| Queue storage | WAL-authoritative foreground transitions, bounded metadata overlays, checkpoints and incremental resident scheduling state | Prove the integrated actor/transaction/collector workload under pressure; standalone zero-metadata-PUT operations do not imply zero transaction-barrier object work |
| Mixed transactions | Table/KV state, Stream/Queue appends, authenticated offsets and Queue ACKs through one decision; SQL composition and savepoints | Extend to the qualified M7 Document participant before migrating Document-dependent consumers; retain full fault and policy coverage |
| Station Batch 5 | Internal real Table/KV handler, native execution condition, retained original work and replacement recovery | Public services, scheduling, payload closure, effects, consumer migration and performance qualification remain open |
| Application Queue programs | Managed program execution and public `.transit` Queue builds/tests reuse database owners | These do not replace arbitrary Station handlers, authenticated actor calls or existing SDK services |
| Table write lifecycle | `commit_saved` returns the original partition outcome; Catalog token bookkeeping still settles separately | Account-wide token/commit composition, TRUNCATE and the inherited matched latency objectives |

Current behavior is owned by [Streams](../handbook/reference/streams.md),
[SQL streaming](../handbook/reference/sql/streaming.md),
[transactions](../handbook/reference/sql/transactions.md),
[Station](../handbook/reference/station.md) and
[application builds](../handbook/reference/applications.md#application-source-builds).
The [Queue contract](../../contracts/QUEUE_V1.md#implemented-boundary),
[private runner](../../packages/zig/transit-station/src/transactional/Runner.zig),
[SQL recovery path](../../packages/zig/transit-sql/src/DatabaseRuntime.zig) and
[Document participant rejection](../../packages/zig/transit-catalog/src/DirectTransaction.zig)
provide the corresponding implementation boundaries. TRUNCATE still has
[no execution contract](../handbook/reference/sql/grammar-surface.md).

The [November 12 runtime qualification](../history/qualification/runtime.md#private-transactional-station-behavior--2026-11-12)
records 18 installed Station schedules, eleven worker-kill boundaries, two node
restarts per schedule, replacement credentials and independent state/input/output
oracles. It also records passing clean lanes at their respective source revisions.
That establishes useful private behavior and recovery coverage. It does not
establish public service replacement, a combined actor-population/collection
campaign, or completion at this plan's newer HEAD.

## Performance changes the next implementation priority

The [retained private comparison](../history/qualification/performance.md#private-transactional-station-comparison--2026-11-12)
reports a **12,015.7 ms median and 19,272.0 ms p95** for the private runner,
versus **67.0 ms and 80.5 ms** for the paired native control. Both verify the
same 128-byte state/output sequence, but the private workload additionally
inserts a Table row, performs two Table reads, journals the turn and measures
discovery through cleanup across five participants. These are different
compositions; their ratio is not an isolated transaction slowdown.

The private run records 27,836 allocation successes and 257,360,870 acquired
backing bytes across twenty measured turns, with an 18,389,712-byte high-water
mark. The first five measured turns have a 5.84-second median and the last five
18.48 seconds. The cause of that growth is unresolved. Correct results and the
64 MiB ceiling do not make this a suitable public replacement cost profile.

The source gives concrete investigation points: `Runner.save` publishes and
rereads control KV progress, `execute` saves around each statement, handler
reads inspect transaction state, and `publish` stages each KV mutation and log
action separately. These are hypotheses to measure, not established causes.
Queue transaction barriers can also materialize metadata that standalone Queue
operations retain in memory. Attribute these costs before changing durability
or recovery boundaries.

**Recommended next slice:** qualify and optimize the private composition before
adding the full service stack. Calls/replies contracts can be designed alongside
that work; public activation waits for the performance and resource gates.
M6 currently selects absolute latency objectives for Tables, not Station.
Freeze a reviewed Station regression budget from matched workloads before
activation; this plan does not invent a new absolute target or weaken Table's
existing targets.

## Review units and effort estimate

An engineer-week means one experienced engineer working full time with the
existing build/test automation. Estimates include owning tests, documentation,
review fixes and integration for each unit. They assume the existing local
authority profile, no automatic conversion of incompatible installations, and
reuse of the current transaction/storage owners. They are low-confidence ranges
until A and B establish the cost and migration inventory.

| Unit | Review units | Engineer-weeks | Existing milestone scope |
| --- | ---: | ---: | --- |
| A. Reconcile qualification and freeze the replacement inventory | 1 | 1–2 | Batches 0–2 and outstanding Batch 5 gates |
| B. Bound and optimize transactional turn execution | 2–3 | 3–5 | Batch 5 follow-through, R7/R9 resource and performance obligations |
| C. Implement authenticated durable calls and replies | 1–2 | 2–3 | Batch 6 |
| D. Migrate timers, scheduling, names and supervision | 2–3 | 2–4 | Batch 6 |
| E. Migrate effects and retained Query consumers | 2–3 | 2–4 | Batch 7 |
| F. Cut over public consumers and remove superseded runtime paths | 3–4 | 4–6 | Batch 7 and M7 handoff |
| G. Finish Table commit composition and latency | 3–4 | 3–5 | Batch 8 / R9 |
| H. Qualify the final revision and close the milestone | 1 | 2–3 | Batch 9 / R10 |
| **Total before contingency** | **15–21** | **19–32** | |

Review units are independently assessable outcomes; a shared-definition cutover
may require several of them to merge together. The contingency range rounds the
total rather than promising an exact schedule. There is no defensible percentage
complete based on file count or merged batches: the remaining consumer and
qualification work is disproportionately broad.

With one engineer, the budget is roughly six to ten working months including
contingency. Additional staffing can overlap G and the Document prerequisite
with Station work, but cannot remove the service/consumer dependency chain or
the final qualification gate. Re-estimate after B; deeper storage changes or
failure to meet the inherited Table targets can exceed this range.

## A Reconcile qualification and freeze the replacement inventory

Create one evidence matrix against the selected implementation revision. Carry
forward the [Batch 9 acceptance matrix](06-streams-queues-and-durable-runtime.md#batch-9--qualify-one-revision-and-promote-supported-behavior)
and the [Batch 5 acceptance cases](station-transaction-implementation.md#required-acceptance-evidence),
with a command, source, outcome and missing coverage for each row. Reuse the
passing database and private-runner suites; add only missing schedules.

Exercise mixed preparation/decision/finalization, automatic DLQ competition,
checkpoint/reopen and collection together with actors. Grow idle actors, inbox
backlog, pending turns and retained history beyond resident caches. Race staging
after the collector cut, abort/closure, current-policy revocation and replacement.
Require a known orphan to be collected while original claims, journals and
pending decisions survive. Keep control/recovery capacity available under data
and maintenance pressure.

Complete all six [log baseline profiles](../../tests/performance/storage/log_runtime.md)
at one source, then supply the still-missing sealed/cold reads, group offsets,
delays, wakeups, lease expiry and offered-load cases. The six existing hot profiles
alone do not cover these extensions. Preserve the
[older failure families](06-streams-queues-and-durable-runtime.md#evidence-still-required-for-completion)
and the newer local timeout/clock/console failures with their original identities;
later clean or hosted passes do not establish their cause.

**Exit:** an explicit pass/open matrix, fixed workload/resource budgets and a
removal inventory naming old module, stored artifact, caller, replacement and
proof. Separate old diagnostic investigations from current regressions and
missing executable coverage. Do not call the broader Batch 5 matrix complete
solely because its 18 installed schedules pass.

## B Bound and optimize transactional turn execution

Start in [the private runner](../../packages/zig/transit-station/src/transactional/Runner.zig),
the shared Catalog/transaction clients and the owning storage publication paths.
Measure discovery, claim, retained progress, reads, statement staging/execution,
decision, finalization and cleanup separately while retaining one end-to-end
sample. Attribute foreground versus background requests and client versus server
allocation. Repeat with increasing retained history to investigate the observed
growth; keep payload, cache, durability and hardware/load conditions fixed.

Coalesce bounded state staging and redundant metadata/inspection where the
shared owners permit it. Reuse buffers and immutable definitions within their
valid lifetimes. Any removal of a durable progress write must retain enough
accepted evidence to recover the exact original claim, statement and decision
after loss at that boundary. Ordinary database clients must remain independent
of Station; do not add a special actor commit protocol or raw provider shortcut.

Add recoverable closure for accepted claim payload reads after the turn and
required replay dependencies settle. ACK, local result disposal and payload
release remain separate. Reuse bounded shared-client operations for this work;
do not silently release a claim that replacement recovery still needs.

**Exit:** the existing installed/fault oracles still pass, larger-than-cache
population and history tests stay within declared budgets, and matched complete
measurements explain the dominant costs and satisfy the reviewed replacement
budget. Report the larger 1 KiB/six-key workload separately from the common
128-byte case. Failed or unresolved attempts remain in the report. Allocation
traffic must be measured after warmup; a memory ceiling alone is not evidence
of the architecture's zero steady-state allocation goal.

## C Implement authenticated durable calls and replies

Freeze the replacement for [Station message origins and waits](../../contracts/STATION_V1.md)
before adapters. Persist correlation, original accepted sender/destination,
wait state and terminal disposition in declared data. Bind actor-origin evidence
to the native execution condition and common decision; a payload's claimed PID
or a similar application row cannot authenticate a call.

Compose receiver ACK, state, journal and reply/outbound intent in one decision.
Resolve an uncertain earlier decision before executing the handler again.
Preserve `block_input`, `stop`, poisoned reads and explicit retry semantics.
Distinguish local await cancellation, durable wait closure and external work
cancellation. Keep correlation and destination stable through name rebinding.

**Exit:** installed caller and receiver replacement, rotated credentials,
duplicate/late replies, timeout/completion races and denied disclosure preserve
one original outcome and never repeat a completed callback. Component fixtures
and all generated consumers agree on the replacement contract.

## D Migrate timers scheduling names and supervision

Implement durable timer registration, original scheduled inputs, closure and
restart recovery on declared data. Reuse Queue waits and timing owners with
bounded registration/recheck, saturation recovery and joined cancellation.
Park idle actors without one resident worker or timer per retained actor.
Native PID ownership, suspension and permanent retirement remain authoritative.

Move registry conditional rebinding and supervision's child/lifecycle intent to
the same data/transaction model. Providers reconcile physical execution;
provider observations and restored rows cannot grant ownership. Keep accepted
destinations stable and stale cleanup conditional on the original binding.

**Exit:** restart/downtime, uncertain time, enqueue/registration races, duplicate
wakes, saturated queues, lost spawn/stop replies and controller replacement
preserve identities and progress. Measure idle requests/CPU and first-work
latency. Verify control progress under quotas and cancellation/join at shutdown.

## E Migrate effects and retained Query consumers

Replace connector persistence with declared intent, attempt, capture and outcome
owners, following [connector semantics](../handbook/reference/connectors.md).
Only a committed, currently authorized intent permits dispatch. Unknown outcomes
retain each connector's recovery/retry policy; Queue redelivery cannot establish
exactly-once remote execution. Replay and finalization must dispatch zero effects.

Move private Station Table/Query consumers to direct data and retained query
owners. Preserve exact source definitions, pins, delivery coverage and current
rights. Replace courier/query-host polling with transactional outboxes, Queue
waits and bounded original-work discovery after loss of notifications.

**Exit:** HTTP/gRPC/Flight and query fault suites preserve recorded destinations,
captured bytes, original unknown outcomes, late cancellation and retained result
attribution across replacement. The real service compositions operate without
the superseded polling delivery roles. Coordinate Document representation work
with its owner; do not substitute two commits for an existing atomic boundary.

## F Cut over consumers and remove superseded runtime paths

Use the [existing consumer inventory](station-transaction-implementation.md#implemented-ownership-and-later-consumer-cutover)
as the minimum removal set. Replace public GenServer/Turn persistence, private
Table helpers and foreign turn actions, bindings/host APIs, all affected language
SDKs, examples, installation/bootstrap, launchers/controllers and Board metadata
interpretation. Preserve the separate Catalog `DirectTableBridge` and native
authority primitives that still have supported non-Station consumers.

Before the Document consumers switch, require M7's direct lifecycle, partitioned
transaction preparation/common-decision visibility, savepoints and original
recovery. [M7 C5/C7](07-document-storage-and-station-decoupling.md#follow-on-reviews-caller-and-common-decision-path)
is an external dependency. Current `.document` transaction rejection and
Table-backed SQL Document reads do not satisfy it. M6 can advance Table/KV
services privately without waiting, but cannot complete full replacement while
Document consumers still need the old writable Station engine.

Apply one coordinated current-v1 replacement for each incompatible merge:
contracts, schema/ABI resources, signing fixtures, saved work, SDKs and consumers
must agree. Missing/foreign definitions refuse before execution. Keep old
installations with matching binaries; automatic historical conversion is not
part of this estimate. Remove superseded paths on public activation, without
fallback decoders or parallel supported writable Station profiles.

**Exit:** real installed consumers/examples use the replacement, the removal
inventory has no unexplained survivors, and authorized Board inspection shows
definitions, progress, leases and outcomes without mutation or payload decoding.
Existing applicable disk-backed Ursula and Substrate authority/readiness/recovery
proofs pass; new distributed Stream/Queue execution remains outside this scope.

## G Finish Table commit composition and latency

Preserve the [Batch 8 scope](06-streams-queues-and-durable-runtime.md#batch-8--close-table-commit-composition-and-latency)
and coordinate implementation with M3's storage owners and M8's cohosted SQL
path. Define account-wide token uniqueness/routing first, including races across
partitions and operation kinds. Then combine eligible single-partition token
identity, mutation and original outcome in one authoritative WAL decision.
Reconstruct secondary bookkeeping only from sufficient accepted evidence;
nonjoining DDL/configuration retains its explicit separate boundaries.

Implement the [proposed TRUNCATE contract](06-streams-queues-and-durable-runtime.md#proposed-truncate-contract-for-implementation)
through a frozen empty successor, retained history and authoritative counts.
Preserve object/schema/grants and original receipts. Prove empty Tables,
concurrent writers, old snapshots and retry after a subsequent INSERT; no
DROP/recreate, implicit data expiry or new transaction coordinator.

**Exit:** original-token fault/model tests pass and matched installed results
meet **19 ms INSERT and 10–20 ms warm SELECT**, retaining the **190 ms**
comparison and fresh/post-write cases. These are inherited objectives, not
measurements of this HEAD. Passing the separate console smoke budget does not
close them. Performance uncertainty is substantial; meeting these numbers may
require more than the estimate. Any scope change must be explicit in M6.

## H Qualify the final revision and close the milestone

Freeze one committed source with matching definition and binaries. Run the full
applicable lane inventory from [suite.json](../../tests/runner/suite.json), plus
provider/deployment proofs outside those lanes and the complete M6 acceptance
matrix. Run measurements separately from heavy builds and tests. Do not assemble
a completion claim by unioning historical passes at different revisions.

Close R0–R10 against executed evidence: declarations and current rights;
Stream progress and complete reads; Queue FIFO/leases/timers/DLQ; mixed atomicity;
Station services/effects; bounded memory and collection; compatible consumer
replacement; and the inherited performance gates. Preserve negative controls
and distinguish finite models, concrete replay, process faults and provider
assumptions. Process death does not establish physical power-loss durability.

Promote supported behavior and exact limits into the public references,
components and contracts as each unit lands. Record commands, sources, raw
results and failures in qualification history. Mark M6 and the roadmap index
Completed together only when every required exit is satisfied.

## Dependencies and implementation order

The main sequence is **A → B → C → D → E → F → H**. G can proceed after A on
the shared Table/SQL owners and must finish before H. M7 lifecycle/participant
work can proceed independently, then joins F; Document integration must not
create a circular requirement for M6's private Table/KV services to finish first.
Storage memory admission, current authorization, deadlines and retained-root
traversal remain prerequisites throughout.

M12's Queue compiler/program delivery is reusable context, not a reason to
reimplement the runner or add source-language features to M6. M9/M22 own broader
language API expansion, but existing affected SDKs must migrate in F. M13 owns
continuous computations; M14 owns wider optimization and scorecards; M24/M25/M27
own new providers, replication and distributed execution. Those future scopes
do not excuse M6's existing latency, resource or recovery obligations.

For the first implementation PR, make A concrete and add B's bounded phase and
allocation attribution to the existing private driver. Preserve its workload
and independent oracle. A subsequent PR can then optimize the largest measured
cost with matching fault/recovery proofs. Revisit the remaining estimate using
that result and the completed consumer inventory before expanding services.

## Validation required for review and implementation

This plan changes repository documentation only. Run source links/fences and
whitespace checks; before opening or updating a PR, run all three baseline gates:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Implementation uses the existing registered `station-transaction`, `station`,
`direct-mixed-transaction`, `direct-queue-transfer`,
`direct-automatic-queue-transfer`, `direct-workload-token`,
`direct-workload-result`, `storage-collection`, `sql-transactions` and
transaction/Queue model tasks as relevant. Extend the owning suites for the
missing cases rather than treating their current pass as new coverage.
The measurement recipes are `test::log-runtime-baseline`,
`test::station-turn-baseline` and `test::station-transaction-baseline`; their
linked guides own arguments and controls.

Public contracts require `just check contracts` and dependent callers/bindings.
Server, SQL, console or startup changes require the `ci-experience` shell's
`console-latency-gate` and `server-sql-types`. Adapter changes also run the
[SQL interface loop](../../tasks/README.md#sql-interface-validation); Board changes
run its check and affected browser proofs. Before implementation pushes, execute
affected committed-HEAD clean lanes. Follow the
[repository gates](../../AGENTS.md#required-checks-before-opening-or-updating-a-pr)
for final contents, and report incomplete checks as incomplete. Documentation
validation supplies no new runtime qualification.
