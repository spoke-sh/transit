# Finite RPC calls

`Transit::Station.grpc_method(descriptor_bytes, path)` binds an explicitly supplied
local descriptor set through Zig, with no reflection, connection or credentials.
Construct `GrpcRequest(method:, metadata:)` with ordered `GrpcMetadata(name:, value:)`;
values are binary strings or `GrpcSecretRef(binding:, version:)`. Application
protobuf serialization remains in the application.

`prepare_grpc(resource, namespace, request, messages: [protobuf_bytes, ''.b],
endpoint_revision:, reconcile_before_ms:)` copies/freeze-owns the resulting metadata,
GRB1 batch and GRQ1 reference. Keep identical inputs recoverable across host loss.
In a handler, call `turn.stage_grpc(request)` per scheduled input until true, then
`turn.call_grpc(peer, request)` and save its correlation in durable state.
The finite batch/half-close grants no response-dependent sends. The per-call profile
allows 64 messages/direction, 16 KiB/message, 64 KiB outgoing and 256 KiB incoming
framed bytes, and 64 metadata fields/8 KiB, independently of total retained calls.

`GrpcReplyCodec.new(application, realm:)` returns typed `GrpcOutcome`, `GrpcRejected`
and `GrpcReleased` records. Match reply origin and saved correlation with
`turn.require_reply`. Status `0` belongs to an observed `OK`; closed unknown has
`nil` status and no complete reference. RPC status does not establish business success.

`runner.open_grpc(outcome)` returns an owned reader with frozen 256-byte parts.
One RPC reader is admitted independently of HTTP. Each read checks current access;
only `complete` establishes verified directional coverage. Revocation poisons the
reader. Reopening requires current permission. Close the reader in `ensure`;
runner close joins native work, including interrupted host waits. Reader disposal
neither releases a durable hold nor promises remote cancellation or rollback.

`turn.retry_grpc(peer, parent, request)` explicitly submits a linked attempt for
current service policy to validate. No transparent retry or stream resume exists.
`turn.release_grpc(peer, resource, exchange)` requests durable hold disposal; verify
the correlated `GrpcReleased` response. Scope checks still reject retained turns,
wrong-thread/fiber calls and cross-realm identities.

`just bindings::ruby-sdk-test` includes the installed RPC caller proof: interrupted
upload recovery, binary/Unicode/full-width messages, duplicate metadata, revoked
prefixes, replay without secrets, joined interruption, retry refusal and disposal
before/after cleanup. The [shared contract](../../../../contracts/STATION_GRPC_V1.md)
and [proof guide](../../../../tests/README.md) separate native, transport and deployment evidence.

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/handbook/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `runner.grpc_diagnostic(outcome, kind: kind)` after the runner has no pending
mutation. Select `:capture_failure` or `:native_effect`; the result is an owned frozen diagnostic hash or `nil`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/handbook/reference/sdks.md#structured-failure-details).
