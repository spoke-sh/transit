# Milestone 6 transactional Station implementation plan

[Milestone 6](06-streams-queues-and-durable-runtime.md) · **Status: In Progress** · 2026-11-11

Implement **Batch 5: one private transactional Station behavior**. A handler
consumes one declared Queue input, changes Table and direct KV state, appends a
replay journal entry and publishes an output intent through one standard database
transaction. An operator can inspect the original input, actor definition,
activation, transaction decision and exact resulting state after worker loss.

The slice first establishes an authoritative actor execution guard at the common
decision boundary. Queue lease ownership is a separate condition. It then proves
a real detached handler against disk storage and signed callers. Keep the runner
internal to its package and qualification harness until the service and consumer
cutover in Batches 6–7; this slice does not switch installed Station applications.

**Source basis:** local `main` and `origin/main` at
`bc849156ad91e9f022ad9a9204c47f654a209a57`. At that basis the shared definition was
`316801f7fa965d47bc3501e8c601fa0136073fd417dabd5dcd0d8b64fdf368da`
(`transit.v1.queue-checkpoints-mixed-sql.2026-11-10`). The implementation and
consumer handoff are recorded below; M6 remains **In Progress**.

## Why this slice is next

The [November 10 slice](06-streams-queues-and-durable-runtime.md#next-slice-implementation-plan--2026-11-10)
landed as merge `134cea87f` (#443). Queue metadata checkpoints, incremental
resident state, mixed SQL lowering and a concrete Queue model replay driver are
present. The next feature dependency in the milestone is the Station runner,
followed by durable services and coherent consumer replacement. Table write
lifecycle work and integrated completion remain Batches 8–9.

Merged implementation does not close the entire earlier qualification matrix.
Unit 0 below carries forward the relevant mixed-decision, DLQ, collection and
resource gates. In particular, the [Queue model owner](../../tests/verification/models/README.md#finite-queuepartition-lease-and-turn-commit-model)
describes nine negative-control traces and five concrete schedules over real
owners. It does not establish exhaustive model-to-runtime correspondence or
physical crash durability. Preserve that scope when extending it for actors.

The subsequent managed Queue-program implementation (#444, merge `f0a112ce3`)
already retains invocation identities and uses standard transactions. Reuse the
underlying catalog/caller primitives, but retain the distinction between a typed
program executor and Station's arbitrary detached behavior handler. Program
activation and invocation fences do not establish native PID ownership.

## Current owners and the missing boundary

| Owner at the source basis | Existing behavior | Work for this slice |
| --- | --- | --- |
| [GenServer](../../packages/zig/transit-station/src/GenServer.zig), [Turn](../../packages/zig/transit-station/src/Turn.zig), [Station contract](../../contracts/STATION_V1.md) | Detached handlers use native mailbox inputs, one associated writable resource and bounded native turns; read failure poisons the proposal | A private runner over declared data, preserving handler isolation, failure semantics and original recovery |
| [Transaction types](../../packages/zig/transit-protocol/src/Transaction.zig), [DirectCatalog](../../packages/zig/transit-catalog/src/DirectCatalog.zig), [decision log](../../packages/zig/transit-storage/src/TransactionDecisionLog.zig) | Common Table/KV/Stream/Queue decisions, immutable deadlines, exact lease checks and current policy; `Begin` carries no actor execution condition | Freeze and enforce native execution ownership through the existing common decision, without another commit protocol |
| [LocalCatalogPolicy](../../apps/transit-node/LocalCatalogPolicy.zig), [DataAuthority](../../packages/zig/transit-backend-local/src/DataAuthority.zig), [PublicationGuard](../../packages/zig/transit-storage/src/PublicationGuard.zig) | Current native policy and resource lifetime checks hold shared authority exclusion through data publication | Compose the actor condition with this fence and prove its ordering against ownership changes, suspension and retirement |
| [ApplicationTransaction](../../packages/zig/transit-query-direct/src/ApplicationTransaction.zig), [managed invocation owners](../../packages/zig/transit-query-direct/README.md) | Explicit participant selection, original invocation recovery, transaction checkpoints and Queue ACK through public data APIs | Reuse public transaction and record interfaces; avoid making Station depend on the application-program interpreter or copying its recovery state machine |
| [Catalog record owners](../../packages/zig/transit-catalog/README.md), [DirectStorageGraph](../../packages/zig/transit-catalog/src/DirectStorageGraph.zig) | Transaction candidates, replaceable progress and protected originals have distinct retention/closure rules | Register actor bindings, pending turns, claims and journals according to their actual lifetimes |
| [Installed handler baseline](../../tests/performance/load/station_turn.md) | Real 128-byte native state transition and one outbound intent, with exact state/output and restart oracles | Repeat a matching control and compare the transactional runner; add a separate larger-state correctness profile |

## Scope and review decisions

Use one local fenced authority, one catalog and `branch == 1`. Select exact
Table/KV objects and Stream/Queue partitions before acquiring a serializable
cut. A shared `key_fifo` inbox routes a stable actor key to one partition; the
first runner processes one input per turn. Independent actor keys may progress
under explicitly bounded active-work limits. Idle actors reside in paged data.

The implementation uses these three choices:

1. **Retain native PID authority.** Bind the declared actor to its existing
   realm/PID and immutable behavior definition. Use a neutral native execution
   condition on standard transactions, checked by the native authority. An actor
   row or a client progress lease must not become a second ownership authority.
2. **Prove the Table/KV runner privately first.** Use a real compiled Zig handler
   and test-only composition. Do not add a public runtime selector, new SDK family,
   SQL actor syntax or fallback between writable Station engines.
3. **Keep one turn to one decision.** Include input ACK, all state changes,
   journal and output intents in that decision. Retain exact uncertain work before
   dispatch and resolve it before handler retry or successor input processing.

Calls/replies, timers, registries, supervision, external effect dispatch, courier
removal, SDK migration and public activation remain Batches 6–7. Partitioned
Document participation remains [M7 C5](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work);
its presence in neutral types does not make it executable. The current SQL row
Document is a separate Table-backed profile and cannot satisfy that handoff.
General concurrency, distributed placement, writable branches, new latency
targets and automatic data migration are outside this slice.

## Proposed lifecycle and authority contract

### Definitions and retained identities

Specify the binding and transition fixtures before adding the runner. These are
proposed record roles, not new public API names:

| Record | Identity and contents | Lifetime and inspection |
| --- | --- | --- |
| Actor binding | Realm/PID, exact behavior definition, catalog/branch, inbox routing key, state objects, journal and outbox interpretations, explicit dependency registrations | Immutable binding plus permanent retirement evidence; neither name reuse nor collectible progress can recreate it |
| Activation observation | Native owner principal, generation, lifecycle and executable binding used to authorize this attempt | Observation of native authority, never a grant or a locally renewable lease |
| Input binding | Original enqueue operation and row ordinal, Queue object/partition, complete claim and lease, retained payload reference and authenticated origin | Retain before handler dispatch; release payload only after original decision and required replay retention are settled |
| Pending turn | Actor/definition/input binding, exact transaction begin/token, participant set, staged statement identities and frozen commit request | Discoverable by the replacement worker before it claims or executes fresh work; protected originals and replaceable progress use their existing distinct owners |
| Committed journal and output | Original turn/input/definition, resulting state basis, journal payload and immutable destinations/output identities | Published by the same decision as ACK and state; a post-commit inspection joins the original transaction receipt rather than embedding a not-yet-known commit LSN |

Declarations and dependency registration do not activate a worker. Bootstrap
must recover original partial publication and register dependencies explicitly.
Changing a name cannot rebind accepted work. State initialization and the first
input's state/output transition commit together; recovery cannot initialize it
again. Default retention remains unlimited. Explicit actor retirement, dependency
removal, payload closure and physical collection are separate operations.

### Execution condition at the common decision

Extend the neutral transaction contract with a frozen native execution condition
binding the actor's realm/PID, owner principal and generation, together with the
behavior binding needed to reject a different executable. Freeze it before
transaction admission; include it in canonical request, token fingerprint,
persisted begin, attempt and decision verification. Ordinary database transactions
remain independent of Station and need no actor condition.

The pending-turn binding must require that exact condition on every saved turn
attempt. Removing or substituting it conflicts with the original commitment.
Ordinary authorized data writes cannot manufacture actor-turn or actor-origin
evidence merely by writing similarly shaped application rows.

The native authority owns the validation. Compose it through the existing
`PublicationGuard` and the decision's verification callbacks; core, Catalog and
storage must not import Station. Reuse the existing native process eligibility,
current execution grant, ownership, suspension/retirement and lifetime checks.
Do not copy selected checks into the worker or accept its cached observation.
Add any missing neutral guard interface to its owning contract first.

Prove that ownership/lifecycle changes cannot interleave between the final
check and `TXDEC1` publication. The local implementation must document the lock
order and hold the native authority fence for that interval; a preflight read or
policy epoch alone is insufficient when an ownership change leaves policy
unchanged. Preserve the existing participant, statement-privilege, Queue lease,
trusted-time and `Transaction.Deadline` checks under that same publication
boundary. No mailbox turn or native scalar-state mutation coordinates this work.

A committed decision remains committed after replacement, retirement or later
lease expiry. An authorized recovery owner finalizes that decision without
running the handler or demanding the old activation be live. If no decision
exists, stale activation cannot commit the prepared attempt. Explicitly resolve
or abort that original attempt before retry policy permits fresh work. Current
authorization still governs every protected inspection and payload disclosure.

Specify recovery authorization separately from the original executor identity.
Reuse the existing delegated executor/control facilities where their contracts
permit inspection, abort and finalization; add a narrowly scoped native recovery
operation if they cannot cover a rotated worker. Prove replacement with a new
principal/key, not only a restarted process using the old key. Recovery must not
re-sign an uncertain original, rewrite its principal or use administrative
credentials to bypass original data permissions for a new commit.

### Authenticated inputs and detached handlers

The first harness accepts external cast-like Queue inputs. Derive caller
provenance from the original authority-accepted enqueue evidence, not a row's
claimed sender/PID. Reject forged or inconsistent attribution. Actor-origin
calls/replies require Batch 6's destination and correlation contract; do not
pretend a generic Queue payload already supplies that protocol.

The handler receives bounded typed input, private Table/KV reads and writes,
and journal/output builders. It receives no signing key, raw provider access,
transaction settlement handle or network dispatcher. Current native trust limits
still apply: this interface is not a sandbox for arbitrary native code.
Any read failure poisons the entire draft even if application code catches it.
Track source cuts and read-your-writes through the shared transaction workspace.

Before dispatch, persist the original claim and transaction binding in protected,
discoverable records. Stage all statements under that transaction, then freeze
and save its commit operation before sending it. Host loss after any dispatch
resolves the original operation. Loss of the reply cannot cause a new token,
changed participant selection or recomputation of a possibly committed turn.

For handler failure, preserve the existing distinction between `block_input` and
`stop` in the replacement contract. A failed body publishes none of its state,
journal, outputs or ACK. Record a bounded, recoverable blocked disposition only
after a proved abort; include that record in recovery discovery. Queue expiry
does not clear the actor's blocked status. An explicit authorized retry may
select new work only after original settlement. A stopped host retains unresolved
work and does not claim that stopping rolled back the transaction.

### Resource and collection boundaries

Budget active actors, input bytes, read/statement/output counts, workspace bytes,
pending recovery pages and per-tick work. Use the existing M3 data/control/
maintenance/collection admission owners. Backpressure must leave control and
original-decision recovery able to progress. Growing actor count or inbox backlog
must not allocate a resident entry per retained actor or message.

Reuse scratch arenas across bounded turns/pages with `.retain_capacity`; retained
handler outputs and saved work must own their bytes beyond scratch reset.
Meter the runner and native service separately. Freeze actual numeric budgets
with the baseline fixture before measuring; do not raise them or relax durability
to obtain a passing result.

Use `TXR1` only for transaction-owned candidates, `CPR1` for replaceable progress,
and `SOR1` for protected original work where their contracts apply. A durable
actor identity is not replaceable progress. Register every new retained root
with the owning traversal before collection can see it. Include staging after
the collector cut, late writes after closure, open claim payloads, pending
preparations, committed journals and old readers in mark/grace/sweep tests.

## Ordered implementation units

| Unit | Implementation and owners | Review exit |
| --- | --- | --- |
| **0. Establish the prerequisite evidence and comparison** | Reconcile #443 against its acceptance matrix; run mixed/DLQ/Queue model and retained-root controls at the selected source. Repeat the real native Station baseline using its existing budgets. Correct relevant stale mixed-SQL availability text in the public Streams reference with its current owner. | Source/definition/commands/outcomes distinguish passing checks from open gates. No unresolved prerequisite is relabeled as a pass. Measurements run without overlapping heavy work. |
| **1. Freeze actor bindings and the neutral execution guard** | Protocol/core, Catalog transaction requests and local native authority. Specify fixtures, signed identity, retirement/replacement races, recovery after decision, lock order and a concrete migration inventory. Update exact contracts alongside the implemented primitives. | Signed public transaction tests reject a forged actor, missing condition on guarded work, stale generation, retired/suspended actor and changed behavior binding. A decision ordered before replacement finishes under recovery authority. |
| **2. Add private lifecycle and recovery composition** | Internal Station modules over public Catalog/client interfaces; use existing dependency, token, protected-record and transaction owners. Bootstrap one actor, discover pending work, retain input and original operations, and expose bounded inspection to the harness. | Worker loss at every record/claim/begin boundary recovers the same identities. Incomplete discovery prevents fresh execution. Collection preserves originals and permanent actor identity. |
| **3. Execute one real detached behavior** | Private Station runner and turn builder, compiled fixture and shared Table/KV/log clients. Stage state, journal, output and exact ACK in one standard transaction. Implement poisoned reads, explicit failure disposition and bounded shutdown. | The 128-byte workload and a separate workload with a value above 256 bytes and more than four changed keys satisfy independent state/input/output oracles. Table and KV both participate. No partial result is externally visible. |
| **4. Prove faults, resources and the handoff** | Extend formal replay with actor guards; add registered installed disk/signed-caller schedules, collection pressure, competing workers and comparison reporting. Publish supported internal scope and evidence with their owners. | The acceptance matrix below passes at one committed revision. The runner remains unexposed. Batches 6–7 receive a tested primitive and concrete consumer/removal inventory. |

Order is **0 → 1 → 2 → 3 → 4**. Contract and fixture drafting can proceed while
Unit 0 investigates existing failures; closing the slice requires its relevant
prerequisites. Split commits by these review boundaries, keeping dependent
format/consumer updates atomic. Register any new proof driver in
[tasks](../../tasks/test.just), [suite ownership](../../tests/runner/suite.json)
and the appropriate test guide; task names for new proofs are assigned with the
implementation, not presented here as existing commands.

## Required acceptance evidence

| Case | Required oracle |
| --- | --- |
| Successful turn and initialization | Independent caller reads verify exact Table/KV bytes, one journal entry, one outbound intent and the original Queue ACK, all attributable to one decision. Restart repeats the oracle without handler execution. |
| Competing and stale workers | Two workers for the same actor cannot both publish; a live Queue lease does not rescue a superseded generation. Another actor key can progress within the configured limits. |
| Lifecycle and policy races | Replacement, suspension, permanent retirement, grant revocation and definition change between prepare and decision reject new commitment. A decision already accepted remains recoverable; protected reads still require current rights. |
| Lease and clock fences | Expired but unreassigned lease, changed lease epoch, time uncertainty/regression and transaction deadline expiry prevent commit without publishing a partial turn. No automatic renewal changes frozen accepted work. |
| Lost requests and replies | Fail before/after claim, original-record attachment, BEGIN, each staged statement, prepare, decision, finalize and progress settlement. A replacement uses original identities and reads the original outcome before handler retry. |
| Failed body and abort | Poisoned read, caught read error, handler exception, conflict and quota refusal leak no state, output or ACK. Proved abort and unresolved outcome remain distinct; blocked disposition survives replacement and lease expiry. |
| Scratch and bounded work | Reset scratch between pages/turns, exceed every configured work/byte ceiling and grow durable actor/backlog populations beyond resident capacity. No dangling output bytes, silent truncation, total-cardinality array or recovery starvation. |
| Checkpoint and collection | Checkpoint/reopen and mark/grace/sweep during staging and pending/committed decisions preserve exact original payloads and results; a known unrelated orphan is reclaimed. Receipt lookup remains valid after permitted payload closure. |
| Provenance and effects | Forged sender metadata cannot gain authority. Output destinations remain immutable. Replay/finalization dispatch zero external effects; this slice measures intent publication only. |
| Formal and concrete boundaries | Add actor-generation/retirement/decision-order cases and guard-removal negative controls over real owners. Report finite model, selected replay, installed process faults and measurements separately; no power-loss or unbounded fairness claim. |

Repeat the baseline's three warmups and twenty measured turns for its p95
comparison, same input/state/output oracle and completion boundary. Retain every
failed/refused/unknown attempt; one missing terminal sample fails the run.
Report the larger-state workload separately. Compare complete turn time, client
allocations, measured server work, WAL/object requests and recovery cost where
instrumented; mark unavailable counters explicitly. Retain the earlier
[Station measurements](../history/qualification/performance.md#installed-station-handler-baseline--2026-11-01)
as historical evidence, not a current control or a new absolute latency budget.

## Compatibility and later cutover

Unit 1's persisted/signed transaction condition requires a current-v1 definition
cutover when it changes compatibility. Regenerate schema/ABI resources, signing
fixtures and dependent callers together, even while the Station runner is
private. Do not default a missing persisted condition to a valid current value.
This generic transaction change does not advertise replacement Station behavior.

Keep the current native Station contract and its installed consumers coherent
until Batches 6–7 replace them together. The private implementation is not a
second supported writable profile. The later cutover removes superseded
GenServer/Turn persistence, private Table helpers, Station bindings/SDK actions,
connector consumers and courier roles only after their replacements pass.
Preserve the separate Catalog `DirectTableBridge`. Incompatible saved work and
history refuse before execution; prior installations retain matching binaries.

The handoff inventory must name each old owner, replacement, stored format,
caller/SDK/example/controller, public documentation and required proof. Include
M7's Document participant/consumer gates, native origin and call correlation,
effect uncertainty and Queue wait/shutdown scheduling. Batch 5 completion does
not remove these obligations or complete M6.

## Validation and review deliverables

For this documentation change, run local link/fence and whitespace checks plus
the three repository baseline gates before opening a PR:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

For implementation, run owning package tests and the following registered
prerequisites inside the pinned development shell, selected by changed scope:
`just test direct-mixed-transaction`, `just test direct-queue-transfer`,
`just test direct-automatic-queue-transfer`, `just test direct-workload-token`,
`just test direct-workload-result`, `just test storage-collection`,
`just test queue-lease-transaction-model`, `just test transaction-decision-model`,
`just test transaction-workspace-model` and `just test station`. Add the new
runner's real installed/fault proof; the current Station suite does not test it.

Public protocol changes require `just check contracts` and dependent binding,
SDK and browser checks. Node/server/startup changes require
`nix develop .#ci-experience --command just test console-latency-gate` and
`nix develop --command just test server-sql-types`. Use the SQL interface loop
if adapters change. Before implementation pushes, run affected committed-HEAD
clean lanes: `core`, `storage-query`, `formal`, and `installation-ui`, plus the
dependent SDK lanes identified by the actual contract diff. Follow the
[repository gates](../../AGENTS.md#required-checks-before-opening-or-updating-a-pr)
and [task ownership](../../tasks/README.md); skipped or incomplete checks cannot
close a unit.

Review delivery consists of the frozen contract/fixtures, source-linked migration
inventory, independent state/input/output oracle, fault/collection evidence and
matched baseline report. Promote implemented semantics and limits to
[Station](../handbook/reference/station.md), its package/contract owners and the
relevant native transaction/authority references. Record executed results in
[qualification history](../history/qualification/README.md) with the exact
source and definition. Keep plans and future public activation in this roadmap.
## Implemented ownership and later consumer cutover

The [private package composition](../../packages/zig/transit-station/README.md#private-transactional-behavior-composition)
implements the neutral execution condition and one detached Table/KV behavior.
Its public authority is the current native PID; the declaration and progress row
are data. No public Station selector or SDK action exposes this composition.
The current-v1 definition changes to
`cca0376c55733fd553a43a187fee9e8c379ab1b14007009a06bfcab3a517fec2`
(`transit.v1.native-transaction-execution.2026-11-11`). Signed outer request
prerequisites and persisted BEGIN conditions are required nullable fields;
missing old fields do not acquire the current definition implicitly.

| Existing owner / stored boundary | Replacement and remaining contract | Consumers and required handoff proof |
| --- | --- | --- |
| [GenServer](../../packages/zig/transit-station/src/GenServer.zig), [native Turn](../../packages/zig/transit-station/src/Turn.zig), native mailbox/view/state records | Private Actor declaration (`STA1` within protected `SOR1`), control KV discovery, ordinary transaction workspace and `TXDEC1`; native ownership remains authoritative | Public Station host, bindings, every language SDK and ledger/work-items examples require one coherent Batch 7 cutover. Installed pending/decision recovery must precede removal of native turn persistence |
| [Frame](../../packages/zig/transit-station/src/Frame.zig), [Waiting](../../packages/zig/transit-station/src/Waiting.zig), [Registry](../../packages/zig/transit-station/src/Registry.zig), [Supervisor](../../packages/zig/transit-station/src/Supervisor.zig) | Batch 6 correlations, authenticated actor-origin evidence, durable calls/replies, waits, timers, names and supervision over declared data | Duplicate/late replies, receiver replacement, timer registration/expiry, saturation and joined shutdown remain distinct from generic Queue rows |
| [Station Table reader](../../packages/zig/transit-station/src/TableReader.zig), [Table write](../../packages/zig/transit-station/src/TableWrite.zig), [Query](../../packages/zig/transit-station/src/Query.zig) and framework block records | Use direct Table/KV and query owners for replacement consumers; preserve the separate Catalog `DirectTableBridge` | Migrate old private Table consumers and their retained-reader/publication proofs before removing their formats; the new handler does not migrate existing stored framework data |
| [Document service](../../packages/zig/transit-station-document/README.md) and native Document records | M7 C4/C5/C7 supply public lifecycle, partition-aware transaction participation and consumer replacement | Document workers, query adapters, connectors and installation must pass those gates; a Table-backed SQL Document does not substitute |
| [Station bindings](../../packages/zig/transit-station-bindings/README.md), [host](../../apps/transit-station-host/README.md) and language SDKs | Generated current-v1 definitions change together now; public handler APIs remain native until Batch 7 | Shared conformance and scripting/systems/managed lanes preserve current consumers. Future changes must move API, ABI, fixtures, examples and documentation together |
| [Delivery](../../apps/transit-delivery/README.md), Station HTTP/gRPC connectors and captured effect records | The private runner publishes an immutable output intent only. Batch 6 supplies dispatch, destination/correlation and original remote-outcome recovery | Duplicate dispatch, replay, cancellation and uncertain remote outcomes need connector-specific qualification before courier removal |
| [Runtime controller](../../apps/transit-runtime-controller/README.md), provider bindings and installation | Native code/workload/generation conditions already fence data publication; provider observations remain physical lifecycle evidence | Managed activation, worker scheduling and bootstrap/replacement profiles need their own installed proofs before public activation |

The [installed runner driver](../../tests/runtime/station/transactional.py),
[decision model](../../tests/verification/models/README.md#finite-transaction-decision-model)
and [comparison](../../tests/performance/load/station_turn.md#private-transactional-comparison)
keep their own execution scopes. Current behavior and numeric limits live with
the package and handbook, while executed results belong in qualification history.
Broader actor scheduling, automatic accepted-claim payload release, native-origin
call correlation and public replacement remain later work; M6 stays In Progress.
