# transit-serving

Qualified M19 implementation of the [serving profile](../../../contracts/SERVING_V1.md).
This library composes public growing Station turns. It has no HTTP, raw storage,
private key storage, clock or gateway retry database. Admission and disposition
records live in the service's private resource; reads use current public clients.

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
the versioned records; `SignedRead` binds a read scope and native identity proof to
the same provisioned key. A successful signature check alone does not establish a
current grant: adapters must ask authority, enforce current service read policy
and revalidate before disclosing protected data. Incoming commands preserve their
caller-signed native bytes. The service owner deduplicates across native sequences
and gateway instances using the durable operation key and content digest.

The service identity includes realm and ingress PID as well as its service number.
Replacing that ingress creates a different authority/history scope; a gateway
cannot recover or retarget the old command merely by reusing the number. Native
signatures and scoped reads bind the ingress explicitly.

Run `zig build test` in the pinned Nix environment. Full HTTP/TLS/deployment and
reactive API qualification are separate gates in [M19](../../../docs/roadmap/M19.md)
and [M20](../../../docs/roadmap/M20.md); this package's unit checks do not prove them.

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
and scoped signatures (`python3 -B tests/reactive_fixtures.py` from the root).
Deterministic tests cover competing attachments, stale subscription controls,
renewal/expiry races, retained growth, aggregate quota and failed reads. These
checks do not advertise SSE/WebSocket or prove deployed recovery.

`TableWatch` acquires the declared Table descriptor, data-progress entry and
first bounded page at one exact current resource revision. The initial transport
profile is an int64 Table; application integers encode as decimal strings. A
`more` flag directs larger snapshots to the existing finite query reader.
`covered` reuses `transit-query`'s source contract/schema basis, checking the
identical resource and data watermark. It does not extend a query's released pin.

`ReactiveAdapter` checks signed scopes, current native/service authority, leases,
attachments and subscription generations before and after bounded observations.
It also rechecks the watched resource's writer, current grant and declaration.
The host supplies a qualified conservative wall-clock upper bound and performs
a final `check` before each protected transport release. A cursor is signed
integrity evidence, never a grant. Snapshot races restart the whole acquisition
up to three times; loss of coverage is explicit reset or interruption.

`Api` reflects the owning types into [OpenAPI 3.2.1](api/openapi.json) and
[AsyncAPI 3.0](api/asyncapi.json), sharing operation metadata with discovery.
`just test::reactive-descriptions` checks pinned official schemas and drift.
Regenerate with `zig build serving-api -Doptimize=ReleaseSafe` then
`python3 -B tests/reactive_descriptions.py zig-out/bin/transit-serving-api --write`.
The independent peer trace can additionally be checked with `--trace PATH`.
Native identity proofs are narrowed to the only supported identity query; fixed
byte arrays and version constants are validated before decoding host envelopes.

The final transport `check` retries up to three conflicting resource observations,
just like snapshot acquisition; exhaustion remains interruption. The example resets
its bounded workspace between attachment polls and never appends an HTTP error
after streaming/upgrade headers may have started. `ReactiveWire.SseItem` describes
the SSE field object; its `data` string contains the shared `ServerMessage`.
Independent description validation explicitly checks that encoded JSON content.
