# Finite gateway configuration

With `transit-flight-gateway` installed on `PATH`, run
`transit-flight-gateway /private/gateway.json`. Provision service,
query hosts and grants before starting this adapter. The
[Flight proof](../../../tests/README.md) creates
an owned, disk-backed native installation with real query hosts, a TLS edge and
pinned independent clients. It deletes only its temporary installation on exit.

The private JSON file is limited to 16 KiB. Required fields are `url` (trusted
native authority), `inspector`, `inspector_seed_file`, `ticket_seed_file`, `port`
and `callers`. Each caller supplies `credential_file`, `seed_file`, `connection`
(realm, principal, source, resource, table, name, requester and requests), `service`, `binding_revision` and two `columns`.
The native principal is dedicated to that requester's admission sequence and is
scoped to its PID. Associate its source resource explicitly and grant current
source/requester inspect and read rights. Publish the matching binding and read/
command policy through `FiniteService`; grant the inspector read-only inspection.
The configured schema must match the current Table schema.

A credential file contains 32–128 ASCII letters, digits, underscores or hyphens,
with no newline. Generate high-entropy credentials; only their SHA-256 hashes
remain in the gateway. Seed files use the existing private Ed25519 hex format.
Keep all files private and out of Git. Ticket keys may be shared by replicas
serving the same mappings. They do not grant data access. Every RPC authenticates
again and every bounded disclosure checks current service and resource rights.

The default listener is `127.0.0.1`; `listen` selects a private IPv4 address.
Terminate verified TLS with the explicit [gRPC edge](../../../examples/flight/nginx.conf.in).
Its 185-second upstream read allowance covers the gateway's 180-second joined RPC
budget; stalled client writes retain a five-second limit. Do not expose plaintext
outside the private deployment boundary. Clients must configure the deployment
CA and verify the hostname; disabling certificate verification is not supported.

| Bound | Default / ceiling |
| --- | --- |
| Caller mappings | 8, unique credential/principal/requester |
| Active data RPCs | 2 per caller, 4 listener-wide |
| Reserved control RPCs | 2 (`GetSchema`, `ListActions`) |
| Connections | 16, one active RPC each, 64 sequential calls, 300 s lifetime |
| Native request deadline | `native_timeout_ms`: 5000; maximum 30000 |
| RPC deadline | `options.request_timeout_ms`: 180000, bounded by connection lifetime |
| Ticket lifetime | `ticket_ttl_ms`: 60000; 1000–300000 |
| Clock uncertainty | `clock_error_ms`: 1000; maximum 5000; use synchronized clocks |
| Adapter workspace | 8 MiB protobuf/native allocation plus 8 MiB Arrow per active RPC |
| Transport workspace | 2 MiB per connection, plus fixed socket/frame buffers |
| Message / stream | 16 KiB / 256 KiB framed, at most 64 response messages |
| Finite statement result | At most 63 batches and 240 KiB retained IPC before ticket issuance |

`options` uses the validated inbound gRPC server configuration. Adapter workspace
and connection memory are independent: default six admitted RPCs and sixteen
connections budget 128 MiB of those allocations before stacks, runtime and TLS
edge overhead. This is a bound, not an RSS measurement or production scale claim.
There is no retained-result cache in the gateway.

Supply `x-transit-request-sequence` explicitly for statement `GetFlightInfo`.
Retain that first sequence and original SQL/schema through an unknown outcome.
The upload uses consecutive native sequences; FlightInfo application metadata
returns its `next_sequence` for a subsequent statement. Do not overlap uploads or
choose a new sequence as an automatic retry. Ticket expiry does
not cancel the accepted query or delete its captured result. Fetching again
starts at the same result's first batch; partial streams never count as complete.
Fixed telemetry records operation, error kind and duration, excluding SQL,
credentials, tickets and values. See [FLIGHT_V1](../../../contracts/FLIGHT_V1.md)
for the supported RPCs, schemas and authority rules.
