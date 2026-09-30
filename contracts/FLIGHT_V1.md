# Finite Flight gateway profile v1

The Flight gateway serves finite int64 Table queries to PyArrow and ADBC C/Python
clients. The
[compatibility matrix](../packages/zig/transit-flight/docs/compatibility.md)
records supported client versions, bounds and excluded operations. This contract
extends [serving](SERVING_V1.md) and [query v1](UNIFIED_QUERY_V1.md);
it does not replace their authorization, admission or result evidence.

## Protocol and source

Use Apache Arrow 23.0.0's Flight/Flight SQL protobuf definitions, pinned with
hashes beside `transit-flight`. Flight SQL commands are standard protobuf `Any`
values in CMD descriptors. Start with one explicitly published Table per scoped
caller mapping, primitive int64 key/value columns and the existing Fuze SQL
subset. Key is non-null; value can be null. Projection, checked int64 sum, count,
finite filters/limits and empty results use the current query plan and source
contracts. Verified nested query cells are adapted to ordinary Arrow int64
columns. The adapter rejects missing, conflicted and mistyped cells; it never
coerces them to null. Count is checked before conversion from uint64 to int64.

The gateway implements GetSchema, GetFlightInfo and server-streaming DoGet, with
a single endpoint per finite result. Catalog metadata comprises GetCatalogs, GetDbSchemas,
GetTables, GetTableTypes and GetSqlInfo, including the standard dense-union/list/
map capability schema. Unsupported information IDs and methods fail explicitly;
never silently omit requested information or advertise unimplemented SQL types.
Prepared statements/parameters, writes, transactions, savepoints, bulk ingestion,
DoPut, DoExchange, polling and cancellation actions return UNIMPLEMENTED.
ListActions is empty; ListFlights is unsupported. Catalog discovery uses the
standard Flight SQL metadata commands and cannot start an application query.
The pinned ADBC Python DBAPI uses its unprepared fallback; the C
consumer uses direct statement execution.

## Credentials, publication and admission

An explicit TLS edge admits connections to a private HTTP/2 listener. A bounded
configured mapping translates an opaque Bearer credential to a dedicated native
query principal/key and published serving/query scope. Keep credentials and keys
in private files. Reject duplicate credentials and caller-supplied principal,
upstream or resource overrides. Connection pooling grants no authorization;
authenticate every RPC. The gateway's inspection key cannot substitute for the
mapped caller's current native read/send rights or source/requester permissions.

Metadata, admission and result reads use current serving identity and read
policy checks plus the public query client's current source/requester checks.
New admission additionally requires the configured published binding. Retained
results keep their original source, request and schema identity; changing a
publication cannot redirect a ticket to a new target. Ticket validation never
grants access or turns an unavailable source into an empty result.

A statement GetFlightInfo requires the decimal `x-transit-request-sequence`
header. It selects the first native sequence and the immutable upload namespace.
The configured published schema, SQL and budgets produce one canonical request
bundle. The gateway signs `begin`, bounded `part` commands, `seal` and `submit`
with consecutive native sequences, waiting for each recorded requester outcome
before sending the next command. The namespace is the first sequence. The
principal must be dedicated to this admission stream; concurrent requests must
not overlap their native sequence ranges.

The same first sequence and canonical bundle reconstruct the same signed commands
through gateway replacement. Changed bytes at a used sequence conflict. An unknown
outcome retains the original sequence and SQL/schema; the gateway never chooses a
new sequence automatically. Successful `FlightInfo.app_metadata` is JSON
`{"version":1,"next_sequence":N}` identifying the sequence after the upload. A new
statement uses that explicit next sequence; increasing the first sequence by one
would overlap the previous upload. Flight clients that do not expose application
metadata must obtain the next native sequence through their dedicated caller's
capabilities only after the previous statement completes.

GetSchema compiles only and never submits. GetFlightInfo waits within its finite
deadline for the recorded query result. Disconnect or deadline does not cancel
accepted native work. A retry can reconstruct the original bytes after gateway
loss, including when a newer sequence has already been admitted. Busy/rejected
application admission remains distinct from native input acceptance.

## Tickets and disclosure

Tickets are private opaque references. The `FTK1` encoding contains nine u64
scope fields (realm, principal, service, binding revision, ingress, requests,
source, resource, Table), a u64 expiry in Unix milliseconds, then a tagged
reference. Integers are little endian. Statement tag 1 contains a u64 native
correlation and SHA-256 of the canonical retained manifest. Metadata tag 2
contains a u16 command length, at most 1024 original command bytes and a SHA-256
digest of its finite encoded result. A final 64-byte Ed25519 signature covers
SHA-256 of `transit.flight.ticket.v1\0` followed by all preceding bytes. Maximum
ticket size is 1207 bytes. Verification requires the complete configured scope,
current time before expiry and the deployment's explicit ticket key.

Ticket keys shared by gateway replicas only preserve reference verification;
they do not replace current resource authorization. Ticket expiry is independent
of admission identity and retained result lifetime. Reissuing access to an old
query must resolve that same accepted input, not execute a new query. Never use
SQL text alone for deduplication.

DoGet reads the same retained manifest and ordered segments through the public
query client. Each bounded read rechecks current source/requester access, including
entry-read permission independently of metadata inspection. Check service policy,
ticket expiry and manifest identity at disclosure boundaries. Revocation after a
returned batch terminates the stream without claiming the earlier prefix is a
complete result. Released pins, retired resources and missing evidence fail closed.
Reconnect restarts retrieval of the same result; no offset-resumption guarantee
or automatic requery is supplied.

FlightData's data_header is the IPC Message flatbuffer without the continuation/
length prefix; data_body is its corresponding record body. FlightInfo/GetSchema
carry the serialized schema message with the standard prefix. Do not place a
whole IPC stream inside data_body. The existing Arrow reader validates finite
segments; complete coverage checks counts, ordered segment digests and manifest
identity. One bounded batch is resident. Captured bytes and digests are verified before
conversion. `FlightInfo.total_bytes` is -1 for statement results because the
primitive Flight encoding differs from the retained cell encoding; total row
count remains exact.

## Capacity and qualification

Use the inbound gRPC server's separately bounded connection, data/control RPC,
metadata, message, response-byte, credit-stall and deadline budgets. The selected
transport admits one live stream per connection and 16 KiB messages; the gateway
must explicitly bound aggregate protobuf/Arrow/query allocations too. Slow peers,
malformed messages and cancellation cannot leave borrowed buffers in detached
tasks. A partial write can require physical connection closure rather than a
fabricated successful trailer. No deadline authorizes durable deletion.

Pinned PyArrow and ADBC C/Python consumers have independent checks for
metadata schemas, null/empty/aggregate results, explicit retry, pooled credential
separation, current read-only revocation and physical restart. Outbound Flight
remains a separately authorized RPC connector effect with recorded capture,
terminal outcome and network-free replay. Native inbound query reads cannot
silently authorize an outbound call.
