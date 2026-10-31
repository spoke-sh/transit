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

[`transit-sql-host`](../transit-sql-host/README.md) owns the MySQL
session engine and its bounded prepared handles, validated parameter type vectors,
result sequencing and command errors. Statement reset retains parameter types;
connection reset and database selection clear ephemeral handles. IDs do not
repeat within a connection. The host supplies execution and current rights;
accepted writes belong to its database runtime. UPDATE returns changed rows by
default and matched rows with negotiated `CLIENT_FOUND_ROWS`. The
[gateway application](../../../apps/transit-sql-gateway/README.md) supplies the
transport policy, authentication and host. Full-password requests require TLS;
explicit loopback trust uses the same native admission without a password exchange.

Reads request at most 32 rows per disclosure. The host checks current rights
after materialization and before transmitting that batch. Empty results and
completion use the same gate; later batches perform fresh checks.

Build with `zig build test` or `zig build check` inside `nix develop`.
