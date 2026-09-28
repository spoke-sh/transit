# transit-http-server

Neutral HTTP/1.1 listener mechanics for [M19](../../../docs/roadmap/M19.md).
This package has no Transit, Station, storage, credentials or application dependency.
Consumers own identity, routes, durable admission, body/result budgets and responses.

`serve` owns a configured pool of 2–64 accepted sockets, with independent active
data and `/health` control limits. It bounds header reads and the whole request,
joins cancelled work before releasing a slot, and closes connections when task or
socket capacity is exhausted. A closed socket says nothing about durable admission.
Every request gets 8 KiB input/4 KiB output buffers; consumer working memory is
additional and must be bounded independently. Partial headers can occupy sockets
only until the header deadline; this is not an authenticated per-principal quota.

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
