# Finite RPC calls and captured replay

The public `Grpc` API shares request encoding, durable publication, call identity
and transcript verification with Zig. Bind a method using a local protoc
`FileDescriptorSet`; no remote reflection is used. The shared parser fixes the
exact path, streaming shape and complete descriptor digest. All four RPC shapes
use a finite outgoing batch committed before dispatch. Received messages cannot
produce additional sends on the same connection.

`Grpc.BindMethodAsync(descriptorBytes, path)` returns `Grpc.Method`.
`Grpc.PrepareAsync(resource, namespaceId, request, messages, options)` returns an
immutable `Grpc.Prepared`. Messages and literal metadata use owned `Bytes`;
metadata is an ordered list of `Grpc.Metadata` values containing `Grpc.Literal`
or `Grpc.SecretRef(binding, ulong version)`. Duplicate and binary metadata and
original protobuf bytes are preserved. Namespace and revision values use `ulong`.
Preparation copies all caller collections before its first asynchronous wait.

In a synchronous handler, `turn.StageGrpc(request)` advances one upload step.
Commit false results and arrange another input. Once ready, call
`turn.CallGrpc(connector, request)` and persist its returned correlation in that
same turn. Reconstruct the exact request after fresh ownership to resume staging.
`Grpc.ReplyCodec<T>` supplies explicit `Application<T>` and `Received<T>` messages.
Authenticate the outer reply with `turn.RequireReply` before using it. Nullable
`Outcome.Status` distinguishes observed zero (`OK`) from unknown, which has no
complete replay reference.

`runner.OpenGrpcAsync(outcome)` returns a runner-owned `Grpc.Reader`.
`ReadAsync(cancellationToken)` returns an owned part or null after validated
completion. Parts contain at most 256 bytes. Use `await using` or `CloseAsync`;
close joins outstanding native work. Cancelling a read invalidates its local
reader and does not cancel remote execution. Copied parts survive runner close.

`turn.RetryGrpc(connector, parent, request)` submits an explicit linked attempt;
`turn.ReleaseGrpc(connector, resource, exchange)` releases the caller hold.
Persist and authenticate the returned correlations. Duplicate release remains
safe after cleanup without a transcript read grant.

Limits are 64 messages, 16 KiB per message, 64 KiB total framed outgoing data,
8 KiB canonical metadata and 64 KiB for the local descriptor. Empty messages and
an empty batch differ. Secret metadata contains a reference, never a secret
value. Deployment fixes endpoint, TLS, method/shape/schema and credential scope;
see the [worker guide](../../../../apps/transit-station-grpc-worker/README.md).

Replay checks current resource policy for every part, including after returning
a prefix. Prefixes remain provisional until completion. Read failure is sticky;
close and reopen after policy restoration. Replay needs no dialing or secret
resolution. Pending uncertain mutations and overlapping operations reject.
Local reader disposal does not release durable history. Retry requires the exact
request, original deadline/attempt budget and explicit worker policy; it creates
a new effect and does not change the parent's outcome. Release does not retire
or erase capture. Control calls require a fresh worker `poll` activation.

`just bindings::dotnet-sdk-test` exercises clean installed packages against the
actual worker and independent TLS peer. It covers staged host replacement,
full-width identities, original binary/Unicode protobuf, status zero, authenticated
outcome/control replies, prefix revocation, sticky replay, joined cancellation,
retry refusal without a child/send and disposal before/after cleanup. Shared
fixtures also distinguish unknown from zero and reject truncated outcomes. See
[executed proof details](../../../../tests/README.md).
