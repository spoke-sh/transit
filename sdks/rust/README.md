# Rust SDK

`transit-client` and `transit-station-sdk` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use the pinned Rust toolchain on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Extract the local 0.2.0 crates and their `transit-native-client` and
`transit-native-station` dependencies. Use exact `=0.2.0` dependencies and ordinary
`[patch.crates-io]` path entries to the extracted packages. Build with the supplied
lockfile. Registry publication is not available.

Use `transit_client` for raw callers and `transit_station_sdk` for typed runners.
Native crates embed their libraries; installed executables do not depend on Cargo
source-cache paths. The controlling API is blocking and runs outside an async
executor's event loop. Exclusive borrows and explicit shutdown govern native
work; unknown outcomes retain their saved canonical request.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station-sdk/README.md)
- [Caller semantics](../../docs/handbook/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.
