# Erlang and Elixir SDK

Erlang OTP applications and Elixir wrappers separate raw signed operations from Station's typed handlers,
state and durable calls. Shared Zig owns protocol and framework semantics;
these packages own language types, codecs, scheduling and packaging.

## Installation

Use OTP 28 and Elixir 1.18 on Linux x86_64. Build all artifacts from the same checkout using
the [source build instructions](../../bindings/README.md#build-and-verification).
Native artifacts require that build's Nix runtime closure. Other platforms and
portable native distributions are not supplied.

Extract the local 0.0.1 OTP tarballs into an ordinary library directory and
set `ERL_LIBS` to it. Raw Erlang clients use `transit_client` with
`transit_native_client`; Station adds `transit_station_sdk` and
`transit_native_station`. Elixir also uses `transit_client_elixir` and
`transit_station_elixir`. Mix/Hex registry publication is not available.

Erlang APIs use immutable records and an owned worker. Elixir exposes structs
through `Transit.Client` and `Transit.Station.Sdk` over the same Erlang caller.
Both retain native port ownership, bounded admission and explicit shutdown.
Process messages and host tasks are not durable application state.

For Elixir, use the [client guide](transit-client-elixir/README.md) and
[Station guide](transit-station-elixir/README.md).

## Client and framework guides

- [Raw client API and recovery](transit-client/README.md)
- [Station API and handler ownership](transit-station-sdk/README.md)
- [Caller semantics](../../docs/handbook/reference/callers.md)
- [Complete application examples](../../examples/station-sdk/README.md)

Select credentials and the native profile explicitly. A locally compatible
library does not establish current server capabilities or authorization. Retain
the original canonical request after an unknown outcome; closing a handle or
cancelling a host task does not undo accepted work.
