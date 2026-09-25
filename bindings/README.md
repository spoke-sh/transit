# Transit and Station bindings

The shared implementation remains Zig. The raw Transit ABI handles public
protocol operations; Station adds detached handler turns, associated state,
Table queries and durable framework messages. Host adapters own allocation,
exceptions and runtime scheduling. They do not reimplement those protocols.

These are M9's qualified low-level bindings. [M11](../docs/roadmap/M11.md)
plans language-native public SDKs with typed operations, managed handler runners
and installable artifacts. The current manual turn/action APIs remain available;
the [caller design](../docs/CLIENT.md#idiomatic-language-sdks) defines the planned
layer above them.

`just bindings::generate` reflects the native exports and updates adapter
resources. `just bindings::check` rejects drift. The
[shared ABI guide](../packages/zig/transit-station/docs/bindings.md) owns the
contract; the [native port](../apps/transit-station-host/README.md) supplies a
versioned child-process route for Node, Java and BEAM.

The [C/C++](../packages/cpp/transit-station/README.md),
[Rust](../packages/rust/transit-station/README.md),
[Python](../packages/python/transit-station/README.md),
[Node](../packages/ts/transit-station/README.md),
[Java](../packages/java/transit-station/README.md),
[.NET](../packages/dotnet/transit-station/README.md) and
[Elixir/Erlang](../packages/beam/transit-station/README.md) adapters exchange real
Table queries across languages. Native/managed cancellation, host loss, malformed
ports and ownership cleanup have executable checks. The reference deployment
qualifies Zig workers; foreign worker isolation remains separate scope.
[The examples](../examples/station-bindings/README.md) use real
authority and Arrow data, not language-specific server routes. Public package
registry releases and non-Linux platforms are not qualified yet.

## Qualification tools

`nix develop .#bindings` adds the locked foreign-language tools to the normal
shell. Keeping them optional avoids expanding every developer/CI closure.
C/C++ use the pinned Zig compiler; Python and Node already come from the default
shell. The current Linux x86_64 baselines are:

| Runtime | Locked baseline |
| --- | --- |
| Zig / C / C++ | 0.17.0-dev.2267+48abf1a34 |
| Python | CPython 3.13.15; PyArrow 23.0.0 for independent IPC checks |
| Rust / Cargo | 1.95.0 |
| Node.js | 24.21.0 from the existing frontend toolchain |
| Java | OpenJDK 21.0.12.1+1; Gson 2.12.1, separately checksummed |
| .NET SDK | 8.0.425 |
| Erlang | OTP 28.5.0.6 |
| Elixir | 1.18.5 built against OTP 28 |

The Nix lock and [binding tools](../nix/bindings-tools.nix) own these versions.
Every listed language runs both service and requester roles in the Linux matrix.
Only Zig is the intended M9 reference worker; these checks do not qualify foreign
runtimes as Substrate workers.
