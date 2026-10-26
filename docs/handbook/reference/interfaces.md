# Interface and architecture map

Use this map to move from a user-facing interface to its owning contract and
the mechanisms underneath it. The [interface chooser](../guides/choose-interface.md)
compares entry points; the [component directory](components.md) identifies the
libraries and executables that implement them. Each linked reference states
its supported operations, types, configuration and failure behavior.

## Public entry points

Start with [data, computation and policies](data-model.md) to choose the data
representation, computation lifetime and observations you need. The interfaces
below expose different portions of that lifecycle through shared owners.

| Interface | Usage and limits | Exact owner or description | Mechanisms |
| --- | --- | --- | --- |
| Local supervisor and console | [CLI](cli.md), [configuration](configuration.md), [console](../../../apps/transit-cli/docs/console.md) | [Installation](../../../contracts/APPLICATION_INSTALLATION_V1.md), [configuration](../../../contracts/CONFIGURATION_V1.md) | [Execution and recovery](../internals/execution-model.md), [service sessions](../internals/service-interfaces.md) |
| Native SQL HTTP/TLS and Unix sessions | [SQL sessions](sql-sessions.md), [statements](sql.md) | [SQL session contract](../../../contracts/SQL_SESSION_V1.md) | [Service interfaces](../internals/service-interfaces.md), [query engine](../internals/query-engine.md) |
| PostgreSQL and MySQL | [Database protocols](database-protocols.md), [local login](../../../apps/transit-cli/docs/sql.md) | [Wire adaptation](../../../contracts/SQL_GATEWAY_V1.md) | [Service interfaces](../internals/service-interfaces.md) |
| Application language SDKs | [SDKs](sdks.md), [caller semantics](callers.md), [examples](../guides/workload-examples.md) | [Station ABI](../../../packages/zig/transit-station-bindings/docs/bindings.md), [native protocol](../../../contracts/TRANSIT_V1.md) | [Client/framework boundary](../internals/client-framework.md) |
| Signed native HTTP | [Native protocol](native.md), [permissions](security.md) | [HTTP carriage](../../../contracts/SERVICE_V1.md), [native operations](../../../contracts/TRANSIT_V1.md) | [System model](../internals/system-model.md), [execution](../internals/execution-model.md) |
| Direct Table lifecycle and reads | [Tables](tables.md), [catalog owner](../../../packages/zig/transit-catalog/docs/direct-catalog.md) | [Direct requests](../../../contracts/DIRECT_TABLE_V1.md), [messages](../../../contracts/direct-table-v1.schema.json) | [Storage runtime](../internals/storage-runtime.md), [query engine](../internals/query-engine.md) |
| Application HTTP publication | [Serving](serving.md), [OpenAPI](openapi.md) | [Serving contract](../../../contracts/SERVING_V1.md) | [Service interfaces](../internals/service-interfaces.md) |
| SSE and WebSocket | [Reactive sessions](reactive.md), [AsyncAPI](asyncapi.md) | [Reactive contract](../../../contracts/REACTIVE_V1.md) | [Service interfaces](../internals/service-interfaces.md) |
| Board and operator inspection | [Board guide](../guides/inspect-board.md), [Board OpenAPI](board-api.md) | [Board schema](../../../contracts/transit-board-v1.openapi.json) | [Observed state and authority](../internals/service-interfaces.md) |
| Arrow IPC/C, Flight SQL and ADBC | [Arrow](arrow.md), [Flight compatibility](flight.md) | [Flight contract](../../../contracts/FLIGHT_V1.md), [query contract](../../../contracts/UNIFIED_QUERY_V1.md) | [Query engine](../internals/query-engine.md) |
| Outbound HTTP, gRPC and Flight | [Connectors](connectors.md) | [HTTP effects](../../../contracts/STATION_HTTP_V1.md), [gRPC effects](../../../contracts/STATION_GRPC_V1.md), [Flight effects](../../../packages/zig/transit-station-flight/README.md) | [Effect lifecycle](../internals/effect-lifecycle.md) |

SQL HTTP, signed native HTTP, application Serving and Board are different
interfaces with different authentication and ownership. A native SQL session
handle does not authenticate a Board or Serving request. A transport's ability
to encode a type does not establish query execution support for that type.

## Runtime foundations

| Subject | Current behavior | Technical account |
| --- | --- | --- |
| Ownership, fencing, process turns and delivery | [Processes](processes.md), [streams](streams.md) | [System model](../internals/system-model.md), [execution model](../internals/execution-model.md) |
| Grants, credentials and resource lifetime | [Security](security.md), [retention](retention.md) | [Execution model](../internals/execution-model.md), [state model](../internals/state-model.md) |
| KV, Tables, Documents and associations | [State](state.md), [Tables](tables.md), [Documents](documents.md) | [State model](../internals/state-model.md) |
| Station calls, supervision and host boundaries | [Station](station.md), [callers](callers.md) | [Client/framework boundary](../internals/client-framework.md) |
| Planning, snapshots, typed batches and result publication | [Queries](queries.md), [SQL types](sql/types.md), [Arrow](arrow.md) | [Query engine](../internals/query-engine.md) |
| Page storage, immutable bulk data, concurrency and cleanup | [Storage](storage.md), [retention](retention.md) | [Storage runtime](../internals/storage-runtime.md) |
| Installation, replacement and physical deployment | [Applications](applications.md), [deployment](deployment.md) | [Execution model](../internals/execution-model.md) |
| Logs, metrics, diagnostics and measured cost | [Observability](observability.md), [performance](performance.md), [benchmarks](benchmarks.md) | [Verification method](../internals/verification-method.md), [storage runtime](../internals/storage-runtime.md) |

## Compatibility and evidence

[Contract downloads](contracts.md) provides machine-readable descriptions from
their authoritative sources. [Versioning](versioning.md) explains why a v1 name
alone does not establish compatibility between builds. [Verification limits](verification.md)
separates current guarantees from the scope of executed checks; the repository's
[proof ledger](../../history/qualification/README.md) owns those execution records.

The handbook documents the checked-out source revision. References and guides
describe use; Internals explains models, invariants, tradeoffs and evidence.
Neither a published page nor a successful documentation build certifies a new
runtime profile. Component API guides remain beside their implementations and
are included or linked from these owners.
