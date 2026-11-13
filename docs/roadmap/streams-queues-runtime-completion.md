# Milestone 6 completion implementation plan

[Milestone 6](06-streams-queues-and-durable-runtime.md) · **Status: In Progress** · 2026-11-12

Milestone 6 has its database foundations and a private transactional Station
behavior. Completing it still requires the public runtime replacement, durable
services and effects, migration of existing consumers, Table commit and latency
work, and qualification of the complete system at one revision.
[PR #451](https://github.com/spoke-sh/transit/pull/451) delivers the initial shared
higher-level database transaction API and migrates the private runner to it.
The [next slice](transaction-read-ownership.md) adds owned Table/KV transaction
reads through that API. Most remaining effort sits in service migration and
proof of the complete replacement.

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
| Shared transaction API | `DirectTransactionClient` exposes explicit begin/acquire/inspect/stage/execute/settle operations; callers compose their lifecycle | Extract reusable transaction orchestration and recovery into the shared database client foundation; expose bounded owned transaction handles without Station dependencies |
| Station Batch 5 | Internal real Table/KV handler, native execution condition, retained original work and replacement recovery | Consume the shared transaction API; retain actor semantics in Station and use the private runner only for qualification. Public services, scheduling, effects and consumer migration remain open |
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

## Required API and ownership boundaries

The target dependency direction is **application → Station behavior API → shared
database transaction API → database transaction owners**. Ordinary data clients
use the same transaction API directly. SQL and managed programs share its neutral
transaction lifecycle through their existing adapters. Accepted database work
executes and recovers without a Station runner or application callback.

This is proposed implementation work. The current
[`DirectTransactionClient`](../../packages/zig/transit-catalog/src/DirectTransactionClient.zig)
supplies individual signed operations. The
[shared data context](../../packages/zig/transit-data-client/docs/context.md)
does not yet own a native transaction handle with the complete lifecycle below.
The [M9 transaction facet](09-client-foundation-and-language-apis.md#4-own-results-and-transactions-through-the-shared-context)
already owns that public client direction; M6 implements the necessary shared
foundation with it before extending Station services.

| Layer | Owns | Boundary |
| --- | --- | --- |
| Database transaction owners in Catalog/storage | Durable acceptance, snapshots/private workspaces, participant preparation, current authorization/fencing, common decision, accepted-work recovery and finalization | Remain authoritative after client or Station loss; never invoke handlers or depend on Station |
| Shared transaction lifecycle and data API | Owned transaction context, typed reads/writes/appends/settlements, statement sequence, savepoints, bounded batching, saved original identities, submission/observation, recovery and cleanup of client-owned work | Reuse the existing decision owner; preserve provisional/applied/unknown outcomes and caller-supplied I/O, budgets and recovery storage |
| SQL and managed-program adapters | SQL lowering/session attribution or program instruction semantics and invocation checkpoints | Reuse the neutral lifecycle; keep their public semantics without separate generic transaction recovery loops |
| Station behavior layer | Actor/behavior identity, native execution condition, handler dispatch, inbox/state/journal/outbox mapping, calls, timers, supervision and failure policy | Supply actor-specific bindings and typed work to the shared API; do not sequence low-level transaction RPCs or own a second commit/recovery state machine |
| Private qualification runner | Fixture composition, failure injection, independent outcome checks and measurements | Exercise the same Station/data APIs intended for consumers; contain no transaction semantics that production callers would need to copy |

Place reusable neutral caller-lifecycle machinery alongside the existing
transaction client in `transit-catalog`, and expose its owned handles through
`transit-data-client`'s existing Context/admission/recovery interfaces. Station
consumes that higher-level data API. SQL and program adapters can depend on the
neutral module without routing through their own SQL client or the Station
framework. Preserve package checks rejecting Station imports below this layer;
the database must not depend on consumer SDKs.

Client recovery means retaining and observing the original operation through
the database owner. It does not move durable commit authority into a host loop.
Station retains actor-specific association and failure disposition, while the
shared lifecycle owns transaction attempt sequencing and settlement. Local
handle closure cannot imply rollback, Queue ACK or durable read release.
Unknown outcomes never authorize rerunning a callback or creating a fresh token.
The optional native execution condition remains a neutral authority input;
ordinary transactions do not acquire actor identities or Station records.

**Decoupling acceptance:** an independent data caller and the Station fixture
must exercise the same shared lifecycle over Table/KV, log appends and Queue
settlement. The ordinary caller must build and run without Station. Removing
the private runner must leave all reusable transaction behavior available through
the shared API. Existing SQL/program adapters must retain their own attribution
and recovery guarantees while using the common transaction machinery.

## Performance qualification through the shared API

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

**Sequence after the initial extraction:** deliver the
[shared transaction read slice](transaction-read-ownership.md), then attribute
and optimize common batching, submission and recovery costs in their shared
owners before adding the full service stack. Keep the existing Station workload
as a regression oracle alongside an ordinary data-client workload through the
same API. The 12-second observation
measures the current composition; it does not establish an inherent transaction
cost or justify a Station-specific execution path. Calls/replies contracts can
be designed alongside this work; public activation waits for the API,
performance and resource gates.
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
| B. Extract the shared transaction API and migrate Station to it | 2–3 | 3–5 | M9 transaction facet; Batch 5 follow-through and R7/R9 obligations |
| C. Implement authenticated durable calls and replies | 1–2 | 2–3 | Batch 6 |
| D. Migrate timers, scheduling, names and supervision | 2–3 | 2–4 | Batch 6 |
| E. Migrate effects and retained Query consumers | 2–3 | 2–4 | Batch 7 |
| F. Cut over public consumers and remove superseded runtime paths | 3–4 | 4–6 | Batch 7 and M7 handoff |
| G. Finish Table commit composition and latency | 3–4 | 3–5 | Batch 8 / R9 |
| H. Qualify the final revision and close the milestone | 1 | 2–3 | Batch 9 / R10 |
| **Total before contingency** | **15–21** | **19–32** | |

Review units are independently assessable outcomes; a shared-definition cutover
may require several of them to merge together. The contingency range rounds the
total rather than promising an exact schedule. B's allowance covers the shared
lifecycle/API extraction, consumer migration and measured common-path work;
it is not a separate budget for optimizing a private Station orchestrator.
Re-estimate after its contract and extraction audit if the shared client work
exceeds this allowance. There is no defensible percentage complete based on
file count or merged batches: the remaining consumer and
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

## B Extract the shared transaction API and migrate Station to it

**Initial extraction merged in PR #451:** Catalog's
[`DirectTransactionSession`](../../packages/zig/transit-catalog/src/DirectTransactionSession.zig)
owns sequencing, request checkpoints, savepoints and bounded settlement. The
[data client](../../packages/zig/transit-data-client/README.md#shared-transactions)
exposes owned `Transaction` contexts, `Context.callTransaction` admission and a
`TransactionRecovery` local journal. Station adapts its existing actor control row;
SQL command preparation and managed program execution reuse neutral helpers while
retaining their service-owned recovery records. Existing wire contracts and the
stored actor Head representation are unchanged.

The independent installed Table/KV and mixed Stream/Queue fixture now uses that
shared context and journal, including lost replies, checkpoint failure, restart,
savepoints and explicit cleanup. These are executable checks, not a claim that
the full exit below has passed. Context-bound read/result ownership, bounded
multi-statement batching, shared-path cost optimization and matched performance
qualification remain follow-up work. The overall milestone estimate is retained
until those measurements and the consumer inventory justify revising it.
The [next implementation plan](transaction-read-ownership.md) scopes the read
ownership work to one PR; batching and matched cost qualification follow it.

Deliver the [ownership boundaries](#required-api-and-ownership-boundaries) by
defining the contract before extracting the shared implementation. Keep the
existing database decision, authorization and recovery contracts authoritative
throughout.

1. **Freeze the shared lifecycle and extraction map.** Audit
   [DirectTransactionClient](../../packages/zig/transit-catalog/src/DirectTransactionClient.zig),
   [SQL TransactionWork](../../packages/zig/transit-sql/src/TransactionWork.zig),
   [ApplicationTransaction](../../packages/zig/transit-query-direct/src/ApplicationTransaction.zig)
   and the [private runner](../../packages/zig/transit-station/src/transactional/Runner.zig).
   Identify common sequencing, original-work retention, submission, observation,
   settlement and cleanup; retain domain-specific behavior in its adapter.
   Specify explicit participants/cuts, typed work, savepoints, deadlines,
   authority conditions, memory ownership and pre-dispatch persistence. Distinguish
   prepared, submitted/unknown, provisional, committed/aborted and cleanup-pending
   observations using the existing typed semantics. Publish fixtures and failure
   transitions before implementation. API names remain a contract-review choice.
2. **Implement and expose the shared transaction lifecycle.** Build the
   neutral orchestration once above Catalog's existing operations, with owned
   handles in the shared data context. Reuse M9's explicit recovery store and
   reserved control admission; support service-owned durable references through
   an adapter rather than requiring a local filesystem in every host. Own bounded
   statement sequencing/batching, source/result lifetimes, saved identities,
   commit/abort observation and deterministic local cleanup. Recovery resumes the
   exact accepted work; no fresh token, callback retry, silent snapshot replacement
   or hidden polling loop. Database owners continue preparation, durable decision
   recovery and finalization independently of caller liveness. First prove the
   API through an ordinary installed data caller without Station.
3. **Migrate consumers and qualify common-path cost.** Replace the private runner's
   low-level acquire/inspect/stage/execute/settle sequencing with calls to the new
   shared API. Retain only actor binding, handler dispatch, turn mapping and
   Station failure policy in the behavior layer. Route common SQL/program
   orchestration through the same neutral machinery while preserving their
   session, invocation and checkpoint contracts. Keep the private driver as the
   fault/measurement fixture. Exercise the same shared transaction lifecycle from
   ordinary data and Station clients, then optimize the largest measured common
   costs with both consumers as regression controls.

Measure discovery, claim, retained progress, reads, staging/execution, decision,
finalization and cleanup separately while retaining end-to-end samples. Attribute
shared client, Station mapping and server work separately. Repeat with increasing
retained history under fixed payload, cache, durability and hardware/load
conditions. Coalesce bounded staging and redundant metadata/inspection in the
shared owners and reuse valid buffers/definitions. Any removed durable progress
write must leave sufficient accepted evidence to recover the exact original
claim, statement and decision after loss at that boundary.

Add recoverable claim payload-read closure through shared data operations after
the turn and required replay dependencies settle. Station supplies the decision
that its actor-specific use is complete. ACK, local result disposal and durable
read release retain separate lifetimes; replacement must still recover every
payload it needs.

**Exit:** independent ordinary and Station callers pass lost-reply, conflict,
revocation, stale-generation, expired-lease, cancellation, savepoint and recovery
tests through the shared lifecycle. The ordinary client has no Station import,
actor bootstrap or private runner dependency; applicable optional-actor guards
are tested separately. The runner contains no independent transaction settlement
loop, and SQL/program recovery semantics remain intact. Existing installed
oracles and larger-than-cache population/history tests pass within unchanged
budgets. Matched measurements explain dominant costs and satisfy the reviewed
replacement budget. Report the larger 1 KiB/six-key workload separately, retain
failed/unresolved attempts, and measure allocations after warmup; a memory
ceiling alone does not establish the zero steady-state allocation goal.

## C Implement authenticated durable calls and replies

Freeze the replacement for [Station message origins and waits](../../contracts/STATION_V1.md)
before adapters. Persist correlation, original accepted sender/destination,
wait state and terminal disposition in declared data. Bind actor-origin evidence
to the native execution condition and common decision; a payload's claimed PID
or a similar application row cannot authenticate a call.

Use B's shared transaction API to compose receiver ACK, state, journal and
reply/outbound intent in one decision. Station supplies correlation and actor
semantics without reimplementing transaction sequencing or recovery.
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
restart recovery on declared data through the shared data/transaction APIs.
Reuse Queue waits and timing owners with bounded registration/recheck,
saturation recovery and joined cancellation.
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
Compose their database changes through B's shared API; connector-specific
attempt and unknown-outcome policy remains with the connector.
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
Expose Station behavior APIs above the shared transaction layer; do not export
the private runner as another user-facing runtime or require SDKs to copy its
former orchestration.

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
Require the independent data-client and Station qualification journeys to use
the same shared transaction lifecycle, with package checks enforcing its
independence from Station.

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

B's order is shared contract → shared implementation and ordinary caller proof
→ thin Station consumer and common-path qualification. C–F depend on that API;
their new services cannot accumulate another low-level transaction loop while
waiting for extraction.

M12's Queue compiler/program delivery is reusable context, not a reason to
reimplement the runner or add source-language features to M6. M6 B and M9's
transaction facet share one implementation and contract; M6 does not wait for
M9's full language redesign. M9/M22 own broader language API expansion, while
existing affected SDKs migrate in F. M13 owns continuous computations;
M14 owns wider optimization and scorecards; M24/M25/M27
own new providers, replication and distributed execution. Those future scopes
do not excuse M6's existing latency, resource or recovery obligations.

For the first implementation PR, make A concrete and deliver B's shared API
contract, extraction map and executable lifecycle fixtures. Preserve the existing
private driver's workload, independent oracle and phase attribution as regression
evidence. Next implement the shared lifecycle with an ordinary data caller, then
migrate Station and optimize measured common costs. Revisit the estimate after
the extraction audit and these measurements before expanding services.

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
Add the independent shared-transaction client journey and package dependency
checks with B, using real transaction owners and the same fault matrix as the
Station composition. A wrapper compiling over the old runner does not satisfy
the decoupling gate.
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
