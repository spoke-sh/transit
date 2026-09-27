# Finite RPC calls and captured replay

The public `Grpc` API shares request encoding, durable publication, call identity
and transcript verification with Zig. Bind a method using a local protoc
`FileDescriptorSet`; no remote reflection is used. The shared parser fixes the
exact path, streaming shape and complete descriptor digest. All four RPC shapes
use a finite outgoing batch committed before dispatch. Received messages cannot
produce additional sends on the same connection.

`Grpc.method(descriptorBytes, path)` returns `Grpc.Method`.
`Grpc.prepare(resource, namespace, request, messages, options)` returns an
immutable `Grpc.Prepared` with owned `Bytes`. Metadata is an ordered list of
`Grpc.Metadata` values containing either `Grpc.Literal(Bytes)` or
`Grpc.SecretRef(binding, BigInteger version)`. Duplicate and binary metadata are
preserved; message bytes are the original protobuf encoding. Full-width unsigned
identities use `BigInteger` and are validated before native access.

In a handler, `turn.stageGrpc(request)` advances one bounded upload step. Commit
false results and arrange another input. Once ready, call
`turn.callGrpc(connector, request)` and persist its returned correlation in the
same turn. Reconstruct the exact request after fresh ownership to resume staging.
`Grpc.ReplyCodec<T>` provides explicit `Application<T>` and `Received<T>` messages;
authenticate replies with `turn.requireReply` before using outcomes or control
acknowledgements. `Outcome.status()` is an `OptionalInt`: zero is observed `OK`,
while unknown outcomes have no status or complete replay reference.

`runner.openGrpc(outcome)` opens a runner-owned `Grpc.Reader`. `read()` returns a
`CompletableFuture<Optional<Grpc.Part>>`; each part owns at most 256 bytes. Read to
validated completion and close with `closeAsync()` or synchronous `close()`.
Cancellation invalidates the local reader and does not cancel remote execution.
Close joins outstanding native work. Already copied parts survive runner close.

`turn.retryGrpc(connector, parent, request)` requests an explicit linked attempt;
`turn.releaseGrpc(connector, resource, exchange)` releases the caller hold.
Both return correlations to persist and authenticate on reply. Duplicate release
remains safe after cleanup without a transcript read grant.

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

`just bindings::java-sdk-test` exercises clean installed packages against the
actual worker and independent TLS peer. It covers staged host replacement,
full-width identities, original binary/Unicode protobuf, status zero, authenticated
outcome/control replies, prefix revocation, sticky replay, joined cancellation,
retry refusal without a child/send and disposal before/after cleanup. Shared
fixtures also distinguish unknown from zero and reject truncated outcomes. See
[executed proof details](../../../../tests/README.md).
