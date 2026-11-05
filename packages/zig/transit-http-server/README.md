# transit-http-server

Neutral HTTP/1.1 listener mechanics for [Serving](../../../docs/handbook/reference/serving.md).
This package has no Transit, Station, storage, credentials or application dependency.
Consumers own identity, routes, durable admission, body/result budgets and responses.

`serve` owns a configured pool of 2–64 accepted sockets, with independent active
data and control limits. `/health` is reserved automatically; an optional
`Context.isControl(request)` may classify further bounded control routes. It bounds header reads and the whole request,
joins cancelled work before releasing a slot, and closes connections when task or
socket capacity is exhausted. A closed socket says nothing about durable admission.
Every request gets 8 KiB input/4 KiB output buffers; consumer working memory is
additional and must be bounded independently. Partial headers can occupy sockets
only until the header deadline; this is not an authenticated per-principal quota.

`Options.requests_per_connection` defaults to 1 and accepts 1–256. An opting-in
consumer also sends keep-alive responses. Requests on a socket remain sequential,
with fresh admission and deadlines; idle sockets retain no data/control slot.
The header deadline bounds idle reuse and the final response advertises closure.
Plain sockets and the SQL TLS adapter use `io.operateTimeout` with an absolute
header deadline, without spawning header timer/work tasks. Partial reads do not
renew the deadline. Buffered pipelined headers also check it before admission.
The adapter checks expiry before submitting I/O even when a socket is ready;
a zero-duration readiness poll alone does not enforce this boundary.
Body reads and response writes share the original total request deadline;
header parsing cannot renew or round that budget into another request interval.
The shared `respond` helper ends reuse even when a handler has consumed the body;
buffered successor requests are not dispatched after that closing response.
The growing node and local gateway use 64 exchanges per connection. Other
consumers keep their existing close-after-response behavior.

`Context.handle(io, allocator, request)` may run concurrently. Consumers must use
private arenas/observations and coordinate shared signers, throttles and mutations.
`connectionError(error, handler_started)` receives finite error categories, never
headers or bodies. Consumers can avoid duplicate observations after dispatch.
`deadline` joins both timer and work branches even on scheduling failure. It
performs no retry. Application synchronous code must remain bounded/cooperative.
The listener retains this joined cancellation boundary for non-socket handler
work. It still runs one task per accepted connection and does not establish
CPU-bounded runnable scheduling.

A custom `Context.Connection` owns TLS or other transport state and supplies
`init`, `reader`, `writer`, `setDeadline`, `readError` and `deinit`. `setDeadline`
receives the listener's absolute `std.Io.Clock.Timestamp`; it must apply to every
subsequent read/write without renewal. `readError` preserves a failed read's
transport cause when `std.Io.Reader` reports `ReadFailed`. The listener maps an
underlying socket timeout to `HttpDeadline`. Initialization owns its separate
handshake deadline, and deinitialization runs after all handler borrowers join.

The [HTTP profile](../../../contracts/HTTP_SERVING_V1.md) defines framing and
connection limits. TLS termination and deployed concurrency qualification belong
to the consuming application; unit checks are not a server security qualification.
Run `zig build test` from this package in the pinned Nix environment.

M20 adds `WebSocket.handshake` and `Decoder`: strict HTTP/1.1 upgrade with a
selected subprotocol, no negotiated extensions, required client masking, 8 KiB
reassembled text, at most 32 fragments, interleaved ping/pong/close and complete
UTF-8 validation. The host must enforce exact Origin/Host, authenticate bootstrap,
bound elapsed reads/writes, serialize writers and join both socket directions.
Framing alone grants no application authority. Unit checks pin fragmented UTF-8,
canonical lengths, control/close restrictions and exhaustion. Consuming peers and
TLS/proxy qualification remain part of M20's separate integration matrix.

Contexts may classify notification waits with `isWait(request)` and configure
`wait_requests`. Their admission counter is independent of ordinary/control
requests; all share the explicit connection bound. The default enables no wait
slots. The context owns authentication, wait deadlines and revalidation. A wait
must release domain locks while sleeping; admission is released on every exit.
