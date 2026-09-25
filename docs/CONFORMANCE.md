# Protocol conformance and implementation gates

Status: adversarial requirements with executable evidence for the bounded M1
profile and its M2–M9 extensions. [tests/README.md](../tests/README.md) maps commands to recorded results,
failure schedules, and limits. The [roadmap](roadmap/README.md) owns milestone gates.
Results apply to their pinned topology, reviewed workload, and failure boundary;
passing a subset does not establish every target guarantee.

## Adversarial scenarios

Each row identifies the contract owner and the earliest required evidence. Use
valid/invalid traces, deterministic schedules, crash injection, and real adapter
tests as appropriate. A happy-path example alone does not satisfy a row.

| Scenario | Required evidence | Owner / milestone |
| --- | --- | --- |
| A worker claims another PID, realm, role, or image | Authenticated provenance and scoped grants reject impersonation before mutation or data disclosure | [Security](SECURITY.md), M1 |
| Permission is revoked while a message, turn, or dispatch is pending | Defined authorization boundaries, fenced policy revisions, and durable blocked/denied outcomes; prior acceptance is not erased | [Security](SECURITY.md#authorization-over-time), M1 |
| A subscriber keeps an old token; a reader follows a private blob reference | Current read authorization covers subscriptions, receipts, payloads, and derived views | [Security](SECURITY.md), M1 API surfaces; M12 transcripts |
| Two authorities and a restored old worker race to commit | At most one accepted successor per prior commit/generation; authority restart cannot reset fencing | [Transit](TRANSIT.md#ownership-and-failure), M1 |
| The append succeeds but its acknowledgement is lost | Stable operation identity recovers the same spawn, admission, commit, or dispatch decision; conflicting content is rejected | [Transit](TRANSIT.md), [Streams](STREAMS.md), M1 |
| Outbox retries reorder a sender's messages or only part of a fan-out arrives | Preserve declared per-sender/destination order, including delayed uncertain admissions; prove terminal delivery outcomes rather than inferring them from timeouts; no cross-process atomicity claim | [Streams](STREAMS.md#commit-and-delivery), M1 |
| Native code attempts forbidden I/O, submits a stale commit, reports false application state, or never returns | Prove runtime I/O boundaries and stale-commit rejection; authorized state bytes remain a trusted application claim, and protocol legality does not prove computation correct or bounded | [Transit](TRANSIT.md#enforcement), M1 |
| A handler repeatedly fails on the head message | Bounded retries, visible blocked state or authorized ordered disposition; no silent skipping or endless supervisor replacement | [Station](STATION.md#failure-and-progress), minimal policy M1; helpers M9 |
| A work cutoff or required-input expiry occurs during suspension or a turn | Only explicitly authorized bounded settlement may continue with a valid recovery basis; final retirement rejects all further execution even when bytes remain | [Retention](RETENTION.md), M1 |
| A result races reconciliation closure or arrives after recovery/trim | One authoritative winner; closed unknown stays unknown; no late admission, retry, or reopening; existing receipts do not constitute new acceptance | [Connectors](CONNECTORS.md#bounded-reconciliation-contract), kernel proof M1; connector execution M12 |
| Clock rollback or a controller partition delays expiry | State the time/error model and refusal behavior; recorded deadlines do not extend through stale authority | [Retention](RETENTION.md#time-and-policy-changes), M1 |
| A worker pauses after dispatch authorization, then loses ownership | Treat the attempt as possibly in flight; do not infer cancellation or safe retry from revocation | [Security](SECURITY.md#effects-and-the-limits-of-revocation), M1 synthetic executor; M12 HTTP |
| A connector is redirected to metadata/admin APIs or submits another attempt's result | Enforce destination/credential scope at each hop and authenticate result provenance | [Connectors](CONNECTORS.md), M12 |
| Data storage fills while expiry, revocation, or GC needs a durable record | Reserve and bound control/maintenance capacity; refuse admission before cleanup deadlocks | [Retention](RETENTION.md#horizons-dependencies-and-capacity), M1 |
| GC races a new reference or crashes after physical deletion | Serialize dependency admission with logical retirement; resume maintenance from durable control evidence outside deleted data | [Retention](RETENTION.md), M1 |
| Bootstrap restarts after partial creation; the application registry is absent | Recover the same realm, catalog, policy roots, and spawn identities without duplicate children or a second execution truth | [Deployment](DEPLOYMENT.md#bootstrap-and-disaster-recovery), M1 |
| A runtime create succeeds before the controller records its result | Reconcile the intended provider incarnation; duplicate sandboxes never gain duplicate commit authority | [Deployment](DEPLOYMENT.md), M1 |
| An old backup lacks a revocation, expiry, or externally completed effect | Refuse automatic live activation; fence the old deployment and reconcile external work before an explicit restore/import | [Deployment](DEPLOYMENT.md#bootstrap-and-disaster-recovery), documented boundary M1; restore proof M15 |
| A Board list, graph, cached result, or agent query crosses a revoked or hidden resource | Current scoped read authorization covers every response and aggregate; no resource leak through identifiers/counts, and no mutation or raw-provider bypass | [Board](BOARD.md#access-and-trust), M2 |
| Board loses connection, or retention advances during a paginated journey | Explicit observation basis, stale/gap states and bounded resynchronization; no invented empty queue, complete history, or causal edge | [Board](BOARD.md#consistency-freshness-and-retention), M2 |
| A lens encounters forged metadata or an unknown schema | Safe rendering and kernel fallback; enriched facts preserve source provenance and cannot override authority | [Board](BOARD.md#higher-level-interpretation), M2 foundation; M9/M11/M12 lenses |
| Board polling or a slow reader exhausts a query budget | Bounded scans, buffers, concurrency and backoff; qualify control progress under inspection load | [Board](BOARD.md), M2 |
| A log sink stalls, telemetry is disabled, or diagnostics flood on one CPU | Bounded work, memory, cardinality and flush; control/deadline progress and unchanged durable outcomes; explicit drops and finite log storage | [Observability](OBSERVABILITY.md), [M4](roadmap/M4.md) |
| A caller injects credentials, arbitrary labels or forged trace context into diagnostics | Redaction, escaping and finite categories prevent disclosure/exhaustion; correlation metadata cannot confer authority | [Observability](OBSERVABILITY.md), [Security](SECURITY.md), M4 |
| A committed operation loses its response, is retried or appears in replay | Distinct transport, receipt and durable outcomes; telemetry cannot fabricate rollback, fresh completion or redispatch | [Observability](OBSERVABILITY.md), M4 |
| Staged state data survives a crash but its turn never commits, or a committed mutation is missing from an index | One durable visibility decision for mutation, input progress and outputs; staging stays invisible, uncertain retries deduplicate, indexes recover without inventing rollback | [State](STATE.md#turn-and-commit-boundary), M7 |
| A PID associates a hidden resource or an old activation writes through a retained reference | Independent current resource grants, fenced writer authority, fixed resource identity, and no disclosure through Board edges/counts | [State](STATE.md), [Security](SECURITY.md), M7 |
| A shared resource changes or its read version is trimmed while a turn is pending | Explicit read basis, bounded dependency protection and defined expiry/recomputation; uncertain commits keep the same proposal, and replay cannot substitute latest values | [State](STATE.md#reads-replay-and-lookup-cost), M7 |
| Required state expires while a PID is suspended, or an associated reader outlives the resource owner | Permanent recovery failure under the accepted required-state policy; no implicit lifetime extension, detachment, or empty-state recreation; outages remain distinct | [State](STATE.md#lifetimes-and-retention), M7 |
| A live key is older than the history window, or a deleted key is replayed from an old snapshot | Current-value preservation, versioned deletion and retained rejection evidence; explicit lagging-reader gaps with no resurrection | [State](STATE.md), M7 bounded KV; M15 distributed extension |
| A resource retires as another operation creates a dependency, or staging/pins exhaust capacity | Serialized admission/retirement, bounded staging and read views, resumable cleanup, and reserved control progress | [State](STATE.md), [Retention](RETENTION.md), M7 |
| A payload claims a trusted reply sender | Authority-derived origins distinguish an external forgery from a committed source-process output, including after courier/node restart | [Client](CLIENT.md), M8 |
| A courier loses an acknowledgement or its send grant is revoked | Exact retry identity, bounded scoped scans, one admission or recorded terminal denial; restart needs no second queue | [Courier](../apps/transit-delivery/README.md), M8 |
| Completed catalogs fill repeatedly or an old identity returns after collection | Explicit opt-in, protected pending work, non-reusable identities and recovery across checkpoint/trim | [Catalog contract](../contracts/CATALOG_V1.md), M8 |
| Initialization crashes, retry names a stale failure, or suspension outlives recovery | Same provisioning receipt, declared required associations, scoped generation fence and permanent expiry; no skipped head input | [Lifecycle contract](../contracts/LIFECYCLE_V1.md), M8 |
| A name is rebound while replies or retries are pending | Fixed destination PID and conditional cleanup; no permission inherited from a lookup or alias | [Station](STATION.md), M9 |
| A language binding narrows an identity, loses an uncertain proposal, blocks its runtime, or releases a live buffer | Shared full-width wire/signature fixtures, exact retry after host/bridge loss, explicit ABI ownership and bounded scheduling; real callers in every target language | [Client](CLIENT.md#binding-guarantees), M9 |
| A Table batch spans resources, exceeds limits, or loses its commit response | Atomic co-located table changes with input progress/reply intent; reject unsupported scope before publication; no partial batch or duplicate mutation | [Tables](TABLES.md#transactions-and-visibility), M9 |
| A materialized table receives duplicates, updates or deletes and loses its cache | Committed source progress and visible rows agree after checkpoint/tail recovery; finite aggregates exclude superseded/deleted versions | [Tables](TABLES.md#materialization-from-durable-streams), M9 |
| An Arrow result loses a fragment, mixes revisions, exceeds memory, or its owner restarts | Bound decode/reassembly, authenticate source, preserve one captured result and verify completion; no partial success or fresh-snapshot substitution | [Tables](TABLES.md#arrow-results-and-durable-replies), M9 |
| A Table caller spoofs a reply destination or queries after service-policy revocation | Explicit service data-sharing authority, durable policy ordering and refusal of further unauthorized fragments; already authorized copied data has its own disclosed retention contract | [Tables](TABLES.md#access-lifetimes-and-inspection), M9 |
| A query sink stalls, completion overtakes batches, or cancellation races in-flight compute | Bounded queues/tasks and control progress; complete expected input/result coverage, explicit cancellation and no partial publication | [Fuze](FUZE.md#bounded-execution-and-recovery), M9 |
| A rewrite drops a residual predicate, changes limit ordering, or reuses a stale plan | Same specified result/schema/errors as execution without rewrites, exact source identity/read basis and current rights; no optimization can broaden access | [Fuze planning](FUZE.md#planning-and-extension-boundaries), M9 for enabled rules |
| An SDK reports success on handler return, reuses a completed turn, or retries an uncertain commit under a new identity | Confirmed outcome types, scoped turn capabilities and exact pending-request recovery through the public API; no duplicate mutation or implicit acknowledgement | [Client SDKs](CLIENT.md#idiomatic-language-sdks), M10 |
| A local await is cancelled, a runner exits with native work in flight, or a durable call outlives its host task | Bounded scheduling and joined ownership, explicit local versus durable cancellation, recorded wait identity and fresh-worker resumption; no suspended-stack durability claim | [Station](STATION.md#languages-and-bindings), M10 |
| A typed payload has an unsupported version or an Arrow adapter narrows values or releases live bytes | Runtime codec validation, explicit decode-failure policy, full-width cross-language fixtures and owned complete results with source evidence | [SDK qualification](roadmap/M10.md#exit-criteria), M10 |
| Concurrent Document edits arrive out of order, duplicate an operation, or depend on a rejected change | Same materialized state/conflicts for the same accepted change set under the supported merge contract; bounded dependency handling and current admission rights | [Documents](roadmap/M11.md), M11 |
| A worker crashes while publishing a Document checkpoint or causal metadata is trimmed too early | Atomic visible change/input/output progress, recoverable merge/deletion evidence and cleanup of unpublished staging; no partial publication or resurrection | [Documents](roadmap/M11.md), [State](STATE.md), M11 |
| An offline replica returns after its merge window, revocation or Document retirement | Explicit rejection/resynchronization under opted-in policy; no revival through mathematically mergeable edits or stale checkpoints | [Documents](roadmap/M11.md), [Retention](RETENTION.md), M11 |
| A unified query decodes KV bytes incorrectly or collapses missing/null/conflicting Document fields | Versioned decoders/projections, exact source revisions, qualified Arrow types and unchanged access/lifetime boundaries across all three source kinds | [Fuze](FUZE.md#one-query-model-across-state-entities), M11 |
| A streaming RPC sends after revocation, changes executors, or silently retries a partial call | Exact committed/authorized send units, fenced progress, independent directional order and no hidden new attempts; partial sends remain possibly applied | [gRPC](GRPC.md#streaming-authority-and-backpressure), M13 |
| A gRPC peer blocks, sends oversized data, or ends with incomplete capture | Bounded bidirectional backpressure and decoding; provisional versus terminal observations, explicit gaps and no success inferred from transport status | [gRPC](GRPC.md#durable-call-and-transcript), M13 |
| A cancelled RPC finishes after closure or is replayed during recovery | Bounded reconciliation, permanent late-result rejection and network-free replay; no remote rollback or implicit stream resumption claim | [gRPC](GRPC.md#failure-retries-and-reconciliation), M13 |
| A Flight ticket is copied across principals or a gateway serves cached data after revocation/expiry | Current scope checks on metadata/results, exact retained result identity, no raw-provider bypass or lifetime extension through a new handle | [Arrow](ARROW.md#identity-lifetime-and-failure), M14 |
| Flight retrieval disconnects or an ADBC client encounters unsupported SQL/types/transactions | Same captured result on retrieval retry, explicit unavailable/unsupported outcomes, qualified metadata schemas and truthful capabilities | [Arrow](ARROW.md#first-remote-query-profile), M14 |
| A tombstone or retry receipt is collected before a late consumer returns | Explicit horizon failure/resynchronization with no resurrection or duplicate admission | [Retention](RETENTION.md), retry boundary M1; KV compaction M7; distributed extension M15 |
| A new image/schema interprets retained state differently | Authorized, versioned migration with a defined failure path; old and new owners cannot commit concurrently | [Transit](TRANSIT.md#replay-and-versions), reject unsupported changes M1; migration M15 |

[M8 readiness evidence](../tests/README.md#m8-runtime-readiness) covers the
handler-facing origin envelope, deployed courier, initialization barrier, scoped
retry/suspension and working catalog reclamation. Durable lifecycle subscriptions,
framework initialization policy and timers are qualified in the
[M9 profile](../tests/README.md#m9-station-bindings-and-tables).

## Evidence and limits

For each supported runtime/storage profile, record the tested revision, topology,
failure boundary, authoritative operation point, input schedule, and expected
durable outcomes. Assertions must inspect history and denied side effects, not
just eventual output. Recovery tests must distinguish local caches, durable
checkpoints, and external systems. A trace should make competing authority or
unexpected effect execution observable.

The first slice uses a single security realm, fixed workload code, a minimal
policy authority, and synthetic effects on the Kubernetes/Substrate reference
deployment. Multiple principals, conflicting authority instances, worker loss
and retention deadlines are exercised in the linked proof suite; the single-realm topology does
not remove those obligations when the profile expands.

The contract does not currently promise Byzantine fault tolerance, globally
ordered messages, cross-process transactions, exactly-once remote effects,
arbitrary native-code determinism, timely scheduling before expiry, or instant
physical erasure. Add such guarantees only with an explicit scope change and
supporting proof. Milestone ordering and the remaining design gates live in
[roadmap](roadmap/README.md).
