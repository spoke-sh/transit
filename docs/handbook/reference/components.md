# Component directory

Use these package interfaces to find APIs, configuration and implementation
ownership. Libraries do not imply separate processes; entry points compose them.
The [architecture](architecture.md) explains dependency direction and authority.

Start from the [data model](data-model.md) when locating a change. Catalog and
Station own data definitions and publication; Query and Fuze own query admission,
source interpretation and computation. Native authorization and retention govern
access and lifetime. SQL, SDK and Board adapters expose those owners. Core,
storage and runtime libraries provide the execution and persistence mechanisms;
their dependency boundaries do not define a separate product model.

## Consumer SDKs

Language APIs and native distribution packages live in [sdks/](../../../sdks/README.md).
The [SDK handbook](sdks.md) groups installation and client/framework guides by
language. Zig consumers use the [SDK entry package](../../../sdks/zig/README.md);
the implementations listed below remain shared runtime libraries.

## Libraries

| Package / module | Owns | Direct package dependencies |
| --- | --- | --- |
| [transit-http-server](../../../packages/zig/transit-http-server/README.md) / `transit_http_server` | Bounded HTTP/1.1 and WebSocket framing, concurrent socket ownership, control reserve and joined deadlines; consumed by Board and serving | None |
| [transit-station-app](../../../packages/zig/transit-station-app/README.md) / `transit_station_app` | neutral definitions, shared compiler, signed conditional publication, bounded host contract and upload continuation | transit-serving |
| [transit-serving](../../../packages/zig/transit-serving/README.md) / `transit_serving` | admission/current reads; session controls, Table watch coverage and generated reactive contracts | transit-station, transit-query |
| [transit-diagnostics](../../../packages/ts/transit-diagnostics/README.md) | Owned shared diagnostic validation and caller-facing rendering | transit-protocol diagnostic schema, AJV |
| [transit-reactive-client](../../../packages/ts/transit-reactive-client/README.md) | Browser transport, bounded reactive attachments, lease renewal and explicit recovery through a Zig host | transit-diagnostics, AJV; reflected reactive host contract |
| [transit-query-client](../../../packages/ts/transit-query-client/README.md) | Reflected finite-query host types, bounded browser transport, semantic cell validation and complete-result reads shared by Board and applications | transit-query schema, transit-reactive-client caller coordination, transit-diagnostics, AJV |
| [transit-application](../../../packages/ts/transit-application/README.md) | generated validators, pure visual edits, scoped signing and exact pending/reviewed-plan recovery | transit-station-app reflected contract, transit-reactive-client, transit-diagnostics, AJV |
| [transit-serving-http](../../../packages/zig/transit-serving-http/README.md) / `transit_serving_http` | Reusable signed HTTP/SSE/WebSocket dispatch, local challenges and joined streaming tasks | transit-serving, transit-http-server |
| [transit-exchange](../../../packages/zig/transit-exchange/README.md) / `transit_exchange` | segment capture, frozen intent coverage and explicit cleanup | transit-station |
| [transit-station-document](../../../packages/zig/transit-station-document/README.md) / `transit_station_document` | structured merge, collaborative text and paged accepted-state publication | transit-station |
| [transit-station-http](../../../packages/zig/transit-station-http/README.md) / `transit_station_http` | finite HTTP request construction, strict framing and durable capture | transit-exchange, transit-tls |
| [transit-tls](../../../packages/zig/transit-tls/README.md) / `transit_tls` | Compiler-pinned TLS client with bounded certificate-path verification | Pinned zig-libs certificate-validation snapshot |
| [transit-tls-server](../../../packages/zig/transit-tls-server/README.md) / `transit_tls_server` | TLS 1.2/1.3 server sessions over bounded, deadline-controlled Zig I/O | Pinned OpenSSL 3.6.4 server API |
| [transit-sql-protocol](../../../packages/zig/transit-sql-protocol/README.md) / `transit_sql_protocol` | SQL session messages, canonical logical carriage and SCRAM | transit-fuze, transit-protocol |
| [transit-sql-client](../../../packages/zig/transit-sql-client/README.md) / `transit_sql_client` | Native HTTP/TLS and Unix session transport, authentication, local discovery and owned responses | transit-sql-protocol |
| [transit-sql](../../../packages/zig/transit-sql/README.md) / `transit_sql` | Shared SQL sessions, credentials, catalog-bound statements and paged account recovery | transit-station, transit-query, transit-catalog |
| [transit-postgres](../../../packages/zig/transit-postgres/README.md) / `transit_postgres` | PostgreSQL frames and deferred-write extended-cycle gate | transit-sql |
| [transit-mysql](../../../packages/zig/transit-mysql/README.md) / `transit_mysql` | Bounded MySQL classic packet framing and sequence checks | transit-sql |
| [transit-station-grpc](../../../packages/zig/transit-station-grpc/README.md) / `transit_station_grpc` | durable finite RPC adapter | transit-exchange, transit-grpc |
| [transit-flight](../../../packages/zig/transit-flight/README.md) / `transit_flight` | Finite Table Flight gateway, pinned wire, bounded IPC and standard metadata codecs | transit-grpc, transit-query, transit-serving |
| [transit-station-flight](../../../packages/zig/transit-station-flight/README.md) / `transit_station_flight` | Recorded outbound Flight requests and bounded typed replay | transit-flight, transit-station-grpc |
| [transit-grpc](../../../packages/zig/transit-grpc/README.md) / `transit_grpc` | Finite HTTP/2 RPC transport and protobuf codecs; no dispatch authority | transit-tls, pinned zig-libs HTTP/2/protobuf/gRPC client snapshot |
| [transit-observability](../../../packages/zig/transit-observability/README.md) / `transit_observability` | Transit diagnostic vocabulary and optional instrumentation | transit-protocol, telemetry |
| [telemetry](../../../packages/zig/telemetry/README.md) / `telemetry` | Bounded diagnostic sinks, local metrics and trace context | None |
| [transit-config](../../../packages/zig/transit-config/README.md) | Typed configuration input, setting descriptions, units, provenance and signed service contract | Public protocol |
| [transit-protocol](../../../packages/zig/transit-protocol/README.md) / `transit_protocol` | Public types, signatures, opaque values, schema, shared fixtures | None |
| [transit-core](../../../packages/zig/transit-core/README.md) / `transit_core` | Protocol state, validation, conditional authority, recovery | transit-protocol |
| [transit-client](../../../packages/zig/transit-client/README.md) / `transit_client` | Signed HTTP calls, activation sessions, retry material | transit-protocol, transit-observability |
| [transit-backend-ursula](../../../packages/zig/transit-backend-ursula/README.md) / `transit_backend_ursula` | Storage/transport, checkpoint, trim, deletion, `UrsulaWal` partition streams | transit-core, transit-observability, transit-storage, upstream ursula-zig |
| [transit-backend-local](../../../packages/zig/transit-backend-local/README.md) / `transit_backend_local` | Native authority WAL publication, immutable pages/blocks, direct data quota/epoch adapter, current authority fence and bounded caches | transit-core, transit-storage, transit-observability; transit-fuze for composition tests |
| [transit-storage](../../../packages/zig/transit-storage/README.md) / `transit_storage` | `TransitLog`, `TransitObjectStore`, immutable data indexes, single-owner `TablePartition` acceptance/read pins, `TableMemtable`, `NvmeCache`, manifest/OCC components | transit-protocol, transit-core generic pages, transit-fuze |
| [transit-board-api](../../../packages/zig/transit-board-api/README.md) / `transit_board_api` | Board response types, OpenAPI generation and evidence projections | transit-protocol, transit-station (framework metadata), transit-query, transit-exchange, transit-station-http/grpc/document (allowlisted metadata) |
| [transit-board-client](../../../packages/ts/transit-board-client/README.md) (TypeScript) | Generated Board models/runtime validators and bounded browser transport | AJV runtime helper |
| [transit-runtime-substrate](../../../packages/zig/transit-runtime-substrate/README.md) / `transit_runtime_substrate` | Provider identity, template validation, sandbox lifecycle operations | transit-observability; invokes pinned external CLI |
| [transit-station](../../../packages/zig/transit-station/README.md) / `transit_station` | GenServer, durable calls, scoped names, supervision, Tables and captured queries | transit-client, transit-fuze |
| [transit-station-bindings](../../../packages/zig/transit-station-bindings/README.md) / `station_abi` | Shared native SDK handles, detached turn actions, C exports and generated host schemas; composes above the framework | transit-station, transit-client ABI, transit-station-http |
| [transit-query](../../../packages/zig/transit-query/README.md) / `transit_query` | Signed query admission, verified typed pages and KV/Table/Document adapters | transit-station, transit-station-document |
| [transit-catalog](../../../packages/zig/transit-catalog/README.md) / `transit_catalog` | Named Table creation, immutable definitions, bounded metadata, signed caller, neutral values and explicit catalog behavior | transit-station |
| [transit-fuze](../../../packages/zig/transit-fuze/README.md) / `transit_fuze` | Source/plan contracts, Table SQL compilation and bounded Zig-native Arrow execution | pinned zarrow, zarrow-compute |


