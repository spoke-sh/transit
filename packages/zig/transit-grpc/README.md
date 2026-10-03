# transit-grpc

Finite Zig HTTP/2 gRPC transport for [M16](../../../docs/roadmap/M16.md). This
package performs one connection and one RPC over a preconstructed message batch.
Station's connector must supply committed intent, current authorization, scoped
credentials, durable capture and terminal settlement before exposing results.
The [Station adapter](../transit-station-grpc/README.md) and
[worker](../../../apps/transit-station-grpc-worker/README.md) own those integrations.

[M22](../../../docs/roadmap/M22.md) also adds the separate inbound `Server`:
see [server ownership and limits](docs/server.md). Its transport proof does not
qualify Flight, authentication or serving/query authority.

`Request` fixes method, shape, ordered metadata and original serialized protobuf
bytes. `execute` validates the whole batch before dialing the pinned IPv4 address;
request slices and capture context must remain alive and immutable until it
returns, including cancellation and joined cleanup.
TLS authenticates the separate hostname and requires `h2` ALPN with an explicit
CA bundle. There is no DNS, proxy discovery, redial, hidden retry, hedging,
reflection or service-config loading. Every execution is one new attempt; callers
must not repeat an uncertain execution implicitly.

The default limits are 16 KiB per message, 64 KiB outgoing framed bytes, 256 KiB
incoming framed bytes, 64 messages per direction and 8 KiB/64 fields per metadata
block. Lower configured limits are enforced. HTTP/2 advertises 16 KiB receive
credit and a 4 KiB HPACK table. A fixed 2 MiB allocation budget covers trust,
HTTP/2, metadata and deframing, with four 16,645-byte TLS I/O buffers and one
16,389-byte outgoing frame buffer outside it. This is a live-call bound; there
is no retained-history collection here. Deadlines are finite, at most five minutes.

`Limits`, `Endpoint` and `Request` offer `validateDiagnostic` alongside ordinary
validation. The optional first-failure witness owns its field path and records
the exact failing check and measured values. It distinguishes message count,
individual message bytes, framed bytes and metadata accounting; later message
and metadata failures retain their original index. Routing, metadata and message
contents are withheld. Initialize the witness to `null` for each independent
operation. Validation does not allocate, dial or grant execution authority.

A single owner alternates partial sends with nonblocking response consumption.
It returns receive credit when bytes leave the HTTP/2 queue and invokes the
capture callback before consuming another complete message. The callback must
commit its allowlisted representation and mark omissions; it sees raw peer
metadata and must exclude secrets before persistence. Callback failure aborts
the call. It cannot turn a captured prefix into terminal success.

Successful `execute` means a valid captured gRPC terminal envelope, which can
contain a nonzero status. It does not mean remote business success. Results
retain actual outgoing/received counts and whether local half-close occurred;
an early server response can finish before the entire batch was written. An
error, cancellation or lost connection leaves remote execution uncertain.
Compressed messages and unsupported encodings reject explicitly; expanded and
wire message sizes are identical in this identity-only profile.

The selected [zig-libs snapshot](../../../third_party/zig-libs/README.md) pins
HTTP/2, HPACK, protobuf and the gRPC client at revision
`04799d8ec9280111046ebab943f446b3af39a95d`, with original and patched hashes in
its manifest. The [TLS adapter](../transit-tls/README.md) pins its own upstream
sources. No foreign runtime, upstream high-level HTTP client/server, or automatic
retry surface is included. The inbound adapter owns its bounded tasks over that
same HTTP/2 codec. The protobuf codec uses explicit scalar/field
specifications. `Descriptor.parse` reads only an explicitly supplied local
`FileDescriptorSet`, computes SHA-256 over its complete original bytes and
resolves exact method path, request/response type names and streaming shape.
There is no reflection or schema discovery. Keep generated application message
codecs separate from the durable call contract.

Descriptor parsing admits 64 KiB, 64 files, 256 methods and 256 nested message
types, with depth 16 and a 1 MiB decode allocation budget. It rejects ambiguous
or missing types/methods. The parsed descriptor owns an arena; call `deinit`.
Returned method paths borrow the supplied path string and type names borrow
the descriptor arena. The digest is a copied value. Unknown descriptor fields
still participate in that digest; this helper does not validate application
protobuf values against their field definitions.

Run `just test::grpc-libraries` and `just test::grpc-transport` inside `nix develop`.
The live proof uses independent grpcio/h2 peers, a pinned generated descriptor,
all four shapes, binary/Unicode/full-width protobuf, duplicate/binary metadata,
trailers, credit stalls, malformed terminal envelopes and bounded failures.
The live probe also resolves all four methods from protoc-generated descriptors.
Units reject truncated/oversize input, duplicates and missing types/methods.
Durable worker recovery, all ten SDKs and local/Compose/reference placement have
separate Station proofs. `Descriptor.at` also enumerates validated methods for
[offline request helper generation](../transit-station-grpc/README.md#offline-generated-helpers).

Transport failures preserve populated TLS/socket read and write causes across
HTTP/2 session operations. They remain distinct from protocol validation, capture
callback failure and an observed RPC status. No transport error triggers redial
or establishes whether the remote application performed its operation.
