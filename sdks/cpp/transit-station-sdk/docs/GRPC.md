# Typed RPC calls and owned replay

The C++ RPC API delegates descriptor validation, immutable request publication,
call framing and transcript validation to shared Zig. It supports unary,
server-streaming, client-streaming and bidirectional methods with one finite
outgoing batch fixed before dispatch. Runtime reflection and automatic retries
are unsupported. See the [worker](../../../../apps/transit-station-grpc-worker/README.md)
for endpoint, TLS, credential and deployment configuration.

Bind a method from a local protoc `FileDescriptorSet`. The shared parser binds
its full descriptor digest, exact method path and streaming shape. Preserve
original protobuf bytes; metadata is ordered and supports duplicate fields,
binary literals and versioned secret references. The message count is at most
64, each message at most 16 KiB, with 64 KiB total framed outgoing bytes and
8 KiB canonical metadata. Empty messages and an empty batch are distinct.

`grpc_method(descriptor, path)` returns a `GrpcMethod`;
`prepare_grpc(resource, namespace_id, request, messages, options)` returns an
immutable `PreparedGrpcRequest`. Byte accessors return owned copies.
Use `turn.stage_grpc(request)` until publication is complete, committing each
step and arranging another input. Then `turn.call_grpc(connector, request)` and
the persisted correlation share one turn. Reconstruct the exact prepared
request after fresh ownership to resume committed upload.

`GrpcReplyCodec<T>` wraps an application codec in `GrpcMessage<T>`, an explicit
variant of application values, `GrpcOutcome` and `GrpcReleased`. Authenticate
the outer reply with `turn.require_reply` before using it. The outcome's optional
status preserves zero (`OK`) separately from an unknown result.

`runner.open_grpc(outcome)` returns a move-only `GrpcReader`. Read until validated
completion, then close it. Each part owns at most 256 bytes and survives reader
and runner disposal. Destruction attempts local close. Reads after runner close
fail CLOSED. `turn.retry_grpc(connector, parent, request)` submits an explicit
linked attempt; `turn.release_grpc(connector, resource, exchange)` releases the
durable hold. Persist and authenticate each returned correlation.

Replay checks current resource authority on every read; prefixes are provisional
until completion. Failure invalidates the reader even if access is later restored;
close and reopen under current authority. Replay uses captured data and needs no
remote connection or credential resolution. One RPC reader is active per runner;
overlapping operations and pending uncertain mutations reject.

Local reader disposal does not cancel a remote call or release durable history.
Explicit retry requires a worker policy allowing the identical request under its
original deadline and attempt budget. Releasing a hold does not retire or erase
capture. These control calls require a fresh worker `poll` activation. Close joins
owned native work; join application threads before destroying public handles.

`just bindings::c-sdk-test` compiles C11 callbacks and C++17 consumers from clean
installed archives. Both pass the real TLS worker schedule with upload recovery,
full-width identity, original protobuf, correlated status zero, prefix revocation,
sticky failure, credential-free replay, joined close, explicit retry refusal and
authenticated disposal before and after cleanup without a read grant. See the
[proof details](../../../../tests/README.md).

Outcome and rejection values own `diagnostic()` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/handbook/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `runner.grpc_diagnostic(outcome, kind)` after the runner has no pending
mutation. Select `ExchangeDiagnosticKind::CaptureFailure` or `ExchangeDiagnosticKind::NativeEffect`; the result is `std::optional<std::string>` containing owned diagnostic JSON.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/handbook/reference/sdks.md#structured-failure-details).
