# 13. Declarative serving and reactive dataflows

[Roadmap](README.md) · **Status:** In Progress ([implementation plan](declarative-serving-implementation.md))

Let an application declare typed inputs, data dependencies, computations,
authorized operations and publications, then consume their results through a web
client or an interactive REPL. Transit owns execution, publication, subscription
progress and recovery; application code owns HTML, components, terminal rendering
and interaction design. The same declared API must run in `transit server`
without Station packages, actors, ingress PIDs or a Station service identity.

This Phase I milestone owns the complete serving and reactive-consumption
boundary. It replaces the target of a declarative UI language with declarative
dataflows that UI and non-UI clients can consume. It does not describe newly
implemented syntax or change any current wire contract by itself.

The [first contract/dependency review](declarative-serving-cutover.md) records the
proposed operation owners, endpoint/retained-record migration inventory and the
neutral HTTP extraction. The complete serving/subscription cutover remains open.

## Prerequisites and current evidence

Build on the [data lifecycle](01-declarative-data-lifecycle.md),
[storage and retained changes](02-storage-and-query-performance.md),
[installed owners](03-live-storage-and-sql-cutover.md),
[statement results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[Streams and Queues](06-streams-queues-and-durable-runtime.md),
[gateway hosting](08-gateway-architecture-and-protocol-ingress.md) and
[shared clients](09-client-foundation-and-language-apis.md). Use each qualified
data kind; Document integration consumes [its own cutover](07-document-storage-and-station-decoupling.md).
Compose source declarations through [M12](12-application-modules-compilation-and-testing.md)
as its compiler supports them, while preserving independently executable SQL
and typed public operations. Full source-toolchain completion is not a prerequisite
for defining or exercising the serving contract.

The source audit at `a43ceee1d` identifies reusable owners and a real mismatch:

| Existing boundary | Evidence and limit |
| --- | --- |
| Serving and reactive sessions | [SERVING_V1](../../contracts/SERVING_V1.md) makes a Station ingress own a service; [REACTIVE_V1](../../contracts/REACTIVE_V1.md) stores sessions/subscriptions under that owner. Rehosting these adapters does not remove their Station dependency. |
| Declarative browser publications | [BROWSER_V1](../../contracts/BROWSER_V1.md) and [the runnable example](../../examples/declarative-browser/README.md) provide catalog administration, real Table snapshots and WebSocket watches. The executable projection excludes parameters, joins and aggregates; it polls watermarks and reconnects with a new snapshot, without a replay cursor. Typed administration is not executable publication SQL. |
| Shared results and publication models | [SQL_RESULTS_V1](../../contracts/SQL_RESULTS_V1.md) and [PUBLISHED_RESOURCE_V1](../../contracts/PUBLISHED_RESOURCE_V1.md) provide result/disclosure and resource definitions to reuse. Pure projection helpers and model tests do not establish a complete installed API. |
| Application interfaces and Board | [APPLICATION_V1](../../contracts/APPLICATION_V1.md), [the interface model](../../packages/zig/transit-station-app/src/Model.zig) and [Board's definition](../../apps/transit-board/board.sql) include screens, themes and renderer bindings. [Board](../../apps/transit-board/main.zig) separately dispatches handwritten API routes. These remain current implementations until their consumers migrate. |

Preserve recorded guarantees and evidence during the cutover. A new milestone
does not reset unfinished work or certify the combination of existing slices.

## Ownership and dependency direction

Definitions, publication revisions, policy and any durable subscription progress
belong to the Control & Policy Plane and database storage owners. Fuze evaluates
queries and dataflows over public authorized data operations. Gateway adapters
bind transports to those operations; they own sockets and bounded buffers, never
an independent catalog, permission store or execution ledger. Station may use
these capabilities through an optional adapter above them. The shared serving,
subscription and client implementation must have no transitive Station dependency.

| Owner | Boundary with this milestone |
| --- | --- |
| M4 / M5 / M6 | Own statement completion, atomic decisions and retained Stream/Queue history. Serving preserves original operation identity and commit boundaries; it does not invent a second transaction or retry protocol. |
| M8 / M9 | Own gateway infrastructure and shared client foundations. This milestone supplies the publication/subscription semantics and installed web/REPL proofs those adapters consume. |
| M12 | Owns source modules, compilation and testing. Emit declarations through this milestone's ordinary SQL owners; no separate UI language or hidden deployment authority. |
| [M14 managed computations](14-sql-and-dataflows.md) | Owns general managed scheduling, incremental operators and complete analytical/dataflow execution. This milestone owns how clients bind inputs, observe results and subscribe. Initial finite queries, snapshot refresh and retained Stream delivery do not wait for a general incremental engine; broader maintained queries use M14's qualified outputs. |
| [M23 service/SDK coverage](23-service-and-sdk-coverage.md) | Expands type, language and transport coverage after the shared serving contract; representative browser and REPL clients are required here. |
| [M29 control and policy](29-control-and-policy-plane.md) / [M30 published resources](30-published-resources-and-investigations.md) | Extend existing authorization with enterprise policy and enriched resources, disclosure and retained investigations. Reuse their delivered models where applicable. Basic publication and subscriptions cannot require those later milestones to finish. |
| [M32 Board](32-board-reimplementation.md) | Consumes public inspection, query and reactive operations. Workbench layout and broader workflows remain there; this milestone owns removal of the bespoke serving dependency and executable/package after migration. |
| [M34 reactive context](34-reactive-context-and-agent-activation.md) | Adds business conditions, governed context assembly and agent activation over the generic subscriptions delivered here. Basic reactivity has no MCP or agent prerequisite. |

## Contract decisions before implementation

1. **Declare dataflows independently of presentation.** Bind stable object and
   definition identities, typed parameters, source dependencies, result schemas,
   execution lifetime, policy and budgets. Support a finite invocation and an
   explicitly maintained or subscribed observation without turning every read
   into a durable job. Parameter changes establish a new bound generation; late
   output cannot replace the current generation. A client edit cannot implicitly
   apply DDL, dispatch a command or authorize an external effect.
2. **Publish explicit capabilities.** Define discoverable read/query, command
   and subscription operations, with typed inputs and outcomes, publication
   revisions, permitted audiences and current authorization. Publication creates
   no grants. Separate definition validation, publication, authorization,
   activation and withdrawal. Bind accepted commands to their original definition
   and idempotency identity; lost responses remain recoverable without resubmission
   as new work. A read-only publication must not disclose backing write credentials
   or expose arbitrary SQL execution.
3. **Select observation semantics.** Distinguish finite results, latest complete
   snapshots, net relation changes and every ordered source event. Define an
   explicit supported profile for each operation. Coalescing is permitted only
   where that profile allows it; a snapshot diff cannot recover intermediate
   `A -> B -> A` events. Reuse the shared result schema and completion rules for
   finite reads, with separate revision/progress semantics for continuous work.
4. **Define subscription identity, lifetime and recovery.** Separate connection
   attachments, ephemeral session interests and explicitly durable subscriptions.
   Define a race-free initial snapshot-to-change handoff, cursor/checkpoint
   meaning, acknowledgement, duplicate handling and retention ownership for each
   profile. Reattach to the original durable interest under current authorization.
   Missing retained coverage requires a typed gap/reset/refusal; never silently
   downgrade complete delivery to a fresh snapshot. Closing a socket, cancelling
   observation and cancelling accepted work are different operations.
5. **Bind transports to the shared contract.** Declare route/method, input
   binding, output codec, authentication, Host/Origin policy and resource limits
   for HTTP request/response, SSE and WebSocket. Native/local clients consume the
   same typed operations without an HTTP loopback requirement. Generate OpenAPI,
   AsyncAPI and client types from shared definitions; runtime validation and
   lossless value handling remain mandatory. A frame, notification or successful
   socket write cannot establish statement completion or end-to-end delivery.
6. **Bound work and preserve disclosure.** Budget active computations, reads,
   buffers, frame sizes, retained pins and per-consumer lag. Recheck current
   permission after buffering and before disclosing rows, metadata or progress.
   Define slow-consumer pressure, fair control capacity, joined cancellation,
   schema replacement and publication withdrawal. Retained history must not
   imply unbounded resident queues; quota pressure cannot authorize expiry.

Record these decisions in the owning serving, reactive, browser, publication,
application and result contracts before dependent adapters. The existing v1
cutover policy applies: replace incompatible definitions and migrate consumers,
fixtures, generated schemas and recovery formats together. Reject foreign stored
definitions; never reinterpret accepted work or silently reset saved state.

## Delivery sequence

1. **Inventory and settle the neutral contract.** Map current serving, browser
   publication and Board routes to shared operations. Identify missing public
   inspection/query operations explicitly. Define the initial supported source,
   parameter, result and delivery matrix and independent fixtures. Retain existing
   source-specific evidence; mark unimplemented SQL and transports as such.
2. **Extract Station-independent owners.** Implement publication admission,
   operation recovery, subscription control and observation over catalog,
   transaction and data owners. Keep Station adapters above that boundary.
   Prove both the transitive package graph and installed runtime independence;
   disabling a Station process while importing its semantics does not pass.
3. **Deliver declarative installation and hosting.** Add executable SQL lifecycle
   operations and typed callers, with immutable migration receipts and explicit
   activation/withdrawal. Integrate the M12 emitter where supported. `transit
   server` hosts the declared routes and shared transport adapters using M8's
   hosting and deadline owners. Ordinary request/response queries need neither
   an application-authored worker nor a Queue solely to obtain their result.
4. **Deliver reactive consumption and two clients.** First qualify parameterized
   finite reads and complete snapshot refresh, then retained ordered Stream
   delivery with explicit durable resumption. Add net relation changes only
   against an owner that proves their semantics. Provide a TypeScript browser
   client and an interactive REPL using shared typed consumption and cleanup.
   Keep rendering, editing and presentation state in those applications.
5. **Migrate consumers and retire the UI-definition path.** Move existing serving
   and reactive consumers to the replacement contracts. Retire screen/theme/
   renderer declarations and their compiler/runtime dependencies after migrating
   actual consumers; retain ordinary frontend code and generated data client types.
   Serve Board assets and declared inspection APIs through the shared server
   capability, preserving private deployment admission, its read-only upstream
   grant and separately scoped workspaces. Migrate launchers, packaging, fixtures
   and docs before removing the `transit-board` executable/package. A second
   application must use the same serving capability without Board-specific code.
6. **Qualify and publish the supported profiles.** Execute the acceptance matrix
   below against one committed installed build. Promote actual behavior and limits
   to Serving, Reactive, Applications, caller and Board references. Keep broader
   sources, incremental operators, enterprise identity and agent policy with their
   named owners; none can substitute for this milestone's first complete journey.

## Completion evidence

Declare an application with a parameterized open-tickets query, an authorized
ticket-update command and a retained event Stream. Install it through public
declarations in `transit server`, without Station, screens or themes. A real
HTML/TypeScript client and a REPL consume the same API and independently verify
values, schemas, publication revisions, source basis and command outcomes. Observe
changing results while commands execute, reconnect each client, replace the
server and inspect the original outcomes and subscription progress.

| Proof | Required observation |
| --- | --- |
| Dependency boundary | Shared serving/subscription/client packages compile without transitive Station imports; installed API use starts no Station actors or hidden requester processes. |
| Finite results and parameters | Empty and multi-batch results, wide integers/decimals, unsupported cell/type refusal, parameter validation and changed input generations agree across both clients. EOF, display limits and interrupted prefixes never imply completion. |
| Snapshot and change handoff | Writes racing initial acquisition, multi-object commits, pending recomputation and `A -> B -> A` preserve the selected profile. Compare completed views with an independent finite oracle; no partially committed result is published. |
| Recovery and accepted work | Lost command replies, duplicate submissions, restart, cancellation races and stale-definition requests preserve the original identity and outcome. Reconnection does not enqueue a new command or manufacture success. |
| Subscription lifecycle | Session close and durable resume differ; duplicate events/checkpoints, cursor tampering, changed schema, publication withdrawal and unavailable retained history produce the contracted outcome. |
| Authorization and bounds | Cross-audience reads, revocation after buffering, slow readers, exhausted budgets and growing retained history preserve denial, bounded resident memory and control progress. Cleanup remains available without renewed data access. |
| Installed consumers | Browser HTTP/SSE/WebSocket and REPL/native paths exercise the shared contract. Board inspection and a second application run through the shared server with no `transit-board` binary or hidden Board-only API authority. |

Component tests, generated OpenAPI/AsyncAPI, parser acceptance and a running socket
are separate evidence from these installed journeys. Record exact commands,
revisions, profiles and failures in the qualification ledger; this planning change
executes none of the proposed runtime proofs.
