# Language SDKs

Raw Transit and Station are separate public packages. Raw clients prepare signed
operations, read capabilities and preserve exact recovery. Station adds typed
messages, private turns, Tables and handler runners. Shared protocol and framework
semantics stay in Zig; host packages own language types, codecs and scheduling.

Build and install the SDKs from this checkout on Linux x86_64. Follow each
package's installation commands and the [SDK examples](../../examples/station-sdk/README.md).
Packages are not distributed through public registries.

| Language | Raw client | Framework |
| --- | --- | --- |
| Zig | [transit-client](../../packages/zig/transit-client/README.md) | [transit-station](../../packages/zig/transit-station/README.md) |
| Python | [transit-client](../../packages/python/transit-client/README.md) | [transit-station](../../packages/python/transit-station/README.md) |
| TypeScript / Node.js | [transit-client](../../packages/ts/transit-client/README.md) | [transit-station](../../packages/ts/transit-station-sdk/README.md) |
| Rust | [transit-client](../../packages/rust/transit-client/README.md) | [transit-station](../../packages/rust/transit-station/README.md) |
| Ruby | [transit-client](../../packages/ruby/transit-client/README.md) | [transit-station](../../packages/ruby/transit-station/README.md) |
| C | [transit-client](../../packages/c/transit-client/README.md) | [transit-station](../../packages/c/transit-station/README.md) |
| C++ | [transit-client](../../packages/cpp/transit-client/README.md) | [transit-station](../../packages/cpp/transit-station/README.md) |
| Java | [transit-client](../../packages/java/transit-client/README.md) | [transit-station](../../packages/java/transit-station/README.md) |
| .NET | [transit-client](../../packages/dotnet/transit-client/README.md) | [transit-station](../../packages/dotnet/transit-station/README.md) |
| Erlang | [transit-client](../../packages/beam/transit-client/README.md) | [transit-station](../../packages/beam/transit-station/README.md) |
| Elixir | [transit-client](../../packages/beam/transit-client-elixir/README.md) | [transit-station](../../packages/beam/transit-station-elixir/README.md) |

The ten non-Zig language targets use the shared native boundary. Browser clients
use separate generated, runtime-validated [query](../../packages/ts/transit-query-client/README.md),
[reactive](../../packages/ts/transit-reactive-client/README.md) and
[application](../../packages/ts/transit-application/README.md) packages; the Node
native client is not a browser credential adapter.

## Rules that travel across languages

- Supply credentials and the protocol profile explicitly; imports perform no I/O.
- A host task/future is not a durable call. Cancelling an await does not establish
  external cancellation or undo accepted work.
- Retain a saved mutation's canonical bytes after an unknown outcome. Exact retry
  must preserve its identity across process and language boundaries.
- Handler fields and scheduling queues are volatile. Commit durable values in
  the turn's state resource and release borrowed views at their documented scope.
- Read bounded pages and own/release Arrow buffers through the binding contract;
  do not copy the whole retained collection into a resident queue.

Use [caller and SDK semantics](callers.md) for authority, scoped turns, native
ownership, scheduling and exact recovery.
`transit app` installs separately compiled Zig workers. Other SDKs provide client
and framework APIs; the local supervisor has no worker adapter for those languages.
