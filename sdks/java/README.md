# Java SDK

`transit-client` and `transit-station-sdk` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use Java 21 on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Copy the local 0.2.0 SDK and matching native JARs, plus the supplied
`gson-2.12.1.jar`, into your application's `lib/` directory. Compile with
`javac --release 21 -cp 'lib/*'` and run with `java -cp 'lib/*:classes' YourApplication`.
The JAR manifests describe dependencies; local installation uses the explicit
classpath. Maven registry publication is not available.

Use `io.transit.sdk.client` for raw callers and `io.transit.sdk.station` for the
framework. Immutable values and bounded futures retain native ownership and
error distinctions. Close owned clients and runners explicitly; cancelling a
future does not establish rejection or durable cancellation.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station-sdk/README.md)
- [Caller semantics](../../docs/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.
