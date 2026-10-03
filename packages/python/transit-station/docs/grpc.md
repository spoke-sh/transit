# Finite RPC calls and replay

The M16 APIs compose the [shared RPC contract](../../../../contracts/STATION_GRPC_V1.md).
`grpc_method(descriptor_bytes, "/package.Service/Method")` resolves a local pinned
protoc descriptor set through Zig and returns `GrpcMethod(path, shape, digest)`.
It starts no connection, reflection or credential lookup. Application protobuf
codecs serialize messages separately; Transit preserves those original bytes.

```python
method = grpc_method(descriptor_bytes, "/test.Peer/Bidi")
request = prepare_grpc(
    resource, namespace, GrpcRequest(method, (
        GrpcMetadata("x-label", b"one"),
        GrpcMetadata("x-label", b"two"),
        GrpcMetadata("authorization", GrpcSecretRef("api", 7)),
    )), (protobuf_message, b""),
    endpoint_revision=7, reconcile_before_ms=deadline,
)
# In a handler, schedule another input while this returns False.
if turn.stage_grpc(request):
    correlation = turn.call_grpc(connector, request)
    turn.state.put(call_key, correlation)
```

Keep the prepared request's immutable source bytes recoverable across host loss.
Publication, the durable wait and call identity live in Transit; Python fields do
not replace them. A call fixes a finite message batch and half-close. Responses
cannot add outgoing messages to that connection. Limits are 64 messages/direction,
16 KiB/message, 64 KiB outgoing framed bytes and 256 KiB incoming framed bytes;
metadata admits 64 fields/8 KiB. Kernel turn limits remain unchanged.

Wrap an application codec in `GrpcReplyCodec(application, realm)`. It returns
`GrpcOutcome`, `GrpcRejected` or `GrpcReleased` for native records. Authenticate
reply origin and saved correlation with `turn.require_reply` before using them.
An observed outcome can have status `0` (`OK`); an unknown outcome has `status=None`
and no complete replay reference. RPC status does not establish business success.

`runner.open_grpc(outcome)` returns a context-managed `GrpcReader`; asynchronous
runners return `AsyncGrpcReader` with `async with` and awaited reads. The runner
owns one RPC reader independently of its HTTP reader. Reads return owned 256-byte
`GrpcPart` values; prefixes remain provisional until `complete=True`. Every part
rechecks current capture access. Revocation poisons that reader; reopening needs
current authorization. Closing a reader or cancelling a host wait does not dispose
a durable hold or cancel the remote operation. Runner shutdown joins native work.

`turn.retry_grpc(connector, parent, prepared)` records an explicit new linked call;
connector policy decides whether the unknown parent is safely retryable under its
original attempt budget/deadline. There is no automatic retry or stream resume.
`turn.release_grpc(connector, capture_resource, exchange)` explicitly requests
hold disposal; authenticate its correlated `GrpcReleased` response.

The installed RPC proof covers upload host replacement, binary/Unicode/full-width
protobuf, duplicate/binary metadata, correlated completion, revoked replay after
a prefix, joined async cancellation, retry refusal and disposal before/after cleanup.
It runs within `just bindings::python-test`; transport and worker crash evidence
remain separate [proofs](../../../../tests/README.md).

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/reference/sdks.md#structured-failure-details).
