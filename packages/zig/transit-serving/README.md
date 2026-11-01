# transit-serving

The reusable [HTTP host](../transit-serving-http/README.md) composes this package
with the neutral listener. Socket/challenge ownership stays outside these durable
service and reactive semantics.

Qualified M19 implementation of the [serving profile](../../../contracts/SERVING_V1.md).
The service core composes public growing Station turns. It has no HTTP, raw storage,
private key storage, clock or gateway retry database. Admission and disposition
records live in the service's private resource; reads use current public clients.

`Caller` is the client composition: exact command preparation/recovery, shared
subject proofs and bounded verified HTTP through the public native client. Its
[one-request host](../../../apps/transit-serving-client/README.md) reads an external
credential only for preparation or observation and owns no durable journal.

`Service` binds one ingress to a service, administrator and timer observer. Install
both `interface()` and `guard()` on the host, initialize it privately, then publish
the versioned binding and per-principal policies before granting public ingress.
The optional Station input guard rejects malformed/spoofed frames before framework
dispatch. It cannot replace kernel authorization or increase a turn's budget.

Each admission uses at most three private mutations plus one outbox: an operation,
active table and ordinary Station wait. At most eight active operations share the
service, with independent per-principal quotas. Terminal records and immutable
binding revisions grow through durable point/page access. They are never held in
an unbounded resident collection or deleted because of capacity pressure.

`Model` owns typed commands, reads, accepted bindings and outcomes. `Codec` encodes
the versioned records; `SignedRead` binds the complete read to its original caller, current credential
epoch, selected role and ingress audience. A successful signature check alone does not establish a
current grant: adapters must ask authority, enforce current service read policy
and revalidate before disclosing protected data. Incoming commands preserve their
caller-signed native bytes. The service owner deduplicates across native sequences
and gateway instances using the durable operation key and content digest.

The service identity includes realm and ingress PID as well as its service number.
Replacing that ingress creates a different authority/history scope; a gateway
cannot recover or retarget the old command merely by reusing the number. Native
signatures and scoped reads bind the ingress explicitly.

Run `zig build test` in the pinned Nix environment. Full HTTP/TLS/deployment and
reactive API qualification are separate gates in [Serving](../../../docs/handbook/reference/serving.md)
and [Reactive APIs](../../../docs/handbook/reference/reactive.md); this package's unit checks do not prove them.

The [compatibility matrix](docs/compatibility.md) lists executed consumers,
placements and limits. Run the [application example](../../../examples/serving/README.md)
for native, Compose or operator-placed Substrate recovery.

M20's [reactive v1 contract](../../../contracts/REACTIVE_V1.md) is implemented
in the [qualified Table profile](docs/compatibility.md).
`ReactiveModel` owns session/subscription/attachment identities and signed cursors;
`ReactiveService` implements conditional controls inside the same `Service` turn.
Four live sessions per service, two per caller and one subscription per session
bound active work. Leases require authenticated monotonic observer input and obey
process/resource bounds. Closed history remains readable without loading it all.
An owner may close/unsubscribe its session after read-policy revocation; these
controls only release its own live work and disclose no source data.

Independent Python/OpenSSL fixtures pin every control, full-width IDs, cursors
and scoped signatures (`python3 -B tests/runner/launch.py tests/interfaces/reactive/reactive_fixtures.py` from the root).
Use `--check` to verify the checked-in fixture without rewriting it. The existing
`test-fixtures` aggregate runs this independent check, including signatures bound
to the current shared definition.
Deterministic tests cover competing attachments, stale subscription controls,
renewal/expiry races, retained growth, aggregate quota and failed reads. These
checks do not advertise SSE/WebSocket or prove deployed recovery.

`TableWatch` resolves the exact direct Table interpretation and first bounded row
page at an accepted partition position. It requires current database CONNECT,
schema USAGE and Table SELECT for the authenticated caller as well as the
configured private reader. The snapshot transport admits two INT64 columns with
the first a non-null primary key; application integers encode as decimal strings.
Its data watermark changes only for accepted row changes. Query bookkeeping does
not advance it. Interpretation changes require an explicit new snapshot. A `more`
flag directs larger snapshots to the finite query reader. `covered` checks the
query's identical Table interpretation and data watermark. It does not extend a
query's released pin.

