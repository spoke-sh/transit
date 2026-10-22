# Glossary

Use these names consistently across applications, commands and documentation.
[Choose an interface](../guides/choose-interface.md) for its implemented profile;
a term in this glossary alone is not a compatibility claim.

Shared vocabulary for users, developers and agents. Official names are
established; definitions distinguish implemented profiles from unsupported
concepts. Detailed contracts and compatibility requirements live with their owners.

## Names and roles

| Term | Meaning |
| --- | --- |
| Transit | The reusable streaming runtime subsystem: the agentic streaming kernel, supporting services, clients, storage/runtime adapters, Board inspection surface, and Station framework and Fuze engine. Its foundational execution protocol is enforced by durable message sequences. See [Processes](processes.md). |
| Board | Transit's operator/agent inspection surface: a static UI and OpenAPI service hosted by the Zig `transit-board` executable. Its views derive from authorized Transit evidence; it grants no execution authority. See [Board](../guides/inspect-board.md). |
| Station | Transit's OTP-inspired framework above the kernel, providing GenServer behaviors, supervision, registries, and composition. Its artifacts use the `transit-station*` name family. See [Station](station.md). |
| Fuze | Transit's Zig-native query and compute engine across KV, Table and Document state, inspired by DataFusion and Acero. Its artifact family is `transit-fuze*`; it runs outside kernel authority. See [Fuze queries](queries.md). |
| Agentic | The class of workloads the system is intended to support. It does not place reasoning loops, goals, or agent/task delegation in the kernel. |
| Ursula | The selected durable stream storage and transport implementation. See [Storage](storage.md). |
| ursula-zig | The upstream Zig client used by Transit's Ursula adapter. It handles transport/protocol operations; Transit defines execution semantics. |
| Agent Substrate | The recommended sandbox execution target on Kubernetes. It manages runtime infrastructure and lifecycle; Transit's durable history governs process execution. See [Deployment](deployment.md). |
| Launcher | Development tooling that provisions and runs a concrete environment. Local, Compose, and reference launchers compose services; they do not replace Transit authority or Station supervision. See the [launcher guide](../../launchers/README.md). |

Use **Transit** for the streaming runtime and its deployment artifacts, including
the [Helm chart](../../charts/transit/README.md) at `charts/transit`. Calling Transit the
**kernel** describes its foundational protocol role; `transit-core` is specifically
the deterministic kernel library. **Board** is the **inspection surface** and
**Station** the **framework** above the kernel. **Fuze** is the **query and compute
engine**; all belong to Transit. Use `transit-board*`, `transit-station*` and
`transit-fuze*` for artifacts, while keeping Board, Station and Fuze in prose.
Short deployment roles such as `board` and `node`
identify instances of those artifacts. The kernel implementation library lives
in `packages/zig/transit-core` and exports the `transit_core` Zig module.
`transit-protocol` owns public wire
contracts; `transit-client` is the application entry point. The Station
library is `transit-station` and exports `transit_station`; the Fuze
library is `transit-fuze` and exports `transit_fuze`. See the
[component directory](components.md) for implemented packages.

"Durable streams" or "streaming substrate" refers to message transport and
persistence. **Agent Substrate** names the external execution project. Keep the
distinction explicit when both appear in the same discussion.

The `transit` executable owns local server and application workflows;
`transit-admin` exposes low-level signed native operations. TypeScript workspaces
use the `@transit/` scope. Protocol and stored identity changes follow the
[hard-cutover policy](versioning.md), including a new shared definition identifier.

## Processes, actors, and execution

