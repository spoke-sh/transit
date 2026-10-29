# Transit native .NET client package

`Transit.Native.Client` 0.0.1 is the separate Linux x86_64 and ARM64 native artifact for the
[public .NET client](../transit-client/README.md). The assembly embeds the pinned
Zig `libtransit_client.so`, with no Station dependency. Loading the assembly does
not load the library, read credentials or start work. The SDK extracts the library
privately, checks versions, removes the extraction file and retains the bounded
shared code image until process exit. Explicit close destroys owned handles and
buffers; the [loader contract](../transit-client/docs/USAGE.md) explains lifetime,
image capacity and override-content checks.

`just bindings::dotnet-build` creates the NuGet package from the pinned optional
bindings shell. It requires that Nix runtime closure. Broader platform packaging,
portable Linux builds and NuGet.org publication remain outside qualification.
