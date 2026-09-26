# Transit native .NET Station package

`Transit.Native.Station` 0.2.0 embeds the shared Zig `libtransit_station.so` for the
[public .NET Station SDK](../transit-station-sdk/README.md), on Linux x86_64.
The SDK worker privately extracts the library, checks versions, and removes it
after owned work is joined and native handles are destroyed. Loading the assembly
starts no native work or credential discovery.

`just bindings::dotnet-build` creates the package in the pinned optional bindings
shell. The artifact requires that Nix runtime closure. Portable releases,
additional platforms and NuGet.org publication remain outside qualification.
