# transit-mysql

MySQL classic packet framing, exported as `transit_mysql` over the shared
`transit-sql-gateway` library.

`Frame.decode` checks the three-byte little-endian payload length and expected
sequence before borrowing a complete packet. Incomplete network fragments return
no message; trailing coalesced packets remain unconsumed. `Frame.read` allocates
one bounded payload only after checking its header; its `Owned` result requires
`deinit`. The caller owns command/authentication sequence transitions and supplies
a transport with bounded `readExact`.

`Command` validates command bodies and typed prepared execution. Its `Parameters`
object retains the last fully validated parameter type vector; failed executions
do not alter it. Values borrow the input message. `Scalar` defines full-width
signed/unsigned metadata and finite numbers, integer Booleans, UTF-8 and binary
values. `Codec` checks length-encoded inputs before slicing. The session owner
supplies NULL/result framing, a truthful selected collation and aggregate bounds.

The selected logical-message budget is below MySQL's 0xffffff-byte continuation
packet. Such a header rejects immediately as oversized; network fragmentation
within the budget is supported. This does not advertise unbounded messages or
server-side cursor/long-data support. No database listener is supplied by these
primitives. See the [wire contract](../../../contracts/SQL_GATEWAY_V1.md).

`Handshake` validates exact SSLRequest/HandshakeResponse41 negotiation, UTF8MB4
encoding, bounded attributes and the caching-SHA2 plugin. It rejects capability
changes across the TLS upgrade and layouts requiring compression, local files,
multiple statements or query attributes. `Backend` encodes HandshakeV10,
full-auth requests, result/parameter metadata, text/binary rows, prepare replies,
classified errors and EOF/OK terminators. Binary result NULL bits start at offset
two; affected rows retain full uint64 values. Status reports autocommit without an
open transaction, generated ID or additional results. Returned packets borrow a
bounded reusable buffer; the session owns sequencing and negotiated EOF choice.

Build with `zig build test` or `zig build check` inside `nix develop`.
