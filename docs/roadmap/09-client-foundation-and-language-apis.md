# 9. Shared client foundation and language-native APIs

[Roadmap](README.md) · **Status:** In Progress ([implementation plan](#implementation-plan--2026-10-29))

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
[language-native programming and mixed composition](32-programming-model.md).
That later milestone retains the recorded source assessment, all three mixed
capabilities (recorded effects, durable consumers and typed Station calls),
Station behavior ergonomics and the complete installed cross-language journeys
after outbound MCP. [Service/SDK coverage](19-service-and-sdk-coverage.md)
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
   remains milestone 19; full mixed and Station ergonomics remain milestone 32.
   Apply the current-v1 cutover policy to incompatible ABI/stored semantics,
   regenerate fixtures, reject incompatible saved artifacts, and publish current
   behavior in caller/component/SDK owners as each slice lands.

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
| [Catalog](../../packages/zig/transit-catalog/README.md), [direct Query](../../packages/zig/transit-query-direct/README.md) and SQL already exclude Station from their database implementation | Preserve that extraction. Do not redo the old package assessment in M32 or move every `Table*` file merely because it remains in Station. |
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
remaining dependency gates. M19 owns broader new language, operation and
platform coverage; M32 owns complete mixed programs and Station ergonomics.
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
| [M19](19-service-and-sdk-coverage.md), In Progress | Existing Go raw and SDK/console coverage | Preserve existing installed consumers during migration. New parity follows this foundation instead of extending the Station-shaped data bridge. |
| [M20](20-formal-semantics-and-correspondence.md#t2-statement-results-disclosure-and-uncertain-settlement), In Progress | Result/settlement models and implementation correspondence | Supply deterministic context/recovery transitions and replay fixtures; do not wait for all formal work or claim full refinement from bounded checks. |
| [M28](28-board-reimplementation.md), In Progress | Public catalog/SQL/browser consumers | Migrate shared boundary changes with their consumers, preserving read-only inspection and browser-specific credentials. Board runtime code never imports consumer SDKs. |
| [M35](35-releases.md), In Progress | Installed native/client packaging and release checks | Add matching generated resources and independent artifacts to current installation checks. New platforms and registry publication remain release/coverage work. |

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

### Package and contract decisions

Keep the low-level `transit-client` implementation independent of Catalog:
Catalog already imports it. Adding Catalog back into that package would create
a cycle. The following new names are proposed implementation packages, not
existing artifacts or frozen public APIs; P0 confirms their dependency closure.

| Package or boundary | Intended responsibility |
| --- | --- |
| Existing `transit-protocol`, Fuze types and domain contracts | Canonical identities, values, definitions, cells, collation/encoding descriptors and operation evidence. One reflected source per neutral type. |
| Existing `transit-client` | Low-level signed native operations, signatures, exact frozen requests and application-owned native loops. Preserve raw-only use. |
| Existing Catalog, direct Query, storage and Document owners | Their current data operations and reusable mechanisms. Extract only genuinely shared code from Station into the appropriate existing owner; create another library only when the dependency audit demonstrates a separate reusable responsibility. |
| Proposed `packages/zig/transit-data-client` | Bounded client context and typed data/lifecycle orchestration over public Catalog/native callers and `transit-sql-client`; operation preparation/settlement and recovery-store hooks. No new execution authority or application workflow scheduler. |
| Proposed `packages/zig/transit-data-bindings` | Shared data context/operation/result ABI and native port schemas, consuming the data client. Extract ordinary catalog/query/logical codecs from Station bindings; behavior and turn actions stay with Station. |
| Existing `apps/transit-client-host` | Compose raw and data bindings into one bounded host for an application context. `transit-station-host` adds only the behavior-facing composition it still needs. These are local host artifacts, not additional network services. |
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

P0 and P1 are **In Progress** through the initial extraction below. P2–P8 remain
**Planned**. Contract work and independent internal pieces may overlap, but a
dependent public adapter cannot advertise an unqualified operation.

| Package | Reviewable result | Prerequisites | Exit gate |
| --- | --- | --- | --- |
| P0 | Contract inventory, language sketches, capability matrix and measured baseline | Current M3–M8 owners | Operation, ownership, recovery and package decisions are explicit before moves/adapters |
| P1 | Reusable data ownership and acyclic package graph | P0; coordinate M6/M7 extraction | Existing affected semantics preserved; direct foundation builds without Station |
| P2 | Bounded shared context and principal coordination | P0/P1; M8/M13 resource agreement | Concurrent facets, fair control progress and joined close under deterministic faults |
| P3 | Data ABI/port and generated resources | P0–P2 | Independent native/port consumers validate handles, values, errors and compatibility |
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

Replace exclusive catalog/query host modes with facet handles in one context.
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
as a prerequisite for the representative slice; M19 owns that expansion. Remove
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
Carry corresponding traces to M20 without duplicating the result models.

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
  [M16](16-document-profiles-and-gateway-exchange-lifecycle.md) and
  [M17–M18](18-branches-merges-and-restore.md) extend computation, Document profiles,
  foreign data and branches through their own contracts. Reserve composition
  points, not executable placeholder APIs or hardcoded branch-one assumptions
  in otherwise neutral references.
- [M19](19-service-and-sdk-coverage.md) expands language/service/platform parity,
  including Flight/ADBC and browser/reactive profiles. M9's Node host/store and
  native Arrow ownership do not establish those interfaces.
- [M21–M24](24-clustered-execution.md) own provider/distributed placement and
  failover. A client must preserve instance/audience/definition and original
  identity; automatic failover cannot silently resubmit against another authority.
- [M25–M29](25-control-and-policy-plane.md) consume shared current authorization,
  publication and bounded observations. M9 neither adds enterprise identity nor
  broadens Board's inspection grant or invents a UI/MCP configuration authority.
- [M30](30-reactive-context-and-agent-activation.md),
  [M31](31-recorded-mcp-integrations.md) and
  [M32](32-programming-model.md) add durable subscriptions, standalone recorded
  effects, typed Station calls and full mixed/behavior journeys. Context
  composition and shared values land here; those later capabilities do not.
- [M34](34-qualification-and-benchmarks.md) and
  [M35](35-releases.md) combine evidence and distribution at a release revision.
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
