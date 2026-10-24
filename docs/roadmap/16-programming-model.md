# 16. Language-native programming model and mixed application composition

[Roadmap](README.md) · **Status:** Planned

Let applications use Transit's data, computations and policies through ordinary
language APIs, adopt Station for selected durable behaviors, or combine both in
one application. Shared types, operation identities, results and recovery should
compose across those choices. Using a Table or calling a Station service must
not require running a Station handler in the caller.

## Prerequisites and scope

Follow [recorded outbound MCP and application guidance](15-recorded-mcp-integrations.md)
in the delivery sequence. Build on the qualified
[data lifecycle](01-declarative-data-lifecycle.md),
[direct runtime cutover](03-live-storage-and-sql-cutover.md),
[statement/result contract](04-statement-results-and-consumption.md),
[service/SDK coverage](09-service-and-sdk-coverage.md) and the relevant
[access](10-control-and-policy-plane.md),
[published-resource](11-published-resources-and-investigations.md) and connector
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
| The [Station bridge](../../packages/zig/transit-station-bindings/README.md) composes catalog callers, query/Document operations and local logical codecs alongside turn actions | Sharing implementation has become coupled to a framework-shaped binding/distribution boundary |
| The catalog example exposes save/next/submit/progress steps, while the [SQL client](../../packages/zig/transit-sql-client/README.md) already has service-managed admission and bounded settlement | Ordinary operation completion and advanced protocol control need distinct, composable public levels |
| [Python handlers](../../sdks/python/transit-station/docs/runtime.md) are synchronous even in `AsyncRunner`; [Node handlers](../../sdks/ts/transit-station-sdk/docs/runtime.md) await scoped actions; [Rust clients](../../sdks/rust/transit-client/README.md) have exclusive blocking ownership | Host scheduling and asynchronous syntax need explicit per-language contracts; neither supplies durable continuations |

Preserve existing strengths: owned values, exact wide numbers and five-state
cells, explicit credentials, scoped turns, current authorization, original-request
recovery, bounded admission and joined shutdown. The raw Zig
[Session](../../packages/zig/transit-client/README.md) and
[non-Station examples](../../examples/README.md) already permit application-owned
execution loops. Keep that lower-level option for other frameworks; ordinary
data clients should not need to implement such a loop.

## Target application modes

| Mode | Application experience | Durable owner |
| --- | --- | --- |
| Direct client | A script, request handler or existing service reads/writes declared data, streams query results and observes accepted operations without a local Station runner | Existing Transit data/computation/service owners |
| Station behavior | A handler consumes recorded input, proposes scoped state/output changes and coordinates durable calls or recorded effects | The native commit boundary plus Station's recorded behavior state |
| Mixed application | Direct callers and Station workers share typed object/service references and results; an ordinary caller invokes a selected durable service and observes its original outcome | Each operation's existing owner; composition does not create a global transaction |

These are explicit compositions, not a connection-wide mode switch. The same
application may deploy callers and workers together or separately. Sharing a
model or endpoint does not share permission, an activation or a transaction.

## Delivery sequence

1. **Define the public application contract before reorganizing packages.** Map
   data/definition identities, typed values/codecs, connections and credentials,
   statement results, accepted-operation handles, service requests and execution
   scopes to their existing owners. Specify which APIs are pure preparation,
   ordinary reads, independently committed operations, private turn actions or
   recorded effects. Define each completion and cancellation boundary. Keep
   generated wire/ABI declarations separate from application-facing types.
2. **Separate reusable data clients from optional Station behaviors.** Make
   catalog/Table, qualified KV/Document, SQL/result and publication clients usable
   without a Station runner, activation, caller PID or Station native artifact.
   Extract reusable client/type/codec and binding ownership where needed rather
   than renaming the present umbrella. Service implementations may still use
   Station internally. Station consumes the same data types and shared owners;
   the generic kernel gains no framework dependency. Define concrete package
   manifests and dependency direction before moving code.
