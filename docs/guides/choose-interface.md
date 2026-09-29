# Choose an interface

Transit has several interfaces because durable application calls, operator
inspection and finite analytical queries have different responsibilities.
Choose the owner that matches the job; a transport never grants authority.

| Your task | Entry point | Supported boundary |
| --- | --- | --- |
| Start a neighborhood or install an app | [Transit CLI](../reference/cli.md) | Trusted local Linux supervisor; explicit initialization and exact recovery |
| Implement a worker or durable caller | [Zig client and language SDKs](../reference/sdks.md) | Shared protocol/Station semantics with target-language types and ownership |
| Integrate a native protocol client | [Signed HTTP protocol](../reference/native.md) | Versioned JSON envelopes, canonical signing, current grants and exact retry |
| Run interactive queries | [Console](../../apps/transit-cli/docs/console.md), [SQL reference](../reference/sql.md) | Explicit finite SELECT over configured KV/Table/Document sources |
| Inspect the system | [Board OpenAPI](../reference/board-api.md) | Private viewers share a scoped read identity; optional query/operator identities are separate |
| Expose application commands and reads | [Serving OpenAPI](../reference/openapi.md) | Signed native commands and scoped reads through a published service |
| Follow changes | [Reactive API / AsyncAPI](../reference/asyncapi.md) | Int64 Table sessions and resumable notifications, fetch-SSE or WebSocket |
| Connect an Arrow analytical client | [Flight SQL / ADBC](../reference/flight.md) | Finite Table v1, selected int64 types and independently tested clients |
| Call an external HTTP or RPC service | [Connectors](../CONNECTORS.md), [gRPC](../GRPC.md) | Recorded effect intent, capture, retry policy and unknown outcomes |

## Version and capability rules

A CLI version, native protocol version, query profile and application revision
are different identifiers. Use the profile in your actual configuration and the
server's authorized capability read. No interface silently converts old durable
history into a new profile.

- Query v1 serves a single declared two-column Table; query v2 adds explicit
  KV/Table/Document sources and five-state nested Arrow cells.
- Flight SQL uses the qualified Table v1 path. Its availability does not imply
  that every native query v2 source or type works through Flight.
- OpenAPI describes Board and the serving HTTP adapter. It does not replace the
  native signing specification or turn every kernel operation into a REST route.
- AsyncAPI describes the reactive WebSocket binding. Fetch-SSE is documented by
  OpenAPI; both use the same durable session/subscription semantics.
- SQL reference grammar contains additional administrative declarations.
  Parser acceptance does not make them executable commands.

[Scope](../SCOPE.md) and the [qualification ledger](../../tests/README.md) distinguish
implemented behavior, tested client/topology combinations and planned extensions.
