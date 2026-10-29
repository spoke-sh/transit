# Elixir client usage

Build with `nix develop .#bindings -c just bindings::beam-build`. Extract the three
`transit_client_elixir`, `transit_client` and `transit_native_client` version 0.0.1
OTP tarballs into an ordinary library directory and set `ERL_LIBS` to it. Run an
Elixir consumer with `elixir app.exs`; standard OTP resolution discovers the
matching native port. The exact core dependency is also declared by `mix.exs`.
The clean-consumer proof installs compiled OTP artifacts; Mix/Hex registry
resolution and publication are outside qualification. Linux x86_64 and ARM64, OTP 28,
Elixir 1.18 and the pinned Nix native closure form the baseline.

```elixir
alias Transit.Client

{:ok, config} = Client.config("http://127.0.0.1:18101", :native_v1)
{:ok, peer} = Client.process(72, durable_pid)
{:ok, credential} = Client.credential(72, principal, seed_file)
{:ok, client} = Client.open(config)

try do
  {:ok, pending} = Client.prepare_send(client, peer, payload, credential, sequence)
  persist_and_sync(Client.export(pending))

  case Client.dispatch(client, pending) do
    {:admitted, receipt} -> observe_admission(receipt)
    {:rejected, error} -> handle_rejection(error)
    {:uncertain, recovery} -> preserve_uncertainty(recovery)
  end
after
  Client.close(client)
end
```

The callbacks and configuration values in this sketch belong to the application.
Explicitly observe and retain `close/1`'s shutdown result when it can contain
in-flight evidence. Constructor results use public structs and tagged errors;
`Pending` and `Uncertain` inspection omits signed bytes, and credential inspection
omits paths. Do not log exported recovery material.

`recover_send/2` classifies exact immutable bytes through Zig without a seed;
`recover_mutation/2` handles other growing commands. Dispatch rechecks current
grants. Identity and admission do not prove processing or reply completion.
`evidence/1` and `close/1` return typed `Shutdown` values with known receipts.
Error structs preserve kind, phase, status and bounded native code.

A `Task` can await an SDK call. Shutting down that task abandons only its wait;
admitted native work remains owned and keeps the client busy. Join with
`close/1`, which stops admission and waits for native cleanup/exit. Killing or
abandoning the close caller itself can lose its returned evidence: observe that
result. Binaries are immutable, and no borrowed native memory escapes. See the
[Erlang guide](../../transit-client/docs/USAGE.md) for exact port/queue bounds,
shutdown limits, recovery semantics and native-path overrides.

`Supervisor.start_link([{Transit.Client, config}], strategy: :one_for_one)` uses
the SDK child specification. Obtain its local child PID, then call
`Transit.Client.handle(pid)` to get the typed opaque client handle. Ordinary OTP
supervision owns only the local bridge; it does not acquire Transit generations
or retry authority. Public durable `ProcessRef` values are separate from BEAM
PIDs. This package leaves M9's `Transit.Station` low-level adapter unchanged.
