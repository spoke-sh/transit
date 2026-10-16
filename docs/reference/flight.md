# Flight SQL and ADBC

The Flight gateway serves finite, read-only Table queries using Fuze and the
existing durable query requester. Each gateway serves a single configured
Table with an immutable catalog definition. Results support up to 128 int64
columns, preserving declared nullability, plus checked int64 COUNT outputs. It uses the current
KV/Table/Document query v1 interface and adapts verified Table cells to ordinary
Arrow columns. Missing, conflicted and mistyped cells reject.

| Surface | Supported profile |
| --- | --- |
| Statement execution | `CommandStatementQuery`, one endpoint, ordered finite batches through `DoGet` |
| Metadata | `GetSchema`, catalogs, database schemas, Tables, Table types, selected SqlInfo |
| Application SQL | [query SQL](sql/select.md), including `COUNT(*)`, `COUNT(column)`, checked sum, output aliases and typed empty results |
| Independent clients | PyArrow 23.0.0; ADBC release 24 Flight SQL driver 1.12.0, Python 3.13 and C vtable on Linux x86_64 |
| Excluded | Prepared parameters, transactions, writes/ingest, `ListFlights`, `DoPut`, `DoExchange`, distributed endpoints and arbitrary actions |

The gateway uses Apache Arrow 23.0.0 protocol definitions. Metadata union/list/map
coverage does not widen application query types. Unsupported operations return
explicit UNIMPLEMENTED. Pinned Python ADBC uses its unprepared fallback.

`GetSchema` and statement execution report SQL syntax, source/type binding and
compiler-bound failures as INVALID_ARGUMENT. Unsupported constructs, grammar-only
families and statements that require a different interface return UNIMPLEMENTED.
Messages give a correction or supported alternative and parser line/byte-column
coordinates where available. Binding errors include the relevant caller-supplied
subject, expected/supplied types and bounded escaped literal. Messages fit the
existing 128-byte decoded gRPC message budget; excess detail ends with
`[truncated]`. SQL excerpts, credentials and unrelated stored values remain
excluded. Percent signs use standard gRPC percent encoding. Authentication and current access
checks precede these diagnostics. A compilation failure does not admit a query or
consume the supplied sequence; an unavailable response after admission still
requires recovery with the original identity below.

