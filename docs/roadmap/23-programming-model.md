# 23. Language-native programming model and mixed application composition

[Roadmap](README.md) · **Status:** Planned

Let applications use Transit's data, computations and policies through ordinary
language APIs, adopt Station for selected durable behaviors, or combine both in
one application. Shared types, operation identities, results and recovery should
compose across those choices. Using a Table or calling a Station service must
not require running a Station handler in the caller.

## Prerequisites and scope

Follow [recorded outbound MCP and application guidance](22-recorded-mcp-integrations.md)
in the delivery sequence. The earlier
[shared client foundation](06-client-foundation-and-language-apis.md) owns package
extraction, shared client/host infrastructure, direct operation/recovery helpers
and representative language APIs before SDK expansion. Consume that delivered
foundation here and extend it to every claimed mixed/Station language profile;
do not postpone those foundation obligations until this milestone.
Build on the qualified
[data lifecycle](01-declarative-data-lifecycle.md),
[direct runtime cutover](03-live-storage-and-sql-cutover.md),
[statement/result contract](04-statement-results-and-consumption.md),
[transactions and outbox](05-transactions-and-atomic-composition.md),
[service/SDK coverage](11-service-and-sdk-coverage.md) and the relevant
[access](16-control-and-policy-plane.md),
[published-resource](17-published-resources-and-investigations.md) and connector
owners. API/contract review can start alongside those foundations. Earlier
milestones retain their implementation and parity promises; this milestone owns
coherent application composition and per-language usability, not deferred coverage.

The [caller reference](../handbook/reference/callers.md),
[SDK reference](../handbook/reference/sdks.md),
[Station model](../handbook/reference/station.md) and
[client/framework account](../handbook/internals/client-framework.md) are the
current owners. Keep the shared Zig implementation and generated binding
contracts. Language-native APIs need not have identical class layouts or
scheduling surfaces to preserve the same semantics.

## Source review — 2026-10-24

Review of runtime/SDK source at `94335c2a` establishes these starting points;
this is an API/source assessment, not newly executed interoperability evidence.

