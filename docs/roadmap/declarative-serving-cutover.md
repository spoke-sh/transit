# Declarative serving: contract decisions and migration inventory

[Implementation plan](declarative-serving-implementation.md) · P0/P1 review · 2026-11-15

This record settles the proposed ownership and migration approach for the first
implementation review. It is not a replacement wire definition or executable SQL
reference. Current [serving](../../contracts/SERVING_V1.md),
[reactive](../../contracts/REACTIVE_V1.md), [browser](../../contracts/BROWSER_V1.md),
[application](../../contracts/APPLICATION_V1.md) and
[publication](../../contracts/PUBLISHED_RESOURCE_V1.md) contracts remain in force
until P7's coordinated consumer cutover. The inventory was audited at `424cc32e8`.

## Decisions and contract owners

### Publication, operations and authorization

Use one catalog publication, with immutable revisions and conditional replacement.
Its stable identity consists of catalog scope, branch and resource identity; route,
canonical name, source path, host instance and Station PID are not that identity.
Keep the PublishedResource definition and schema/dependency commitments. Extend its
operation binding through BrowserAdministration's ordinary typed owner, with SQL
lowering to that same owner. No independent gateway definition registry is allowed.

A publication names operations with four explicit kinds:

| Kind | Bound owner | Initial admission rule |
| --- | --- | --- |
| Finite query | Direct query execution and shared SQL result readers | Compiled single-Table projection/filter, declared typed parameters, exact source definition and result schema |
| Command | Native database mutation/transaction and saved-work recovery | Typed Table conditional update; explicit expected row revision and original client token |
| Inspection | Existing public catalog, managed-computation or native inspection operation | Fixed typed operation and scoped arguments; never arbitrary callback registration or raw storage access |
| Subscription | Catalog subscription control plus direct source/history owner | Explicit latest-complete-snapshot or ordered-Stream profile; parameter changes establish a new generation |

Publication validation, acceptance, physical activation and withdrawal are separate.
An unhosted declaration remains inspectable. Route collisions and unsupported
source/type/profile combinations reject activation with attributable reasons.
Replacement does not relabel accepted commands, result readers or retained cursors.

The publication declares its audience, transports and resource budgets; it creates
no privileges. Protected operations require the current authenticated subject's
native source rights. Publisher-backed public reads explicitly use the published
read authority and expose only the fixed query's permitted output. They cannot
inherit write, administrative or arbitrary SQL capabilities. Commands in the first
profile require an authenticated caller. Native/local entry points use the same
owner without HTTP loopback or a private Board signer.

Browser provider/identity/session bindings remain their existing authority. The
shared API consumes the authenticated identity; it does not add an identity store.
Host/Origin, trusted TLS termination, CSRF policy and native authorization stay
separate checks. Recheck current publication and source authority after buffering,
including schema, counts, progress and empty results. Cleanup may release already
owned resources after read revocation without disclosing data or renewing a lease.

### Original command acceptance and recovery

Use [DirectClientToken](../../packages/zig/transit-catalog/src/DirectClientToken.zig)
for the original client-token binding to saved native work. The account scope
includes stable publication and operation identity. Revision, parameters and the
selected target belong in the committed intent, not in a new deduplication account:
changing them under the same token must conflict. Credential/role rotation cannot
create a new identity for a previously accepted command.

The owner freezes the exact public operation, publication/source definitions,
parameter values, expected mutation basis and native saved-work reference before
dispatch. A committed binding is admission of original work, not completion of
its data mutation. Recovery reads that reference and settles the same work; neither
HTTP retries nor a gateway crash may compile/reissue a new mutation under a fresh
token. Conflicting reuse returns original-versus-supplied evidence under current
authorization. A missing response remains uncertain, never an inferred rejection.