| Term | Meaning |
| --- | --- |
| Process | Transit's logical execution primitive: identity, mailbox, committed control state, ordered sequence, and lifecycle. Application state can be inline or associated through resources, according to the selected profile. It is independent of an OS process, worker, or sandbox. |
| Initialization barrier | Process control state that prevents handler execution until declared required associations exist and initialization is explicitly completed. |
| PID | Opaque, durably scoped process identity. It survives eligible worker recovery, suspension, and migration; logical termination or process expiry retires it permanently. |
| Actor | A programming-model participant implemented by a Transit process. It adds no separate identity layer. Use **Substrate Actor** when referring to the external runtime resource. |
| GenServer | A Station behavior running in a Transit process, providing sequential message handling, state associations, and request/reply under that process's PID. |
| Mailbox | The process's ordered view of durably admitted input messages. Admission and processing progress are distinct. |
| Input origin | Authority-derived evidence identifying an external principal, source-process output or effect attempt; not a sender claim inside application bytes. |
| Unbounded mailbox | A logically unbounded durable backlog that can outlive a worker and exceed its RAM. Read windows, storage capacity, and admission still have explicit limits. |
| Process sequence | The process's ordered protocol history, including admitted messages and execution/lifecycle records. It establishes no global order across processes. |
| Admission | Durable acceptance of a message's identity and place in the target PID's mailbox. It does not mean handling or an external effect has completed. |
| Turn | Handling one admitted input against an explicit committed state/read basis and proposing state changes, outgoing messages, and effect intents. |
| Application state | Caller-defined data with opaque business meaning. Inline-state profiles record a value; resource-backed profiles use durable associations. Protocol acceptance does not prove computation correct. |
| State revision | In the inline-state profile, the process's committed state version used as a turn precondition; it starts at zero and advances to the successful turn position. Distinct from ownership generation and resource revisions. |
| Turn commit | The durable boundary that makes a turn's state transition and pending outputs authoritative together. |
| Settlement | Completion of specifically authorized work within recorded finite limits after the cutoff for starting new work; it cannot grant more work or revive a retired PID. |
| Worker | A replaceable executor that hosts process or connector work. A worker is distinct from the logical process it executes. |
| Activation | A period of process execution under validated ownership on a worker. Recovery or resumption creates a fresh activation of the same PID. |
| Activation reference | Conceptually `(PID, ownership_generation)`, identifying an execution incarnation. The reference itself grants no authority. |
| Ownership generation | A monotonically advancing generation for a PID's execution ownership. Fencing must reject work from superseded owners. |
| Fencing | Enforced rejection of stale ownership at commit and dispatch authorization boundaries. Observing a timeout or assigning a new worker alone is insufficient; an already-authorized attempt may still be in flight. |
| Suspension | Pausing execution while preserving the PID and its recovery basis within the accepted process/mailbox lifetime. |
| Termination | An authorized, irreversible end to a logical process. It retires the PID and applies explicit policy to pending work; it is distinct from worker loss. |
| Supervisor | A Station process whose durable state and policy govern child PIDs, lifecycle intent, and recovery or replacement. |

See [Transit](processes.md), [Station](station.md), and [Streams](streams.md) for
ordering, ownership, and behavior requirements.

## State resources and associations

[State](state.md) defines native v1 resources and associations.
Tables and Documents build on that resource boundary. General workload
ownership must not be inferred from a reference; inline bytes or payload IDs
alone do not create an association or lifetime dependency.

