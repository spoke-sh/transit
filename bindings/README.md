# Transit and Station bindings

The shared Zig implementation owns signatures, validation, sequencing, framework
transitions and exact recovery. Raw Transit clients and Station SDKs are separate
packages. Host APIs own language types, codecs, scheduling and packaging; generated
wire declarations remain separate from those APIs.

Use the [SDK directory](../docs/handbook/reference/sdks.md) for the current Python,
TypeScript, Rust, Go, Ruby, C, C++, Java, .NET, Erlang and Elixir packages. Go
provides a raw client; the other non-Zig targets also provide Station adapters. The
[installed examples](../examples/station-sdk/README.md) provide service and requester
programs. All use native v1. The pre-1.0 [versioning policy](../docs/handbook/reference/versioning.md)
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
ownership. See [caller semantics](../docs/handbook/reference/callers.md).

`just bindings::generate` regenerates declarations and embedded schemas from Zig
exports. `just bindings::check` detects drift. No legacy generic handler package,
compatibility alias or alternative protocol profile is installed.

## Source ownership

Language APIs and native distribution manifests live in [sdks/](../sdks/README.md).
Shared Zig implementation and generated ABI owners stay in `packages/zig/`;
this directory owns generation and packaging tools. The Zig SDK exports those
shared modules directly. No runtime package imports the SDK tree.

## Build and verification

Enter `nix develop .#bindings` for the locked language tools. These packages target
Linux x86_64 and are built from this checkout. Native packages retain their local
Nix runtime linkage. Public registries and other platform artifacts are not
provided by these build tasks.

The Python wheel, Node tarball, Ruby gem, Java JAR, .NET NuGet, Rust crate, Go, BEAM OTP and C/C++ archive builders require `--native-prefix PATH`
to package libraries and hosts from an explicitly selected Zig install prefix. For example,
`python3 -B bindings/build_python.py /tmp/transit-wheels --native-prefix /tmp/transit-native`
uses that prefix's `lib/` and `bin/` artifacts; all must come from the same source
definition and build. The task module resolves immutable native outputs through
the [Zig fixture graph](../build/README.md) and records their source, profile,
compiler, target, definition and hashes under `.cache/native-artifacts/`.
Debug and ReleaseSafe package directories are separate under
`.cache/bindings/<profile>/`. Each recipe explicitly selects the authority and
client profiles; installed consumer schedules retain their existing profiles.
The package directories are generated outputs, not cached test results.

| Task | Work |
| --- | --- |
| `just bindings::zig-test` | Shared module identity and isolated real Zig application build |
| `just bindings::runtime-boundary` | Nix runtime and gateway build without SDK source |
| `just bindings::build` | Resolve and record the immutable Debug client fixture set |
| `just bindings::native` | Native/port parity, scoped turns, exact recovery, query capture and checkpoint/tail materialization |
| `just bindings::python-test` | Strict Python APIs and clean installed wheel consumers |
| `just bindings::node-sdk-test` | TypeScript checks and installed Node consumers |
| `just bindings::rust-sdk-test` | Locked crates, ownership and installed Rust consumers |
| `just bindings::go-build` | Go module and matching explicit native installation archives |
| `just bindings::go-check` | Go formatting, vetting, race detection and strict cgo pointer checks |
| `just bindings::go-sdk-test` | Installed Go raw-client and example recovery against a disk-backed authority |
| `just bindings::ruby-sdk-test` | Gems, block/thread ownership and port consumers |
| `just bindings::c-sdk-test` | Installed C11/C++17 APIs and example executables |
| `just bindings::java-sdk-test` | JARs, typed futures and joined port consumers |
| `just bindings::dotnet-sdk-test` | NuGet artifacts and owned task consumers |
| `just bindings::beam-sdk-test` | Installed Erlang/Elixir applications and port ownership |
| `just bindings::sdk-interop` | Installed language service/requester pairs |
| `just bindings::unified-all` | Current query callers over KV, Table and Document sources |
| `just bindings::test` | Native and installed SDK schedules plus interoperability |

The [Nix tools](../nix/bindings-tools.nix) own language versions and dependencies.
The [proof ledger](../docs/history/qualification/README.md) records executed combinations and limits;
a task's presence does not establish that it passed for the current revision.

## Go source builds

Use the pinned Go toolchain from the bindings shell:

```sh
nix develop .#bindings
just bindings::go-sdk-test
```

The task builds the Go module and explicit native installation archives under
`.cache/bindings/Debug/go/`, checks formatting, runs `go vet` and race tests with
`GOEXPERIMENT=cgocheck2`, and runs the real-authority recovery schedule from an
installed consumer outside the checkout. It also builds and runs the actual
[Go example](../examples/go-client/README.md). A foreign-definition build and a
build with cgo disabled must reject native open. `GOTOOLCHAIN=local` prevents an
implicit compiler download; the module has no external Go dependencies.

For packaging alone, use `just bindings::go-build`. The underlying builder
accepts `--native-prefix PATH` to use an explicitly selected Zig installation.
The module's generated C header, function signatures and constants participate
in `just bindings::generate` and `just bindings::check`. Follow the
[Go installation guide](../sdks/go/README.md) to consume the extracted artifacts.
