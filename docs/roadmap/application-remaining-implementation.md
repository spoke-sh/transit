# Milestone 12 remaining implementation plan

[Milestone 12](12-application-modules-compilation-and-testing.md) · **Status: First increment in progress** · 2026-11-11

Complete the application authoring journey: compose data, computations and
policies in typed `.transit` modules; inspect independently executable SQL;
evolve an installation through explicit, immutable migrations; and test the
same program with controlled identities, time, effects and recovery schedules.

Build on the merged compiler, Table tests, source grammar and typed-target
implementation. The next functional increment should emit the installed
public-data Queue program profile. Follow it with richer typed composition,
runtime-enforced module boundaries, protected command/workflow composition,
migration synthesis and safe replacement. Add tests and selected formal
correspondence with each capability, rather than postponing them to integration.

This plan sequences the remaining P0–P6 work at source `bc849156a`, the merge of
PR #445. It preserves the milestone's **In Progress** status, acceptance criteria
and earlier slice records. The public-data Queue build/test increment is the
selected implementation scope. Later syntax and runtime extensions remain proposals;
the [source contract](../../contracts/APPLICATION_SOURCE_V1.md) remains the owner
of implemented behavior. The source-basis audit below is historical; implementation
and qualification must be assessed separately from the plan.

The first increment adds exact public Stream/Queue handles, checked ordered
program emission and explicit lifecycle statements, plus bounded completion/refusal
observations and finite Stream row assertions in isolated tests. Its synthetic
fixture checks accepted input, refusal before mutation and refusal after a staged
insert inside an atomic block. Nominal program columns, symbolic program
declarations, protected effects, migrations and replacement remain outside this
increment. Current syntax and limits belong to the
[public Queue source profile](../../contracts/APPLICATION_SOURCE_V1.md#public-queue-programs).

## Current implementation and gaps

| Boundary | Implemented at the source basis | Remaining work |
| --- | --- | --- |
| Recursive builds | Pure compiler, higher-order module parameters, bounded recursion, explicit Table instance names, locked repository/subdirectory imports, overrides, offline builds and atomic artifact publication | Richer resource/behavior interfaces, returned constructors/composed modules where absent, and broader definition graphs; preserve the existing resolver |
| Syntax and types | Independent ANTLR/Zig comparisons, complete Table-template syntax checks, bounded formatter, nominal scalar domains, closed variants, exhaustive compile-time MATCH and exact public Table exports | Runtime inputs and variants, query cardinality, refinements, typed expressions/commands, effects, ownership and transitions |
| SQL lowering | `WorkingCatalog` checks Table CREATE, literal DML and finite single-Table SELECT; emitted SQL is reparsed and bound independently | Other data kinds, schemas/views, ordered programs, helpers and migration targets; a raw SQL escape hatch would bypass the required checking |
| Runtime programs | Cohosted SQL publishes and runs bounded public-data Queue programs through the existing application owners | Source emission, Queue-program migration binding, independent inspection, deployed protected effects/responses, deadlines and definition replacement have separate gates |
| Migration execution | Immutable SQL files, original step tokens/receipts, drift checks and resumable execution; staged Table and finite Table-dataflow adapters | Offline desired-state diff, explicit prior graph, broader staged dependencies, transforms and conditional replacement |
| Tests and proofs | Isolated Table tests through real local owners; typed rows/counts/refusals; source grammar comparisons and three scoped Lean laws | Subject/grant and clock controls, workflow assertions, scripted effects/observations, replay sweeps and temporal/native correspondence |

The implementation anchors are
[WorkingCatalog](../../packages/zig/transit-compiler/src/WorkingCatalog.zig),
[Compiler](../../packages/zig/transit-compiler/src/Compiler.zig),
[SourceTypes](../../packages/zig/transit-compiler/src/SourceTypes.zig),
[TypedOperands](../../packages/zig/transit-compiler/src/TypedOperands.zig),
[build resolution](../../apps/transit-cli/BuildSources.zig), and
[the test runner](../../packages/zig/transit-test/README.md).
The [installed Queue contract](../../contracts/APPLICATION_PROGRAM_V1.md#installed-sql-profile)
is narrower than its typed runtime components. Do not infer installed support
from the presence of an instruction parser or an effect worker.

The [latest typed-target qualification](../history/qualification/query.md#typed-target-rebase-and-shared-sql-framing--2026-11-11)
records focused compiler, grammar, installed build/test, SQL-type and clean formal
passes. Full core, storage/query and installation/UI lanes and console latency
were not rerun after that rebase. Earlier failures retain their sources and
outcomes. These records are prerequisites for qualification work, not a pass at
this plan's baseline.

## Decisions proposed for review

1. **Deliver an executable public-data program before protected workflows.**
   Connect the compiler to existing Queue program semantics first. Live command
   ingress, effects and response capabilities follow their runtime owners.
2. **Keep one checked representation and one runtime meaning.** Extend the
   compiler's typed bindings before erasing them to SQL. Share pure Fuze and
   definition APIs; keep Station, live catalog access and network I/O outside
   compilation. Do not create another workflow interpreter or persistent IR.
3. **Start migration synthesis with Tables.** Deliver unchanged/new/additive
   Table diffs against an explicit basis independently of protected workflows.
   Broaden adapters only when their ordinary execution and recovery contracts
   are available. Keep destructive transforms explicit.
4. **Establish replacement with `require_idle` first.** Add generation pinning
   and draining as subsequent, separately proved policies. All three policies in
   D5 remain completion scope; a narrower first slice does not remove them.
5. **Keep source visibility and runtime protection distinct.** Public resource
   composition can proceed now. Private storage and privileged procedures require
   an enforceable catalog/security contract and direct-SQL denial proofs.
6. **Retain performance and qualification obligations.** Do not relax deadlines,
   quotas or failed controls to enable a larger language profile. The Platform
   coverage and timing targets remain unmeasured until their full inventory runs.

## Ownership and dependency gates

| Owner | Required handoff |
| --- | --- |
| [Source contract](../../contracts/APPLICATION_SOURCE_V1.md), [grammar](../../contracts/application-source/README.md), `transit-compiler` | Syntax, stages, typed bindings, deterministic evaluation, diagnostics, SQL equivalence and source-only rejection at runtime entry points |
| [Fuze](../../packages/zig/transit-fuze/README.md), [application programs](../../contracts/APPLICATION_PROGRAM_V1.md) | Pure typed expressions, resource descriptors, ordered instructions, cardinality and runtime refusals; factor pure APIs without reversing Fuze/Catalog dependencies |
| [Catalog definitions](../../contracts/CATALOG_DEFINITIONS_V1.md), [catalog](../../contracts/DECLARATIVE_CATALOG_V1.md), M5–M7/M10 | Stable definitions, current policy, exact dependencies and native transactions; qualify each Document profile explicitly rather than assuming all Document work is complete |
| [M13 SQL/dataflow work](dataflow-sql-implementation.md), [SOURCE/SINK](../../contracts/SOURCE_V1.md) | Installed publication/control, program migration binding, protected host composition and observable progress; M12 must not duplicate service discovery or invocation recovery |
| [Migration](../../contracts/MIGRATION_V1.md), M11 | Saved basis, conditional application, immutable receipts and drift rejection; physical rewrites remain with the online rewrite owner |
| [Test host](../../apps/transit-cli/TestHost.zig), M8/M9 | Real isolated database composition, signed identities, inherited deadlines, original-operation settlement and joined cleanup |
| [Verification owners](../../tests/verification/models/README.md), M23 | Selected temporal models, Lean laws and native trace projections delivered with language features; no general proof inferred from shared generation |

Do not wait for every adjacent milestone to complete before using an admitted
operation. For each source form, record its source checker, executable SQL owner,
installed placement, bounds, migration adapter and proof. If one required owner
is missing, reject that target before publishing an artifact. Missing support
must not silently become an empty effect set or a skipped test.

## Delivery sequence

| Increment | Outcome | Depends on | Original scope |
| --- | --- | --- | --- |
| 0 | Reconciled baseline and capability inventory | Current committed source | P0, P6 |
| 1 | Modules emit and test public-data Queue programs | 0 and installed program profile | P0, P1, P3, P5 |
| 2 | Typed expressions, cardinality, functions, guards and atomic procedures | 1; pure expression work can start after 0 | P1–P3, P5 |
| 3 | Reference exports and runtime module encapsulation | 2 and catalog/security contract | P1, P2 |
| 4 | Protected command/workflow composition and transition contracts | 2–3 and installed ingress/effect/response owners | P2, P3, P5 |
| 5 | Explicit-basis migration synthesis | 0 and the relevant declaration adapters; Table work can proceed alongside 1–4 | P0, P3, P4 |
| 6 | Conditional replacement with original-generation recovery | 5 and each runtime definition owner | P4, D5 |
| 7 | Complete deterministic workflow tests and replay sweeps | Controls added during 1–6; protected schedules require 4 and 6 | P5 |
| 8 | Combined application, correspondence and performance qualification | 1–7 and external runtime prerequisites | P6 |

Each increment may span several PRs. Each executable feature PR includes its
contract, grammar, implementation, negative cases, caller proof and public
documentation. A contract-only PR can precede it but cannot advertise execution.

### 0. Reconcile qualification and freeze target capabilities

Reproduce the unresolved owning gates at a committed implementation baseline;
retain failure logs and distinguish regressions from failures reproduced by an
unchanged control. A reproduced baseline failure still fails the gate. Close
affected failures before publishing implementation updates under the repository
rules; do not reuse an earlier PR's approval exception.

Audit the three source entry points, CLI resolution, statement owners and
migration adapters. Record the capabilities above with current code pointers and
positive/negative cases in existing contracts and inventories. Preserve the
existing build/test/typed-target fixtures rather than replacing their scope.

Audit bounds across framing, preparation, wire messages and retained records.
Current source files allow 1 MiB; migration files allow 64 KiB and
[DirectMigration](../../packages/zig/transit-catalog/src/DirectMigration.zig)
allows 64 steps. The proposed 1 MiB migration/256-step profile is unfinished.
Do not confuse the ordered-program parser's 64 KiB ceiling with acceptance by
every enclosing SQL envelope. Never split an atomic declaration to fit a limit.

**Exit:** every next-slice form has an exact owner and support decision;
qualification results identify their committed source and remaining failures.

### 1. Compile a complete public-data Queue application

Use a synthetic reservation application: an explicit input Queue, public Table
state and an output Stream. A module publishes a Queue program that reads one
request, checks a predicate, commits the state change and output with the exact
input ACK, and exposes observed completion through existing SQL operations.
The build only emits these operations; the caller separately executes them and
explicitly authorizes/activates the program.

Split implementation into three reviewable units:

1. **Definitions and typed handles.** Extend `Syntax`, `Template`, `Graph`,
   `SourceTypes` and `WorkingCatalog` with the exact public schema/resource
   definitions needed by the fixture. Reuse shared Table, KV and log declaration
   compilers. Add kind-specific resource handles and interface checks; a Queue
   reference must not degrade to an unchecked identifier. Admit each new kind
   only with checked operand roles, canonical schema/policy bindings and tests.
   Add finite Table-dataflow/view and Document adapters separately as their
   exact target profiles are established.
2. **Ordered program checking and emission.** Reuse
   [ApplicationProgram](../../packages/zig/transit-fuze/src/ApplicationProgram.zig)
   and its pure binding semantics for LET, reads, REQUIRE, IF, atomic mutations,
   appends and public failure handlers. Carry nominal annotations through every
   new operand path; reject unsupported combinations before erasure. Preserve
   instruction order, exact resource definitions, read/write requirements,
   first-boundary ACK and checkpoint semantics. Reparse emitted SQL and compare
   checked instruction/resource projections, not only text or scalar schemas.
3. **Real execution and tests.** Extend `transit-test`/`TestHost` with explicit
   bounded progress stepping and workflow observations through real owners.
   Publication or ACTIVATE completion cannot satisfy a workflow assertion.
   Preserve case isolation, complete result evidence and joined cleanup. Keep
   runtime scheduling outside the compiler and reuse service execution machinery.

The first application uses only supported public data and one input partition.
Effects, protected values, HTTP ingress, runtime-private storage and replacement
remain rejected. Do not advertise PostgreSQL/MySQL or remote gateway execution
when the installed owner requires native cohosted SQL.

**Exit:** build offline, remove source packages, execute through the ordinary
client, and inspect exact state/output counts and invocation completion. Compare
hand-expanded SQL. Exercise wrong resource kind/domain, duplicate bindings,
revocation after build and before commit, abort without partial outputs, lost
commit reply, restart and original-input recovery. Earlier Table products and
typed-target fixtures retain their behavior. These are required new proofs,
not claims about tests already present.

### 2. Add typed expressions and reusable atomic composition

Extend the checked core with explicit row schemas, one/optional/many cardinality,
five-state values, ordered guards, effect signatures and resource read/write
sets. Keep build-time values distinct from runtime expressions; database results
must never enter compile-time evaluation. Define bounded refinements and the
runtime validation required when constructing them from external input.

Add pure FUNCTION and predicate/query constructors using Fuze's scalar and query
semantics. Compile-time higher-order arguments specialize hygienically; runtime
closures and unrestricted recursion remain outside the profile. Add GUARD
expansion without reordering refusals or dropping dependency reads. Extend module
interfaces and returned constructors where the current module parameter model
does not express these compositions.

Inline PROCEDURE bodies into the caller's existing atomic program boundary.
Declare and check allowed reads/writes and return types; forbid external effects
and suspension inside that boundary. This first public-storage profile grants
no callee privilege. Runtime-private procedures depend on increment 3.

Finish the typed-target case as a runtime decision: validate an incoming tag/ID,
exhaustively choose Machine or Site, read the correct bound resource and handle
zero, one and multiple rows explicitly. Define a supported runtime encoding in
the owner contract before emitting it; retain the existing compile-time MATCH
semantics independently.

**Exit:** compare source, checked core and ordinary SQL for NULL/missing/error/
conflict, overflow, cardinality failure, wrong nominal IDs, invalid refinements,
unhandled variants and reordered guards. Check that a higher-order argument
cannot hide effects. Add scoped Lean substitution/ordered-expansion laws and
independent compiler/runtime comparisons with explicit premises.

### 3. Enforce reference exports and runtime module boundaries

Define reference-only key exports separately from readable/writable Table
handles. Preserve exact native foreign-key bindings and DROP dependencies without
exposing rows. Add exported queries and procedures with typed inputs, outcomes,
effects and behavioral obligations; import/interface conformance grants nothing.

Before accepting private storage, specify module ownership, caller/callee policy
checks and unforgeable definition bindings in the catalog/security owners. Emit
ordinary SQL that preserves those obligations. Inlining cannot substitute a
compiler assertion for runtime enforcement, and a schema USAGE grant cannot
bypass promised private access rules.

**Exit:** direct SQL and generated SQL both reject unauthorized storage access,
forged ownership, wrong reference definitions and revoked calls. Legitimate
exported operations retain their atomic boundary and current permission checks.
Moving files/aliases preserves explicit instance identity; conflicting package
versions cannot share one stateful instance silently.

### 4. Check protected commands, effects and transitions

Extend the source and ordinary runtime contracts together for the admitted
COMMAND, SOURCE, SINK and PUBLICATION profiles. Reuse the installed host work
from M13 and its adjacent ingress/serving owners. Component parsing, declared
sinks and physical HTTP helpers do not establish a deployed workflow.

Add typed PROFILE defaults and explicit override validation without reading
runtime settings or secret values during a build. Carry runtime references into
SQL. Add control-flow analysis across branches, early refusals and failure
handlers: each request capability and operation must settle or transfer exactly
once on every admitted terminal path. Define obligations across suspension and
recovery separately from static path checking.

Track protected data through expressions, containers, helper calls and admitted
control-dependent flows. Permit only contract-approved disclosures and
declassification; BEARER/cookie wrapping remains protected. Reject secret values
in persistent application rows, output bodies, diagnostics and build artifacts.
This analysis does not prove general side-channel noninterference.

Define named transitions, pre/postconditions, capacity invariants and exact
evidence bindings. Keep desired state, observed state and operation progress
distinct. Evidence received dynamically needs validation against object,
definition, generation and operation. Recheck authority across commit/effect/
suspension boundaries. Unknown effect outcomes remain explicit; replay observes
recorded work and never redispatches.

**Exit:** execute the one-use admission/continuation and bounded-capacity cases
with competing callers, revocation, interrupted handoff and unknown effects.
Preserve reservations and original operations. Add selected TLA+ safety models,
intended failing controls and native trace replay in the same increments; state
fairness separately for liveness. Profiles emit only fully executable policies,
with source activation ordered after its required authorized consumers/sinks.

### 5. Synthesize migrations from an explicit definition basis

First specify a bounded, immutable offline basis: contract/compiler identity,
namespace/instance bindings, exact definitions and dependency closure, plus any
prior migration bytes. Distinguish logical proposed definitions from accepted
live object IDs. An explicit export can prepare a basis; a build never contacts
a deployment implicitly or treats a name as proof of its identity.

Add a pure definition diff shared with catalog interpretation owners. Start with
unchanged Tables, new Tables and supported additive column changes. Reuse
`logicalFingerprint` and schema projection rules. Require explicit transforms
for drop, rename ambiguity, type/collation/representation changes and splits.
Delegate physical online rewrites to M11. Domain, variant, constraint and effect
changes must invalidate affected evidence even when physical scalar types agree.

Add a migration build target with frozen inputs and a fresh version/name. Emit
reviewable immutable SQL without overwriting applied files or applying anything.
Replay the prior migration sequence offline, apply the proposed diff to the
logical graph and compare the desired fingerprints under identical bindings.
Compare actual old-to-new migration execution with a fresh desired installation
for supported cases; preserve historical identity separately from that comparison.

Broaden the staged graph to each admitted resource/definition kind. Queue program
migrations require M13's original dependency/receipt adapter; ordinary Queue SQL
execution alone is insufficient. Grants/activation remain explicit requested
steps. Coordinate any file/step-limit increase across client, protocol, ledger
and service, with bounded page/scratch behavior and current-v1 cutover evidence;
raising constants alone does not satisfy P0.

**Exit:** unchanged input emits no changes; additive input emits deterministic
dependency-ordered SQL; destructive ambiguity rejects. Test drift, target
mismatch, missing/foreign bases, dependency upgrades, partial application and
lost replies. Resume frozen SQL and original step tokens after source/compiler
changes. Never recompile accepted work or silently reset an incompatible ledger.

### 6. Replace definitions without reinterpreting accepted work

Specify conditional prior revision/digest checks and replacement receipts for
each VIEW, DATAFLOW, PUBLICATION, SINK and SOURCE owner. Retain exact old and new
dependency graphs. A common SQL spelling does not imply identical activation or
cleanup rules across these kinds.

Deliver `require_idle` first with an atomic admission/replacement fence; an
observed idle flag alone cannot exclude a concurrent new invocation. Then add
`pin_generation`, retaining immutable old plans and their dependencies until
original continuations finish. Finally add `drain_active`, with explicit closure
of old admission, bounded drain progress and separate new-generation activation.
Retention defaults and uncertain external outcomes still apply; timeout cannot
erase old obligations or imply remote cancellation.

**Exit:** replace during Queue acquisition, commit uncertainty, suspended effects
and policy changes. New work binds the new accepted definition; old work finishes
on its original definition or is fenced/drained under the selected policy.
Restart/lost control replies cannot substitute plans, roles or operation IDs.
Model and replay replacement races, verify historical inspection and safe
dependency cleanup, and reject stale/foreign saved requests before execution.

### 7. Complete deterministic workflow testing and replay

Extend the existing runner incrementally alongside features: subject/grant
controls and transaction faults with increments 1–3; virtual clocks and scripted
effects/observations with 4; replacement schedules with 6. Test declarations
cannot select deployment credentials or dispatch to real providers. Controls
remain runner-only and use the same production emitter and native owners.

Add explicit workflow outcomes, refusal reasons, dispatch counts and bounded
progress assertions. Mock registration must distinguish missing, conflicting,
unused and exhausted expectations. Unknown/timeout responses must exercise the
owner's uncertainty path rather than fabricate completion. Virtual clocks must
reach all declared time consumers; wall-clock leakage fails deterministic replay.

Specify the proposed replay option in the CLI contract before adding it.
Enumerate before/after transaction, effect-intent, dispatch/observation and
handoff yield points. Freeze seeds and schedule inventories, restore isolated
owner state, and recover original work. Maintain independent projections of
state, reservations, outputs and effects. Never count an unvisited boundary or
incomplete schedule as passed.

**Exit:** every declared schedule completes within explicit budgets and retains
its outcome/evidence. Removed fencing, double ACK/handoff, replay dispatch and
false terminal coverage fail their intended controls. Run real disk restart and
installed-host checks separately: simulated storage and scripted providers do
not establish physical durability or provider idempotency.

### 8. Qualify the complete application journey

Use public synthetic fixtures for the three language cases and multi-package
composition. Separately freeze the authorized Platform workload inventory and
revision; do not copy private source, credentials or provider policy into Transit.
The milestone's historical seven-file baseline names 26 commands and 14 workflows;
reconcile changes explicitly without silently reducing required coverage.

Exercise root/child builds, repository subdirectories, transitive locks, overrides,
network-disabled rebuilds, path relocation and conflicting instances. Run emitted
SQL without source packages. Compare hand-expanded and generated definitions,
ordered refusals, state and original outcomes. Migrate a prior installation,
replace running definitions, restart, revoke rights and inspect complete results.

Measure duplication reduction, check-only latency and full offline test/replay
time with pinned hardware, toolchain, workload, cache state and schedules. The
existing targets remain more than 35% less duplication, below 500 ms check-only,
and below two seconds for the complete command/workflow offline inventory.
Retain all samples and failures; report failure against a target explicitly.

Promote each supported profile and its limits to the application/SQL references,
CLI and package guides as it lands. Bind model/proof evidence to source,
dependencies, compiler/contracts, emitted SQL and exact tools. Close M12 only
when every completion journey in the numbered milestone has attributable,
complete evidence at the final integrated revision.

## Validation and review gates

This document proposes checks; it does not record their execution. For this
documentation-only change, run the repository fast and handbook gates plus the
source-link check. No runtime suite is required for a plan.

For each implementation PR, run the baseline commands from the repository root:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Use the existing [application checks](../../tasks/README.md#application-source-checks)
and expand their real inventories with each increment:

| Change | Owning checks and evidence |
| --- | --- |
| Compiler, source grammar or types | `just test application-compiler`, `just test application-source-grammar`, `just test application-source-types`; independent AST/SQL comparisons, formatter round trips, allocation/budget failures and selected Lean laws |
| Test runner or source execution | `just test application-runner`, `just test application-build`, `just test application-test`, `just test application-test-host`; real signed local owners, complete outcomes and cleanup |
| Migration or managed runtime | `just test migrate-lifecycle`, `just test managed-tables`, affected native transaction/recovery checks; extend these with actual new journeys rather than treating existing coverage as sufficient |
| Contract/schema/ABI changes | `just check contracts` and dependent caller/package checks; generated resources and foreign/missing-definition rejection |
| CLI/server/SQL build or execution paths | `just test console-latency-gate` and `just test server-sql-types` in the pinned `ci-experience` environment; preserve the established measurement profile |
| Temporal/transition features | Selected existing/new model tasks, intended negative controls, native trace replay and audited Lean premises; register new tasks before claiming coverage |

Run commands inside the owning pinned Nix shells. Before pushing implementation
or test-infrastructure changes, run affected clean lanes against committed HEAD:
`storage-query`, `formal` and `installation-ui` for source/test integration;
include `core` and dependent caller lanes when shared authority, contracts or
runtime owners change. Select through [suite.json](../../tests/runner/suite.json)
and the [clean-checkout workflow](../../tasks/README.md). Keep fast, full handbook,
focused runtime, clean-lane and final combined qualification results distinct.

Update task registration, diagnostic/proof/invariant inventories and the public
capability owner together. A timeout, skipped case, incomplete exploration or
dependency installation is not a passing check. Re-run affected gates after
subsequent edits; preserve original failures and the scope of any later pass.

## Review checkpoints

The first implementation review should approve the public-data fixture and its
exact source/resource profile, then the pure binding/emission boundary and
test-host progress controls. Subsequent reviews settle runtime module authority,
protected command semantics, the explicit migration basis, replacement policies
and replay schedule coverage before exposing those interfaces.

The largest dependencies are installed protected ingress/effects, runtime module
encapsulation, generation retention and the complete consumer workload. Their
absence permits independent Table migration and public-data compiler work to
continue, but prevents marking the corresponding milestone journeys complete.
No dates or effort estimates are implied by the increment order.