| Term | Meaning |
| --- | --- |
| Process control state | Durable protocol facts governing lifecycle, ownership, mailbox progress, associations, and outstanding obligations; distinct from application values |
| State resource | Realm-scoped durable identity with a kind/version, committed revisions, data, and explicit lifecycle policy |
| State association | A versioned named relationship from a PID to an exact resource, declaring intended access and whether recovery requires it; grants neither permission nor lifetime ownership |
| Required state association | A dependency whose availability constrains the PID's recovery window; expiry is terminal under the first resource profile |
| Lifetime owner | The logical PID or explicitly independent/workload scope whose policy governs resource retirement; not necessarily its writer or reader |
| Writer PID | The process whose fenced turns serialize mutations to a resource; execution ownership and resource grants are still required |
| Resource revision | An immutable committed state version used for reads and mutation preconditions, independent of PID progress and activation generation |
| Read basis | The exact resource identities/revisions observed by a turn and the evidence supporting its recovery/replay contract |
| KV | The initial versioned resource interface for opaque key/value lookup, put, delete, and bounded enumeration |
| Table | A Station typed keyspace within a state resource, with declared schema/keys and Arrow query results; mutations retain one resource's transaction boundary |
| Document | A [Station state abstraction](documents.md) for nested structured values and collaborative text, with versioned change/merge rules; Fuze queries its accepted materialized revisions, not speculative edits |
| Table transaction | A bounded mutation batch committed in one resource/turn; does not extend across separate resources or writer PIDs |
| Arrow record batch | A finite set of typed column arrays with one schema, used for tabular interchange and query computation; it is not a durable commit |
| Arrow IPC stream | Serialized schema and record batches for cross-process interchange; durability, result framing and recovery remain Station/Transit responsibilities |
| Query result | A versioned observation of an exact resource/schema revision, with identity, coverage, completion and lifetime; a partial result is not successful completion |
| Materialized index | A rebuildable lookup structure derived from committed resource history/checkpoints; not a second state authority |
| Working set | Pages, buffers and active operations resident in memory; its budget is independent of the total durable collection |
| Cardinality limit | A limit on total entries or identities; distinguish an explicit deployment quota from a temporary compiled catalog ceiling |
| Operation budget | A bound on one request, atomic proposal, scan or result batch; does not by itself cap the whole resource |
| Staged data | Durably prepared data that remains unpublished until referenced by an accepted commit decision |

See [Tables](tables.md) for Table operations, materialization and
transaction limits, [Documents](documents.md) for Documents and
[unified queries](queries.md) for unified querying.
A finite Arrow batch stream and a durable Transit stream
have different responsibilities.

## Arrow execution and interchange

These interfaces live above the kernel; their owning contracts distinguish
implemented profiles from unsupported capabilities. [Fuze](queries.md) owns query
execution; [Arrow](arrow.md) owns interchange and remote query interfaces;
[SQL](sql.md) distinguishes executable syntax from reference grammar.

| Term | Meaning |
| --- | --- |
| Logical query plan | Versioned, typed query operations independent of entity storage, SQL spelling, execution scheduling or transport |
| Relational surface | SQL spelling over shared typed operations. Finite SELECT compiles to Fuze; broader administrative DDL/DML remains grammar-only unless its separate owner qualifies execution |
| Dataframe surface | A typed per-language builder over the shared logical plan. A complete dataframe API is not supported; callers use the existing typed plans |
| System namespace | Relational addressing of non-data sources such as connector attempts or transport state. This is not supported SQL; Board inspection uses its public API |
| Query source adapter | Supplies an authorized versioned state view, schema/capabilities and bounded batches to Fuze; distinct from a durable storage backend |
| Physical operator | A bounded local scan/transform/aggregate/sink in Fuze; not a Transit PID or durable commit |
| Arrow C Data / C Stream | Native array and batch-stream ownership interfaces for in-process interoperability; distinct from the Transit/Station command ABI |
| Flight RPC | Remote Arrow discovery/transfer protocol; a live connection and a Flight ticket do not supply durable mailbox or execution authority |
| Flight SQL | SQL query/metadata protocol over Flight; the server still defines its supported SQL and transaction capabilities |
| ADBC | Arrow-oriented database client/driver API; finite Table access through the Flight SQL driver, separate from general Transit clients |
| Flight ticket | Opaque reference to a query result; our gateway must bind it to exact evidence, current read permission and availability, not treat possession as a grant |
| Acero | Apache Arrow's C++ execution engine, used as design inspiration for bounded batch execution; Transit implements its engine in Zig |
| DataFusion | Apache's extensible Rust query engine, used as design inspiration for Fuze's sources, expressions, logical/physical plans and optimization; not an embedded dependency |

## Identity and authority

