# Milestone 13: lowered DATAFLOW SQL implementation

[Milestone 13](13-sql-and-dataflows.md) · [Roadmap](README.md) · **Status:** In Progress

**Plan basis:** local `main` at
`5df71dc890d24d1587f1d3e8df3688d931a04c81`, 2026-11-10. This is an implementation
proposal, not executed runtime evidence or a change to M13's **In Progress**
status. Other worktrees and unmerged changes are not prerequisites satisfied by
this baseline.

Implement the executable, lowered SQL form of `DATAFLOW`: an application submits
SQL through the ordinary service, publishes an immutable computation, explicitly
authorizes and activates it, and inspects its original work and outcomes after
disconnect or replacement. M12 owns `.transit` composition, static language
semantics and SQL emission. M13 owns admission and execution of that emitted SQL.
The installed runtime must work with the source packages and compiler absent.

The next delivery is **ordered Queue DATAFLOW SQL over the existing typed
application runtime**. Preserve the installed finite Table DATAFLOW profile, then
extend relational dataflows through complete-history consumption and incremental
execution. Do not make a new compiler, a new workflow engine or completion of
DBSP a prerequisite for executing the already defined ordered SQL body.

This plan supplies the current lowered-SQL delivery order. The milestone's
[R0–R10 packages](13-sql-and-dataflows.md#work-packages-and-dependencies),
[SOURCE plan](13-sql-and-dataflows.md#create-source-implementation-plan--2026-11-05)
and [downstream application plan](downstream-application-language.md) retain their
broader acceptance obligations and earlier evidence. Historical references to
M12 as the dataflow owner predate the insertion of the source-language milestone;
this plan uses the current numbering throughout.

## First implementation slice

The initial implementation adds the standalone public-data SQL path from unit 1
and composes the existing installed host from unit 3. `ApplicationSql` resolves
native definitions; `ManagedOperations` retains typed Queue declarations and
explicit-role controls; EXPLAIN and publisher-scoped SHOW expose dependencies
and observed progress. The native name reservation selects the computation
object, and rejected publications stop recurring initialization. Control
settlement distinguishes a lost reply from a saved CAS fenced by later progress.

The public contract is the
[installed SQL profile](../../contracts/APPLICATION_PROGRAM_V1.md#installed-sql-profile).
The owning installed proof extends
[`server_managed_tables.py`](../../tests/interfaces/installation/server_managed_tables.py)
with lowered bodies, original publication/control response loss, changed-token
refusal, two atomic boundaries, suspend/restart/resume and retirement. Native
mixed-participant and cancellation proofs remain with
[`managed_table.zig`](../../tests/catalog/tables/managed_table.zig).
Registration of these cases is not an executed pass; qualification results belong
in the PR and proof ledger after the gates finish.

This slice does not close units 1–4 or M13. Migration dependency evidence,
independent-reader inspection, broader capability/denial schedules, protected
host composition, emitter correspondence and retained-history/incremental
execution keep their gates below. Unsupported installed host features reject
before SQL admission rather than publishing an unexecutable program.

## Execution boundary and acceptance journey

Two SQL profiles already have different owning semantics:

| Lowered SQL | Current boundary | M13 responsibility |
| --- | --- | --- |
| `CREATE DATAFLOW name INTO output AS SELECT ...` | Installed native cohosted SQL; one ordinary Table source, finite recomputation and retained completed revisions | Preserve its lifecycle and readers; qualify combined faults/resources, then add admitted history and incremental profiles |
| `CREATE DATAFLOW name FROM QUEUE input AS item ... AS BEGIN ... END` | Fuze parser, typed declarations, native invocation/transaction owners and bounded service discovery exist; SQL installation and deployed host composition remain incomplete | Connect ordinary SQL admission, migration planning, lifecycle controls, inspection and the configured host to those owners |

The [managed computation contract](../../contracts/DATAFLOW_V1.md) owns shared
identity and lifecycle. The [ordered program contract](../../contracts/APPLICATION_PROGRAM_V1.md)
owns instruction, Queue, continuation, transaction and effect semantics. Use a
typed computation-kind distinction through preparation, saved operations,
inspection and recovery; never try one executor after another on failure.
Shared lifecycle does not make a Queue invocation a recomputed relation.

The first installed acceptance case is a synthetic, public-data Queue program
submitted as SQL. It uses a predicate, a typed read, `LET`, `REQUIRE`, one
`BEGIN ATOMIC` block, a conditional state mutation and a Stream append. The first
committed checkpoint settles the exact input lease. An independent reader verifies
the mutation, append, original invocation and common decision. Restart during an
uncertain decision resumes the same input and instruction identities. A second
program body changes the computation's behavior, proving the service executes
the declaration rather than a fixed test handler.

Subsequent increments add multiple atomic boundaries, failure continuations,
explicitly composed effects and response handoff. The existing
[application SQL corpus](../../tests/fixtures/application-programs/README.md)
is a conformance input with frozen provenance, not a currently runnable example.
Use its real bodies once their owners are installed; do not simplify that fixture
or substitute provider-specific orchestration to obtain a pass. The full browser
journey has additional ingress/publication gates owned by the downstream plan.

## Source audit and recent milestone context

| Delivered foundation or source finding | Reuse and remaining integration gate |
| --- | --- |
| [M12](12-application-modules-compilation-and-testing.md), #437/#438/#441: recursive Table builds, isolated Table tests and independent source grammar checks | Generated SQL executes through ordinary owners. Current `transit build` rejects Queue/effect programs; do not claim it already emits the broader DATAFLOW profile. M13 can qualify handwritten canonical SQL first, then M12 adds emission and emitter/runtime correspondence for that same profile. |
| [Application foundation](downstream-application-language.md), #435 | `ApplicationProgram` parses, binds and encodes ordered instructions; `ManagedApplication`, `ApplicationInvocation`, `ApplicationExecution` and `ApplicationRecovery` retain and execute original work. `DatabaseRuntime.applicationStep` already discovers it. Extend service composition; do not implement another invocation scheduler or instruction interpreter. |
| [`ManagedSql`](../../packages/zig/transit-sql/src/ManagedSql.zig) and [`ManagedOperations`](../../packages/zig/transit-sql-service/src/ManagedOperations.zig) | SQL CREATE currently requires `INTO ... AS SELECT`; controls have no executor-role operand. Saved `DFS1` requests contain `ManagedTable.Declaration`. Add ordered-program variants and role binding before admitting Queue SQL. |
| [`MigrationRunner`](../../packages/zig/transit-sql-service/src/MigrationRunner.zig) and [`MigrationDataflow`](../../packages/zig/transit-sql-service/src/MigrationDataflow.zig), #404/#435 | Finite DATAFLOW migrations and compound framing exist. A Queue body is framed as one step but is not installed by that fact. Extend exact dependency evidence beyond source/output Tables; preserve original step receipts and reviewed-plan drift checks. |
| [M4](04-statement-results-and-consumption.md) and [M5](05-transactions-and-atomic-composition.md), Completed for their recorded profiles | Use existing command outcomes, finite result readers, common decisions, original transaction recovery and provisional statement semantics. SQL activation completion is not invocation completion. M5's local Table proof does not independently qualify every mixed participant. |
| [M6](06-streams-queues-and-durable-runtime.md), #428/#436 | Native acquisition predicates, mixed participants and finite `STREAM_SLICE` over hot WAL/sealed `.tseg` are present. Reuse `QueuePredicate`, exact lease ACK and `DirectStreamSliceScan`. Mixed SQL, bounded Queue metadata checkpoints and the full Station migration retain their own gates. A finite Stream pin does not establish continuous history coverage. |
| [M7](07-document-storage-and-station-decoupling.md), native row Document integration | `ApplicationTransaction` admits the supported row Document profile with native policy/read guards. Qualify those exact operations when exposed; do not wait for every Document feature or infer general ordered-tree/change-feed support. |
| [M3 allocation admission](03-live-storage-and-sql-cutover.md#next-slice-implementation-plan--2026-11-08), #431 | Charge integration to `DirectStorageMemory`/`DirectRequestMemory` and preserve separate control, maintenance and collection reserves. This is a delivered allocation boundary, not evidence that application continuations, protected bodies and every query buffer are covered. |
| [M8](08-gateway-architecture-and-protocol-ingress.md) and [M9](09-client-foundation-and-language-apis.md) | Reuse cohosted SQL, account activation fences, operation recovery, shared client contexts and command lifetimes. Complete inherited whole-program deadlines and host cancellation where required; no per-dataflow timer/thread pool or client-side workflow coordinator. |
| [M10](10-standards-and-catalogs.md) and [M11](11-indexing-and-access-paths.md) | Exact historical interpretation and current constraints are foundations; secondary access paths and phased rewrites remain separately gated. Bounded scans can establish semantics without waiting for all index work. |
| [Finite dataflow contract](../../contracts/DATAFLOW_V1.md) | Reuse SOR1 original staging/closure, CPR1 progress, TXR1 candidates, DFR1 retained manifests and forward DFL1 links. `ManagedTable.evaluate` still drains an executor within one step. Batching is not a fairness or allocation proof. |
| [SOURCE/SINK contract](../../contracts/SOURCE_V1.md), #410/#419/#435 | Declarations, owned capture storage/readers and sink profiles exist. `ApplicationEffectRuntime` is a physical HTTP component requiring explicit composition. SOURCE polling and installed application dispatch are separate unfinished journeys; do not label either absent component work or installed execution. |
| [`FuzeDelta`](../../packages/zig/transit-fuze/src/FuzeDelta.zig), [`AnalyticalSql`](../../packages/zig/transit-fuze/src/AnalyticalSql.zig), [`VectorUdf`](../../packages/zig/transit-fuze/src/VectorUdf.zig) | Fixed-size Z-sets, spill counters and an instruction-array Wasm helper remain component mechanisms. They do not establish durable arrangements, production analytical SQL or a validated Wasm binary runtime. |

Existing proof accounts retain their exact revisions and limits: [finite managed
Tables](../history/qualification/query.md#managed-finite-table-lifecycle--2026-11-01),
[owned original closure](../history/qualification/query.md#owned-original-staging-and-closure--2026-11-03),
[SOURCE capture storage](../history/qualification/catalog.md#owned-source-capture-storage-and-readers--2026-11-07),
[storage admission](../history/qualification/storage.md#aggregate-local-storage-allocation-admission--2026-11-08)
and [isolated Table tests](../history/qualification/interfaces.md#isolated-application-table-tests--2026-11-10).
Merged implementations and those source-specific passes do not establish a
combined pass at this plan's baseline. The earlier failed managed-performance
campaigns remain part of the [measurement baseline](13-sql-and-dataflows.md#qualification-and-measurement-baseline).

## Contracts to settle before exposing SQL

1. **Typed dispatch and names.** Define how one scoped DATAFLOW name resolves its
   computation kind, immutable definition and control owner. Concurrent attempts
   to publish both kinds under the same name must conflict at native acceptance.
   Use the existing catalog/dependency boundary; do not search both token accounts
   and choose the first match. Define SQL operation and inspection variants before
   changing durable `DFS1` requests or migration evidence.
2. **Exact publication and role authorization.** Resolve the lowered body's native
   resources and selected capabilities before publication. Freeze actual object,
   definition, schema, input predicate, limits and source/instruction commitments.
   `AUTHORIZE ... AS ROLE` selects a nonzero role for ordered programs through
   `ManagedApplication.prepareControl`. Resolve any admitted public `SETTING(...)`
   operand in the reviewed context and save the resolved role. Rechecks use current
   policy; accepted invocations preserve their original role after replacement.
3. **Control meaning by profile.** Preserve Published, Authorized, Active,
   Suspended and Retired. Queue programs cannot `REFRESH` by replaying an input;
   the existing typed owner rejects refresh and SQL must preserve that refusal.
   Document the existing cancel-before-control-CAS behavior: a lost control race
   can leave its original invocation cancelled, and retry cannot cancel a newer
   one. Permanent retirement waits for original cleanup before removing edges.
4. **Publication, readiness and execution.** CREATE and EXPLAIN perform no Queue
   acquisition or effect. ACTIVATE records desired control; unavailable host
   capabilities produce attributable blocked readiness. Explicitly decide which
   profiles may be published before placement is available, while rejecting
   unsupported syntax/types before acceptance. Readiness grants no future rights.
5. **Instruction and transaction boundaries.** Preserve exact instruction identity,
   lexical scope, nullable/cardinality rules, TRUE-only guards and checked values.
   A proposed continuation becomes committed only through its native decision.
   First commit includes the input ACK; later blocks retain progress without
   another ACK. Resolve an uncertain transaction before failure handling.
6. **Bounded input and output.** Reuse the delivered 64 KiB program-source and
   native SQL envelopes, separate migration-file/codec limits, 4,096-node and
   depth limits, and current dependency/authorization budgets. Check all service,
   persisted-request and encoded-envelope ceilings together. Oversized programs
   refuse before publication; no global limit increase substitutes for ownership.
7. **Effects, responses and deadlines.** An intent, a fresh dispatch permission,
   a complete response, unknown outcome and response delivery are distinct facts.
   Replay only observes. Freeze the invocation deadline and carry remaining time
   through native decisions and external work; missing protected input is not
   permission to reconstruct credentials or resend. Response handoff needs native
   commit evidence, current disclosure rights and one live response owner.
8. **Definition replacement.** M12 owns source-level replacement/migration
   synthesis; M13 supplies runtime fencing/draining and original continuation
   semantics for any admitted lowered replacement. Keep replacement unsupported
   until that joint contract lands. A changed SQL body cannot overwrite accepted
   instructions, and resume never recompiles an original with the latest compiler.

Extend [DATAFLOW_V1](../../contracts/DATAFLOW_V1.md),
[APPLICATION_PROGRAM_V1](../../contracts/APPLICATION_PROGRAM_V1.md),
[SQL_SESSION_V1](../../contracts/SQL_SESSION_V1.md),
[MIGRATION_V1](../../contracts/MIGRATION_V1.md) and the affected native owners
together. Any incompatible persisted, ABI or wire change replaces the shared
current-v1 definition and all generated consumers/fixtures. Reject missing or
foreign definitions before execution; keep original builds available to settle
incompatible accepted work. Add no fallback decoder or automatic data reset.

## Reviewable implementation sequence

These are review units within M13, with mappings to the existing R packages.
Contract, implementation, negative admission cases, callers and public documentation
travel together. Every unit adds real SQL evidence; helper tests alone cannot
close it. R9 caller migration and R10 correspondence accompany every unit.

### 1. Admit and publish lowered Queue DATAFLOW SQL — R0/R1/R9

Extend `ManagedSql` and `Session` preparation with a typed ordered-program
variant. Delegate body parsing/type checking to `ApplicationProgram` and native
binding to `ApplicationDeclaration`/`ApplicationBinding`; do not create a second
procedural grammar in the service. Keep `SqlScript`'s whole-body framing and source
locations, including nested blocks, strings, comments and failure handlers.

Extend `ManagedOperations`' frozen request and original-operation recovery to
publish through `ManagedApplication`. Preparation reads authorized metadata;
publication reserves ownership before bytes, binds dependency edges and initializes
control through the existing owner. Classify terminal refusals separately from
transport uncertainty. The same client token returns its original publication,
even after the SQL session disappears. Changing its content conflicts.

Add native cohosted SQL controls with exact expected definition/control and saved
role binding. Keep interactive transaction, PostgreSQL/MySQL and standalone
remote admission explicitly unsupported until their own adapter proofs land.
Existing finite controls and retained revisions remain regressions.

**Exit:** installed SQL can publish, authorize, inspect and retire a public-data
Queue program. CREATE, EXPLAIN and metadata reads perform zero acquisitions and
zero network effects. Denied dependencies, wrong role, name-kind collisions,
unsupported body features and changed-token retries reject through typed outcomes.
Lost publication/control replies and restart recover the original operation.

### 2. Review and apply the same SQL through migrations — R0/R9

Extend `MigrationDataflow`'s Table-specific source/output evidence into a bounded
typed dependency plan. Existing resources bind exact definitions; resources
created earlier in the history bind producer step identities and their accepted
receipts. Extend the planning overlay only for native declaration owners actually
needed by the selected program: Queue, Stream, KV and the admitted Table/Document
profiles. All steps and unsupported dependencies are checked before admission.

Apply through the same statement/managed-operation owner as interactive SQL.
Retain complete CREATE bodies as single migration steps; instruction identities
remain internal to their immutable program. Freeze public settings/roles and
verify final definition/control postconditions without treating later invocation
progress as migration drift. Do not add a migration-only execution path.

**Exit:** a fresh SQL history declares input/state/output objects and the program,
then authorizes it. Repeated apply makes no new definitions or control changes.
Lost replies, competing apply, failed preparation and producer-definition drift
preserve original step identity and explicit resume. The same definition results
from ordinary SQL and migration execution. Source packages are absent at runtime.

### 3. Activate the installed public-data program — R3/R8

Compose the existing `DatabaseRuntime.applicationStep`, `ApplicationRecovery`
and default public `ApplicationHost` into the installed SQL journey. Qualify
single-partition Queue acquisition and predicate routing first. Keep explicit
multi-partition refusal; do not consume only partition zero. Preserve saved empty
acquisitions, bounded retry timing and publication wakeups instead of creating a
new durable attempt per poll.

Exercise `ApplicationExecution.tick` and `ApplicationTransaction` through the
native owners, including Table/KV/Stream and the supported row Document profile
as separately admitted cases. Persist input and proposed successors before
dispatch; join the original transaction decision before adopting a checkpoint.
Supply multiple-block and failure-handler cases after the one-block journey.
An unresolved block cannot be treated as an abort or enter replacement work.

Qualify fairness between application recovery, finite managed Tables, ordinary
SQL and controls. Charge reusable scratch, detached proposals, retained records
and active tasks to explicit owners. M3's allocator coverage must be measured at
the actual integration boundary. Yield at bounded work units, preserve reserved
settlement/cleanup capacity, and join tasks before reusing host memory.

**Exit:** after client disconnect, SQL-submitted input produces exactly the
declared state and Stream outputs, with the original input ACK and checkpoint
in one decision. Process death at claim, input retention, prepare, commit and
finalization recovers the same invocation. Competing owners, stale leases,
revocation, suspend/retire, empty acquisition and allocation pressure cannot
publish a duplicate or partial outcome. A long invocation cannot starve controls.

### 4. Expose independent progress and exact outcomes — R3/R9

Extend shared Catalog inspection with ordered-program definition, executor-role
attribution, desired control, host readiness, input identity, current instruction,
pending original transaction/effect and terminal disposition. Keep payloads and
protected environments out of ordinary metadata. Define a typed observation
whose empty, blocked, failed and uncertain states cannot be mistaken for success.

`SHOW DATAFLOW`, EXPLAIN and client/Board readers consume this same read operation.
An invocation outcome does not have a fabricated relational result revision.
Preserve finite `SHOW DATAFLOW ... REVISION` and its existing row reader; reject
that selector for a program unless a distinct outcome-selection contract is
explicitly added. No metadata read acquires input, advances progress or repairs
work. Recheck independent reader rights after buffering and at terminal delivery.

**Exit:** an independently authorized observer can explain a stalled invocation
and verify a completed one without executor/write privileges. Revoked, empty,
buffered and repeated reads fail closed. Board uses the signed read seam and
continues to perform zero mutation/settlement requests.

### 5. Compose effects, protected responses and deadlines — R8/R9

Reuse `ApplicationEffect`, `ApplicationReadSet` and the physical
[`ApplicationEffectRuntime`](../../packages/zig/transit-serving-http/src/ApplicationEffectRuntime.zig).
Configure their host in the node/SQL deployment explicitly; do not enable all
program capabilities merely because the worker can be constructed. Share the
existing CONNECTION/SINK operations, exact secret references and native policy
checks. Preserve guard validation after connection establishment and before the
first request write.

First qualify a generic program with one explicitly declared sink against an
independent synthetic HTTP peer. Carry the same effect identity, frozen operands,
executor role and invocation deadline through lost admission/settlement replies.
Only live fresh admission permits a send. Replacement observes or records unknown;
it cannot turn missing response bytes into another attempt. Suspend/retire fences
future work while preserving actual in-flight outcome evidence.

Then compose protected request reservations, response intents and atomic handoff
with their [serving/browser owners](downstream-application-language.md#p4--add-protected-ingress-sink-effects-and-response-handoff).
Bind exactly one response owner to the accepted handoff decision; disclose only
after commit and a current guard check. Socket loss and protected-body expiry
must preserve durable state/outcomes and bounded failure continuations. Enforce
whole-program deadlines across successive blocks; the earlier experimental
deadline proof is not a pass.

**Exit:** real lowered SQL selects the request, branch and effect operands.
Independent peer request counts, native receipts and response observations agree
under crash, denial, expiry and cancellation. No credentials appear in retained
public state, metadata or logs. The full application corpus remains gated on
ingress/publication/migration integration; a passing sink case does not close it.

### 6. Qualify the lowered-SQL contract with M12 — R9/R10

Once M12 can emit the admitted program profile, run emitted SQL and an independently
reviewed canonical SQL fixture through the same service and compare definitions,
ordered instructions, guarded effects, refusal outcomes and native decisions.
Run with the source repository/compiler absent, then repeat after restart.
Source-only imports, build declarations and test directives must reject at runtime.

M12 extends `transit test` with its own subject/clock/effect facilities; until those
exist, use real service and fault fixtures. Do not add fake passing workflow tests
to the delivered Table-only runner. Extend its independent source grammar and
lowering correspondence with each admitted language construct, while M13 owns
runtime transition replay. Generated expectations from the same compiler are
insufficient as the only oracle.

**Exit:** the admitted source construct and its SQL preserve exact identities,
guards, transaction boundaries and outcome uncertainty. The installed SQL journey
also works independently of source compilation. Broader browser adoption remains
with the downstream plan and its qualified deployment artifacts.

### 7. Complete relational WAL activation and incremental state — R2/R3/R4

This track preserves the other executable DATAFLOW profile. Finish the
[finite fault/resource gate](13-sql-and-dataflows.md#next-implementation-slice-owned-staging-and-finite-qualification)
without rebuilding delivered SOR1/CPR1/TXR1 ownership. Add bounded finite executor
continuations so large evaluations yield while retaining their exact source cut.
Do not claim a new batching gain without matched complete-successor measurements.

Extend `TableChangeReader` into a durable snapshot/history handoff: protect history
before backfill, save the original pin/cursor and commit offered complete-acceptance
coverage only with output/checkpoint. Notifications only wake discovery. Keep
`finite_recomputation`, `net_relation_changes` and `complete_ordered_changes`
distinct; true history loss blocks ordered capture. Archived logical coverage
can bridge WAL trim, but snapshot differences cannot recover `A -> B -> A`.

Add multiple sources only with paged definition/policy bindings and actual common
transaction decisions. Delayed participants must not expose half a commit; aborts
contribute no committed rows. Unrelated LSNs have no global maximum. Reuse M6's
finite Stream reader for its admitted composition, with explicit multi-source
consistency; a Stream offset is not a Table commit LSN or a consumer-group ACK.
Output chaining needs qualified acyclic dependency traversal and complete cuts.

Replace DFP1 result payloads and fixed-size delta arrangements through one planned
current-v1 `.tseg` cutover with native signed `@weight: i64` multiplicities.
Preserve DFR1's logical attribution, result ordering/coverage and current disclosure
guards; migrate all readers and reachable roots together. Stage durable arrangement
and result roots before the common output/checkpoint decision. Scratch spill is
disposable; checkpoint arrangements remain retained recovery state. M14 supplies
shared compaction improvements, while M13 must deliver a bounded usable baseline.

Start incremental filter/projection and admitted bag union, then join cross terms,
outer/semi/anti match counts, distinct and groups. Qualify against independent
finite evaluation at each completed basis, including five-state values,
collations and checked failure order. `[MAX_INT64, 1, -1]` cannot become a
successful SUM because its widened final total fits. Event-time windows require
persisted watermarks, lateness, retractions and finality before admission.

**Exit:** actual SQL, retained readers and restart prove complete-commit coverage,
independent finite/incremental agreement and bounded real segment/spill I/O.
Missing pages, exhaustion, quota failure and incomplete prefixes never complete
a revision. Unlimited retention remains the default; retirement and watermarks
do not authorize deletion.

### 8. Close the remaining SQL and connector surface — R5/R6/R7/R8

Keep the milestone's full scope, with each feature admitted through the same
lowered SQL and typed owners rather than helper-only coverage:

| Review boundary | Required implementation and exit |
| --- | --- |
| Analytical plans | Production typed plan DAG, multi-way/non-equi/semi/anti/LATERAL joins and dependent-join unnesting; independent scalar-cardinality, NULL, multiplicity and error-order oracles. Constant IN/NOT IN can land independently through M15's shared owned predicates. |
| CTEs, sets, windows and aggregates | Bounded recursive CTEs, set/bag operations, ROWS/RANGE/GROUPS frames, QUALIFY and rich aggregates through the real parser/executor. Real sort/join/group/window spill and explicit exact/approximate semantics; no spill-counter substitute. |
| Historical and temporal SQL | `CHANGES` over retained complete intervals, composition of delivered `STREAM_SLICE`, application-time periods and knowledge-cut AS OF joins using M10 definitions. Qualify late corrections, ties, endpoints and unavailable history; SQL MERGE uses one original transaction and remains distinct from branch merge. |
| Functions | Immutable function/body/schema bindings, hygienic SQL macros and an explicitly admitted real Wasm binary/validation/runtime profile with fuel, memory and vector ownership. No ambient effects or Station mailbox dispatch for query UDFs. |
| SOURCE activation | Reuse delivered capture ownership/readers; add fenced original HTTP admission and durable fixed-delay scheduling before enabling SOURCE controls. The raw-body ingestion profile differs from application protected-JSON sinks; reuse transport mechanics without conflating their retention, dispatch or disclosure contracts. |
| Governed relational sinks | Bind output/checkpoint and a stable effect intent to one common decision, then dispatch under current connector authority. Ordered/net trigger semantics are explicit; retracting a relation cannot retract an HTTP request. |

These units can proceed when their specific contracts are ready. They do not block
Units 1–4's public-data program, and finishing that program does not complete M13.
Retain the milestone's interval-depth/state-book workload, temporal propagation,
larger-than-RAM and caller-migration obligations in the linked R packages.

## Handoffs to upcoming milestones

| Owner | M13 supplies | Owner retains |
| --- | --- | --- |
| [M14 performance](14-data-structures-and-performance.md) | Charged work units, bounded retained/spill state, correctness oracle and measured complete-operation/foreground-interference baseline | Physical structure selection, shared LSM compaction, statistics and integrated regression budgets; no deferred M13 correctness or memory gate |
| [M15 strings/search](15-vectorized-strings-and-search.md), [M16 compilation](16-data-centric-compilation-and-specialization.md) | Exact typed plans, owned string/key lifetimes, failure order and checkpoint/continuation semantics | Shared collation/membership/search primitives and optional fused/AOT implementations; M16 reuses M12's build graph and cannot change SQL meaning |
| [M17 profiles](17-document-profiles-and-gateway-exchange-lifecycle.md), [M18 spatial](18-geospatial-and-spatio-temporal-computing.md), [M19 foreign relations](19-multi-model-and-foreign-relations.md), [M20 assets](20-game-asset-pipelines-and-simulation-streaming.md) | Definition-bound adapters, operator traits, replay/retraction versus bounded-rebuild contracts and atomic complete publication | Actual profile decoding, spatial/asset semantics and foreign import/CDC qualification. A codec or pure helper is not an admitted SQL source. |
| [M21 branches](21-branches-merges-and-restore.md) | Branch-qualified source/definition/result identity and retained roots | Writable histories, merge/restore and shared arrangement roots; copying a definition never activates it or recreates effect rights |
| [M22 coverage](22-service-and-sdk-coverage.md), [M23 correspondence](23-formal-semantics-and-correspondence.md) | Shared SQL/native operations, representative installed evidence and production transition/operator traces | Broader language/platform matrix and systematic proof composition. M13 still migrates affected callers and supplies its own negative controls. |
| [M24–M27 distributed operations](24-storage-providers-and-concurrency.md) | Local original-decision recovery and explicit lease/cut assumptions | Provider, replication, disaster-recovery and placement qualification; multiple local workers are not distributed authority evidence |
| [M28 policy](28-control-and-policy-plane.md), [M29 publication](29-published-resources-and-investigations.md), [M31 Board](31-board-reimplementation.md), [M33 activation](33-reactive-context-and-agent-activation.md) | Current native policy checks, exact outcomes, read-only inspection and deliberate trigger/effect boundaries | Broader secret/identity/publication/workbench/agent behavior. M13 supplies generic execution, not hardcoded authentication or agent policy. |

## Verification and completion gates

| Boundary | Required real-path cases | Forbidden result |
| --- | --- | --- |
| SQL and migration admission | Whole compound bodies, exact types/resources, role/settings drift, malformed/oversized programs, source-only constructs and both computation kinds | Partial publication, parser fallback, execution from CREATE/EXPLAIN or changed-content token reuse |
| Original invocation | Lost claim/input/proposal/decision replies; process death before/after each native boundary; multiple blocks and failure handlers | New input/effect identity, double ACK, duplicated output, adopted uncommitted continuation or failure before original settlement |
| Control and policy | Competing activation, stale service/invocation fences, cancel-before-CAS race, revoked dependency, suspend/retire and host unavailability | Resurrected definition, substituted executor role, unauthorized publication or cancelled original forgotten during cleanup |
| Effects and responses | Independent HTTP peer, lost send/outcome evidence, secret rotation, response expiry, handoff race, deadline across blocks and joined cancellation | Replay send, unknown relabeled as refusal/success, secret disclosure, duplicate response owner or socket loss treated as rollback |
| History and delta execution | Concurrent backfill, archive/trim, true gaps, no-ops, oscillations, empty results, delayed/aborted participants and compaction without mutation | Skipped committed input, fabricated common frontier, half-transaction result or finite prefix called complete |
| Resource and collection | Durable populations beyond resident slots, bounded active work, real spill, allocation/I/O failures, collection with pending/retained roots and cold restart | Unbounded resident backlog, starvation of controls, missing accepted bytes recreated, or quota pressure used as expiry consent |
| Independent readers | Metadata and finite rows through shared clients; denied buffered/empty/terminal reads; source-free installed execution | Inspection mutates work, authorization inferred from ownership, or command acceptance presented as application completion |

Extend the current test owners rather than inventing successful placeholder
commands. Existing starting points include `test-application-programs`, the
signed native application cases, `tests/interfaces/installation/server_managed_tables.py`,
the migration/fault suites, source declaration/capture tasks and Board computation
inspection. Add installed lowered-Queue SQL cases to the appropriate owners and
register their actual tasks in `tests/runner/suite.json` before treating them as
gates. Existing `managed-tables` tests do not already prove ordered program SQL.

For every PR, including this plan, run the repository baseline:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

For implementation units, select affected package, protocol, SQL and installed
checks from the [task inventory](../../tasks/README.md), including:

```sh
nix develop --command just check contracts
nix develop --command just test::managed-tables
nix develop --command just test::source-declarations
nix develop --command just test::source-capture
nix develop .#ci-experience --command just test console-latency-gate
nix develop --command just test server-sql-types
```

Run source/capture tasks when those boundaries change; retain finite managed
regressions for shared DATAFLOW changes. Browser/contracts changes also require
`just transit-board::check` and affected browser proofs. SQL types or wire adapter
changes require the complete [SQL interface validation loop](../../tasks/README.md#sql-interface-validation),
including `just test sql-wire-contracts` and `just test sql-wire-types`.
Before pushing implementation/test-infrastructure changes, run affected
`just ci clean --lane NAME` checks against committed HEAD, with dependent lanes
for shared authority/contracts. Documentation-only work adds no runtime suite.
Final integrated qualification must use one committed revision; installation,
task listings, skipped runs and unions of older passes are not that gate.

Develop T8 lifecycle/DDL and T5 history-handoff correspondence with the owning
reducers; add A3 incremental equivalence as operators land. Reuse the existing
model/trace harness and independent fixtures. Negative controls must expose a
removed fence, early checkpoint or unauthorized dispatch. M12's selected lowering
proofs and M23's wider models cannot substitute for installed behavior.

Measure invocation-to-verified-outcome and source-acceptance-to-complete-revision
latency separately from HTTP response/notification latency. Record backlog,
catch-up, foreground/control latency, recovery work, allocations after warmup,
peak owned memory, spill bytes and retained amplification. Set regression budgets
from matched complete runs before optimization, preserving failures and unknown
metrics. Keep performance windows separate from heavy builds and proofs.

Units 1–4 complete the first lowered Queue DATAFLOW SQL slice only when its
installed publication-to-outcome journey and faults pass. Units 5–6 establish the
admitted effect/response and source-emission handoffs with their adjacent owners.
Units 7–8 and the existing R0–R10 acceptance obligations remain necessary for full
M13 completion. Promote supported semantics and limits to the query/application,
SQL, caller and storage owners as code lands; record executed evidence in
qualification history and update milestone status only when its full gates pass.
