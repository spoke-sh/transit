# transit-station-sdk for Rust

Typed growing-profile Station handlers, KV/Table state, retained sources, durable
calls and original Arrow IPC over the shared Zig implementation. The separate
M9 `transit-station` crate keeps its low-level entry points.

Read the [usage and recovery guide](docs/USAGE.md), the compiled
[counter and query examples](../../../examples/station-sdk/rust/README.md), and
the [Rust design](../../../docs/sdk/RUST.md). Generated declarations are private;
the independent [raw client](../transit-client/README.md) owns raw operations.
The [HTTP guide](docs/HTTP.md) covers experimental typed request publication,
correlated outcomes and replay readers that borrow their runner exclusively.

Build version-matched `.crate` artifacts with
`nix develop .#bindings --command just bindings::rust-build`. The native dependency
embeds Linux x86_64 libraries; their Nix runtime closure must be available. Registry
publication and other platforms remain unqualified. See the
[native package](../transit-native-station/README.md) for artifact overrides.

Run `nix develop .#bindings --command just bindings::rust-sdk-test` for formatting,
clean external consumers, compiler rejection cases and real authority schedules.
The [test guide](../../../tests/README.md) records evidence and limitations.