| Term | Meaning |
| --- | --- |
| Authentication | Verifying the caller's credential and binding its identity to an operation through a trusted channel. |
| Principal | An issuer-qualified human, service, or logical workload identity. It is distinct from a PID, worker, or credential. |
| Security realm | An explicit administrative authority for principals, grants, and resource access; distinct from naming, storage, and provider namespaces. |
| Authorization | Deciding whether a principal may perform an action on a scoped resource under current policy. |
| Grant | Scoped permission with subject, actions/resources, validity, and policy revision. It does not replace activation ownership or process lifetime. |
| Authority delegation | Explicit granting of bounded authority, constrained by the delegator's grant; receiving a message does not implicitly delegate privileges. Distinct from application-level agent/task delegation. |
| Revocation | A durable policy operation ending authority at a defined boundary. It does not undo accepted history or prove a remote attempt was cancelled. |
| Trusted computing base | Components whose correct operation is assumed for the stated guarantees, including protocol authorities and privileged effect/storage/runtime paths. |

See [Security](security.md) for enforcement placement, historical decisions,
current access checks, and provider boundaries.

## Names and registries

| Term | Meaning |
| --- | --- |
| Namespace | An explicit scope for registered names, with defined authority, visibility, and lifetime. It is not implicitly a host, Kubernetes namespace, or Substrate atespace. |
| Registered name | An optional `(namespace, name)` alias to a PID. Rebinding it does not change the old process's identity or redirect its accepted work. |
| Registry | A Station service whose durable protocol history determines name-to-PID bindings. Lookup caches are derived views. |
| Registry revision | A version of a name binding used for conditional changes and recorded resolution. It is distinct from execution ownership and runtime binding revisions. |

See [Station registries](station.md) for local and
cluster scopes, conflict handling, and stable message destinations.

## Messages, storage, and recovery

| Term | Meaning |
| --- | --- |
| Message identity | A stable identifier preserved across retries. Reusing it with conflicting content is a protocol conflict. |
| Causation | The relationship identifying which input, turn, or effect caused a record. |
| Correlation | An identity joining related work, such as a request and its reply. It does not itself establish order or authority. |
| Durable stream | Persistent ordered records with resumable reading under a documented durability/retention contract. |
| Immutable payload | A logical storage object with a fixed byte body, content hash and unreused identity. Native publication/deletion records preserve its identity; Station Publication and Exchange define their own dependency and lifetime boundaries. |
| Cursor | Ursula's opaque cache/collapse token, independent of the offset or record position that selects a read location. It is not a Transit message identity or execution position. |
| Authoritative history | Validated durable records, including checkpoints replacing reclaimed prefixes, that determine accepted work, progress, ownership, lifetime, and effect eligibility. |
| Outbox | Committed pending outputs awaiting delivery. Retried delivery preserves identity and the destination deduplicates admission. |
| Delivery courier | Independently restartable service that advances committed outboxes through scoped Transit commands; durable progress stays in the kernel history. |
| Checkpoint | A durable record of a validated history prefix, state/progress, versions, and required dependencies. It becomes essential recovery evidence if that prefix is reclaimed. |
| Process snapshot | Saved process state tied to its PID, history position, and versions. It may supply checkpoint state; state alone does not prove complete recovery coverage. |
| Sandbox snapshot | Runtime memory/filesystem capture. Restoring it does not restore ownership or supersede newer protocol history. |
| Replay | Reconstructing or inspecting committed execution within retained history using recorded outcomes, without redispatching external effects. |
| Recovery | Restoring valid state and authority, then resuming eligible live work within its lifetime and delivery/attempt contracts. |
| Producer epoch | Ursula's producer-deduplication generation. It is distinct from a Transit ownership generation; their mapping must be proved. |

See [Streams](streams.md), [Processes](processes.md), and [Storage](storage.md).

## Retention and lifetime