Publication fencing and native admission must be coordinated by the catalog/data
owners. Existing token `Fence`/`Lease` records provide a useful mechanism but
currently require the same principal/connection. A caller cannot borrow a
publisher's fence as if it granted caller rights. P2/P3 must add the explicit
authorized publication check at the native boundary and qualify its race with
withdrawal. A gateway-side read followed by an unfenced write does not satisfy
this decision. Reuse the native saved-work state machine and its catalog ordering;
do not add a second gateway journal or require an actor/Queue for a Table update.

The first tickets update and event append share the qualified Table/Stream
transaction. A common transaction decision establishes their atomicity; sequential
HTTP calls cannot. External effects retain recorded intent, policy and uncertain
outcome owners above this base. Cancellation of observation never rolls back a
command. Preserve the existing command outcome even if result delivery fails.

### Result and subscription profiles

Finite results reuse [SQL_RESULTS_V1](../../contracts/SQL_RESULTS_V1.md): one schema,
typed rows, observation basis, authoritative terminal outcome and bounded cleanup.
Physical batches and EOF cannot manufacture a complete result. Do not collect a
whole unbounded result to make it appear atomic to a client.

| Profile | Progress and reconnect | Snapshot acquisition rule |
| --- | --- | --- |
| Latest complete snapshot | A generation and complete result revision; coalescing allowed. Reconnect may report a clearly identified new basis. | Acquire an exact finite result and check source progress after attaching observation. A racing write schedules a successor; no stale result is labeled current. |
| Ordered Stream | Original durable subscription, exact source definition, attachment generation and processed frontier. Replay may repeat identifiable events after a lost ACK. | Start at an explicit retained position. An optional snapshot must come with a source-owned handoff cut; a current Table scan cannot invent a Stream starting position. |
| Net relation changes | Contract distinguishes net changes from source events. Activation refuses until the computation owner supplies qualified revisions/deltas. | Requires that owner's complete revision and handoff evidence; it is not synthesized by snapshot comparison while claiming every event. |

Maintain independent partition positions unless a source owner proves common order.
ACK advances a verified contiguous processed frontier under the current attachment
generation; it does not assert exactly-once client effects. An ordered cursor binds
subscription, generation, publication/source definitions and partition progress.
Its integrity does not grant read rights. SSE Last-Event-ID and WebSocket frames
carry the same progress, without their own checkpoint store.

Separate ephemeral interests from explicitly durable subscriptions. Durable control
records belong to the catalog; retained coverage belongs to the Stream/history
owner. Attachment leases fence competing connections and bound live work. They do
not authorize history expiry. Slow-consumer limits, pin ownership and eventual
cleanup must be explicit. Missing retained coverage produces a typed gap/refusal;
resume never silently resets ordered delivery to a fresh snapshot.

### SQL and schema cutover

SQL publication lifecycle operations must lower to the typed owner for validate,
create, conditional replace, inspect and withdraw. Typed and SQL callers must
produce the same immutable binding and original-operation recovery reference.
Administrative declarations require explicit submission. Source compilation is
offline and adds no publication authority. Reference grammar/parser acceptance is
not sufficient evidence to advertise a command.

P2 must add the executable grammar and emitted fixtures together with that owner;
the first review intentionally publishes no guessed SQL spelling or wire tag.
The exact owning type definitions will generate the replacement OpenAPI, AsyncAPI
and client validators. The following independent cases are required before P0's
contract work is considered complete:

- Same client token with changed publication revision/parameters conflicts;
  original intent and outcome remain addressable after credential replacement.
- Unsupported operators, parameter domains and codecs reject before execution;
  wide integers/decimals, NULL and other cell states cannot be conflated.
- Empty, multi-batch and interrupted results have distinct terminal evidence.
- A parameter generation change cannot relabel a late result or submit a command.
- A source changing `A → B → A` may coalesce snapshots but must preserve both
  ordered events when that profile is selected.
- Lost ACK and competing attachment preserve one processed frontier; withdrawal,
  changed definitions, revoked rights and unavailable history refuse disclosure.
