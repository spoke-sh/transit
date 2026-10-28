# Transit .NET client

Version 0.0.1 provides typed raw operations independently of Station, over the
generated shared Zig C ABI. Public records, owned retry bytes, task scheduling and
NuGet packaging belong to this SDK. Signing, metadata and protocol semantics stay
in Zig. Loading the assembly starts no work and discovers no credentials.

The baseline is .NET 8 on Linux x86_64 with the optional pinned bindings shell.
`just bindings::dotnet-sdk-test` builds packages and runs the clean consumer proof.
The [usage guide](docs/USAGE.md) describes installation, explicit recovery and
cancellation. The clean consumer qualifies exact recovery, revoked access,
cancelled awaits and joined native ownership in [Language SDKs](../../../docs/handbook/reference/sdks.md).

The direct native dependency is a separate [NuGet package](../transit-native-client/README.md).
Generated `Internal/NativeApi.cs` and `contract.json` come from
`just bindings::generate`; `just bindings::check` rejects drift. Internal helpers
are shared only with the version-matched Station assembly.

Endpoint serialization preserves URI escaping. The shared native client removes
trailing base-path slashes before appending an operation path. Direct
authority connections use the same canonical route as proxied connections.
