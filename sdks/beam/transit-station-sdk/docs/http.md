# HTTP calls and immutable reader tokens

`transit_http` exposes the M15 HTTP API using ordinary records, binaries and tagged
results. Shared Zig owns request construction, immutable publication, call framing
and capture validation. The native `http_requests` and `http_replay` capabilities
are required. The [finite worker](../../../../apps/transit-station-http-worker/README.md)
owns exact endpoint scope, credential resolution and network execution. Its
initial profile admits one root call per provisioned connector PID.

```erlang
-include_lib("transit_station_sdk/include/transit_station_sdk.hrl").
Request = #transit_http_request{
    method = post,
    target = [{literal, <<"/items/">>}, {variable, <<"id">>, <<"λ /"/utf8>>}],
    headers = [{<<"Authorization">>,
                [{literal, <<"Bearer ">>}, {secret, <<"api">>, 7}]}]},
{ok, Prepared} = transit_http:prepare(
    Resource, Namespace, Request, Body,
    #{endpoint_revision => Revision, reconcile_before_ms => Deadline}).
```

Methods are `get`, `head`, `post`, `put`, `patch`, `delete` and `options`.
Header order and duplicates are preserved. Pieces distinguish literal bytes,
named ordinary UTF-8 variables and versioned secret references. The prepared
record contains immutable owned reference, metadata and body binaries. The body
limit is 64 KiB and canonical metadata is limited to 8 KiB. Namespace and endpoint/
secret versions preserve unsigned 64-bit integers; resource IDs and deadlines
obey the native counter bound. Pure preparation and decoding use an owned local
native host without credentials or authority operations.

`transit_http:stage(Turn, Prepared)` returns `{ok, false}` when it adds one bounded
upload step to the private turn. Commit and arrange another application input.
When true, both immutable records were committed before this turn:
`transit_http:call(Turn, Connector, Prepared)` may share the turn with persisting
its returned correlation. Guard against another call using that persisted state.
Reconstruct the exact prepared request after fresh ownership to resume committed
staging. The application retains source bytes until publication. A namespace
permanently identifies one request and cannot be reused. Observe committed runner
events; a callback return is not a durable acknowledgement.

Application codecs retain ownership of payload dispatch. A byte-oriented codec
can return immutable payloads to the handler. On a `reply` input, authenticate
the original connector and persisted correlation with
`transit_turn:require_reply/4`, then call `transit_http:decode_reply(Realm, Bytes)`.
It returns `#transit_http_rejected{}`, `#transit_http_outcome{}` or
`#transit_http_released{}`. A cast containing
outcome-shaped bytes is not a reply. Outcomes distinguish observed, closed unknown
and not dispatched; only observed outcomes contain complete references. HTTP
status is not business success. No language wrapper duplicates HTTP framing or
outcome interpretation.

Open replay outside callbacks with `transit_http:open(Runner, Outcome)` or
`open/3` with `captured` or `require_unredacted` policy. There is one active reader
per runner, and pending uncertain mutations prevent replay operations.

```erlang
{ok, Reader0} = transit_http:open(Runner, Outcome),
{ok, {Part, Reader1}} = transit_http:read(Reader0),
%% Continue with Reader1; an old token cannot advance the stream.
{ok, ok} = transit_http:close(Reader1).
```

Each read returns `{ok, {PartOrDone, NextReader}}`, where a part is
`#transit_http_part{kind, bytes, complete}` with at most 256 owned bytes and `done`
marks end of stream. Every read rechecks current resource authority. Only
`transit_http:complete(NextReader)` establishes validated completion; prior
prefixes remain provisional. Captured mode reports omissions; unredacted mode
rejects gaps. Replay never resolves credentials or performs an HTTP request.

Always continue with the returned token. Reusing an older token returns
`read_failed`/`HttpReplayFailed`, preventing silent progress past a part lost when
a waiting BEAM process died. It does not invalidate an independently retained
current token. Any native/read-materialization failure poisons the active reader.
Restoring permission requires close/reopen. There is no cache that bypasses
current authorization. Local token state is bounded independently of retained
capture size.

Runner work remains owned when its waiting process exits. Stop and close join
native work; owner death follows the existing graceful shutdown path. Local
shutdown does not cancel remote HTTP execution. Reader close disposes the local
slot, and repeated close is accepted for the last closed identity. After runner
close, all reader tokens fail `closed`. Previously returned binaries remain owned.
Disposal does not release a durable caller hold, retire capture or erase history.

Inside a handler, `transit_http:release(Turn, Connector, Capture, Exchange)`
requests disposal of the durable caller hold. Persist its correlation and
authenticate the subsequent reply with `transit_turn:require_reply/4`, then decode
and check the `#transit_http_released{resource, exchange}` identity. Duplicate
calls remain safe after worker restart and cleanup without transcript read access.
The service checks the recorded holder and current admission policy. Release
does not cancel remote work, retire capture or clean up its members; the finite
worker needs a fresh `poll` activation to handle it.

`transit_http:followup(Turn, Connector, ParentOutcome, Reason, Prepared)` records
an explicit new correlated call using the native `http_followup` capability.
`Reason` is `retry`, `redirect`, `reconcile` or `cancel`. Stage the new request
first, save the returned correlation, and authenticate the new reply as above.
The service validates the original caller, current scope and frozen parent policy
before allocating a child attempt. It preserves the original deadline and shared
attempt budget; a refusal arrives as a correlated rejected outcome. The parent
remains unchanged, and no helper retries or cancels remote work automatically.
The turn, prepared request and parent must belong to the same realm. Expired
turns and unknown reasons fail before recording a call.

`just bindings::beam-sdk-test` compiles installed Erlang and Elixir consumers
and runs the shared TLS/recovery/revocation/disposal schedule, four followup
policy refusals without extra HTTP sends, and existing SDK
regressions. See the [proof guide](../../../../tests/README.md#m15-connector-work-in-progress)
for executed evidence. Native allocation proofs are distinct from BEAM heap-loss
qualification.

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `transit_http:diagnostic(Runner, Outcome, Kind)` after the runner has no pending
mutation. Select `capture_failure` or `native_effect`; the result is `{ok, DiagnosticMap}` or `{ok, null}`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/reference/sdks.md#structured-failure-details).
