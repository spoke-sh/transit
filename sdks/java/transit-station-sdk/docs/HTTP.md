# HTTP calls and captured replay

`io.transit.sdk.station.Http` exposes typed HTTP values through the shared Zig
bindings. It requires the native `http_requests` and `http_replay` capabilities.
The [finite worker](../../../../apps/transit-station-http-worker/README.md) owns
endpoint scope, credentials and actual network execution. Its initial profile
admits one root call per provisioned connector PID.

```java
Http.Prepared request = Http.prepare(
    new ResourceRef(realm, resource), namespace,
    new Http.Request(Http.Method.POST,
        List.of(new Http.Literal("/items/"), new Http.Variable("id", "λ /")),
        List.of(new Http.Header("Authorization", List.of(
            new Http.Literal("Bearer "),
            new Http.SecretRef("api", BigInteger.valueOf(7)))))),
    body, new Http.Options(endpointRevision, reconcileBeforeMillis, 1));
```

Request lists and prepared byte values are immutable copies. Namespace, endpoint
revision and secret version use `BigInteger` with unsigned 64-bit validation.
Resources and deadlines use bounded native counters. The body limit is 64 KiB;
canonical metadata is limited to 8 KiB. Secret pieces carry binding/version
references. Pure preparation and reply decoding use an owned local native host,
without credentials or Transit authority, and join it before returning.

In a handler, `turn.stageHttp(request)` stages one bounded publication step.
When it returns false, commit and arrange another application input. A true result
means both immutable request records were committed before this turn; call
`turn.callHttp(connector, request)` and persist its correlation in that same turn.
The application guards against starting another call after that correlation is
committed. Reconstruct the exact request after fresh ownership to resume upload,
keeping the original body available until publication. A namespace permanently
identifies one request and cannot be repurposed. Observe committed runner events;
a handler return is not a durable acknowledgement.

`Http.ReplyCodec<T>` wraps an application codec as `Codec<Http.Message<T>>`.
Handlers receive an explicit `Http.Application<T>` or `Http.Received<T>` value.
The wrapper reserves exact `HTR1`/`HTF1`/`HTK1` prefixes and rejects reply encoding.
`Http.Received` carries a disposal acknowledgement, admission rejection or an outcome whose phase is
observed, closed unknown or not dispatched. Only observed outcomes have complete
capture references; HTTP status is not business success. Authenticate the outer
`Types.Reply` using `turn.requireReply(reply, connector, persistedCorrelation)`
before trusting a decoded outcome. Cast payloads do not become replies merely
because they contain a valid outcome.

Outside handler callbacks, `runner.openHttp(outcome)` returns a
`CompletableFuture<Http.Reader>`. Its default captured policy reports omissions;
`REQUIRE_UNREDACTED` rejects missing required data. Each `reader.read()` returns
a future of an optional owned part, bounded at 256 bytes, and rechecks current
resource authorization. Empty means end of stream. `reader.complete()` becomes
true only after validated completion; earlier prefixes remain provisional.
Replay performs no HTTP request and requires no credential resolution.

Only one reader may be active per runner. Pending uncertain mutations and
overlapping work reject. A failed read is sticky; restoring permission requires
close/reopen. Host materialization failure also poisons the reader. Cancelling a
read future invalidates it because the native cursor may already have advanced.
Cancellation does not interrupt native ownership: stop and close the runner to
join outstanding work. Cancelling an open future can lose the returned handle;
close the runner to release its reserved reader. No future cancellation promises
remote HTTP cancellation or releases durable capture dependencies.

`reader.closeAsync()` disposes the local cursor; `reader.close()` waits for it.
Blocking close rejects from handler/completion callbacks; use asynchronous close
there. Close is idempotent while the runner remains open. Runner close joins and
invalidates all readers, whose later reads fail `CLOSED`; returned immutable
`Bytes` remain valid. Local disposal does not retire capture or release its
durable caller hold. Applications own that explicit lifecycle decision.

Inside a handler, `turn.releaseHttp(connector, outcome.resource(), outcome.exchange())`
requests disposal of that durable hold. Persist the correlation, authenticate
`Http.Released` with `turn.requireReply`, and check its resource/exchange.
Duplicate calls remain safe after worker restart and capture cleanup. No
transcript read grant is needed; the service checks its recorded holder and
current admission policy. Release performs no remote cancellation, retirement
or member cleanup. The finite worker needs a fresh `poll` activation to handle it.

`turn.followupHttp(connector, parent, Http.FollowupReason.RETRY, request)` records
an explicit linked-attempt call. Other reasons are `REDIRECT`, `RECONCILE` and
`CANCEL`. Publish the proposed request in the current associated resource first,
preserving the original deadline and total attempt budget. Save the correlation
and authenticate the resulting outcome or rejection. The shared service validates
the original caller, current scope and frozen parent policy before allocating a
child; this helper performs no automatic retry or retry-safety inference. Configure
a fresh child exchange and matching parent/reason on the finite worker. The parent
outcome remains unchanged.

`just bindings::java-sdk-test` runs installed JAR consumers through shared golden
fixtures and the independent TLS caller/recovery/revocation/disposal schedule,
alongside client and Station regressions. See the
[proof guide](../../../../docs/history/qualification/runtime.md#m15-connector-work-in-progress) for
executed evidence. Native allocation failure checks and Java host allocation
fault injection are distinct qualifications.

Outcome and rejection values own `diagnostic()` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/handbook/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `runner.httpDiagnostic(outcome, kind)` after the runner has no pending
mutation. Select `ExchangeDiagnosticKind.CAPTURE_FAILURE` or `ExchangeDiagnosticKind.NATIVE_EFFECT`; the result is `CompletableFuture<Optional<JsonObject>>`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/handbook/reference/sdks.md#structured-failure-details).
