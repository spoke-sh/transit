# transit-grpc

Finite Zig HTTP/2 gRPC transport for [M16](../../../docs/roadmap/M16.md). This
package performs one connection and one RPC over a preconstructed message batch.
Station's connector must supply committed intent, current authorization, scoped
credentials, durable capture and terminal settlement before exposing results.
Those authority integrations are still in progress.

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
sources. No foreign runtime, high-level HTTP client, RPC server or automatic
retry surface is included. The protobuf codec uses explicit scalar/field
specifications; schema discovery is the consuming adapter's responsibility.

Run `just test::grpc-libraries` and `just test::grpc-transport` inside `nix develop`.
The live proof uses independent grpcio/h2 peers, a pinned generated descriptor,
all four shapes, binary/Unicode/full-width protobuf, duplicate/binary metadata,
trailers, credit stalls, malformed terminal envelopes and bounded failures.
Durable RPC recovery, SDKs and deployment proofs remain M16 work.
