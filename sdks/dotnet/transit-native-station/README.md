# Transit native .NET Station package

`Transit.Native.Station` 0.2.0 embeds the shared Zig `libtransit_station.so` for the
[public .NET Station SDK](../transit-station-sdk/README.md), on Linux x86_64.
The SDK privately extracts the library, checks versions, removes the extraction
file and retains its bounded shared code image until process exit. Explicit close
still joins owned work and destroys native handles. The
[client loader contract](../transit-client/docs/USAGE.md) defines image capacity
and override-content checks. Loading the assembly starts no native work or
credential discovery.

`just bindings::dotnet-build` creates the package in the pinned optional bindings
shell. The artifact requires that Nix runtime closure. Portable releases,
additional platforms and NuGet.org publication remain outside qualification.
