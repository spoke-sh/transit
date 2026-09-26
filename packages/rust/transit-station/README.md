# transit-station for Rust

Generated `extern` declarations and owned `GenServer`/`Client` wrappers over the
shared Zig implementation. Runtime semantics, signing, Tables and Arrow parsing
stay in Zig. Rust owns JSON values, exceptions/panics and scheduling. Cargo.lock
pins the sole direct Rust dependency, serde_json; arbitrary-precision JSON parsing
and decimal string cells/correlations preserve the shared wire contract.

The independent [M11 raw client](../transit-client/README.md) now provides typed
operations, owned workers and installable native artifacts. The
[typed Station SDK](../transit-station-sdk/README.md) provides borrowed handler
turns, Tables, query results and explicit recovery stores. This M9 crate retains its existing entry points.

```sh
nix develop .#bindings
zig build station-abi client-abi
export TRANSIT_LIBRARY_DIR="$PWD/zig-out/lib"
cargo build --locked --manifest-path packages/rust/transit-station/Cargo.toml --example station
just bindings::test
```

The [example](../../../examples/station-bindings/rust/main.rs) takes a provisioned
host-config path, role (`service`/`requester`) and peer PID. The proof creates those
resources automatically and exchanges queries with independent C/C++ callers.
The baseline is Rust/Cargo 1.95.0 on Linux x86_64. Native libraries must remain
available at their explicit runtime path; public registry packaging is unqualified.

Use `transit_station::spawn` for native work. It applies the generated **8 MiB**
stack budget; Rust's default 2 MiB worker stack failed the Debug service proof.
For async integration, send work to a bounded owned worker or configure the
executor's blocking workers appropriately. Handles are `Send`, deliberately not
`Sync`; operations require `&mut self`, and Drop releases the native handle.
Dropping an await is not remote cancellation, and panic/unwinding does not
implicitly finish a handler. Fence/reconcile a lost activation before recomputing.

Actions and results use the [generated shared schema](../../zig/transit-station-bindings/abi-v1.json).
`pending` and raw `Client::prepare` return exact frozen strings; never re-encode
them before retry. Query results expose original IPC bytes (hex in the action
result); `arrow_cell` is an optional bounded native reader, preserving int64 as
decimal text. [ABI rules](../../zig/transit-station-bindings/docs/bindings.md) govern the
same budgets, grants, failure distinctions and lifetime behavior as Zig callers.
