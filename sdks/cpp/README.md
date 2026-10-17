# C++ SDK

`transit-client-cpp` and `transit-station-cpp` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use C++17 callers and the pinned Zig compiler on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Extract the C++, C SDK and matching native archives into one prefix. Use its
`lib/pkgconfig` directory with the `transit-client-cpp` or `transit-station-cpp`
pkg-config package. C++ wrappers link the installed C SDK; they do not duplicate
native protocol logic.

Include `transit/client.hpp` or `transit/station.hpp`. The APIs provide typed
values and move-only owners. RAII controls local lifetime; destruction does not
undo accepted requests. Use explicit saved-command recovery for unknown outcomes.
Headers, C SDK libraries and native artifacts must share the current definition.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station-sdk/README.md)
- [Caller semantics](../../docs/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.
