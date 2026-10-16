# C SDK

`transit-client-c` and `transit-station-c` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use C11 callers and the pinned Zig compiler on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Extract the local SDK and matching native archives into one prefix. Set
`PKG_CONFIG_PATH` to its `lib/pkgconfig` directory and compile using
`pkg-config --cflags --libs transit-client-c` or `transit-station-c`.
The SDK uses its installed rpath and locates the native library beside itself.

Include `transit/client.h` or `transit/station.h`. C callers use owned handles,
explicit destroy operations and bounded inline values. Generated symbols bind
headers and libraries to the current contract definition; rebuild consumers
with matching artifacts when that definition changes. The shared implementation
uses C++17 internally; the public C interface remains C11.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station/README.md)
- [Caller semantics](../../docs/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.