3. **Provide ordinary operations with an explicit advanced recovery surface.**
   Build submission, bounded settlement and result consumption on the owning
   service/client contracts, including `transit-sql-client`. Applications should
   not each implement upload/sequence/poll loops to execute a normal statement.
   Keep prepare/save/dispatch and application-owned recovery stores available for
   callers needing explicit control; never hide local persistence or expand a
   transport retry into new work. Surface original accepted identity, progress,
   confirmed outcome or uncertainty when the wait ends. Distinguish incomplete
   reads from genuinely empty complete results.
4. **Define typed invocation between ordinary callers and Station services.**
   Bind requests, replies and codecs to explicit application definitions and
   authorized service identities. Specify admission, durable correlation, recorded
   reply/result ownership, observation, cancellation and retention without
   requiring the caller to host a behavior just to receive an outcome. A host
   future is a temporary wait on that identity, not its durable record. Preserve
   destinations through name rebinding and replacement. Reuse supported service
   operations; missing invocation/result contracts must be designed explicitly,
   not simulated by an unbounded hidden client worker or private mailbox.
5. **Make execution scopes and effects explicit in mixed code.** Share typed
   schemas, keys, rows, references and diagnostics, while distinguishing direct
   clients from turn-scoped views and mutation proposals. Reuse pure domain
   functions, validation and transformations in both modes; pass scoped data or
   effect capabilities explicitly when a function performs work. A direct client write
   inside a handler is a separate committed operation; it cannot silently join
   the input/state/output commit. Define allowed composition, explicit rejection
   and orchestration paths before offering transaction-like conveniences. Preserve
   the one-mutated-KV-resource turn limit until its owner changes it. Host HTTP,
   tool calls and arbitrary awaits are not recorded effects or restartable
   continuations. Recorded connectors retain intent, current authorization,
   capture/reconciliation and network-free replay whether invoked through a
   Station workflow or a qualified ordinary service client.
   Adopting Station for one workflow should preserve existing data types and
   object identities; any change of writer ownership still needs its explicit
   fencing/recovery operation and cannot reinterpret accepted work.
6. **Specify the idiomatic API and runtime contract per language.** Review actual
   small programs for sync/async calls, typed errors, iteration, ownership,
   cancellation and resource cleanup. Select Python context managers and its
   callback policy, Node promises/async iteration, Rust ownership and explicit
   executor integration, Go contexts, JVM/.NET task and disposal models, C/C++
   ownership, Ruby blocks/enumerators, and BEAM process/supervision integration
   deliberately. Zig retains explicit allocator/I/O/lifetime control. Host
   supervisors and futures do not
   replace durable Station supervision or state. Share bounded transports,
   workers, codecs and diagnostics where sound; define principal-sequence
   coordination and prevent cross-scope authority or borrowed-handle leakage.
7. **Migrate the current v1 coherently and publish the model.** Move consumers,
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

Prove no Station artifact/runner is required by the direct-client example.
Check shared type identity and codecs, partial results, current revocation,
wrong reply origin, name rebinding, lost acceptance/reply, cancellation racing
with completion, stale activations and turn-scope escape. A failed handler must
not be reported as rolling back a separately committed client operation.
Recorded effect replay must send no network request. Verify bounded memory,
workers/queues, sequence coordination, responsive host runtimes and joined cleanup
under slow I/O and shutdown. Independent language-pair callers/services must agree
on identities, typed values and outcomes without sharing implementation state.
Add a Station workflow to the direct example while retaining its existing dataset
and authorized callers; exercise conflicting direct and worker writes under the
owning concurrency contract instead of inventing a combined transaction.

Measure application code needed for the normal and recovery paths, and review
whether examples read naturally in each language. Syntax polish and copied API
names are insufficient evidence. [SDK coverage](09-service-and-sdk-coverage.md)
retains its operation/platform matrix; record actual mixed-mode evidence in the
[proof ledger](../../tests/README.md) before claiming this programming model.