`ReactiveAdapter` checks signed scopes, current native/service authority, leases,
attachments and subscription generations before and after bounded observations.
It also rechecks the watched resource's writer, current grant and declaration.
The host supplies a conservative wall-clock upper bound and performs
a final `check` before each protected transport release. A cursor is signed
integrity evidence, never a grant. Snapshot races restart the whole acquisition
up to three times; loss of coverage is explicit reset or interruption.

`Api` reflects the owning types into [OpenAPI 3.2.1](api/openapi.json) and
[AsyncAPI 3.0](api/asyncapi.json), sharing operation metadata with discovery.
`just test::reactive-descriptions` checks pinned official schemas and drift.
Regenerate with `zig build serving-api -Doptimize=ReleaseSafe` then
`python3 -B tests/interfaces/reactive/reactive_descriptions.py zig-out/bin/transit-serving-api --write`.
The independent peer trace can additionally be checked with `--trace PATH`.
Read proofs require the current contract definition and are authenticated through
native authority. Fixed byte arrays and version constants are validated before
decoding host envelopes. Restricted callers receive no private read credential.

The final transport `check` retries up to three conflicting resource observations,
just like snapshot acquisition; exhaustion remains interruption. The example resets
its bounded workspace between attachment polls and never appends an HTTP error
after streaming/upgrade headers may have started. `ReactiveWire.SseItem` describes
the SSE field object; its `data` string contains the shared `ServerMessage`.
Independent description validation explicitly checks that encoded JSON content.

`ReactiveClient` supplies shared frozen caller preparation, committed-control
observation and scoped read signing for private hosts. `ReactiveAdapter.inspect`
projects only the existing Table watch metadata; it never reads application rows.
The [private client contract](../../../contracts/REACTIVE_CLIENT_V1.md) describes
credential scope, source evidence and generated browser validation. This consumer
foundation alone does not qualify complete live query replacement or UI fairness.

The opt-in `LiveService` composes the ingress with the v1 finite requester.
The [refresh guide](docs/refresh.md) owns its bounded round-robin scheduler,
eight-intent limit per follow generation, current scoped proofs and prepared-query activation.
Accepted work survives view closure; only new scheduling depends on a live lease.


`FiniteService` is the M22 opt-in composition of `Service` and the public v1
Table requester. Initialization uses three mutations plus GenServer's descriptor,
keeping the four-write limit. Native query admission rechecks current serving
read/command policy and the configured published binding inside the owning turn.
The original requester enforces one active query and owns its retained statuses,
waiting and result publication. Tickets, SQL and sockets stay outside this owner.
Composition unit tests pass; gateway/client and placement qualification is open.

Rejected controls use [`ServingFailure`](src/ServingFailure.zig) to retain original
conflict, policy, quota and lifecycle evidence in one bounded durable record.
Current authorized disposition reads project it through the shared diagnostic
contract. See [serving semantics](../../../docs/handbook/reference/serving.md) for recovery
and the [wire contract](../../../contracts/SERVING_V1.md#rejected-input-evidence)
for encoding and disclosure rules.


`OperationDiagnostic` projects each retained operation phase independently of
HTTP delivery. Operation records retain original authenticated reply sizes;
`Service.operation` validates phase/count/result consistency before use.
Status/results and reactive terminal operation events use the same projection.
Result reads with no completed reply still perform the final current-authority
check before exposing their outcome diagnostic.

`ServingDiagnostic.codes` is the finite adapter registry. Attempt context
separates local input, authorized read failure, unconfirmed dispatch, rejected
native command and received native receipt. Malformed bindings, policies and
watch sources found during a read are integrity failures; the same validators on
caller input report binding failures. HTTP status follows this context. Socket
closure cannot establish session closure, and unknown byte exhaustion reports its
origin as unrecorded. Every failure retains a bounded next action without replacing
accepted work or starting a new generation.
