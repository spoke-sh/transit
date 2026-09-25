# Arrow interchange and remote queries

Status: M9 implements finite IPC results, checked by an independent Arrow
consumer, and qualifies C Data/C Stream ownership. See the [integration evidence](../packages/zig/transit-fuze/docs/integration.md).
Remote interoperability remains planned: [M14](roadmap/M14.md) adds gRPC and
[M15](roadmap/M15.md) qualifies Flight, Flight SQL and ADBC.
[TABLES.md](TABLES.md) owns Table mutations, snapshots, materialization, transactions
and durable result delivery. This document owns the interchange and gateway seams.

## Roles in the stack

| Surface | Role in Transit | Boundary |
| --- | --- | --- |
| Arrow arrays and record batches | Typed columnar data for computation and results | Representation does not define durable state or transactional visibility |
| C Data / C Stream | In-process array and batch-reader exchange across bindings | Explicit buffer ownership; distinct from the Transit/Station command ABI |
| IPC | Serialized schema/batches for durable results and cross-process exchange | IPC stream/file formats do not supply admission, recovery or retention |
| Fuze | Shared planning and bounded computation over authorized state views; Table first | Runs in callers/workers, never in `transit-node`; [engine design](FUZE.md) |
| Flight RPC | Remote Arrow result discovery and transfer | Network streams/tickets do not replace durable mailboxes or grants |
| Flight SQL | Standard SQL query/metadata interface over Flight | Needs our own planner, capability profile and transaction semantics |
| ADBC | Client/driver API for consuming the query service | Not another wire protocol or the general Transit execution client |

