# Typed HTTP calls and owned replay

Include `transit/station.hpp` and use `transit::sdk::station`. The C++17 API adds
owned values, a reply-codec union and move-only replay readers over the
[C SDK's shared native boundary](../../../c/transit-station/docs/HTTP.md).
The current worker's finite admission and deployment rules are documented
[beside the worker](../../../../apps/transit-station-http-worker/README.md).

```cpp
auto request = prepare_http(
    ResourceRef(realm, request_resource), request_namespace,
    {HttpMethod::Post,
     {HttpLiteral{"/items/"}, HttpVariable{"id", "λ /"}},
     {{"Authorization", {HttpLiteral{"Bearer "}, HttpSecretRef{"api", 7}}}}},
    body, {endpoint_revision, reconcile_before_ms, 1});
```

`PreparedHttpRequest` owns immutable copies; its byte getters return copies and
copying the prepared value shares immutable storage. Full-width namespace and
endpoint/secret revision values remain `uint64_t`. Secret pieces are references.
The shared Zig implementation validates and serializes all request data. Header
order and duplicate fields are preserved. The 64 KiB body and 8 KiB canonical
metadata limits are explicit.

In a scoped handler, `turn.stage_http(request)` contributes one bounded upload
step. When it returns false, commit and arrange another application input. A true
result permits `turn.call_http(connector, request)` in that same turn; persist
its correlation with application state. Reconstruct the exact request after
fresh ownership to continue committed upload. The application keeps its source
body available until publication and guards against another call after the
correlation has committed. Namespace reuse with different content is rejected.

Wrap an application codec in `HttpReplyCodec<Message>` and use
`Handler<HttpMessage<Message>>`. `HttpMessage` is an explicit variant of the
application value, `HttpOutcome` and `HttpReleased`. Exact `HTR1`/`HTF1`/`HTK1` prefixes are reserved for
shared reply decoding; encoding a reply through this receive-only codec
fails. Inspect the outer `Reply` variant and call
`turn.require_reply(original_connector, persisted_correlation)` before using
the outcome. Typed decoding does not authenticate origin.

`HttpOutcome` distinguishes rejection, observed, closed unknown and not
dispatched. Its optional status is HTTP status, not business success. Only an
observed outcome has a complete reference. `decode_http_reply` also supports
explicit decoding outside a handler.

```cpp
auto reader = runner.open_http(outcome, HttpReplayPolicy::Captured);
while (auto part = reader.read()) {
    // part->data owns at most 256 bytes; prefixes remain provisional.
}
if (!reader.complete()) throw std::runtime_error("incomplete capture");
reader.close();
```

There is one active reader per runner. Current authorization is checked on every
read; pending mutations and overlapping operations reject. A read failure is
sticky until close/reopen, including host allocation failure when copying a
returned part. `RequireUnredacted` rejects missing required data; captured mode
reports omissions. Replay never resolves credentials or refetches HTTP data.

`HttpReader` is move-only; destruction attempts local close. It may outlive its
runner safely: reads then fail `CLOSED`, while already returned `Bytes` remain
owned. Close joins native work; stop does not cancel remote execution or release
durable holds. Join application threads before destroying handles. Reader
disposal is local and does not authorize capture retirement.

To release the durable caller hold, use
`turn.release_http(connector, outcome.resource(), outcome.exchange())` inside a
handler and persist its correlation. Authenticate the subsequent `HttpReleased`
with `turn.require_reply`, then check `resource()` and `exchange()`.
`decode_http_released` also decodes acknowledgement bytes outside a handler.
Duplicate disposal remains safe after restart and cleanup without a transcript
read grant; the service checks the recorded holder and current admission policy.
Release does not perform remote cancellation, retirement or cleanup. The finite
worker needs a fresh `poll` activation to handle it.

Use `turn.followup_http(connector, parent, HttpFollowupReason::Retry, request)`
for an explicit linked-attempt call. Other reasons are `Redirect`, `Reconcile`
and `Cancel`. Publish the proposed request in the current associated resource
first, preserving the original deadline and total attempt budget. Save the new
correlation and authenticate the resulting `HttpOutcome`, which may contain a
rejection. The shared service validates the original caller, current scope and
frozen parent policy before allocating a child. The helper performs no automatic
retry or retry-safety inference. Configure a fresh child exchange and matching
parent/reason on the finite worker. The parent outcome remains unchanged.

The installed C++ consumer in `just bindings::c-sdk-test` checks shared golden
fixtures, typed correlation, staged upload recovery, current grant revocation,
owned replay after disposal and joining a delayed read. The same schedule runs
through compiled C11 callbacks. Host allocation poisoning is implemented but
fault-injected host allocation qualification remains separate from the shared
native allocation proofs.

Outcome and rejection values own `diagnostic()` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/reference/sdks.md#structured-failure-details).