- Source-language output and direct SQL yield the same typed declaration; display
  declarations, arbitrary callbacks and an implicit Station ingress reject.

These cases are a contract-fixture checklist, not executable proof. P0 remains
open for the generated definitions and independent fixtures; this review fixes
their ownership and required behavior without publishing a competing current v1.

## Endpoint and consumer migration inventory

The table covers the route families in the current serving, browser and Board
dispatchers. Operation-level schemas and consumers migrate with their family;
an unchanged URL does not establish definition compatibility.

| Current routes/surface | Current consumers | Destination and disposition |
| --- | --- | --- |
| `/serving/v1/command`, `/serving/v1/read` | Serving callers, finite examples and native/HTTP proofs | Shared typed command/status/result/disposition owners. Optional Station invocation adapters preserve their original call and outcome; ordinary database commands acquire no ingress PID. |
| `/reactive/v1/{discovery,control,challenge,events,read,websocket,openapi.json,asyncapi.json}` | Reactive example, TS client, signed native callers and transport/security proofs | One shared publication/subscription owner and generated transport descriptions. Replace service/PID identities and stored control formats in the coordinated cutover. |
| `/reactive/v1/client`, `/reactive/v1/client/control` | Private reactive client host and browser example | Migrate consumers to shared authenticated publication consumption. Remove the required private signing proxy and its superseded schema/routes with them. |
| `/auth/{providers,session,logout}`, `/auth/{provider}/{login,callback}` | Declarative browser example and provider integration proofs | Retain provider/session authorization and original challenge claims. Hosting consumes the shared neutral HTTP transport; any stored interpretation changes need explicit migration. |
| `/published/{name}/{snapshot,watch}` | Declarative browser clients and snapshot/watch proofs | Bind through the unified publication owner. Preserve public versus bound-identity audience and migrate current snapshot consumers before changing their profile. |
| Board `/api/v1/{catalog,sql-read,workbook,computations}` | Board workbench and computation browser proofs | Public DirectCatalogRead/ReadWorkspace/WorkbookWorkspace/ManagedInspection operations with existing scopes and typed results. |
| Board `/api/v1/{query,relational,application}` | Captured/relational/application workspaces and recovery views | Qualified query/application owners through optional adapters; preserve exact submitted identity, result basis and recovery. Classify real application operations separately from UI definitions. |
| Board `/api/v1/{capabilities,storage,atlas,processes}`, `/processes/{pid}/{mailbox,outbox,effects,payloads,history,journey,associations}` under the API prefix | Inspection/atlas views and native read proofs | Public bounded inspection operations. Keep current inspection/data grants distinct and source evidence intact. Framework interpretation stays above generic serving. |
| Board `/api/v1/resources`, `/resources/{resource}/{entries,participation,records,http/{exchange},grpc/{exchange},documents/{document}}` under the API prefix, and object detail routes | Resource and connector metadata views | Public authorized reads and pure projections. No provider/raw storage path; unknown application values remain opaque. |
| Board `/api/v1/interface` and compiled screen/theme/navigation definitions | Board frontend and interface compiler examples | Move presentation to ordinary frontend code; retire UI-only declarations and compiler branches. Retain named resource/relational definitions and real migration/compiler owners. |
| `/health`, Board `/api/v1/deployment`, `/openapi/v1.json`, immutable assets and frontend routes | Server readiness, launchers, browsers and package proofs | Shared listener/assets/capability reporting. Health is not authorized inspection readiness. Preserve remote scope and prohibit fallback to local data after denial. |

