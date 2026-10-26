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
for exact `HTR1`/`HTF1`/`HTK1` prefixes. The reply branch is receive-only. A synchronous
decode joins its separate bounded worker; callbacks remain synchronous.
`Http.Received` contains a disposal acknowledgement, rejection or observed/closed-unknown/not-dispatched
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

Inside a handler, `turn.ReleaseHttp(connector, outcome.Resource, outcome.Exchange)`
requests disposal of that durable dependency. Save its correlation in state,
authenticate the subsequent `Http.Released` with `turn.RequireReply`, and check
the resource/exchange. Duplicates remain safe after worker restart and capture
cleanup. Transcript read access is unnecessary; the service checks the recorded
holder and current admission policy. Release does not cancel remote work, retire
the capture or clean up its members. The finite worker handles it in a fresh
`poll` activation.

`turn.FollowupHttp(connector, parent, Http.FollowupReason.Retry, request)` records
an explicit linked-attempt call. Other reasons are `Redirect`, `Reconcile` and
`Cancel`; invalid enum values reject. Publish the proposed request in the current
associated resource first, preserving the original deadline and total attempt
budget. Save the correlation and authenticate its outcome or rejection. The shared
service checks the original caller, current scope and frozen parent policy before
allocating a child. This helper performs no automatic retry or retry-safety
inference. Configure a fresh child exchange and matching parent/reason on the
finite worker. The parent outcome remains unchanged.

`just bindings::dotnet-sdk-test` runs clean NuGet consumers through shared golden
fixtures and the independent TLS/recovery/revocation/cancellation schedule, plus
the existing client and Station regressions. The
[proof guide](../../../../docs/history/qualification/runtime.md#m15-connector-work-in-progress) records
executed results and remaining qualification. Native allocation proofs do not
imply fault-injected managed allocation coverage.

Outcome and rejection values own `Diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/handbook/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `await runner.HttpDiagnosticAsync(outcome, kind)` after the runner has no pending
mutation. Select `ExchangeDiagnosticKind.CaptureFailure` or `ExchangeDiagnosticKind.NativeEffect`; the result is an owned `JsonObject` or `null`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/handbook/reference/sdks.md#structured-failure-details).
