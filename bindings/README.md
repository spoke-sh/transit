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
