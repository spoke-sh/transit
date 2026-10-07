# Transit and Station bindings

The shared Zig implementation owns signatures, validation, sequencing, framework
transitions and exact recovery. Raw Transit clients and Station SDKs are separate
packages. Host APIs own language types, codecs, scheduling and packaging; generated
wire declarations remain separate from those APIs.

Use the [SDK directory](../docs/reference/sdks.md) for the current Python,
TypeScript, Rust, Ruby, C, C++, Java, .NET, Erlang and Elixir packages. The
[installed examples](../examples/station-sdk/README.md) provide service and requester
programs. All use native v1. The pre-1.0 [versioning policy](../docs/reference/versioning.md)
requires matching current definitions and hard cutovers.

## Shared boundary

The [client ABI](../packages/zig/transit-client/docs/bindings.md) provides owned
operations and saved exact requests. The [Station ABI](../packages/zig/transit-station-bindings/docs/bindings.md)
adds scoped handler turns, bounded state/Table access, durable calls, publication,
Document operations, query results and recorded HTTP/RPC capture. The
[native port](../apps/transit-station-host/README.md) exposes those same operations
to runtimes that use a child process.

Preparation and dispatch are separate. A mutation's original canonical bytes must
survive an unknown outcome and host replacement. Foreign pointers, cancelled host
tasks and application queues do not change durable authority. Destruction joins
owned work and releases native buffers; read results retain their documented
ownership. See [caller semantics](../docs/reference/callers.md).

`just bindings::generate` regenerates declarations and embedded schemas from Zig
exports. `just bindings::check` detects drift. No legacy generic handler package,
compatibility alias or alternative protocol profile is installed.

## Build and verification

Enter `nix develop .#bindings` for the locked language tools. These packages target
Linux x86_64 and are built from this checkout. Native packages retain their local
Nix runtime linkage. Public registries and other platform artifacts are not
provided by these build tasks.

The Python wheel, Node tarball, Ruby gem, Java JAR, .NET NuGet, Rust crate, BEAM OTP and C/C++ archive builders accept `--native-prefix PATH`
to package libraries and hosts from an explicitly selected Zig install prefix. For example,
`python3 -B bindings/build_python.py /tmp/transit-wheels --native-prefix /tmp/transit-native`
uses that prefix's `lib/` and `bin/` artifacts; all must come from the same source
definition and build. Omitting the option uses this checkout's `zig-out/`.

| Task | Work |
| --- | --- |
| `just bindings::build` | Shared client/Station libraries and native hosts |
| `just bindings::native` | Native/port parity, scoped turns, exact recovery, query capture and checkpoint/tail materialization |
| `just bindings::python-test` | Strict Python APIs and clean installed wheel consumers |
| `just bindings::node-sdk-test` | TypeScript checks and installed Node consumers |
| `just bindings::rust-sdk-test` | Locked crates, ownership and installed Rust consumers |
| `just bindings::ruby-sdk-test` | Gems, block/thread ownership and port consumers |
| `just bindings::c-sdk-test` | Installed C11/C++17 APIs and example executables |
| `just bindings::java-sdk-test` | JARs, typed futures and joined port consumers |
| `just bindings::dotnet-sdk-test` | NuGet artifacts and owned task consumers |
| `just bindings::beam-sdk-test` | Installed Erlang/Elixir applications and port ownership |
| `just bindings::sdk-interop` | Installed language service/requester pairs |
| `just bindings::unified-all` | Current query callers over KV, Table and Document sources |
| `just bindings::test` | Native and installed SDK schedules plus interoperability |

The [Nix tools](../nix/bindings-tools.nix) own language versions and dependencies.
The [proof ledger](../tests/README.md) records executed combinations and limits;
a task's presence does not establish that it passed for the current revision.