Audit source owners:
[signed dispatch](../../packages/zig/transit-serving-http/src/root.zig),
[reactive routes](../../packages/zig/transit-serving-http/src/ReactiveTransport.zig),
[private host](../../packages/zig/transit-serving-http/src/PrivateClient.zig),
[browser routes](../../packages/zig/transit-serving-http/src/BrowserRequest.zig),
[Board routing and parsers](../../apps/transit-board/main.zig).
The [implementation plan's Board map](declarative-serving-implementation.md#board-route-migration-map)
owns the corresponding executable, configuration, build and launcher migration.

## Retained-record preflight and disposition

An upgrade must inventory the actual installation through current public read
owners before selecting a cutover. Directory presence, package names and exports
are not proof that accepted work is settled. These are required preflight
dispositions, not an implemented upgrade utility:

| Retained family | Required disposition |
| --- | --- |
| `SV1` config/binding revisions and per-principal policies (`c/b/v/p` keys) | Explicitly recreate publication through its new owner using an audited mapping of stable source identities and rights; service numbers/PIDs cannot become new rights implicitly. Preserve original definitions for recovery evidence. |
| `SV1` operations, active slots and rejected inputs (`o/a/e`) | Settle each admitted original native/Station identity or migrate through a verified preservation path. Pending, uncertain, timed-out and failed-delivery records cannot be counted as successful commands or resubmitted as new work. Retained terminal evidence must remain inspectable under the supported migration. |
| Reactive source revisions, sessions/subscriptions, active slots and observer time (`W/V/S/L/T`) | Reconcile original controls, close/fence attachments and explicitly dispose or migrate each interest. Preserve recorded source position; old int64 invalidation cursors cannot become durable every-event cursors. Never reset uncertainty by recreating the service. |
| Browser records: provider, secret, binding, publication, identity, challenge and session | Retain unchanged provider/identity semantics and exact DirectClientToken history. Publication conversion is conditional on its original revision. A claimed provider challenge cannot be replayed as a fresh external exchange; unresolved claims block destructive replacement. |
| PublishedResource descriptors and named query/resource definitions | Preserve object/definition/schema/dependency identity and grants. Refuse unsupported conversions; presentation metadata does not grant runtime authority. |
| Station application/interface definitions, migrations and saved publication plans | Separate screen/theme-only data from named resources, relational definitions and migration receipts. Remove UI consumers first; preserve accepted migration/publication outcomes. Do not delete the entire station-app package by name. |
| Captured query, Exchange/HTTP/gRPC results and saved client requests | Keep original captures, retained source/result references and definition identity. Use optional domain adapters or verified migration; exporting bytes alone does not resolve accepted work or authorize replay. |
| Local worksheet/workbook state and active finite result readers | Explicitly close/release live readers during drain. Session-local editing state is not a durable computation. Do not splice a newly executed query into an earlier result prefix. |

Record original definition, scope, identity, current outcome, dependent retained
references and chosen migration in the preflight evidence. Any unclassified record,
unreadable required history, unknown accepted outcome or absent preservation proof
blocks the destructive cutover. There is no fallback decoder, implicit empty store
or compatibility alias. Keep the old installation available for original-outcome
resolution until the explicit migration/drain prerequisite is satisfied.

## First extraction and remaining dependency work

`transit-http` now owns request construction, framing, single-attempt TLS transport
and borrowed response callbacks. Its only direct package dependency is
`transit-tls`. Station's HTTP adapter owns durable record encoding and admission
diagnostic projection. Browser/provider and application-effect callers use the
neutral package directly. The existing HTTP terminal wire bytes and capture order
are preserved, so this extraction changes no stored definition identifier.

The source dependency guard covers `transit-http` and `transit-http-server`.
Standalone compilation and independent real HTTP/TLS peers exercise the neutral
composition separately from the Station adapter. This is the small P1 extraction
specified for the first review, not the final minimal serving host proof.

Remaining P1 work must remove Station and legacy query dependencies from serving
semantics, separate optional adapters, and compile the complete neutral
serving/subscription/client graph. Extend the guard to those owners when their
cutover is real. P2–P8 still own executable publication SQL, installed browser/REPL
APIs, durable subscriptions, consumer migration, Board retirement and full
qualification. Milestone 13 is In Progress, not complete.
