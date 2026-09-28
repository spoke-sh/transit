# transit-serving-http

Reusable Zig HTTP, fetch-SSE and WebSocket host for
[transit-serving](../transit-serving/README.md). The M21 extraction keeps the
[M20 protocol](../../../contracts/REACTIVE_V1.md) and existing serving example
unchanged on the wire. The neutral [HTTP server](../transit-http-server/README.md)
owns listener admission, deadlines and WebSocket framing; this package owns
signed dispatch, challenge consumption and joined streaming tasks.

Compose `Context` with a validated `Gateway`, upstream URL, gateway reader key
and diagnostics, then pass it to `transit-http-server.serve`. The host maps only
explicitly configured caller public keys and forwards their exact signed native
commands. Its reader credential and accepted service/watch publication remain
separate from caller identity. No handler, raw store or provider is imported.

`Gateway.validate` checks declared connection/request limits, caller uniqueness,
HTTPS origin and reactive clock/deadline requirements. Configuration owns the
lifetime of borrowed URL/origin/caller slices; `Context` outlives all listener
tasks. Each task owns a bounded upstream allocator. Challenges stay local to this
context: route SSE challenge and events to the same instance. Durable session
and cursor recovery still uses the public serving reader and configured signer.

The extracted host retains two-second challenges, 500 ms idle authority checks,
one-second writes and the configured finite connection deadline. Cancellation
joins receive/event tasks before releasing sockets and buffers. No response
status is appended after streaming headers. Data capacity and control capacity
remain separate; accepted application work is never cancelled by disconnect.

From this directory, `zig build test` checks the standalone manifest. The actual
host is exercised by `just test::serving-tls`, `just test::reactive`, and the
reactive browser/limits/placement proofs documented in [tests](../../../tests/README.md).