## Executables and examples

| Entry point | Role |
| --- | --- |
| [transit-sql-gateway](../../../apps/transit-sql-gateway/README.md) | Shared SQL runtime, native HTTP/TLS and Unix peer sessions, PostgreSQL/MySQL listeners and account recovery |
| [transit-flight-gateway](../../../apps/transit-flight-gateway/README.md) | Finite Table Flight SQL over a private HTTP/2 listener behind an explicit TLS edge |
| [transit-station-document-worker](../../../apps/transit-station-document-worker/README.md) | authenticated Document writer and bounded maintenance |
| [transit-station-grpc-worker](../../../apps/transit-station-grpc-worker/README.md) | finite RPC preparation/dispatch/capture worker |
| [transit-station-http-worker](../../../apps/transit-station-http-worker/README.md) | finite HTTP preparation/dispatch/capture worker |
| [transit-node](../../../apps/transit-node/README.md) | Hosts core with Ursula, signed ingress, trusted time; separate maintenance mode |
| [transit-delivery](../../../apps/transit-delivery/README.md) | Public-client courier for ordered committed outboxes; no storage or handler authority |
| [transit-runtime-controller](../../../apps/transit-runtime-controller/README.md) | Composes public client and Substrate adapter to reconcile one PID |
| [transit-station-controller](../../../apps/transit-station-controller/README.md) | Observes Station timers/children or applies separately scoped lifecycle intent |
| [transit-station-host](../../../apps/transit-station-host/README.md) | Bounded native port for host languages; delegates to the shared ABIs |
| [transit-client-host](../../../apps/transit-client-host/README.md) | Standalone raw client port; canonical recovery and metadata without Station |
| [transit-query-host](../../../apps/transit-query-host/README.md) | Runnable source/requester workers and scoped courier |
| [transit-table-service](../../../apps/transit-table-service/README.md) | Signed original-subject Table mediation with private storage credentials |
| [transit-cli](../../../apps/transit-cli/README.md) (`transit`) | Local server lifecycle and shared local/remote SQL sessions |
| [transit-board](../../../apps/transit-board/README.md) | Inspection API plus optional query capability with embedded [TanStack Router frontend](../../../apps/transit-board-web/README.md); public client and transit-board-api composition |
| [kubectl-transit](../../../apps/kubectl-transit/README.md) | Kubernetes installation/workload inspection, service logs and origin-aware Board access |
| [transit-admin](../../../apps/transit-admin/README.md) | Signs/submits commands and reads scoped views |
| [example-counter](../../../examples/counter/README.md) | Complete caller, also the reference deployment workload |
| [example-byte-log](../../../examples/byte-log/README.md) | Independent caller against the same generic authority |
| [example-station-ledger](../../../examples/station-ledger/README.md) | Three Station processes with Tables, calls, registry, supervision and Arrow replies |
| [example-state-query](../../../examples/state-query/README.md) | Finite SQL caller with private original-intent recovery and bounded owned pages |
| [example-station-document](../../../examples/station-document/README.md) | Independent structured/text editors over the public Document call/read APIs |


Core depends on the public protocol, never Station or a provider. Fuze has no
Station, Ursula or Substrate dependency. Language SDKs use the shared Zig client
and framework through generated boundaries; see the [SDK index](sdks.md).
Applications import public package modules rather than sibling source files.
Each library owns its manifest, direct dependencies and focused checks.

## Repository tooling

The [handbook project](../README.md) contains the Docusaurus site and its guides,
reference and Internals sources. It builds static documentation from those
sources, selected component guides and generated interface descriptions. It has
no runtime dependency on a Transit server. The [interface map](interfaces.md)
connects this directory's implementation owners to public usage and internals.
