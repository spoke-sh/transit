# Typed HTTP calls and asynchronous replay

`Transit.Station.Sdk.Http` delegates request construction, immutable publication,
call framing and capture validation to the shared Zig implementation. It requires
the `http_requests` and `http_replay` capabilities. The
[finite worker](../../../../apps/transit-station-http-worker/README.md) owns actual
HTTP execution, endpoint scope and secret resolution; its initial profile admits
one root call per provisioned connector PID.

```csharp
Http.Prepared request = await Http.PrepareAsync(
    new ResourceRef(realm, resource), requestNamespace,
    new(Http.Method.Post,
        [new Http.Literal("/items/"), new Http.Variable("id", "λ /")],
        [new("Authorization", [new Http.Literal("Bearer "),
                               new Http.SecretRef("api", 7)])]),
    body, new(endpointRevision, reconcileBeforeMillis));
```

Preparation copies all request lists and body bytes before its first asynchronous
wait. `Prepared` and `Bytes` own immutable data; `Copy()` returns independent byte
arrays. Namespace and endpoint/secret versions preserve full `ulong` width.
Resource IDs and deadlines obey native counter bounds. Requests are limited to
64 KiB of body and 8 KiB of canonical metadata. Secret pieces contain references,
not credential values. Preparation and `DecodeReplyAsync` use their own bounded
native worker without credentials or authority operations.

Inside a synchronous handler, `turn.StageHttp(request)` adds one bounded upload
step. On false, commit the turn and arrange another application input. On true,
`turn.CallHttp(connector, request)` may share the turn with persisting its returned
correlation. Both immutable records were committed before that turn. Check the
persisted correlation to avoid starting another call. Reconstruct the exact
request after fresh ownership to resume upload, retaining the original body until
publication. A namespace permanently identifies one request. Observe committed
runner events; callback completion alone is not durable acceptance.

`Http.ReplyCodec<T>` wraps an application codec as `ICodec<Http.Message<T>>`.
It returns `Http.Application<T>` or `Http.Received<T>` using shared native decoding
for exact `HTR1`/`HTF1` prefixes. The outcome branch is receive-only. A synchronous
decode joins its separate bounded worker; callbacks remain synchronous.
`Http.Received` contains rejection or observed/closed-unknown/not-dispatched
outcomes. Authenticate the outer `Reply<Http.Message<T>>` with
`turn.RequireReply(reply, connector, persistedCorrelation)` before using it.
Typed outcome bytes alone do not authenticate origin. Only observed outcomes
have complete references; HTTP status does not establish business success.

`await runner.OpenHttpAsync(outcome)` opens one runner-owned capture reader.
`ReadAsync()` returns an owned part of at most 256 bytes, or null at end. Each
read checks current resource authority. Only `reader.Complete` establishes
validated capture completion; prefixes are provisional. Captured policy reports
omissions, while `RequireUnredacted` rejects missing required data. Replay makes
no HTTP requests and does not resolve credentials.

Overlapping operations and pending uncertain mutations reject. Failed reads are
sticky, including failure to materialize an owned part: restore authority, close
and reopen. A cancelled read wait invalidates the reader because native progress
may already have advanced. Native work remains owned; stop and asynchronously
dispose the runner to join it. Cancelling an open wait may lose the returned
handle, so close the runner to release its slot. Cancellation does not promise
remote HTTP cancellation or release durable capture holds.

`CloseAsync`, `DisposeAsync` and `Dispose` close the local reader. Synchronous
disposal rejects callback reentry. Close is idempotent while its runner is open;
after runner disposal, reads fail `Closed`. Previously returned immutable bytes
remain usable. Local disposal does not retire capture or release its durable
caller dependency. Use explicit lifecycle operations for those changes.

`just bindings::dotnet-sdk-test` runs clean NuGet consumers through shared golden
fixtures and the independent TLS/recovery/revocation/cancellation schedule, plus
the existing client and Station regressions. The
[proof guide](../../../../tests/README.md#m15-connector-work-in-progress) records
executed results and remaining qualification. Native allocation proofs do not
imply fault-injected managed allocation coverage.
