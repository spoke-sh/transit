# transit-station for C++

[transit_station.hpp](include/transit_station.hpp) adds move-only Station handles
and buffers over the generated [C ABI](../../zig/transit-station-bindings/include/transit_station.h).
It also wraps raw Transit request preparation and exact frozen-request calls.
Link `transit_station` and `transit_client`; include both generated header
directories and this package's `include`. C callers use the generated headers
directly, with the same ownership and status rules.

The baseline is C11/C++17 compiled by the pinned Zig toolchain on Linux x86_64.
`just bindings::native` compiles both examples and exchanges real durable Table
queries across C, C++ and Python. [The C example](../../../examples/station-bindings/c/main.c)
manages every native buffer explicitly; [C++](../../../examples/station-bindings/cpp/main.cpp)
uses RAII and retains original IPC bytes before inspecting a cell.

Calls block. Use a bounded worker with the generated minimum stack budget and
join it before moving/destroying a handle. Handles are not concurrent containers;
RAII cannot make destruction during another thread's native call safe. Buffer
views borrow until their owning `Buffer` is released. Copies are ordinary owned
`std::string` values. Neither exceptions nor destructors commit/acknowledge inputs.

`GenServer::next/apply/finish/pending` follow the
[shared ABI](../../zig/transit-station-bindings/docs/bindings.md). `transit::Error` retains
the native numeric status and error text. JSON access delegates to Zig's bounded
helper, so no extra C++ parser or protocol implementation is needed. Application
handlers remain outside the authority and own their failure policy.
