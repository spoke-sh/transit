# .NET SDK

`Transit.Client` and `Transit.Station.Sdk` separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use .NET 8 on Linux x86_64 and ARM64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Add the local NuGet output directory as a package source and reference the
0.0.1 SDK packages. Their exact dependencies include `Transit.Native.Client`
and `Transit.Native.Station`. NuGet restores these into an ordinary external
project; publication to NuGet.org is not available.

The native assemblies carry matching Zig libraries and privately extract them
at explicit open. Immutable values and bounded asynchronous tasks preserve
owned data. Dispose clients and runners using their documented asynchronous
lifetime APIs. Cancelling an await does not close an in-flight durable request.

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station-sdk/README.md)
- [Caller semantics](../../docs/handbook/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.