| Term | Meaning |
| --- | --- |
| Retention contract | The application's recorded policy for lifetime, available history, cleanup, and expiry outcomes. Defaults are unlimited; finite semantics require opt-in. |
| Process lifetime | The interval in which a PID may start work, followed by any explicit bounded settlement period before final retirement. |
| Work cutoff | The boundary after which fresh work cannot be authorized; specifically preauthorized settlement can remain eligible. |
| Settlement window | The finite interval and permissions for completing identified work after its work cutoff, with required recovery resources retained. |
| Mailbox lifetime | Availability of the logical mailbox and required pending inputs; it constrains process suspension and activation. |
| Resumption bound | The latest permitted resumption boundary given process policy and required resource lifetimes. It does not guarantee scheduling before that time. |
| Process expiry | Terminal retirement when the opted-in process/mailbox recovery lifetime ends. Activation permanently fails for that PID. |
| Recovery basis | Validated durable state, retained history, pending work, ownership, and control evidence sufficient to recover an eligible process. |
| Replay horizon | The retained historical interval available for replay/inspection; it can be shorter than process lifetime. |
| Cleanup target | A threshold after which safe removal is eligible; dependencies may delay cleanup. |
| Hard logical expiry | A deadline ending declared availability or execution rights, regardless of whether bytes have been physically reclaimed. |
| Workload-scoped resource | A resource owned by a logical PID, session, or workload, surviving worker replacement and retired under its owner's lifecycle policy. |
| Compaction | Replacement of history by a smaller representation preserving declared semantics, such as an execution checkpoint or latest state by key. |
| Tombstone | An ordered/versioned logical deletion marker. It can outlive the value to prevent resurrection before eventual reclamation. |
| Consumer watermark | Recorded reader progress used to evaluate retention dependencies; it grants no implicit right to retain data indefinitely. |
| Retention pin | An explicit, scoped dependency delaying eligible cleanup, with an owner and release/deadline policy. It cannot silently extend hard lifetime. |
| Working catalog | Bounded authoritative materialization of processes, effects, outputs and resources. Explicit collection can release eligible slots; it never reuses durable identities. |
| Catalog collection | Recorded, application-opted-in removal of eligible completed catalog entries. Distinct from journal trim, payload deletion and logical expiry. |
| Garbage collection | Background physical reclamation after validated logical trim/retirement decisions and dependency resolution. |
| Storage quota | A capacity limit enforced independently of retention age, with explicit admission/backpressure behavior. |
| Logical stream | A stable protocol stream whose ordering and retention contract are independent of its storage provider. |
| Physical segment | An adapter-managed portion of a logical stream that can be rotated or reclaimed without changing logical identity or sequence positions. |

See [Retention](retention.md) for lifetime interaction, policy changes,
checkpoint authority, and reclamation guarantees.

## Transports, effects and connectors

