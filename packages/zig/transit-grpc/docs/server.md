# Inbound server

`Server.serve` accepts a private cleartext HTTP/2 listener. A deployment must
place its configured TLS/authentication boundary in front of that listener;
transport parsing alone grants no application access. M22's Flight adapter must
qualify that composition separately. The outbound `execute` API and its durable
connector obligations are unchanged.

The implemented profile accepts one framed unary request, then a unary or
server-streaming response. Each connection advertises one concurrent stream;
sequential pooled calls reuse it. Defaults admit 16 connections, four data RPCs,
two separately reserved control RPCs, 64 calls per connection and a five-minute
connection lifetime. A listener connection rejected at capacity has no admission
receipt. The one-stream limit requires independent connections for simultaneous
control progress. grpcio can share a subchannel across channel objects; the proof
explicitly disables that sharing when testing concurrent connections.

Request headers/body have five seconds, each RPC at most three minutes, and
each blocked write or credit wait five seconds. A smaller `grpc-timeout` limits
the call. All deadlines cancel and join their work. A deadline at a known frame
boundary can return status 4; cancellation or an interrupted write can close the
physical connection. A returned prefix is never a successful terminal response.

One fixed 2 MiB allocation budget per connection owns HPACK, frame buffering and
decoded headers. Fixed socket/read buffers and the 16,389-byte request/response
frames are separate. The defaults retain M16's 16 KiB messages, 256 KiB framed
response bytes, 64 response messages and 8 KiB/64 metadata fields. Request
cardinality is exactly one, even though the shared outbound limits support more.
Identity-only compression rejects unsupported encodings; declared lengths never
size allocations. No input/result history accumulates in the transport.

The owner maintains one outstanding asynchronous socket read. `Response.check`
polls that read without cancelling it or discarding bytes; handlers call it around
bounded upstream work. `send` returns only after consuming peer flow-control
credit and flushing the whole message. On handler return or cancellation every
task using borrowed request/response buffers is joined before teardown.

The context classifies control methods, authorizes every request, budgets its
own protobuf/Arrow/query allocations, and maps application outcomes to statuses.
It must not infer authority from control admission or connection reuse. Header
lookups reject duplicate singleton credentials. Diagnostic callbacks receive
only error kinds and whether a handler started; status text must be a fixed
public message, never request data or credentials.

`just test::grpc-server` uses pinned independent grpcio/h2 clients. It covers
pooled sequential calls, empty/binary/Unicode messages, a 16 KiB message, 192 KiB
of streaming response, withheld credit, control admission during data saturation,
reset/deadline cleanup and explicit malformed/compressed/oversize rejection.
This is a local transport proof; Flight metadata, TLS placement, durable
admission recovery and current resource authorization remain separate gates.
