# Transit .NET Station SDK

Version 0.2.0 adds typed synchronous `IHandler<T>` callbacks, scoped KV/Table
helpers, bounded `Task` runner operations and owned query IPC over the shared
Zig implementation. The independent [raw client](../transit-client/README.md)
owns the shared worker/packaging helpers; it does not depend on Station. Generated
ABI delegates and contract resources remain separate from public types.

The public runner is qualified under [M11](../../../docs/roadmap/M11.md) through
`just bindings::dotnet-sdk-test`: clean NuGet consumers, all mutation gates, exact
host-loss recovery, cancellation/join, retained Tables and original query IPC.
Build from `nix develop .#bindings` with `just bindings::dotnet-build`. The package targets .NET 8/Linux x86_64 and
uses exact `Transit.Client` and `Transit.Native.Station` 0.2.0 dependencies.
Native artifacts require the pinned Nix closure. Registry publication and foreign
Substrate worker images remain outside qualification.

The [usage guide](docs/USAGE.md) covers installation, typed state, recovery,
cleanup, queries and migration from the M9 adapter. Installed
[examples](../../../examples/station-sdk/dotnet/README.md) provide both roles.
M15's [HTTP guide](docs/HTTP.md) covers immutable requests, typed outcomes,
scoped upload/calls and owned asynchronous capture readers.

Handlers use `Initialize`, `OnMessage`, `OnControl` and `OnResult`; the runner owns
native preparation/finish and gated dispatch. Explicit `Recovery.FreshOwnership`
or `Recovery.PersistBeforeDispatch` governs host-loss recovery. Hook failure retains
exact pending bytes and known receipts for `ReconcileAsync`. Callbacks run on the
owned 8 MiB native worker and must be synchronous; `async void` handler and
persistence callbacks are rejected before startup. Returning from a callback
does not prove commitment. Local cancellation/stop does not cancel durable work.

`Key<T>` carries a bounded versioned codec. `TableSchema<T>` selects nullable
`long?`, `bool?`, `string?` or immutable `Bytes?` cells. Turn-derived helpers reject
wrong-thread, reentrant and expired access. Read errors poison the private turn.
Retained-source identities need explicit durable retain/release operations.
Queries expose complete metadata and copied original Arrow IPC; no optional .NET
Arrow adapter is selected. Use explicit asynchronous disposal and retain shutdown
evidence; managed tasks and object fields are not durable state.

M16 adds [finite RPC calls and captured replay](docs/GRPC.md), including local
descriptor binding, binary metadata and observed status zero.

M17 adds [immutable Document changes and asynchronous accepted-state reads](docs/DOCUMENTS.md)
with scoped jobs, full-width identities and joined cancellation/disposal.

M18 adds [typed unified state queries](docs/UNIFIED_QUERY.md), with owned nested
Arrow values, current source checks and explicit signed retry tokens.

[Table mutation callers](docs/MUTATIONS.md) expose bounded SQL compilation,
immutable recovery values, explicit admission and current status through an
owned asynchronous client.