| Current evidence | Programming-model gap |
| --- | --- |
| Independent [raw clients](../../sdks/ts/transit-client/README.md) expose signed input preparation, capabilities and exact mutation recovery; [Go](../../sdks/go/README.md) currently exposes only that slice | A first-class data application should not have to start from principal sequences and mailbox admission |
| [TypeScript catalog](../../sdks/ts/transit-station-sdk/docs/catalog.md) and [relational](../../sdks/ts/transit-station-sdk/docs/relational.md) clients work without a handler but are exported from Station; Python has the same catalog/query placement | Package identity mixes ordinary data access with adopting the behavior framework |
| Zig [Station](../../packages/zig/transit-station/src/root.zig) owns `Table*`, `Publication` and `ImmutableIndex`, used by [catalog](../../packages/zig/transit-catalog/README.md), [query](../../packages/zig/transit-query/README.md), [documents](../../packages/zig/transit-station-document/README.md) and [SQL](../../packages/zig/transit-sql/README.md) | Reusable data implementations and Station behavior adapters need separable package ownership |
| The [Station bridge](../../packages/zig/transit-station-bindings/README.md) and [host](../../apps/transit-station-host/README.md) expose mutually exclusive `growing_server`, `query_client`, `catalog_client` and `local_codec` modes | Sharing implementation has become coupled to a framework-shaped binding boundary and separate OS processes per client facet |
| The catalog example exposes save/next/submit/progress steps, while the [SQL client](../../packages/zig/transit-sql-client/README.md) already has service-managed admission and bounded settlement | Ordinary operation completion and advanced protocol control need distinct, composable public levels |
| [Recorded connectors](../handbook/reference/connectors.md) use Station staging; [Table change readers](../handbook/reference/tables.md#snapshot-and-change-capture) and [reactive watches](../handbook/reference/reactive.md) have separate consumption and coverage contracts | Mixed applications need ordinary caller entry points for recorded effects, durable change consumers and typed Station calls; a notification is not a complete changefeed |
| [Python handlers](../../sdks/python/transit-station/docs/runtime.md) are synchronous even in `AsyncRunner`; [Node handlers](../../sdks/ts/transit-station-sdk/docs/runtime.md) await scoped actions; [Rust clients](../../sdks/rust/transit-client/README.md) have exclusive blocking ownership | Host scheduling and asynchronous syntax need explicit per-language contracts; neither supplies durable continuations |

Preserve existing strengths: owned values, exact wide numbers and five-state
cells, explicit credentials, scoped turns, current authorization, original-request
recovery, bounded admission and joined shutdown. The raw Zig
[Session](../../packages/zig/transit-client/README.md) and
[non-Station examples](../../examples/README.md) already permit application-owned
execution loops. Keep that lower-level option for other frameworks; ordinary
data clients should not need to implement such a loop.

## Target application modes and package boundary

The Gemini Argon transcript review makes all three mixed capabilities explicit
delivery requirements. The entry points below are proposed API vocabulary, not existing
methods or frozen signatures. Design their language-native forms together with
their owning contracts before publishing runnable examples.

| Mode | Package / entry point | Application experience | Durable owner |
| --- | --- | --- | --- |
| 1. Direct data & query | `transit-client` | A script, request handler or service declares schemas, reads/writes Tables, KV and Documents, composes supported transactions/outbox intents, streams SQL `ResultSet`s and observes accepted operations with zero Station imports | Existing Transit catalog, data, query and SQL service owners |
| 2A. Mixed: standalone recorded effects | `transit-client` (`client.effects`) | Ordinary caller code invokes governed HTTP, gRPC or outbound MCP connectors with explicit operation identity, secret references, capture and network-free replay outside a handler turn | Connector intent, capture and reconciliation owners |
| 2B. Mixed: data-activated stream consumers | `transit-client` (`client.subscribe`) | A lightweight function or worker subscribes to `TransitLog`, Table or Document change streams with durable checkpointing, explicit delivery profiles (`complete_changes`, `net_changes`, `recompute`) and snapshot-to-tail handoff | Storage changefeed and reactive subscription owners |
| 2C. Mixed: caller-to-actor RPC | `transit-client` (`client.service`) | Ordinary caller code invokes a named or PID-addressed Station behavior using shared typed request/reply schemas and waits on its durable correlation outcome without hosting a local actor | Native mailbox admission, Station behavior owner and recorded reply evidence |
| 3. Full Station behavior | `transit-station` (`GenServer`, `Supervisor`, `Turn`) | A stateful actor consumes recorded input, proposes atomic turn-scoped KV state and staged Table/Document/effect intents, and participates in supervision and registries | The native turn commit boundary plus Station's recorded behavior state |

These are explicit compositions, not a connection-wide mode switch. The target
lets non-Station and mixed callers use the `transit-client` SDK surface without a
Station dependency; `transit-station` layers on top
of `transit-client` for applications that author stateful actor behaviors. The
same application may deploy direct callers, stream consumers and Station workers
together or separately. Sharing a model or endpoint does not share permission,
an activation or a transaction.

## Milestone dependencies and completion map

| Capability | Foundation milestones | Completion required here |
| --- | --- | --- |
| Direct Table, KV, Document and Catalog operations | [Installed lifecycle](03-live-storage-and-sql-cutover.md), [client foundation](06-client-foundation-and-language-apis.md), [SDK coverage](11-service-and-sdk-coverage.md) | Preserve the delivered direct-client packages, bounded operation/recovery helpers and low-level control while composing all application modes |
| Transactions and transactional outbox | [Transactions](05-transactions-and-atomic-composition.md), [client foundation](06-client-foundation-and-language-apis.md) | Qualify idiomatic transaction scopes, provisional results, savepoints, uncertain commit recovery and staged messages/effects across direct and mixed programs |
| SQL execution, `StatementResult` and streaming `ResultSet` | [Milestone 4](04-statement-results-and-consumption.md), [Milestone 11](11-service-and-sdk-coverage.md) | Expose unified `client.sql` / `client.query` streaming iterators and command outcomes directly on `transit-client` in every target language |
| Data-activated stream consumers (`client.subscribe`) | [Milestone 2](02-storage-and-query-performance.md), [Milestone 8](08-sql-and-dataflows.md), [Milestone 11](11-service-and-sdk-coverage.md), [Milestone 21](21-reactive-context-and-agent-activation.md) | Bind language-native iterators/callbacks to fenced durable consumer positions, explicit delivery profiles and snapshot-to-tail handoffs without requiring `GenServer` |
| Standalone recorded effects (`client.effects`) | [Milestone 11](11-service-and-sdk-coverage.md), [Milestone 16](16-control-and-policy-plane.md), [Milestone 22](22-recorded-mcp-integrations.md) | Add caller admission and observation over durable HTTP/gRPC/MCP intent and capture owners, preserving unknown outcomes and connector-specific retry policy |
| Typed caller-to-actor RPC (`client.service`) | [Milestone 1](01-declarative-data-lifecycle.md), [Milestone 11](11-service-and-sdk-coverage.md), [Milestone 17](17-published-resources-and-investigations.md) | Provide shared service definitions, durable request correlation and outcome settlement from `transit-client` without manual `256B` frame packing or caller-hosted actors |
| Turn-scoped actor composition (`transit-station`) | [Milestone 1](01-declarative-data-lifecycle.md), [Milestone 3](03-live-storage-and-sql-cutover.md) | Align `Turn` views and proposals (`turn.kv`, `turn.tables`, `turn.documents`, `turn.effects`, `turn.call`) with `transit-client` domain types while enforcing the atomic commit boundary |

## Delivery sequence

1. **Extend the foundation's application contract to complete mixed programs.** Map
   data/definition identities, typed values/codecs, connections and credentials,
   statement results, accepted-operation handles, service requests and execution
   scopes to their existing owners. Specify which APIs are pure preparation,
   ordinary reads, independently committed operations, private turn actions or
   recorded effects. Define each completion and cancellation boundary. Keep
   generated wire/ABI declarations separate from application-facing types.
   Review side-by-side direct, mixed and Station programs over one domain in
   Python, TypeScript, Rust, Go, Zig and BEAM before freezing APIs; extend the
   same review to every claimed language. Include happy paths, interruption and
   recovery, not just method signatures. Resolve ordinary catalog/object/service
   references from explicit endpoint, credentials and namespace configuration;
   expose infrastructure coordinates only when needed. Resolution must bind work
   to exact identities/definitions and current grants, not redirect accepted work
   after a rename or replacement.
2. **Extend the delivered package/client foundation to mixed capabilities.**
   Require milestone 6's extraction of reusable Table storage, publication and
   immutable-index primitives from `packages/zig/transit-station` into shared
   implementation packages; verify that subscriptions, effects and service calls
   preserve that dependency boundary. Keep turn/behavior adapters with Station;
   moving every `Table*` file wholesale
   would not establish the intended dependency boundary. Catalog, query, SQL and
   serving data paths should depend on those shared owners, with Station
   dependencies limited to actual behavior integration. These packages remain
   under `packages/`; runtime code must never depend on consumer `sdks/` facades
   or grow a kernel-to-framework dependency. Make catalog/Table,
   qualified KV/Document, SQL/result, changefeed subscription, standalone recorded
   effect and service-invocation clients usable from `transit-client` without a
   Station runner, activation, caller PID or Station native artifact. Unify the
   native host/ABI bridge from milestone 6 so one client context can compose catalog,
   query, data, subscription, effect and RPC facets over bounded shared resources
   instead of requiring mutually exclusive OS host modes. Define principal
   sequence coordination, handle ownership, fair scheduling, cancellation and
   joined shutdown. Slow scans must not starve effect/control progress or other
   principals. A shared context need not serialize every operation on one socket
   or thread; pure codecs must remain usable without credentials or I/O. Service
   implementations may still use Station internally; `transit-station` layers on
   `transit-client` for applications authoring stateful actor behaviors. Define
   concrete package manifests and dependency direction before moving code.
3. **Compose ordinary and advanced recovery across the new capabilities.**
   Reuse milestone 6's submission, bounded settlement and result consumption over
   the owning service/client contracts, including `transit-sql-client`. Applications should
   not each implement upload/sequence/poll loops to execute a normal statement.
   Keep prepare/save/dispatch and application-owned recovery stores available for
   callers needing explicit control; never hide local persistence or expand a
   transport retry into new work. Surface original accepted identity, progress,
   confirmed outcome or uncertainty when the wait ends. Distinguish incomplete
   reads from genuinely empty complete results.
   Specify the recovery-store hook, failure behavior and recovery guarantee when
   no store is configured. Persist exact prepared work before dispatch when the
   chosen profile promises recovery after caller loss. Bind application operation
   keys to their scope, frozen content and definition; reject conflicting reuse
   and define receipt retention. A string key alone supplies no durability.
   Move mechanical staging, continuation and wakeup work into the owning shared
   service/framework state machines so ordinary callers and handlers do not each
   implement FIFO queues and `Advance` self-casts. Preserve durable progress,
   interleaving policy, quotas and original identity; arbitrary host stack frames
   do not become durable continuations. Direct ingestion remains independent of
   actor frame limits when no custom behavior is invoked.
   Add idiomatic transaction contexts/callbacks over milestone 5's supported
   domain, isolation, read-your-writes and savepoint contract. Distinguish
   provisional statement outcomes from committed results and original commit
   recovery. A local timeout or context exit cannot manufacture rollback.
   Stage messages/effects through the shared transactional outbox; durable commit
   may permit dispatch despite a lost client reply. Never rerun arbitrary host
   I/O on an automatic callback retry or await a staged effect as though it had
   already executed inside the transaction. Direct transactions, native turns and
   consumer checkpoints share a commit only where the owning contract permits.
4. **Define typed caller-to-actor RPC.**
   Bind service requests, replies and codecs (`client.service`) to explicit
   application definitions and authorized service identities. Specify admission,
   durable correlation, recorded reply/result ownership, observation, cancellation
   and retention without requiring the caller to host a behavior or pack raw
   mailbox frames just to receive an outcome. A host future is a temporary view
   on that durable operation identity, not its durable record. Preserve
   destinations through name rebinding and replacement. Reuse supported service
   operations; missing invocation/result contracts must be designed explicitly,
   not simulated by an unbounded hidden client worker or private mailbox.
5. **Expose data-activated consumers with explicit recovery boundaries.** Bind
   `client.subscribe` iterators/functions to qualified Table/Document or logical
   `TransitLog` feeds, rather than exposing storage implementation records. Define
   complete ordered changes, net changes and recomputation profiles with their
   owners; these are semantic choices, not interchangeable delivery optimizations.
   Specify snapshot-to-tail handoff, transaction completeness, schema evolution,
   deleted rows, gaps, backpressure, pause/resume and consumer ownership/fencing.
   A host iterator is a view on a durable subscription and checkpoint.
   Define whether processing and checkpoint advancement share an existing commit
   scope. Independent RPCs, effects and data writes remain separate operations;
   advancing a checkpoint after them does not make them atomic. Record progress
   and stable per-step identities so replay resolves original work after a crash
   between any two steps. Identities must distinguish source object/partition,
   transaction and individual change, not assume a log position identifies one
   row globally. Define concurrent-write preconditions and stale decisions.
   Missing retained history fails explicitly rather than resetting coverage.
6. **Make standalone effects and turn scopes explicit in mixed code.**
   Define caller admission, durable intent/attempt/capture ownership, observation
   and reconciliation for `client.effects` using the
   [connector contract](../handbook/reference/connectors.md). Work must remain
   inspectable and recoverable when the caller exits; a local await cannot own
   its only record. Keep authorization of attempts separate from publication and
   retain secret references and network-free replay. A caller operation key does
   not establish remote idempotency or make unknown outcomes safe to retry;
   connector-specific evidence and policy decide further external work. Captured
   HTTP/gRPC status alone does not establish application business success.
   Share typed schemas, keys, rows, references and diagnostics, while distinguishing
   direct clients (`Client`) from turn-scoped views and mutation proposals (`Turn`).
   Reuse pure domain functions, validation and transformations in both modes; pass
   scoped data or effect capabilities explicitly when a function performs work. A
   direct client write inside a handler is a separate committed operation; it cannot
   silently join the input/state/output commit. Use milestone 5's allowed composition,
   explicit rejection and orchestration paths before offering scoped conveniences.
   Preserve the one-mutated-KV-resource turn limit until its owner changes it. Host
   HTTP, tool calls and arbitrary awaits are not recorded effects or restartable
   continuations. A turn may atomically record an intent with its permitted state
   and input/output changes; the resulting remote action or another resource's
   publication completes separately. Shared Table references must not imply that
   every catalog Table can join an actor's commit. Preserve application-owned
   native execution loops; any convenience for a scoped native turn still needs
   an eligible activation, fencing and the original commit/recovery protocol.
   Adopting Station for one workflow should preserve existing data types and
   object identities; any change of writer
   ownership still needs its explicit fencing/recovery operation and cannot
   reinterpret accepted work.
7. **Specify the idiomatic API and runtime contract per language.** Review actual
   small programs for sync/async calls, typed errors, iteration, ownership,
   cancellation and resource cleanup. Select Python context managers and its
   callback policy, Node promises/async iteration, Rust ownership and explicit
   executor integration, Go contexts, JVM/.NET task and disposal models, C/C++
   ownership, Ruby blocks/enumerators, and BEAM process/supervision integration
   deliberately. Zig retains explicit allocator/I/O/lifetime control. Native
   BEAM processes may compose direct and mixed capabilities without adopting a
   foreign behavior loop. Host supervisors and futures do not replace durable
   Station supervision or state. Share bounded transports, workers, codecs and
   diagnostics where sound; define principal-sequence
   coordination and prevent cross-scope authority or borrowed-handle leakage.
   Align Node/browser domain types, results and diagnostics where supported while
   preserving their distinct transports and credential scopes. Browser clients
   cannot inherit native-host credentials or filesystem recovery. Qualify any
   zero-copy/Arrow integration through explicit buffer retention/release and
   preserve wide integers instead of narrowing them for convenience.
   Review worker startup, credential/activation handoff and shutdown as part of
   each example. The installed supervisor currently hosts compiled Zig workers;
   declare external-host deployment or explicitly deliver a language adapter
   through the existing [installation owner](../handbook/reference/applications.md).
   SDK API support alone does not establish managed worker deployment support.
8. **Migrate the current v1 coherently and publish the model.** Move consumers,
   generated boundaries, installed artifacts and examples together where affected;
   replace the shared definition for incompatible ABI or stored semantics. Keep
   original accepted work and reject incompatible saved artifacts. Publish the
   direct, Station and mixed workflows in caller/SDK/component guides, and the
   ownership rationale in the existing client/framework account. This does not
   require one universal SDK object, an ORM, a new workflow language, portable
   artifact support or transparent durable execution of arbitrary host code.

## Completion evidence

Require three runnable installed examples for each claimed language/profile:
an ordinary data application, a Station behavior, and their mixed composition.
Use the same dataset/types and independently checked outcomes. The mixed story
starts in an ordinary service, reads data, submits a typed durable request, lets
a Station worker update its scoped state and record an effect, then observes the
original outcome through the ordinary client. Stop/restart either side and
recover without a second business operation. Include an application-managed
native worker to preserve the lower-level execution option.

Qualify all three mixed capabilities independently and in one composed journey:
an ordinary change consumer calls a typed Station service, requests a recorded
external observation, conditionally updates its source object and advances its
checkpoint. Use the same domain definitions in callers and handlers. Each step
has an explicit durable owner and completion evidence. Crash after admission,
after a remote action but before capture, after a data commit and before checkpoint
advancement, and after a checkpoint with a lost acknowledgement. Resume original
operations; unresolved remote outcomes must remain unresolved. Include multiple
changes in one transaction, duplicate delivery, deletes, `A -> B -> A`, competing
consumers, source evolution, stale conditional writes and unavailable history.
Never infer exactly-once external execution from the checkpoint or operation key.

Prove no Station artifact/runner is required by the direct-client example.
Check shared type identity and codecs, partial results, current revocation,
wrong reply origin, name rebinding, lost acceptance/reply, cancellation racing
with completion, stale activations and turn-scope escape. A failed handler must
not be reported as rolling back a separately committed client operation.
Recorded effect replay must send no network request. Verify bounded memory,
workers/queues, sequence coordination, responsive host runtimes and joined cleanup
under slow I/O and shutdown. Independent language-pair callers/services must agree
on identities, typed values and outcomes without sharing implementation state.
Exercise mixed catalog/query/effect/behavior activity through the shared context,
including concurrent principals, cancellation of one operation, recovery-store
failure and isolation of remaining work. Measure startup cost, idle/resident
memory, native threads/processes and fairness against declared deployment budgets;
one facade over duplicated unbounded runtimes does not satisfy the requirement.
Interrupt shared staging across multiple turns and verify recovery without
application-written continuation queues or hidden volatile backlog. Verify that
turn-scoped intents can commit before their separately observed effects complete.
Add a Station workflow to the direct example while retaining its existing dataset
and authorized callers; exercise conflicting direct and worker writes under the
owning concurrency contract instead of inventing a combined transaction.

Add a direct SQL/SDK multi-object transaction and outbox example to the shared
domain. Exercise write skew, rollback after spill, uncertain commit and a committed
outbox intent whose commit reply was lost. Compare equivalent SQL and language
programs against the transaction oracle; a failed Station handler cannot roll back
an independently committed transaction. Keep external outcome uncertainty visible.

Measure application code needed for the normal and recovery paths, and review
whether examples read naturally in each language. Syntax polish and copied API
names are insufficient evidence. [SDK coverage](11-service-and-sdk-coverage.md)
retains its operation/platform matrix; record actual mixed-mode evidence in the
[proof ledger](../../tests/README.md) before claiming this programming model.