A saved query failure reports its original `query.<code>`, admission/execution
stage and request namespace. A measured budget failure also reports its
dimension, limit and required amount without integer precision loss. The gateway
maps arithmetic overflow to OUT_OF_RANGE, budgets to RESOURCE_EXHAUSTED, current
denial to PERMISSION_DENIED and unavailable source/history or invalid cell state
to FAILED_PRECONDITION. A saved cancellation is CANCELLED and retirement is
FAILED_PRECONDITION. Repeating the same request preserves the original cause;
current access checks still gate its disclosure. Flight and ADBC expose these
messages through their normal exceptions. The `transit-diagnostic-bin` binary
trailer also carries the shared [diagnostic envelope](../../contracts/DIAGNOSTICS_V1.md).
PyArrow client middleware receives its JSON bytes; ADBC exposes the named entry
in its error details. It preserves semantic codes, original compiler/runtime
witnesses, exact identities/counters, outcomes and valid recovery actions without
parsing exception prose. The decoded detail is bounded to 4096 bytes; long text
is explicitly truncated or marked unavailable, while numeric evidence remains
exact. The [wire contract](../../contracts/FLIGHT_V1.md#capacity-and-qualification)
specifies metadata encoding and optional-detail failure behavior.

Caller failures retain shared query codes for drafts, cursors, uploads, source
changes and result integrity. Malformed result evidence maps to DATA_LOSS;
invalid input maps to INVALID_ARGUMENT. Allocation/transport failure maps to
UNAVAILABLE and preserves any earlier work. Flight ticket, sequence and protobuf
validation keep their specific profile diagnostics. These failed attempts do
not replace a retained domain outcome or an already unknown submission.

Schema and catalog metadata requests validate the configured immutable Table
definition against the current catalog. ALTER or DROP requires publication of
an updated definition before those requests can describe the successor. Exact
query retries and retained tickets keep their original definition and remain
subject to current authorization.

## Connect with ADBC

Provision the query hosts, service binding, dedicated caller/requester and
[gateway configuration](../../apps/transit-flight-gateway/docs/configuration.md).
The gateway needs a verified TLS edge and an explicitly trusted CA. This example
uses files from that provisioned deployment; it does not create identities.

```python
from pathlib import Path
import adbc_driver_flightsql as flightsql
from adbc_driver_flightsql import dbapi

# Substitute your deployment's verified TLS hostname and private files.
uri = 'grpc+tls://flight.example.test:8443'
credential = Path('/private/flight-credential').read_text()
certificate = Path('/private/flight-ca.pem').read_text()
with dbapi.connect(uri, db_kwargs={
    flightsql.DatabaseOptions.AUTHORIZATION_HEADER.value: 'Bearer ' + credential,
    flightsql.DatabaseOptions.TLS_ROOT_CERTS.value: certificate,
}, autocommit=True) as connection:
    with connection.cursor() as cursor:
        # Choose this sequence deliberately and retain it with the exact SQL.
        cursor.adbc_statement.set_options(**{
            flightsql.StatementOptions.RPC_CALL_HEADER_PREFIX.value
            + 'x-transit-request-sequence': '1',
        })
        cursor.execute('SELECT id, value FROM items LIMIT 8')
        result = cursor.fetch_arrow_table()
```

Use the client versions listed above. The
[finite example](../../examples/flight/README.md) provisions isolated native,
Compose and reference installations and executes the actual Python/C consumers.

## Identity, retry and result lifetime

Every RPC authenticates its caller. Statement admission requires a canonical
decimal `x-transit-request-sequence`; the same sequence and original SQL/schema
reconstruct the same signed upload commands under the same configured key, native
credential epoch and selected role. The query freezes that original authority;
rotation or a role change cannot renew an accepted query. Reusing its first
sequence with changed authority conflicts before further upload. The header is the first sequence of
that upload, which uses multiple consecutive native operations. Preserve it after
uncertainty, including across gateway replacement. Successful FlightInfo application
metadata returns `{"version":1,"next_sequence":N}`. Use that sequence for the next
statement; incrementing the prior first sequence by one overlaps its upload.
Clients without access to FlightInfo application metadata can read their dedicated
principal’s next native sequence after the prior statement completes.

Tickets are signed, scoped to the configured selected role and expiring. They never replace current service,
source and requester rights. Every bounded read and final disclosure rechecks
those rights. Ticket expiry does not cancel a query or delete its result. Fetching
again starts the captured result at its first batch; there is no offset resume.
A partial batch stream remains a prefix until successful terminal completion.

The selected result cap is 63 batches / 240 KiB retained IPC. Larger results
reject rather than invent nonstandard framing. See the
[compatibility matrix](../../packages/zig/transit-flight/docs/compatibility.md)
for client compatibility and memory, connection and deadline limits. See the
[Flight wire contract](../../contracts/FLIGHT_V1.md) for exact messages.

Outbound Flight is a separate [recorded connector](../../packages/zig/transit-station-flight/README.md).
Replay reads its authorized capture without network dispatch. Flight SQL access
is not permission to bypass connector policy for external effects.

A COUNT value above `9223372036854775807` is valid in the native query's uint64
result but cannot be represented by this Flight profile. `flight.integer_out_of_range`
reports the result column, actual value, required type and maximum at the output
stage. It leaves the saved query outcome unchanged; use the native query result
interface to read that value. Invalid Arrow/IPC result evidence instead produces
an integrity diagnostic. Clock failures remain distinct from ticket expiry. Host time plus configured
clock error and ticket lifetime must fit the native counter range; exceeding
that range reports an unavailable clock rather than an invalid caller ticket.

Failed RPC reads retain the selected query identity when available and permitted.
Current denial suppresses that identity and execution facts while retaining the
native denial cause. Earlier compiler, terminal-outcome and uncertain-upload
diagnostics keep priority over the RPC fallback.
