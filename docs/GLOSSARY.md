# Glossary

Shared vocabulary for Rey's foundational documents. Official names are
established; definitions describe the intended architecture, not implemented
capabilities. Detailed contracts live in the linked design documents.

## Names and roles

| Term | Meaning |
| --- | --- |
| Rey | The monorepo containing Transit, Board, Station, connectors, runtime adapters, executables, and applications. Trading is an intended application. |
| Transit | The agentic streaming kernel: the foundational execution protocol enforced by durable message sequences. See [TRANSIT.md](TRANSIT.md). |
| Board | The operator/agent inspection surface: a static UI and OpenAPI service hosted by the Zig `board` executable. Its views derive from authorized Transit evidence; it grants no execution authority. See [BOARD.md](BOARD.md). |
| Station | The OTP-inspired framework above Transit, providing GenServer behaviors, supervision, registries, and composition. See [STATION.md](STATION.md). |
| Agentic | The class of workloads the system is intended to support. It does not place reasoning loops, goals, or agent/task delegation in the kernel. |
| Ursula | The selected durable stream storage and transport implementation. See [URSULA.md](URSULA.md). |
| ursula-zig | The upstream Zig client used by Rey's Ursula adapter. It handles transport/protocol operations; Transit defines execution semantics. |
| Agent Substrate | The recommended sandbox execution target on Kubernetes. It manages runtime infrastructure and lifecycle; Transit's durable history governs process execution. See [DEPLOYMENT.md](DEPLOYMENT.md). |
| Launcher | Development tooling that provisions and runs a concrete environment. Local, Compose, and reference launchers compose services; they do not replace Transit authority or Station supervision. See the [launcher guide](../launchers/README.md). |

