# .NET public SDK examples

These handlers implement the shared [counter and query formats](../README.md)
through typed public .NET APIs: `Counter`, `Requester`, `TableService` and
`QueryRequester`. Correlations and observations live in associated state;
application fields and suspended tasks are not durable. Codecs validate exact
versions, lengths, tags and nullable markers, with `ulong`/`long` preserving all
64-bit values.

Build with `nix develop .#bindings -c just bindings::dotnet-build` and reference
`Transit.Sdk.Examples` 0.2.0 from the local NuGet feed. Its dependencies install the
public SDKs and separate native artifacts. Build a normal console consumer named
`Consumer` with exact references to `Transit.Client`, `Transit.Station.Sdk` and
`Transit.Sdk.Examples`, then run the installed example executable using that
consumer's resolved dependency/runtime configuration from its output directory:

```sh
dotnet exec --depsfile Consumer.deps.json --runtimeconfig Consumer.runtimeconfig.json Transit.Sdk.Examples.dll config.json service --commits 1
dotnet exec --depsfile Consumer.deps.json --runtimeconfig Consumer.runtimeconfig.json Transit.Sdk.Examples.dll config.json requester --commits 1
```

Each role needs its own object with `url`, `profile: "growing_v3"`, `realm`,
`principal`, `pid`, `generation`, `seed_file` and `peer`. Provision the process,
current grants, ownership and `data` association first; run delivery through the
deployment. The CLI explicitly selects `Recovery.FreshOwnership`, stops on
uncertainty and requires fencing/reconciliation after host loss. Use
`Recovery.PersistBeforeDispatch` for exact persisted host-loss retry.

Query callbacks stream bounded original IPC segments. Their external effects need
application idempotency. No optional .NET Arrow adapter is selected. The public
runner and installed executable pass the shared M11 lifecycle/data schedule via
`just bindings::dotnet-sdk-test`, including independent IPC decoding after disposal.
