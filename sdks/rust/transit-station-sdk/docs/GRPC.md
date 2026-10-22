# Finite RPC calls

`grpc_method(descriptor_bytes, path, native_directory)` binds a local pinned
`FileDescriptorSet` through Zig. `GrpcRequest` contains that method and ordered
`GrpcMetadata` values (`Literal(Vec<u8>)` or immutable binding/version `Secret`).
`prepare_grpc(resource, namespace, &request, &[&message, b""], options, directory)`
returns owned metadata, original-message batch and commitment bytes. Descriptor
binding performs no reflection, credential lookup or RPC. Application-generated
protobuf codecs remain separate from durable call construction.

A handler calls `turn.stage_grpc(&prepared)` once per scheduled input until true,
then `turn.call_grpc(peer, &prepared)` and saves the returned correlation in state.
The shared Zig uploader resumes after host loss from identical recoverable source
bytes; Rust fields are not durable state. The fixed batch and half-close cannot
change in response to peer messages. Limits are 64 messages/direction, 16 KiB per
message, 64 KiB outgoing and 256 KiB incoming framed bytes, 64 metadata fields/8 KiB.
These bounds apply per call, independently of retained history cardinality.

`GrpcReplyCodec<T>` wraps an application codec and yields `GrpcMessage<T>` with
application values or `GrpcReply::{Outcome, Rejected, Released}`. Authenticate the
recorded peer/correlation with `turn.require_reply`. An observed `GrpcOutcome`
status is `Some(0)` for `OK`; closed unknown has `None` and no complete reference.
Status is RPC evidence, not business success.

`runner.open_grpc(&outcome, GrpcReplayPolicy::Captured)` returns a reader borrowing
its runner mutably. Reads own their part bytes and recheck current authorization;
prefixes remain provisional until verified completion. Rust prevents overlapping
runner operations and use after close through this borrow. Failed protocol or
authority reads remain failed. `close`/`Drop` release local reader state only;
runner shutdown joins native work. No remote cancellation or rollback is implied.

`turn.retry_grpc(peer, &parent, &prepared)` explicitly requests a new linked attempt.
Service policy separately enforces remote idempotency and original deadline/budget.
`turn.release_grpc(peer, resource, exchange)` requests durable hold disposal;
authenticate the `Released` reply. Neither is implicit in replay or destruction.

`just bindings::rust-sdk-test` includes an installed RPC caller against the actual
Zig worker, interrupted upload recovery, binary/Unicode/full-width messages,
duplicate metadata, revoked replay prefixes, owned data after close, joined native
work, retry refusal and disposal before/after cleanup. See the
[shared contract](../../../../contracts/STATION_GRPC_V1.md) and
[proof guide](../../../../tests/README.md) for limits and separate transport evidence.

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/handbook/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `runner.grpc_diagnostic(&outcome, kind)` after the runner has no pending
mutation. Select `ExchangeDiagnosticKind::CaptureFailure` or `ExchangeDiagnosticKind::NativeEffect`; the result is `Result<Option<serde_json::Value>>`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/handbook/reference/sdks.md#structured-failure-details).
