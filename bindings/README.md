# Transit and Station bindings

The shared implementation remains Zig. The raw Transit ABI handles public
protocol operations; Station adds detached handler turns, associated state,
Table queries and durable framework messages. Host adapters own allocation,
exceptions and runtime scheduling. They do not reimplement those protocols.

`just bindings::generate` reflects the native exports and updates adapter
resources. `just bindings::check` rejects drift. The
[shared ABI guide](../packages/zig/transit-station/docs/bindings.md) owns the
contract; the [native port](../apps/transit-station-host/README.md) supplies a
versioned child-process route for Node, Java and BEAM.

The Python adapter and native host proof are implemented. C/C++, Rust, Node,
Java, .NET and Elixir/Erlang adapters and the complete cross-language matrix are
still M9 work. [The examples](../examples/station-bindings/README.md) use real
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
| Node.js | 24 from the existing frontend toolchain |
| Java | OpenJDK 21.0.12.1+1; Gson 2.12.1, separately checksummed |
| .NET SDK | 8.0.425 |
| Erlang | OTP 28.5.0.6 |
| Elixir | 1.18.5 built against OTP 28 |

The Nix lock and [binding tools](../nix/bindings-tools.nix) own these versions.
Tool availability is separate from completed language qualification.