| Term | Meaning |
| --- | --- |
| Transport | Byte/stream carriage with connection lifecycle, multiplexing and wire flow control but no effect-shaped contract of its own: TCP, QUIC, SCTP, and HTTP/2's session layer as gRPC uses it. Never a connector; nothing to capture, retry or reconcile until a connector's protocol is layered on it. |
| Effect | Work at an external or nondeterministic boundary, requested through a committed intent and observed through recorded outcomes. |
| Capability | Scoped authority to request or perform particular operations, enforced by the protocol and runtime boundaries. |
| Connector | Library and executor logic for a particular effect family, including its capture, retry, and reconciliation semantics. Built on one transport; HTTP, gRPC and the selected outbound Flight profile are implemented. Other effect families are not supplied by this connector set. |
| Serving layer | Inbound boundary over public Transit/Station operations: scoped service bindings, admission and bounded disclosure/recovery. HTTP/reactive and Flight adapters have separate interfaces; distinct from outbound connectors. |
| Service binding | Versioned, realm-scoped binding of explicit operations, targets, codecs, policies and budgets through a serving protocol. Naming or publication grants no access. |
| HTTP route | A method/path-template binding to a published operation and codec revision; transport presentation rather than a new application authority. |
| Reactive API | Implemented Table interaction contract with SSE/WebSocket bindings, shared typed commands/events, session/subscription lifecycle and generated API descriptions. |
| API session | Scoped logical reactive interaction with a generation and finite live-work lease; distinct from its disposable connection, subscriptions and accepted operation identities. |
| Watch | Table subscription to authorized source/projection change progress, with identity, generation, lease, budgets and resume semantics; not a durable mailbox or continuous query. |
| Follow changes | Implemented bounded live-view mode that uses notifications to request new exact snapshots. Coalesced invalidations do not claim every intermediate state or incremental query maintenance. |
| Integration | A provider-specific library built on one connector, adding that provider's schema/pagination/auth-flow knowledge without owning a new durability contract; it reuses the connector's attempt/reconciliation machinery rather than inventing its own. |
| Fetch worker | A connector executor authorized to issue HTTP requests and record response data and attempt metadata. |
| gRPC connector worker | Trusted executor of committed, authorized RPC sends with durable captures, finite streaming budgets and bounded reconciliation. |
| Attempt | One authorized execution attempt of an effect, with its own identity. Retries and redirects remain individually observable. |
| Dispatch authorization | The durable decision permitting one external attempt after current checks. From that point it may be in flight even if its worker has not yet sent. |
| Exchange stream group | A Transit manifest and related durable records/streams representing one external exchange, its attempts, messages and metadata. HTTP and gRPC have distinct framing; neither implies a native Ursula group or multi-stream transaction. |
| RPC half-close | The caller ends its request-message direction while the response direction can continue; not terminal success or a durable outcome. |
| Transcript | The recorded request/response data and observations, with explicit capture boundaries and omissions. |
| Interpolation | Rendering request variables from recorded bindings or authorized secret references, with field-specific encoding rules. |
| Secret reference | A credential binding/version resolved by an authorized executor, allowing transcripts to identify substitutions without storing the secret value. |
| Unknown outcome | An attempt whose remote result cannot be established from recorded evidence, such as a worker crash after sending. It requires connector recovery policy. |
| Reconciliation | Connector work to establish an attempt's outcome using its external-system contract; it is not permission to repeat the original effect. |
| Reconciliation lifetime | The accepted window and work budget for reconciliation. Recovery cannot renew it implicitly. |
| Reconciliation closure | The irreversible end of an attempt's result-acceptance path. Late submissions are rejected; historical receipts remain receipts. |
| Closed with outcome unknown | A terminal local disposition ending reconciliation without claiming remote success, failure, or cancellation. |
| Transport flow control | Wire-pressure regulation owned by the selected transport (TCP's window, QUIC's limits, HTTP/2's frame credit). Never evidence of durable application admission by itself. |
| Application admission credit | Transit's own bound on how far a sender may run ahead of what the receiver has durably stored, independent of transport flow control; quantized to the protocol's own durable unit (a segment, a captured attempt) and receiver-issued, not sender-self-paced. |

See [Connectors](connectors.md) for shared attempt/reconciliation and HTTP
capture, [gRPC connectors](connectors.md) for streaming RPC authority and transcripts, and
[Flow control](streams.md) for the shared admission-credit pattern and
its distinction from transport flow control.

## Inspection and interpretation

See [Serving](serving.md), [Reactive APIs](reactive.md) and
[Reactive interfaces](reactive.md) for inbound service, API and
live-view contracts, separate from connector attempts.

| Term | Meaning |
| --- | --- |
| Observation basis | The source, read position, policy revision, retained boundary, and coverage supporting an inspected view. Different sources need not share one consistent cut. |
| Journey | A bounded view of recorded causal relationships between inputs, turns, outputs, admissions, and effects. It introduces no new execution identity and may contain explicit gaps. |
| Lens | A versioned Board interpretation of authorized runtime/framework evidence, without decoding application business values, replacing kernel facts, or broadening access. |

Arrivals and departures are presentation terms mapped to mailbox admissions,
committed outputs, and effect stages. They do not change those stages' guarantees.
See [Board](../guides/inspect-board.md) for the visual language and evidence rules.

## Declarative application interfaces

| Term | Meaning |
| --- | --- |
| Interface definition | Typed composition of screens, public bindings, actions and theme references within its selected declaration grammar and publication profile. General SQL/visual equivalence remains design direction. It grants no authority. |
| Interface revision | An immutable validated definition with explicit component/contract compatibility; conditional publication selects the active revision without atomically changing unrelated resources. |
| Interface binding | A declared connection from presentation to an exact public inspection projection, finite query or command target, with schema, capability and budget requirements. Distinct from a service or runtime binding. |
| Application migration | A versioned data-owner plan between application revisions, with conditional public operations, bounded progress and recoverable step receipts in the selected application profile. Not an implicit cross-resource transaction or authority restore. |

[Reactive applications](applications.md) owns this model and its limits;
Its shared compiler validates SQL and visual proposals before explicit publication.

## Operational observability

| Term | Meaning |
| --- | --- |
| Instrumentation | Code observing service operations through logs, metrics and traces; it does not authorize execution or replace durable evidence. |
| Operational log | A diagnostic event with an owner, time and structured fields. Delivery and retention can be incomplete; it is not the protocol audit record. |
| Metric | An aggregated measurement with defined units, labels, scope, freshness and reset behavior. Service-local counts are not automatically exact durable totals. |
| Trace / span | A trace relates observed operations; a span describes a bounded operation with timing and context. Neither is a complete durable process journey. |
| Trace context | Identifiers and permitted metadata relating spans/logs across boundaries. Remote context is untrusted and grants no permission. |
| Service instance | One running incarnation of an executable, used to attribute telemetry and counter resets. Distinct from a Transit PID, activation and provider runtime instance. |
| Liveness / readiness / progress | Respectively, ability to make required local progress, ability to serve a declared role now, and advancement of workload or maintenance work. None proves ownership. |

See [Observability](observability.md) for signal ownership, interpretation and
resource bounds. `transit-observability` is the Transit-specific instrumentation
package; Board owns its service instrumentation separately. The neutral
`telemetry` package supplies bounded sinks, metrics and trace context to both.

## Monorepo and deployment

| Term | Meaning |
| --- | --- |
| Package | A source/dependency boundary in the monorepo with its own build definition. A Zig package may expose modules, executable artifacts, or both. |
| Library/module | Reusable Zig code imported by consumers. Transit and Station expose packages with explicit module interfaces; static/shared artifacts have their own consumer and compatibility requirements. |
| Language binding | Generated declarations/codecs and a thin host-runtime adapter over the shared client/framework implementation; targets the languages in [Client](callers.md) |
| Language SDK | A language-native public API over shared bindings, with typed operations, errors, handler/runtime integration and packaging; implemented in [the SDKs](sdks.md), sharing Zig protocol semantics |
| Handler runner | SDK integration that dispatches local handlers and drives the shared Station turn machine; temporary worker machinery, not durable process identity or execution authority |
| C ABI | The versioned native call boundary implemented for client/Station bindings, with opaque handles and explicit ownership; distinct from the signed network protocol and Arrow's data interfaces |
| Example application | A complete runnable caller demonstrating the public client. `example-counter` and `example-byte-log` are examples; neither is required Transit infrastructure. |
| Executable | A runnable entry point composing libraries with configuration and lifecycle handling. It is not synonymous with a library, Transit process, or deployment. |
| Transit backend | A durable storage and transport implementation of Transit's persistence requirements. Packages use `transit-backend-*`; `transit-backend-ursula` exports `transit_backend_ursula`. Each implementation must prove its supported guarantees. |
| Runtime instance | An explicitly identified deployment of an execution provider, such as a particular Substrate installation. It scopes provider resource references. |
| Runtime binding | A durable association between a Transit PID and a scoped provider resource/workload version, reconciled by an adapter. It describes hosting, not execution authority. |
| Runtime binding revision | A version of that hosting association. Changing it does not change the PID or replace ownership fencing. |
| Substrate Actor | The external runtime's sandbox lifecycle unit, addressed by atespace and name within a Substrate instance. It maps to a Transit process in the first reference slice. |
| Runtime adapter | Code reconciling committed lifecycle intent with an execution provider and recording observations into Transit. Packages use `transit-runtime-*`; `transit-runtime-substrate` exports `transit_runtime_substrate`. Provider state does not grant execution authority. |
| Reference deployment | The Kubernetes/Agent Substrate configuration against which execution, isolation, and worker-recovery behavior are proved. |

See [Components](components.md) for package
boundaries and [Deployment](deployment.md) for runtime authority and portability.
