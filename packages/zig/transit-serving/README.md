# transit-serving

M19 implementation in progress of the [serving profile](../../../contracts/SERVING_V1.md).
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

Run `zig build test` in the pinned Nix environment. Full HTTP/TLS/deployment and
reactive API qualification are separate gates in [M19](../../../docs/roadmap/M19.md)
and [M20](../../../docs/roadmap/M20.md); this package's unit checks do not prove them.
