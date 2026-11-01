# 9. Shared client foundation and language-native APIs

[Roadmap](README.md) · **Status:** In Progress ([remaining implementation plan](#remaining-implementation-plan--2026-11-01))

Let ordinary applications use data, queries and transactions through idiomatic
language clients without adopting Station. Establish reusable package ownership,
bounded client infrastructure and recovery semantics before expanding the SDK
matrix or building collaboration adapters on those APIs.

## Prerequisites and split ownership

Consume the [installed data lifecycle](03-live-storage-and-sql-cutover.md),
[statement results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[declarative streams, queues and durable runtime](06-streams-queues-and-durable-runtime.md),
[logical document storage and Station decoupling](07-document-storage-and-station-decoupling.md)
and [gateway architecture, sans-I/O wire protocols and direct-plane ingress](08-gateway-architecture-and-protocol-ingress.md). Contract and language
sketches begin with those owners; core data paths must not wait until this
milestone to acquire sound ownership. The
[caller reference](../handbook/reference/callers.md),
[SDK reference](../handbook/reference/sdks.md) and
[client/framework account](../handbook/internals/client-framework.md) describe
the current boundaries.

This milestone extracts the foundation from
[language-native programming and mixed composition](34-programming-model.md).
That later milestone retains the recorded source assessment, all three mixed
capabilities (recorded effects, durable consumers and typed Station calls),
Station behavior ergonomics and the complete installed cross-language journeys
after outbound MCP. [Service/SDK coverage](21-service-and-sdk-coverage.md)
retains its delivered raw-client/console slices and operation/platform breadth;
it expands over this package and API foundation rather than establishing a
competing interface first. None of the split marks existing work complete.

## Delivery sequence

1. **Review shared application contracts before package moves.** Map identities,
   definitions, typed values/codecs, references, credentials, result readers,
   transactions, accepted-operation handles and execution scopes to their owners.
   Distinguish pure preparation, reads, independent commits, transaction-scoped
   changes, native turn proposals and recorded effects. Review side-by-side
   direct, transaction, recovery and mixed-mode sketches in Python, TypeScript,
   Rust, Go, Zig and BEAM, then every claimed language. Mark future capability
   sketches as proposals; executing a later mixed journey is not this gate.
   Select native error, cancellation, iteration, ownership and cleanup behavior
   without requiring identical class layouts or scheduling models.
2. **Extract reusable data implementation from Station adapters.** Give shared
   Table storage/publication/index and catalog/query clients real Zig package
   owners under `packages/`, with manifests and direct dependencies. Keep behavior
   and turn adapters with Station. Runtime apps cannot depend on `sdks/` facades;
   the kernel remains independent of Station. Migrate current consumers through
   the package interfaces and preserve their existing qualified behavior. The
   ordinary client artifact must not require a Station runner or caller-hosted
   actor merely to use data. Keep pure codecs usable without credentials or I/O.
3. **Unify bounded client and host infrastructure.** Make data/catalog/query
   facets compose in one client context while leaving room for subscriptions,
   effects and service calls from their later owners. Replace mutually exclusive
   client host modes where they prevent composition. Define principal-sequence
   coordination, handle/buffer ownership, fair admission, worker/queue bounds,
   cancellation and joined shutdown. A context need not use one socket or thread;
   slow queries must not starve control progress. Preserve application-owned
   native loops and explicit Zig allocator/I/O control. Separate native-host and
   browser transport, credential and recovery-store profiles.
4. **Provide ordinary operations and explicit recovery control.** Reuse shared
   SQL result readers and owner-managed submission/staging/settlement so ordinary
   calls do not require application upload/poll/continuation queues. Keep
   prepare/save/dispatch and low-level step control for advanced callers. Specify
   recovery-store hooks, failures and the guarantee without a store; persist exact
   prepared work before dispatch when caller-loss recovery is promised. Bind
   operation keys to scope, content, definition and receipt lifetime. Preserve
   uncertainty, incomplete results and original identity; a local await is not
   a durable record, and retry does not authorize new work. Transaction helpers
   must preserve provisional statement results, explicit commit outcomes and
   the callback/outbox boundaries from the transaction owner.
5. **Ship the foundation through representative installed clients.** Qualify
   direct data/query/transaction and recovery paths in Zig, Python and TypeScript
   first, including concurrent facets through the shared host. Existing consumers
   in every affected language migrate coherently; the representative set does
   not excuse a broken existing binding. Broader new operation/platform coverage
   remains [M21](21-service-and-sdk-coverage.md); full mixed and Station ergonomics
   remain [M34](34-programming-model.md).
   Apply the current-v1 cutover policy to incompatible ABI/stored semantics,
   regenerate fixtures, reject incompatible saved artifacts, and publish current
   behavior in caller/component/SDK owners as each slice lands.

## Remaining implementation plan — 2026-11-01

**Source basis:** `origin/main` at
`c8d060cb2dfcf3bc531ef2e41fcdf7d4f172c2d5`. Deliver ordinary data applications
through the public Zig, Python sync/async and TypeScript/Node clients on Linux
x86_64: declare and inspect a Table, write typed values, stream a verified SQL
result, commit a local transaction and recover the original uncertain operation
after caller loss. The installed application needs no Station artifact, caller
actor or application-managed staging/poll queue. KV, Stream, Queue and the
owner-gated Document facet remain required for full M9 completion.

This is the current execution sequence for the existing P0–P8 work packages.
It supersedes the incoming-gate assessments and next-step ordering in the
[October 31 plan](#remaining-implementation-plan--2026-10-31), while preserving
its delivered work and the [original acceptance matrix](#acceptance-matrix).
The records cited below qualify their own revisions; they do not establish a
combined pass at this source. M9 remains **In Progress**.

**Integration update:** the implementation was integrated with `origin/main` at
`f1c07455b8f3a788e8e91bce9981fae90a0706f6`. Its current-v1 definition cutover
and shared native/Go Serving caller are part of the integrated baseline; Serving
coverage does not supply the independent data bindings planned here. Roadmap
references use the new numbering: asset pipelines are M19, branches M20,
service/SDK breadth M21 and mixed programming M34. The source assessment below
retains the original planning revision; the delivered increment is recorded
[separately](#implemented-context-and-kv-recovery-increment--2026-11-01).

### Source assessment and changed prerequisites

| Owner | Available at this source | Consequence for M9 |
| --- | --- | --- |
| M9 shared packages | `transit-data-client`, Fuze `QueryValues`/`NeutralEncoding` and `transit-query-direct` already provide Station-independent Catalog, value and retained-reader owners. The data-client build rejects transitive Station imports. | Finish the binding/package extraction; do not repeat the delivered implementation move or add Catalog beneath the raw client, which would create a cycle. |
| M9 context | [`Context`](../../packages/zig/transit-data-client/docs/context.md) has bounded Catalog/SQL directories, separate active data/control permits, generation checks, SQL leases and joined closure. It has no admission queue, fairness guarantee or principal allocator. Each SQL facet reserves 40 MiB for its primary/control clients, plus metadata. | Extend the existing context. Managed result/transaction handles and aggregate resource accounting remain work; a lease wrapper alone does not provide them. |
| M9 persistence | [`LocalRecoveryStore` and `SqlRecovery`](../../packages/zig/transit-data-client/docs/recovery.md) persist frozen SQL submissions and command evidence with explicit process locking, atomic file publication and bounded enumeration. [`Executor.before_submit`](../../packages/zig/transit-sql-client/README.md#persisting-an-original-attempt) already closes the pre-send persistence gap. | Add domain adapters and real-service caller-death schedules. Do not rebuild the hook/store or describe loopback/file tests as installed recovery. Store ownership does not coordinate principal sequences. |
| M4/M5 | Completed shared statement results and local Table transactions supply bounded readers, authoritative completion, provisional statements, savepoints and original decision recovery. | Compose those owners directly. SQL BEGIN still selects Tables; native mixed selection has a separate explicit contract. |
| M6 direct KV | [`Catalog.callKV`](../../packages/zig/transit-catalog/docs/direct-kv.md) now declares, mutates, reads, pins and recovers named KV without a writer PID. [Installed KV evidence](../history/qualification/catalog.md#named-direct-kv-cutover--2026-10-31) covers lost replies and node replacement. | KV is available for client composition now. `Context` currently exposes only Table/log/Stream/Queue calls, so add its KV facet and owned recovery adapter. SQL `CREATE KV` remains unsupported. |
| M6 native transactions | [`DirectTransactionClient`](../../packages/zig/transit-catalog/src/DirectTransactionClient.zig) composes Table/KV state, Stream/Queue appends and offset/ACK settlements. [Installed mixed evidence](../history/qualification/transactions.md#installed-mixed-state-output-and-input-settlement--2026-10-31) recovers original statements and the common decision after two node replacements. | Begin the native transaction facet and recovery integration now. Preserve explicit object/partition selection, one statement sequence and savepoints. The remaining preparation/finalization fault matrix and clean integrated qualification still gate the broader claim. |
| M6 logs and SQL | Stream/Queue lifecycle, finite reads, claim waits and settlements are implemented. [Installed declaration SQL](../history/qualification/sql.md#stream-and-queue-declaration-sql--2026-10-31) covers DDL and metadata through native SQL, console, PostgreSQL and MySQL. Explicit paired DLQ statements are implemented. | Compose typed payload operations and reuse SQL results for declarations. Workload SQL verbs, retained `STREAM_SLICE`, mixed SQL, automatic DLQ scheduling and installed transfer qualification remain M6 work. |
| M7 Documents | Logical algebra, `DocumentPartition`, tree/shredding and retained-storage foundations exist; the [public caller and consumer cutover](07-document-storage-and-station-decoupling.md#implementation-plan-for-remaining-work) remains unfinished. | Keep direct Document APIs and transaction participation gated. M7 supplies the minimal public caller and migrates affected consumers; it must not wait for M9's complete language redesign. |
| M8 gateways | Event-driven recovery and local SQL composition are delivered. [Resumable PG/MySQL command engines](08-gateway-architecture-and-protocol-ingress.md#resumable-command-session-implementation--2026-10-31) now emit neutral requests/output; the installed host still has blocking workers and timer races. [Startup reductions](08-gateway-architecture-and-protocol-ingress.md#installed-startup-reduction-plan--2026-10-31) have paired iteration evidence. | Use the existing SQL client/service seam. CPU-scaled scheduling, socket deadlines, coarse remote execution, broader ingress and final performance gates remain M8 obligations. Measure SDK startup separately from server readiness. |
| M20 branches | A [read-only immutable single-Table branch](20-branches-merges-and-restore.md#local-table-branch-increment) is available through typed callers with retained definition/data attribution. Whole-catalog and writable branches remain open. | Preserve full branch identity and existing branch reads through extraction. Do not globally force branch one, widen transaction branch support or promise writable/merged branches. |

The [client qualification record](../history/qualification/sdk.md#local-sql-recovery-and-context-leases--2026-10-31)
includes passing package/native checks and actual-file plus scripted SQL tests.
It also retains earlier failed/incomplete clean lanes. Recent KV, mixed and SQL
records likewise distinguish installed schedules from clean co-built lanes.
Re-run affected gates at the integrated definition; neither unioning old passes
nor fixing a fixture certifies the new client boundary.

### Dependency order and completion checkpoints

Keep P0–P8 stable so earlier implementation and evidence remain traceable.
P0/P1/P2/P4/P5 are **In Progress**; P3/P6/P7/P8 are **Planned**. Ready incoming
operations do not mean their context or installed-language adapters have landed.

| Change order | Existing work packages | Reviewable outcome | Dependency and exit gate |
| --- | --- | --- | --- |
| 1 | Finish P0; audit remaining P1 | Updated neutral context/recovery contracts, capability matrix, language journeys and installed resource baseline | Current owner contracts and build/load graph; negative fixtures distinguish refusal, possible acceptance, known outcome and cleanup failure. |
| 2 | Complete P2 | Principal coordination, bounded fair admission and aggregate ownership over the existing context | Change 1; deterministic saturation, multiple scopes, cancelled waits, stale handles and close races preserve control progress and ownership. |
| 3 | Complete P4 | Ordinary Catalog/KV/log operations and durable original-attempt recovery using the existing store | Changes 1–2; persist-before-send and store/send/receipt failures pass against real services with caller replacement. |
| 4 | Complete P5; begin available P7 integration | Managed SQL results, explicit Table transactions and native mixed transaction handles | Changes 1–3; shared result/decision semantics and owner-specific participant checks pass through the composed Zig API. |
| 5 | P3 and remaining P1 | Independent data ABI/port with generated resources and bounded multiplexing | Changes 2–4 define semantics first; independent ABI/port consumers prove lifetime, malformed-input, cancellation and slow-output behavior. |
| 6 | P6; available P7 clients | Installed public Zig, Python sync/async and Node APIs; coherent migration of affected existing consumers | Change 5; real isolated applications run with Station artifacts absent and preserve existing raw/framework capabilities. |
| 7 | Complete P7 | KV/Stream/Queue lifecycle and mixed composition, then direct Documents after M7 handoff | Each owner's executable caller and relevant participant gate; every promised kind has recovery, revocation and bounded-read evidence. |
| 8 | P8 | Common-revision qualification, resource comparison and public documentation | All preceding exits and affected M3/M8 installed profiles; update milestone/index status only after every completion requirement passes. |

The first Table/SQL installation checkpoint is changes 1–6. It need not wait for
all of M6–M8, historical catalogs or Station's replacement. Add already available
KV/log facets as their adapters pass; do not postpone their shared contract design
until after ABI publication. Document-specific completion remains conditional on
M7. A Table-only release cannot close M9.

### 1. Finish the contract and resource baseline

Update the [neutral context decisions](#proposed-neutral-client-context-contract)
against the implemented context and recovery guides before extending public
handles. Domain truth stays in
[data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[direct operations](../../contracts/DIRECT_TABLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md) and
[SQL sessions](../../contracts/SQL_SESSION_V1.md).
Specify which operations prepare pure values, read metadata, commit independently,
propose transaction work or merely observe accepted work. Map each operation to
its current capability, authority, cancellation and recovery owner.

Freeze fixtures for exact scope/content identity, five-state cells, wide integers,
decimal coefficient/scale, definitions and collation descriptors. Review the
[language sketches](#language-contract-review) against direct writes, bounded
reads, lost commit replies and cleanup failure in every affected language.
Generated declarations carry these semantics; SDKs still own idiomatic types,
iteration and scheduling. Unsupported server/type/participant combinations must
refuse explicitly rather than falling back to Station or a different operation.

Run the [SDK baseline workloads](#sdk-performance-baseline-and-optimization-gates)
through currently shipped Zig/Python/Node packages before optimizing. Charge
the existing 40 MiB SQL facet reserves, recovery buffers, host workers, queues,
retained batches and language objects separately. Freeze workload-specific
latency/throughput/memory/control-delay budgets from those measurements. Existing
console and startup improvements are comparison context, not SDK results.

### 2. Complete context coordination and ownership

Extend `transit-data-client.Context` and its admission owner; retain explicit Zig
allocator/I/O injection and the existing generation/close checks. Add finite
queued-admission counts/bytes and deadlines, FIFO within a lane and fair selection
among eligible facets. Preserve immediate typed refusal as an explicit policy.
Parked Queue/Stream waits and slow results must leave independent bounded capacity
for cancellation, lease controls, receipt observation and unrelated facets.
Use shared `transit-io`/memory owners; do not create a pool per facet.

Coordinate native sequences by realm/principal within the original authority
instance across participating handles, separately from domain operation IDs and
SQL client tokens. Use explicit exclusive
principal ownership for the first profile; external/cross-process allocation
requires its own owner-qualified contract. A recovery-directory lock or observed
server counter cannot reserve sequences. Uncertainty blocks only the sequence
scope whose owner requires it, and credential refresh preserves the original
identity. Reject conflicting ownership rather than silently assigning new work.

Define managed operation/result/transaction handles with explicit charged bytes
and generation checks. Closing refuses new data, allows bounded control work,
joins active native ownership and reports unresolved remote work separately.
Cancelling the close await leaves a retained owner responsible for joining.
Keep live memory and native code mappings until their actual lifetime fence;
do not replace the existing Rust/.NET loader guarantees with a timer.

### 3. Finish ordinary operations and durable recovery

Build bounded domain adapters over `Catalog` and the existing saved-operation
codecs. Ordinary calls and advanced prepare/save/dispatch/step APIs must share
one implementation of preparation, staging, admission and observation. Accepted
execution remains with the service owner; use its bounded public progress calls
where necessary, without asking applications to operate a continuation queue or
adding a client-owned durable scheduler. Stop recovery activity when settled.

Use `LocalRecoveryStore` as the first explicit Linux store, with its process-held
exclusive lock; per-record expiring claims are not a prerequisite. Custom store
hooks must meet the same exact-original, atomic-update and bounded-enumeration
contract. Preserve the current SQL adapter and extend recovery to Catalog, direct
KV, Stream/Queue mutations and transaction controls. Persist original bytes
before any accepting send and returned staging/statement references before a
dependent send. Size admission against the whole encoded record; the default
store budget is not enough for every legal domain payload. Refuse oversized work
before dispatch or admit it under an explicitly configured bounded budget.

Preserve two independent observations: what the remote owner established and
whether local evidence was saved. Store failure after a known commit cannot
become rejection or authorize a new token. Records saved before a send may remain
unresolved when the owner has no status; absence is not proof of rejection.
Reopen with current credentials and the exact instance/account/scope. SQL recovery
observes the original token without replay; other domains use only their specified
exact-retry operations. Never restore an interactive SELECT by executing it again.
Without a store, return owned recovery material and promise no caller-loss
recovery once that material is lost. No implicit expiry or quota-driven forgetting.

### 4. Own results and transactions through the shared context

Compose `Executor`, `ResultSet`, `Window` and `Pending` through managed handles
above the existing SQL leases. The handle must outlive executor calls and borrowed
batches; schema/observation, copied windows and transport storage keep distinct
owners. Reserve a separate control path while a result is held. Verify empty,
multi-batch and nested values, early close, retained copies, malformed completion,
session loss and current authorization after buffering. A display limit, transport
EOF or missing terminal never supplies complete coverage.

Expose explicit begin/statement/savepoint/commit/rollback/inspect/attach controls
before transaction context managers. SQL Table transactions retain their current
selection and service-managed tokens. The native facet uses M6's
`DirectTransactionClient`, explicit object/partition directory and original
statement requests; it must not widen SQL BEGIN or add another coordinator.
Preserve provisional counts, common cuts, permanent consumed identities, stale
workspace-read rejection and final decision versus cleanup progress. Persist
BEGIN, staged statements, savepoints and decision controls with their distinct
owner identities. Reattachment is explicit; inspection alone does not attach.

Language scope exit must preserve both an application exception and unresolved
commit/rollback/cleanup evidence. Never rerun a callback automatically. A mixed
transaction can atomically settle an input, mutate state and append an intent;
that does not dispatch an external effect. Keep Document participants refused
until M7 supplies the same decision obligations.

### 5. Extract the data binding and migrate installed clients

Implement the proposed `packages/zig/transit-data-bindings` and
`apps/transit-data-host` only after the shared ownership semantics above exist.
Keep `apps/transit-client-host` usable as the lightweight raw port. One data host
composes Catalog, SQL and qualified facets with bounded request IDs, work queues,
frames and output. A slow port consumer must not starve control or cause unlimited
buffering. Native batch borrows and port-owned copies have separate lifetimes
and bounds. Pure codecs remain usable without credentials or a running host.

Extract ordinary Catalog/query/value bindings from Station; retain behavior and
turn actions there. Real libraries own manifests, direct dependencies, generated
schemas and checks. Runtime code imports shared packages, never `sdks/` facades.
Client-only installations must actually load/run without Station native images;
renaming exports is insufficient. Preserve shared type identity when client and
Station packages are installed together.

Ship the reviewed public Zig, Python sync/async and Node journeys first. Python
cancellation and Node `AbortSignal` preserve native join ownership and original
outcomes; iteration uses bounded demand. Migrate every incompatible existing
language, runtime/browser consumer, generated resource and example in the same
current-v1 cutover. Internal components can land incrementally; superseded public
data exports cannot remain as compatibility shims. Replace the shared definition
identifier for incompatible ABI or stored semantics and regenerate schemas,
binding resources and signing fixtures together. Keep root `VERSION` and exact
pins aligned and reject old definitions in native libraries, hosts and saved
records without deleting recovery material. New language/platform breadth stays
with M21; preserving an existing affected binding is an M9 obligation.

### 6. Complete data-kind integration and later handoffs

| Facet or later owner | Required M9 integration or preserved extension point | Gate retained by the owner |
| --- | --- | --- |
| Direct KV | Add `Context` access, ordinary declare/resolve/mutate/get/pin/release and exact recovery; qualify values above native-turn limits and missing versus NULL. | Reuse the implemented M6 direct caller and native transaction profile. Native resource associations/grants are not direct KV authorization. |
| Stream | Compose append, finite retained reads/waits, assignment, offset settlement and explicit read release with the same context/store. | Reading or iterator close never commits an offset. Continuous subscriptions and snapshot-to-tail delivery remain M12/M32/M34 work. |
| Queue | Compose enqueue, original claim/wait recovery, pages, ACK/NACK/extension and payload-read release. Carry original leases through language values. | Wait timeout is not an accepted empty claim; payload-read release is not NACK. Stale leases cannot settle. Automatic DLQ scheduling stays in M6. |
| Native mixed work | Expose the existing state/append/settlement participant vocabulary and exact decision recovery; add paired transfer after its installed gate. | M6 owns remaining mixed fault qualification and Station/effect consumer migration. A typed variant alone does not qualify an installed transfer. |
| Document | Integrate M7's shared direct caller, accepted revisions, five-state cells, exact recovery and qualified participant when delivered. | M7 owns public dispatch, the acceptance/consumer cutover and atomic Document participation. Private candidate bytes are not accepted revisions. |
| [M10](10-standards-and-catalogs.md#delivered-implementation-evidence--2026-10-30) / [M11](11-indexing-and-access-paths.md) | Preserve exact definitions, comparison/type descriptors, operation progress and metadata observation through generated/native APIs. | Standards/helper tests do not establish executable historical catalogs, constraints or indexes. Their durable runtime/SQL integrations stay with those owners. |
| [M12](12-sql-and-dataflows.md#delivered-implementation-evidence--2026-10-30)–[M15](15-data-centric-compilation-and-specialization.md) | Bounded batch/lease APIs and measured bridge costs must accept later operators without changing logical completion. Preserve finite, captured and maintained lifetimes. | Component dataflow/string helpers do not establish durable activation, a metered service, integrated search or AOT execution. No SDK-side query scheduler. |
| [M16](16-document-profiles-and-gateway-exchange-lifecycle.md)–[M20](20-branches-merges-and-restore.md) | Keep typed codec and kind/definition/branch attribution extensible; retain the implemented immutable Table branch profile. | Document profiles, spatial/foreign adapters, asset pipelines, writable branches, merge and restore require their own current-v1 integration and proof. |
| [M21](21-service-and-sdk-coverage.md) / [M34](34-programming-model.md) | Supply independent packages, composable facets and shared recovery semantics. | M21 expands operations/platforms/Flight/browser coverage. M34 owns complete mixed programs, standalone recorded effects, durable subscriptions and typed Station calls. A Node filesystem store proves no browser recovery profile. |
| [M22](22-formal-semantics-and-correspondence.md), [M23](23-storage-providers-and-concurrency.md)–[M26](26-clustered-execution.md), [M27](27-control-and-policy-plane.md)–[M33](33-recorded-mcp-integrations.md) | Preserve replayable transitions, exact authority identity, current authorization and source-bound public observations. | Formal/distributed, governance, Board, publication and agent integrations do not extend M9's local delivery claim. Board inspection stays read-only. |

### Verification and first implementation changes

Retain the [acceptance matrix](#acceptance-matrix) and
[performance experiment](#sdk-performance-baseline-and-optimization-gates).
The following checks are planned work, not results of this planning change.

| Boundary | Required checks |
| --- | --- |
| Context and recovery | Owning `zig build test`/`check`; deterministic multi-scope admission/sequence/close traces; allocation failure; disk-full/torn-record/lock/sync failures; SIGKILL the caller before send, after acceptance and before receipt save against a real Transit service. Reopen and reconcile only the original work. |
| SQL and native participants | Existing SQL result/gateway and `just test::sql-transactions` schedules; `just test::direct-kv`, `just test::direct-state-transaction`, `just test::direct-mixed-transaction`; extend them through the composed client. Include buffered revocation, final lease expiry, lost decisions, retained cuts and cleanup failure. |
| Logs and declarations | Existing `just test::direct-table-service tables`, `queues`, `stream-maintenance` and `just test::sql-log-declarations`; extend installed clients for original claim recovery, explicit offset/lease settlement and empty/multi-batch metadata. |
| ABI and installed packages | `just check contracts`, `just bindings::check`, public Zig consumer and independent ABI/port consumers; installed Python/Node catalog feedback plus new context/SQL/recovery journeys; every affected language's complete suite. Test malformed values, incompatible definitions and actual loaded dependency closure. |
| Resources and progress | Fixed resident budget while retained records exceed caches; counting-allocator checks after warmup for admitted shared hot paths; slow queries/parked waits alongside control and multiple principals. Measure OS/I/O allocations separately from bridge/language allocation and GC. |
| Integrated revision | Affected committed-source `core`, `storage-query`, `interfaces-sql`, `interfaces-relational`, `sdks-conformance`, `sdks-scripting`, `sdks-systems`, `sdks-managed` and installation/browser lanes selected from the final diff. Preserve failed, skipped and incomplete runs; do not describe selected lanes as complete qualification. |

Use the pinned shells, [SDK inventory](../../tests/sdk/README.md),
[interface schedules](../../tests/interfaces/README.md) and existing
[task owners](../../tasks/README.md). Register new executable scenarios with their
actual callers; do not add placeholder success tasks. Record source and artifact
hashes, toolchains, workload/bounds and raw results in
[SDK qualification](../history/qualification/sdk.md), linking domain proof owners.
Promote supported behavior into caller/SDK/component documentation with each
implementation slice. Run link/whitespace and affected handbook checks, and
`python3 -B tasks/version.py` after manifest changes.

The next three implementation changes are concrete:

1. Complete P0's source/capability and installed resource baseline; specify the
   principal/admission and managed-handle transitions over the existing context.
2. Implement those P2 transitions, add the missing context KV dispatch and its
   data/control classification, and prove bounded concurrency/close without
   changing the owning KV semantics.
3. Add P4's ordinary Catalog/KV recovery adapters and real-service killed-caller
   proof using the existing store. Build P5's result/native transaction ownership
   on those transitions before publishing the independent data ABI.

Keep M9 open until the complete installed representative matrix, all promised
facets and common-revision resource/recovery gates pass. M42/M43 can combine and
distribute that evidence later; they cannot substitute for M9's own exit gates.

### Implemented context and KV recovery increment — 2026-11-01

The source assessment above remains tied to its recorded base. This increment
adds `Context.callKV` with the existing direct owner's data/control classification,
plus opt-in finite admission waits for Catalog, KV/log/Stream/Queue and SQL leases.
Queue metadata is preallocated, lanes remain separate, eligible waiters keep FIFO
order and cancelled/expired/closing data waiters release their facet ownership.
Control waits survive closing until joined. Queue counts bound metadata, not the
host's stacks, borrowed buffers or whole-process memory.

`KVRecovery` reuses `LocalRecoveryStore` and the existing saved-mutation codec.
It persists before dispatch, observes the original binding under current rights,
validates accepted evidence with the storage owner and keeps receipt-storage
failure separate from the known service outcome. The installed KV schedule now
kills the caller after acceptance and before reply delivery, removes the old
standalone fixture save, and replaces both caller and node before recovery from
the store. The [executed qualification](../history/qualification/sdk.md#bounded-admission-and-direct-kv-recovery--2026-11-01)
records the passing scoped checks and failed/incomplete broad lanes separately.

P0/P2/P4/P5 remain **In Progress**. Direct data requests use domain operation
identities and signed proofs, so they do not consume or allocate native principal
sequences. Native sequence coordination remains required when native commands
join the context. The resource baseline, aggregate byte accounting, ordinary
Catalog/log settlement, managed results/native transactions, independent data
ABI/port, installed Python/Node matrix and Document handoff remain open. This
increment does not close M9 or substitute local queue tests for host scheduling
or installed-language evidence.

## Remaining implementation plan — 2026-10-31

Historical source assessment and delivery order, superseded by the
[November 1 plan](#remaining-implementation-plan--2026-11-01). The implementation
and qualification records below retain their original scope; incoming KV,
transaction, SQL and gateway gates describe the earlier source.

**Source basis:** `40917354507bdc38658ad5dca8c8448da6807f02`. This refresh
sequences the remaining P0–P8 work against the checked-in implementation. The
[initial plan and extraction records](#implementation-plan--2026-10-29) retain
their dated evidence; their earlier incoming-gate assessments are historical.
This planning change establishes no new runtime qualification.

### Implemented context and submission slice

The implementation from this refresh is based on `b60f12154` after
integrating the latest M8 wire and M20 branch work. It advances P2 and the SQL
submission prerequisite of P4; it does not complete either work package.

- `transit-data-client.Context` owns bounded, generation-checked Catalog facets
  over supplied allocator/I/O. Separate data/control admission covers the existing
  Table/log/Stream/Queue operations. Closing refuses new data work, retains
  control access until joined, and preserves ownership after timeout/cancellation.
- SQL facets now compose through explicit context leases over the existing
  executor. Negotiation, borrowed-result lifetime and cancellation are explicit;
  primary/control clients retain independent reserves. This advances P5 without
  establishing managed result handles, shared concurrent response storage or
  installed language composition.
- `Executor.Options.before_submit` freezes SQL text, canonical parameters,
  original token and observed account/instance/database/source/transaction scope
  before execute. Its borrowed `Submission` excludes session credentials.
  Callback failure prevents dispatch; recovery validates the original definition
  and account/instance and uses the existing token observer without replaying SQL.
- Package tests cover deterministic capacity, allocation failure, stale handles,
  close races and result ownership. SQL loopback tests check persistence ordering,
  store failure/cancellation, scope substitution, context denial, lost replies
  and recovery-record validation.
- `LocalRecoveryStore` now supplies explicit Linux local-file storage with a
  process-held exclusive lock, checksummed definition-bound records, immutable
  original bytes, revision-checked evidence updates, atomic publication and
  bounded enumeration. `SqlRecovery` connects it to the executor and preserves
  known command outcomes when receipt persistence fails. Actual-file and loopback
  tests do not establish real-service caller-loss, power-loss or installed
  foreign-language qualification.

The [context guide](../../packages/zig/transit-data-client/docs/context.md) and
[SQL persistence API](../../packages/zig/transit-sql-client/README.md#persisting-an-original-attempt)
own the current semantics. Remaining work includes P0's representative resource
baseline, principal coordination, fair queued admission, managed result/transaction handles,
store process-loss qualification and ordinary Catalog settlement, generated data ABI/host,
installed language APIs, and each M6/M7 public handoff. The source inventory below
records the pre-implementation audit; the ordered work packages remain the
completion gates.

[Executed qualification](../history/qualification/sdk.md#local-sql-recovery-and-context-leases--2026-10-31)
records the local store and SQL lease checks. The earlier context/submission
account records native checks, the reproduced baseline CLI diagnostic failure
and the SQL source-provisioning timeout. Neither clean lane is a complete pass.

The first installed outcome remains a Linux x86_64 application using the public
Zig, Python sync/async or TypeScript/Node client to declare a Table, inspect its
definition, write typed values, stream SQL results, commit a local multi-Table
transaction and recover the original uncertain operation. It requires no Station
artifact, caller actor or application-managed staging/poll queue. Full M9 closure
also requires the qualified KV, Document, Stream and Queue facets; Table delivery
alone does not complete the milestone.

### Current implementation and gaps

| Boundary at this source | Available implementation | Remaining M9 work |
| --- | --- | --- |
| Independent data caller | [`transit-data-client.Catalog`](../../packages/zig/transit-data-client/src/Catalog.zig) owns explicit Catalog calls and per-attempt evidence; its build rejects transitive Station imports | Shared context, admission, principal coordination, ordinary completion and durable recovery-store integration. The current handle returns `Busy` on overlap and creates no pool. |
| Values and direct readers | Fuze `QueryValues` / `NeutralEncoding` and `transit-query-direct` own the extracted deterministic values and retained Table readers | Preserve exact shared types and qualified source lifetimes; remove remaining ordinary data binding/package coupling without moving native-turn helpers indiscriminately. |
| SQL and transactions | M4's `Executor`/`ResultSet` and M5's local Table transactions are implemented; the Zig SDK exports their owners | Bind them once into the common data context and language APIs. Expose a pre-dispatch persistence boundary for SQL attempts and transaction controls. |
| Stream and Queue | `Catalog.callLog`, `callStream` and `callQueue` already provide typed lifecycle/payload/recovery operations, finite reads, fenced settlements and bounded waits | Compose these operations into the context and representative clients. New primitive semantics, SQL verbs, atomic DLQ and mixed participants remain M6 work. |
| KV and Document | M6 has `KVPartition` and KV authority; M7 has direct Document contracts, algebra, `DocumentPartition`, authority and storage-graph foundations | Named direct KV and public direct Document dispatch/caller cutovers remain incoming gates. Neither a storage type nor a generated descriptor establishes an installed API. |
| Native bindings and ports | Raw ABI/host remain independent. Catalog/relational language APIs still live under Station; Station host modes remain exclusive | Independent data ABI, composable data host, generated resources, language ownership and coherent migration of every affected consumer. |
| Packaging and qualification | Existing installed SDK schedules and the earlier SQL resource baseline are reusable | Demonstrate actual client-only dependency closure, simultaneous facets, caller-loss recovery and common-revision correctness/resource evidence. |

The [Queue wait evidence](../history/qualification/catalog.md#bounded-public-queue-claim-waits--2026-10-31)
includes a passing focused installed Queue schedule, a failed clean core lane
and a later failed Station service deadline. The separate successful recovery
of that service's original input does not turn either failed run into a pass.
Reproduce affected baselines before attributing new failures to M9; preserve
original recovery material and unchanged correctness/deadline assertions.

### Previous milestones and incoming gates

| Owner | What M9 consumes | Dependency boundary |
| --- | --- | --- |
| [M1](01-declarative-data-lifecycle.md), [M2](02-storage-and-query-performance.md), Completed | Scoped object/definition identities, frozen work, retention and bounded durable storage contracts | Reuse identities and public callers. No client-owned catalog, storage access, implicit expiry or total-cardinality resident queue. |
| [M3](03-live-storage-and-sql-cutover.md), In Progress | Installed direct lifecycle, definition changes, retained reads and restart paths | Run client journeys against those installed owners. Remaining M3 qualification stays with M3; a client wrapper cannot repair an unqualified service profile. |
| [M4](04-statement-results-and-consumption.md), Completed | Command outcomes, one logical result, typed batches, observation and verified terminal coverage | P5 adapts these types rather than introducing another result protocol or parsing SQL text to infer command kind. |
| [M5](05-transactions-and-atomic-composition.md), Completed for local Tables | Common cuts, provisional DML, savepoints, original decisions and explicit reattachment | Deliver Table transaction APIs now. KV/Document/append/settlement participation requires the separate M6/M7 handoff. |
| [M6](06-streams-queues-and-durable-runtime.md#work-packages-and-dependencies), In Progress | Existing direct database separation and typed Stream/Queue operations, including waits | Start standalone Stream/Queue composition after the context boundary. Named KV, mixed transactions and the Station consumer replacement remain separately gated. |
| [M7](07-document-storage-and-station-decoupling.md#remaining-work-packages-and-gates), In Progress | Delivered internal Document foundation; future public caller and atomic consumer replacement | M7 supplies the minimal shared caller/ABI with its cutover. It must not wait for M9's complete host or language redesign; M9 subsequently composes that caller. |
| [M8](08-gateway-architecture-and-protocol-ingress.md#remaining-implementation-plan--2026-10-29), In Progress | Event-driven recovery, typed local dispatch and selected node SQL co-hosting | Use the delivered local service seam. Configuration handoff, coarse remote execution, transport scheduling and integrated performance remain owner work; qualify each placement before claiming it. |

Do not turn these milestones into an all-or-nothing start gate. P0/P1 and
deterministic P2 work can proceed immediately. Table/SQL delivery uses the
implemented M3–M5 owners and selected M8 placement. Standalone Stream/Queue
facets need their public operation evidence, not a completed Station migration.
Only mixed participant exposure and dependent Station changes wait for M6/M7
atomicity. M9 stays open while any promised facet remains unqualified.

### Ordered implementation changes

Keep the existing P0–P8 identifiers. Each change below carries its owning public
documentation and focused verification; generated declarations are never the
sole evidence that an operation executes.

1. **Complete P0 with executable contracts and a measured baseline.** Extend
   `transit-data-client` with neutral context configuration, scoped facet handles,
   operation knowledge, ownership and recovery-store types. Specify them in a
   package-owned contract guide before exporting an ABI. Retain domain meanings
   in `DATA_LIFECYCLE_V1`, `DIRECT_TABLE_V1`, `SQL_RESULTS_V1` and
   `SQL_SESSION_V1`. Generate shared fixtures for validation failure,
   pre-dispatch refusal, possible acceptance, known terminal outcome and cleanup
   failure. Review the existing language sketches against these exact cases.
   Measure current native, Python and Node startup, processes/threads, reserved
   memory, copies, completion latency and close/cancel cost with matching
   installed inputs; the historical console baseline cannot stand in for these
   client measurements. **Exit:** neutral transitions and negative fixtures
   execute, package ownership is acyclic, and comparison workloads/budgets are
   recorded before implementation claims.
2. **Finish P1 and implement P2's context independently of an ABI.** Keep Catalog
   below `transit-data-client` and the raw client below Catalog. Compose the
   existing SQL client and shared `transit-io`/memory reserves above those owners.
   Supply Zig allocator/I/O injection and one host-owned resource configuration
   for foreign callers. Add bounded data and control admission, generation-checked
   handles, per-scope sequence coordination, and `open -> closing -> joined`
   ownership. A slow SQL fetch or parked Queue/Stream wait must leave capacity
   for control and unrelated facets. A store claim alone does not allocate a
   native principal sequence across processes: require explicit exclusive
   principal ownership or an owner-qualified external allocator.
   **Exit:** deterministic saturation/cancellation/close tests, counting-allocator
   checks after warmup and existing Catalog/value/reader regressions pass; one
   context does not allocate a worker pool per facet.
3. **Implement P4's frozen-attempt and store boundary before convenience APIs.**
   Add shared ordinary Catalog preparation/staging/admission/settlement over
   the existing explicit calls. First extend the shared SQL executor so the
   original account/instance/token and canonical request can be persisted before
   its first potentially accepting send. The implemented callback now exposes
   this ordering; integrate it with the durable store and ordinary Catalog path.
   Saving only the returned `Outcome` leaves a caller-crash gap. Make ordinary `execute` and advanced
   prepare/persist/submit consume the same implementation. Freeze the owning
   fingerprint inputs, selected database/source, parameters, execution mode and
   applicable transaction/session binding without serializing credentials.
   Persist subsequent owner references before dependent dispatch. Lost initial
   SQL replies use the original token and observation owner; a missing status
   is not permission to recompile or send a replacement statement. Interactive
   SELECT results remain non-resumable after session loss. Apply this ordering
   to BEGIN, statements and COMMIT, not only Table writes.
   The local store and SQL adapter now provide atomic update, exclusive process
   ownership, bounded paging and private permissions. Add the remaining domain
   adapters, recovery claims and real-service process-loss qualification.
   **Exit:** injected failure
   at each store/send/receipt boundary preserves the original identity; known
   commitment and failed receipt persistence remain separate observations.
4. **Implement P5's SQL/result/transaction facet in Zig.** Compose existing
   `Executor`, `ResultSet`, `Window`, `Pending` and explicit transaction controls
   under context permits. Keep schema/observation ownership separate from batch
   borrows, bounded retained copies and transport buffers. A retained result
   cannot silently monopolize the control connection. Preserve incomplete
   prefixes, authoritative counts, provisional transaction statements, stale
   workspace-cursor rejection, original commit decisions and cleanup progress.
   Define transaction-scope exit before adding context-manager conveniences:
   explicit commit/rollback can remain unresolved; host cancellation or close
   establishes neither. Never retry an application callback.
   **Exit:** real local SQL tests cover empty/multi-batch/nested results, early
   close, current authorization, lost commit replies and replacement-session
   reattachment through this composed caller.
5. **Implement P3's independent data boundary and perform the P6 cutover.**
   Add the proposed `transit-data-bindings` package with generated context,
   operation, result/batch, cancellation and shutdown resources. Preserve the
   lightweight raw-only `transit-client-host`; compose all data facets in one
   proposed `transit-data-host` executable rather than expanding raw-only
   dependencies or starting one process per facet. The data host may also expose
   raw operations through their existing owner. Station's behavior host consumes
   shared types/bindings where needed; it does not remain the ordinary data API
   entry point. Bound multiplexed request IDs, frames, queued work and output;
   prove control progress under blocked reads and a slow stdout consumer.
   Native borrowed batches and port-owned copies have distinct explicit bounds.
   Migrate Python and Node public client packages, native distributions and the
   public Zig SDK with every incompatible affected SDK/runtime/generated
   consumer in one coordinated current-v1 cutover. Internal components can land
   first; do not leave old public data exports as forwarding compatibility
   shims. **Exit:** isolated installed declare/write/query/transaction/recovery
   programs run with Station artifacts absent; raw and existing affected
   capabilities still work with matching definitions and type identity.
6. **Integrate P7 per qualified data kind.** First compose delivered `callLog`,
   `callStream` and `callQueue` into the same context/store and representative
   clients. Wait timeout, an accepted empty claim, an incomplete read and a
   completed read remain different outcomes. Preserve original claim selection,
   current lease/generation checks and explicit Stream offset settlement.
   Distinguish Queue payload-read `release` from NACK and from freeing a local
   page. Iterator close frees local buffers; remote payload-read release and
   lease settlement remain explicit operations. Add direct KV and Document after
   M6/M7 deliver their public caller and replacement gates. Qualify each
   standalone facet separately, then expose transaction participation only when
   the owning mixed envelope executes. **Exit:** declaration, mutation,
   bounded read, lost-reply recovery and revocation pass for each promised kind;
   generated participant variants alone remain refused.
7. **Complete P8 on one integrated committed revision.** Run the affected
   installed language matrix, actual local and claimed remote gateway paths,
   caller/store/process-loss faults and resource comparisons. Carry the
   [acceptance matrix](#acceptance-matrix) into registered schedules, including
   preserved raw/Station consumers and incompatible-definition rejection.
   Promote supported APIs and limits to caller/SDK references, component guides
   and language docs as each slice lands. **Exit:** all P0–P8 obligations,
   including gated P7 facets, have attributed evidence; update the milestone
   header and roadmap index together only then.

The immediate reviewable change is step 1 plus deterministic context admission
types from step 2, followed by the SQL frozen-attempt seam from step 3. Do not
begin by moving Python/Node imports: their package boundary cannot become
independent until the shared data ABI and its complete dependency closure exist.
P3 follows the shared P4/P5 semantics even though its numeric label is earlier;
those labels identify work packages, not a requirement to publish adapters first.

### Later milestones and extension boundaries

| Later owner | Foundation M9 must leave usable | Work retained by that owner |
| --- | --- | --- |
| [M10](10-standards-and-catalogs.md), [M11](11-indexing-and-access-paths.md) | Lossless logical values and orthogonal type/collation/codec descriptors; exact definitions, pins, operation progress and diagnostics | Historical interpretation, constraints and index/rewrite operations. Support follows the executed owner, not a type tag or parser capability. |
| [M12](12-sql-and-dataflows.md), [M13](13-data-structures-and-performance.md), [M14](14-vectorized-strings-and-search.md), [M15](15-data-centric-compilation-and-specialization.md) | Bounded result batches, transferable ownership, measured bridge costs and distinct computation lifetimes | Managed computation activation, query/search operators, resource policies and compilation. No SDK scheduler, result-materialization requirement or baked-in storage/vector page size. |
| [M16](16-document-profiles-and-gateway-exchange-lifecycle.md)–[M20](20-branches-merges-and-restore.md) | Exact kind/definition/branch attribution, five-state values and owner-extensible typed codecs | Document profiles, spatial types, foreign relations and branches. Preserve branch fields while refusing unsupported branches; do not add executable placeholders or silently assume all references mean branch one. |
| [M21](21-service-and-sdk-coverage.md) | Independent client packages, shared ABI/port contracts and representative installed journeys | New language, service, browser, Flight/ADBC and platform breadth. Existing affected bindings still migrate in M9; Node filesystem recovery proves no browser profile. |
| [M22](22-formal-semantics-and-correspondence.md), [M23](23-storage-providers-and-concurrency.md)–[M26](26-clustered-execution.md) | Replayable deterministic context/knowledge transitions and original authority/instance identity | Formal correspondence and distributed/provider/failover qualification. Reconnecting to a different authority never silently resubmits accepted work. |
| [M27](27-control-and-policy-plane.md)–[M31](31-mcp-service-and-apps.md) | Current authorization and source-bound, bounded observations through shared public operations | Enterprise identity, published resources/investigations, reviewed changes, Board and MCP. Runtime consumers use shared packages; Board inspection keeps its read-only grant. |
| [M32](32-reactive-context-and-agent-activation.md)–[M34](34-programming-model.md) | Composable facets, shared values, original-operation recovery and explicit transaction/effect boundaries | Durable subscriptions, standalone recorded effects, typed Station calls and full direct/Station/mixed journeys. Finite Stream waits do not establish continuous subscriptions. |
| [M41](41-sql-grammar-and-dialect-ergonomics.md), [M42](42-qualification-and-benchmarks.md), [M43](43-releases.md) | Version-bound generated resources, precise capability reporting, installed examples and reproducible measurements | Grammar harmonization, combined qualification and distribution. M9 cannot defer its own installed correctness or matching artifact checks to release work. |

### Verification and delivery checklist

Use the pinned development shells and existing owners in
[installed SDK checks](../../tests/sdk/README.md),
[SQL interfaces](../../tests/interfaces/README.md) and the
[task reference](../../tasks/README.md). Extend their scenarios and inventory
with the new context/store/data-client journeys; do not invent successful
placeholder tasks. Planned checks below are not executed evidence.

| Change | Focused checks and required evidence |
| --- | --- |
| P0/P1/P2/P4 shared types, context and store | Owning package `zig build test`/`check`; independent failure-transition fixtures; allocator fault injection; real disk store reopen/torn-write/disk-full/concurrent-owner tests; retained Catalog and direct-reader regressions |
| P3 boundary/cutover | `just check contracts`, `just bindings::check`, independent ABI and port consumers, foreign/missing-definition refusal, stale handles, malformed values, bounded frames and joined close |
| P5 SQL/transactions | SQL client/result package checks and existing gateway/transaction schedules; inspect original receipts after lost replies, verify denied buffered disclosure, no snapshot splice and no callback replay |
| P6 installed consumers | `just bindings::feedback python --scope catalog` and `just bindings::feedback node --scope catalog` for the existing boundary; extend installed schedules for new context/SQL/store journeys; run the public Zig SDK and full affected language suites before claiming the cutover |
| P7 facets | `just test::direct-table-service tables` (includes Stream operations), `just test::direct-table-service queues` and `just test::direct-table-service stream-maintenance`, plus new representative language schedules; add KV/Document/mixed-participant schedules only with those public owners |
| P8 integration | Selected `just ci clean --lane core`, `--lane storage-query`, `--lane interfaces`, `--lane sdks` and installation/consumer lanes affected by the final diff, at committed HEAD; retain failed and skipped results distinctly |
| Documentation and packaging | `python3 -B tests/runner/docs.py`, whitespace checks and affected handbook checks; `python3 -B tasks/version.py` after manifests change; isolated installation and loaded-artifact checks |

Resource acceptance compares identical data, server revision, durability,
authorization and result consumption. Report cold startup separately from warm
steady state, native backing allocations separately from language objects/GC,
and completion/settlement separately from transport latency. Increase retained
rows and operations past cache/page capacity at a fixed resident budget; no
resident-memory term may grow with retained cardinality. Exercise slow reads
alongside Catalog work, parked waits, transaction controls and multiple principals. Record
concurrency, byte/queue limits and maximum observed control delay; do not call
admission fair merely because a single request completes. Set regression budgets
from the P0 baseline before comparing candidates, and retain regressions openly.

Record runtime results in [SDK qualification](../history/qualification/sdk.md)
with source, artifact hashes, toolchains, commands, workloads and raw reports;
link SQL/transaction/catalog/performance owners for their evidence. The repository
documentation check validates this plan's links and fences only.

## Implementation plan — 2026-10-29

**Source basis:** committed checkout `607c53fbace7bfb25ab5b4a119d5e84d4b49fbff`,
refreshed from the initial `b8aab78fb` audit after M8's first recovery slice
merged as PR #235 during this review. This is a source and contract assessment,
not new executed qualification. M8 is `In Progress`: foreground settlement and
event-driven recovery are implemented, while typed dispatch, co-hosting, coarse
remote execution and the remaining ingress/qualification gates stay open.
Further unmerged work is outside this source basis. The initial implementation
slice below starts M9 without claiming its remaining gateway or data-kind gates.

**Integration refresh:** the value/reader slice is rebased onto
`d64ebb7ce78346f83b96e81d498e38c90e591999`, including M8's PR #239. Typed
signed Table/native dispatch and installed node SQL co-hosting are now delivered
for the selected path. Configuration/reload still belongs to the installation
gateway; coarse remote execution, the remaining transport work and full placement
qualification stay open. Consume this partial handoff without treating P2a–P2c
as complete. The retained resource comparison below predates co-hosting and
measures the historical remote gateway placement, not this rebased runtime.

### Starting point and selected outcome

An ordinary installed application should declare a Table, inspect its exact
definition, write typed values, stream a finite SQL result, compose a local
Table transaction and recover the original uncertain operation without importing
Station, running a handler, allocating a caller actor or implementing an
upload/poll loop. Retain explicit low-level controls for applications that need
them. The initial representative targets are Zig, Python sync/async and
TypeScript on Node, on the currently supported Linux x86_64 installation profile.

| Evidence at the source basis | Consequence for this implementation |
| --- | --- |
| [Catalog](../../packages/zig/transit-catalog/README.md), [direct Query](../../packages/zig/transit-query-direct/README.md) and SQL already exclude Station from their database implementation | Preserve that extraction. Do not redo the old package assessment in M34 or move every `Table*` file merely because it remains in Station. |
| [Station exports](../../packages/zig/transit-station/src/root.zig) still include Table, Publication and ImmutableIndex helpers; [Query](../../packages/zig/transit-query/build.zig.zon) still composes Station and Station Document | Classify remaining reusable code separately from native-turn, captured-query and behavior adapters. Removing an import alone does not preserve their accepted-work or atomicity contracts. |
| [M4's shared client](../../packages/zig/transit-sql-client/README.md) supplies `Executor`, `ResultSet`, bounded windows, uncertainty and cleanup; [M5](05-transactions-and-atomic-composition.md#closeout--2026-10-28) is completed for local Table transactions | Bind these implemented owners. Do not create a new SDK result protocol or transaction coordinator. Native KV/Document, Stream/Queue and Station transaction participants remain later owner work. |
| [Python catalog](../../sdks/python/transit-station/docs/catalog.md) and [TypeScript catalog](../../sdks/ts/transit-station-sdk/docs/catalog.md) expose direct operations from Station packages; existing SDK catalog users drive prepare/stage/admit/execute themselves | Move ordinary data APIs into the client packages and add shared completion helpers, preserving advanced saved-intent controls and exact identities. |
| [Raw ABI](../../packages/zig/transit-client/docs/bindings.md) and [client host](../../apps/transit-client-host/README.md) are already independent; [Station host](../../apps/transit-station-host/README.md) has exclusive catalog/query/behavior/codec profiles | Preserve raw-only use while adding a composable data context. Avoid requiring one child process and I/O pool for each facet. |
| [M8 recovery evidence](../history/qualification/sql.md#event-driven-sql-recovery--2026-10-29) qualifies foreground pending settlement and event-driven recovery; the [matched comparison](../history/qualification/performance.md#event-driven-sql-recovery--2026-10-29) records zero post-statement idle upstream calls alongside write-latency regressions | Consume this delivered owner. Do not rebuild its recovery loop in clients or treat less idle traffic as proof that the latency target is met. |
| [M7](07-document-storage-and-station-decoupling.md#implementation-plan-for-initial-document-decoupling) has delivered the deterministic `transit-document` core and private `DocumentIndex` staging | This is not a public `DocumentPartition` service. Gate direct Document APIs on acceptance, retention, authorization and the coordinated consumer cutover. |
| [M13](13-data-structures-and-performance.md#implementation-plan-for-issue-194) and the SQL client already establish reusable reserves and explicit batch/statement lifetimes | Reuse those primitives and measure all added bridge/host costs. A new context must not reintroduce per-facet pools or per-row backing allocation. |

The first Table/SQL slice can ship before all of M6/M7. It is an intermediate
foundation gate, not completion of every declared data facet. P7 below requires
the owner-qualified KV/Document/Stream/Queue profiles and preserves their
remaining dependency gates. M21 owns broader new language, operation and
platform coverage; M34 owns complete mixed programs and Station ergonomics.
Existing affected bindings must migrate in the relevant cutover regardless of
whether they are in the representative new-feature set.

### Coordination and incoming gates

| Owner and status at the source basis | Handoff consumed by M9 | Work that can proceed and gate that remains |
| --- | --- | --- |
| [M3](03-live-storage-and-sql-cutover.md), In Progress | Installed catalog/data lifecycle, exact retained reads, maintenance/restart evidence and single-executable packaging | Inventory and Table API work can start now. Reuse the installed lifecycle schedules; M9 does not close M3's remaining storage/performance gates. |
| [M4](04-statement-results-and-consumption.md), Completed | Logical results, observation evidence, borrowed batches and terminal counts | P0/P5/P6 use the current result owner and its failure semantics directly. |
| [M5](05-transactions-and-atomic-composition.md), Completed for local Tables | Signed controls, provisional results, savepoints, original transaction handle, common cuts and explicit reattachment | P5 exposes the selected profile. Preserve whole-Table conflicts, explicit decision/cleanup and unsupported-participant refusal; do not assume reserved participant tags execute. |
| [M6](06-streams-queues-and-durable-runtime.md), In Progress | Delivered database/SQL decoupling; future direct KV, Stream/Queue operations and state/input/output transaction composition | P1 preserves the delivered database boundary. P7 waits for native operations, recovery evidence and the Station atomicity migration where affected. |
| [M7](07-document-storage-and-station-decoupling.md), In Progress | Shared Document semantics now; direct Document lifecycle and public replacement later | Reuse its types without copying merge logic. Do not expose private staged roots as accepted revisions or implement a temporary Station-backed direct Document API. |
| [M8](08-gateway-architecture-and-protocol-ingress.md#implementation-plan--2026-10-28), In Progress | Delivered foreground settlement/event-driven recovery and selected typed local dispatch/node co-hosting; configuration handoff, coarse remote submission, transport/control lanes and sans-I/O work remain | P0/P1 and deterministic context work can proceed. P4–P6 consume the delivered local seam while preserving M8's remaining P2a–P2c and applicable P3/P4 gates. P8 needs those qualified paths, not completion of unrelated Flight/Serving or new data-kind coverage. |
| [M13](13-data-structures-and-performance.md), In Progress | Memory/I/O reserves, accounting definitions, current SQL result lifetimes and regression measures | Share allocator/context changes and baseline workloads. M9 owns new client/bridge overhead; M13 owns broader database optimization and scorecards. |
| [M21](21-service-and-sdk-coverage.md), In Progress | Existing Go raw and SDK/console coverage | Preserve existing installed consumers during migration. New parity follows this foundation instead of extending the Station-shaped data bridge. |
| [M22](22-formal-semantics-and-correspondence.md#t2-statement-results-disclosure-and-uncertain-settlement), In Progress | Result/settlement models and implementation correspondence | Supply deterministic context/recovery transitions and replay fixtures; do not wait for all formal work or claim full refinement from bounded checks. |
| [M30](30-board-reimplementation.md), In Progress | Public catalog/SQL/browser consumers | Migrate shared boundary changes with their consumers, preserving read-only inspection and browser-specific credentials. Board runtime code never imports consumer SDKs. |
| [M43](43-releases.md), In Progress | Installed native/client packaging and release checks | Add matching generated resources and independent artifacts to current installation checks. New platforms and registry publication remain release/coverage work. |

Agree the M8 handoff before changing common code:

- The gateway owner owns `DatabaseRuntime`, service placement, session recovery,
  ingress pumps and wire-codec refactoring. M9 owns caller composition, native
  bindings, recovery-store integration and language adapters. Changes to
  `transit-sql-client`, `transit-io`, result lifetimes or generated definitions
  need one coordinated implementation and fixture update.
- Record the actual statement/control/recovery operations, capabilities,
  deadlines, cancellation behavior, session/instance binding and result leases
  in the owning contracts. Do not code against provisional `DatabaseHost` names
  or import server runtime/storage implementations into a SQL client.
- Preserve the delivered recovery distinction: a verified terminal data outcome
  can coexist with pending accounting or transaction cleanup. Status remains
  observation-only. Client cancellation, a failed receipt-store update or lost
  reply must not withdraw known completion or allocate replacement SQL.
- Ordinary SQL submission executes once through the shared client and M8's
  server-owned runtime. The remote placement's coarse submission is not a
  promise that fetching all rows or observing an uncertain outcome uses one
  exchange. Bounded observation through the existing settlement owner remains
  valid; new periodic SDK recovery daemons do not.
- Typed Table operations keep their owning catalog contract. If a new coarse
  typed submission is needed, specify it with Catalog/M8 first; hiding the old
  server orchestration cascade in a language wrapper does not meet that gate.
  Advanced staging controls remain explicit and bounded.
- Qualify co-hosted and supported standalone gateway paths against the same
  installed workload. Rebase the source inventory when the M8 handoff lands;
  earlier request-count/latency observations are historical baselines, not
  measured improvements for the new clients.

M7's direct contract and minimal shared Zig caller/ABI seam must not wait for
this milestone's complete context or language consolidation. M7 owns the atomic
public Document replacement and its affected-consumer migration; M9 then
composes that qualified caller into the common context. M8 hosts only qualified
routes. This ordering avoids a cycle in which M7 waits for M9 while M9 P7 waits
for M7. The same rule applies to M6's new primitive/participant handoffs.

### SDK performance baseline and optimization gates

**Remaining work:** extend measurement to installed SDKs now, using existing
qualified APIs; do not wait for the ordinary SQL/context APIs or all-language
coverage to land. The current console/resource and shared Zig allocation probes
do not measure a foreign-language host, its bridge, language objects or GC.
The catalog/value extractions above establish ownership, not SDK speedups.

Start with public Zig, Python and TypeScript/Node consumers, then extend the
same operation matrix to the other supported languages. Measure the currently
shipped Catalog/Query and raw-client APIs under their actual package placement;
add ordinary SQL, transactions and the shared context only when their adapters
exist. Keep unsupported combinations explicit in the report.

| Boundary | Baseline workload and observations |
| --- | --- |
| Cold application and context | Import/module initialization, native library/port startup, context open, connection/authentication and first verified operation; elapsed/CPU time, processes, threads and RSS/PSS |
| Language/bridge cost | Same typed values through shared Zig, native ABI/port and public language API; encode/decode time, copies, bytes, language allocations/GC and backing allocations measured separately |
| Established data calls | Empty/one-row reads, point/range/full reads, single-row and batch writes, fresh reads after mutation, metadata and supported prepared operations; first row, verified completion, rows/bytes per second and exact counts |
| Result consumption | Narrow/wide/nested values, multi-batch results, slow readers, early close and cancellation; bounded live memory, batch lifetime, per-row conversion and cleanup cost |
| Runtime and concurrency | Native send admission separately from completed Station calls/turns, supported concurrent facets, overload refusal, cancel/close and settled idle CPU/traffic; preserve existing one-call admission where applicable |
| Recovery | Lost replies and original-operation recovery, host restart, current revocation and interrupted result consumption; unresolved work is a failed/incomplete sample, never omitted or submitted under a new identity |

Implement the operation driver beside `tests/performance/`, reusing installed
SDK packaging and owned service fixtures from `tests/sdk/` and `tests/harness/`.
Use one independent value/count oracle and identical backend, schema, data,
batching, durability, authentication and completion boundaries for language
comparisons. Separate process-per-call from persistent-client results. A raw
admission receipt cannot be compared with console statement completion.
Record source, compiler/native binary and installed package hashes, language
runtime versions, filesystem, quotas and warmup/cache conditions. Keep instrumented
diagnostics separate from elapsed-time comparisons; do not subtract overlapping
server/bridge timings to manufacture client overhead.

First publish raw baselines and attribution, then freeze per-operation latency,
throughput, memory and allocation budgets before choosing optimizations. Use
at least three alternating matched pairs with 50 steady-state samples per arm
for the initial regression gate; retain cold-start cases separately and do not
infer p99 from that sample size. Extend offered-load and tail sampling explicitly.
Optimize measured costs in the shared client first, then bridge serialization,
batch conversion, repeated validation, host scheduling and language allocation
where attribution supports them. Re-run correctness/recovery and all affected
language consumers with each shared change. Report SDK improvements against their
own baseline; #211's historical SQL target is not a blanket SDK speedup claim.

#### SDK performance implementation sequence — 2026-11-01

**Status: In Progress within P0/P8.** Coordinate with the
[M8 follow-up delivery plan](08-gateway-architecture-and-protocol-ingress.md#follow-up-performance-delivery--2026-11-01)
at merged source `a000b8d18449fdee7901955d0c94417ceeab32eb`. Its startup probes
and the existing SDK conformance results do not establish SDK performance.
Start measurement on current installed APIs while P2–P6 continue; the following
work neither requires the new data ABI first nor marks those packages complete.

The installed Catalog/Query driver now covers public Zig, Python synchronous and
asynchronous clients, and Node with one bounded independent oracle, native/package
identity checks and explicit completion/close evidence. Its
[first exploratory campaign](../history/qualification/performance.md#executable-hashing-and-installed-sdk-measurement--2026-11-01)
uses the isolated maintenance-disabled profile. Default-maintenance and complete
integrated campaign qualification, allocation/copy attribution, broader values
and language coverage, future context/
SQL adapters and numeric regression budgets remain open. Node module import is
the leading measured cold-start cost; profile eager schema-validator compilation
next and measure launch through the first verified response so deferred work
cannot masquerade as a gain.

The application journey is to open an installed client, inspect a declared Table,
write/read typed values, consume a complete bounded result and close or recover
the original operation. Use the capability matrix to select public operations
that actually execute in each language. Raw send admission, a completed Station
call, a direct Table mutation and a terminal SQL statement are different cases.

| PR or split series | Implementation owner and dependency | Deliverable and exit |
| --- | --- | --- |
| Installed benchmark driver and oracle | `tests/performance/`, installed packaging from `tests/sdk/`, fixtures/reporting from `tests/harness/`; no new API prerequisite | One workload manifest, neutral report schema and independent value/count oracle; public Zig, Python sync/async and Node consumers execute supported cases from isolated installations |
| Baseline and attribution | Existing shared Zig/native ABI/port plus each language host; depends on the driver | Frozen uninstrumented measurements and separate diagnostics for cold startup, persistent operations, conversions, allocations, resources and recovery; per-case budgets declared before optimization |
| Shared-client optimization | `transit-data-client`, `transit-client`, `transit-sql-client`, query/value owners as attribution selects | One measured bottleneck per PR, preserving bounded scratch/output ownership, current authorization, exact outcomes and joined close; all affected consumers pass |
| Bridge and language optimization | Existing bindings and `sdks/<language>/`; depends on the corresponding baseline and shared contracts | Measured reductions in serialization/copies, per-row conversion, repeated setup or language allocation, with lifetime/cancellation/GC checks and installed package comparisons |
| Coverage and regression gates | P8 with P3/P5/P6 as adapters land; remaining languages via M20 | Same workload/oracle across supported languages, new context/SQL/transaction cases only when executable, reproducible matched scorecards and enforceable budgets |

**Driver contract.** Implement a small operation-owned runner under
`tests/performance/` through `tests/runner/launch.py` and a corresponding `just`
entry. Reuse installed consumer builds and private service fixtures; do not
import SDK source from the checkout or include compilation/package installation
in client startup timing. Package preparation has its own recorded duration.
Specify deterministic input values, workload seed, row/byte counts, batch sizes,
completion boundary and expected outputs once, with thin language adapters.
Keep setup writes outside read timings and verify them before each measurement.
Streaming verification must itself use bounded memory.

Each sample identifies operation/API/transport, package and native binary hashes,
server/driver revisions and definition, language runtime, host/resource/cache
profile, warmup and repetition. Store attempted, complete, failed, incomplete and
unsupported outcomes explicitly. Unsupported combinations are absent capability,
not zero-time passes. Record first-row and verified terminal time separately,
rows/bytes processed, elapsed/CPU time, RSS/PSS, threads/processes, native backing
allocation counts/bytes, copies and language allocation/GC where supported.
Unavailable measurements are explicitly unavailable, not zero. Never retain
credentials or application payloads in benchmark reports.

Add reporting/oracle controls that reject a fast wrong result, a missing terminal
batch, omitted failed attempts, definition/package mismatch, incompatible workload
settings and silently substituted unsupported APIs. These controls qualify the
driver; they do not replace executing real installed consumers. Requalify both
arms with the same driver when its timing or completion semantics change.

**First baseline campaign.** Freeze the public Zig, Python and Node capability
matrix and Linux x86_64 environment. Measure process/module/native-host startup
separately from persistent-client calls. Include empty/one-row and point/range/full
reads, supported single/batch writes, metadata, fresh readback after mutation,
narrow/wide/nested values and results spanning multiple batches. Add slow readers,
early close, cancellation, lost replies, restart and current revocation using
existing fault owners. Use ordinary SQL, transaction and shared-context cases
only in languages whose installed adapters support them; record the expansion
dependency rather than benchmarking a private substitute.

Run diagnostics separately at the shared Zig, ABI/port and language boundary with
the same typed values and completion semantics. Measure settled idle activity,
control delay and saturation at the current supported admission/concurrency
limits; keep rejection distinct from queued work. Host scheduling or new fair
queues depend on the P2 contract and cannot be added solely by the benchmark.
Populate per-case latency/throughput, memory/allocation and cancel/close budgets
from reproducible controls before selecting changes. Preserve the source-attributed
baseline even when a later API or package placement supersedes it.

**Optimization and completion.** Rank costs from these measurements. Reuse
connections/buffers and bounded scratch, reduce duplicate conversions or copies,
and batch host transitions only where the corresponding measurements support
them. Borrowed data must retain its documented owner/lifetime; zero-copy or fewer
allocations cannot hide an unbounded retained result. Shared changes run affected
language conformance and recovery checks, not only the representative three.
Incompatible ABI or stored recovery changes first update the shared contract,
definition and generated fixtures under the current-v1 cutover policy.

For each claimed steady-state improvement use at least three alternating matched
pairs and 50 samples per arm/case, with independent cold-start observations and
the same installed inputs. Establish offered-load/tail campaigns separately.
The representative gate closes only when the supported matrix passes correctness,
failure/recovery and frozen resource/latency budgets on one committed revision.
Add report/oracle and scoped warmed-allocation checks to ordinary CI; run full
timings on the controlled performance runner and retain raw artifacts. Broader
language coverage stays explicit until executed. Update the
[SDK proof ledger](../history/qualification/sdk.md),
[performance evidence](../history/qualification/performance.md), active budget
inputs and public SDK owners together; do not claim an overall 10–100× SDK gain
from a local codec or admission benchmark.

### Package and contract decisions

Keep the low-level `transit-client` implementation independent of Catalog:
Catalog already imports it. Adding Catalog back into that package would create
a cycle. The data client now exists; the data bindings and data host below remain
proposed artifacts. The 2026-10-31 refresh selects a separate data host to preserve
the existing raw-only artifact's dependency closure. P0 confirms the complete
build and installed-load graph before the public cutover.

| Package or boundary | Intended responsibility |
| --- | --- |
| Existing `transit-protocol`, Fuze types and domain contracts | Canonical identities, values, definitions, cells, collation/encoding descriptors and operation evidence. One reflected source per neutral type. |
| Existing `transit-client` | Low-level signed native operations, signatures, exact frozen requests and application-owned native loops. Preserve raw-only use. |
| Existing Catalog, direct Query, storage and Document owners | Their current data operations and reusable mechanisms. Extract only genuinely shared code from Station into the appropriate existing owner; create another library only when the dependency audit demonstrates a separate reusable responsibility. |
| Existing `packages/zig/transit-data-client` | Extend the explicit Catalog caller into a bounded client context over public Catalog/native callers and `transit-sql-client`, with operation preparation/settlement and recovery-store hooks. No new execution authority or application workflow scheduler. |
| Proposed `packages/zig/transit-data-bindings` | Shared data context/operation/result ABI and native port schemas, consuming the data client. Extract ordinary catalog/query/logical codecs from Station bindings; behavior and turn actions stay with Station. |
| Existing `apps/transit-client-host`; proposed `apps/transit-data-host` | Preserve the lightweight raw port. Compose all data facets, with optional raw operations, in one data host per application context. `transit-station-host` retains behavior composition and consumes shared types/bindings. These are local host artifacts, not additional network services. |
| `sdks/<language>/` client and native distribution packages | Language-native values, iteration, scheduling and packaging. A client-only installation contains the necessary data bridge but no Station native library or runner. Station SDKs depend on shared client types. |

Require real manifests, module interfaces and package tests. No sibling source
imports, SDK-to-runtime reverse dependency, duplicated codec or disguised Station
dependency is acceptable. Inspect both the build graph and what the installed
process actually loads/starts. Preserve the kernel's existing dependency direction.

Public language entry points can remain `transit-client` / `@transit/client`
while internal composition lives above the low-level Zig package. Zig consumers
use the public SDK's explicit modules and retain allocator/I/O control. Pure
value/definition preparation and codecs require neither credentials nor I/O;
metadata-dependent preparation is explicitly a read, never described as pure.

P0 defines the neutral context/handle/recovery-store contract before P3 adapters.
Keep domain semantics in [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[direct Table](../../contracts/DIRECT_TABLE_V1.md),
[SQL results](../../contracts/SQL_RESULTS_V1.md) and
[SQL sessions](../../contracts/SQL_SESSION_V1.md); generated ABI declarations
describe ownership and carriage, not a competing domain protocol. Extend those
owners only where the operation requires it. Apply the current-v1 cutover policy
to incompatible ABI or saved semantics, regenerate signing/schema/binding
fixtures together, and reject missing/foreign definitions before dispatch.
Do not add v2, dual decoders or old Station import shims.

### Reviewable work packages

P0 and P1 are **In Progress** through the initial extraction below. P2 and P4 are
**In Progress** through the context/submission slice, and P5 through explicit
SQL leases; P3 and P6–P8 remain
**Planned**. Contract work and independent internal pieces may overlap, but a
dependent public adapter cannot advertise an unqualified operation.

| Package | Reviewable result | Prerequisites | Exit gate |
| --- | --- | --- | --- |
| P0 | Contract inventory, language sketches, capability matrix and measured baseline | Current M3–M8 owners | Operation, ownership, recovery and package decisions are explicit before moves/adapters |
| P1 | Reusable data ownership and acyclic package graph | P0; coordinate M6/M7 extraction | Existing affected semantics preserved; direct foundation builds without Station |
| P2 | Bounded shared context and principal coordination | P0/P1; M8/M13 resource agreement | Concurrent facets, fair control progress and joined close under deterministic faults |
| P3 | Data ABI/port and generated resources | P0–P2; P4/P5 shared semantics before public adapters | Independent native/port consumers validate handles, values, errors and compatibility |
| P4 | Ordinary data operations and exact recovery-store integration | P0–P2; relevant M8/Catalog handoff | One shared prepare/dispatch/settle implementation survives caller/store/transport failures |
| P5 | Shared SQL and transaction consumption | P0–P2; delivered M4/M5 and M8 execution boundary | Complete/incomplete results and original transaction decisions preserved through the bridge |
| P6 | Installed Zig, Python and Node foundation; affected-binding migration | P3–P5 | Direct Table/query/transaction/recovery applications run without Station artifacts |
| P7 | Owner-gated KV/Document/Stream/Queue facets | P1–P6 plus each M6/M7 public and transaction cutover | Each claimed facet uses the direct owner with its exact lifecycle, authority and recovery evidence |
| P8 | Common-revision qualification and public documentation | P1–P7 plus relevant installed M3/M8 gates | Acceptance matrix passes; artifacts, supported profiles and remaining exclusions agree |

### Initial implementation slice — catalog caller ownership

The first slice introduces
[`transit-data-client`](../../packages/zig/transit-data-client/README.md) with a
real direct Catalog caller and migrates `CatalogAbi` to consume it. The public
Zig SDK exports the exact shared module. Transport/local-intent ownership and
per-call mutation evidence leave Station's ABI implementation; canonical data
operations, validation and acceptance remain with Catalog. Existing native ABI,
port actions, saved work, definition identifier and language APIs are unchanged.
This is an internal ownership extraction plus a Zig API, not the P6 public
language-package cutover or an alternate catalog protocol.

The extraction uses these already-defined contract boundaries:

| Operation class | Owner and inspectable result | Extraction rule |
| --- | --- | --- |
| Load/forget and local capabilities | `DirectTableBridge` local immutable intent/summary and generated capabilities | No network or permission assertion; failed replacement preserves prior intent |
| Compile/prepare/preview | Catalog lowering and current authorized metadata | Separate local validation from reads; no admission or automatic dispatch |
| Stage/admit/execute/cancel | Original direct binding, accepted owner observation and per-call attempt evidence | Preserve explicit steps and frozen work; neither transport failure nor output-copy failure establishes rejection |
| Metadata, dependency and retention operations | Existing exact definitions, current policy and saved pin owners | Owned output survives client close; closing local transport never releases durable pins |
| SQL and transactions | Existing `transit-sql-client` and M4/M5 | No new adapter, scope or recovery loop in this slice; M8 execution handoff remains required |

`Catalog` takes caller-owned allocator/I/O and starts no pool. The ABI retains
its existing host-owned pool, status mapping and joined-call responsibilities.
This permits shared I/O composition but does not establish P2 admission fairness,
principal-sequence coordination or a unified catalog/SQL context. No native
artifact or ordinary API has been added for Python/Node yet.

The P0 language review direction is recorded below; names are proposed vocabulary,
not shipped foreign-language signatures. Each design must retain original work
and distinguish provisional statement results from the final transaction decision.

| Language | Direct and result use | Transaction and recovery use |
| --- | --- | --- |
| Zig | Explicit allocator/I/O, owned outcomes and scoped borrowed batches | Explicit controls and original handles; caller-owned durable store hook |
| Python | Context-managed sync/async clients and iterators with exact Python integers | Explicit decision on scope exit; exceptions retain original recovery material and cleanup failure |
| TypeScript/Node | Promise operations, async iterators, validated tagged cells and `bigint` | AbortSignal stops waiting without inferring rollback; store/recover exact original operation |
| Rust | Exclusive client borrows, owned handles and iterator-scoped batch borrows | Typed provisional/decision outcomes; dropping a future cannot free active native ownership |
| Go | Context-aware operations on bounded native workers and explicit result close | Context cancellation preserves uncertainty; original handles/store survive goroutine lifetime |
| BEAM | Supervised port ownership, immutable records/structs and bounded requests | Monitor/timeout is host evidence; recover the recorded operation without rerunning a callback |

The following slice extends P0 with the affected-language ownership review and
context/store decisions, and P1 with the remaining query/value inventory and
selected extraction. It does not wait for M8's pending P2 transport
interfaces because it preserves the existing direct caller operations. It does
not qualify new coarse submission, automatic settlement, SQL/transaction
conveniences or the KV/Document/Stream/Queue facets.

### Value and direct-reader extraction

**Audit basis:** `cf6f5ab533b01b15b141f74f20ffe42c1168d95d`, including the
merged Catalog extraction. This slice implements the moves in the following
source inventory and selects the neutral ownership contract below before adding
a context ABI. Fuze owns `QueryValues` and the shared `NeutralEncoding` helpers;
`transit-query-direct` owns the relational bridge and Table history reader.
The contract is proposed; it does not describe an implemented context, recovery
store, ordinary foreign-language SQL API or new server capability.

| Audited boundary | Decision and consumer migration |
| --- | --- |
| Fuze `LogicalCodec`, `LogicalJson`, `Types` | Already pure canonical owners. Make the Station logical ABI wrapper import Fuze directly; preserve its buffer/status boundary and every existing language codec. |
| Query `Values` columns, scalar/cell projections, predicates and plans | Move deterministic conversion to Fuze `QueryValues`, preserving exact types, errors, collations, integers and allocator ownership. Query continues to compose those types with source/bundle declarations. |
| Station Document `JsonValues` integer/hex helpers | Move the shared conversion implementation with those values; retain the Document reference adapter with its current accepted-revision owner. Preserve existing error names and bytes. |
| Query `Values.Source`, `Capture`, `Bundle`, `Limits` and `Action` | Retain with captured/native query composition: they bind `SourceDefinition`, publication identity, requester authorization and legacy KV/Document decoders. They are not the ordinary SQL result model. |
| Query `RelationalBridge` | Move its direct retained-Table session, pages, budgets and disclosure rules into `transit-query-direct`; migrate the composed Query export to that exact module. |
| Query `TableChangeReader` | Move the existing direct history reader into `transit-query-direct`; preserve original history acquisition, checkpoint and explicit release rules. |
| `QueryAbi`, `QueryBridge`, Query `Bridge`, `Workspace`, `RelationalCaller`, `ApiDiagnostic` | Retain mixed captured/interactive hosting and diagnostic composition. Do not rename this closure into the independent data client. A later data boundary binds SQL's existing `Executor` and `ResultSet`. |
| Station `TableData`, `TableCandidate`, `TablePages`, `TableHead`, `TableHistory`, `TableChanges`, `TableReader` | Retain native-turn resource readers, candidate state and history adapters. Direct storage/query owners already exist separately; moving these aliases would not replace their accepted-turn semantics. |
| Station `TableCreation`, `TableWrite`, `TableStatement`, `TableCleanup`, `TableAlter` | Retain native Table lifecycle/turn controls until their owning atomic migration. They are not a second direct Table commit owner. |
| Station `Publication`, `PublicationReference`, `PublicationParts`, `PublicationUpload`, `ImmutableIndex` | Retain accepted native-resource publication and immutable index composition used by behaviors, captured jobs and Station Document. Pure hashing alone does not make the lifecycle a database primitive. |

Affected native consumers are the Station ABI/exporters and port, Query's bundle,
relational and captured adapters, Board, CLI, query host, SQL captured integration
and Flight. They consume the same exported types after extraction. The Zig SDK
adds the independent direct Query module and verifies shared type identity.
Python, Node, Rust, Ruby, C/C++, Java, .NET and Erlang/Elixir retain their current
ABI/port operations and generated resources; Go remains a raw-client consumer.
No language receives an additional operation merely because its generated
schema mentions a shared type. Contract drift and independent ABI/port fixtures
must remain unchanged for this package-only extraction.

P0/P1 remain **In Progress**. The context/store decisions below still need
executable neutral types, failure schedules and reflected ABI resources before
P2/P3 adapters land. The installed SQL baseline covers the current console and
owned service processes; per-language native/port startup, allocation reserves,
cancellation and joined-close measurements remain part of P0/P8. The future data
bridge and shared catalog/SQL context are not supplied by these package moves.

The [installed SQL resource baseline](../history/qualification/performance.md#shared-client-resource-baseline--2026-10-29)
records 47 verified statements in both arms with matching measurement drivers,
8 owned processes and 9 console threads. It retains the observed slower
candidate timings and shared-host limits; it establishes no resource-sharing
improvement or zero-allocation claim.

### Proposed neutral client-context contract

This is the P0 decision record for P2–P6. Implementing it requires neutral Zig
types, reflected boundary resources and failure fixtures; the names below are
semantic vocabulary, not a frozen ABI or runnable language API. Domain identities
and outcomes continue to come from `DATA_LIFECYCLE_V1`, `DIRECT_TABLE_V1`,
`SQL_RESULTS_V1` and `SQL_SESSION_V1`.

#### Identity, configuration and operation classes

A context has one local generation, explicit transport/trust configuration and
credential providers. A facet binds a complete authority instance/realm and its
own account or principal/role scope. Configuring two facets does not equate their
identities or grant permissions. Context creation validates local configuration
and reserves capacity; network negotiation is explicit and reports the selected
server definition/capabilities. Pure values require neither a context nor I/O.

| Operation | Identity and authority | Observable outcome and recovery owner |
| --- | --- | --- |
| Pure codec/type/plan conversion | Current format definition and supplied logical type; no permission claim | Owned output or local refusal; no durable recovery record |
| Metadata-dependent preparation | Complete facet scope, current rights and exact observed definition | Immutable prepared work, observation and definition; preparation is an authorized read |
| Independent Catalog change | Original operation binding, content and current permission | Domain acceptance/progress/terminal evidence; frozen intent/reference survives uncertainty |
| SQL statement | Account, service instance, original client token and session | Existing command/result/unresolved outcome; no SQL-text classification or new-token retry |
| Transaction statement/control | Original transaction handle and serialized command tokens | Provisional statement counts, final decision and cleanup separately; attach is explicit |
| Captured/native turn proposal | Existing requester/turn owner and recorded destinations | Existing commit/replay semantics; not admitted as an independent database commit |
| Recorded external effect | Owning connector intent and authorization | Connector outcome/uncertainty; no effect dispatch or callback replay from generic recovery |

Native principal sequencing is keyed by realm/principal and coordinated across
all native handles in the context. Domain operation IDs and SQL client tokens
remain distinct namespaces. Cross-process sharing requires an explicit durable
allocator/lease or exclusive ownership; a local mutex establishes neither.
Uncertainty quarantines only a scope whose owner forbids sequence advancement.
Credential refresh never substitutes a different principal or accepted identity.

#### Admission, memory and lifetime

The configuration supplies finite counts/bytes for active data operations,
pending admission, transports, outstanding responses, result leases and control
work. A zero control reserve is invalid. Reuse `transit-io` and existing SQL
reserves; charge stacks, task records, transport storage, retained values and
spill separately. Do not infer process-wide bounds from one allocator counter.
A slow result holds only its charged leases. Cancellation, close, renewal and
original-operation observation retain admission capacity independent of data
work; none may wait for an unbounded data queue to drain.

Admission returns a generation-bound permit, an explicitly deadline-bounded
wait, or a typed capacity refusal before dispatch. FIFO within a lane and
round-robin eligible facets provide deterministic scheduling; control has its
own finite lane, so neither control nor data can consume the other's reserve.
Only one request borrows a mutable transport, SQL attachment or result handle.
A retained SQL result does not imply that its control connection is available
for simultaneous callers without a separate permit.

Owned values survive the next call and context closure. A batch borrow ends on
advance/close; retaining it requires a bounded copy or a charged lease. Stale
handle generations fail before dereference. Collection limits stop collection,
not the logical result, and never establish terminal coverage. Existing source
and post-buffer authorization checks run before every disclosure.

The close transition is `open -> closing -> joined`. Closing refuses new data
admission, signals cancellation to active host work and joins it before freeing
buffers, I/O or mapped libraries. Control cleanup has a bounded budget and reports
unresolved cleanup separately. Close does not silently roll back a transaction,
release an explicit durable pin, forget an uncertain operation or assert that a
remote effect was cancelled. Cancelling the host task awaiting close leaves a
retained native close owner responsible for the join.

#### Recovery-store hook and failure ordering

The store is an explicit capability, not an implicit file or process-local map.
Its operations are atomic `insert_if_absent`, compare-and-swap `update`, fenced
`claim/release`, bounded `list_page` and policy-authorized `remove`. Records bind
format/definition, immutable original scope and operation key, exact prepared
bytes, subsequent owner references and observed receipt/transaction evidence.
They never include signing keys/passwords. Payload-bearing stores require private
permissions. Keys reused with different scope/content reject before dispatch.

Persist prepared bytes before staging or the first potentially accepting send.
Persist each returned staging/reference handle before the next dependent send.
A failed pre-dispatch insert sends nothing. A failed update after possible
acceptance returns the original record and uncertainty; it cannot authorize a
replacement operation. Receipt persistence failure reports the known outcome
and store failure separately. It must not demote a verified commitment to a
rejection or tell the caller to rerun its transaction callback.

A claim prevents simultaneous recovery owners; claim expiry changes local store
ownership only. Recovery uses current credentials to observe or repeat only
owner-permitted actions against the original binding. It never rebuilds SQL,
re-resolves a renamed object, acquires a replacement snapshot or dispatches an
external effect. Missing/corrupt/incompatible records fail closed. Uncertain
records remain enumerable after cancellation or process loss; storage quota
pressure cannot delete them. Receipt retention follows the domain owner and an
explicit store policy, independently of local handle/session expiry.

Without a store the API returns owned recovery material and preserves identity
while that material survives. It promises no recovery after all such material
is lost. The reference durable implementation must prove atomic replacement,
file and directory synchronization, lock fencing, disk-full handling and bounded
paging before it can claim process-loss recovery. Browser credentials/storage
require a separate profile; they cannot reuse a Node filesystem assumption.

#### Language contract review

The same four journeys apply in each language: prepare an independent Table
write, consume a bounded read, run a two-Table transaction with an outbox row, and
resolve the original lost commit reply. Names remain proposals. No helper may
implicitly retry a transaction callback or conflate an abandoned await with
rollback.

| Language | Proposed application shape and ownership decision |
| --- | --- |
| Zig | `Context.init(allocator, io, config)`; explicit `deinit`/joined close; `Outcome` owns metadata and `nextBatch` borrows. Explicit begin/commit handles and store callbacks; errors retain original work. |
| Python | `with Client(...)` / `async with AsyncClient(...)`; context-managed result iterator; exact `int` and decimal coefficient/scale. `prepare`, `dispatch` and `recover` share native owners. Cancellation shields native join; commit uncertainty carries the original transaction handle. |
| TypeScript/Node | `await Client.open(...)`, `try/finally` close, async result iteration; validated cells and `bigint`. `AbortSignal` requests cancellation without inferring rollback. Explicit commit yields a typed decision/unresolved union and original store key. |
| Rust | Owned client/context and recovery values; exclusive mutable transport/transaction borrows, scoped batch views. Dropping a future retains a native join owner. Commit returns a decision or original unresolved handle; no automatic `Drop` commit. |
| Go | `Client` plus `context.Context` per operation; bounded native workers, `Rows.Close` and terminal `Err`. Cancelled contexts preserve original operation material; transaction decisions remain explicit. No Go data implementation is claimed by this sketch. |
| Erlang/Elixir | Supervised bounded port owner; immutable records/structs and monitored request IDs; demand-driven result pages. Caller death/timeout never supplies durable cancellation. Recovery uses the saved operation; supervision does not replay a transaction function. |
| Ruby | Block-scoped client/result ownership with explicit close; exact Integer and decimal values. Exceptions retain original operation and cleanup evidence; block exit does not invent a commit. |
| C/C++ | Opaque generation-checked handles and explicit buffer/lease release; C++ move-only owners over the same ABI. Status and owned recovery/diagnostic output are separate; destructors cannot hide unresolved transaction decisions. |
| Java | `AutoCloseable` context/result owners and bounded executors; exact `BigInteger`/decimal projections. Interrupted waits leave native ownership joined; explicit commit results preserve original handles. |
| .NET | `IDisposable`/`IAsyncDisposable`, bounded native scheduling and async iteration; lossless wide values. `CancellationToken` affects waiting/control, while disposal joins active native work and reports unresolved cleanup. |

Before P2/P3 land, deterministic tests must cover saturation with reserved
control progress, per-scope sequence quarantine, stale generations, cancelled
close, every store failure boundary, a known commit racing cancellation and an
incomplete result prefix. Then installed Zig/Python/Node journeys exercise the
same state machine. Generated JSON/ABI declarations remain separate from these
language-owned interfaces.

#### P0 — Freeze contracts and user journeys

Use one small application dataset for direct declaration/write/read, a two-Table
transaction with an outbox row, a lost commit reply and a bounded long read.
Review side-by-side API sketches for Zig, Python, TypeScript, Rust, Go and BEAM,
then every affected language before its migration. Include failure/cleanup
paths, not only successful method names. These are design sketches until P6;
future effects/subscription/Station-call sketches remain explicitly proposed.

Produce an operation matrix recording pure validation/preparation, authorized
read, independently committed change, provisional transaction statement, native
turn proposal and recorded external effect. For every operation name its stable
object/definition, current authority, accepted identity, result/progress evidence,
resident limits and recovery lifetime. Local capability discovery, server
capability negotiation and current permission are separate checks.

Select language semantics explicitly: Python context managers and sync/async
iterators; Node promises and async iteration with runtime-validated values and
lossless integers; Zig explicit ownership and borrowed batches; Rust exclusive
borrows/owned handles; Go contexts with bounded native workers; BEAM supervised
port ownership without blocking schedulers. Exact decimals and all five cell
states must survive each representation. Do not require identical class layouts
or make language task cancellation mean durable rollback.

Record the complete move/consumer inventory and a matched baseline for installed
startup, host processes/threads, reserved/live memory, statement and completion
latency, copies, backing allocations, cancellation and close. Select numeric
regression budgets before implementation using M13's measurement definitions;
do not infer them from M8's historical figures or introduce arbitrary SLOs.

#### P1 — Complete shared ownership without replacing authority

Audit every remaining Station `Table*`, Publication and ImmutableIndex use,
plus `CatalogAbi`, `QueryAbi`, `LogicalCodec`, `QueryCodec` and their callers in
[Station bindings](../../packages/zig/transit-station-bindings/src/Abi.zig).
Classify each as already direct, shared deterministic data mechanism, public
data caller, or actual behavior/native-turn adapter. Retain M3/M6's qualified
native-turn paths until their atomic replacement exists. Do not relocate their
acceptance logic under a data name and call that decoupling.

Give ordinary data callers a dependency path through the proposed data client
and bridge. Extract captured/maintained/Station-specific composition only with
its owner; direct interactive SQL uses the existing remote SQL client and does
not acquire the whole captured-query runtime. Reuse M7's Document evaluator and
M13's memory/I/O primitives. Preserve original saved operations and rejection
checks through package-only moves; semantic cutovers require coordinated
contracts and consumers, not a successful rename/build.

#### P2 — Share context resources and coordinate identities

One context composes catalog, data and SQL facets over explicitly configured
endpoints, trust and credentials. It may own multiple connections, sessions and
execution lanes. A context does not merge different principals, grant scopes,
transaction attachments or session settings. A transaction pins its original
session/handle and serial command ownership; unrelated reads can use other
admitted lanes.

Define bounded active operations, pending admission, connection/worker slots,
result leases, bytes and diagnostics, with reserved control capacity for cancel,
close, renewal and recovery observations. Charge total host/context reservations,
including native stacks and transport storage. Saturation waits within a stated
deadline or returns a typed refusal; it never queues unlimited work, evicts a
borrowed batch or discards an accepted obligation. Reuse `transit-io` rather than
building another thread pool. New facets cannot multiply pools by default.

Coordinate native principal sequences across all handles in the context, keyed
by the owning realm/principal scope. Keep SQL account/client tokens and domain
operation IDs separate. For a principal shared across processes, require an
explicit external allocator/store coordination contract or exclusive ownership;
an in-process lock is insufficient. Preserve the original sequence and frozen
content through uncertainty. Quarantine only the scope whose protocol forbids
advancement; unrelated principals and control work must continue.

Define handle generations, one active borrower per mutable handle, owned values,
borrowed batch expiry, explicit retention/copy and deterministic release.
Shutdown stops admission, joins native work, closes transient readers within
bounded cleanup budgets and preserves unresolved recovery records. It cannot
silently abort transactions or release explicit durable pins. Preserve current
native-library mapping safeguards until an actual thread-exit fence proves that
unloading is safe. A cancelled close await must not free live native memory.

#### P3 — Expose the shared boundary, then migrate adapters

Generate context, operation, result/batch and close/cancel declarations from the
shared Zig types. Keep generated fields out of application APIs where they do
not help the caller. Native/port negotiation rejects incompatible definitions
before creating usable handles; operation support cannot be inferred from the
ABI's numeric version or from a generated enum.

Replace exclusive catalog/query host modes with facet handles in one data context,
using the data host selected in the refreshed package decisions. Preserve the
independent raw-only host and its existing dependency closure.
Specify bounded request IDs, demultiplexing, frame budgets and outstanding work
if the port multiplexes requests. Control/cancel progress must remain possible
while a query is slow; changing the configuration alone does not establish
concurrency. Keep pure codec use independent of authority configuration and
preserve machine stdout, drained diagnostics and joined child shutdown.

Use the shared SQL batch interface for row/column iteration; do not serialize an
entire result into a host message. Select and document the bounded port copy
profile separately from native borrowed-buffer/Arrow views. Verify nested bytes,
five-state tags, decimal widths, embedded NULs, invalid frames and stale handles.
Retained rows/exports must either own their data or retain a charged lease across
the next advance. Managed-language finalizers are a fallback, not the cleanup
contract.

#### P4 — Make ordinary operations recoverable without application loops

Provide shared ordinary prepare/submit/settle operations over Catalog and native
owners, with bounded deadlines and typed terminal or unresolved outcomes.
Advanced callers retain explicit prepare/save/stage/admit/step/observe controls.
Both levels execute the same state machine. No language-specific poll queue,
fresh-token retry, inferred success or automatic name re-resolution may replace
accepted work. A renamed/recreated object cannot retarget a saved intent.

Define an explicit recovery-store hook and ship one reference durable local
implementation for the representative native profile. The store persists exact
prepared bytes before remote staging or the first potentially accepting dispatch,
then records every additional recovery reference before dependent work is dispatched. Its
record binds authority instance/realm, account/principal/role scope, operation
kind and key, immutable content/definition, and known receipt/transaction handle.
No signing secret is serialized. Records may contain private application data;
keep them out of telemetry and give the local store private permissions.

Specify atomic insertion/update, concurrent ownership, crash consistency, bounded
enumeration, corruption and disk-full behavior. An operation key reused with
different scope/content rejects. Store failure before dispatch sends nothing;
failure after possible acceptance preserves uncertainty and the original record.
Failure to persist an observed receipt does not turn known commitment into
rejection. Recovery observes or retries only the original owner-authorized work,
under current credentials, without rerunning application callbacks. Mark/remove
records only under explicit receipt-retention policy, never because a local wait
or session expired. Deduplication lifetime follows the durable owner, not an SDK
cache TTL.

Without a store, return owned recovery material and state the actual guarantee:
the shared client preserves identity while its owner/material survives, but does
not promise recovery after all caller state is lost. A durable record is not a
credential or an admission receipt. Browser storage/credentials use a separate
profile; Node filesystem recovery is not a browser implementation.

#### P5 — Bind results and transactions to their existing owners

Adapt `Executor`, `ResultSet`, batch leases and bounded windows once in the
shared bridge. Expose command kind/counts, data or metadata observation, delivered
rows, verified completion and early closure distinctly. Stream at bounded memory
independent of result size. EOF, budget refusal, display limits, expired sessions
and cancellation leave incomplete prefixes; no adapter restarts SELECT to splice
in another snapshot. Repeated fetches use the original sequencing and budget.

Expose explicit begin/commit/rollback/savepoint/reattach through the M5 owner.
Private statement counts remain provisional; only the original decision supplies
commit/abort evidence, separately from cleanup. Session loss does not roll back,
inspection does not attach, and local close cannot silently discard an open
transaction's recovery handle. Preserve stale workspace-cursor rejection after
another statement or rollback and current authorization after buffering.

Build ergonomic transaction scopes only after those explicit controls. The scope
must expose unresolved exit/rollback/commit and preserve both a callback failure
and cleanup failure. Never retry a callback automatically: application code can
have external effects. Outbox/checkpoint examples use qualified Table mutations;
publishing an intent does not dispatch or establish remote exactly-once effects.
Reject unsupported isolation, participant kinds, DDL and nested transaction
semantics instead of implementing hidden commits or a second coordinator.

#### P6 — Deliver representative clients and the complete affected cutover

Implement the reviewed Table/catalog, finite SQL and local Table transaction
journeys in Zig, Python sync/async and Node. Import and pure value construction
start no work. Ordinary data calls require no Station PID, runner activation,
native Station library or manual upload/continuation loop. Keep advanced APIs
available with the same identities and outcomes.

Migrate existing catalog/query/value consumers in every affected SDK, generated
resource, example and runtime consumer in the same current-v1 cutover. Preserve
each existing qualified capability, even if that language does not yet gain the
new SQL/transaction convenience layer. Do not add new Go/other-language breadth
as a prerequisite for the representative slice; M21 owns that expansion. Remove
superseded public data exports rather than leaving Station forwarding shims.
Station behavior APIs can consume the shared values internally without another
public data authority.

Install the actual distributable packages into isolated environments outside the
checkout and execute real application binaries/programs. Check dependency/load
closure with Station artifacts absent, and test mixed dependency installation
for duplicate native images or incompatible type identities. Keep versions and
exact internal pins aligned with root `VERSION`; run `tasks/version.py` after
manifest changes. Packaging changes do not imply support for untested platforms.

#### P7 — Integrate owner-qualified data facets

For each M6/M7 handoff, add its typed operations to the same context and recovery
boundary, not a mode-specific host. Minimum representative journeys are:

| Facet | Required journey and preserved distinction |
| --- | --- |
| KV | Declare/resolve, mutate/read and recover through the qualified direct owner; native resource associations do not grant access or imply ownership. |
| Document | Declare, apply a causal change, recover the original outcome and read the accepted revision; conflicts and missing values remain explicit. Private candidate staging is not acceptance. |
| Stream | Produce, consume a bounded range and explicitly commit the original offset under the owner's group/fencing rules; reading does not acknowledge consumption. |
| Queue | Enqueue, claim with a fenced lease, then acknowledge/release/extend through the owner's operations; timeout is not ACK and stale leases cannot settle work. |

Add transaction participation only when the M6/M7 participant is qualified in
the shared commit envelope. Preserve state/input/output atomicity during any
Station consumer migration. Existing native KV/Document behavior remains its
documented profile until that cutover; do not publish parallel direct and legacy
engines as a shortcut. Keep P7 open if these owners have not landed. Continuous
change subscriptions, managed computations, protocol Document Profiles and
standalone effects/Station calls retain their later owners.

#### P8 — Qualify one integrated revision and publish supported behavior

Extend the existing [installed SDK schedules](../../tests/sdk/README.md) and
owning SQL/catalog/transaction suites instead of replacing them with mock-only
wrappers. Register new scenarios/consumers in the test inventory and pin the
native build/installed package inputs. Run focused component checks first,
then the affected installed language matrix and actual gateway paths at one
committed revision. Preserve prior failures and report unavailable/skipped
profiles separately.

### Acceptance matrix

| Boundary | Required evidence and forbidden outcome |
| --- | --- |
| Package independence | A clean client-only installation declares/writes/queries/transacts without Station artifacts or caller actors; runtime imports no `sdks/` source. |
| Semantic parity | Representative callers agree on scoped object/definition identity, exact integers/decimals, collation descriptors, five-state cells, counts and observation evidence. Malformed/foreign artifacts reject before dispatch. |
| Original-operation recovery | Kill the caller before send, after acceptance and before receipt persistence; lose stage/admission/commit replies; reopen the store with current credentials. Exactly the original operation is reconciled, with same-key/different-content refusal and no duplicate accepted change. |
| Store boundaries | Inject failed sync, torn/invalid records, disk full, duplicate writers and failed receipt updates. Pre-dispatch failure sends nothing; post-dispatch failure cannot manufacture rejection, success or a new identity. |
| Result ownership and completeness | Empty/multi-batch/nested values, retained rows, early close, missing terminal, duplicate fetch and malformed counts. No use after batch reuse, complete-result inference from EOF, or snapshot splice. |
| Transactions | Read-your-writes/common cut, provisional counts, savepoints, conflict abort, lost commit reply, replacement-session reattachment, cancellation racing commit and failed cleanup. No implicit rollback, callback retry or unsupported participant acceptance. |
| Current authorization | Revoke after preparation/acceptance/buffering, including repeat/metadata/empty/terminal reads and recovery observations. Cached capability/type/receipt data grants no new disclosure. |
| Concurrency and cleanup | Slow query alongside catalog work, transaction controls and multiple principals; cancel one operation and continue others; saturate lanes and close during I/O. Enforce configured queue/memory bounds, control progress and joined native ownership. |
| Resource/performance boundary | Compare matched native and installed calls: startup/processes/threads, reserved/live bytes, copy/backing-allocation counts, throughput, p50/p95 completion, cancel and close. Prove no retained-cardinality memory term and zero new steady-state backing allocations in the admitted shared hot paths; measure language object/GC costs separately. |
| M8 composition | No SDK-added idle recovery traffic after settlement and no restored client-side SQL storage choreography. Bounded fetch/control/uncertainty observations remain visible and use the qualified gateway paths. |
| All affected consumers | Existing raw, catalog, query, Station, browser/runtime and incompatible-definition schedules still execute where changed; representative new coverage cannot excuse a broken existing binding. |
| Gated facets | P7 executes through the accepted direct owners with original-operation, revocation and participant-fencing schedules; generated declarations or private storage tests alone do not pass. |

Use deterministic transitions and negative schedules for shared context/knowledge
state, allocation fault injection for ownership, and real local WAL/installed
callers for persistence and process-loss evidence. Preserve disk-backed Ursula
checks for the existing raw/native profile. Process death is not power-loss
qualification; passing an abstract model does not certify native host scheduling.
Carry corresponding traces to M22 without duplicating the result models.

Record source, toolchains, profiles, commands, outcomes and raw reports in
[SDK qualification](../history/qualification/sdk.md), with links to owning
transaction/SQL/performance evidence. Promote implemented behavior and limits
to caller/SDK references, client/framework internals, component guides and
per-language documentation in each implementation slice. M9 closes only when
P0–P8 and the selected acceptance matrix are complete; partial Table delivery
does not silently waive P7. Update this milestone and the roadmap index together.

### Later consumers and scope boundaries

- [M10](10-standards-and-catalogs.md) and
  [M11](11-indexing-and-access-paths.md) extend exact definitions, historical
  interpretation, constraints and index progress through these types and
  operation handles. No SDK-owned index scheduler or alternative snapshot truth.
- [M12](12-sql-and-dataflows.md),
  [M16](16-document-profiles-and-gateway-exchange-lifecycle.md),
  [M17](17-geospatial-and-spatio-temporal-computing.md) and
  [M18–M20](20-branches-merges-and-restore.md) extend computation, Document profiles,
  geospatial/spatio-temporal computing, foreign data and branches through their own contracts. Reserve composition
  points, not executable placeholder APIs or hardcoded branch-one assumptions
  in otherwise neutral references.
- [M21](21-service-and-sdk-coverage.md) expands language/service/platform parity,
  including Flight/ADBC and browser/reactive profiles. M9's Node host/store and
  native Arrow ownership do not establish those interfaces.
- [M23–M26](26-clustered-execution.md) own provider/distributed placement and
  failover. A client must preserve instance/audience/definition and original
  identity; automatic failover cannot silently resubmit against another authority.
- [M27–M31](27-control-and-policy-plane.md) consume shared current authorization,
  publication and bounded observations. M9 neither adds enterprise identity nor
  broadens Board's inspection grant or invents a UI/MCP configuration authority.
- [M32](32-reactive-context-and-agent-activation.md),
  [M33](33-recorded-mcp-integrations.md) and
  [M34](34-programming-model.md) add durable subscriptions, standalone recorded
  effects, typed Station calls and full mixed/behavior journeys. Context
  composition and shared values land here; those later capabilities do not.
- [M42](42-qualification-and-benchmarks.md) and
  [M43](43-releases.md) combine evidence and distribution at a release revision.
  M9 still requires its own installed acceptance before that later qualification.

## Completion evidence

Measure the representative installed clients' allocation/copy counts, bounded
streaming, cancellation/settlement cost and durable completion latency against
the same native operations. Carry these baselines into the later
[performance scorecard](13-data-structures-and-performance.md). Shared declaration
and progress conventions must accommodate the
[indexing lifecycle](11-indexing-and-access-paths.md) without another client
scheduler or recovery protocol; index-specific adapters arrive with that owner.

Run real installed direct-client applications with no Station runner artifact.
Compare object/type identity, five-state values, exact integers/decimals and
result evidence across the representative languages. Exercise original-operation
recovery, lost commit replies, revocation, incomplete reads, recovery-store
failure, cancellation, borrowed-buffer lifetimes and joined close.

Verify actual dependency closure, not just renamed exports. Exercise concurrent
catalog/query/transaction work, multiple principals and one cancelled operation
while other work continues. Measure startup cost, threads/processes, memory,
queue bounds and control fairness. Preserve existing native and SDK recovery
proofs across the package cutover. Language sketches alone do not establish API,
platform or worker-deployment support; record executed profiles in the
[proof ledger](../history/qualification/README.md).
