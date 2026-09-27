# transit-station-grpc

The M16 Zig adapter composes [Exchange](../transit-exchange/README.md), Station
Publication and the finite [RPC transport](../transit-grpc/README.md). Its
[versioned contract](../../../contracts/STATION_GRPC_V1.md) describes the finite
batch authority profile. Pure checks, independent transport peers and the actual
worker recovery proofs pass, together with all ten public SDKs, Board and the
local/Compose/reference example. The adapter does not authorize an RPC.

`Request` fixes a method, shape, descriptor-set SHA-256 and ordered metadata.
`provenance` emits canonical bounded JSON with lowercase hex for literal bytes
and immutable binding/version references for credentials. `parse` owns the decoded
representation in an explicit arena; call `deinit`. It refuses noncanonical bytes.
`render` borrows source/resolver memory until the transport joins; credential
resolution is an executor capability and is absent from provenance and parsing.

`Batch` preserves original protobuf bytes and empty messages. It validates finite
message/byte budgets before encoding or returning borrowed message slices.
`RequestRecord.prepare` fills caller-owned metadata/batch buffers and constructs
GRQ1. `stage` uses Station's shared resumable `PublicationUpload`; schedule later
turns until it returns true before admitting the call. Source buffers remain the
caller's responsibility. Namespace reuse or changed identity fails explicitly.
`read` checks current resource availability for every bounded part. After both
records are read, `validateContent` checks their commitments, shape and descriptor
identity; it returns an owned request. A digest does not validate an application's
protobuf schema or grant method access.

`Policy.Prepared` freezes numeric routing, TLS authority/trust, descriptor,
request/batch commitments, credential references, finite limits and response
metadata allowlist. Canonical parsing rejects alternate encodings. Explicit
idempotent retry preserves all fields and a nonempty literal key; it returns a
policy reference, never an execution permit. Other followup kinds are refused.

`Capture.emit` translates borrowed transport events into indexed message headers,
4 KiB body parts, filtered metadata and half-close records. Supply a sink that
seals each segment before returning. A sink error leaves its accepted prefix and
permanently disables that active capture. `finish` appends timing, omissions and
terminal counts; Exchange completion and the kernel observation remain separate
worker duties. Response metadata retains wire base64, duplicate order and explicit
omission counts. Default filtering cannot be treated as application protobuf
redaction; secret-bearing message bodies are outside this profile.

`Replay.open/read` uses Exchange's current-availability reader on every chunk.
It validates the frozen policy and directional coverage with fixed per-call
memory: a 65,544-byte batch buffer, 8 KiB metadata copy, bounded field hashes and
131,072-byte temporary parse arena. No history-sized allocation, sockets,
reflection or credential resolver is accepted. Returned prefixes are provisional;
only the final part has `complete=true`. Required omissions or a failed read are
explicit gaps; terminal status alone cannot establish complete coverage.

Limits are per call: 64 messages/direction, 16 KiB/message, 64 KiB outgoing and
256 KiB incoming framed bytes. GRB1's storage envelope needs at most 65,544 bytes,
including its own magic/count; wire accounting still charges five bytes/message.
Metadata has an 8 KiB canonical representation and at most 64 fields. Configured
endpoint limits can be smaller. No total retained-record limit is implied.

`Service` owns authenticated call/retry/disposal records and exact method, shape,
descriptor and metadata scope. Shared Exchange helpers enforce fixed reply routes,
current caller policy, duplicate identity and settlement before result publication.
Native GR* codecs preserve RPC status separately from unknown/not-dispatched
outcomes; they do not infer success from an absent status.

Run `just test::unit` for the package and independent Python contract fixture.
The fixture covers original Unicode/binary protobuf, duplicate/binary metadata,
secret references, empty messages and full-width namespace/revision identities.
Transport qualification and dependency provenance live in the transport package;
no fixture is evidence of a completed durable effect or deployment.

`just test::grpc-worker` runs the actual [worker](../../../apps/transit-station-grpc-worker/README.md)
over disk Ursula. [Proof details](../../../tests/README.md#m16-finite-connector-qualification)
record executed recovery schedules and remaining qualification.

## Read-only metadata

`Inspection.read` projects selected policy and terminal metadata from a currently
authorized `Exchange.Client.Reader`. It verifies the member commitment chain and
selected record bytes under one resource revision, scanning at most 256 members.
It loads no request metadata, batch, response metadata or protobuf body. Policy
output omits routing and credential references. Directional counts distinguish
indexed partial messages from a complete captured terminal result; status zero
remains present. This is bounded inspection, not full replay or remote computation
verification. Board's `grpc-test` / `grpc-browser` tasks exercise actual captures
and current authorization through this surface.

## Offline generated helpers

Build `zig build grpc-bindings`, then generate Zig request constructors from the
local descriptor output of pinned `protoc --include_imports --descriptor_set_out`:

```sh
zig-out/bin/transit-grpc-bindings tests/fixtures/grpc/peer.pb | zig fmt --stdin > /tmp/rpc-methods.zig
```

Each generated function is named by the exact method path, fixes its shape and
descriptor digest, and accepts ordered metadata references. For example,
`methods.@"/test.Peer/Bidi"(metadata)` returns a `Request` for ordinary
`RequestRecord.prepare`. These helpers generate no sockets, secret resolvers,
reflection or protobuf message codecs. Application message codecs remain separate.
The generator validates every method before emitting source and bounds descriptor
parsing as documented by the transport package. Foreign SDKs resolve the same
generated local descriptors through their typed method helper and shared Zig
codec. `just test::grpc-codegen` regenerates, compiles and uses all four shapes,
including malformed-descriptor rejection without partial output.
