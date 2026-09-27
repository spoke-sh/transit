# HTTP calls and captured replay

The M15 HTTP API in `transit/station.h` delegates request preparation, immutable
publication, call framing and replay validation to the shared Zig implementation.
It requires native capabilities `http_requests` and `http_replay`. The initial
worker accepts one root call per provisioned connector PID; deployment, exact
endpoint scope and credential binding belong to the
[worker](../../../../apps/transit-station-http-worker/README.md).

`transit_station_http_prepare` accepts a method, ordered target pieces, ordered
headers, binary body and explicit resource/namespace/revision/deadline/attempt
options. Pieces distinguish literal text, ordinary named variables and versioned
secret references. Ordinary target variables are escaped by shared Zig. Header
names are NUL-terminated; piece text is a byte slice validated as UTF-8. A secret
piece contains its binding and version, never a credential value. Request bodies
are bounded at 64 KiB and canonical metadata at 8 KiB.

Preparation copies its inputs into an owned `transit_station_http_request`.
`transit_station_http_request_inspect` returns borrowed immutable views valid
until `transit_station_http_request_destroy`; copy any bytes needed afterward.
Namespace and endpoint/secret revisions preserve full unsigned 64-bit values.
Resource IDs and deadlines obey the native counter limits. Namespaces identify
one permanent immutable request and must not be reused for different content.

Inside a handler on that request's writable resource:

```c
bool ready = false;
transit_sdk_error error = transit_station_turn_http_stage(turn, request, &ready);
if (error.kind != TRANSIT_SDK_OK) return error;
if (ready) {
    uint64_t correlation;
    error = transit_station_turn_http_call(turn, connector, request, &correlation);
    if (error.kind != TRANSIT_SDK_OK) return error;
    /* Persist correlation in this turn with an application key. */
}
```

Each false staging result contributes one bounded upload step to the private
turn. Commit the turn and arrange another application input; no helper silently
schedules work. Reconstruct the exact prepared request after fresh ownership to
resume committed staging. Keep its original body available until publication.
The first true result means both immutable records were committed before this
turn, so the validated call and correlation write can share its commit. Use the
persisted correlation to avoid starting another call on later inputs. Observe
runner events: returning from the handler is not a committed result.

Application codecs can reserve the exact `HTR1` and `HTF1` prefixes and delegate
those payloads to `transit_station_http_decode`. The returned inline outcome
owns its reference bytes and distinguishes admission rejection, observed,
closed unknown and not dispatched. Only observed outcomes carry complete replay
references; HTTP status does not prove business success. In a reply handler,
call `transit_station_turn_require_reply` with the original connector PID and
persisted correlation before trusting an outcome. A decoded payload alone does
not authenticate its sender. A cast with an outcome-shaped payload is not a reply.

Open replay with `transit_station_http_open` outside handler callbacks. One reader
is active per runner. Pending uncertain mutations prevent replay operations.
Each `transit_station_http_read` rechecks current resource authority and returns
an inline `transit_station_http_part` containing at most 256 owned bytes. `present`
distinguishes a part from end of stream; `complete` records validated completion.
Earlier parts are provisional. The default captured policy exposes omission
metadata; the unredacted policy rejects a gap. No replay operation resolves
credentials or performs an HTTP request.

A failed read invalidates that local reader, including failure to materialize a
native response. Restoring a grant does not resume it: close and reopen under
current authority. `transit_station_http_close` is idempotent while the runner
remains open; `transit_station_http_reader_destroy` releases the handle and
attempts local close. Disposal does not release the durable caller hold or erase
capture. Those are explicit lifecycle operations.

For durable disposal, call `transit_station_turn_http_release` in a handler with
the connector PID, capture resource and exchange, and persist the returned
correlation. Decode `HTK1` payloads with `transit_station_http_decode_released`
into the separate inline `transit_station_http_released` type; authenticate the
outer reply with `transit_station_turn_require_reply` and check its resource and
exchange. Rejections still use the existing outcome decoder. Duplicate disposal
remains safe after restart and cleanup, without a transcript read grant. The
service checks the recorded holder and current admission policy. Release does
not perform remote cancellation, retirement or cleanup. The finite worker needs
a fresh `poll` activation to handle this control call.

Concurrent operations return `BUSY`. Close joins owned native work; stop does not
cancel remote HTTP execution. Join application threads before destroying a public
handle. A reader keeps the runner's local storage valid after runner destruction,
but subsequent reads return `CLOSED`. Inline part copies survive all handle
destruction. Callback contexts and codecs must remain alive until runner close.

`just bindings::c-sdk-test` compiles the installed HTTP callback fixture as C11
and drives the direct C APIs through the shared TLS/recovery/replay schedule.
It also runs the C++ wrapper and existing client/Station regressions. See the
[proof guide](../../../../tests/README.md#m15-connector-work-in-progress) for
executed evidence and remaining M15 limits.
