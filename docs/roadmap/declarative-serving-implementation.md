# Milestone 13 implementation plan

[Milestone 13: Declarative serving and reactive dataflows](13-declarative-serving-and-reactive-dataflows.md)
· **Status: In Progress** · 2026-11-15

Deliver one application-defined API through `transit server`, consumed by a real
HTML/TypeScript client and an interactive REPL, without Station packages or
actors in the shared serving path. Applications declare data, typed operations,
publication policy and reactive observations. Client code owns presentation.
Then migrate existing serving consumers and Board onto those same capabilities,
retire the screen/theme interface language and remove the standalone
`transit-board` executable and distribution package.

Implementation has started with the [first contract/dependency review](declarative-serving-cutover.md). Its source basis is `424cc32e8`, the merge of
[PR #464](https://github.com/spoke-sh/transit/pull/464). The audit below inspected
source and package manifests; it did not execute runtime proofs. Milestone 13
is In Progress. All new interfaces and implementation names below are proposals
until their owning contracts and executable checks land.

## First complete application and scope

Use one tickets application throughout implementation and qualification:

| Declaration | Intended operation |
| --- | --- |
| Tickets Table | Typed ticket ID, project ID, status, title and revision, with native authorization and a stable definition identity |
| Open tickets query | A parameterized, bounded single-Table projection/filter; complete results carry schema and source evidence |
| Update ticket command | Typed ID, expected revision and changed fields; native conditional mutation with an original recoverable operation identity |
| Ticket events Stream | Explicitly declared ordered events with durable consumer progress; update plus event append uses the qualified common transaction |
| API publication | Named read, command and subscription capabilities, audience, transport bindings and budgets; publication itself grants no rights |

The browser and REPL first read the same query, submit the same command and watch
complete successor snapshots. Next, each consumes the retained Stream, disconnects
and resumes its original subscription. The Stream is application data, not an
automatic event log synthesized by the gateway. If a Table/Stream common decision
is unavailable in the selected installed profile, close that M5/M6 integration
gate before claiming update/event atomicity.

The first finite projection supports the current scalar browser types, NULL and
typed parameters. Explicitly reject unsupported operators, values and codecs;
never round wide integers/decimals or collapse missing/conflict/type-error into
NULL. Broader existing query consumers must retain their qualified value and
result semantics at migration, even when they exceed this first example.
General joins, incremental operator maintenance, arbitrary multi-source live SQL,
enterprise identity and agent activation retain their M14/M29/M34 owners.

Define net-relation-change semantics in the shared contract, but enable that
profile only when its computation owner can prove it. Initial implementation
must deliver finite reads, latest-complete-snapshot observation and retained
ordered Stream delivery. General incremental SQL is not a prerequisite.

## Source audit and reuse map

| Source at the audited revision | Reuse and required change |
| --- | --- |
| [Serving manifest](../../packages/zig/transit-serving/build.zig.zon), [root](../../packages/zig/transit-serving/src/root.zig), [service contract](../../contracts/SERVING_V1.md) | Direct dependencies include Station and `transit-query`, which also reaches Station. Service identity/admission uses an ingress PID and turns. Replace the ownership model; a renamed executable or changed top-level import is insufficient. |
| [HTTP host manifest](../../packages/zig/transit-serving-http/build.zig.zon), [BrowserProviders](../../packages/zig/transit-serving-http/src/BrowserProviders.zig), [ApplicationEffectRuntime](../../packages/zig/transit-serving-http/src/ApplicationEffectRuntime.zig) | Browser/provider and effect helpers share this host with signed Station dispatch. They import request/transport types from `transit-station-http`. Extract neutral HTTP mechanics and separate optional effect/Station composition. |
| [HTTP listener](../../packages/zig/transit-http-server/README.md) | Already independent of Transit/Station; retain framing, deadlines, wait/control admission and joined cancellation. This milestone consumes M8's hosting rather than implementing another listener. |
| [BrowserAdministration](../../packages/zig/transit-catalog/src/BrowserAdministration.zig), [BrowserDeclarations](../../packages/zig/transit-catalog/src/BrowserDeclarations.zig), [BrowserRecordStore](../../packages/zig/transit-catalog/src/BrowserRecordStore.zig) | Typed preparation, conditional publication and paged immutable control records already exist. Records reuse DirectClientToken; do not add a gateway journal. Publication validation currently rejects parameters and multiple dependencies. Publication SQL remains missing. |
| [PublishedResource](../../packages/zig/transit-catalog/src/PublishedResource.zig), [published-resource contract](../../contracts/PUBLISHED_RESOURCE_V1.md) | Reuse stable identities, parameter domains, dependency/schema bindings and disclosure metadata. Consolidate browser/API publication around this authority; do not create a parallel resource catalog. Optional presentation descriptors are not a UI runtime. |
| [BrowserRuntime](../../packages/zig/transit-serving-http/src/BrowserRuntime.zig), [BrowserSnapshot](../../packages/zig/transit-serving-http/src/BrowserSnapshot.zig), [BrowserWatch](../../packages/zig/transit-serving-http/src/BrowserWatch.zig) | Actual catalog-backed Table reads and changed snapshots exist. Current watches poll metadata every 500 ms, are bounded in lifetime and reconnect with a fresh snapshot; they supply no durable replay cursor. Do not describe this path as complete resumable subscriptions. |
| [NativeServer](../../apps/transit-node/NativeServer.zig), [server configuration](../../apps/transit-cli/server/Config.zig) | The internal node module co-hosts BrowserRuntime with native/SQL services through a local endpoint. Extend this composition. The source directory name does not imply a published `transit-node` executable. |
| [SQL client](../../packages/zig/transit-sql-client/README.md), [SQL_RESULTS_V1](../../contracts/SQL_RESULTS_V1.md), [direct query package](../../packages/zig/transit-query-direct/build.zig.zon) | Client/direct-query manifests have no transitive Station dependency. Reuse typed results, original operations, bounded readers and temporary workbook computation instead of a serving-only result protocol. |
| [DirectStreamClient](../../packages/zig/transit-catalog/src/DirectStreamClient.zig), [DirectStream](../../packages/zig/transit-catalog/src/DirectStream.zig) | Existing observe/page/cursor/group/wait and saved-mutation operations provide the data boundary. Define authorized subscription ownership and checkpoint mapping over them; a returned cursor alone is not a retained-history guarantee. |
| [Reactive TypeScript client](../../packages/ts/transit-reactive-client/README.md), [private client contract](../../contracts/REACTIVE_CLIENT_V1.md) | Preserve runtime validation, frozen-control recovery, bounded state, joined shutdown and denial handling. Replace the required private signing host with a shared publication client profile; browser clients must not need Board as a proxy. |
| [Board routing](../../apps/transit-board/main.zig), [Workbench](../../apps/transit-board/Workbench.zig), [Board API](../../packages/zig/transit-board-api/README.md) | ReadWorkspace, WorkbookWorkspace and public catalog/managed inspection are reusable. Board's API manifest also reaches Station, legacy query and connector codecs. Extract reusable operation contracts and isolate optional framework projections above the generic serving boundary. |
| [Interface definition](../../apps/transit-board/board.sql), [station-app package](../../packages/zig/transit-station-app/README.md) | UI definitions coexist with named relational/resource publication and migration. Retire only the UI path after classifying and relocating remaining real owners; deleting the whole package would discard unrelated capabilities. |
| [Build composition](../../build/runtime.zig), [Nix distribution](../../nix/transit.nix), [release inventory](../../tasks/package_release.py), [runtime roles](../../apps/transit-cli/RuntimeRole.zig) | Board is built separately and distributed as a copy of the Transit executable selected by its invoked name. Removing that artifact requires consumer, configuration, launcher and release-test migration. |

## Proposed decisions for review

### D1. One publication authority and no Station dependency

Keep durable declarations and subscription/control records in `transit-catalog`,
backed by existing direct storage and conditional operations. Refactor
`transit-serving` into neutral serving/subscription semantics over protocol,
catalog and shared result types. Keep physical HTTP hosting in
`transit-serving-http`, with native/local entry points invoking the same owners.
Neither package nor the shared consumption client may depend transitively on
Station or the legacy `transit-query` package merely to obtain types.

Extract the existing reusable HTTP request/transport implementation into a real
neutral library, tentatively `transit-http`, consumed by both the host and Station
HTTP adapters. Preserve its single implementation and fixtures. Do not duplicate
TLS, secret-reference rendering, capture or retry behavior to escape an import.
Station behavior, captured Query and connector-specific projections remain
optional adapters above shared serving; their dependencies cannot enter its base
module graph. Providers and runtime placement supply I/O, not authority.

### D2. Bind typed operations, not arbitrary server callbacks

A publication binds stable object/definition revisions, an operation kind, typed
parameters/results, policy and budgets. A transport binding adds route/method,
codec and origin/authentication constraints. It references a public typed query,
command, inspection or subscription operation; it cannot serialize an arbitrary
Zig callback or smuggle application handlers into the node.

SQL declarations and M12-generated SQL use those same owners. Settle syntax and
negative grammar cases in P0 before enabling execution; examples in this plan
describe semantics rather than introducing a runnable SQL dialect. The runtime
requires neither source repositories nor screen/theme definitions.

### D3. Preserve the native command acceptance boundary

Use current scoped caller authority and the existing token/operation machinery.
Bind the request to its publication/definition, caller, parameters and original
operation before dispatch. Persist or deterministically recover the mapping to
the exact native intent so a lost gateway response cannot create a second write.
Decide the atomic admission/mapping boundary in the contract, not independently
inside each adapter. Public status recovery must address that original operation.

Finite reads and ordinary mutations execute directly through database owners.
A Queue or captured job is required only by an explicitly selected workflow.
Stopping an observation does not roll back accepted work; external effects remain
recorded, separately authorized operations. Preserve existing protected provider
exchange behavior during extraction, without making the unfinished #430 workflow
journey a hidden prerequisite for an ordinary Table API.

### D4. Keep result, refresh and event delivery distinct

Use `SQL_RESULTS_V1` for finite results, including schema, observation, typed
batches, terminal count and early release. A refresh publishes a new complete
result revision, never a patch applied to an incomplete prefix. Parameter edits
create a new generation; stale output retains its old attribution and cannot
replace the current generation. Commands require explicit submission.

For latest-snapshot observation, coalescing is allowed and reconnect may establish
a clearly identified new snapshot. For ordered Stream delivery, retain original
subscription identity and checkpoint, allow identifiable replay after an uncertain
acknowledgement and advance only a verified contiguous processed frontier.
Do not promise exactly-once application effects. SSE Last-Event-ID and WebSocket
frames are projections of this contract, not an independent progress authority.
Partition positions remain a vector unless an owner supplies a common order.

### D5. Make lifetime and disclosure explicit

Offer connection/session-scoped interests and explicitly durable subscriptions.
Define owned retained-history/pin obligations, attachment fencing, lease/expiry,
close and authorized cleanup independently. Durable does not mean an unbounded
resident backlog. Retention stays unlimited by default; permitted history expiry
causes the contracted gap/refusal and never an implicit reset for ordered delivery.

Recheck publication, caller and source rights after buffering and immediately
before bounded disclosure, including metadata and terminal counts. Start with
existing native credentials and browser identity bindings. Keep publisher-backed
public reads and caller-bound protected reads explicit; a service credential
cannot accidentally broaden either. Board retains private deployment admission,
its read-only upstream identity and separately scoped query/application workspaces.

### D6. One current-v1 cutover

Coordinate `SERVING_V1`, `REACTIVE_V1`, `REACTIVE_CLIENT_V1`, `BROWSER_V1`,
`APPLICATION_V1` and affected publication/result definitions. Keep one semantic
owner per operation; browser identity and wire framing contracts may remain
separate without duplicating publication or subscription authority. Replace the
shared definition identifier wherever incompatible stored/wire semantics change.

Private candidate helpers and tests may land in earlier review units. Do not
ship an alternative public v1 profile, deprecated route, compatibility alias or
fallback decoder while consumers migrate. The installed candidate journey runs
on the implementation branch; P7 performs the coordinated public cutover.
P0 reviews proposed contract changes and fixtures; publish the replacement current
contract definition with its runtime and consumer cutover, not as a premature
claim that the current executable supports it.

Inventory retained commands, captures, sessions and definitions before that cutover.
Drain original accepted work or perform an explicitly verified migration preserving
its identity and evidence. Unresolved work that cannot be preserved blocks upgrade;
never reinterpret it under a new definition, discard it or silently initialize a
fresh installation. Exporting evidence alone does not settle accepted work.

## Work packages and review boundaries

Each package can contain multiple logical commits. Existing public behavior stays
intact until the coordinated cutover; component results do not establish an
installed serving profile. Scope and evidence move together in each review unit.

| Package | Work and primary owners | Exit gate | Depends on |
| --- | --- | --- | --- |
| P0 — Contract and migration inventory | Settle D1–D6 in owning contracts; classify every current endpoint, consumer and retained record; define identities, result/event schemas, admission and snapshot handoff; create independent positive/negative fixtures and grammar cases | Reviewed capability matrix, migration disposition per existing profile, no unresolved acceptance/authorization owner | Existing M4/M5/M6/M8/M9 contracts; qualified data kinds only |
| P1 — Neutral dependency extraction | Refactor serving roots/manifests; extract shared HTTP mechanics; move Station/captured-query/connector adapters above neutral modules; separate browser authentication from publication hosting without duplicating state | Recursive manifest/build-module checks plus a minimal compiled host with no Station imports; existing transport and provider negative controls pass | P0 |
| P2 — Catalog publication and installation | Extend BrowserAdministration/PublishedResource with typed operations and transport bindings; add ordinary SQL execution and migration receipts; implement dependency validation, conditional replacement, withdrawal and bounded discovery | Typed callers and SQL reach the same catalog revisions; crash/lost-reply installation resumes original work; publication neither grants rights nor executes requests | P0–P1; M12 lowering where supported |
| P3 — Finite API and original command outcomes | Connect native/local and HTTP dispatch to shared result readers and database operation recovery; validate parameters/codec; expose status and cleanup; co-host via NativeServer and server configuration | Installed candidate tickets read/update through browser and REPL, including empty/multi-batch reads, lost write reply, denial, restart and no Station actors | P2 |
| P4 — Latest complete snapshots | Bind source observations and parameter generations; establish snapshot-to-watch handoff; implement refresh scheduling, cancellation, withdrawal and bounded coalescing; expose SSE and WebSocket through one owner | Concurrent writes during acquisition cannot disappear behind a falsely current snapshot; slow/disconnected clients see explicit status and complete successors; every-change claims are refused | P3; M8 notification/wait hooks or explicit bounded fallback |
| P5 — Retained ordered subscriptions | Add durable control/progress records over direct owners, map Stream groups/cursors/checkpoints, fence attachments and retain required history; implement resume, acknowledgement, gaps and cleanup | Restart and lost acknowledgements preserve the same subscription and ordered coverage, including intermediate A → B → A events and explicit history loss | P2, P4; M6 retained-history/consumer contract |
| P6 — Shared clients and existing consumer migration | Evolve TS reactive consumption/validators and Zig shared callers; integrate the REPL with shared typed outcomes; migrate finite/captured/Station examples through optional adapters; regenerate OpenAPI/AsyncAPI/client types | Independent browser and terminal peers verify the same values, outcomes, progress and errors; browser requires no Board signing proxy; original recovery identities survive supported recovery | P3–P5 |
| P7 — Board, UI-definition and public-v1 cutover | Replace bespoke routing with declared shared operations, serve immutable frontend assets, move presentation configuration to frontend code; migrate interface consumers, deployment/configuration and retained state; remove superseded wire/ABI surfaces and Board artifact | All affected callers cut over together; installed Board and a second app use the same serving host; incompatible definitions reject before execution | P1–P6 and migration preflight |
| P8 — Qualification and public documentation | Run focused and committed-source integration gates at one revision; publish current operations/limits; verify package contents and installed remote/local modes | Milestone completion matrix passes with attributable evidence; no legacy executable, hidden Station requester, skipped proof or unfinished migration | P7 |

The first review should contain P0 and a small P1 extraction with its dependency
proof. The first vertical implementation target is P2–P4's tickets application;
demonstrate it before expanding publication kinds or migrating Board. P5 and P6
can develop against settled fixtures, but public release still waits for P7.
P3 includes a minimal shared client facet used by both clients; P6 extends it and
migrates existing consumers rather than replacing throwaway per-client protocols.

### Board route migration map

Resolve missing public operations in their domain before declaring routes. Do not
move `main.zig`'s switch into a new generic-looking Board service.

| Current surface | Destination and preservation requirement |
| --- | --- |
| `/api/v1/catalog`, `/api/v1/computations` | Public DirectCatalogRead/ManagedInspection operations, available to native clients and published with bounded read-only policy |
| `/api/v1/sql-read`, `/api/v1/workbook` | Shared ReadWorkspace/WorkbookWorkspace semantics and result lifecycle; session-local draft graphs remain distinct from durable managed computations |
| `/api/v1/query`, `/api/v1/relational` | Existing typed finite/captured query owners through explicit capability adapters; preserve uncertain submissions, exact result basis and separately configured scope |
| Atlas, process/resource/record and HTTP/gRPC/Document inspection | Public bounded inspection and pure, source-attributed projections. Keep framework codecs optional above generic serving; retain opaque unknown values and independent data-read grants |
| `/api/v1/application`, `/api/v1/interface` | Classify publication/command recovery separately from screen/theme/navigation data. Move presentation to frontend code and retire obsolete UI operations; preserve real application operation owners |
| Deployment discovery, `/health`, API descriptions, static assets | Shared host capability/health/schema publication and immutable asset mounts; health does not establish authorized API readiness |

Inventory uses of `transit-station-app` before removing any module: named
resources, named relational definitions, migration and ordinary application source
compilation are not equivalent to the retired screen/theme compiler. Update the
application grammar and fixtures only for the replaced interface definition path.

Preserve local and independently deployed remote inspection with explicit endpoint,
principal, origin, bind address and workspace scope through shared server
configuration. A denied/unavailable remote endpoint must not fall back to local
data. Migrate `server/Board.zig`, readiness/restart/shutdown probes, RuntimeRole,
build/Nix/release inventories, local/Compose/Kubernetes launchers and examples.
Remove the binary, basename dispatch, executable overrides and OCI/package output
only after these consumers use the shared server. Frontend and reusable browser
libraries may retain `transit-board*` names; this is not removal of the UI product.

## Verification and acceptance matrix

Use independent expected values and deliberately failing controls. Extend existing
test owners rather than copying their infrastructure; register any new tasks in
the runner inventory and owning Just files before citing them as executable gates.

| Boundary | Required proof and existing home |
| --- | --- |
| Dependency direction | Add recursive package/module negative controls that fail on transitive Station/legacy-query imports; compile the minimal serving/client composition and inspect installed process/operation evidence. Existing package/binding boundary checks are a starting point, not this proof. |
| Publication and migration | Extend [published resource tests](../../tests/catalog/tables/published_resources.py), [declarative browser](../../tests/interfaces/http/declarative_browser.py) and installation/migration proofs: exact revision conflict, missing dependency, unauthorized publication, failed activation, interrupted replacement and original-work recovery. |
| Parameters and finite outcomes | Extend SQL result/session and HTTP serving tests with empty/multi-batch results, lossless values, invalid parameters, buffered revocation, cancelled readers, allocation pressure, partial transport output and changed generations. Count authoritative mutations independently after lost replies. |
| Snapshot handoff | Race writes and complete multi-object commits around source acquisition, watcher registration and final disclosure. Validate eventual complete successors under the declared refresh profile and that intermediate events are never falsely claimed as captured. |
| Ordered delivery | Extend direct Stream and [reactive tests](../../tests/interfaces/reactive/reactive.py): slow reader, lost ACK, duplicate frames, server restart, competing attachments, cursor tampering, revoked source, schema change and unavailable history. Test both ephemeral closure and durable reattachment. |
| Transport/security | Extend HTTP/TLS, [authorization-serving](../../tests/interfaces/http/authorization_serving.py), reactive limits and description fixtures: Host/Origin/proxy policy, identity binding, request/body/frame budgets, idle authority checks, deadlines and joined receive/write cleanup. Preserve existing provider/exchange guarantees. |
| Browser and REPL | Real installed browser and terminal peers use one published application over HTTP/SSE/WebSocket and native/local bindings. Compare typed results and progress independently; test pause/close/reload/restart and ensure denied buffered data is not disclosed. |
| Board and artifacts | Extend [server-board-package](../../tests/interfaces/installation/server_board_package.py), Board browser/workbench/query proofs, launchers and release checks: only `transit` needed for Board, exact configured remote scope, revoked inspection grant, no private storage access, no Board-only backend for the second app. |
| Growth and resource isolation | Increase retained publications/closed subscriptions/history with fixed resident budgets; exhaust data slots while close/recovery controls progress. Measure actual heap/OS allocations and result/refresh cost; bounded arrays cannot become total-history limits. |

Every implementation PR runs the baseline fast and handbook gates. Shared contract
changes additionally run `just check contracts` and affected package/caller checks;
browser changes run `just transit-board::check` and affected real browser proofs.
Server, console, SQL or gateway changes run `just test server-sql-types` and
`nix develop .#ci-experience --command just test console-latency-gate`. Use an
isolated measurement window/CI host for the latency gate; functional passes or
measurements competing with another campaign cannot replace it.

Before pushing implementation or test-infrastructure changes, run affected
`just ci clean --lane NAME` gates against committed HEAD. Select from the current
[suite inventory](../../tests/runner/suite.json):

- P1–P2: `core` and `storage-query`, plus `interfaces-connectors` when extracting
  HTTP transport and `interfaces-sql` when adding executable SQL declarations.
- P3–P5: `storage-query`, `interfaces-sql` and `installation-ui`; add the owning
  connector/relational lanes when their adapters change.
- P6–P7: `installation-ui`, `browser`, `launchers`, affected `interfaces-*` lanes
  and SDK lanes for actual ABI/generated binding changes.
- P8: combine affected lanes and the installed acceptance matrix at one revision;
  full clean qualification remains the integration/release gate.

Several serving/reactive proofs are registered as external tasks rather than
members of those clean lanes. Run the affected `just test serving`,
`serving-tls`, `serving-capacity`, `serving-lifetimes`, `serving-growth`, `reactive`,
`reactive-limits`, `reactive-client`, `reactive-refresh` and
`reactive-descriptions` tasks explicitly, plus affected placement/Compose/reference
proofs. A lane pass cannot stand in for an omitted external test. Preserve
recorded failures, uncertain writes and current bounds when adapting fixtures.

Record source, command, profile, original-operation evidence and limits in the
qualification ledger. Promote implemented semantics into Serving, Reactive,
Applications, caller, OpenAPI/AsyncAPI and Board references with each public
cutover. A documentation check or generated schema establishes no runtime support.

## Effort, dependencies and review focus

Budget approximately **14–22 review units and 16–25 engineer-weeks of direct
work**, with roughly 25% integration contingency (**20–32 engineer-weeks** total).
These are planning estimates for the complete migration and qualification,
not elapsed-time or agent-throughput promises. Contract/dependency work is about
3–5 weeks; publication/finite APIs 4–6; refresh/retained subscriptions 4–6;
client/Board migration and final qualification 5–8. Re-estimate after P0's consumer
inventory and the first installed vertical proof.

The largest uncertainties are preserving existing accepted work across the v1
cutover, extracting HTTP/query metadata without a new dependency cycle, complete
Stream retention/checkpoint integration, and the breadth of Board/SDK consumers.
Do not hide these behind an early executable rename. M6/M8/M9/M12 work can supply
shared pieces, but this milestone remains accountable for the installed serving
journey. M14/M29/M30/M34 extensions cannot silently expand its first required profile.

Review D1–D6, the three initial delivery profiles, the P7 cutover boundary and the
Board route map before implementation. Exact SQL spelling, persisted field
layouts, cursor encoding, quotas and native admission mapping are P0 contract
deliverables; the recommended architecture and acceptance scope above do not
depend on inventing those details in advance.
