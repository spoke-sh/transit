# Finite Flight compatibility

The [protocol](../../../../contracts/FLIGHT_V1.md) defines exact formats and
exclusions; the [proof ledger](../../../../tests/README.md)
records executed combinations. A new combination requires its own evidence.

| Dimension | Selected profile |
| --- | --- |
| Source/result | Public Table query v1; one explicitly configured Table per caller |
| Application types | Two int64 columns, nullable value; full-width integers remain exact |
| SQL | Existing Fuze read-only SELECT compiler, filters, limits, count and checked sum |
| Wire | Apache Arrow 23.0.0 Flight/Flight SQL protobuf definitions, pinned in `proto/manifest.json` |
| Clients | PyArrow 23.0.0; Apache ADBC release 24 Flight SQL driver 1.12.0, Python 3.13 and C vtable consumers on Linux x86_64 |
| Discovery | `GetSchema`; `GetFlightInfo`/`DoGet` for catalogs, database schemas, Tables, Table types and selected SqlInfo |
| Statement | `CommandStatementQuery`, one endpoint, ordered schema and finite batches through `DoGet` |
| Admission | Explicit canonical decimal `x-transit-request-sequence`, dedicated native principal/requester; same sequence and plan reconstruct the same signed request |
| Read lifetime | Signed ticket expiry plus current caller/service/source/request authority on every bounded read and final disclosure |
| Metadata types | Standard union/list/map schemas qualified separately; they do not widen application SQL types |
| Unsupported | Prepared parameters, transactions, writes/ingest, `ListFlights`, `DoPut`, `DoExchange`, distributed endpoints and arbitrary actions; explicit UNIMPLEMENTED |
| ADBC fallback | Pinned Python DBAPI attempts preparation and uses its unprepared fallback; C uses direct statement execution |

No custom ADBC driver or foreign query engine runs in the gateway. Metadata
inspection does not grant entry reads, and a caller's source association does not
grant foreign process diagnostics. Board interprets source capture and received
manifest records using its inspection principal; a recorded manifest does not
establish that every result segment remains available.

Native, Compose and reference TLS client workloads pass exact 41-row results, nulls, typed
empty results, count/sum, repeated fetch and exact admission retry. Compose also
passes physical worker/gateway/node/disk recovery (271.18 seconds with packaging,
413 cold objects / 42,821,771 bytes retained). Reference passes the same physical
recovery with fresh Substrate activations in 367.00 seconds (365 cold objects /
37,968,589 bytes). These are single local proof costs, not throughput or hosted CI
budgets. See [examples/flight](../../../../examples/flight/README.md).

Native faults qualify pooled per-RPC identity, exact lost-admission retry,
tampered/foreign/expired tickets, entry-read revocation after a real batch, pin
release, request/source retirement and complete physical recovery. Two concurrent
fetches tolerate deliberately delayed native reads while a third is refused and
current-schema control progresses. One-byte HTTP/2 credit stalls terminate within
the declared write budget. Sampled gateway RSS was 57,794,560 bytes under that
workload; the proof does not establish peak RSS for every admitted combination.
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
and the recorded RPC worker. The qualified outbound type profile is one or two
int64 columns. Its native TLS peer/restart proof is separate from inbound and
placement evidence. Replay has no network dispatch path and requires a complete,
currently authorized capture before reporting successful completion.
