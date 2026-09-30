# transit-http-server

Neutral HTTP/1.1 listener mechanics for [M19](../../../docs/roadmap/M19.md).
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
The growing node and local gateway use 64 exchanges per connection. Other
consumers keep their existing close-after-response behavior.

`Context.handle(io, allocator, request)` may run concurrently. Consumers must use
private arenas/observations and coordinate shared signers, throttles and mutations.
`connectionError(error, handler_started)` receives finite error categories, never
headers or bodies. Consumers can avoid duplicate observations after dispatch.
`deadline` joins both timer and work branches even on scheduling failure. It
performs no retry. Application synchronous code must remain bounded/cooperative.

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
