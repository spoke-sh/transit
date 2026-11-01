# transit-mysql

MySQL classic packet framing, exported as `transit_mysql` over the neutral
`transit-sql-protocol.Wire` types. The package has no SQL service, storage,
socket, TLS, timer or task dependency; its build checks the transitive runtime
import boundary.

`Frame.decode` checks the three-byte little-endian payload length and expected
sequence before borrowing a complete packet. Incomplete network fragments return
no message; trailing coalesced packets remain unconsumed. `Frame.frameSize`
validates a header before the host reserves or reads its body. The caller owns
command/authentication sequence transitions and transport operations.

`Frame.Input` is an incremental continuation over caller-owned storage. `next`
returns an input slice, a validated capacity request or one complete borrowed
frame. Commit partial reads with `advance`, or copy fragments with `feed`, which
reports the consumed count and leaves coalesced trailing bytes unconsumed.
Capacity replacement preserves the received prefix. End every frame borrow
before `release`; it erases used bytes and retains capacity. Invalid headers,
EOF or host cancellation close the decoder; the owner erases its full allocation
before freeing it. Framing does not authenticate or authorize execution.

`Command` validates command bodies and typed prepared execution. Its `Parameters`
object retains the last fully validated parameter type vector; failed executions
do not alter it. Values borrow the input message. `Scalar` defines full-width
signed/unsigned metadata and finite numbers, integer Booleans, UTF-8 and binary
values. `Codec` checks length-encoded inputs before slicing. The session owner
supplies NULL/result framing, a truthful selected collation and aggregate bounds.

The selected logical-message budget is below MySQL's 0xffffff-byte continuation
packet. Such a header rejects immediately as oversized; network fragmentation
within the budget is supported. This does not advertise unbounded messages or
server-side cursor/long-data support. See the
[wire contract](../../../contracts/SQL_GATEWAY_V1.md).

`Handshake` validates plaintext HandshakeResponse41 or exact SSLRequest/response negotiation, UTF8MB4
encoding, bounded attributes and the caching-SHA2 plugin. It rejects capability
changes across the TLS upgrade. Only the intersection of server flags and known
client offers selects features; unadvertised compression, local files, multiple
statements and query attributes remain disabled. `Backend` encodes HandshakeV10,
full-auth requests, result/parameter metadata, text/binary rows, prepare replies,
classified errors and EOF/OK terminators. Binary result NULL bits start at offset
two; affected rows retain full uint64 values. Status reports configured autocommit and the shared session's open transaction
flag, without a generated ID or additional results. Returned packets borrow a
bounded reusable buffer; the session owns sequencing and negotiated EOF choice.

`Session` owns authenticated command transitions, bounded prepared handles,
validated parameter type vectors, packet sequencing and command errors. Call
`start` with a borrowed command, then `poll` for a `Wire.Session` request or
completion. SQL work and output are values; the engine invokes no host callbacks.
Complete each request with its generation/sequence token. Partial output retains
immutable bytes until drained; a transport failure closes without retrying the
accepted SQL or appending ERR to a partial packet. An authority refusal before
any bytes preserves the packet sequence for the error response.

Statement reset retains parameter types; connection reset and database selection
clear ephemeral handles. IDs do not repeat within a connection. Input and bound
values live through the command's `done` event. Prepared metadata belongs to the
host until explicit destruction; read batches borrow cells until the next pull
or close. Abort fences late completions; join outstanding work and close host
handles before `deinit`. Encoding retains bounded high-water storage for reuse.

[`transit-sql-host`](../transit-sql-host/README.md) supplies execution, transport
and current rights; accepted writes belong to its database runtime. UPDATE returns
changed rows by default and matched rows with negotiated `CLIENT_FOUND_ROWS`.
Reads request at most 32 rows per disclosure. Protected metadata, rows and terminal
output carry an authority guard. After parking, the host must recheck current
rights immediately before writing buffered bytes, including an empty result or
completion. A resumed write reply observes its original accepted outcome without
executing the SQL again. Immediate output from one bounded batch shares a check.

The host retains authentication and TLS orchestration. Full-password requests
require TLS; explicit loopback trust uses the same native admission without a
password exchange. See the
[gateway application](../../../apps/transit-sql-gateway/README.md) for policy.

Build with `zig build test` or `zig build check` inside `nix develop`.
