# gRPC connector

Status: the finite [M16](roadmap/M16.md) profile is implemented and locally
qualified after [HTTP M15](roadmap/M15.md). The Zig [transport](../packages/zig/transit-grpc/README.md),
[durable adapter](../packages/zig/transit-station-grpc/README.md), actual worker,
ten language SDKs, Board and local/Compose/reference example have executed proofs.
[Tests](../tests/README.md) separates those results from deferred hosted CI costs.
The [RPC contract](../contracts/STATION_GRPC_V1.md) owns exact formats; the shared
[effect boundary](CONNECTORS.md#effect-boundary) and
[bounded reconciliation contract](CONNECTORS.md#bounded-reconciliation-contract)
apply without weakening expiry, fencing or replay rules.

The connector reuses M15's Exchange lifecycle and M14 Publication for immutable
request/capture bytes, current-policy reads, exact settlement, descendant budgets
and bounded cleanup. It fixes a finite outgoing batch and half-close before one
exact effect dispatch. Responses may arrive concurrently but cannot create later
sends on that connection. All four method shapes are qualified in this profile.
An authorized predecessor without complete captured evidence closes unknown;
recovery never replays a sent prefix or implicitly reconnects. Interactive sends
and live connection handoff remain separate, unimplemented extensions.

## Purpose and ownership

Station callers describe remote RPC work in durable messages; a trusted Zig
connector worker performs authorized attempts and records observations. The
caller waits through its mailbox and durable correlation state, not a handler
blocked on a live socket. Generated service helpers construct intents; they
cannot open network connections or resolve credentials as a side effect.

M16 implements unary, server-streaming, client-streaming and bidirectional methods
with explicit finite call/message/byte budgets. gRPC orders messages within each
direction of a call; the directions are independent. It does not provide a
durable replay log. See [gRPC's call model](https://grpc.io/docs/what-is-grpc/core-concepts/).
Unlimited history retention remains the default; it does not imply an unlimited
live RPC. Indefinite subscriptions need an application resume/rotation contract.

The connector and its protocol handling are Zig native. Pinned HTTP/2, HPACK,
protobuf and TLS dependencies have independent-peer proofs. Compression is
identity-only; compressed messages reject explicitly. Foreign grpcio and h2
implementations are test peers, not worker runtime dependencies. The transport must also leave room for the later [Flight gateway](ARROW.md),
whose ingress and query authorization are separate from outbound effect authority.

## Durable call and transcript

A versioned call descriptor binds the caller PID/turn, effect/attempt identity,
target authority, fully qualified service/method, call shape, schema/descriptor
digest, deadline, budgets, capture/retention policy and credential references.
Pin service descriptors; reflection must not silently introduce a network call
or change the schema during replay.

Use an exchange group with a manifest, request messages, attempt observations,
response messages and terminal completion. Each direction has its own monotonically
ordered message indices. Record permitted initial metadata, request half-close,
response trailers, gRPC status, transport errors, observation timing and capture
gaps. A half-close ends only the request direction; it is not call completion.
Local observation order cannot invent a total order or server-side causality
between concurrent request and response messages.

Capture original serialized protobuf message bytes before decoding, subject to
the declared secret omissions; re-encoding a parsed message is not byte-exact
capture. Distinguish application messages from HTTP/2 frames and compressed wire
bytes. Bound both wire and expanded sizes, nested decoding and metadata counts.
Preserve binary/duplicate metadata semantics. Credentials and secret-bearing
fields use typed references and omission markers; do not store rendered secrets
or claim a complete byte transcript where redaction occurred.

Final publication names already durable messages, their order/coverage and the
terminal status. `OK` is insufficient if required capture is incomplete. Partial
messages can be delivered as explicitly provisional observations after durable
capture, with a separately recorded terminal outcome. Applications that act on
partial responses need their own partial-progress policy; later failure cannot
roll back already committed turns or external actions.

## Streaming authority and backpressure

The implemented permit covers one committed finite batch. An interactive
streaming-send extension would additionally need the following obligations:

- Every outgoing message or finite batch must have committed content/identity
  and a dispatch authorization covering that exact work, method, destination,
  credentials and budget. Initial call authorization is not permission for
  arbitrary later messages. Newly authorized sends require current policy;
  already authorized sends retain the existing potentially-in-flight semantics.
- Serialize stream progress, request half-close and completion through durable
  connector state. Fence executor handoff and result acceptance; a live HTTP/2
  connection is not transferable proof of ownership. Where current kernel
  primitives are insufficient, define a versioned generic extension and its
  conformance proof rather than relying on worker conventions.
- Bound request/response queues, live calls, bytes and capture work. Stop pulling
  before capacity is exhausted; control progress must survive a blocked peer.
  Receiving flow-control credit or completing a transport write is not evidence
  of durable remote admission. Publish observations only after local capture.
  This is application admission credit, not transport flow control; specify it
  as an instance of [FLOW_CONTROL.md](FLOW_CONTROL.md)'s pattern (the captured
  message/attempt as the credit unit) rather than a bespoke scheme.

[gRPC flow control](https://grpc.io/docs/guides/flow-control/) regulates transport
pressure; it does not acknowledge the application's durable handling. Exercise
both directions independently so two peers waiting for the other to drain cannot
exhaust worker capacity. Transcript exhaustion closes with an explicit capture
failure/unknown outcome under policy; it never silently drops messages or marks
a partial transcript complete.

## Failure, retries and reconciliation

The worker may lose the connection after the remote method has applied a change
but before any response is durably recorded. Deadlines, cancellation, non-OK status
and ownership loss do not prove rollback. Recovery reads the transcript, then
uses the method's explicit idempotency/status/reconciliation contract or records
an unknown outcome. A status lookup or remote cancellation is itself authorized
external work under the original finite reconciliation policy.

Disable hidden retries, hedging and service-config retry policies in the first
profile. The [gRPC retry guide](https://grpc.io/docs/guides/retry/) documents
transparent retries even without an application retry policy. Qualify the chosen
transport's actual behavior; every fresh RPC attempt must remain visible and
authorized, including replacement streams after connection failure. TCP byte
retransmission within an existing connection is a different mechanism.

Do not restart a partially sent client/bidirectional stream merely because a new
worker owns the connector. Resuming requires an explicit remote protocol for
message identities, accepted offsets and duplicate handling; gRPC alone supplies
none of that durable contract. Without it, preserve the partial transcript and
settle under bounded unknown-outcome policy. M16 need not implement generic
automatic resumption to support bounded streaming methods honestly.

[gRPC cancellation](https://grpc.io/docs/guides/cancellation/) is cooperative.
Record requested cancellation separately from observed remote outcome. When
reconciliation closes, reject late result admission permanently; the remote
system may still finish. Previously accepted provisional observations remain
historical evidence. Replay uses those records without dialing, sending,
resolving secrets or running reflection.

## Security, inspection and qualification

Authorize destination resolution, authority/SNI, TLS identity, method and secret
scope together. Deny credential forwarding to an unapproved alternate endpoint;
connection pooling cannot mix realms or credential scopes. Authenticate captured
results against the attempt and executor, not user-supplied metadata. Apply
current read policy to descriptors, transcripts and referenced bodies.

Board may explain framework call/attempt identity, direction, message counts,
timing, half-close and terminal evidence. It does not decode arbitrary protobuf
application values. Service logs/metrics remain bounded diagnostics; they must
not contain credentials, raw messages or unbounded method/target labels. Follow
[Security](SECURITY.md) and [Observability](OBSERVABILITY.md).

[M16](roadmap/M16.md) owns interoperation tests, crash/revocation schedules and
reference deployment qualification. Server-side hosting of arbitrary application
gRPC services, gRPC-Web and automatic remote-stream resumption are outside its
first profile. [M19](roadmap/M19.md) first formalizes [serving](SERVING.md) with
HTTP; M22 adds the specific Flight/Flight SQL ingress adapter over that foundation.
Neither HTTP serving nor the outbound gRPC client proves an inbound gRPC server.
