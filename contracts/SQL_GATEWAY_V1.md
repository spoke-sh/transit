# Database wire adaptation primitives v1

This contract defines the shared gateway library, PostgreSQL frame/cycle gate,
MySQL frame decoder and typed message/scalar codecs. These primitives do not themselves open a listener or
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

`Frontend.decode` validates complete Query, Parse, Bind, Describe, Close,
Execute, Sync, Flush and Terminate bodies, including trailing bytes, names,
UTF-8, parameter counts and format codes. Input slices borrow the bounded frame;
the session must own any bytes retained beyond it. Bind distinguishes NULL from
empty bytes. Formats have zero, one or exactly the affected number of entries;
the caller validates result formats against the prepared output schema. Parse
OID count/inference and Bind parameter count are checked against that statement
by the session owner. `saslInitial` admits only bounded SCRAM-SHA-256 payloads.

| Logical type | Result OID | Text | Binary |
| --- | ---: | --- | --- |
| int64 | 20 | Signed decimal | Signed eight-byte big-endian |
| uint64 / counts | 1700 | Unsigned decimal | Positive numeric, scale zero, base-10000 digits; `numeric(20,0)` modifier |
| finite float64 | 701 | Decimal floating point | Eight-byte IEEE big-endian |
| Boolean | 16 | `t` / `f` | Exactly zero or one |
| UTF-8 | 25 | UTF-8 without NUL | Same |
| Binary | 17 | `\\x` followed by hex | Exact bytes |

Parameter OID zero infers the canonical type. Signed integer OIDs 21/23/20
admit lossless int16/int32/int64 representations for int64 or nonnegative uint64;
numeric OID 1700 is also available for uint64. Numeric parameters have integer
scale and a maximum of five base-10000 digits; negative, fractional, special and
overflow values reject. Float OIDs 700/701 preserve their declared width before
widening to float64. UTF-8 accepts OIDs 25/1043. Other cross-kind conversions
reject, including an incompatible declared OID on a NULL parameter. Text integer
parameters obey their declared width. SQL constraints remain the compiler's
responsibility. Bytea text decoding allocates in the supplied allocator; other
variable-sized inputs borrow their frame. Encoders append a non-NULL payload;
the row owner supplies length or NULL framing and bounds the aggregate message.

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

`Command.decode` admits Query, Prepare, Execute, Close, Reset, InitDB, Ping, Quit
and ResetConnection bodies. Query/Prepare SQL is bounded UTF-8 without NUL;
unknown commands reject. `Parameters.execute` checks the statement ID, zero
cursor flags, iteration count one, NULL bitmap, new-type flag and exact payload
end. It remembers types only after a complete valid execution body. A caller
must retain that state with the prepared statement and validate the expected
logical parameter types. No query-attribute layout is accepted.

| Logical type | Result field type | Flags / representation |
| --- | --- | --- |
| int64 | LONGLONG (8) | Signed eight-byte little-endian |
| uint64 / counts | LONGLONG (8) | UNSIGNED, eight-byte little-endian |
| finite float64 | DOUBLE (5) | Eight-byte IEEE little-endian |
| Boolean | TINY (1) | UNSIGNED; integer zero or one |
| UTF-8 | VAR_STRING (253) | Session's explicitly selected UTF-8 collation |
| Binary | BLOB (252) | BINARY flag, charset 63 |

Non-nullable fields add NOT_NULL. Numeric fields use charset 63. Parameters
admit signed/unsigned TINY, SHORT, LONG, INT24 and LONGLONG when they fit the
logical integer or zero/one Boolean destination; FLOAT widens to finite DOUBLE.
String/blob wire types carry length-encoded UTF-8/binary bytes. Embedded NUL is
valid in MySQL length-framed values. NULL remains separate from an empty value;
type code NULL carries no value bytes. Unsupported codes/flags, negative unsigned
values and narrowing overflow reject. Result encoders append one non-NULL field;
the owner supplies text NULL markers or the binary-row NULL bitmap (offset two),
row framing and aggregate byte limits. Execute parameter bitmaps have offset zero.

`Codec.length` handles every defined non-NULL length width and rejects reserved
markers. `Codec.string` checks its byte bound before slicing input. These helpers
do not allocate based on untrusted lengths. Decoded parameter strings borrow the
input until the session clones/binds them.

## Primary definitions

The adapters follow the selected portions of PostgreSQL's
[message formats](https://www.postgresql.org/docs/18/protocol-message-formats.html)
and [message flow](https://www.postgresql.org/docs/18/protocol-flow.html), and
MySQL's [classic packets](https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html).
The credential primitives use the SCRAM-SHA-256 construction described by
[RFC 7677](https://www.rfc-editor.org/rfc/rfc7677).
