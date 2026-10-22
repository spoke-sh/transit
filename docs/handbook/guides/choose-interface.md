# Choose an interface

Choose an interface for the data and lifecycle you need: defining a Table,
reading a Document, computing a result or observing change. The
[data model](../reference/data-model.md) connects representations, computation
lifetimes and policies. Each interface exposes selected operations through the
owning data or execution service; a transport never grants authority.

| Your task | Entry point | Supported boundary |
| --- | --- | --- |
| Define, query and evolve Tables | [Quickstart](quickstart.md), [Table catalog](../reference/tables.md) | Shared SQL/typed lifecycle, current object rights and atomic statement publication |
| Use KV or collaborative Documents | [Resource client](../reference/state.md), [Document services](../reference/documents.md) | Explicit encoding or accepted structured revisions; SQL declarations do not provision these objects |
| Run interactive SQL | [Console](../../../apps/transit-cli/docs/console.md), [SQL reference](../reference/sql.md) | Independent server-managed local/remote sessions; finite reads, Table mutations and scoped administration |
| Build a SQL session client | [SQL HTTP/TLS API](../reference/sql-sessions.md) | Logical sessions, typed results and token-based recovery of accepted operations |
| Use a PostgreSQL or MySQL client | [Database protocols](../reference/database-protocols.md) | Explicit listeners and authentication, autocommit Table reads/writes and six scalar types; optional local TLS |
| Inspect the system | [Board OpenAPI](../reference/board-api.md) | Private viewers share a scoped read identity; optional query/operator identities are separate |
| Expose application commands and reads | [Serving OpenAPI](../reference/openapi.md) | Signed native commands and scoped reads through a published service |
| Follow changes | [Reactive API / AsyncAPI](../reference/asyncapi.md) | Int64 Table sessions and resumable notifications, fetch-SSE or WebSocket |
| Connect an Arrow analytical client | [Flight SQL / ADBC](../reference/flight.md) | Finite Table v1, selected int64 types and independently tested clients |
| Capture or maintain a relational result | [Typed Zig query owners](../reference/queries.md#relational-boundary) | Frozen definitions, explicit activation and recorded source vectors; maintained wakeups are host-managed |
| Call an external HTTP or RPC service | [Connectors](../reference/connectors.md), [gRPC](../reference/connectors.md) | Recorded effect intent, capture, retry policy and unknown outcomes |
| Start a server or install an app | [Transit CLI](../reference/cli.md) | Trusted local Linux supervisor; automatic first startup and exact recovery |
| Implement a worker or durable caller | [Zig client and language SDKs](../reference/sdks.md) | Shared protocol/Station semantics with target-language types and ownership |
| Integrate a native protocol client | [Signed HTTP protocol](../reference/native.md) | Versioned JSON envelopes, canonical signing, current grants and exact retry |

## Version and capability rules

The [versioning policy](../reference/versioning.md) requires one current v1
definition per Transit-owned protocol before 1.0 and hard cutovers between
incompatible definitions. The interfaces below use the current v1 definitions.

A CLI version, native protocol version, query profile and application revision
are different identifiers. Use the profile in your actual configuration and the
server's authorized capability read. No interface silently converts old durable
history into a new profile.

- Query v1 declares KV, Table or accepted Document sources and preserves five
  cell states in nested Arrow output.
- Flight SQL uses the same query path for its configured int64 Table subset,
  converting verified results to primitive Arrow columns.
- OpenAPI describes Board and the serving HTTP adapter. It does not replace the
  native signing specification or turn every kernel operation into a REST route.
- AsyncAPI describes the reactive WebSocket binding. Fetch-SSE is documented by
  OpenAPI; both use the same durable session/subscription semantics.
- SQL reference grammar contains additional administrative declarations.
  Parser acceptance does not make them executable commands.

See [architecture and scope](../reference/architecture.md) for component
responsibilities and [deployment](../reference/deployment.md) for supported environments.
The [interface and architecture map](../reference/interfaces.md) connects each
surface to its contract, usage reference and internals.
