# Elixir Station usage

Build with `nix develop .#bindings -c just bindings::beam-build`. Install the
compiled 0.2.0 `transit_client_elixir` and `transit_station_elixir` archives plus
the four Erlang/native dependencies listed in the [shared usage guide](../../transit-station-sdk/docs/usage.md)
under an external `ERL_LIBS` directory. The builder derives the application
metadata and direct dependencies from `mix.exs`; runtime consumers need only the
compiled OTP artifacts and pinned Nix native closure. Hex/Mix registry resolution
is outside current qualification.

Use `Transit.Client` configuration, credential and durable `ProcessRef` structs.
`Transit.Station.Sdk.ServiceConfig` combines that client and an `Activation`, with
association `"data"` and optional query results. Open with:

```elixir
alias Transit.Station.Sdk.Runner
{:ok, runner} = Runner.open(service, MyHandler, initial_context, MyCodec,
  failure_policy: :stop,
  recovery: {:persist_before_dispatch, MyRecoveryStore, store_options})
```

The installed [examples](../../../../examples/station-sdk/elixir/README.md) contain
complete codecs, counter/requester, Table service and streaming query handlers.
`Handler`, `Codec` and `RecoveryStore` are ordinary Elixir behaviours. Handler
callbacks return `{:ok, context}` or `{:error, reason}`. Context, Tasks and BEAM
process fields are local; associated state and recorded outcomes are durable.

Use `Turn`, `State`, `Source`, `Table`, `Query` and `ResultReader` helpers. They
return tagged results and public structs, with integer precision preserved.
`State.find/2` and `Table.get/2` distinguish `:missing` from `{:found, value}`.
A `Row` with `value: nil` is a present nullable cell. Application codec values are
returned unchanged, including user structs, nested maps and tuples.

`Runner.next/1` returns progress/idle/stopped atoms or `Committed`, `Blocked` and
`NeedsRecovery` structs. A callback return is not a commit. `reconcile/1` preserves
identity and retained confirmation; `evidence/1` and `close/1` expose recovery
material. `Sdk.export/1` returns exact signed frozen bytes for durable persistence;
public Inspect implementations omit those bytes. Protect exported data and raw
terms. Recovery hooks must finish durable storage before returning `:ok`.

Each helper belongs to one active callback process. An operation from a Task or
other process returns `:busy`; an escaped helper returns `:turn_expired`. Codec
reentry is rejected. A caught failed read still aborts the whole private turn.
Original IPC binaries and manifests are owned data and remain usable after close.
No optional Elixir Arrow adapter is selected.

Runner calls yield while the owned worker waits for native I/O. Cancelling a Task
abandons that local wait only; the admitted operation retains the worker slot.
`stop/1` is cooperative. `close/1` drains native work, acknowledges cleanup and
joins the native child. It can return a committed event or exact pending material.
Use a live owner to collect its result; losing a closing caller can lose the local
snapshot. This is independent of the durable recovery hooks.

`Runner.child_spec({service, handler, context, codec, options})` is temporary with
a 70-second shutdown budget. `Runner.handle(pid)` obtains its public handle.
Supervision does not acquire a new Transit generation. Forced process/VM loss
requires explicit activation and recovery. See the shared guide for operation,
port, workspace and cleanup bounds, error distinctions, failure policies,
recovery ordering and current authorization requirements.

Application code uses typed SDK callbacks, records and codecs. The shared native
port owns protocol and Station semantics through the current v1 definition.
Generated action schemas and transport calls remain internal adapter boundaries.
