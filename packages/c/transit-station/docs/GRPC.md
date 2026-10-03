# RPC calls and captured replay

The C RPC API delegates descriptor validation, immutable request publication,
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

`transit_station_grpc_method_bind` creates a method;
`transit_station_grpc_prepare` copies a template, message slices and options
into an owned request. Inspect returns borrowed immutable views until
`transit_station_grpc_request_destroy`. Namespace, endpoint and secret revisions
preserve `uint64_t`. Call input pointers remain valid for their synchronous use.

In a handler, `transit_station_turn_grpc_stage` advances one upload step.
Commit false results and arrange another input. Once ready, call
`transit_station_turn_grpc_call` and persist its returned correlation in that
same turn. Reconstruct the exact request after fresh ownership to resume.
Never reuse its namespace with different content.

Decode reply payloads with `transit_station_grpc_decode` (or the separate
`transit_station_grpc_decode_released`). Authenticate their outer envelope with
`transit_station_turn_require_reply` using the original worker and saved
correlation. `has_status` distinguishes observed status zero from unknown.
A decoded payload alone does not prove its origin.

Open a reader with `transit_station_grpc_open`, read owned inline parts with
`transit_station_grpc_read`, and close/destroy it explicitly. Each part is at
most 256 bytes. A reader retains safe local runner storage after runner destroy;
subsequent operations return CLOSED. Already copied parts remain owned.

`transit_station_turn_grpc_retry` submits a new linked attempt under the original
budget; `transit_station_turn_grpc_release` disposes the durable caller hold.
Both return correlations that must be persisted and authenticated on reply.

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

Outcome and rejection values own `diagnostic.json` and `diagnostic.size` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/reference/sdks.md#structured-failure-details).
