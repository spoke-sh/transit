# Transit native .NET client package

`Transit.Native.Client` 0.2.0 is the separate Linux x86_64 native artifact for the
[public .NET client](../transit-client/README.md). The assembly embeds the pinned
Zig `libtransit_client.so`, with no Station dependency. Loading the assembly does
not load the library, read credentials or start work. An owned SDK worker extracts
the library privately, checks versions, and unloads/removes it on explicit close.

`just bindings::dotnet-build` creates the NuGet package from the pinned optional
bindings shell. It requires that Nix runtime closure. Broader platform packaging,
portable Linux builds and NuGet.org publication remain outside qualification.