Use **Transit**, **Board**, and **Station** in prose, with **kernel**,
**inspection surface**, and **framework** as their roles. The kernel implementation library lives in `packages/zig/transit-core`
and exports the `transit_core` Zig module. `transit-protocol` owns public wire
contracts; `transit-client` is the application entry point. The planned Station
library exports `station`. See the
[decomposition plan](ARCHITECTURE.md#planned-monorepo-decomposition) for implemented
and proposed packages.

"Durable streams" or "streaming substrate" refers to message transport and
persistence. **Agent Substrate** names the external execution project. Keep the
distinction explicit when both appear in the same discussion.

## Processes, actors, and execution

| Term | Meaning |
| --- | --- |
| Process | Transit's logical execution primitive: identity, mailbox, committed state, ordered sequence, and lifecycle. It is independent of an OS process, worker, or sandbox. |
| PID | Opaque, durably scoped process identity. It survives eligible worker recovery, suspension, and migration; logical termination or process expiry retires it permanently. |
| Actor | A programming-model participant implemented by a Transit process. It adds no separate identity layer. Use **Substrate Actor** when referring to the external runtime resource. |
| GenServer | A Station behavior running in a Transit process, providing sequential message handling, explicit state, and request/reply under that process's PID. |
| Mailbox | The process's ordered view of durably admitted input messages. Admission and processing progress are distinct. |
| Unbounded mailbox | A logically unbounded durable backlog that can outlive a worker and exceed its RAM. Read windows, storage capacity, and admission still have explicit limits. |
| Process sequence | The process's ordered protocol history, including admitted messages and execution/lifecycle records. It establishes no global order across processes. |
| Admission | Durable acceptance of a message's identity and place in the target PID's mailbox. It does not mean handling or an external effect has completed. |
| Turn | Handling one admitted input against committed process state and proposing the next state, outgoing messages, and effect intents. |
| Application state | Opaque caller-owned bytes recorded by Transit. Protocol acceptance does not prove application computation correct. |
| State revision | The version of committed application state used as a turn precondition. In M1 it starts at zero and advances to the successful turn position; it is distinct from ownership generation. |
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

See [Transit](TRANSIT.md), [Station](STATION.md), and [Streams](STREAMS.md) for
ordering, ownership, and behavior requirements.

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

See [SECURITY.md](SECURITY.md) for enforcement placement, historical decisions,
current access checks, and provider boundaries.

## Names and registries

| Term | Meaning |
| --- | --- |
| Namespace | An explicit scope for registered names, with defined authority, visibility, and lifetime. It is not implicitly a host, Kubernetes namespace, or Substrate atespace. |
| Registered name | An optional `(namespace, name)` alias to a PID. Rebinding it does not change the old process's identity or redirect its accepted work. |
| Registry | A Station service whose durable protocol history determines name-to-PID bindings. Lookup caches are derived views. |
| Registry revision | A version of a name binding used for conditional changes and recorded resolution. It is distinct from execution ownership and runtime binding revisions. |

See [Station registries](STATION.md#registries-and-addressing) for local and
cluster scopes, conflict handling, and stable message destinations.

## Messages, storage, and recovery

| Term | Meaning |
| --- | --- |
| Message identity | A stable identifier preserved across retries. Reusing it with conflicting content is a protocol conflict. |
| Causation | The relationship identifying which input, turn, or effect caused a record. |
| Correlation | An identity joining related work, such as a request and its reply. It does not itself establish order or authority. |
| Durable stream | Persistent ordered records with resumable reading under a documented durability/retention contract. |
| Immutable payload | A logical storage object with a fixed byte body, content hash and unreused identity. M1 supports standalone payloads with explicit publication and deletion records; application dependencies and finite body lifetimes need a later contract. |
| Cursor | Ursula's opaque cache/collapse token, independent of the offset or record position that selects a read location. It is not a Transit message identity or execution position. |
| Authoritative history | Validated durable records, including checkpoints replacing reclaimed prefixes, that determine accepted work, progress, ownership, lifetime, and effect eligibility. |
| Outbox | Committed pending outputs awaiting delivery. Retried delivery preserves identity and the destination deduplicates admission. |
| Checkpoint | A durable record of a validated history prefix, state/progress, versions, and required dependencies. It becomes essential recovery evidence if that prefix is reclaimed. |
| Process snapshot | Saved process state tied to its PID, history position, and versions. It may supply checkpoint state; state alone does not prove complete recovery coverage. |
| Sandbox snapshot | Runtime memory/filesystem capture. Restoring it does not restore ownership or supersede newer protocol history. |
| Replay | Reconstructing or inspecting committed execution within retained history using recorded outcomes, without redispatching external effects. |
| Recovery | Restoring valid state and authority, then resuming eligible live work within its lifetime and delivery/attempt contracts. |
| Producer epoch | Ursula's producer-deduplication generation. It is distinct from a Transit ownership generation; their mapping must be proved. |

See [STREAMS.md](STREAMS.md), [TRANSIT.md](TRANSIT.md), and [URSULA.md](URSULA.md).

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
| Garbage collection | Background physical reclamation after validated logical trim/retirement decisions and dependency resolution. |
| Storage quota | A capacity limit enforced independently of retention age, with explicit admission/backpressure behavior. |
| Logical stream | A stable protocol stream whose ordering and retention contract are independent of its storage provider. |
| Physical segment | An adapter-managed portion of a logical stream that can be rotated or reclaimed without changing logical identity or sequence positions. |

See [RETENTION.md](RETENTION.md) for lifetime interaction, policy changes,
checkpoint authority, and reclamation guarantees.

## Effects and connectors

| Term | Meaning |
| --- | --- |
| Effect | Work at an external or nondeterministic boundary, requested through a committed intent and observed through recorded outcomes. |
| Capability | Scoped authority to request or perform particular operations, enforced by the protocol and runtime boundaries. |
| Connector | Library and executor logic for a particular effect family, including its capture, retry, and reconciliation semantics. |
| Fetch worker | A connector executor authorized to issue HTTP requests and record response data and attempt metadata. |
| Attempt | One authorized execution attempt of an effect, with its own identity. Retries and redirects remain individually observable. |
| Dispatch authorization | The durable decision permitting one external attempt after current checks. From that point it may be in flight even if its worker has not yet sent. |
| Exchange stream group | A Rey manifest and related durable records/streams representing one HTTP request, its attempts, responses, and metadata. It does not imply a native Ursula group or multi-stream transaction. |
| Transcript | The recorded request/response data and observations, with explicit capture boundaries and omissions. |
| Interpolation | Rendering request variables from recorded bindings or authorized secret references, with field-specific encoding rules. |
| Secret reference | A credential binding/version resolved by an authorized executor, allowing transcripts to identify substitutions without storing the secret value. |
| Unknown outcome | An attempt whose remote result cannot be established from recorded evidence, such as a worker crash after sending. It requires connector recovery policy. |
| Reconciliation | Connector work to establish an attempt's outcome using its external-system contract; it is not permission to repeat the original effect. |
| Reconciliation lifetime | The accepted window and work budget for reconciliation. Recovery cannot renew it implicitly. |
| Reconciliation closure | The irreversible end of an attempt's result-acceptance path. Late submissions are rejected; historical receipts remain receipts. |
| Closed with outcome unknown | A terminal local disposition ending reconciliation without claiming remote success, failure, or cancellation. |

See [CONNECTORS.md](CONNECTORS.md) for HTTP text, capture completeness, timing,
and replay requirements.

## Inspection and interpretation

| Term | Meaning |
| --- | --- |
| Observation basis | The source, read position, policy revision, retained boundary, and coverage supporting an inspected view. Different sources need not share one consistent cut. |
| Journey | A bounded view of recorded causal relationships between inputs, turns, outputs, admissions, and effects. It introduces no new execution identity and may contain explicit gaps. |
| Lens | A versioned Board interpretation of authorized evidence, adding application/framework meaning without replacing kernel facts, broadening access, or executing application handlers. |

Arrivals and departures are presentation terms mapped to mailbox admissions,
committed outputs, and effect stages. They do not change those stages' guarantees.
See [Board](BOARD.md) for the visual language and evidence rules.

## Monorepo and deployment

| Term | Meaning |
| --- | --- |
| Package | A source/dependency boundary in the monorepo with its own build definition. A Zig package may expose modules, executable artifacts, or both. |
| Library/module | Reusable Zig code imported by consumers. Transit and Station will expose libraries; packaging a static/shared artifact is a separate consumer need. |
| Example application | A complete runnable caller demonstrating the public client. `example-counter` and `example-byte-log` are examples; neither is required Transit infrastructure. |
| Executable | A runnable entry point composing libraries with configuration and lifecycle handling. It is not synonymous with a library, Transit process, or deployment. |
| Transit backend | A durable storage and transport implementation of Transit's persistence requirements. Packages use `transit-backend-*`; `transit-backend-ursula` exports `transit_backend_ursula`. Each implementation must prove its supported guarantees. |
| Runtime instance | An explicitly identified deployment of an execution provider, such as a particular Substrate installation. It scopes provider resource references. |
| Runtime binding | A durable association between a Transit PID and a scoped provider resource/workload version, reconciled by an adapter. It describes hosting, not execution authority. |
| Runtime binding revision | A version of that hosting association. Changing it does not change the PID or replace ownership fencing. |
| Substrate Actor | The external runtime's sandbox lifecycle unit, addressed by atespace and name within a Substrate instance. It maps to a Transit process in the first reference slice. |
| Runtime adapter | Code reconciling committed lifecycle intent with an execution provider and recording observations into Transit. Packages use `transit-runtime-*`; `transit-runtime-substrate` exports `transit_runtime_substrate`. Provider state does not grant execution authority. |
| Reference deployment | The Kubernetes/Agent Substrate configuration against which execution, isolation, and worker-recovery behavior are proved. |

See [ARCHITECTURE.md](ARCHITECTURE.md#planned-monorepo-decomposition) for package
boundaries and [DEPLOYMENT.md](DEPLOYMENT.md) for runtime authority and portability.