These distinctions follow Arrow's [columnar/IPC format](https://arrow.apache.org/docs/format/Columnar.html),
[C Data interface](https://arrow.apache.org/docs/format/CDataInterface.html),
[Flight](https://arrow.apache.org/docs/format/Flight.html),
[Flight SQL](https://arrow.apache.org/docs/format/FlightSql.html) and
[ADBC API](https://arrow.apache.org/adbc/current/format/specification.html).
The Transit ownership, lifetime and recovery rules below are our design choices.
Keep the engine's batch-reader interface independent of serialization. IPC stream
bytes and Flight's `FlightData` framing need separate codecs; do not assume a
whole IPC stream can be copied into an RPC response unchanged.

The engine, planner, connectors and gateway remain Zig native. Do not embed
DataFusion, Acero or another foreign query engine to implement them. Independent Arrow
libraries and external clients may be used for interoperability tests. Client
driver implementation languages do not change the server language boundary.

## Fuze execution boundary

[Fuze](FUZE.md) owns the Zig-native query engine: shared source/plan/operator
interfaces, DataFusion- and Acero-inspired design, bounded execution and recovery.
It targets KV, Table and Document queries; M9 qualifies the first Table profile.
This document owns interchange and remote query access. SQL and Flight reuse
Fuze's qualified semantics; neither broadens resource transactions or supplies
continuous materialization automatically.

## Flight gateway and effect connector

There are two paths, with different authority boundaries:

```mermaid
flowchart LR
    External[Arrow / ADBC client] -->|Flight / Flight SQL| Gateway[Zig Flight gateway]
    Gateway -->|Authenticated public client requests| Service[Station Table service PID]
    Service -->|Accepted snapshot result| Gateway
    Service -->|Committed external effect intent| Connector[gRPC connector worker]
    Connector -->|Authorized RPC attempt| Remote[External gRPC / Flight service]
```

The gateway submits Table requests and retrieves accepted results through public
Transit/Station interfaces. It cannot scan Ursula or bypass the writer's service
policy. Flight SQL discovery must use an explicitly published, permissioned
Table catalog; association or naming alone does not expose a resource as SQL.

The [gRPC connector](GRPC.md) covers outbound external calls, including calls to
an external Flight service. Responses used by a handler must enter through
recorded observations; calling a Flight client directly from a handler would
bypass the effect boundary. Share Zig HTTP/2, protobuf and codec machinery where
useful, while keeping ingress identity mapping and effect dispatch separate.

## First remote query profile

M15 starts with read-only, finite queries over one Table/resource snapshot.
Read-only refers to application tables; accepting queries and tracking result
delivery still require authorized durable bookkeeping:

- Flight query discovery/schema and `DoGet` retrieval of captured results. Use
  one endpoint per result initially so there is no cross-endpoint ordering or
  consistency promise. Define ticket validation, errors and reconnect behavior.
- Flight SQL statement queries and catalog/schema/capability metadata. Specify a
  bounded `SELECT` grammar with projection, supported predicates, limit and the
  qualified aggregates. Lower it to the same Fuze structured plans used by M9.
- No table writes, bulk ingestion, query federation, general SQL, transactions,
  savepoints or durable continuous `DoExchange` in this profile. Reject unsupported
  requests explicitly and report capabilities truthfully. Add prepared statements
  only if the selected client matrix requires them, with scoped handle lifetimes;
  parameter binding must not become arbitrary SQL string interpolation.

Flight SQL defines fixed metadata schemas, including the union/list/map types in
`GetSqlInfo`. Qualify those protocol schemas separately from M9's much smaller
Table type matrix; a successful scalar query is insufficient evidence of driver
compatibility. See the [Flight SQL definitions](https://arrow.apache.org/docs/format/FlightSql.html).

Reuse the existing [ADBC Flight SQL driver](https://arrow.apache.org/adbc/current/driver/flight_sql.html)
as the first client path. Prove pinned C and Python clients against our Zig
endpoint before considering a dedicated Transit ADBC driver. ADBC does not
replace M9's process/GenServer bindings, and support in those bindings does not
prove compatibility with every Arrow client or driver version.

## Identity, lifetime and failure

M15 must select and prove an ingress identity profile. Start with explicitly
configured gateway credentials mapped to dedicated, least-privilege Transit
principals and allowed Table service PIDs. Do not trust principal/PID claims in
request metadata or invent general delegation, which is not implemented. TLS
authentication, service data-sharing policy and current resource permissions
are distinct checks. Board's private shared-viewer policy is not automatically
the Flight gateway's policy; scope this boundary in [Security](SECURITY.md).

Tickets and query handles identify an exact result, realm, principal/service
scope, schema and revision. Bind each fetch to current permission and result
availability; possession alone does not authorize access. Avoid raw provider URLs
and secrets in tickets, logs or catalogs. Revalidate continuing reads at a
declared bounded batch/byte interval, including cached results and metadata.
Revocation prevents further authorization; already released bytes cannot be
recalled. Do not expose hidden tables through names, counts or error distinctions.

Durable result retention follows the application's opted-in policy and defaults
to unlimited. A finite connection timeout or expiring access ticket does not
silently authorize result deletion. A new handle cannot extend a hard result or
source lifetime. Bound admission and resident buffers even with unlimited
retention; sustained backlog may reject new work.

A dropped connection does not cancel durable work or imply remote consumption.
Retrying `DoGet` for the same available ticket restarts retrieval of that captured
result; clients discard their partial copy or use an explicitly qualified resume
extension. No standard offset-resume guarantee is assumed. Gateway restart must
resolve an existing ticket from durable result evidence; unavailable/expired
results fail explicitly. Cancelling a query is an authorized durable disposition,
not a socket-close side effect. Repeated SQL submissions are new queries unless
the client supplies a supported stable request identity; SQL text is not a dedup key.

M15 must budget SQL/protobuf requests, standard metadata schemas, result bytes,
ticket records and pending queries against the profile it actually deploys.
Network streaming cannot conceal a missing durable payload/lifetime contract or
raise M7's limits implicitly. A larger storage/result profile requires an explicit
prerequisite milestone if the selected interoperability fixtures cannot fit.

## Qualification and later work

[M9](roadmap/M9.md) proves batches, operator behavior and IPC/C ownership with
independent consumers. [M14](roadmap/M14.md) proves the gRPC transport and effect
boundary. [M15](roadmap/M15.md) proves actual Flight/ADBC clients, authentication,
schemas, backpressure, cancellation and recovery together. Keep dependency pins,
supported protocol versions and proof commands with the implementing packages.
Flight SQL writes, a native ADBC driver, continuous query maintenance and
cross-resource/distributed transactions need their own future milestones.
