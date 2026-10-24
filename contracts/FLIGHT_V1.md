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
caller mapping, bound to its catalog scope, owner, object, immutable metadata
reference and complete logical row descriptor. Up to 128 output columns preserve
their declared names and nullability; column position does not imply a key.
Primitive int64 outputs, checked int64 sum, count,
finite filters/limits and empty results use the current query plan and source
contracts. Verified nested query cells are adapted to ordinary Arrow int64
columns. The adapter rejects missing, conflicted and mistyped cells; it never
coerces them to null. Count is checked before conversion from uint64 to int64.
Other logical columns may be filtered using their supported operators or counted,
but projecting them returns UNIMPLEMENTED before upload. GetTables with
include_schema requires the published Table to fit that same primitive profile.
Supported storage types do not imply support for Flight output conversion.

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
query principal/key, optional selected role and published serving/query scope. Keep credentials and keys
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
bundle, including a proof of the original principal, selected role, credential
epoch, query bytes and intended recipient. The mapping also fixes the capture
executor and minimum direct Table position. The first sequence is the capture
operation ID; the signed grant selects a current cut at or beyond that minimum.
The source worker acquires the pin once and retains its selected cut independently
of its native progress resource. Reconstruction uses the original configured
minimum, never a new current observation. Altering the minimum or executor changes
the bundle and conflicts at the original first sequence. Neither configuration
nor the pin grants CONNECT, USAGE or SELECT rights.

The gateway signs `begin`, bounded `part` commands, `seal` and `submit`
with consecutive native sequences, waiting for each recorded requester outcome
before sending the next command. The namespace is the first sequence. The
principal must be dedicated to this admission stream; concurrent requests must
not overlap their native sequence ranges.

The same first sequence and canonical bundle reconstruct the same signed commands
through gateway replacement while the configured key, native credential epoch
and selected role remain unchanged. Rotation or a role change cannot resume an
old upload as a new subject: changed bundle bytes conflict at its original first
sequence, before any successor command is sent. Retain the old identity for
inspection; do not assign replacement SQL a used namespace. Changed bytes at a used sequence conflict. An unknown
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

Tickets are private opaque references. The `FTK1` encoding contains the current
32-byte Transit definition, eight u64 scope fields (realm, principal, service,
binding revision, ingress, requests, source, resource), a one-byte selected-role
presence flag followed by its u64 ID (zero when absent), the 32-byte Table source
declaration fingerprint, a u64 expiry in Unix milliseconds, then a tagged
reference. The declaration commits the catalog scope, owner, full-width object
identity, immutable metadata reference and logical descriptor. Reusing a Table
name or changing its declaration cannot redirect a ticket. Integers are little endian. Statement tag 1 contains a u64 native
correlation and SHA-256 of the canonical retained manifest. Metadata tag 2
contains a u16 command length, at most 1024 original command bytes and a SHA-256
digest of its finite encoded result. A final 64-byte Ed25519 signature covers
SHA-256 of `transit.flight.ticket.v1\0` followed by all preceding bytes. Maximum
ticket size is 1263 bytes. Incompatible definitions reject; no earlier ticket
layout is decoded. Verification requires the complete configured scope,
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

SQL failures return a bounded printable-ASCII `grpc-message`, at most 128 decoded
bytes. Percent signs are percent-encoded on the wire. Authenticated compilation
errors may disclose the failing caller-supplied identifier, expected/supplied
types and escaped literal context; truncation is explicit. They never include
the full SQL, credential material or unrelated stored row values. Current
authorization precedes diagnostic disclosure.

Terminal query messages retain `query.<code>`, admission/execution stage and the
request namespace from the saved query. Measured page/segment/result-byte failures
also carry exact unsigned limit/required amounts. OUT_OF_RANGE identifies checked
arithmetic overflow; RESOURCE_EXHAUSTED identifies bounded work/size exhaustion;
PERMISSION_DENIED identifies policy/access or publisher/peer denial;
FAILED_PRECONDITION identifies source/history/initialization and cell-state
failures; ALREADY_EXISTS is not used for query namespace conflicts (ABORTED is).
Unsupported profiles map to UNIMPLEMENTED and invalid request/plan/type inputs to
INVALID_ARGUMENT. Cancellation maps to CANCELLED and retirement to
FAILED_PRECONDITION. These statuses summarize the domain failure; they do not
authorize fresh submission or imply rollback.

At the caller boundary, invalid retained manifest/segment/digest/coverage evidence
maps to DATA_LOSS. Invalid caller fields/cursors map to INVALID_ARGUMENT, and
allocation or transport failure maps to UNAVAILABLE. Flight-specific ticket,
sequence and protobuf checks retain their own mappings. The shared query cause
and safe read action survive this presentation; they never override an original
compiler witness, retained failure or actual uncertain-dispatch witness.

Failures also carry the shared [Diagnostic v1](DIAGNOSTICS_V1.md) in the
`transit-diagnostic-bin` application trailer. Its value is UTF-8 JSON, at most
4096 decoded bytes; gRPC binary metadata base64-encodes those bytes on HTTP/2.
It is not `grpc-status-details-bin`, whose upstream type is `google.rpc.Status`.
PyArrow clients receive the bytes through client middleware; ADBC exposes the
named binary error detail. Consumers validate the shared contract definition,
exact counters and outcome/action evidence before using it. The standard gRPC
status and short message remain available without a metadata-aware client.

Compiler and saved query failures use the shared owner projections. Query
identity, original runtime witness, frozen basis and exact budgets survive this
channel. Unknown upload sends identify the first query sequence and the actual
native sequence; exact reconciliation uses the original GetFlightInfo SQL and
first `x-transit-request-sequence`. An authentication/access error does not
include stored runtime witnesses or a protected query identity.

Normal diagnostics retain their complete envelope. When metadata would exceed
4096 bytes, messages and textual/path context are shortened, with explicit
truncation. If necessary, text/location facts become explicitly unavailable;
code, cause, outcome, identity, numeric facts, digests and recovery actions remain
exact. Fact locations retain their numeric coordinates when their source path is
shortened. No result rows are fetched to enrich a diagnostic. Failure to produce
optional detail preserves the primary gRPC status/message. A deployment metadata
budget smaller than the encoded trailers can omit the optional binary trailer;
it never authorizes a larger header budget or changes a domain outcome.

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

Flight result conversion refuses unsigned COUNT values above signed int64 maximum
with `flight.integer_out_of_range` (UNIMPLEMENTED), output-stage evidence and the
exact column/value/range. This is a transport-profile limitation, not a failed
computation; the native uint64 result remains unchanged. Invalid Arrow or IPC
result evidence maps to DATA_LOSS. Invalid clock observations and ticket expiry
remain separate failures. The gateway retains native rejection evidence before
disposing its RPC client, and adds a selected query target only when available and
permitted by the diagnostic's disclosure category.
