# transit-station-grpc

The M16 Zig adapter composes [Exchange](../transit-exchange/README.md), Station
Publication and the finite [RPC transport](../transit-grpc/README.md). Its
[versioned contract](../../../contracts/STATION_GRPC_V1.md) describes the finite
batch authority profile. Worker, durable response capture and SDK qualification
are in progress; the request codec alone does not authorize an RPC.

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

Limits are per call: 64 messages/direction, 16 KiB/message, 64 KiB outgoing and
256 KiB incoming framed bytes. GRB1's storage envelope needs at most 65,544 bytes,
including its own magic/count; wire accounting still charges five bytes/message.
Metadata has an 8 KiB canonical representation and at most 64 fields. Configured
endpoint limits can be smaller. No total retained-record limit is implied.

Run `just test::unit` for the package and independent Python contract fixture.
The fixture covers original Unicode/binary protobuf, duplicate/binary metadata,
secret references, empty messages and full-width namespace/revision identities.
Transport qualification and dependency provenance live in the transport package;
no fixture is evidence of a completed durable effect or deployment.
