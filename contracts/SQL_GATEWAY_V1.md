# Database wire adaptation primitives v1

This contract defines the shared gateway library, PostgreSQL frame/cycle gate
and MySQL frame decoder. These primitives do not themselves open a listener or
admit a durable write. Executed evidence belongs to the
[proof ledger](../tests/README.md).

## Common values and resource budgets

`transit-sql-gateway.Type` admits exactly int64, uint64, finite float64, Boolean,
UTF-8 and binary logical descriptors. Nullability is independent of the type.
Values retain exact integer sign/range and finite floating-point checks. Missing,
type-error and conflict cells never encode as SQL NULL. Other stored descriptors
return `UnsupportedWireType` at this boundary.

`Limits.validate` checks the following default configuration and ceilings.
These are operation/resident bounds, independent of retained Table cardinality.
The application owner must enforce admission and use these limits at each I/O
and allocation boundary; constructing a Limits value does not reserve capacity.

| Bound | Default | Ceiling |
| --- | ---: | ---: |
| Connections | 64 | 256 |
| Connections per account | 8 | Total connection bound |
| Concurrent authentication attempts | 4 | 16, within the connection bound |
| Prepared statements per session | 16 | 64 |
| Portals per session | 4 | 8 |
| Frame length | 4 MiB + 8192 bytes | Same |
| Extended-cycle bytes | 4 MiB + 8192 bytes | Twice the frame ceiling |
| Extended-cycle messages | 64 | 256 |
| Session allocator budget | 16 MiB | 64 MiB |
| Handshake / command / idle / write deadline | 5 / 30 / 30 / 5 seconds | 270 seconds each |

Every configured bound is positive. A cycle accommodates at least one frame and
fits the session budget. SQL text remains at most 4096 bytes. The common maximum
parameter count is 256; the owning SELECT/DML compiler can impose a tighter
syntax/plan bound. The constants reserve at most 63 bytes for account/database/statement/portal
names and 32 configured accounts. Their owning session/configuration APIs must
enforce these ceilings; Table identifiers retain the SQL owner's limits. These
constants do not bound durable operation history.

## Credential verification

A verifier contains mandatory version 1, the current native definition,
iterations, a 16-byte salt, 32-byte StoredKey and 32-byte ServerKey. Derivation is
PBKDF2-HMAC-SHA-256 followed by the SCRAM Client Key/Server Key derivations.
Iterations are 4096–262144, default 65536. The password profile is 1–128 printable
ASCII bytes (U+0020–U+007E). SASLprep is the identity on this profile; unsupported
codepoints reject rather than changing password bytes.

The SCRAM owner accepts `n,,` and `y,,` GS2 headers, a bounded client-first bare
message and a 16–256-byte printable nonce excluding commas. It appends 24 Base64
characters from 18 secure random bytes supplied by the I/O owner. The exact
client/server-first and client-final-without-proof bytes form AuthMessage.
The final message must match the original GS2 header and combined nonce, with a
canonical Base64 32-byte proof. Constant-time StoredKey comparison precedes the
server proof. A finish attempt consumes the state on both success and failure;
`deinit` erases retained key/proof material. SCRAM-SHA-256-PLUS is unsupported.
PostgreSQL's startup account selects the verifier; the SCRAM name does not select
another identity.

The same verifier can check a full plaintext password received inside an already
established TLS session, for MySQL's full caching_sha2_password exchange. The
caller owns TLS admission, secure randomness, credential revision/rotation,
authentication concurrency and erasure of the received password buffer. No fast
authentication cache or unencrypted RSA-password exchange is implemented here.

## PostgreSQL frame and cycle ownership

Startup frames carry a four-byte big-endian total length of at least eight bytes,
then a code/version. SSLRequest and GSSENCRequest have length eight; the selected
v3.0 CancelRequest has length sixteen. Typed frames carry a one-byte type and a
four-byte big-endian length including that length field. Values below four,
above signed int32 or above the configured budget reject before allocation.
A complete decoded frame borrows its exact payload and reports consumed bytes;
a partial frame returns no message. The transport wrapper reads only its exact
header/payload and returns an independently owned bounded buffer.

The deterministic cycle gate accepts metadata-only Parse/Bind/Describe/Close
work and one execution. Execute of a write only records deferred admission;
only a subsequently validated Sync returns `sync_write`. Any intervening message
including Flush or another Execute fails that cycle before write dispatch.
A write Execute with a row limit rejects. Reads may execute/resume one portal;
resumption requires its suspended state and exact identity. A read cycle cannot
later admit a write. Sync clears the gate. Failed cycles ignore all messages
except Terminate and Sync; Sync returns an empty completion action.

The adapter must validate message bodies before acting on gate results, discard
candidate writes after any validation failure and destroy portals at Sync. Named
statement lifetime belongs to the session owner. Invalid framing closes the
connection, because a body boundary cannot be trusted. A gate action is neither
authorization nor a native receipt. The backend protocol's full transaction and
pipeline semantics are outside this explicitly selected autocommit cycle.

## MySQL frame ownership

Classic packets carry payload length:u24 little-endian and sequence:u8. The
caller supplies the expected sequence for the current authentication/command
exchange. A mismatch rejects before allocation. Complete messages borrow payloads
and report consumed bytes; partial network fragments return no message. The
transport wrapper allocates only after checking the header.

The selected logical-message bound is below 0xffffff bytes. A full-size MySQL
continuation header therefore rejects as oversized before reading its body.
Sequence 255 is valid when expected; the exchange owner controls wrap/reset.
Framing alone neither advertises command capabilities nor executes SQL.

## Primary definitions

The adapters follow the selected portions of PostgreSQL's
[message formats](https://www.postgresql.org/docs/18/protocol-message-formats.html)
and [message flow](https://www.postgresql.org/docs/18/protocol-flow.html), and
MySQL's [classic packets](https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html).
The credential primitives use the SCRAM-SHA-256 construction described by
[RFC 7677](https://www.rfc-editor.org/rfc/rfc7677).
