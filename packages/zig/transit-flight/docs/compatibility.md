# Finite Flight compatibility

This matrix defines the gateway's supported sources, client versions and limits.
The [protocol](../../../../contracts/FLIGHT_V1.md) specifies exact wire formats.

| Dimension | Supported interface |
| --- | --- |
| Source/result | Query v1 with a Table source; one explicitly configured Table per caller |
| Application types | Up to 128 int64 output columns with declared nullability; checked COUNT conversion from uint64; full-width integers remain exact |
| SQL | Shared logical SELECT compiler, typed filters, limits, `COUNT(*)`, `COUNT(column)`, checked int64 sum and output aliases; unsupported output types reject before admission |
| Wire | Apache Arrow 23.0.0 Flight/Flight SQL protobuf definitions, pinned in `proto/manifest.json` |
| Clients | PyArrow 23.0.0; Apache ADBC release 24 Flight SQL driver 1.12.0, Python 3.13 and C vtable consumers on Linux x86_64 |
| Discovery | `GetSchema`; `GetFlightInfo`/`DoGet` for catalogs, database schemas, Tables, Table types and selected SqlInfo |
| Statement | `CommandStatementQuery`, one endpoint, ordered schema and finite batches through `DoGet` |
| Admission | Explicit canonical decimal `x-transit-request-sequence`, dedicated native principal/requester; same first sequence and plan reconstruct the same signed upload commands |
| Read lifetime | Signed ticket expiry plus current caller/service/source/request authority on every bounded read and final disclosure |
| Metadata types | Standard union/list/map schemas; application SQL types remain int64 |
| Unsupported | Prepared parameters, transactions, writes/ingest, `ListFlights`, `DoPut`, `DoExchange`, distributed endpoints and arbitrary actions; explicit UNIMPLEMENTED |
| ADBC fallback | Pinned Python DBAPI attempts preparation and uses its unprepared fallback; C uses direct statement execution |

Configured Tables carry complete logical schemas and immutable catalog identities.
Selecting an int64 subset or counting a richer column is supported; this does not
add arbitrary logical output types to the primitive Flight profile. GetTables
with include_schema rejects a Table outside that profile. Quoted Unicode names
and up to 255-byte names share the SQL schema rules.

No custom ADBC driver or foreign query engine runs in the gateway. Metadata
inspection does not grant entry reads, and a caller's source association does not
grant foreign process diagnostics. Board interprets source capture and received
manifest records using its inspection principal; a recorded manifest does not
establish that every result segment remains available.

The gateway runs in native, Compose and reference TLS deployments; see
[examples/flight](../../../../examples/flight/README.md) for setup. The
[test guide](../../../../tests/README.md) records client interoperability,
restart recovery, fault schedules and measured resource use.

Each RPC authenticates its caller independently, including on pooled connections.
Lost admission replies recover through the original first request sequence and
canonical upload. Successful FlightInfo application metadata supplies the next
sequence after the complete upload. Tampered,
foreign and expired tickets reject. Reads enforce current permission, pin
availability and request/source lifetime. Per-caller admission allows two
concurrent data RPCs and refuses a third while reserving control capacity.
HTTP/2 credit stalls terminate within the configured write budget.
Compressed, oversized and truncated request frames are rejected before dispatch.

Use the installed client's actual error surface: pinned PyArrow's `GetSchema`
exposes gRPC UNAVAILABLE as `OSError` with status detail, while `DoGet` uses a
typed Flight error. The placement readiness loop only retries unavailability
within its finite budget; it does not retry denied reads or choose a new sequence.

The listener has 16 connections, four data slots and two reserved control slots;
each configured caller has two data slots. Each active RPC owns an 8 MiB native
read/protobuf arena and an 8 MiB Arrow workspace. Connections have 2 MiB arenas;
the default aggregate allocation ceiling is 128 MiB plus stacks/runtime/TLS edge.
At most 16 KiB/message, 64 response messages and 256 KiB framed response are
permitted. Accepted queries are bounded to 63 result segments and 240 KiB retained
IPC. Larger results are refused rather than split into nonstandard messages.

The configured native-read timeout is distinct from the 180-second RPC deadline,
five-second write/credit budget, 300-second connection budget and ticket lifetime
(1–300 seconds). The TLS example permits 185 seconds for the upstream response.
Callers preserve their original sequence after uncertainty. Retrieval starts
the same captured result from its first batch; there is no offset resumption.
Earlier authorized batches remain a prefix until successful terminal status and
complete ordered coverage.

Outbound calls use [transit-station-flight](../../transit-station-flight/README.md)
and the recorded RPC worker. Outbound operations support one or two int64 columns.
Replay has no network dispatch path and requires a complete,
currently authorized capture before reporting successful completion.
