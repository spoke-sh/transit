# Transit public Station C++ SDK

M11's `transit/station.hpp` defines C++17
`Codec<T>`, `Handler<T>`, `Runner<T>`, typed keys, nullable Table rows, scoped
helpers, recovery stores and owned IPC segments. It uses namespace
`transit::sdk::station` and is separate from M9's `transit_station.hpp` adapter.

The direct [C Station SDK](../../c/transit-station/README.md) dependency owns the
bounded native worker and typed operations. C++ adds RAII, typed callback
dispatch and exception containment. `build.zig.zon` also declares direct C and
C++ client dependencies. Run `zig build check` in this package to instantiate
supported Table types and runner ownership contracts. `just bindings::c-sdk-test`
qualifies installed counter CLI roles, typed query handlers and the shared
authority/recovery schedule. See [installation and usage](docs/USAGE.md).
M15's [typed HTTP calls and replay](docs/HTTP.md) add immutable prepared requests,
an explicit reply-codec union and move-only capture readers.

A copied `Turn` retains its local scope token. All operations still reject
expired scope, wrong-thread access and callback reentry. Associated state is
durable; handler object fields and copied handles are temporary. Returning from
the handler does not mean its proposal committed. Observe `Event::info()` and
reconcile `TRANSIT_EVENT_NEEDS_RECOVERY` using the retained exact mutation.
`RecoveryStore` callbacks run before each mutation and after a known receipt.
Exceptions are caught before crossing the C callback boundary. Stop/block-input
policy discards private changes; close/RAII joins without acknowledging them.

Result readers use the current scoped grant on every manifest/segment access.
`IpcSegment` and its copied bytes survive runner destruction. This core package
does not select an optional Arrow C++ dependency; independent IPC qualification
uses the shared PyArrow consumer after runner disposal.
